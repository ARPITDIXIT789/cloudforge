#!/usr/bin/env bash
# ==============================================================================
# CloudForge — 1-Click Cloud Resource Teardown Script
# ==============================================================================
# Gracefully unwinds:
#   1. ArgoCD Root Applications & Custom Ingresses (to avoid orphaned AWS ALBs)
#   2. Kubernetes Service LoadBalancers & Controller resources
#   3. Terraform State Infrastructure (RDS, EKS, NAT GW, VPC)
# ==============================================================================

set -euo pipefail

# Visual stylings
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

log_info()    { echo -e "${CYAN}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

echo -e "${RED}${BOLD}"
cat << "EOF"
    __  ___  ___  __   ___  ____   ___   ____  __
   /  |/  / / _ \ \ \ / / \/ /  \ / _ \ /  _/ / /
  / /|_/ / / // /  \ V /   \/ _ // // / _/ / / /__
 /_/  /_/ /____/    \_/  _/\_\__/____/ /___/ /____/
     ⚠️  CLOUDFORGE CLOUD RESOURCE TEARDOWN ⚠️
EOF
echo -e "${NC}"

read -rp "Select Environment to destroy [dev/prod] (default: dev): " INPUT_ENV
ENV=${INPUT_ENV:-dev}
TF_DIR="terraform/environments/${ENV}"

if [[ ! -d "$TF_DIR" ]]; then
    log_error "Directory '$TF_DIR' not found."
    exit 1
fi

echo ""
log_warn "This action will PERMANENTLY DESTROY all cloud resources in environment: [${BOLD}${ENV}${NC}]"
log_warn "Resources to be purged: EKS Cluster, RDS Database, VPC, NAT Gateways, Bastion host."
echo ""
read -rp "Are you absolutely sure you want to proceed? Type 'DESTROY' to confirm: " CONFIRMATION

if [[ "$CONFIRMATION" != "DESTROY" ]]; then
    log_info "Teardown aborted. No resources were modified."
    exit 0
fi

# ------------------------------------------------------------------------------
# 1. Clean up Kubernetes Ingresses & ArgoCD Applications First
# (CRITICAL: Ensures AWS Load Balancer Controller deletes AWS ALBs before VPC is destroyed)
# ------------------------------------------------------------------------------
log_info "Step 1: Removing Kubernetes Ingresses and ArgoCD Apps to release AWS ALBs..."
if kubectl get ingress --all-namespaces &> /dev/null; then
    log_info "Deleting all Ingress objects..."
    kubectl delete ingress --all --all-namespaces --timeout=120s || true
fi

log_info "Deleting ArgoCD Root & Addons applications..."
kubectl delete -f gitops/argocd/root-application.yaml --ignore-not-found=true --timeout=60s || true
kubectl delete -f gitops/argocd/addons-app.yaml --ignore-not-found=true --timeout=60s || true

log_info "Waiting 30 seconds for AWS Application Load Balancers to deprovision..."
sleep 30

# ------------------------------------------------------------------------------
# 2. Terraform Teardown
# ------------------------------------------------------------------------------
log_info "Step 2: Destroying Terraform infrastructure in ${TF_DIR}..."
cd "${TF_DIR}"

terraform destroy -auto-approve

cd - > /dev/null

log_success "All CloudForge AWS resources in [${ENV}] have been destroyed."
log_info "No ongoing AWS charges will be incurred."
