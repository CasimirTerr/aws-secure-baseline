# Bootstrap: creates the S3 bucket that holds Terraform state for the main baseline.
#
# This lives in its own folder because of the chicken-and-egg problem: the main
# config stores its state in this bucket, so the bucket has to exist first.
# Run this once with local state, then never really touch it again.

terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "aws-secure-baseline"
      ManagedBy = "terraform"
    }
  }
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

data "aws_caller_identity" "me" {}

locals {
  # account id in the name so it's globally unique without me having to think about it
  state_bucket = "tf-state-${data.aws_caller_identity.me.account_id}-${var.aws_region}"
}

resource "aws_s3_bucket" "state" {
  bucket = local.state_bucket

  # state files are the one thing you really don't want to delete by accident
  lifecycle {
    prevent_destroy = true
  }
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
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# state can contain secrets in plain text, so no unencrypted connections allowed
data "aws_iam_policy_document" "state" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.state.arn, "${aws_s3_bucket.state.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = data.aws_iam_policy_document.state.json

  depends_on = [aws_s3_bucket_public_access_block.state]
}

output "state_bucket" {
  value       = aws_s3_bucket.state.id
  description = "Put this in backend.hcl in the root folder"
}
