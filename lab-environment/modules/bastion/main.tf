# ---------------------------------------------------------------------------
# Bastion Host — SSH key generation + static IP + VM
# ---------------------------------------------------------------------------

# Generate SSH key pair
resource "tls_private_key" "bastion" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save private key to local file
resource "local_file" "private_key" {
  content         = tls_private_key.bastion.private_key_pem
  filename        = "${path.root}/lab-key.pem"
  file_permission = "0600"
}

# Static external IP for the bastion
resource "google_compute_address" "bastion" {
  name         = "${var.bastion_name}-ip"
  project      = var.project_id
  region       = var.region
  address_type = "EXTERNAL"
}

# Bastion VM
resource "google_compute_instance" "bastion" {
  name         = var.bastion_name
  project      = var.project_id
  zone         = var.zone
  machine_type = var.machine_type

  tags = ["bastion"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 20
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = var.subnet_self_link

    access_config {
      nat_ip = google_compute_address.bastion.address
    }
  }

  metadata = {
    ssh-keys               = "debian:${tls_private_key.bastion.public_key_openssh}"
    block-project-ssh-keys = "false"
  }

  metadata_startup_script = <<-SCRIPT
    #!/bin/bash
    set -e
    apt-get update -y
    apt-get install -y curl wget net-tools dnsutils traceroute
  SCRIPT

  service_account {
    scopes = ["cloud-platform"]
  }

  allow_stopping_for_update = true
}
