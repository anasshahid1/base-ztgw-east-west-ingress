locals {
  # Intercept deployment group: auto-wired from ZTGW or explicit
  intercept_deployment_group = (var.deploy_ztgw
    ? data.external.ztgw[0].result["intercept_deployment_group"]
    : var.intercept_deployment_group
  )

  # Security profile parent scope
  security_profile_parent = (var.security_profile_scope == "project"
    ? "projects/${var.project_id}"
    : "organizations/${var.organization_id}"
  )

  # Resource names with optional overrides
  consumer_fw_policy             = var.consumer_fw_policy != "" ? var.consumer_fw_policy : "${var.deploy_key}-consumer-policy"
  consumer_fw_policy_association = var.consumer_fw_policy_association != "" ? var.consumer_fw_policy_association : "${var.deploy_key}-consumer-policy-association"
  security_profile               = var.security_profile != "" ? var.security_profile : "${var.deploy_key}-custom-intercept-profile"
  security_profile_group         = var.security_profile_group != "" ? var.security_profile_group : "${var.deploy_key}-security-profile-group"
  endpoint_group                 = var.endpoint_group != "" ? var.endpoint_group : "${var.deploy_key}-intercept-endpoint-group"
  endpoint_group_association     = var.endpoint_group_association != "" ? var.endpoint_group_association : "${var.deploy_key}-intercept-endpoint-group-association"
}

# ---------------------------------------------------------------------------
# Provider side: GCP Zero Trust Gateway (via Zscaler REST API)
# ---------------------------------------------------------------------------
# The ZTC Terraform provider does not yet have a native ZTGW resource.
# This external data source calls the Zscaler REST API to deploy the ZTGW
# and returns the intercept_deployment_group for use by consumer resources.
# ---------------------------------------------------------------------------

data "external" "ztgw" {
  count   = var.deploy_ztgw ? 1 : 0
  program = ["bash", "${path.module}/scripts/deploy_ztgw.sh"]

  query = {
    client_id           = var.client_id
    client_secret       = var.client_secret
    vanity_domain       = var.vanity_domain
    cloud               = var.cloud
    login_domain        = var.login_domain
    gateway_name        = var.gateway_name
    gcp_region          = var.gcp_region
    location_name       = var.location_name
    iam_principal_email = var.iam_principal_email
  }
}

# ---------------------------------------------------------------------------
# Consumer side: GCP NSI resources
# ---------------------------------------------------------------------------

data "google_compute_network" "consumer" {
  count   = var.deploy_consumer ? 1 : 0
  name    = var.consumer_network
  project = var.project_id
}

resource "google_compute_network_firewall_policy" "consumer" {
  count       = var.deploy_consumer ? 1 : 0
  name        = local.consumer_fw_policy
  project     = var.project_id
  description = "Consumer firewall policy for Zscaler GCP NSI intercept integration."
}

resource "google_compute_network_firewall_policy_association" "consumer" {
  count             = var.deploy_consumer ? 1 : 0
  name              = local.consumer_fw_policy_association
  project           = var.project_id
  attachment_target = data.google_compute_network.consumer[0].id
  firewall_policy   = google_compute_network_firewall_policy.consumer[0].id
}

resource "google_network_security_intercept_endpoint_group" "consumer" {
  count    = var.deploy_consumer ? 1 : 0
  provider = google-beta

  intercept_endpoint_group_id = local.endpoint_group
  project                     = var.project_id
  location                    = var.location
  intercept_deployment_group  = local.intercept_deployment_group
}

resource "google_network_security_intercept_endpoint_group_association" "consumer" {
  count    = var.deploy_consumer ? 1 : 0
  provider = google-beta

  intercept_endpoint_group_association_id = local.endpoint_group_association
  project                                 = var.project_id
  location                                = var.location
  network                                 = data.google_compute_network.consumer[0].id
  intercept_endpoint_group                = google_network_security_intercept_endpoint_group.consumer[0].id

  depends_on = [
    google_network_security_intercept_endpoint_group.consumer
  ]
}

resource "google_network_security_security_profile" "custom_intercept" {
  count    = var.deploy_consumer ? 1 : 0
  provider = google-beta

  name        = local.security_profile
  parent      = local.security_profile_parent
  location    = var.location
  description = "Custom intercept security profile for Zscaler GCP NSI integration."
  type        = "CUSTOM_INTERCEPT"

  custom_intercept_profile {
    intercept_endpoint_group = google_network_security_intercept_endpoint_group.consumer[0].id
  }

  depends_on = [
    google_network_security_intercept_endpoint_group.consumer
  ]
}

resource "google_network_security_security_profile_group" "consumer" {
  count    = var.deploy_consumer ? 1 : 0
  provider = google-beta

  name                     = local.security_profile_group
  parent                   = local.security_profile_parent
  location                 = var.location
  description              = "Security profile group for Zscaler GCP NSI integration."
  custom_intercept_profile = google_network_security_security_profile.custom_intercept[0].id

  depends_on = [
    google_network_security_security_profile.custom_intercept
  ]
}

resource "google_compute_network_firewall_policy_rule" "ingress_allow" {
  count           = var.deploy_consumer ? 1 : 0
  project         = var.project_id
  firewall_policy = google_compute_network_firewall_policy.consumer[0].name
  priority        = var.allow_ingress_rule_priority
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
    google_compute_network_firewall_policy_association.consumer
  ]
}

resource "google_compute_network_firewall_policy_rule" "ingress_intercept" {
  count                  = var.deploy_consumer ? 1 : 0
  project                = var.project_id
  firewall_policy        = google_compute_network_firewall_policy.consumer[0].name
  priority               = var.ingress_rule_priority
  direction              = "INGRESS"
  action                 = "apply_security_profile_group"
  security_profile_group = "//networksecurity.googleapis.com/${google_network_security_security_profile_group.consumer[0].id}"
  enable_logging         = var.enable_firewall_logging
  description            = "Apply Zscaler GCP NSI security profile group to ingress traffic."

  match {
    src_ip_ranges = var.ingress_source_ranges

    layer4_configs {
      ip_protocol = "all"
    }
  }

  depends_on = [
    google_compute_network_firewall_policy_association.consumer,
    google_network_security_security_profile_group.consumer
  ]
}

resource "google_compute_network_firewall_policy_rule" "egress_intercept" {
  count                  = var.deploy_consumer ? 1 : 0
  project                = var.project_id
  firewall_policy        = google_compute_network_firewall_policy.consumer[0].name
  priority               = var.egress_rule_priority
  direction              = "EGRESS"
  action                 = "apply_security_profile_group"
  security_profile_group = "//networksecurity.googleapis.com/${google_network_security_security_profile_group.consumer[0].id}"
  enable_logging         = var.enable_firewall_logging
  description            = "Apply Zscaler GCP NSI security profile group to egress traffic."

  match {
    dest_ip_ranges = var.egress_destination_ranges

    layer4_configs {
      ip_protocol = "all"
    }
  }

  depends_on = [
    google_compute_network_firewall_policy_association.consumer,
    google_network_security_security_profile_group.consumer
  ]
}
