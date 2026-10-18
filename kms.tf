# Customer-managed KMS key for CloudTrail logs.
# Costs $1/month. Worth it: I control who can decrypt, rotation is on,
# and every use of the key shows up in CloudTrail itself.

resource "aws_kms_key" "logs" {
  description             = "Encrypts CloudTrail log files"
  enable_key_rotation     = true
  deletion_window_in_days = 30
}

resource "aws_kms_alias" "logs" {
  name          = "alias/cloudtrail-logs"
  target_key_id = aws_kms_key.logs.key_id
}

data "aws_iam_policy_document" "kms_logs" {
  # Without this statement the key can lock *me* out. Classic KMS mistake.
  statement {
    sid       = "AccountAdmins"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:${local.partition}:iam::${local.account_id}:root"]
    }
  }

  statement {
    sid       = "CloudTrailEncrypt"
    actions   = ["kms:GenerateDataKey*"]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }

    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:aws:cloudtrail:arn"
      values   = ["arn:${local.partition}:cloudtrail:*:${local.account_id}:trail/*"]
    }
  }

  statement {
    sid       = "CloudTrailDescribeKey"
    actions   = ["kms:DescribeKey"]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }

  # lets people in this account read the logs IF they also have IAM permission to
  statement {
    sid       = "AllowLogDecryptionInAccount"
    actions   = ["kms:Decrypt", "kms:ReEncryptFrom"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:CallerAccount"
      values   = [local.account_id]
    }

    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:aws:cloudtrail:arn"
      values   = ["arn:${local.partition}:cloudtrail:*:${local.account_id}:trail/*"]
    }
  }
}

resource "aws_kms_key_policy" "logs" {
  key_id = aws_kms_key.logs.id
  policy = data.aws_iam_policy_document.kms_logs.json
}
