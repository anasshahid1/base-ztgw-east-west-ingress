variable "vm_name" {
  description = "Name of the VM instance."
  type        = string
}

variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "zone" {
  description = "GCP zone (e.g. us-central1-a)."
  type        = string
}

variable "machine_type" {
  description = "Machine type for the VM."
  type        = string
  default     = "e2-small"
}

variable "subnet_self_link" {
  description = "Self-link of the subnet to attach the VM to."
  type        = string
}

variable "network_tags" {
  description = "Network tags for the VM."
  type        = list(string)
  default     = ["nginx"]
}

variable "assign_public_ip" {
  description = "Whether to assign an ephemeral public IP."
  type        = bool
  default     = false
}

variable "ssh_public_key" {
  description = "SSH public key to inject into the VM. Leave empty for OS Login."
  type        = string
  default     = ""
}

variable "startup_script" {
  description = "Custom startup script. Leave empty for default nginx install."
  type        = string
  default     = ""
}
