# =============================================================================
# GCP ZTGW Lab Environment — Root Configuration
# =============================================================================
#
# Scenario toggles:
#   deploy_east_west = true  → VPC-A, VPC-B, nginx VMs, bastion, VPC peering
#   deploy_ingress   = true  → VPC-Ingress, web server, external passthrough NLB
#   deploy_nsi       = true  → NSI consumer resources on all deployed VPCs
#
# Architecture (when both = true):
#   VPC-A (10.1.0.0/16)   <-- East-West with NSI --> VPC-B (192.168.0.0/16)
#       |                       bi-directional peering           |
#       |-- nginx VM                                        nginx VM --|
#       |-- bastion (public IP, SSH key)                              |
#       |-- NSI consumer                                   NSI consumer --|
#
#   VPC-Ingress (172.16.0.0/16) — External Passthrough NLB -> ZTGW -> web server
#       |-- web server VM (nginx)
#       |-- external passthrough NLB (L4)
#       |-- NSI consumer
#
# =============================================================================

# ---------------------------------------------------------------------------
# Bastion — always deployed; lives in VPC-A (east-west) or VPC-Ingress
# ---------------------------------------------------------------------------

module "bastion" {
  source = "./modules/bastion"

  bastion_name = "${var.deploy_key}-bastion"
  project_id   = var.project_id
  region       = var.region
  zone         = var.zone
  machine_type = var.machine_type
  # If east-west is enabled, bastion goes into VPC-A; otherwise into the ingress VPC
  subnet_self_link = var.deploy_east_west ? module.vpc_a[0].subnet_self_link : module.ingress_vpc[0].subnet_self_link
}

# =============================================================================
# EAST-WEST SCENARIO
# =============================================================================

# ---------------------------------------------------------------------------
# VPC-A — East-West VPC (10.1.0.0/16)
# ---------------------------------------------------------------------------

module "vpc_a" {
  count  = var.deploy_east_west ? 1 : 0
  source = "./modules/vpc"

  vpc_name    = var.vpc_a_name
  project_id  = var.project_id
  region      = var.region
  vpc_cidr    = var.vpc_a_cidr
  subnet_cidr = var.vpc_a_subnet_cidr
  peer_cidr   = var.vpc_b_cidr
}

# ---------------------------------------------------------------------------
# VPC-B — East-West VPC (192.168.0.0/16)
# ---------------------------------------------------------------------------

module "vpc_b" {
  count  = var.deploy_east_west ? 1 : 0
  source = "./modules/vpc"

  vpc_name    = var.vpc_b_name
  project_id  = var.project_id
  region      = var.region
  vpc_cidr    = var.vpc_b_cidr
  subnet_cidr = var.vpc_b_subnet_cidr
  peer_cidr   = var.vpc_a_cidr
}

# ---------------------------------------------------------------------------
# Nginx VM in VPC-A
# ---------------------------------------------------------------------------

module "vm_a" {
  count  = var.deploy_east_west ? 1 : 0
  source = "./modules/vm"

  vm_name          = "${var.vpc_a_name}-nginx"
  project_id       = var.project_id
  zone             = var.zone
  machine_type     = var.machine_type
  subnet_self_link = module.vpc_a[0].subnet_self_link
  network_tags     = ["nginx", "east-west"]
  ssh_public_key   = module.bastion.ssh_public_key
}

# ---------------------------------------------------------------------------
# Nginx VM in VPC-B
# ---------------------------------------------------------------------------

module "vm_b" {
  count  = var.deploy_east_west ? 1 : 0
  source = "./modules/vm"

  vm_name          = "${var.vpc_b_name}-nginx"
  project_id       = var.project_id
  zone             = var.zone
  machine_type     = var.machine_type
  subnet_self_link = module.vpc_b[0].subnet_self_link
  network_tags     = ["nginx", "east-west"]
  ssh_public_key   = module.bastion.ssh_public_key
}

