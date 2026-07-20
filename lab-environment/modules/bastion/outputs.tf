output "bastion_external_ip" {
  description = "Static external IP of the bastion."
  value       = google_compute_address.bastion.address
}

output "bastion_internal_ip" {
  description = "Internal IP of the bastion."
  value       = google_compute_instance.bastion.network_interface[0].network_ip
}

output "bastion_name" {
  description = "Name of the bastion VM."
  value       = google_compute_instance.bastion.name
}

output "ssh_private_key_path" {
  description = "Local path to the generated SSH private key."
  value       = local_file.private_key.filename
}

output "ssh_public_key" {
  description = "Generated SSH public key (OpenSSH format)."
  value       = tls_private_key.bastion.public_key_openssh
}

output "ssh_command" {
  description = "SSH command to connect to the bastion."
  value       = "ssh -i ${local_file.private_key.filename} debian@${google_compute_address.bastion.address}"
}
