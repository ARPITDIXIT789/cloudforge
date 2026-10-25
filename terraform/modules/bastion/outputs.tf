###############################################################################
# CloudForge — Bastion Module Outputs
###############################################################################

output "bastion_public_ip" {
  description = "The public IP address of the bastion host."
  value       = aws_instance.bastion.public_ip
}

output "bastion_instance_id" {
  description = "The EC2 instance ID of the bastion host."
  value       = aws_instance.bastion.id
}

output "bastion_security_group_id" {
  description = "Security group ID attached to the bastion host."
  value       = aws_security_group.bastion.id
}
