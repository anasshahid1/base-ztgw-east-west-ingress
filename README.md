# Zscaler GCP ZTGW Lab - East-West and Ingress

Terraform-based lab environment for deploying and testing Zscaler GCP Zero Trust Gateway (ZTGW) with Network Security Intercept (NSI) for **east-west** and **ingress** use cases.

## Architecture

```
                        East-West Traffic Flow
                        ~~~~~~~~~~~~~~~~~~~~~~

  VPC-A (10.1.0.0/16)                          VPC-B (192.168.0.0/16)
  +------------------+                          +------------------+
  | nginx VM         |<--- VPC Peering -------->| nginx VM         |
  | (10.1.1.x)       |     (bi-directional)     | (192.168.1.x)    |
  |                  |                          |                  |
  | Bastion VM       |                          |                  |
  | (public IP, SSH) |                          |                  |
  +------------------+                          +------------------+
         |                                             |
         |  NSI Firewall Policy                        |  NSI Firewall Policy
         |  Endpoint Group                             |  Endpoint Group
         |                                             |
         +-------------------+   +---------------------+
                             |   |
                      +------v---v------+
                      |   GCP ZTGW      |
                      |   (Geneve)      |
                      +-----------------+


                        Ingress Traffic Flow
                        ~~~~~~~~~~~~~~~~~~~~

  External Client
       |
       v
  External Passthrough NLB (static public IP, port 80)
       |
       v
  VPC-Ingress (172.16.0.0/16)
  +------------------+
  | Web Server VM    |
  | (nginx)          |
  | (172.16.1.x)     |
  +------------------+
         |
         |  NSI Firewall Policy
         |  Endpoint Group
         |
         v
  +------+----------+
  |   GCP ZTGW      |
  |   (Geneve)      |
  +-----------------+
```

## Prerequisites

- **GCP account** with a project that has billing enabled
- **`gcloud` CLI** authenticated (`gcloud auth application-default login`)
- **Zscaler OneAPI credentials** (client ID + client secret + vanity domain)
- **`curl`**, **`unzip`**, **`python3`** (standard on macOS/Linux)
- Terraform is downloaded automatically by the `zsec` wrapper

## Quick Start

### Clone the repo

```bash
git clone https://github.com/anasshahid1/base-ztgw-east-west-ingress.git
cd base-ztgw-east-west-ingress
```

### Deploy

The recommended approach is a **two-stage deployment**:

#### Stage 1 - Deploy the ZTGW

```bash
./ztgw/zsec up
```

Select **option 2 (ZTGW-only)**. The wizard will prompt for:

- Zscaler OneAPI credentials (client ID, secret, vanity domain, cloud)
- Gateway name and GCP region
- Location name and IAM principal email

After deployment, copy the `intercept_deployment_group` from the output.

#### Stage 2 - Deploy the Lab Environment

```bash
rm ztgw/.zsecrc    # clear previous config
./ztgw/zsec up
```

Select **option 4 (Lab Environment)**. The wizard will prompt for:

- **Lab scenario**: East-West, Ingress, or Both
- **GCP project ID** and region
- **NSI configuration**: paste the `intercept_deployment_group` from Stage 1
- **Security profile scope**: project (default) or organization

The wizard shows a deployment summary before proceeding.

### One-Stage Deploy (if ZTGW already exists)

If you already have a ZTGW deployed with an `intercept_deployment_group`, skip Stage 1 and go directly to Stage 2.

## Lab Scenarios

### East-West

Creates two VPCs with nginx VMs, bi-directional VPC peering, and NSI on both VPCs. Traffic between VPC-A and VPC-B is intercepted by the ZTGW.

| Resource | Details |
|---|---|
| VPC-A | `vpc-ew-a` (10.1.0.0/16, subnet 10.1.1.0/24) |
| VPC-B | `vpc-ew-b` (192.168.0.0/16, subnet 192.168.1.0/24) |
| VM-A | e2-small, nginx, private IP in VPC-A |
| VM-B | e2-small, nginx, private IP in VPC-B |
| Bastion | e2-small, static public IP, SSH key in VPC-A |
| VPC Peering | Bi-directional between VPC-A and VPC-B |
| NSI | Endpoint groups + firewall policies on both VPCs |

### Ingress

Creates one VPC with a web server behind an external passthrough NLB (L4). Inbound traffic from the internet is intercepted by the ZTGW via NSI before reaching the web server.

| Resource | Details |
|---|---|
| VPC-Ingress | `vpc-ingress` (172.16.0.0/16, subnet 172.16.1.0/24) |
| Web Server | e2-small, nginx |
| NLB | External passthrough L4, static public IP, port 80 |
| NSI | Endpoint group + firewall policy on ingress VPC |

### Both

Deploys everything from East-West and Ingress scenarios together.

## Post-Deploy Steps

### 1. Install nginx on VMs

The VMs are created with startup scripts that install nginx, but if NSI is active during creation the outbound apt traffic may be intercepted. If nginx is not running, SSH into each VM from the GCP console and run:

```bash
sudo apt-get update -y && sudo apt-get install -y nginx && sudo systemctl enable nginx && sudo systemctl start nginx
```

### 2. Create forwarding rules in Zscaler Cloud Connector portal

NSI intercepts traffic and sends it to the ZTGW. You need forwarding rules in the Cloud Connector portal to allow or inspect the traffic.

**East-West rule example:**

| Field | Value |
|---|---|
| Source | VM-A internal IP or VPC-A CIDR (10.1.0.0/16) |
| Destination | VM-B internal IP or VPC-B CIDR (192.168.0.0/16) |
| Location | Your ZTGW location name |
| Forwarding Method | Local |

