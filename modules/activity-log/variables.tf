variable "subscription_id" {
  description = "Subscription whose Activity Log is exported. The setting is created at scope `/subscriptions/<subscription_id>` unless `target_scope_override` is set."
  type        = string
}

variable "target_scope_override" {
  default     = null
  description = "Optional scope override, e.g. a management group `/providers/Microsoft.Management/managementGroups/<id>`. `null` uses the subscription scope derived from `subscription_id`."
  type        = string
}

variable "storage_account_id" {
  description = "Destination storage account id, typically a log-forwarder's `storage_account_id` output. The Activity Log scope is global, so the storage may be in any region."
  type        = string
}

variable "name" {
  default     = "rhythmic-datadog"
  description = "Name of the Activity Log (and optional directory) diagnostic setting. A distinct name is non-clobbering."
  type        = string
}

variable "activity_log_categories" {
  default     = ["Administrative", "Security", "ServiceHealth", "Alert", "Recommendation", "Policy", "Autoscale", "ResourceHealth"]
  description = "Activity Log categories to export (rendered as `enabled_log { category = ... }`)."
  type        = list(string)

  validation {
    condition     = length(var.activity_log_categories) > 0
    error_message = "activity_log_categories must contain at least one category."
  }
}

variable "enable_entra_diagnostics" {
  default     = false
  description = <<-END
    Ship the tenant directory (sign-in / audit) diagnostic setting. Default OFF.
    The directory setting is a tenant-wide operation and requires the deploying
    identity to hold a directory role that can manage directory diagnostic
    settings (a Security Administrator or Global Administrator directory role),
    granted out-of-band as a one-time bootstrap; it is not a subscription ARM
    role assignment.
  END
  type        = bool
}

variable "entra_log_categories" {
  default     = ["SignInLogs", "AuditLogs", "NonInteractiveUserSignInLogs", "ServicePrincipalSignInLogs"]
  description = "Directory diagnostic categories to export when `enable_entra_diagnostics = true`. Several categories require a directory premium (P1/P2) license; validate availability against the live tenant before enabling."
  type        = list(string)
}
