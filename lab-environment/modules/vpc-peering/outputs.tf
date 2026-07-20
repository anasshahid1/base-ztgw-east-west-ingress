output "peering_a_to_b" {
  description = "Name of the A-to-B peering."
  value       = google_compute_network_peering.a_to_b.name
}

output "peering_b_to_a" {
  description = "Name of the B-to-A peering."
  value       = google_compute_network_peering.b_to_a.name
}

output "peering_a_to_b_state" {
  description = "State of the A-to-B peering."
  value       = google_compute_network_peering.a_to_b.state
}

output "peering_b_to_a_state" {
  description = "State of the B-to-A peering."
  value       = google_compute_network_peering.b_to_a.state
}
