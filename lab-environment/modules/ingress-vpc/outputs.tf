output "network_id" {
  description = "ID of the ingress VPC."
  value       = google_compute_network.ingress.id
}

output "network_name" {
  description = "Name of the ingress VPC."
  value       = google_compute_network.ingress.name
}

output "network_self_link" {
  description = "Self-link of the ingress VPC."
  value       = google_compute_network.ingress.self_link
}

output "subnet_self_link" {
  description = "Self-link of the ingress subnet."
  value       = google_compute_subnetwork.ingress.self_link
}

output "web_server_internal_ip" {
  description = "Internal IP of the web server."
  value       = google_compute_instance.web_server.network_interface[0].network_ip
}

output "web_server_name" {
  description = "Name of the web server VM."
  value       = google_compute_instance.web_server.name
}

output "nlb_external_ip" {
  description = "External IP of the passthrough NLB."
  value       = google_compute_address.nlb.address
}

output "nlb_forwarding_rule" {
  description = "Name of the NLB forwarding rule."
  value       = google_compute_forwarding_rule.nlb.name
}
