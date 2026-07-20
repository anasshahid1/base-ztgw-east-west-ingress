variable "vpc_name" {
  description = "Name of the ingress VPC."
  type        = string
  default     = "vpc-ingress"
}

variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "GCP region."
  type        = string
}

variable "zone" {
  description = "GCP zone for the web server VM."
  type        = string
}

variable "vpc_cidr" {
  description = "Full VPC CIDR."
  type        = string
  default     = "172.16.0.0/16"
}

variable "subnet_cidr" {
  description = "Subnet CIDR range."
  type        = string
  default     = "172.16.1.0/24"
}

variable "machine_type" {
  description = "Machine type for the web server VM."
  type        = string
  default     = "e2-small"
}

variable "ssh_public_key" {
  description = "SSH public key to inject into the web server. Leave empty for OS Login."
  type        = string
  default     = ""
}
