variable "name" {
  description = "Short name for this forwarder, used to derive the Function App, plan and storage account names."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{2,}$", var.name))
    error_message = "name must be lowercase alphanumeric with hyphens, at least 2 characters."
  }
}

variable "resource_group_name" {
  description = "Existing resource group that receives the Function App, its plan and its storage account."
  type        = string
}

variable "location" {
  description = "Azure region for the Function App. Event Hub triggers work across regions, but co-locating with the hub avoids egress."
  type        = string
}

variable "event_hub_name" {
  description = "Name of the Event Hub (topic) the Function consumes. Passed to the Function as EVENTHUB_NAME."
  type        = string
}

variable "event_hub_connection_string" {
  description = "Connection string of a LISTEN-only authorization rule on the hub or its namespace. Never pass a send or manage credential: the consumer must not be able to write to the hub. Passed to the Function as EVENTHUB_CONNECTION_STRING."
  type        = string
  sensitive   = true
}

variable "datadog_api_key" {
  description = "Datadog API key the Function submits logs with."
  type        = string
  sensitive   = true
}

variable "datadog_site" {
  description = "Datadog site the Function submits to (`datadoghq.com` for US1). Passed as DD_SITE."
  type        = string
  default     = "datadoghq.com"
}

variable "datadog_tags" {
  description = "Tags appended to every forwarded log, passed to the Function as the comma-joined DD_TAGS."
  type        = list(string)
  default     = []
}

variable "parse_defender_logs" {
  description = "Enable the forwarder's built-in Microsoft Defender for Cloud parsing, which sets `source:microsoft-defender-for-cloud` and a `service` of SecurityAlerts, SecurityRecommendations, SecurityFindings or SecureScore per record. Passed as DD_PARSE_DEFENDER_LOGS."
  type        = bool
  default     = true
}

variable "datadog_source" {
  description = "Optional override for the source the forwarder assigns to records it cannot classify from their resource id (`azure` by default). Passed as DD_SOURCE when set."
  type        = string
  default     = null
}

variable "datadog_service" {
  description = "Optional service tag the forwarder assigns to records it cannot classify. Passed as DD_SERVICE when set."
  type        = string
  default     = null
}

variable "function_app_name" {
  description = "Override the derived Function App name. Function App names are global DNS names (`<name>.azurewebsites.net`); leave null to derive `<name>-datadog-forwarder`."
  type        = string
  default     = null

  validation {
    condition     = var.function_app_name == null || can(regex("^[a-z0-9][a-z0-9-]{0,58}[a-z0-9]$", var.function_app_name))
    error_message = "function_app_name must be 2-60 lowercase alphanumeric characters or hyphens, starting and ending alphanumeric."
  }
}

variable "storage_account_name" {
  description = "Override the derived storage account name for the Function runtime. Must be globally unique, 3 to 24 characters, lowercase alphanumeric only. Leave null to derive it from `name` plus a deterministic hash."
  type        = string
  default     = null

  validation {
    condition     = var.storage_account_name == null || can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "storage_account_name must be 3-24 lowercase alphanumeric characters."
  }
}

variable "tags" {
  description = "Tags applied to the created Azure resources."
  type        = map(string)
  default     = {}
}
