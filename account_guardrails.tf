# Account-wide settings. All free, all things that should honestly be on by default.

# Block public access for EVERY bucket in the account, current and future.
# Bucket-level settings can't override this, so nobody can make a bucket public by accident.
resource "aws_s3_account_public_access_block" "this" {
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# New EBS volumes and snapshots get encrypted automatically
resource "aws_ebs_encryption_by_default" "this" {
  enabled = true
}

# Password policy roughly following CIS AWS Foundations 1.8 / 1.9
resource "aws_iam_account_password_policy" "this" {
  minimum_password_length        = 14
  require_lowercase_characters   = true
  require_uppercase_characters   = true
  require_numbers                = true
  require_symbols                = true
  allow_users_to_change_password = true
  password_reuse_prevention      = 24
  max_password_age               = 90
}

# IAM Access Analyzer flags anything shared outside the account
# (public buckets, roles other accounts can assume, KMS keys, etc.)
resource "aws_accessanalyzer_analyzer" "account" {
  analyzer_name = "account-analyzer"
  type          = "ACCOUNT"
}
