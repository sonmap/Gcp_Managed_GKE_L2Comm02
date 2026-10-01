terraform {
  required_version = ">= 1.6.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0, < 8.0"
    }
  }
}

provider "google" {
  project = var.host_project_id
  region  = var.region
}

provider "google" {
  alias   = "edge"
  project = var.edge_project_id
  region  = var.region
}

# APIs required by Scheduler / GitHub Connection / Trigger.
resource "google_project_service" "cloudscheduler" {
  provider           = google.edge
  project            = var.edge_project_id
  service            = "cloudscheduler.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "secretmanager" {
  provider           = google.edge
  project            = var.edge_project_id
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

data "google_compute_network" "shared_vpc" {
  project = var.host_project_id
  name    = var.network_name
}

data "google_project" "service_project" {
  project_id = var.edge_project_id
}

# Cloud Build 2nd-gen GitHub connection stores its OAuth token in Secret Manager.
resource "google_project_iam_member" "cloudbuild_p4sa_secretmanager_admin" {
  provider = google.edge
  project  = var.edge_project_id
  role     = "roles/secretmanager.admin"
  member   = "serviceAccount:service-${data.google_project.service_project.number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"

  depends_on = [google_project_service.secretmanager]
}

# Infrastructure Manager must be able to create/update Cloud Build triggers.
resource "google_project_iam_member" "inframgr_cloudbuild_editor" {
  provider = google.edge
  project  = var.edge_project_id
  role     = "roles/cloudbuild.builds.editor"
  member   = "serviceAccount:${var.inframgr_service_account}"
}

# Attach Edge service project to Shared VPC host.
resource "google_compute_shared_vpc_service_project" "edge" {
  host_project    = var.host_project_id
  service_project = var.edge_project_id
}

# GKE Node subnet.
# Design principle:
# - Existing 172.x is preserved for actual service networks.
# - 10.x is consumed only for the relatively small Node primary range.
# - Pod IP uses 100.64/10 space to reduce RFC1918 exhaustion.
# - Kubernetes Service IP uses GKE managed 34.118.224.0/20 in 30-infra-manager.
resource "google_compute_subnetwork" "gke" {
  project                  = var.host_project_id
  name                     = var.subnet_name
  region                   = var.region
  network                  = data.google_compute_network.shared_vpc.id
  ip_cidr_range            = var.node_cidr
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = var.pod_range_name
    ip_cidr_range = var.pod_cidr
  }

  depends_on = [google_compute_shared_vpc_service_project.edge]
}

locals {
  project_number    = data.google_project.service_project.number
  gke_service_agent = "service-${local.project_number}@container-engine-robot.iam.gserviceaccount.com"
  cloud_services_sa = "${local.project_number}@cloudservices.gserviceaccount.com"
}

resource "google_compute_subnetwork_iam_member" "gke_agent_network_user" {
  project    = var.host_project_id
  region     = var.region
  subnetwork = google_compute_subnetwork.gke.name
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:${local.gke_service_agent}"
}

resource "google_compute_subnetwork_iam_member" "cloud_services_network_user" {
  project    = var.host_project_id
  region     = var.region
  subnetwork = google_compute_subnetwork.gke.name
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:${local.cloud_services_sa}"
}

resource "google_project_iam_member" "gke_host_service_agent_user" {
  project = var.host_project_id
  role    = "roles/container.hostServiceAgentUser"
  member  = "serviceAccount:${local.gke_service_agent}"
}

resource "google_project_iam_member" "gke_firewall_admin" {
  project = var.host_project_id
  role    = "roles/compute.securityAdmin"
  member  = "serviceAccount:${local.gke_service_agent}"
}

output "gke_subnet" {
  value = google_compute_subnetwork.gke.name
}

output "node_cidr" {
  value = var.node_cidr
}

output "pod_cidr" {
  value = var.pod_cidr
}

output "service_cidr" {
  value = var.service_cidr
}
