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

resource "google_project_iam_member" "cloudbuild_p4sa_secretmanager_admin" {
  provider = google.edge
  project  = var.edge_project_id
  role     = "roles/secretmanager.admin"
  member   = "serviceAccount:service-${data.google_project.service_project.number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"

  depends_on = [google_project_service.secretmanager]
}

resource "google_project_iam_member" "inframgr_cloudbuild_editor" {
  provider = google.edge
  project  = var.edge_project_id
  role     = "roles/cloudbuild.builds.editor"
  member   = "serviceAccount:${var.inframgr_service_account}"
}

resource "google_compute_shared_vpc_service_project" "edge" {
  host_project    = var.host_project_id
  service_project = var.edge_project_id
}

# GKE network design:
# - Existing 172.x stays reserved for service networks.
# - 10.x is consumed only by the small Node primary range.
# - Pod IP uses 100.64.0.0/21.
# - No Service secondary range is created here; Autopilot uses its managed
#   Service range when 30-infra-manager recreates the cluster.
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
