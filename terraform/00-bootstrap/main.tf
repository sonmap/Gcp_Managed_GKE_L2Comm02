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
  project = var.edge_project_id
  region  = var.region
}

provider "google" {
  alias   = "host"
  project = var.host_project_id
  region  = var.region
}

provider "google" {
  alias   = "data"
  project = var.data_project_id
  region  = var.region
}

locals {
  edge_apis = toset([
    "artifactregistry.googleapis.com",
    "bigquery.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudscheduler.googleapis.com",
    "compute.googleapis.com",
    "config.googleapis.com",
    "container.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "secretmanager.googleapis.com",
    "serviceusage.googleapis.com",
    "storage.googleapis.com",
    "workflows.googleapis.com",
    "workflowexecutions.googleapis.com"
  ])

  host_apis = toset([
    "compute.googleapis.com",
    "container.googleapis.com",
    "serviceusage.googleapis.com"
  ])

  deploy_edge_roles = toset([
    "roles/artifactregistry.admin",
    "roles/cloudbuild.builds.editor",
    "roles/compute.viewer",
    "roles/container.admin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountUser",
    "roles/resourcemanager.projectIamAdmin",
    "roles/serviceusage.serviceUsageAdmin"
  ])

  deploy_host_roles = toset([
    "roles/compute.networkAdmin",
    "roles/compute.securityAdmin",
    "roles/resourcemanager.projectIamAdmin",
    "roles/serviceusage.serviceUsageAdmin"
  ])

  inframgr_roles = toset([
    "roles/artifactregistry.admin",
    "roles/cloudbuild.builds.editor",
    "roles/compute.viewer",
    "roles/config.agent",
    "roles/container.admin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountUser",
    "roles/logging.viewer",
    "roles/resourcemanager.projectIamAdmin",
    "roles/workflows.admin"
  ])
}

resource "google_project_service" "edge" {
  for_each           = local.edge_apis
  project            = var.edge_project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_project_service" "host" {
  provider           = google.host
  for_each           = local.host_apis
  project            = var.host_project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_storage_bucket" "tfstate" {
  project                     = var.edge_project_id
  name                        = var.tfstate_bucket_name
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = false

  versioning {
    enabled = true
  }

  depends_on = [google_project_service.edge]
}

resource "google_service_account" "tf_admin" {
  project      = var.edge_project_id
  account_id   = "sa-l2comm-tf-admin"
  display_name = "L2Comm delegated Terraform administrator"
  depends_on   = [google_project_service.edge]
}

resource "google_service_account" "inframgr" {
  project      = var.edge_project_id
  account_id   = "sa-l2comm-inframgr"
  display_name = "L2Comm Infrastructure Manager execution SA"
  depends_on   = [google_project_service.edge]
}

resource "google_storage_bucket_iam_member" "tf_admin_state_admin" {
  bucket = google_storage_bucket.tfstate.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.tf_admin.email}"
}

resource "google_storage_bucket_iam_member" "admin_state_admin" {
  bucket = google_storage_bucket.tfstate.name
  role   = "roles/storage.objectAdmin"
  member = "user:${var.admin_user}"
}

resource "google_project_iam_member" "tf_admin_edge" {
  for_each = local.deploy_edge_roles
  project  = var.edge_project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.tf_admin.email}"
}

resource "google_project_iam_member" "tf_admin_host" {
  provider = google.host
  for_each = local.deploy_host_roles
  project  = var.host_project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.tf_admin.email}"
}

resource "google_project_iam_member" "tf_admin_data_bq" {
  provider = google.data
  project  = var.data_project_id
  role     = "roles/bigquery.admin"
  member   = "serviceAccount:${google_service_account.tf_admin.email}"
}

resource "google_service_account_iam_member" "vm_can_impersonate_tf_admin" {
  service_account_id = google_service_account.tf_admin.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${var.vm_service_account}"
}

resource "google_service_account_iam_member" "admin_can_impersonate_tf_admin" {
  service_account_id = google_service_account.tf_admin.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "user:${var.admin_user}"
}

resource "google_project_iam_member" "inframgr_project_roles" {
  for_each = local.inframgr_roles
  project  = var.edge_project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.inframgr.email}"
}

resource "google_project_iam_member" "inframgr_host_network_user" {
  provider = google.host
  project  = var.host_project_id
  role     = "roles/compute.networkUser"
  member   = "serviceAccount:${google_service_account.inframgr.email}"
}

resource "google_project_iam_member" "inframgr_data_bq" {
  provider = google.data
  project  = var.data_project_id
  role     = "roles/bigquery.admin"
  member   = "serviceAccount:${google_service_account.inframgr.email}"
}

resource "google_service_account_iam_member" "vm_can_use_inframgr" {
  service_account_id = google_service_account.inframgr.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${var.vm_service_account}"
}

resource "google_service_account_iam_member" "admin_can_use_inframgr" {
  service_account_id = google_service_account.inframgr.name
  role               = "roles/iam.serviceAccountUser"
  member             = "user:${var.admin_user}"
}

resource "google_project_iam_member" "vm_config_admin" {
  project = var.edge_project_id
  role    = "roles/config.admin"
  member  = "serviceAccount:${var.vm_service_account}"
}
