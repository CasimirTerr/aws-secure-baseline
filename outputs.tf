output "log_bucket" {
  value = aws_s3_bucket.logs.id
}

output "cloudtrail_arn" {
  value = aws_cloudtrail.main.arn
}

output "cloudtrail_kms_key" {
  value = aws_kms_alias.logs.name
}

output "guardduty_detector_id" {
  value = aws_guardduty_detector.main.id
}

output "security_alerts_topic" {
  value = aws_sns_topic.security_alerts.arn
}

output "config_rules" {
  value = keys(aws_config_config_rule.managed)
}

output "next_steps" {
  value = <<-EOT
    1. Confirm the SNS subscription email AWS just sent you.
    2. Security Hub takes a few hours to score the account. Check it tomorrow.
    3. Run aws-iam-auditor against this account (see README).
  EOT
}
