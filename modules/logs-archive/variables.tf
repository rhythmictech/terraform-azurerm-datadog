variable "name" {
  description = "Short name for this archive, used to derive resource names and as the default Datadog archive name."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{2,}$", var.name))
    error_message = "name must be lowercase alphanumeric with hyphens, at least 2 characters."
  }
}

variable "resource_group_name" {
  description = "Existing resource group that holds the archive storage account."
  type        = string
}

variable "region" {
  description = "Azure region for the archive storage account. Unlike the log forwarder, the archive has no co-regional constraint: `azure_archive` takes no region, so a single archive serves every region."
  type        = string
}

# Datadog integration identity. The archive is written by the SAME app
# registration used for the Azure integration; Datadog's own docs direct you to
# reuse it. No new Entra object is required, which matters where creating app
# registrations is a customer-side action.
variable "datadog_client_id" {
  description = "Client (application) id of the Datadog Azure integration app registration. Datadog authenticates to the archive container as this identity."
  type        = string
}

variable "datadog_tenant_id" {
  description = "Entra tenant id containing the Datadog app registration."
  type        = string
}

variable "datadog_sp_object_id" {
  default     = null
  description = "Object id of the Datadog app registration's service principal, used as the role-assignment principal. Required when `create_role_assignment` is true."
  type        = string

  validation {
    condition     = !var.create_role_assignment || var.datadog_sp_object_id != null
    error_message = "datadog_sp_object_id is required when create_role_assignment is true."
  }
}

variable "create_role_assignment" {
  default     = true
  description = "Grant the Datadog service principal `Storage Blob Data Contributor` on the archive storage account. This is a data-plane (DataAction) grant, so the applying identity needs RBAC write plus data-plane rights, not Lighthouse delegation. Set false when the grant is made out of band."
  type        = bool
}

variable "storage_account_name" {
  default     = null
  description = "Override the derived storage account name. Must be globally unique, 3 to 24 characters, lowercase alphanumeric only. Leave null to derive it from `name` plus a deterministic hash."
  type        = string

  validation {
    condition     = var.storage_account_name == null || can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "storage_account_name must be 3-24 lowercase alphanumeric characters."
  }
}

variable "container_name" {
  default     = "datadog-log-archive"
  description = "Blob container that receives the archive."
  type        = string
}

variable "storage_account_replication_type" {
  default     = "LRS"
  description = "Replication for the archive storage account. `GRS` or `GZRS` is worth considering for a two-year retention store, at roughly double the cost."
  type        = string

  validation {
    condition     = contains(["LRS", "GRS", "RAGRS", "ZRS", "GZRS", "RAGZRS"], var.storage_account_replication_type)
    error_message = "storage_account_replication_type must be one of LRS, GRS, RAGRS, ZRS, GZRS, RAGZRS."
  }
}

variable "shared_access_key_enabled" {
  default     = false
  description = <<-END
    Allow Shared Key (account key) authorization on the archive storage account.

    Defaults to **false**: Datadog writes the archive as the app registration over
    Entra auth, so account keys are not needed for the data path, and disabling
    them removes a long-lived credential from a store holding two years of logs.

    Two caller-side consequences of the default:

    - The applying identity manages the container over Entra data-plane auth, so
      the `azurerm` provider needs `storage_use_azuread = true` and the identity
      needs a blob data role. Without that, container creation fails.
    - The azurerm provider documents that **updating** `container_access_type`
      always uses Shared Key. This module only ever sets `private`, so that path
      is not exercised, but a caller who later changes it will need keys back on.

    Set true if either constraint is unacceptable.
  END
  type        = bool
}

variable "tier_to_cool_after_days" {
  default     = 90
  description = "Days after last modification before archive blobs move to the Cool tier."
  type        = number

  validation {
    condition     = var.tier_to_cool_after_days >= 1
    error_message = "tier_to_cool_after_days must be at least 1."
  }
}

variable "delete_after_days" {
  default     = 731
  description = "Days after last modification before archive blobs are deleted. Defaults to roughly two years, matching the retention of the AWS-side equivalent."
  type        = number

  validation {
    condition     = var.delete_after_days > var.tier_to_cool_after_days
    error_message = "delete_after_days must be greater than tier_to_cool_after_days, otherwise blobs are deleted before they ever tier and the cool-tier saving never materializes."
  }
}

variable "blob_soft_delete_retention_days" {
  default     = 7
  description = "Blob soft-delete retention window. Together with versioning this is the tamper-resistance mechanism used INSTEAD of an immutability policy; see the module README for why immutability is deliberately not offered."
  type        = number

  validation {
    condition     = var.blob_soft_delete_retention_days >= 1 && var.blob_soft_delete_retention_days <= 365
    error_message = "blob_soft_delete_retention_days must be between 1 and 365."
  }
}

variable "archive_name" {
  default     = null
  description = "Datadog archive name. Defaults to `name`."
  type        = string
}

variable "archive_query" {
  default     = "*"
  description = "Datadog log query selecting what this archive receives. `*` archives everything reaching the org, which is the usual intent for a retention archive. NOTE: archives in a Datadog org are ORDERED and the first match wins, so a broad query on a shared org can capture logs intended for another archive."
  type        = string
}

variable "archive_path" {
  default     = null
  description = "Optional prefix within the container for archived objects."
  type        = string
}

variable "include_tags" {
  default     = true
  description = "Store log tags in the archived records. Defaults true so rehydrated logs come back with their tags, which is what makes an archive searchable after the fact."
  type        = bool
}

variable "rehydration_tags" {
  default     = []
  description = "Tags applied to logs rehydrated from this archive, for distinguishing them from live ingestion."
  type        = list(string)
}

variable "rehydration_max_scan_size_in_gb" {
  default     = null
  description = "Cap on how much archived data a single rehydration may scan. null leaves it unlimited."
  type        = number
}

variable "tags" {
  default     = {}
  description = "Tags applied to the created Azure resources."
  type        = map(string)
}
