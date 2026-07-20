variable "bastion_name" {
  description = "Name for the bastion VM."
  type        = string
  default     = "bastion"
}

variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "GCP region for the static IP."
  type        = string
}

variable "zone" {
  description = "GCP zone for the bastion VM."
  type        = string
}

variable "machine_type" {
  description = "Machine type for the bastion."
  type        = string
  default     = "e2-small"
}

variable "subnet_self_link" {
  description = "Self-link of the subnet to place the bastion in."
  type        = string
}
