variable "vpc_name" {
  description = "Name of the VPC network."
  type        = string
}

variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "GCP region for the subnet."
  type        = string
}

variable "vpc_cidr" {
  description = "Full VPC CIDR (e.g. 10.1.0.0/16). Used for internal firewall rules."
  type        = string
}

variable "subnet_cidr" {
  description = "Subnet CIDR range (e.g. 10.1.1.0/24)."
  type        = string
}

variable "peer_cidr" {
  description = "CIDR of the peered VPC. Leave empty if no peering. Used to allow traffic from peer."
  type        = string
  default     = ""
}