**Ingress rule example:**

| Field | Value |
|---|---|
| Source | 0.0.0.0/0 (external clients) |
| Destination | NLB external IP or web server internal IP |
| Location | Your ZTGW location name |
| Forwarding Method | Local |

### 3. Network firewall policy enforcement order

The VPCs are configured with `network_firewall_policy_enforcement_order = BEFORE_CLASSIC_FIREWALL` so that NSI intercept rules in the firewall policy are evaluated before classic firewall rules.

## SSH Access

After deployment, outputs provide SSH commands:

```bash
# SSH to bastion
ssh -i lab-environment/lab-key.pem debian@<bastion-external-ip>

# SSH to VM-A via bastion jump
ssh -i lab-environment/lab-key.pem -J debian@<bastion-ip> debian@<vm-a-ip>

# SSH to VM-B via bastion jump
ssh -i lab-environment/lab-key.pem -J debian@<bastion-ip> debian@<vm-b-ip>
```

You can also access VMs directly from the GCP console SSH-in-browser.

## Testing

### East-West (from VM-A)

```bash
curl http://<vm-b-internal-ip>
```

If NSI is active and no forwarding rule exists, you will see a Zscaler block page (504/403) confirming traffic is being intercepted.

### Ingress (from your terminal)

```bash
curl http://<nlb-external-ip>
```

Traffic flows: Client -> NLB -> NSI intercept -> ZTGW -> web server.

## Teardown

```bash
./ztgw/zsec destroy
```

This destroys all lab resources and cleans up local state files.

For ZTGW-only teardown (if deployed separately), delete `.zsecrc` and re-run with the ZTGW config.

## Repo Structure

```
base-ztgw-east-west-ingress/
|-- README.md
|-- .gitignore
|-- deploy-all.sh             # One-shot deploy script (fill in values)
|-- ztgw/                     # ZTGW deployment + zsec wrapper
|   |-- main.tf               # ZTGW + NSI consumer resources
|   |-- variables.tf
|   |-- outputs.tf
|   |-- provider.tf
|   |-- versions.tf
|   |-- terraform.tfvars.example
|   |-- zsec                  # Interactive deployment wrapper
|   `-- scripts/
|       |-- deploy_ztgw.sh    # ZTGW deploy via Zscaler REST API
|       `-- destroy_ztgw.sh   # ZTGW teardown
`-- lab-environment/          # Lab VPCs, VMs, NSI, bastion, NLB
    |-- main.tf               # Root module wiring all modules
    |-- variables.tf
    |-- outputs.tf
    |-- providers.tf
    |-- versions.tf
    |-- terraform.tfvars.example
    `-- modules/
        |-- bastion/          # SSH key gen + bastion VM + static IP
        |-- ingress-vpc/      # VPC + web server + NLB (L4)
        |-- nsi-consumer/     # NSI: firewall policy + endpoint group + security profile
        |-- vm/               # Compute VM with nginx startup script
        |-- vpc/              # VPC + subnet + firewall rules
        `-- vpc-peering/      # Bi-directional VPC peering
```

## Variables Reference

### Lab Environment Variables

| Variable | Description | Default |
|---|---|---|
| `project_id` | GCP project ID | (required) |
| `region` | GCP region | `us-central1` |
| `zone` | GCP zone | `us-central1-a` |
| `deploy_key` | Naming prefix for all resources | `ztgw-lab` |
| `machine_type` | VM machine type | `e2-small` |
| `deploy_east_west` | Deploy east-west scenario | `true` |
| `deploy_ingress` | Deploy ingress scenario | `true` |
| `deploy_nsi` | Deploy NSI consumer resources | `false` |
| `intercept_deployment_group` | ZTGW intercept deployment group ID | (required when deploy_nsi=true) |
| `security_profile_scope` | Security profile scope: `project` or `organization` | `project` |

### ZTGW Variables

| Variable | Description | Default |
|---|---|---|
| `client_id` | Zscaler OneAPI client ID | (required) |
| `client_secret` | Zscaler OneAPI client secret | (required) |
| `vanity_domain` | Zscaler vanity domain | (required) |
| `cloud` | Zscaler cloud | `zscaler` |
| `gateway_name` | ZTGW name | `gcp-ztgw-demo` |
| `gcp_region` | GCP region for ZTGW | `us-central1` |

## Troubleshooting

### nginx not running on VMs

The startup script may fail if NSI egress intercept catches the outbound apt traffic. SSH into the VM from the GCP console and install manually:

```bash
sudo apt-get update -y && sudo apt-get install -y nginx
sudo systemctl enable nginx && sudo systemctl start nginx
```

### SSH timeout to bastion

The bastion uses the `bastion` network tag. Add a firewall rule allowing SSH from your IP:

```bash
gcloud compute firewall-rules create allow-ssh-myip \
    --project=YOUR_PROJECT \
    --network=vpc-ew-a \
    --allow=tcp:22 \
    --source-ranges=YOUR_IP/32 \
    --target-tags=bastion
```

### IAP tunnel SSL errors

If you see `SSL: CERTIFICATE_VERIFY_FAILED` when using `gcloud compute ssh --tunnel-through-iap`, this is caused by SSL inspection (e.g., Zscaler Client Connector) intercepting the IAP tunnel. Use the GCP console SSH-in-browser instead.

### Zscaler 504 Gateway Timeout

Traffic is being intercepted by the ZTGW but no forwarding rule matches. Create a forwarding rule in the Cloud Connector portal.

### Zscaler 403 Forbidden

Traffic is intercepted and a Zscaler policy is blocking it (e.g., uncategorized URL). Create a forwarding rule to allow the traffic.
