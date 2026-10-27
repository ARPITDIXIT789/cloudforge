###############################################################################
# CloudForge — RDS Module Variables
###############################################################################

variable "identifier" {
  description = "Unique identifier for the RDS instance."
  type        = string
}

variable "engine_version" {
  description = "PostgreSQL engine version."
  type        = string
  default     = "16"
}

variable "instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Allocated storage in GB."
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Name of the initial database."
  type        = string
}

variable "db_username" {
  description = "Master username for the database."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the RDS instance resides."
  type        = string
}

variable "isolated_subnet_ids" {
  description = "List of isolated subnet IDs for the DB subnet group."
  type        = list(string)
}

variable "eks_node_security_group_id" {
  description = "Security group ID of the EKS worker nodes (for ingress rule)."
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

variable "project_name" {
  description = "Name of the project, used in resource naming and tags."
  type        = string
}

variable "multi_az" {
  description = "Enable Multi-AZ deployment for RDS."
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot when destroying the RDS instance."
  type        = bool
  default     = true
}

variable "backup_retention_period" {
  description = "Backup retention period in days (0 or 1 for Free Tier accounts)."
  type        = number
  default     = 1
}