# ---------------------------------------------------------------------------
# Bi-directional VPC Peering: VPC-A <-> VPC-B
# ---------------------------------------------------------------------------

module "vpc_peering" {
  count  = var.deploy_east_west ? 1 : 0
  source = "./modules/vpc-peering"

  vpc_a_name      = module.vpc_a[0].network_name
  vpc_a_self_link = module.vpc_a[0].network_self_link
  vpc_b_name      = module.vpc_b[0].network_name
  vpc_b_self_link = module.vpc_b[0].network_self_link
}

# ---------------------------------------------------------------------------
# NSI Consumer — VPC-A
# ---------------------------------------------------------------------------

module "nsi_consumer_a" {
  count  = var.deploy_east_west && var.deploy_nsi ? 1 : 0
  source = "./modules/nsi-consumer"

  providers = {
    google-beta = google-beta
  }

  name_prefix                = "${var.deploy_key}-vpc-a"
  project_id                 = var.project_id
  organization_id            = var.organization_id
  location                   = var.nsi_location
  network_id                 = module.vpc_a[0].network_id
  intercept_deployment_group = var.intercept_deployment_group
  security_profile_scope     = var.security_profile_scope

  ingress_source_ranges     = [var.vpc_b_cidr, var.vpc_a_cidr]
  egress_destination_ranges = [var.vpc_b_cidr, "0.0.0.0/0"]

  depends_on = [
    module.vpc_a,
    module.vpc_peering
  ]
}

# ---------------------------------------------------------------------------
# NSI Consumer — VPC-B
# ---------------------------------------------------------------------------

module "nsi_consumer_b" {
  count  = var.deploy_east_west && var.deploy_nsi ? 1 : 0
  source = "./modules/nsi-consumer"

  providers = {
    google-beta = google-beta
  }

  name_prefix                = "${var.deploy_key}-vpc-b"
  project_id                 = var.project_id
  organization_id            = var.organization_id
  location                   = var.nsi_location
  network_id                 = module.vpc_b[0].network_id
  intercept_deployment_group = var.intercept_deployment_group
  security_profile_scope     = var.security_profile_scope

  ingress_source_ranges     = [var.vpc_a_cidr, var.vpc_b_cidr]
  egress_destination_ranges = [var.vpc_a_cidr, "0.0.0.0/0"]

  depends_on = [
    module.vpc_b,
    module.vpc_peering
  ]
}

# =============================================================================
# INGRESS SCENARIO
# =============================================================================

# ---------------------------------------------------------------------------
# Ingress VPC — External Passthrough NLB + Web Server
# ---------------------------------------------------------------------------

module "ingress_vpc" {
  count  = var.deploy_ingress ? 1 : 0
  source = "./modules/ingress-vpc"

  vpc_name       = var.ingress_vpc_name
  project_id     = var.project_id
  region         = var.region
  zone           = var.zone
  vpc_cidr       = var.ingress_vpc_cidr
  subnet_cidr    = var.ingress_vpc_subnet_cidr
  machine_type   = var.machine_type
  ssh_public_key = module.bastion.ssh_public_key
}

# ---------------------------------------------------------------------------
# NSI Consumer — Ingress VPC
# ---------------------------------------------------------------------------

module "nsi_consumer_ingress" {
  count  = var.deploy_ingress && var.deploy_nsi ? 1 : 0
  source = "./modules/nsi-consumer"

  providers = {
    google-beta = google-beta
  }

  name_prefix                = "${var.deploy_key}-ingress"
  project_id                 = var.project_id
  organization_id            = var.organization_id
  location                   = var.nsi_location
  network_id                 = module.ingress_vpc[0].network_id
  intercept_deployment_group = var.intercept_deployment_group
  security_profile_scope     = var.security_profile_scope

  ingress_source_ranges     = ["0.0.0.0/0"]
  egress_destination_ranges = ["0.0.0.0/0"]

  depends_on = [
    module.ingress_vpc
  ]
}
