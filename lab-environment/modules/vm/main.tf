# ---------------------------------------------------------------------------
# Compute VM running nginx via startup script
# ---------------------------------------------------------------------------

resource "google_compute_instance" "this" {
  name         = var.vm_name
  project      = var.project_id
  zone         = var.zone
  machine_type = var.machine_type

  tags = var.network_tags

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 20
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = var.subnet_self_link

    # Only assign external IP if requested
    dynamic "access_config" {
      for_each = var.assign_public_ip ? [1] : []
      content {
        // Ephemeral external IP
      }
    }
  }

  metadata = {
    ssh-keys               = var.ssh_public_key != "" ? "debian:${var.ssh_public_key}" : null
    enable-oslogin         = var.ssh_public_key == "" ? "TRUE" : null
    startup-script         = var.startup_script != "" ? var.startup_script : local.default_nginx_startup
    block-project-ssh-keys = false
  }

  service_account {
    scopes = ["cloud-platform"]
  }

  allow_stopping_for_update = true

  lifecycle {
    ignore_changes = [metadata["ssh-keys"]]
  }
}

locals {
  default_nginx_startup = <<-SCRIPT
    #!/bin/bash
    set -e
    apt-get update -y
    apt-get install -y nginx
    HOSTNAME=$(hostname)
    IP=$(hostname -I | awk '{print $1}')
    cat > /var/www/html/index.html <<EOF
    <!DOCTYPE html>
    <html>
    <head><title>$HOSTNAME</title></head>
    <body>
      <h1>Hello from $HOSTNAME</h1>
      <p>Internal IP: $IP</p>
      <p>VM Name: ${var.vm_name}</p>
    </body>
    </html>
    EOF
    systemctl enable nginx
    systemctl restart nginx
  SCRIPT
}
