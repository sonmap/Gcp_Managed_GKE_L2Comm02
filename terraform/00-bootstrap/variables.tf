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

variable "region" {
  type    = string
  default = "asia-northeast3"
}

variable "admin_user" {
  type    = string
  default = "admin@sonmap.net"
}

variable "vm_service_account" {
  type    = string
  default = "620081195575-compute@developer.gserviceaccount.com"
}

variable "tfstate_bucket_name" {
  type    = string
  default = "gcp-prod-edp-edge-509423-l2comm-tfstate"
}
