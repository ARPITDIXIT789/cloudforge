#!/usr/bin/env bash
# ==============================================================================
# CloudForge — 1-Click Interactive Bootstrap Engine
# ==============================================================================
# Goes from "Zero to Production" in ~15 minutes:
#   1. Validates CLI prerequisites (terraform, aws, kubectl, helm)
#   2. Provisions AWS VPC, EKS, RDS, Bastion via Terraform
#   3. Syncs kubeconfig for EKS
#   4. Deploys ArgoCD GitOps engine & App-of-Apps
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

trap 'log_error "CloudForge bootstrap interrupted or encountered a failure on line $LINENO."' ERR

echo -e "${CYAN}${BOLD}"
cat << "EOF"
   ______  __                   __ ______                               
  / ____/ / /____  __  ______ _/ // ____/___  _________ ____            
 / /     / / __  \/ / / / __ `/ // /_  / __ \/ ___/ __ `/ _ \           
/ /___  / / /_/ / /_/ / /_/ / // __/  / /_/ / /  / /_/ /  __/           
\____/ /_/\____/\__,_/\__,_/_//_/     \____/_/   \__, /\___/            
                                                /____/                  
      >> CloudForge: Zero to Production Platform Blueprint <<
EOF
echo -e "${NC}"

# ------------------------------------------------------------------------------
# 1. Prerequisite Checks
# ------------------------------------------------------------------------------
log_info "Verifying required toolchain dependencies..."

REQUIRED_TOOLS=("terraform" "aws" "kubectl" "helm")
for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
        log_error "Missing required executable: '$tool'. Please install it before running bootstrap."
        exit 1
    fi
    log_success "Found: $tool ($(command -v "$tool"))"
done

# Check AWS authentication
log_info "Validating AWS CLI credentials..."
if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS credentials are not active or expired. Please run 'aws configure' or export AWS_PROFILE."
    exit 1
fi
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
log_success "Authenticated to AWS Account ID: ${BOLD}${ACCOUNT_ID}${NC}"

# ------------------------------------------------------------------------------
# 2. Interactive Configuration Prompts
# ------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}--- Step 1: Configuration Parameters ---${NC}"
read -rp "Target Environment [dev/prod] (default: dev): " INPUT_ENV
ENV=${INPUT_ENV:-dev}

read -rp "AWS Region (default: ap-south-1): " INPUT_REGION
AWS_REGION=${INPUT_REGION:-ap-south-1}

read -rp "Project Identifier (default: cloudforge): " INPUT_PROJECT
PROJECT_NAME=${INPUT_PROJECT:-cloudforge}

TF_DIR="terraform/environments/${ENV}"

if [[ ! -d "$TF_DIR" ]]; then
    log_error "Terraform directory '$TF_DIR' does not exist."
    exit 1
fi

echo ""
log_info "Summary of Configuration:"
echo "  - Environment: ${ENV}"
echo "  - AWS Region:  ${AWS_REGION}"
echo "  - Project:     ${PROJECT_NAME}"
echo "  - Path:        ${TF_DIR}"
echo ""

read -rp "Proceed with infrastructure provisioning? (y/N): " CONFIRM
if [[ "${CONFIRM,,}" != "y" ]]; then
    log_warn "Bootstrap cancelled by user."
    exit 0
fi

# ------------------------------------------------------------------------------
# 3. Terraform Infrastructure Provisioning
# ------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}--- Step 2: Infrastructure as Code (Terraform) ---${NC}"
log_info "Initializing Terraform in ${TF_DIR}..."
cd "${TF_DIR}"

terraform init

log_info "Executing Terraform Apply (VPC, EKS, RDS, Bastion)..."
terraform apply -auto-approve

# Extract Outputs
EKS_CLUSTER_NAME=$(terraform output -raw eks_cluster_name 2>/dev/null || echo "${PROJECT_NAME}-${ENV}-eks")
BASTION_IP=$(terraform output -raw bastion_public_ip 2>/dev/null || echo "N/A")
RDS_ENDPOINT=$(terraform output -raw rds_endpoint 2>/dev/null || echo "N/A")

cd - > /dev/null

log_success "Infrastructure provisioned successfully!"
log_info "EKS Cluster:    ${EKS_CLUSTER_NAME}"
log_info "Bastion Host:   ${BASTION_IP}"
log_info "PostgreSQL RDS: ${RDS_ENDPOINT}"

# ------------------------------------------------------------------------------
# 4. Kubernetes & Kubeconfig Setup
# ------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}--- Step 3: Kubernetes Authentication & GitOps ---${NC}"
log_info "Updating kubeconfig for cluster ${EKS_CLUSTER_NAME} in region ${AWS_REGION}..."
aws eks update-kubeconfig --name "${EKS_CLUSTER_NAME}" --region "${AWS_REGION}"

log_info "Checking Kubernetes node connectivity..."
kubectl get nodes -o wide

# ------------------------------------------------------------------------------
# 5. ArgoCD GitOps Engine Bootstrap
# ------------------------------------------------------------------------------
log_info "Installing ArgoCD into 'argocd' namespace..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

log_info "Waiting for ArgoCD server deployment ready state..."
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s || true

log_info "Registering CloudForge Addons and App-of-Apps..."
kubectl apply -f gitops/argocd/addons-app.yaml
kubectl apply -f gitops/argocd/root-application.yaml

# ------------------------------------------------------------------------------
# 6. Observability Stack Bootstrap
# ------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}--- Step 4: Observability Assets ---${NC}"
log_info "Applying Prometheus Alert Rules and Alertmanager configuration..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f observability/prometheus/alert-rules.yaml --dry-run=client -o yaml | kubectl apply -f - || true
kubectl apply -f observability/alertmanager/alertmanager-config.yaml --dry-run=client -o yaml | kubectl apply -f - || true

# ------------------------------------------------------------------------------
# 7. Final Summary & Hand-off
# ------------------------------------------------------------------------------
echo ""
echo -e "${GREEN}${BOLD}========================================================================${NC}"
echo -e "${GREEN}${BOLD}           🚀 CloudForge Bootstrap Completed Successfully!             ${NC}"
echo -e "${GREEN}${BOLD}========================================================================${NC}"
echo ""
echo -e "Access your environments:"
echo -e "  - ArgoCD UI:            Run 'kubectl port-forward svc/argocd-server -n argocd 8080:443'"
echo -e "                          Initial Admin Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
echo -e "  - Bastion Jumpbox:      ssh -i ~/.ssh/your-key.pem ec2-user@${BASTION_IP}"
echo -e "  - RDS PostgreSQL:       ${RDS_ENDPOINT}"
echo -e "  - Golden Signals Dash:  Import 'observability/grafana/golden-signals-dashboard.json' into Grafana"
echo ""
echo -e "${CYAN}Run 'make test' to verify DevSecOps health checks.${NC}"
echo -e "${YELLOW}To tear down cloud resources and prevent charges: run 'make destroy'${NC}"
echo ""
