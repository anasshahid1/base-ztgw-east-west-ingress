# =============================================================================
# GCP ZTGW Lab Environment — Variables
# =============================================================================

# ---------------------------------------------------------------------------
# GCP Project / Region
# ---------------------------------------------------------------------------

variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "GCP region for all resources."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone for VMs."
  type        = string
  default     = "us-central1-a"
}

variable "organization_id" {
  description = "GCP organization ID. Required when security_profile_scope = 'organization'."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# Lab Scenario Toggles
# ---------------------------------------------------------------------------

variable "deploy_east_west" {
  description = "Deploy east-west scenario: two VPCs, nginx VMs, bastion, VPC peering."
  type        = bool
  default     = true
}

variable "deploy_ingress" {
  description = "Deploy ingress scenario: one VPC, web server, external passthrough NLB."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Naming
# ---------------------------------------------------------------------------

variable "deploy_key" {
  description = "Naming prefix for all resources."
  type        = string
  default     = "ztgw-lab"
}

# ---------------------------------------------------------------------------
# VM Configuration
# ---------------------------------------------------------------------------

variable "machine_type" {
  description = "Machine type for all VMs (bastion, nginx, web server)."
  type        = string
  default     = "e2-small"
}

# ---------------------------------------------------------------------------
# VPC-A (East-West)
# ---------------------------------------------------------------------------

variable "vpc_a_name" {
  description = "Name of the first east-west VPC."
  type        = string
  default     = "vpc-ew-a"
}

variable "vpc_a_cidr" {
  description = "CIDR for VPC-A."
  type        = string
  default     = "10.1.0.0/16"
}

variable "vpc_a_subnet_cidr" {
  description = "Subnet CIDR for VPC-A."
  type        = string
  default     = "10.1.1.0/24"
}

# ---------------------------------------------------------------------------
# VPC-B (East-West)
# ---------------------------------------------------------------------------

variable "vpc_b_name" {
  description = "Name of the second east-west VPC."
  type        = string
  default     = "vpc-ew-b"
}

variable "vpc_b_cidr" {
  description = "CIDR for VPC-B."
  type        = string
  default     = "192.168.0.0/16"
}

variable "vpc_b_subnet_cidr" {
  description = "Subnet CIDR for VPC-B."
  type        = string
  default     = "192.168.1.0/24"
}

# ---------------------------------------------------------------------------
# Ingress VPC
# ---------------------------------------------------------------------------

variable "ingress_vpc_name" {
  description = "Name of the ingress VPC."
  type        = string
  default     = "vpc-ingress"
}

variable "ingress_vpc_cidr" {
  description = "CIDR for the ingress VPC."
  type        = string
  default     = "172.16.0.0/16"
}

variable "ingress_vpc_subnet_cidr" {
  description = "Subnet CIDR for the ingress VPC."
  type        = string
  default     = "172.16.1.0/24"
}

# ---------------------------------------------------------------------------
# NSI Configuration
# ---------------------------------------------------------------------------

variable "deploy_nsi" {
  description = "Deploy NSI consumer resources. Set to false to create VPCs/VMs only without NSI. Requires intercept_deployment_group when true."
  type        = bool
  default     = false
}

variable "intercept_deployment_group" {
  description = "Intercept deployment group resource ID from the ZTGW. Required when deploy_nsi = true."
  type        = string
  default     = ""
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

variable "nsi_location" {
  description = "Location for NSI resources. Typically 'global'."
  type        = string
  default     = "global"
}
