# ---------------------------------------------------------------------------
# Deployment mode
# ---------------------------------------------------------------------------

variable "deploy_ztgw" {
  description = "Deploy a new GCP ZTGW. Set to false when pointing to an existing ZTGW."
  type        = bool
  default     = true
}

variable "deploy_consumer" {
  description = "Deploy consumer-side GCP NSI resources. Set to false for ZTGW-only mode."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Zscaler OneAPI authentication (required when deploy_ztgw = true)
# ---------------------------------------------------------------------------

variable "client_id" {
  description = "Zscaler OneAPI OAuth2 client ID."
  type        = string
}

variable "client_secret" {
  description = "Zscaler OneAPI OAuth2 client secret."
  type        = string
  sensitive   = true
}

variable "vanity_domain" {
  description = "Zscaler vanity domain (e.g. 'acme' -> acme.zslogin.net)."
  type        = string
}

variable "cloud" {
  description = "Zscaler cloud name: zscaler, zscalerone, zscalertwo, zscalerthree, zscalerbeta."
  type        = string
  default     = "zscaler"
}

variable "login_domain" {
  description = <<-EOT
    Override OAuth2 login domain. Auto-derived from cloud if empty.
    Use 'zslogin.net' for tenants that authenticate through production login
    but use a different backend cloud.
    EOT
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# GCP ZTGW deployment parameters (used when deploy_ztgw = true)
# ---------------------------------------------------------------------------

variable "gateway_name" {
  description = "Name for the GCP Zero Trust Gateway."
  type        = string
  default     = "gcp-ztgw-demo"
}

variable "gcp_region" {
  description = <<-EOT
    GCP region to deploy the ZTGW. Supported regions:
      us-central1, us-east1, us-east4, us-east5,
      us-west1, us-west2, us-west3, us-west4,
      asia-south1, asia-south2, asia-southeast1,
      australia-southeast1,
      europe-west1, europe-west3, europe-west4
  EOT
  type        = string
  default     = "us-central1"
}

variable "location_name" {
  description = "Location name for the ZTGW (auto-created in Zscaler)."
  type        = string
  default     = "gcp-ztgw-demo-location"
}

variable "iam_principal_email" {
  description = "IAM principal email for the GCP ZTGW."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# Consumer-side intercept deployment group
# ---------------------------------------------------------------------------

variable "intercept_deployment_group" {
  description = "Existing intercept deployment group resource ID. Required when deploy_ztgw = false. When deploy_ztgw = true, this value is auto-wired from the ZTGW output."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# Security profile scope
# ---------------------------------------------------------------------------

variable "security_profile_scope" {
  description = "Scope for security profile and security profile group resources: 'organization' or 'project'."
  type        = string
  default     = "project"

  validation {
    condition     = contains(["organization", "project"], var.security_profile_scope)
    error_message = "security_profile_scope must be 'organization' or 'project'."
  }
}

# ---------------------------------------------------------------------------
# GCP consumer project parameters
# ---------------------------------------------------------------------------

variable "project_id" {
  description = "GCP project where consumer VPC and endpoint group are deployed. Required when deploy_consumer = true."
  type        = string
  default     = ""
}

variable "organization_id" {
  description = "GCP organization ID (required when security_profile_scope = 'organization')."
  type        = string
  default     = ""
}

variable "billing_project_id" {
  description = "Billing/quota project for organization-level Network Security resources. Usually the same as project_id. Required when deploy_consumer = true."
  type        = string
  default     = ""
}

variable "region" {
  description = "Default provider region for GCP resources."
  type        = string
  default     = "us-central1"
}

variable "location" {
  description = "Location for NSI resources. Typically 'global'."
  type        = string
  default     = "global"
}

variable "consumer_network" {
  description = "Existing consumer VPC network name. Required when deploy_consumer = true."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# Naming prefix
# ---------------------------------------------------------------------------

variable "deploy_key" {
  description = "Naming prefix for all consumer-side resources."
  type        = string
  default     = "ztgw-nsi"
}

# ---------------------------------------------------------------------------
# Optional resource name overrides
# ---------------------------------------------------------------------------

variable "consumer_fw_policy" {
  description = "Override for the global network firewall policy name."
  type        = string
  default     = ""
}

variable "consumer_fw_policy_association" {
  description = "Override for the firewall policy association name."
  type        = string
  default     = ""
}

variable "security_profile" {
  description = "Override for the custom intercept security profile name."
  type        = string
  default     = ""
}

variable "security_profile_group" {
  description = "Override for the security profile group name."
  type        = string
  default     = ""
}

variable "endpoint_group" {
  description = "Override for the intercept endpoint group name."
  type        = string
  default     = ""
}

variable "endpoint_group_association" {
  description = "Override for the intercept endpoint group association name."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# Firewall policy rules
# ---------------------------------------------------------------------------

variable "ingress_rule_priority" {
  description = "Priority for the ingress intercept firewall rule."
  type        = number
  default     = 100
}

variable "allow_ingress_rule_priority" {
  description = "Priority for the allow-list ingress rule (evaluated before the intercept rule)."
  type        = number
  default     = 90
}

variable "egress_rule_priority" {
  description = "Priority for the egress intercept firewall rule."
  type        = number
  default     = 101
}

variable "ingress_source_ranges" {
  description = "Source CIDR ranges for inbound traffic inspection."
  type        = list(string)
  default     = ["10.1.0.0/16"]
}

variable "allow_ingress_source_ranges" {
  description = "Source CIDR ranges allowed without Zscaler inspection."
  type        = list(string)
  default     = ["34.117.59.81/32"]
}

variable "egress_destination_ranges" {
  description = "Destination CIDR ranges for outbound traffic inspection."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_firewall_logging" {
  description = "Enable logging on firewall policy rules."
  type        = bool
  default     = true
}
