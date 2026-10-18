# ---------------------------------------------------------------------------
# GuardDuty + email alerts for the serious findings
# ---------------------------------------------------------------------------

resource "aws_guardduty_detector" "main" {
  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"
}

# S3 protection watches data events on buckets for things like mass downloads
resource "aws_guardduty_detector_feature" "s3" {
  detector_id = aws_guardduty_detector.main.id
  name        = "S3_DATA_EVENTS"
  status      = "ENABLED"
}

resource "aws_sns_topic" "security_alerts" {
  name = "security-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.security_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# EventBridge needs explicit permission to publish to the topic
data "aws_iam_policy_document" "sns_alerts" {
  statement {
    sid       = "AllowEventBridge"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.security_alerts.arn]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }

  statement {
    sid       = "AllowBudgets"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.security_alerts.arn]

    principals {
      type        = "Service"
      identifiers = ["budgets.amazonaws.com"]
    }
  }
}

resource "aws_sns_topic_policy" "security_alerts" {
  arn    = aws_sns_topic.security_alerts.arn
  policy = data.aws_iam_policy_document.sns_alerts.json
}

# Only page me for High/Critical. Medium and Low I can check in the console.
resource "aws_cloudwatch_event_rule" "guardduty_high" {
  name        = "guardduty-high-severity"
  description = "GuardDuty findings >= ${var.guardduty_alert_min_severity} go to email"

  event_pattern = jsonencode({
    source        = ["aws.guardduty"]
    "detail-type" = ["GuardDuty Finding"]
    detail = {
      severity = [{ numeric = [">=", var.guardduty_alert_min_severity] }]
    }
  })
}

resource "aws_cloudwatch_event_target" "guardduty_to_sns" {
  rule = aws_cloudwatch_event_rule.guardduty_high.name
  arn  = aws_sns_topic.security_alerts.arn

  # turn the giant finding JSON into something readable in an email
  input_transformer {
    input_paths = {
      severity = "$.detail.severity"
      type     = "$.detail.type"
      title    = "$.detail.title"
      account  = "$.detail.accountId"
      region   = "$.detail.region"
      id       = "$.detail.id"
    }
    input_template = "\"GuardDuty finding (severity <severity>) in <account> / <region>: <title>. Type: <type>. Finding ID: <id>\""
  }
}

# ---------------------------------------------------------------------------
# Security Hub - pulls GuardDuty, Config, Access Analyzer into one place
# and scores the account against CIS + AWS best practices
# ---------------------------------------------------------------------------

resource "aws_securityhub_account" "main" {
  count = var.enable_securityhub ? 1 : 0

  enable_default_standards = false # I'd rather pick the standards myself below
}

resource "aws_securityhub_standards_subscription" "cis" {
  count         = var.enable_securityhub ? 1 : 0
  standards_arn = "arn:${local.partition}:securityhub:${local.region}::standards/cis-aws-foundations-benchmark/v/1.4.0"

  depends_on = [aws_securityhub_account.main]
}

resource "aws_securityhub_standards_subscription" "aws_foundational" {
  count         = var.enable_securityhub ? 1 : 0
  standards_arn = "arn:${local.partition}:securityhub:${local.region}::standards/aws-foundational-security-best-practices/v/1.0.0"

  depends_on = [aws_securityhub_account.main]
}
