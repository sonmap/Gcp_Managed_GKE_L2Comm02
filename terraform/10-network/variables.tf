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

# Final Node primary range.
# /24 provides 256 addresses and leaves comfortable headroom for
# Autopilot-managed nodes and future workload growth.
variable "node_cidr" {
  type    = string
  default = "10.252.1.0/24"
}

variable "pod_range_name" {
  type    = string
  default = "pods-prod-edp-l2comm-an3"
}

# RFC6598 shared address space used for Pods to preserve scarce RFC1918 space.
# /19 provides 8,192 addresses.
variable "pod_cidr" {
  type    = string
  default = "100.64.128.0/19"
}

variable "inframgr_service_account" {
  type        = string
  description = "Infrastructure Manager deployment service account"
  default     = "sa-l2comm-inframgr@gcp-prod-edp-edge-509423.iam.gserviceaccount.com"
}
