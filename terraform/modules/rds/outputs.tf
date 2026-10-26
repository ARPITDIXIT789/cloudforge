###############################################################################
# CloudForge — RDS Module Outputs
###############################################################################

output "db_endpoint" {
  description = "The connection endpoint of the RDS instance (host:port)."
  value       = aws_db_instance.this.endpoint
}

output "endpoint" {
  description = "Alias for db_endpoint."
  value       = aws_db_instance.this.endpoint
}

output "db_name" {
  description = "The name of the database."
  value       = aws_db_instance.this.db_name
}

output "database_name" {
  description = "Alias for db_name."
  value       = aws_db_instance.this.db_name
}

output "db_port" {
  description = "The port the database is listening on."
  value       = aws_db_instance.this.port
}

output "port" {
  description = "Alias for db_port."
  value       = aws_db_instance.this.port
}

output "db_secret_arn" {
  description = "ARN of the Secrets Manager secret containing DB credentials."
  value       = aws_secretsmanager_secret.db.arn
}

output "db_instance_id" {
  description = "The RDS instance identifier."
  value       = aws_db_instance.this.id
}
