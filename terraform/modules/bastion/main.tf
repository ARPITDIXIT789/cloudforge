###############################################################################
# CloudForge — Bastion Module
# Hardened bastion host in public subnet for SSH access
# Ingress restricted to admin_cidr only
###############################################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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
# Data Source — Amazon Linux 2023 AMI (latest)
# ---------------------------------------------------------------------------
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# ---------------------------------------------------------------------------
# Security Group — SSH from admin CIDR only
# ---------------------------------------------------------------------------
resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-${var.environment}-bastion-sg"
  description = "Bastion host security group — SSH from admin CIDR only"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-bastion-sg"
  })
}

resource "aws_security_group_rule" "bastion_ssh_ingress" {
  description       = "SSH access from admin CIDR"
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [var.admin_cidr]
  security_group_id = aws_security_group.bastion.id
}

resource "aws_security_group_rule" "bastion_egress_all" {
  description       = "Allow all outbound traffic"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.bastion.id
}

# ---------------------------------------------------------------------------
# Bastion EC2 Instance
# ---------------------------------------------------------------------------
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  key_name               = var.key_name

  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    set -euo pipefail

    # Update system packages
    dnf update -y

    # Install essential utilities
    dnf install -y \
      git \
      jq \
      unzip \
      curl \
      wget \
      tar \
      htop \
      tmux \
      vim \
      postgresql16 \
      amazon-ssm-agent

    # Install AWS CLI v2
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
    unzip -qo /tmp/awscliv2.zip -d /tmp
    /tmp/aws/install --update
    rm -rf /tmp/aws /tmp/awscliv2.zip

    # Install kubectl
    curl -fsSLO "https://dl.k8s.io/release/v1.30.0/bin/linux/amd64/kubectl"
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm -f kubectl

    # Enable and start SSM Agent
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent

    # Harden SSH — disable password authentication
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    systemctl restart sshd

    echo "Bastion bootstrap complete"
  EOF

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"   # Enforce IMDSv2
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = merge(local.common_tags, {
    Name = "bastion-${var.project_name}-${var.environment}"
  })

  lifecycle {
    ignore_changes = [ami]
  }
}
