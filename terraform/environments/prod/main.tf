# =============================================================================
# CloudForge — Production Environment
# =============================================================================
# Production-grade infrastructure orchestration. This configuration uses
# hardened, multi-AZ, right-sized resources suitable for production workloads.
#
# Key differences from dev:
#   - Multi-AZ RDS for high availability
#   - Larger EKS node group (min 3, max 8) for resilience
#   - Larger instance types for sustained throughput
#   - Separate state key for isolation from dev/staging
#
# Usage:
#   cp terraform.tfvars.example terraform.tfvars   # fill in your values
#   terraform init -backend-config="key=cloudforge/prod/terraform.tfstate"
#   terraform plan
#   terraform apply
# =============================================================================

# -----------------------------------------------------------------------------
# Terraform & Provider Configuration
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  # Production state — isolated from dev/staging
  backend "s3" {
    bucket         = "arpit-cloudforge-state-2026"
    key            = "cloudforge/prod/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "cloudforge-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Repository  = "cloudforge"
      CostCenter  = "production"
    }
  }
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

# Retrieve available AZs in the target region
data "aws_availability_zones" "available" {
  state = "available"
}

# Current AWS caller identity for account-level references
data "aws_caller_identity" "current" {}

# -----------------------------------------------------------------------------
# Module: VPC
# -----------------------------------------------------------------------------
# Creates the foundational network: VPC, public/private subnets across 3 AZs,
# NAT Gateway(s), Internet Gateway, and route tables.

module "vpc" {
  source = "../../modules/vpc"

  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
}

# -----------------------------------------------------------------------------
# Module: EKS
# -----------------------------------------------------------------------------
# Provisions the EKS cluster and managed node groups in private subnets.
# Production sizing: min 3 nodes for AZ-level fault tolerance.

module "eks" {
  source = "../../modules/eks"

  cluster_name = "${var.project_name}-${var.environment}-eks"
  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.private_subnet_ids

  # Production sizing — larger instances, higher minimums for HA
  node_instance_types = ["t3.xlarge"]
  node_desired_size   = 3
  node_min_size       = 3
  node_max_size       = 8

  depends_on = [module.vpc]
}

# -----------------------------------------------------------------------------
# Module: RDS
# -----------------------------------------------------------------------------
# Deploys a PostgreSQL RDS instance with Multi-AZ failover for production
# availability. Security group chaining restricts access to EKS nodes only.

module "rds" {
  source = "../../modules/rds"

  identifier                 = "${var.project_name}-${var.environment}-rds"
  project_name               = var.project_name
  environment                = var.environment
  vpc_id                     = module.vpc.vpc_id
  isolated_subnet_ids        = module.vpc.isolated_subnet_ids
  eks_node_security_group_id = module.eks.node_security_group_id

  # Database configuration
  db_name     = var.db_name
  db_username = var.db_username

  # Production sizing — Multi-AZ, larger instance for sustained throughput
  instance_class          = "db.r6g.large"
  multi_az                = true
  backup_retention_period = 7
  skip_final_snapshot     = false

  depends_on = [module.vpc]
}

# -----------------------------------------------------------------------------
# Module: Bastion
# -----------------------------------------------------------------------------
# Launches a hardened bastion host in a public subnet. In production, access
# should be tightly scoped and audited via CloudTrail / Session Manager.

module "bastion" {
  source = "../../modules/bastion"

  project_name     = var.project_name
  environment      = var.environment
  vpc_id           = module.vpc.vpc_id
  public_subnet_id = module.vpc.public_subnet_ids[0]

  # Access control — restrict to VPN / office IP only
  admin_cidr   = var.admin_cidr
  key_name     = var.bastion_key_name

  depends_on = [module.vpc]
}
