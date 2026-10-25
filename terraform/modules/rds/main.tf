###############################################################################
# CloudForge — RDS Module
# Production-grade PostgreSQL with Secrets Manager integration
# Placed in isolated subnets; access limited to EKS node security group
###############################################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

# ---------------------------------------------------------------------------
# Local values
# ---------------------------------------------------------------------------
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ---------------------------------------------------------------------------
# Random password for RDS master user
# ---------------------------------------------------------------------------
resource "random_password" "db" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# ---------------------------------------------------------------------------
# AWS Secrets Manager — store database credentials
# ---------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "db" {
  name                    = "${var.project_name}/${var.environment}/rds/${var.identifier}"
  description             = "Master credentials for RDS instance ${var.identifier}"
  recovery_window_in_days = 7

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-rds-secret"
  })
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id

  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db.result
    engine   = "postgres"
    host     = aws_db_instance.this.address
    port     = aws_db_instance.this.port
    dbname   = var.db_name
  })
}

# ---------------------------------------------------------------------------
# DB Subnet Group — isolated subnets only
# ---------------------------------------------------------------------------
resource "aws_db_subnet_group" "this" {
  name        = "${var.project_name}-${var.environment}-db-subnet-group"
  description = "Isolated subnet group for RDS"
  subnet_ids  = var.isolated_subnet_ids

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-db-subnet-group"
  })
}

# ---------------------------------------------------------------------------
# Security Group — ingress ONLY from EKS nodes on port 5432
# ---------------------------------------------------------------------------
resource "aws_security_group" "db" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "Allow PostgreSQL access from EKS worker nodes only"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-rds-sg"
  })
}

resource "aws_security_group_rule" "db_ingress_eks" {
  description              = "PostgreSQL access from EKS worker nodes"
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = var.eks_node_security_group_id
  security_group_id        = aws_security_group.db.id
}

resource "aws_security_group_rule" "db_egress_none" {
  description       = "Deny all outbound (RDS does not initiate connections)"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.db.id
}

# ---------------------------------------------------------------------------
# RDS Instance — PostgreSQL 16
# ---------------------------------------------------------------------------
resource "aws_db_instance" "this" {
  identifier = "${var.project_name}-${var.environment}-${var.identifier}"

  # Engine
  engine         = "postgres"
  engine_version = var.engine_version

  # Instance & Storage
  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  # Database
  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result

  # Networking
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]
  multi_az               = var.multi_az
  publicly_accessible    = false

  # Backup & Maintenance
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:30-sun:05:30"

  # Snapshot
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.project_name}-${var.environment}-${var.identifier}-final"

  # Lifecycle protection
  lifecycle {
    prevent_destroy = true
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-${var.identifier}"
  })
}
