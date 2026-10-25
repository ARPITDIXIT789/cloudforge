###############################################################################
# CloudForge — Bastion Module Variables
###############################################################################

variable "instance_type" {
  description = "EC2 instance type for the bastion host."
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Name of the SSH key pair for bastion access."
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet ID where the bastion host is launched."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the bastion host resides."
  type        = string
}

variable "admin_cidr" {
  description = "CIDR block allowed SSH access to the bastion host."
  type        = string

  validation {
    condition     = can(cidrhost(var.admin_cidr, 0))
    error_message = "admin_cidr must be a valid CIDR block."
  }
}

variable "project_name" {
  description = "Name of the project, used in resource naming and tags."
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod)."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}
