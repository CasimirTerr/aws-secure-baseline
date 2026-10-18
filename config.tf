# ---------------------------------------------------------------------------
# AWS Config: records what every resource looks like over time and
# continuously checks it against rules. GuardDuty catches *behavior*,
# Config catches *drift* (someone opens port 22 next month, Config notices).
# ---------------------------------------------------------------------------

resource "aws_iam_role" "config" {
  count = var.enable_config ? 1 : 0
  name  = "aws-config-recorder"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "config.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "config" {
  count      = var.enable_config ? 1 : 0
  role       = aws_iam_role.config[0].name
  policy_arn = "arn:${local.partition}:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_config_configuration_recorder" "main" {
  count    = var.enable_config ? 1 : 0
  name     = "default"
  role_arn = aws_iam_role.config[0].arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true # IAM users/roles/policies, only record these in one region
  }
}

resource "aws_config_delivery_channel" "main" {
  count          = var.enable_config ? 1 : 0
  name           = "default"
  s3_bucket_name = aws_s3_bucket.logs.id
  s3_key_prefix  = "config"

  snapshot_delivery_properties {
    delivery_frequency = "TwentyFour_Hours"
  }

  depends_on = [aws_config_configuration_recorder.main, aws_s3_bucket_policy.logs]
}

resource "aws_config_configuration_recorder_status" "main" {
  count      = var.enable_config ? 1 : 0
  name       = aws_config_configuration_recorder.main[0].name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.main]
}

# AWS managed rules. Picked the ones that map to the biggest real-world risks
# (and to my other two projects: iam-auditor and cloudtrail-threat-detector).
locals {
  config_rules = var.enable_config ? {
    "root-account-mfa-enabled"           = { id = "ROOT_ACCOUNT_MFA_ENABLED", params = null }
    "iam-user-mfa-enabled"               = { id = "IAM_USER_MFA_ENABLED", params = null }
    "mfa-enabled-for-iam-console-access" = { id = "MFA_ENABLED_FOR_IAM_CONSOLE_ACCESS", params = null }
    "access-keys-rotated"                = { id = "ACCESS_KEYS_ROTATED", params = { maxAccessKeyAge = "90" } }
    "iam-root-access-key-check"          = { id = "IAM_ROOT_ACCESS_KEY_CHECK", params = null }
    "iam-policy-no-admin-access"         = { id = "IAM_POLICY_NO_STATEMENTS_WITH_ADMIN_ACCESS", params = null }
    "cloudtrail-enabled"                 = { id = "CLOUD_TRAIL_ENABLED", params = null }
    "cloudtrail-log-validation"          = { id = "CLOUD_TRAIL_LOG_FILE_VALIDATION_ENABLED", params = null }
    "guardduty-enabled"                  = { id = "GUARDDUTY_ENABLED_CENTRALIZED", params = null }
    "s3-public-read-prohibited"          = { id = "S3_BUCKET_PUBLIC_READ_PROHIBITED", params = null }
    "s3-public-write-prohibited"         = { id = "S3_BUCKET_PUBLIC_WRITE_PROHIBITED", params = null }
    "s3-ssl-requests-only"               = { id = "S3_BUCKET_SSL_REQUESTS_ONLY", params = null }
    "restricted-ssh"                     = { id = "INCOMING_SSH_DISABLED", params = null }
    "ebs-encrypted-volumes"              = { id = "ENCRYPTED_VOLUMES", params = null }
  } : {}
}

resource "aws_config_config_rule" "managed" {
  for_each = local.config_rules

  name             = each.key
  input_parameters = each.value.params == null ? null : jsonencode(each.value.params)

  source {
    owner             = "AWS"
    source_identifier = each.value.id
  }

  depends_on = [aws_config_configuration_recorder_status.main]
}
