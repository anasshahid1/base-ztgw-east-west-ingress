# ---------------------------------------------------------------------------
# VPC + Subnet + Basic Firewall Rules
# ---------------------------------------------------------------------------

resource "google_compute_network" "this" {
  name                                      = var.vpc_name
  project                                   = var.project_id
  auto_create_subnetworks                   = false
  routing_mode                              = "GLOBAL"
  network_firewall_policy_enforcement_order = "BEFORE_CLASSIC_FIREWALL"
}

resource "google_compute_subnetwork" "this" {
  name          = "${var.vpc_name}-subnet"
  project       = var.project_id
  network       = google_compute_network.this.id
  region        = var.region
  ip_cidr_range = var.subnet_cidr
}

# ---------------------------------------------------------------------------
# Firewall rules
# ---------------------------------------------------------------------------

# Allow internal traffic within the VPC CIDR
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.vpc_name}-allow-internal"
  project = var.project_id
  network = google_compute_network.this.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  source_ranges = [var.vpc_cidr]
  priority      = 1000
}

# Allow SSH from bastion network tag
resource "google_compute_firewall" "allow_ssh_from_bastion" {
  name    = "${var.vpc_name}-allow-ssh-bastion"
  project = var.project_id
  network = google_compute_network.this.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_tags = ["bastion"]
  priority    = 900
}

# Allow GCP health check probes (for load balancers)
resource "google_compute_firewall" "allow_health_checks" {
  name    = "${var.vpc_name}-allow-health-checks"
  project = var.project_id
  network = google_compute_network.this.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  # GCP health check probe ranges
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  priority      = 950
}

# Allow IAP for SSH (so bastion can be reached via IAP tunnel too)
resource "google_compute_firewall" "allow_iap" {
  name    = "${var.vpc_name}-allow-iap"
  project = var.project_id
  network = google_compute_network.this.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # IAP forwarding range
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["bastion"]
  priority      = 800
}

# Allow peered VPC CIDR (only if peer_cidr is provided)
resource "google_compute_firewall" "allow_peer" {
  count   = var.peer_cidr != "" ? 1 : 0
  name    = "${var.vpc_name}-allow-peer"
  project = var.project_id
  network = google_compute_network.this.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  source_ranges = [var.peer_cidr]
  priority      = 1000
}
