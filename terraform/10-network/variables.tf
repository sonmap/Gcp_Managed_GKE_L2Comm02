variable "edge_project_id" {
  type    = string
  default = "gcp-prod-edp-edge-509423"
}

variable "host_project_id" {
  type    = string
  default = "gcp-prod-edp-hub-vpchost"
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

# /26 gives 64 addresses (60 usable in a GCP subnet), enough for the
# ~20-node capacity-planning equivalent with operational headroom.
variable "node_cidr" {
  type    = string
  default = "10.254.0.0/26"
}

variable "pod_range_name" {
  type    = string
  default = "pods-prod-edp-l2comm-an3"
}

# RFC6598 shared address space used for Pods to preserve scarce 172/10 space.
# /21 provides 2,048 addresses while reducing the reserved address footprint
# compared with the previous /18 proposal.
variable "pod_cidr" {
  type    = string
  default = "100.64.0.0/21"
}

variable "inframgr_service_account" {
  type        = string
  description = "Infrastructure Manager deployment service account"
  default     = "sa-l2comm-inframgr@gcp-prod-edp-edge-509423.iam.gserviceaccount.com"
}
