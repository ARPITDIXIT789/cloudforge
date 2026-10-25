# =============================================================================
# CloudForge — Production Environment Variables
# =============================================================================
# All input variables for the production environment. Copy
# terraform.tfvars.example to terraform.tfvars and populate before apply.
#
# Production defaults are tuned for reliability and performance.
# =============================================================================

# -----------------------------------------------------------------------------
# General
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region to deploy all production resources into."
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project identifier used for resource naming and tagging."
  type        = string
  default     = "cloudforge"
}

variable "environment" {
  description = "Deployment environment. Fixed to 'prod' for this configuration."
  type        = string
  default     = "prod"

  validation {
    condition     = var.environment == "prod"
    error_message = "This configuration is for the production environment only. Use environments/dev for development."
  }
}

# -----------------------------------------------------------------------------
# Networking
# -----------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for the production VPC. Must be large enough for public and private subnets across 3 AZs."
  type        = string
  default     = "10.1.0.0/16"
}

variable "admin_cidr" {
  description = "CIDR block allowed to SSH into the bastion host (e.g., VPN egress IP). Must be set explicitly — no default for security."
  type        = string

  validation {
    condition     = can(cidrhost(var.admin_cidr, 0))
    error_message = "admin_cidr must be a valid CIDR block, e.g. 203.0.113.10/32."
  }
}

# -----------------------------------------------------------------------------
# Bastion
# -----------------------------------------------------------------------------

variable "bastion_key_name" {
  description = "Name of the EC2 key pair to use for SSH access to the production bastion host. Must already exist in the target AWS region."
  type        = string
}

# -----------------------------------------------------------------------------
# Database (RDS)
# -----------------------------------------------------------------------------

variable "db_name" {
  description = "Name of the initial PostgreSQL database to create on the production RDS instance."
  type        = string
  default     = "appdb"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]{0,62}$", var.db_name))
    error_message = "db_name must start with a letter and contain only alphanumeric characters or underscores (max 63 chars)."
  }
}

variable "db_username" {
  description = "Master username for the production RDS PostgreSQL instance. Avoid reserved words (admin, postgres)."
  type        = string
  default     = "cloudforge_admin"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]{0,62}$", var.db_username))
    error_message = "db_username must start with a letter and contain only alphanumeric characters or underscores."
  }
}
