variable "vpc_a_name" {
  description = "Name of VPC A."
  type        = string
}

variable "vpc_a_self_link" {
  description = "Self-link of VPC A."
  type        = string
}

variable "vpc_b_name" {
  description = "Name of VPC B."
  type        = string
}

variable "vpc_b_self_link" {
  description = "Self-link of VPC B."
  type        = string
}

variable "export_custom_routes" {
  description = "Export custom routes to peer."
  type        = bool
  default     = true
}

variable "import_custom_routes" {
  description = "Import custom routes from peer."
  type        = bool
  default     = true
}
