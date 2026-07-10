variable "target_resource_ids" {
  description = <<-END
    Map of `friendly_key => resource_id` for the resources that get the single
    diagnostic setting; drives `for_each`. Use static/config-derived values
    only (never a data-source or otherwise computed collection), so the key set
    is known at plan time. One instance applies one category config across all
    targets; heterogeneous targets need multiple instantiations.
  END
  type        = map(string)
}

variable "storage_account_id" {
  description = "Destination storage account id for the diagnostic setting, typically a log-forwarder module's `storage_account_id` output. It must be in the same region as each target resource."
  type        = string
}

variable "name" {
  default     = "rhythmic-datadog"
  description = "Name of the diagnostic setting created on each target. Azure keys diagnostic settings by name, so a distinct name never clobbers a customer-owned setting (there is a hard cap of 5 settings per resource)."
  type        = string
}

variable "log_category_groups" {
  default     = ["allLogs"]
  description = "Log category GROUPS to enable (rendered as `enabled_log { category_group = ... }`). `allLogs` captures every category the target supports."
  type        = list(string)
}

variable "log_categories" {
  default     = []
  description = "Individual log CATEGORIES to enable (rendered as `enabled_log { category = ... }`) for targets addressed by category rather than group."
  type        = list(string)
}

variable "metric_categories" {
  default     = ["AllMetrics"]
  description = "Metric categories to enable (rendered as `enabled_metric { category = ... }`). Set to `[]` where the target supports no metrics; at least one enabled_log or enabled_metric must remain."
  type        = list(string)

  validation {
    condition     = length(var.log_category_groups) > 0 || length(var.log_categories) > 0 || length(var.metric_categories) > 0
    error_message = "At least one of log_category_groups, log_categories, or metric_categories must be non-empty (a diagnostic setting needs at least one enabled log or metric)."
  }
}
