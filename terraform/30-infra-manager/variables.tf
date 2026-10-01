variable "edge_project_id" {
  type    = string
  default = "gcp-prod-edp-edge-509423"
}

variable "host_project_id" {
  type    = string
  default = "gcp-prod-edp-hub-vpchost"
}

variable "data_project_id" {
  type    = string
  default = "pjt-c-admin"
}

variable "target_dataset" {
  type    = string
  default = "dlk_sample"
}

variable "target_table" {
  type    = string
  default = "gcp_region_inventory"
}

variable "region" {
  type    = string
  default = "asia-northeast3"
}

variable "network_name" {
  type    = string
  default = "vpc-prod-edp-hub"
}

variable "subnet_name" {
  type    = string
  default = "subnet-prod-edp-l2comm-gke-an3"
}

variable "pod_range_name" {
  type    = string
  default = "pods-prod-edp-l2comm-an3"
}

# GKE managed Service CIDR. No subnet secondary range is created for Services.
variable "service_cidr" {
  type    = string
  default = "34.118.224.0/20"
}

variable "control_plane_cidr" {
  type    = string
  default = "10.254.5.0/28"
}

variable "cluster_name" {
  type    = string
  default = "gke-l2comm-batch-an3"
}

variable "artifact_repository" {
  type    = string
  default = "ar-l2comm-python"
}

variable "helm_repository" {
  type    = string
  default = "ar-l2comm-helm"
}

variable "image_name" {
  type    = string
  default = "python-bq-batch"
}

variable "image_tag" {
  type    = string
  default = "v1"
}

variable "namespace" {
  type    = string
  default = "l2comm-batch"
}

variable "ksa_name" {
  type    = string
  default = "ksa-l2comm-batch"
}

variable "workflow_name" {
  type    = string
  default = "wf-l2comm-gke-job"
}

variable "vm_service_account" {
  type    = string
  default = "620081195575-compute@developer.gserviceaccount.com"
}

variable "autopilot_node_service_account" {
  type        = string
  description = "Service account used by GKE Autopilot nodes to pull images"
  default     = "541022739403-compute@developer.gserviceaccount.com"
}

variable "cloudbuild_connection_name" {
  type    = string
  default = "github-l2comm"
}

variable "cloudbuild_repository_name" {
  type    = string
  default = "Gcp_Managed_GKE_L2Comm02"
}

variable "cloudbuild_trigger_name" {
  type    = string
  default = "trg-l2comm-python-image"
}
