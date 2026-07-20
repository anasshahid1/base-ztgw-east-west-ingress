# ---------------------------------------------------------------------------
# Ingress VPC — VPC + Subnet + Web Server + External Passthrough NLB
# ---------------------------------------------------------------------------
# This VPC is for testing the ingress use case where an external passthrough
# load balancer sends packets first to GCP ZTGW (via NSI) and then to the
# backend web server.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# VPC + Subnet
# ---------------------------------------------------------------------------

resource "google_compute_network" "ingress" {
  name                                      = var.vpc_name
  project                                   = var.project_id
  auto_create_subnetworks                   = false
  routing_mode                              = "GLOBAL"
  network_firewall_policy_enforcement_order = "BEFORE_CLASSIC_FIREWALL"
}

resource "google_compute_subnetwork" "ingress" {
  name          = "${var.vpc_name}-subnet"
  project       = var.project_id
  network       = google_compute_network.ingress.id
  region        = var.region
  ip_cidr_range = var.subnet_cidr
}

# ---------------------------------------------------------------------------
# Firewall rules
# ---------------------------------------------------------------------------

# Allow internal
resource "google_compute_firewall" "ingress_allow_internal" {
  name    = "${var.vpc_name}-allow-internal"
  project = var.project_id
  network = google_compute_network.ingress.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  source_ranges = [var.vpc_cidr]
  priority      = 1000
}

# Allow health check probes
resource "google_compute_firewall" "ingress_allow_health_checks" {
  name    = "${var.vpc_name}-allow-health-checks"
  project = var.project_id
  network = google_compute_network.ingress.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["web-server"]
  priority      = 950
}

# Allow external HTTP to web server (for the NLB)
resource "google_compute_firewall" "ingress_allow_http" {
  name    = "${var.vpc_name}-allow-http"
  project = var.project_id
  network = google_compute_network.ingress.name

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web-server"]
  priority      = 900
}

# Allow SSH from bastion tag
resource "google_compute_firewall" "ingress_allow_ssh_bastion" {
  name    = "${var.vpc_name}-allow-ssh-bastion"
  project = var.project_id
  network = google_compute_network.ingress.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_tags = ["bastion"]
  priority    = 900
}

# Allow IAP SSH
resource "google_compute_firewall" "ingress_allow_iap" {
  name    = "${var.vpc_name}-allow-iap"
  project = var.project_id
  network = google_compute_network.ingress.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  priority      = 800
}

# ---------------------------------------------------------------------------
# Web Server VM
# ---------------------------------------------------------------------------

resource "google_compute_instance" "web_server" {
  name         = "${var.vpc_name}-web-server"
  project      = var.project_id
  zone         = var.zone
  machine_type = var.machine_type

  tags = ["web-server"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 20
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.ingress.self_link
    # No public IP — traffic comes through the NLB
  }

  metadata = {
    ssh-keys = var.ssh_public_key != "" ? "debian:${var.ssh_public_key}" : null
  }

  metadata_startup_script = <<-SCRIPT
    #!/bin/bash
    set -e
    apt-get update -y
    apt-get install -y nginx
    HOSTNAME=$(hostname)
    IP=$(hostname -I | awk '{print $1}')
    cat > /var/www/html/index.html <<EOF
    <!DOCTYPE html>
    <html>
    <head><title>Ingress Web Server</title></head>
    <body>
      <h1>Ingress VPC Web Server</h1>
      <p>Hostname: $HOSTNAME</p>
      <p>Internal IP: $IP</p>
      <p>Traffic path: Client -> External NLB -> ZTGW (NSI) -> This Server</p>
    </body>
    </html>
    EOF
    systemctl enable nginx
    systemctl restart nginx
  SCRIPT

  service_account {
    scopes = ["cloud-platform"]
  }

  allow_stopping_for_update = true
}

# ---------------------------------------------------------------------------
# Instance Group (unmanaged, for the NLB backend)
# ---------------------------------------------------------------------------

resource "google_compute_instance_group" "web_server" {
  name    = "${var.vpc_name}-web-ig"
  project = var.project_id
  zone    = var.zone
  network = google_compute_network.ingress.self_link

  instances = [
    google_compute_instance.web_server.self_link
  ]

  named_port {
    name = "http"
    port = 80
  }
}

# ---------------------------------------------------------------------------
# External Passthrough Network Load Balancer (L4)
# ---------------------------------------------------------------------------

# Regional health check (required for external passthrough NLB)
resource "google_compute_region_health_check" "web_server" {
  name    = "${var.vpc_name}-health-check"
  project = var.project_id
  region  = var.region

  tcp_health_check {
    port = 80
  }

  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3
}

# Regional backend service (for external passthrough NLB)
resource "google_compute_region_backend_service" "web_server" {
  name                  = "${var.vpc_name}-backend"
  project               = var.project_id
  region                = var.region
  protocol              = "TCP"
  load_balancing_scheme = "EXTERNAL"
  health_checks         = [google_compute_region_health_check.web_server.id]

  backend {
    group          = google_compute_instance_group.web_server.self_link
    balancing_mode = "CONNECTION"
  }
}

# Static external IP for the NLB
resource "google_compute_address" "nlb" {
  name         = "${var.vpc_name}-nlb-ip"
  project      = var.project_id
  region       = var.region
  address_type = "EXTERNAL"
}

# Forwarding rule — the actual external passthrough NLB
resource "google_compute_forwarding_rule" "nlb" {
  name                  = "${var.vpc_name}-nlb"
  project               = var.project_id
  region                = var.region
  ip_address            = google_compute_address.nlb.address
  ip_protocol           = "TCP"
  port_range            = "80"
  load_balancing_scheme = "EXTERNAL"
  backend_service       = google_compute_region_backend_service.web_server.id
}
