#!/usr/bin/env bash
#
# deploy-all.sh — One-shot: Deploy ZTGW + East-West Lab
#
# Usage:
#   cd /Users/anasshahid/GCP-ZTGW-Prod-VPCs
#   ./deploy-all.sh
#
# You will be prompted ONCE for the Zscaler client secret (hidden input).
# Everything else is pre-filled.
#

set -eo pipefail

RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
CYAN=$(tput setaf 6)
RESET=$(tput sgr0)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ZTGW_DIR="$SCRIPT_DIR/ztgw"
LAB_DIR="$SCRIPT_DIR/lab-environment"

# ============================================================================
# Pre-filled configuration
# ============================================================================

CLIENT_ID=""                          # Zscaler OneAPI client ID
VANITY_DOMAIN=""                      # Zscaler vanity domain (e.g. acme)
CLOUD="zscaler"                       # zscaler, zscalerone, zscalertwo, zscalerthree, zscalerbeta
LOGIN_DOMAIN=""                       # Leave empty for cloud default, or set e.g. zslogin.net
GATEWAY_NAME="gcp-ztgw-prod"
GCP_REGION="us-central1"
LOCATION_NAME="gcp-ztgw-prod-location"
IAM_PRINCIPAL=""                      # IAM principal email for ZTGW
PROJECT_ID=""                         # GCP project ID
ZONE="us-central1-a"
DEPLOY_KEY="ztgw-lab"
MACHINE_TYPE="e2-small"

# ============================================================================
# Prompt for secret (hidden input — the ONLY interactive step)
# ============================================================================

echo ""
echo "${GREEN}============================================================${RESET}"
echo "${GREEN}  One-Shot Deploy: ZTGW + East-West Lab${RESET}"
echo "${GREEN}============================================================${RESET}"
echo ""
echo "  Client ID:      ${CYAN}$CLIENT_ID${RESET}"
echo "  Vanity Domain:  ${CYAN}$VANITY_DOMAIN${RESET}"
echo "  Cloud:          ${CYAN}$CLOUD${RESET}"
echo "  Gateway Name:   ${CYAN}$GATEWAY_NAME${RESET}"
echo "  Region:         ${CYAN}$GCP_REGION${RESET}"
echo "  Project:        ${CYAN}$PROJECT_ID${RESET}"
echo "  IAM Principal:  ${CYAN}$IAM_PRINCIPAL${RESET}"
echo ""

while [ -z "$CLIENT_SECRET" ]; do
    read -rs -p "${CYAN}Enter Zscaler OneAPI Client Secret (input hidden): ${RESET}" CLIENT_SECRET
    echo ""
done

echo ""
echo "${GREEN}Secret received. Starting deployment...${RESET}"
echo ""

# ============================================================================
# Step 1: Ensure Terraform binary exists
# ============================================================================

cd "$ZTGW_DIR"
mkdir -p bin

if [[ ! -e ./bin/terraform ]]; then
    echo "Downloading Terraform..."
    tversion=1.9.0
    archdetect=$(uname -m)
    if [[ "$OSTYPE" == "linux"* ]]; then
        os_str=linux; arch=amd64
    elif [[ "$OSTYPE" == "darwin"* && "$archdetect" == "arm64" ]]; then
        os_str=darwin; arch=arm64
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        os_str=darwin; arch=amd64
    fi
    curl -so ./bin/terraform_${tversion}_${arch}.zip \
        "https://releases.hashicorp.com/terraform/${tversion}/terraform_${tversion}_${os_str}_${arch}.zip"
    unzip -qo ./bin/terraform_${tversion}_${arch}.zip -d ./bin
    rm -f ./bin/terraform_${tversion}_${arch}.zip
    echo "${GREEN}Terraform downloaded.${RESET}"
fi

TERRAFORM="$ZTGW_DIR/bin/terraform"

# ============================================================================
# Step 2: Deploy ZTGW (ZTGW-only mode)
# ============================================================================

echo ""
echo "${GREEN}============================================================${RESET}"
echo "${GREEN}  PHASE 1: Deploying ZTGW${RESET}"
echo "${GREEN}============================================================${RESET}"
echo ""

export TF_VAR_deploy_ztgw=true
export TF_VAR_deploy_consumer=false
export TF_VAR_client_id="$CLIENT_ID"
export TF_VAR_client_secret="$CLIENT_SECRET"
export TF_VAR_vanity_domain="$VANITY_DOMAIN"
export TF_VAR_cloud="$CLOUD"
export TF_VAR_login_domain="$LOGIN_DOMAIN"
export TF_VAR_gateway_name="$GATEWAY_NAME"
export TF_VAR_gcp_region="$GCP_REGION"
export TF_VAR_location_name="$LOCATION_NAME"
export TF_VAR_iam_principal_email="$IAM_PRINCIPAL"
export TF_VAR_project_id="$PROJECT_ID"
export TF_VAR_region="$GCP_REGION"

