terraform {
  required_version = ">= 1.5.7"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0, < 8.0"
    }
  }
}

provider "google" {
  project = var.edge_project_id
  region  = var.region
}

provider "google" {
  alias   = "data"
  project = var.data_project_id
  region  = var.region
}

resource "google_artifact_registry_repository" "python" {
  project       = var.edge_project_id
  location      = var.region
  repository_id = var.artifact_repository
  description   = "L2Comm Python batch images"
  format        = "DOCKER"
}

resource "google_artifact_registry_repository" "helm" {
  project       = var.edge_project_id
  location      = var.region
  repository_id = var.helm_repository
  description   = "L2Comm offline OCI Helm charts"
  format        = "DOCKER"
}

resource "google_service_account" "runtime" {
  project      = var.edge_project_id
  account_id   = "sa-l2comm-runtime"
  display_name = "L2Comm GKE Python runtime"
}

resource "google_service_account" "workflow" {
  project      = var.edge_project_id
  account_id   = "sa-l2comm-workflow"
  display_name = "L2Comm Workflow GKE Job launcher"
}

resource "google_service_account" "cloudbuild" {
  project      = var.edge_project_id
  account_id   = "sa-l2comm-cloudbuild"
  display_name = "L2Comm Cloud Build"
}

resource "google_project_iam_member" "runtime_job_user" {
  project = var.edge_project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.runtime.email}"
}

resource "google_project_iam_member" "runtime_compute_viewer" {
  project = var.edge_project_id
  role    = "roles/compute.viewer"
  member  = "serviceAccount:${google_service_account.runtime.email}"
}

resource "google_bigquery_dataset_iam_member" "runtime_data_editor" {
  provider   = google.data
  project    = var.data_project_id
  dataset_id = var.target_dataset
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${google_service_account.runtime.email}"
}

resource "google_project_iam_member" "workflow_container_developer" {
  project = var.edge_project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${google_service_account.workflow.email}"
}

resource "google_project_iam_member" "workflow_invoker" {
  project = var.edge_project_id
  role    = "roles/workflows.invoker"
  member  = "serviceAccount:${google_service_account.workflow.email}"
}

resource "google_project_iam_member" "cloudbuild_ar_writer" {
  project = var.edge_project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.cloudbuild.email}"
}

resource "google_project_iam_member" "cloudbuild_log_writer" {
  project = var.edge_project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cloudbuild.email}"
}

resource "google_project_iam_member" "cloudbuild_storage_viewer" {
  project = var.edge_project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.cloudbuild.email}"
}

# Build is event-driven, not part of every batch execution.
# After this trigger exists, main branch changes under the included paths
# automatically build/push the application image once.
resource "google_cloudbuild_trigger" "python_image" {
  project     = var.edge_project_id
  location    = var.region
  name        = var.cloudbuild_trigger_name
  description = "Auto-build L2Comm Python image on source updates"
  filename    = "cloudbuild/cloudbuild.yaml"

  service_account = google_service_account.cloudbuild.id

  included_files = [
    "app/**",
    "cloudbuild/**",
    "terraform/30-infra-manager/**"
  ]

  repository_event_config {
    repository = "projects/${var.edge_project_id}/locations/${var.region}/connections/${var.cloudbuild_connection_name}/repositories/${var.cloudbuild_repository_name}"

    push {
      branch = "^main$"
    }
  }

  depends_on = [
    google_artifact_registry_repository.python,
    google_project_iam_member.cloudbuild_ar_writer,
    google_project_iam_member.cloudbuild_log_writer,
    google_project_iam_member.cloudbuild_storage_viewer
  ]
}

resource "google_project_iam_member" "autopilot_default_node_sa" {
  project = var.edge_project_id
  role    = "roles/container.defaultNodeServiceAccount"
  member  = "serviceAccount:${var.autopilot_node_service_account}"
}

resource "google_artifact_registry_repository_iam_member" "vm_reader" {
  project    = var.edge_project_id
  location   = var.region
  repository = google_artifact_registry_repository.python.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${var.vm_service_account}"
}

resource "google_artifact_registry_repository_iam_member" "autopilot_node_reader" {
  project    = var.edge_project_id
  location   = var.region
  repository = google_artifact_registry_repository.python.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${var.autopilot_node_service_account}"
}

resource "google_container_cluster" "autopilot" {
  project          = var.edge_project_id
  name             = var.cluster_name
  location         = var.region
  enable_autopilot = true

  network    = "projects/${var.host_project_id}/global/networks/${var.network_name}"
  subnetwork = "projects/${var.host_project_id}/regions/${var.region}/subnetworks/${var.subnet_name}"

  # Pod addresses come from the 100.64/10-based secondary range created in 10-network.
  # Service addresses use the GKE-managed 34.118.224.0/20 range and therefore do not
  # consume an additional subnet secondary range.
  ip_allocation_policy {
    cluster_secondary_range_name = var.pod_range_name
    services_ipv4_cidr_block     = var.service_cidr
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = true
    master_ipv4_cidr_block  = var.control_plane_cidr
  }

  # Required in the PoC because the management VM source range is not RFC1918.
  master_authorized_networks_config {
    private_endpoint_enforcement_enabled = false
  }

  workload_identity_config {
    workload_pool = "${var.edge_project_id}.svc.id.goog"
  }

  deletion_protection = false
}

resource "google_service_account_iam_member" "workload_identity" {
  service_account_id = google_service_account.runtime.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.edge_project_id}.svc.id.goog[${var.namespace}/${var.ksa_name}]"

  depends_on = [google_container_cluster.autopilot]
}

locals {
  image_uri    = "${var.region}-docker.pkg.dev/${var.edge_project_id}/${var.artifact_repository}/${var.image_name}:${var.image_tag}"
  helm_oci_uri = "oci://${var.region}-docker.pkg.dev/${var.edge_project_id}/${var.helm_repository}"
}

resource "google_workflows_workflow" "gke_batch" {
  project         = var.edge_project_id
  region          = var.region
  name            = var.workflow_name
  description     = "Create and wait for the L2Comm Kubernetes Job on GKE Autopilot"
  service_account = google_service_account.workflow.email

  source_contents = templatefile("${path.module}/workflow.yaml.tftpl", {
    edge_project_id = var.edge_project_id
    region          = var.region
    cluster_name    = google_container_cluster.autopilot.name
    namespace       = var.namespace
    ksa_name        = var.ksa_name
    image_uri       = local.image_uri
    target_project  = var.data_project_id
    target_dataset  = var.target_dataset
    target_table    = var.target_table
  })
}

output "cluster_name" {
  value = google_container_cluster.autopilot.name
}

output "artifact_image" {
  value = local.image_uri
}

output "helm_oci_repository" {
  value = local.helm_oci_uri
}

output "cloudbuild_trigger_name" {
  value = google_cloudbuild_trigger.python_image.name
}

output "namespace" {
  value = var.namespace
}

output "runtime_service_account" {
  value = google_service_account.runtime.email
}

output "workflow_service_account" {
  value = google_service_account.workflow.email
}

output "workflow_name" {
  value = google_workflows_workflow.gke_batch.name
}
