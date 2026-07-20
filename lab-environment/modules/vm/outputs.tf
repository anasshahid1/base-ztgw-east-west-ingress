output "instance_id" {
  description = "ID of the compute instance."
  value       = google_compute_instance.this.id
}

output "instance_name" {
  description = "Name of the compute instance."
  value       = google_compute_instance.this.name
}

output "instance_self_link" {
  description = "Self-link of the compute instance."
  value       = google_compute_instance.this.self_link
}

output "internal_ip" {
  description = "Internal IP address of the VM."
  value       = google_compute_instance.this.network_interface[0].network_ip
}

output "external_ip" {
  description = "External IP address (if assigned)."
  value       = try(google_compute_instance.this.network_interface[0].access_config[0].nat_ip, null)
}

output "zone" {
  description = "Zone where the VM is deployed."
  value       = google_compute_instance.this.zone
}
