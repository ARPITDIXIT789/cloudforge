# =============================================================================
# CloudForge — Dev Environment
# =============================================================================
# Development environment orchestration. This file wires together all
# infrastructure modules (VPC, EKS, RDS, Bastion) with dev-appropriate sizing.
#
# Usage:
#   cp terraform.tfvars.example terraform.tfvars   # fill in your values
#   terraform init -backend-config="key=cloudforge/dev/terraform.tfstate"
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

  # Override the root backend key for the dev environment
  backend "s3" {
    bucket         = "cloudforge-terraform-state"
    key            = "cloudforge/dev/terraform.tfstate"
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
# Creates the foundational network: VPC, public/private subnets, NAT Gateway,
# Internet Gateway, and route tables.

module "vpc" {
  source = "../../modules/vpc"

  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
  aws_region   = var.aws_region
}

# -----------------------------------------------------------------------------
# Module: EKS
# -----------------------------------------------------------------------------
# Provisions the EKS cluster and managed node groups inside the private subnets
# created by the VPC module.

module "eks" {
  source = "../../modules/eks"

  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  # Dev-appropriate sizing — small cluster for cost efficiency
  node_instance_types = ["t3.medium"]
  node_desired_size   = 2
  node_min_size       = 1
  node_max_size       = 4

  depends_on = [module.vpc]
}

# -----------------------------------------------------------------------------
# Module: RDS
# -----------------------------------------------------------------------------
# Deploys a PostgreSQL RDS instance in private subnets. Security group chaining
# allows inbound access only from EKS worker nodes and the bastion host.

module "rds" {
  source = "../../modules/rds"

  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  # Database configuration
  db_name     = var.db_name
  db_username = var.db_username

  # Dev-appropriate sizing — single-AZ, smaller instance
  instance_class = "db.t3.medium"
  multi_az       = false

  # Security group chaining: allow EKS nodes → RDS
  allowed_security_group_ids = [module.eks.node_security_group_id]

  depends_on = [module.vpc]
}

# -----------------------------------------------------------------------------
# Module: Bastion
# -----------------------------------------------------------------------------
# Launches a hardened bastion host in a public subnet for secure SSH access
# to private resources (EKS nodes, RDS).

module "bastion" {
  source = "../../modules/bastion"

  project_name     = var.project_name
  environment      = var.environment
  vpc_id           = module.vpc.vpc_id
  public_subnet_id = module.vpc.public_subnet_ids[0]

  # Access control
  admin_cidr   = var.admin_cidr
  key_name     = var.bastion_key_name

  depends_on = [module.vpc]
}
