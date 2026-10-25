# =============================================================================
# CloudForge — Production Environment Outputs
# =============================================================================
# Exported values for consumption by CI/CD pipelines, monitoring dashboards,
# Helm charts, and downstream automation scripts.
# =============================================================================

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------

output "vpc_id" {
  description = "ID of the VPC created for the production environment."
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs (used by ALB, bastion)."
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of private subnet IDs (used by EKS nodes, RDS)."
  value       = module.vpc.private_subnet_ids
}

# -----------------------------------------------------------------------------
# EKS
# -----------------------------------------------------------------------------

output "eks_cluster_name" {
  description = "Name of the production EKS cluster."
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "API server endpoint for the production EKS cluster."
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_certificate_authority" {
  description = "Base64-encoded certificate data for the EKS cluster CA."
  value       = module.eks.cluster_certificate_authority
  sensitive   = true
}

output "eks_node_security_group_id" {
  description = "Security group ID attached to EKS managed node groups."
  value       = module.eks.node_security_group_id
}

# -----------------------------------------------------------------------------
# RDS
# -----------------------------------------------------------------------------

output "rds_endpoint" {
  description = "Connection endpoint for the production RDS PostgreSQL instance (host:port)."
  value       = module.rds.endpoint
}

output "rds_database_name" {
  description = "Name of the initial database created on the RDS instance."
  value       = module.rds.database_name
}

output "rds_port" {
  description = "Port the RDS instance is listening on."
  value       = module.rds.port
}

# -----------------------------------------------------------------------------
# Bastion
# -----------------------------------------------------------------------------

output "bastion_public_ip" {
  description = "Public IP address of the production bastion host for SSH access."
  value       = module.bastion.public_ip
}

output "bastion_instance_id" {
  description = "EC2 instance ID of the production bastion host."
  value       = module.bastion.instance_id
}

# -----------------------------------------------------------------------------
# Account / Region Metadata
# -----------------------------------------------------------------------------

output "aws_account_id" {
  description = "AWS account ID where production resources are deployed."
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS region where production resources are deployed."
  value       = var.aws_region
}
