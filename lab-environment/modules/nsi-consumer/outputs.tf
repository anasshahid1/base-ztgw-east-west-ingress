output "firewall_policy_id" {
  description = "ID of the consumer firewall policy."
  value       = google_compute_network_firewall_policy.this.id
}

output "firewall_policy_name" {
  description = "Name of the consumer firewall policy."
  value       = google_compute_network_firewall_policy.this.name
}

output "endpoint_group_id" {
  description = "ID of the intercept endpoint group."
  value       = google_network_security_intercept_endpoint_group.this.id
}

output "endpoint_group_association_id" {
  description = "ID of the intercept endpoint group association."
  value       = google_network_security_intercept_endpoint_group_association.this.id
}

output "security_profile_id" {
  description = "ID of the custom intercept security profile."
  value       = google_network_security_security_profile.this.id
}

output "security_profile_group_id" {
  description = "ID of the security profile group."
  value       = google_network_security_security_profile_group.this.id
}
