# =============================================================================
# GCP ZTGW Lab Environment — Outputs
# =============================================================================

# ---------------------------------------------------------------------------
# Bastion (always deployed)
# ---------------------------------------------------------------------------

output "bastion_external_ip" {
  description = "Static external IP of the bastion host."
  value       = module.bastion.bastion_external_ip
}

output "bastion_ssh_command" {
  description = "SSH command to connect to the bastion."
  value       = module.bastion.ssh_command
}

output "ssh_private_key_path" {
  description = "Local path to the generated SSH private key."
  value       = module.bastion.ssh_private_key_path
}

# ---------------------------------------------------------------------------
# East-West: VPC-A
# ---------------------------------------------------------------------------

output "vpc_a_network_name" {
  description = "Name of VPC-A."
  value       = var.deploy_east_west ? module.vpc_a[0].network_name : null
}

output "vpc_a_subnet_name" {
  description = "Name of VPC-A subnet."
  value       = var.deploy_east_west ? module.vpc_a[0].subnet_name : null
}

output "vm_a_internal_ip" {
  description = "Internal IP of the nginx VM in VPC-A."
  value       = var.deploy_east_west ? module.vm_a[0].internal_ip : null
}

# ---------------------------------------------------------------------------
# East-West: VPC-B
# ---------------------------------------------------------------------------

output "vpc_b_network_name" {
  description = "Name of VPC-B."
  value       = var.deploy_east_west ? module.vpc_b[0].network_name : null
}

output "vpc_b_subnet_name" {
  description = "Name of VPC-B subnet."
  value       = var.deploy_east_west ? module.vpc_b[0].subnet_name : null
}

output "vm_b_internal_ip" {
  description = "Internal IP of the nginx VM in VPC-B."
  value       = var.deploy_east_west ? module.vm_b[0].internal_ip : null
}

# ---------------------------------------------------------------------------
# VPC Peering
# ---------------------------------------------------------------------------

output "peering_a_to_b_state" {
  description = "State of VPC-A to VPC-B peering."
  value       = var.deploy_east_west ? module.vpc_peering[0].peering_a_to_b_state : null
}

output "peering_b_to_a_state" {
  description = "State of VPC-B to VPC-A peering."
  value       = var.deploy_east_west ? module.vpc_peering[0].peering_b_to_a_state : null
}

# ---------------------------------------------------------------------------
# Ingress VPC
# ---------------------------------------------------------------------------

output "ingress_vpc_name" {
  description = "Name of the ingress VPC."
  value       = var.deploy_ingress ? module.ingress_vpc[0].network_name : null
}

output "ingress_web_server_internal_ip" {
  description = "Internal IP of the ingress web server."
  value       = var.deploy_ingress ? module.ingress_vpc[0].web_server_internal_ip : null
}

output "ingress_nlb_external_ip" {
  description = "External IP of the passthrough NLB."
  value       = var.deploy_ingress ? module.ingress_vpc[0].nlb_external_ip : null
}

# ---------------------------------------------------------------------------
# NSI Consumer (conditional)
# ---------------------------------------------------------------------------

output "nsi_vpc_a_endpoint_group_id" {
  description = "NSI endpoint group ID for VPC-A."
  value       = var.deploy_east_west && var.deploy_nsi ? module.nsi_consumer_a[0].endpoint_group_id : null
}

output "nsi_vpc_b_endpoint_group_id" {
  description = "NSI endpoint group ID for VPC-B."
  value       = var.deploy_east_west && var.deploy_nsi ? module.nsi_consumer_b[0].endpoint_group_id : null
}

output "nsi_ingress_endpoint_group_id" {
  description = "NSI endpoint group ID for the ingress VPC."
  value       = var.deploy_ingress && var.deploy_nsi ? module.nsi_consumer_ingress[0].endpoint_group_id : null
}

# ---------------------------------------------------------------------------
# SSH instructions (east-west only)
# ---------------------------------------------------------------------------

output "ssh_to_vm_a" {
  description = "SSH to VM-A via bastion."
  value       = var.deploy_east_west ? "ssh -i ${module.bastion.ssh_private_key_path} -J debian@${module.bastion.bastion_external_ip} debian@${module.vm_a[0].internal_ip}" : null
}

output "ssh_to_vm_b" {
  description = "SSH to VM-B via bastion."
  value       = var.deploy_east_west ? "ssh -i ${module.bastion.ssh_private_key_path} -J debian@${module.bastion.bastion_external_ip} debian@${module.vm_b[0].internal_ip}" : null
}

output "test_east_west_a_to_b" {
  description = "Test east-west connectivity from VM-A to VM-B (run from bastion)."
  value       = var.deploy_east_west ? "curl http://${module.vm_b[0].internal_ip}" : null
}

output "test_east_west_b_to_a" {
  description = "Test east-west connectivity from VM-B to VM-A (run from bastion)."
  value       = var.deploy_east_west ? "curl http://${module.vm_a[0].internal_ip}" : null
}

# ---------------------------------------------------------------------------
# Test instructions (ingress)
# ---------------------------------------------------------------------------

output "test_ingress_nlb" {
  description = "Test ingress NLB from your terminal."
  value       = var.deploy_ingress ? "curl http://${module.ingress_vpc[0].nlb_external_ip}" : null
}
