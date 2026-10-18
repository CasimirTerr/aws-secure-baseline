variable "aws_region" {
  description = "Region for everything. us-east-1 because that's where global events (IAM, sign-ins) land."
  type        = string
  default     = "us-east-1"
}

variable "owner" {
  description = "Goes in the Owner tag on everything."
  type        = string
  default     = "casimir"
}

variable "alert_email" {
  description = "Where budget alerts and high-severity GuardDuty findings get sent."
  type        = string
}

variable "monthly_budget_usd" {
  description = "Monthly spend limit for the budget alerts."
  type        = number
  default     = 10
}

variable "log_retention_days" {
  description = "How long to keep CloudTrail and Config logs in S3."
  type        = number
  default     = 365
}

# Config and Security Hub are the two pieces that actually cost money after the free trial,
# so they can be switched off if I'm just testing.
variable "enable_config" {
  description = "Turn on AWS Config recording + compliance rules (a few cents to a couple dollars a month in a small account)."
  type        = bool
  default     = true
}

variable "enable_securityhub" {
  description = "Turn on Security Hub with the CIS and AWS Foundational benchmarks. Needs Config on to be useful."
  type        = bool
  default     = true
}

variable "guardduty_alert_min_severity" {
  description = "GuardDuty findings at or above this severity get emailed. 7 = High, 4 = Medium."
  type        = number
  default     = 7
}

variable "lab_mode" {
  description = "If true, the log bucket can be destroyed with logs still in it. Set false for a real account."
  type        = bool
  default     = true
}
