variable "resource_types" {
  description = <<-END
    Azure resource types to discover, e.g. `["Microsoft.Web/sites",
    "Microsoft.Sql/servers/databases"]`. Each is queried across the whole
    subscription the provider is configured for.

    `Microsoft.Storage/storageAccounts` is special-cased: Azure exposes storage
    diagnostic settings only on the child service scopes, so a storage account is
    expanded into `var.storage_services` and the account itself never receives a
    setting.
  END
  type        = list(string)

  validation {
    condition     = length(var.resource_types) > 0
    error_message = "resource_types must list at least one type; an empty list would discover nothing."
  }
}

variable "storage_account_ids_by_region" {
  description = <<-END
    Destination storage account id per region, e.g.
    `{ eastus = "/subscriptions/.../ddlogseastus" }`. A diagnostic setting can
    only target a storage account in the monitored resource's OWN region, so one
    destination per region is required rather than one overall.

    Keys are matched case- and space-insensitively, so `"East US"` and `"eastus"`
    are equivalent. Any region that has discovered scopes but no entry here is
    reported in the `unmapped_regions` output and, unless
    `fail_on_unmapped_region` is false, fails the plan.
  END
  type        = map(string)
}

variable "name" {
  default     = "rhythmic-datadog"
  description = "Name of the diagnostic setting created on each discovered scope. Azure keys diagnostic settings by name, so a distinct name never clobbers a customer-owned setting (there is a hard cap of 5 settings per scope)."
  type        = string

  validation {
    condition     = length(trimspace(var.name)) > 0
    error_message = "name must be non-empty."
  }
}

variable "log_category_groups" {
  default     = ["allLogs"]
  description = "Log category GROUPS to enable (rendered as `enabled_log { category_group = ... }`). `allLogs` captures every category the scope supports, which keeps coverage correct as Azure adds categories. Set to `[]` and use `log_categories` for any type that rejects the group."
  type        = list(string)
}

variable "log_categories" {
  default     = []
  description = "Individual log CATEGORIES to enable (rendered as `enabled_log { category = ... }`). Only useful when every discovered type supports the same category names, so prefer `log_category_groups` for heterogeneous discovery."
  type        = list(string)
}

variable "metric_categories" {
  default     = []
  description = <<-END
    Metric categories to enable (rendered as `enabled_metric { category = ... }`).

    Defaults to `[]`, unlike the sibling `diagnostic-setting` module. This module
    routes to a blob destination consumed by a log forwarder, and platform
    metrics normally reach Datadog through the metrics integration instead;
    enabling `AllMetrics` across a whole discovered estate duplicates that data
    at cost. Set explicitly if the blob path really is the intended metric route.
  END
  type        = list(string)

  validation {
    condition     = length(var.log_category_groups) > 0 || length(var.log_categories) > 0 || length(var.metric_categories) > 0
    error_message = "At least one of log_category_groups, log_categories, or metric_categories must be non-empty (a diagnostic setting needs at least one enabled log or metric)."
  }
}

variable "storage_services" {
  default     = ["blobServices", "fileServices", "queueServices", "tableServices"]
  description = "Storage sub-service scopes to expand each discovered storage account into. Azure attaches storage diagnostic settings to `<account-id>/<service>/default`, never to the account id, so enumerating accounts alone silently monitors nothing."
  type        = list(string)

  validation {
    condition = length(setsubtract(
      toset(var.storage_services),
      toset(["blobServices", "fileServices", "queueServices", "tableServices"])
    )) == 0
    error_message = "storage_services entries must be one of blobServices, fileServices, queueServices, tableServices."
  }
}

variable "required_tags" {
  default     = {}
  description = "Tag filter applied to discovery; only resources carrying all of these tag key/value pairs are matched. Empty (the default) discovers everything of the given types, which is the correct starting point for an untagged estate but is also unbounded, so prefer scoping once a tagging convention exists."
  type        = map(string)
}

variable "exclude_resource_groups" {
  default     = []
  description = "Resource group names to exclude from discovery. Matched case-insensitively. Typically the group holding the log-forwarding infrastructure itself, so the forwarder does not monitor its own storage."
  type        = list(string)
}

variable "exclude_resource_ids" {
  default     = []
  description = "Individual resource ids to exclude from discovery, for carve-outs that a type or resource-group filter cannot express. For a storage account, excluding the ACCOUNT id removes all of its expanded service scopes."
  type        = list(string)
}

variable "fail_on_unmapped_region" {
  default     = true
  description = "Fail the plan when a discovered scope sits in a region with no entry in `storage_account_ids_by_region`. Defaults to true because the alternative is silently leaving those resources unmonitored, which looks identical to success. Set false only to deliberately, and visibly, monitor a subset of regions."
  type        = bool
}