cd "$ZTGW_DIR"
$TERRAFORM init
$TERRAFORM apply -auto-approve

echo ""
echo "${GREEN}ZTGW deployment complete. Extracting intercept_deployment_group...${RESET}"

INTERCEPT_DG=$($TERRAFORM output -raw intercept_deployment_group 2>/dev/null || true)

if [ -z "$INTERCEPT_DG" ]; then
    echo "${RED}ERROR: Could not retrieve intercept_deployment_group from ZTGW output.${RESET}"
    echo "${YELLOW}Check the ZTGW health status and re-run.${RESET}"
    $TERRAFORM output
    exit 1
fi

echo ""
echo "${GREEN}Intercept Deployment Group:${RESET}"
echo "  ${CYAN}$INTERCEPT_DG${RESET}"
echo ""

# ============================================================================
# Step 3: Deploy East-West Lab with NSI
# ============================================================================

echo "${GREEN}============================================================${RESET}"
echo "${GREEN}  PHASE 2: Deploying East-West Lab + NSI${RESET}"
echo "${GREEN}============================================================${RESET}"
echo ""

# Unset ZTGW-specific vars that would conflict with lab
unset TF_VAR_deploy_ztgw
unset TF_VAR_deploy_consumer
unset TF_VAR_client_id
unset TF_VAR_client_secret
unset TF_VAR_vanity_domain
unset TF_VAR_cloud
unset TF_VAR_login_domain
unset TF_VAR_gateway_name
unset TF_VAR_gcp_region
unset TF_VAR_location_name
unset TF_VAR_iam_principal_email

# Set lab-environment vars
export TF_VAR_project_id="$PROJECT_ID"
export TF_VAR_region="$GCP_REGION"
export TF_VAR_zone="$ZONE"
export TF_VAR_deploy_key="$DEPLOY_KEY"
export TF_VAR_machine_type="$MACHINE_TYPE"
export TF_VAR_deploy_east_west=true
export TF_VAR_deploy_ingress=false
export TF_VAR_deploy_nsi=true
export TF_VAR_intercept_deployment_group="$INTERCEPT_DG"
export TF_VAR_security_profile_scope="project"

cd "$LAB_DIR"
$TERRAFORM init
$TERRAFORM apply -auto-approve

echo ""
echo "${GREEN}============================================================${RESET}"
echo "${GREEN}  DEPLOYMENT COMPLETE${RESET}"
echo "${GREEN}============================================================${RESET}"
echo ""

# ============================================================================
# Step 4: Print all the outputs
# ============================================================================

echo "${CYAN}--- ZTGW ---${RESET}"
echo "  Intercept Deployment Group: $INTERCEPT_DG"
echo ""

echo "${CYAN}--- East-West Lab ---${RESET}"

BASTION_IP=$($TERRAFORM output -raw bastion_external_ip 2>/dev/null || echo "N/A")
VM_A_IP=$($TERRAFORM output -raw vm_a_internal_ip 2>/dev/null || echo "N/A")
VM_B_IP=$($TERRAFORM output -raw vm_b_internal_ip 2>/dev/null || echo "N/A")
SSH_KEY=$($TERRAFORM output -raw ssh_private_key_path 2>/dev/null || echo "N/A")

echo "  Bastion External IP:  ${GREEN}$BASTION_IP${RESET}"
echo "  VM-A Internal IP:     ${GREEN}$VM_A_IP${RESET}  (VPC: vpc-ew-a, 10.1.0.0/16)"
echo "  VM-B Internal IP:     ${GREEN}$VM_B_IP${RESET}  (VPC: vpc-ew-b, 192.168.0.0/16)"
echo "  SSH Key:              ${GREEN}$SSH_KEY${RESET}"
echo ""

echo "${CYAN}--- SSH Commands ---${RESET}"
echo "  Bastion:   ssh -i $SSH_KEY debian@$BASTION_IP"
echo "  VM-A:      ssh -i $SSH_KEY -J debian@$BASTION_IP debian@$VM_A_IP"
echo "  VM-B:      ssh -i $SSH_KEY -J debian@$BASTION_IP debian@$VM_B_IP"
echo ""

echo "${CYAN}--- East-West Test (run from bastion) ---${RESET}"
echo "  A -> B:    curl http://$VM_B_IP"
echo "  B -> A:    curl http://$VM_A_IP"
echo ""

echo "${CYAN}--- For Zscaler Cloud Connector Portal ---${RESET}"
echo "  VM-A (source/dest):   $VM_A_IP"
echo "  VM-B (source/dest):   $VM_B_IP"
echo "  VPC-A CIDR:           10.1.0.0/16"
echo "  VPC-B CIDR:           192.168.0.0/16"
echo ""

echo "${GREEN}============================================================${RESET}"
echo "${GREEN}  Ready for rule creation in Zscaler Cloud Connector Portal${RESET}"
echo "${GREEN}============================================================${RESET}"
echo ""
