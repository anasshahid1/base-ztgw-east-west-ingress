variable "name_prefix" {
  description = "Naming prefix for all NSI consumer resources."
  type        = string
}

variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "organization_id" {
  description = "GCP organization ID. Required when security_profile_scope = 'organization'."
  type        = string
  default     = ""
}

variable "location" {
  description = "Location for NSI resources (typically 'global')."
  type        = string
  default     = "global"
}

variable "network_id" {
  description = "Self-link / ID of the consumer VPC network."
  type        = string
}

variable "intercept_deployment_group" {
  description = "Intercept deployment group resource ID from the ZTGW."
  type        = string
}

variable "security_profile_scope" {
  description = "Scope for security profile: 'project' (default) or 'organization'."
  type        = string
  default     = "project"

  validation {
    condition     = contains(["organization", "project"], var.security_profile_scope)
    error_message = "security_profile_scope must be 'organization' or 'project'."
  }
}

# ---------------------------------------------------------------------------
# Firewall rule configuration
# ---------------------------------------------------------------------------

variable "allow_ingress_priority" {
  description = "Priority for the allow-list ingress rule."
  type        = number
  default     = 90
}

variable "ingress_intercept_priority" {
  description = "Priority for the ingress intercept rule."
  type        = number
  default     = 100
}

variable "egress_intercept_priority" {
  description = "Priority for the egress intercept rule."
  type        = number
  default     = 101
}

variable "allow_ingress_source_ranges" {
  description = "Source CIDRs allowed without Zscaler inspection."
  type        = list(string)
  default     = ["35.235.240.0/20"]
}

variable "ingress_source_ranges" {
  description = "Source CIDRs for inbound traffic inspection."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "egress_destination_ranges" {
  description = "Destination CIDRs for outbound traffic inspection."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_firewall_logging" {
  description = "Enable logging on firewall policy rules."
  type        = bool
  default     = true
}
