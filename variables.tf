########################################
# Naming / tagging
########################################

variable "name" {
  description = "Moniker to apply to the integration and created Azure resources (typically the client name)."
  type        = string
}

# No resource in this module accepts a tag map today (role assignments and app
# registrations are untagged); retained as a stable interface for tagged
# resources added by companion modules (e.g. the log forwarder).
# tflint-ignore: terraform_unused_declarations
variable "tags" {
  default     = {}
  description = "Tags applied to created Azure resources. (App registrations and role assignments do not carry tags.)"
  type        = map(string)
}

########################################
# Datadog org / provider-site
########################################

# Retained for interface parity; the datadog provider is configured with api_url
# by the consumer, so this value is not consumed by the module directly.
# tflint-ignore: terraform_unused_declarations
variable "datadog_site_name" {
  default     = "datadoghq.com"
  description = <<-END
    Datadog site (e.g. `datadoghq.com` for US1). NOTE: the `datadog` provider
    itself uses `api_url` (not a `site` argument); for US1
    `api_url = "https://api.datadoghq.com/"` (the provider default).
    Consumers/examples configure `api_url` on the provider block. This variable
    is retained for parity and any site-derived logic.
  END
  type        = string
}

########################################
# App-registration boundary (dual path)
########################################

variable "create_app_registration" {
  default     = false
  description = <<-END
    `false` (default): CONSUME a client-created Datadog app registration via the
    `datadog_*` vars below. `true`: this module CREATES the `azuread_application`
    + `service_principal` + `application_password` and requires an
    interactive/privileged identity with Microsoft Graph write (Application
    Administrator).

    Keep `false` on any pipeline whose deploying identity has no Graph access
    (`true` would fail at the azuread_* resources). Sandbox/self-service tenants
    only.
  END
  type        = bool
}

variable "datadog_client_id" {
  default     = null
  description = "Client (application) id of the client-created Datadog app registration. Required when create_app_registration = false; must be null when creating."
  type        = string

  validation {
    condition     = var.create_app_registration || var.datadog_client_id != null
    error_message = "datadog_client_id is required when create_app_registration = false (consume path)."
  }

  validation {
    condition     = !var.create_app_registration || var.datadog_client_id == null
    error_message = "datadog_client_id must be null when create_app_registration = true (the module derives it)."
  }
}

variable "datadog_tenant_id" {
  default     = null
  description = "Entra tenant id of the client tenant. Required when create_app_registration = false; must be null when creating."
  type        = string

  validation {
    condition     = var.create_app_registration || var.datadog_tenant_id != null
    error_message = "datadog_tenant_id is required when create_app_registration = false (consume path)."
  }

  validation {
    condition     = !var.create_app_registration || var.datadog_tenant_id == null
    error_message = "datadog_tenant_id must be null when create_app_registration = true (the module derives it)."
  }
}

variable "datadog_sp_object_id" {
  default     = null
  description = "Object id of the Datadog service principal (enterprise app). Used as principal_id for the Monitoring Reader assignment. Required when create_app_registration = false; must be null when creating."
  type        = string

  validation {
    condition     = var.create_app_registration || var.datadog_sp_object_id != null
    error_message = "datadog_sp_object_id is required when create_app_registration = false (consume path)."
  }

  validation {
    condition     = !var.create_app_registration || var.datadog_sp_object_id == null
    error_message = "datadog_sp_object_id must be null when create_app_registration = true (the module derives it)."
  }
}

variable "datadog_client_secret" {
  default     = null
  description = "Client secret of the client-created Datadog app registration. Required when create_app_registration = false unless secretless_auth_enabled = true; must be null when creating. Passed to datadog_integration_azure."
  sensitive   = true
  type        = string

  validation {
    condition     = var.create_app_registration || var.secretless_auth_enabled || var.datadog_client_secret != null
    error_message = "datadog_client_secret is required when create_app_registration = false (unless secretless_auth_enabled = true)."
  }

  validation {
    condition     = !var.create_app_registration || var.datadog_client_secret == null
    error_message = "datadog_client_secret must be null when create_app_registration = true (the module derives it)."
  }
}

variable "app_registration_display_name" {
  default     = null
  description = "Display name used only when create_app_registration = true. Default null -> the module computes `Datadog-<name>`."
  type        = string

  validation {
    condition     = var.app_registration_display_name == null || trimspace(coalesce(var.app_registration_display_name, " ")) != ""
    error_message = "app_registration_display_name must be null or a non-blank string (coalesce silently skips \"\")."
  }
}

variable "app_registration_password_end_date" {
  default     = null
  description = "Optional explicit RFC3339 end date for the created client secret (Azure caps app secrets at 730 days). Only used when create_app_registration = true; null lets Azure apply its default window."
  type        = string
}

########################################
# Role assignment (per-subscription)
########################################

