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
VMHOST=$$(hostname)
VMIP=$$(hostname -I | awk '{print $$1}')
cat > /etc/nginx/sites-available/default <<'NGINXCONF'
server {
    listen 80 default_server;
    root /var/www/html;
    index index.html;
    location /ip {
        add_header Content-Type text/plain;
        add_header Access-Control-Allow-Origin *;
        return 200 $remote_addr;
    }
    location / {
        try_files $uri $uri/ =404;
    }
}
NGINXCONF
cat > /var/www/html/index.html <<HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>$$VMHOST - ZTGW Lab</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#0f1923;color:#e0e6ed;font-family:'Segoe UI',system-ui,-apple-system,sans-serif;min-height:100vh;display:flex;align-items:center;justify-content:center}
.card{background:#1a2733;border-radius:16px;width:520px;max-width:95vw;overflow:hidden;box-shadow:0 20px 60px rgba(0,0,0,0.5)}
.header{background:linear-gradient(135deg,#047857,#10b981);padding:28px 32px}
.header h1{font-size:14px;text-transform:uppercase;letter-spacing:2px;color:rgba(255,255,255,0.8);font-weight:500}
.header h2{font-size:22px;color:#fff;margin-top:6px;font-weight:600}
.info{padding:24px 32px}
.row{display:flex;justify-content:space-between;align-items:center;padding:14px 0;border-bottom:1px solid #253442}
.row:last-child{border-bottom:none}
.label{font-size:11px;text-transform:uppercase;letter-spacing:1.5px;color:#7a8fa0;font-weight:600}
.value{font-size:16px;font-family:'SF Mono','Cascadia Code','Consolas',monospace;color:#34d399;font-weight:500}
.divider{height:1px;background:#253442}
.source-ip{padding:24px 32px;text-align:center}
.source-ip .label{margin-bottom:10px}
.source-ip .value{font-size:28px;color:#6ee7b7;transition:all 0.3s ease}
.source-ip .value.loading{color:#475569;font-size:16px}
.path{padding:24px 32px;background:#151f2a;border-radius:0 0 16px 16px}
.path .label{margin-bottom:16px}
.step{display:flex;align-items:center;gap:12px;padding:6px 0}
.dot{width:10px;height:10px;border-radius:50%;background:#10b981;flex-shrink:0}
.dot.here{background:#6ee7b7;box-shadow:0 0 12px #6ee7b7}
.ln{width:10px;display:flex;justify-content:center;flex-shrink:0}
.ln::after{content:'';width:2px;height:20px;background:#334155;display:block}
.step-text{font-size:14px;color:#94a3b8}
.step-text.here{color:#6ee7b7;font-weight:600}
.badge{display:inline-block;background:rgba(16,185,129,0.12);color:#34d399;font-size:10px;padding:2px 8px;border-radius:4px;margin-left:8px}
</style>
</head>
<body>
<div class="card">
<div class="header"><h1>Zscaler GCP ZTGW Lab</h1><h2>Ingress Web Server</h2></div>
<div class="info">
<div class="row"><span class="label">Hostname</span><span class="value">$$VMHOST</span></div>
<div class="row"><span class="label">VM IP</span><span class="value">$$VMIP</span></div>
</div>
<div class="divider"></div>
<div class="source-ip"><div class="label">Your Source IP</div><div class="value loading" id="srcip">detecting...</div></div>
<div class="path">
<div class="label">Traffic Path</div>
<div class="step"><span class="dot"></span><span class="step-text">Client</span></div>
<div class="step"><span class="ln"></span></div>
<div class="step"><span class="dot"></span><span class="step-text">External NLB</span><span class="badge">L4 Passthrough</span></div>
<div class="step"><span class="ln"></span></div>
<div class="step"><span class="dot"></span><span class="step-text">NSI Intercept</span></div>
<div class="step"><span class="ln"></span></div>
<div class="step"><span class="dot"></span><span class="step-text">GCP ZTGW</span><span class="badge">Geneve</span></div>
<div class="step"><span class="ln"></span></div>
<div class="step"><span class="dot here"></span><span class="step-text here">$$VMHOST</span><span class="badge">you are here</span></div>
</div>
</div>
<script>
fetch('/ip').then(function(r){return r.text()}).then(function(ip){var e=document.getElementById('srcip');e.textContent=ip.trim();e.classList.remove('loading')}).catch(function(){document.getElementById('srcip').textContent='unavailable'});
</script>
</body>
</html>
HTMLEOF
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
