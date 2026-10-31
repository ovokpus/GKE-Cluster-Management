# S3 bucket (+ optional DynamoDB lock table) for the Terraform s3 backend.
# Terraform >= 1.10 can lock with S3 itself (use_lockfile = true); the DynamoDB
# table is kept for older Terraform versions and existing setups.
variable "bucket_name" { type = string }
variable "lock_table_name" {
  description = "Set to null to skip the DynamoDB table and use S3 native locking."
  type        = string
  default     = "terraform-locks"
}

resource "aws_s3_bucket" "state" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "locks" {
  count        = var.lock_table_name == null ? 0 : 1
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
  point_in_time_recovery {
    enabled = true
  }
  server_side_encryption {
    enabled = true
  }
}

output "bucket" { value = aws_s3_bucket.state.bucket }
output "lock_table" { value = var.lock_table_name }