variable "manage_datadog_sp_role_assignment" {
  default     = false
  description = <<-END
    `false` (default): the module does NOT assign Monitoring Reader to the Datadog
    SP -- assume it is pre-assigned out-of-band during onboarding by a
    higher-privilege identity. `true`: the module owns the assignment (the
    deploying identity must be allowed to assign roles to an external SP
    principal, and no matching assignment may pre-exist -- else HTTP 409).
  END
  type        = bool
}

variable "role_assignment_scopes" {
  description = <<-END
    Subscription scopes granted to the Datadog SP, e.g.
    ["/subscriptions/<sub-guid-a>","/subscriptions/<sub-guid-b>"]. Only used
    (for_each'd) when manage_datadog_sp_role_assignment = true. A management-group
    scope (/providers/Microsoft.Management/managementGroups/<id>) also works as a
    string; use per-subscription scopes when the tenant has no custom management group.
  END
  type        = list(string)
}

variable "role_definition_name" {
  default     = "Monitoring Reader"
  description = "Built-in role granted to the Datadog SP (least-privilege). Keep `Monitoring Reader`; it already grants the read access Datadog resource-collection needs. Constrained to read-only roles to prevent accidental escalation on a third-party principal."
  type        = string

  validation {
    condition     = contains(["Monitoring Reader", "Reader"], var.role_definition_name)
    error_message = "role_definition_name must be a read-only role (\"Monitoring Reader\" or \"Reader\"); granting a write/owner role to the external Datadog service principal violates least-privilege."
  }
}

variable "enable_log_archive_blob_role" {
  default     = false
  description = <<-END
    OPTIONAL: also grant `Storage Blob Data Contributor` to the Datadog SP for a
    log archive. Gated by manage_datadog_sp_role_assignment; off by default.
    WARNING: this reuses the subscription-level `role_assignment_scopes`, so
    flipping this flag grants blob read/WRITE/DELETE to the external Datadog SP
    across EVERY storage account in each subscription. Introduce a narrower,
    archive-specific scope before enabling this seam in production. Keep the role
    as Storage Blob Data Contributor (archives require write/delete).
  END
  type        = bool
}

########################################
# Integration collection flags + filters
########################################

variable "host_filters" {
  default     = ["datadog_managed:true"]
  description = "Tag filters controlling which Azure hosts Datadog monitors (noise control). Carries the `datadog_managed:true` convention. Rendered comma-joined for the resource."
  type        = list(string)
}

variable "app_service_plan_filters" {
  default     = []
  description = "Tag filters for App Service Plans (workloads running on App Service Plans). Rendered comma-joined; null when empty."
  type        = list(string)
}

variable "container_app_filters" {
  default     = []
  description = "Tag filters for Container Apps. Rendered comma-joined; null when empty."
  type        = list(string)
}

variable "automute" {
  default     = true
  description = "Auto-mute monitors for scaled-down/deleted Azure VMs. Provider default is false; this module opts to true."
  type        = bool
}

variable "enable_cspm" {
  default     = false
  description = "Cloud Security Posture Management. Maps to cspm_enabled. Requires enable_resource_collection = true (provider constraint, enforced by validation)."
  type        = bool

  validation {
    condition     = !var.enable_cspm || var.enable_resource_collection
    error_message = "enable_cspm = true requires enable_resource_collection = true (datadog_integration_azure provider constraint)."
  }
}

variable "enable_custom_metrics" {
  default     = false
  description = "Enable custom-metrics collection. Maps to custom_metrics_enabled."
  type        = bool
}

variable "enable_resource_collection" {
  default     = true
  description = "Collect Azure resource configuration. Maps to resource_collection_enabled."
  type        = bool
}

variable "metrics_enabled" {
  default     = true
  description = "Master Azure metrics collection toggle. Maps to metrics_enabled."
  type        = bool
}

variable "secretless_auth_enabled" {
  default     = false
  description = <<-END
    Preview passthrough. When true, Datadog authenticates via Entra
    workload-identity federation and `client_secret` is omitted (the native
    secretless/OIDC path). Keep false until the provider feature GAs.
  END
  type        = bool
}

########################################
# Main logs index (ported ~verbatim from AWS logs.tf)
########################################

variable "logs_manage_main_index" {
  default     = false
  description = "A boolean flag to manage the main Datadog logs index."
  type        = bool
}

variable "logs_main_index_daily_limit" {
  default     = null
  description = "Daily log limit for the main index (only used if logs_manage_main_index == true). null disables the daily limit."
  type        = number
}

variable "logs_main_index_daily_limit_reset_time" {
  default     = "00:00"
  description = "The reset time for the daily limit of the main logs index (specify as HH:MM)."
  type        = string
}

variable "logs_main_index_daily_limit_reset_offset" {
  default     = "+00:00"
  description = "The reset time timezone offset for the daily limit of the main logs index (specify as +HH:MM or -HH:MM)."
  type        = string
}

variable "logs_main_index_daily_limit_warn_threshold" {
  default     = 0.9
  description = "Warning threshold for daily log volume for the main index (only used if logs_manage_main_index == true)."
  type        = number
}

variable "logs_main_index_retention_days" {
  default     = 15
  description = "The number of days to retain logs in the main index (only used if logs_manage_main_index == true)."
  type        = number
}

variable "logs_main_index_exclusion_filters" {
  default     = []
  description = "A list of objects defining exclusion filters for the main index."
  type = list(object({
    name       = string
    is_enabled = bool
    filter = object({
      query       = string
      sample_rate = number
    })
  }))
}

########################################
# Estimated usage anomaly/threshold monitors (ported ~verbatim from AWS usage.tf)
########################################

variable "enable_estimated_usage_detection" {
  default     = false
  description = "Enable estimated usage anomaly and threshold monitoring."
  type        = bool
}

variable "estimated_usage_detection_default_config" {
  description = <<-END
    Map of default usage monitoring settings for each metric type. All are disabled by default.

    Anomaly monitoring uses Datadog's anomaly detection feature. See https://docs.datadoghq.com/monitors/types/anomaly/.

    Estimated usage monitoring uses simple thresholds on the `estimated_usage` metric family. By default, host thresholds
    are by day, as Datadog uses the peak instance count for the month on a 99th percentile basis. Log monitors are
    cumulative across the month, from the first day of the month at 00:00 UTC.
  END

  default = {
    hosts = {
      anomaly_enabled     = false
      anomaly_span        = "last_1d"
      anomaly_threshold   = 0.15
      anomaly_window      = "last_1h"
      anomaly_deviations  = 1
      anomaly_seasonality = "daily"
      anomaly_rollup      = 600

      estimated_usage_enabled   = false
      estimated_usage_span      = "current_1d"
      estimated_usage_threshold = 1000 # always override when using
    }
    logs_indexed = {
      anomaly_enabled     = false
      anomaly_span        = "last_1d"
      anomaly_threshold   = 0.15
      anomaly_window      = "last_1h"
      anomaly_deviations  = 2
      anomaly_seasonality = "hourly"
      anomaly_rollup      = 60

      estimated_usage_enabled   = false
      estimated_usage_span      = "current_1mo" # not recommended to change this
      estimated_usage_threshold = 1000          # always override when using
    }
    logs_ingested = {
      anomaly_enabled     = false
      anomaly_window      = "last_1h"
      anomaly_span        = "last_1d"
      anomaly_threshold   = 0.15
      anomaly_deviations  = 2
      anomaly_seasonality = "hourly"
      anomaly_rollup      = 60

      estimated_usage_enabled   = false
      estimated_usage_span      = "current_1mo" # not recommended to change this
      estimated_usage_threshold = 1000          # always override when using
    }
  }

  type = map(object({
    anomaly_enabled           = bool
    anomaly_span              = string
    anomaly_threshold         = number
    anomaly_window            = string
    anomaly_deviations        = number
    anomaly_seasonality       = string
    anomaly_rollup            = number
    estimated_usage_enabled   = bool
    estimated_usage_span      = optional(string)
    estimated_usage_threshold = number
  }))
}

variable "estimated_usage_detection_config" {
  default     = {}
  description = "Map of usage types to monitor; merged over estimated_usage_detection_default_config."
  type        = map(any)
}

variable "estimated_usage_anomaly_message" {
  default     = "Datadog usage anomaly detected"
  description = "Message for usage anomaly alerts."
  type        = string
}

variable "estimated_usage_threshold_message" {
  default     = "Datadog usage threshold exceeded"
  description = "Message for usage threshold alerts."
  type        = string
}

variable "log_limit_exceeded_message" {
  default     = null
  description = "Message for log limit warning alerts (alert suppressed if null)."
  type        = string
}

variable "renotify_interval" {
  default     = 30
  description = "Renotify interval for all usage alerts, in minutes (set to null to disable)."
  type        = number
}

variable "renotify_statuses" {
  default     = ["alert"]
  description = "Renotify statuses for all usage alerts (not used if renotify_interval is null)."
  type        = list(string)

  validation {
    condition     = alltrue([for s in var.renotify_statuses : contains(["alert", "no data", "warn"], s)])
    error_message = "The renotify_statuses must be a list of 'alert', 'no data', or 'warn'."
  }
}

########################################
# Health custom pipeline (Azure Service Health / Resource Health)
########################################

variable "manage_health_pipeline" {
  default     = false
  description = <<-END
    A boolean flag to manage the Datadog custom log pipeline that normalizes
    forwarded Azure Service Health / Resource Health records. When true, the
    pipeline remaps the affected service, message, and the health-classification
    attributes (incidentType, currentHealthStatus, cause) so downstream monitors
    can filter on stable `@properties.*` facets. Datadog custom pipelines are
    org-global, so enable this on exactly one instantiation.
  END
  type        = bool
}
