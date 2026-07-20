# ---------------------------------------------------------------------------
# NSI Consumer Side — Firewall Policy, Endpoint Group, Security Profile
# ---------------------------------------------------------------------------
# Connects a consumer VPC to the Zscaler ZTGW via GCP Network Security
# Intercept (NSI). Default scope is "project" for the security profile.
# ---------------------------------------------------------------------------

locals {
  security_profile_parent = (var.security_profile_scope == "project"
    ? "projects/${var.project_id}"
    : "organizations/${var.organization_id}"
  )

  # Resource names with prefix
  fw_policy_name              = "${var.name_prefix}-consumer-policy"
  fw_policy_assoc_name        = "${var.name_prefix}-consumer-policy-association"
  security_profile_name       = "${var.name_prefix}-custom-intercept-profile"
  security_profile_group_name = "${var.name_prefix}-security-profile-group"
  endpoint_group_name         = "${var.name_prefix}-intercept-endpoint-group"
  endpoint_group_assoc_name   = "${var.name_prefix}-intercept-endpoint-group-association"
}

# ---------------------------------------------------------------------------
# Global Network Firewall Policy
# ---------------------------------------------------------------------------

resource "google_compute_network_firewall_policy" "this" {
  name        = local.fw_policy_name
  project     = var.project_id
  description = "Consumer firewall policy for Zscaler GCP NSI intercept — ${var.name_prefix}."
}

resource "google_compute_network_firewall_policy_association" "this" {
  name              = local.fw_policy_assoc_name
  project           = var.project_id
  attachment_target = var.network_id
  firewall_policy   = google_compute_network_firewall_policy.this.id
}

# ---------------------------------------------------------------------------
# Intercept Endpoint Group + Association
# ---------------------------------------------------------------------------

resource "google_network_security_intercept_endpoint_group" "this" {
  provider = google-beta

  intercept_endpoint_group_id = local.endpoint_group_name
  project                     = var.project_id
  location                    = var.location
  intercept_deployment_group  = var.intercept_deployment_group
}

resource "google_network_security_intercept_endpoint_group_association" "this" {
  provider = google-beta

  intercept_endpoint_group_association_id = local.endpoint_group_assoc_name
  project                                 = var.project_id
  location                                = var.location
  network                                 = var.network_id
  intercept_endpoint_group                = google_network_security_intercept_endpoint_group.this.id

  depends_on = [
    google_network_security_intercept_endpoint_group.this
  ]
}

# ---------------------------------------------------------------------------
# Security Profile (Custom Intercept) + Security Profile Group
# ---------------------------------------------------------------------------

resource "google_network_security_security_profile" "this" {
  provider = google-beta

  name        = local.security_profile_name
  parent      = local.security_profile_parent
  location    = var.location
  description = "Custom intercept security profile — ${var.name_prefix}."
  type        = "CUSTOM_INTERCEPT"

  custom_intercept_profile {
    intercept_endpoint_group = google_network_security_intercept_endpoint_group.this.id
  }

  depends_on = [
    google_network_security_intercept_endpoint_group.this
  ]
}

resource "google_network_security_security_profile_group" "this" {
  provider = google-beta

  name                     = local.security_profile_group_name
  parent                   = local.security_profile_parent
  location                 = var.location
  description              = "Security profile group — ${var.name_prefix}."
  custom_intercept_profile = google_network_security_security_profile.this.id

  depends_on = [
    google_network_security_security_profile.this
  ]
}

# ---------------------------------------------------------------------------
# Firewall Policy Rules — Intercept
# ---------------------------------------------------------------------------

# Allow trusted ingress (bypasses intercept)
resource "google_compute_network_firewall_policy_rule" "allow_ingress" {
  project         = var.project_id
  firewall_policy = google_compute_network_firewall_policy.this.name
  priority        = var.allow_ingress_priority
  direction       = "INGRESS"
  action          = "allow"
  enable_logging  = var.enable_firewall_logging
  description     = "Allow trusted ingress sources without Zscaler inspection."

  match {
    src_ip_ranges = var.allow_ingress_source_ranges

    layer4_configs {
      ip_protocol = "all"
    }
  }

  depends_on = [
    google_compute_network_firewall_policy_association.this
  ]
}

# Ingress intercept rule
resource "google_compute_network_firewall_policy_rule" "ingress_intercept" {
  project                = var.project_id
  firewall_policy        = google_compute_network_firewall_policy.this.name
  priority               = var.ingress_intercept_priority
  direction              = "INGRESS"
  action                 = "apply_security_profile_group"
  security_profile_group = "//networksecurity.googleapis.com/${google_network_security_security_profile_group.this.id}"
  enable_logging         = var.enable_firewall_logging
  description            = "Apply Zscaler NSI security profile group to ingress traffic."

  match {
    src_ip_ranges = var.ingress_source_ranges

    layer4_configs {
      ip_protocol = "all"
    }
  }

  depends_on = [
    google_compute_network_firewall_policy_association.this,
    google_network_security_security_profile_group.this
  ]
}

# Egress intercept rule
resource "google_compute_network_firewall_policy_rule" "egress_intercept" {
  project                = var.project_id
  firewall_policy        = google_compute_network_firewall_policy.this.name
  priority               = var.egress_intercept_priority
  direction              = "EGRESS"
  action                 = "apply_security_profile_group"
  security_profile_group = "//networksecurity.googleapis.com/${google_network_security_security_profile_group.this.id}"
  enable_logging         = var.enable_firewall_logging
  description            = "Apply Zscaler NSI security profile group to egress traffic."

  match {
    dest_ip_ranges = var.egress_destination_ranges

    layer4_configs {
      ip_protocol = "all"
    }
  }

  depends_on = [
    google_compute_network_firewall_policy_association.this,
    google_network_security_security_profile_group.this
  ]
}
