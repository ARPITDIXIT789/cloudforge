# =============================================================================
# CloudForge — Terraform Remote State Configuration
# =============================================================================
# This file configures an S3 backend with DynamoDB state locking for safe,
# concurrent Terraform operations across teams.
#
# Prerequisites:
#   1. Create the S3 bucket:        cloudforge-terraform-state
#   2. Create the DynamoDB table:   cloudforge-terraform-locks
#      - Partition key: LockID (String)
#   3. Enable versioning on the S3 bucket for state history.
#
# Update the bucket name and region below before running `terraform init`.
# =============================================================================

terraform {
  backend "s3" {
    bucket         = "cloudforge-terraform-state"
    key            = "cloudforge/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "cloudforge-terraform-locks"
    encrypt        = true
  }
}
