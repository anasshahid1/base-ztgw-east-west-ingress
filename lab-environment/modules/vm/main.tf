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
.header{background:linear-gradient(135deg,#0369a1,#0ea5e9);padding:28px 32px}
.header h1{font-size:14px;text-transform:uppercase;letter-spacing:2px;color:rgba(255,255,255,0.8);font-weight:500}
.header h2{font-size:22px;color:#fff;margin-top:6px;font-weight:600}
.info{padding:24px 32px}
.row{display:flex;justify-content:space-between;align-items:center;padding:14px 0;border-bottom:1px solid #253442}
.row:last-child{border-bottom:none}
.label{font-size:11px;text-transform:uppercase;letter-spacing:1.5px;color:#7a8fa0;font-weight:600}
.value{font-size:16px;font-family:'SF Mono','Cascadia Code','Consolas',monospace;color:#38bdf8;font-weight:500}
.divider{height:1px;background:#253442}
.source-ip{padding:24px 32px;text-align:center}
.source-ip .label{margin-bottom:10px}
.source-ip .value{font-size:28px;color:#22d3ee;transition:all 0.3s ease}
.source-ip .value.loading{color:#475569;font-size:16px}
.path{padding:24px 32px;background:#151f2a;border-radius:0 0 16px 16px}
.path .label{margin-bottom:16px}
.step{display:flex;align-items:center;gap:12px;padding:6px 0}
.dot{width:10px;height:10px;border-radius:50%;background:#0ea5e9;flex-shrink:0}
.dot.here{background:#22d3ee;box-shadow:0 0 12px #22d3ee}
.ln{width:10px;display:flex;justify-content:center;flex-shrink:0}
.ln::after{content:'';width:2px;height:20px;background:#334155;display:block}
.step-text{font-size:14px;color:#94a3b8}
.step-text.here{color:#22d3ee;font-weight:600}
.badge{display:inline-block;background:rgba(14,165,233,0.12);color:#38bdf8;font-size:10px;padding:2px 8px;border-radius:4px;margin-left:8px}
</style>
</head>
<body>
<div class="card">
<div class="header"><h1>Zscaler GCP ZTGW Lab</h1><h2>East-West Workload</h2></div>
<div class="info">
<div class="row"><span class="label">Hostname</span><span class="value">$$VMHOST</span></div>
<div class="row"><span class="label">VM IP</span><span class="value">$$VMIP</span></div>
</div>
<div class="divider"></div>
<div class="source-ip"><div class="label">Your Source IP</div><div class="value loading" id="srcip">detecting...</div></div>
<div class="path">
<div class="label">Traffic Path</div>
<div class="step"><span class="dot"></span><span class="step-text">Source</span></div>
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
}
