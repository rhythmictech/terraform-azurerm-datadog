########################################
# Naming / placement
########################################

variable "name" {
  description = "Moniker used to derive resource names and (optionally) the storage-account name."
  type        = string
}

variable "region" {
  description = <<-END
    Azure region for the forwarder resources; passed to the child module as
    `location`. Must match the region of every resource whose diagnostic setting
    targets this forwarder's storage account (a diagnostic setting can only
    reach a storage account in the same region), so deploy one forwarder per
    region.
  END
  type        = string
}

variable "resource_group_name" {
  description = "Name of an EXISTING resource group for the forwarder resources. The child module requires it to pre-exist (it is read via a data source, not created)."
  type        = string
}

variable "tags" {
  default     = {}
  description = "Tags applied to every resource the forwarder module creates (storage account, Container App environment, and job)."
  type        = map(string)
}

########################################
# Datadog API key (direct value OR Key Vault)
########################################

variable "datadog_api_key" {
  default     = null
  description = <<-END
    The Datadog API key value passed to the forwarder. Provide this OR the Key
    Vault pair (`key_vault_id` + `datadog_api_key_secret_name`), not both and not
    neither. It lands in Terraform state, so prefer the Key Vault path and rely
    on an encrypted state backend.
  END
  sensitive   = true
  type        = string

  validation {
    # Exactly one credential source: the direct key XOR the Key Vault path
    # (keyed off key_vault_id; the pair is validated together on key_vault_id).
    condition     = (var.datadog_api_key != null) != (var.key_vault_id != null)
    error_message = "Provide exactly one Datadog API key source: either datadog_api_key, or the key_vault_id + datadog_api_key_secret_name pair (not both, not neither)."
  }
}

variable "key_vault_id" {
  default     = null
  description = <<-END
    ARM id of an existing Key Vault holding the Datadog API key. Set together
    with `datadog_api_key_secret_name`; the wrapper reads the secret via a data
    source and passes the value through. Requires the deploying identity to hold
    Key Vault secret read access. Mutually exclusive with `datadog_api_key`.
  END
  type        = string

  validation {
    condition     = (var.key_vault_id == null) == (var.datadog_api_key_secret_name == null)
    error_message = "key_vault_id and datadog_api_key_secret_name must be set together (both null, or both non-null)."
  }
}

variable "datadog_api_key_secret_name" {
  default     = null
  description = "Name of the secret within `key_vault_id` that holds the Datadog API key. Must be set together with `key_vault_id`."
  type        = string
}

variable "datadog_site" {
  default     = "datadoghq.com"
  description = "Datadog site the forwarder ships logs to (US1 = `datadoghq.com`). Passed to the child module's `datadog_site`, which validates it against the supported site list."
  type        = string
}

########################################
# Storage account
########################################

variable "storage_account_name" {
  default     = null
  description = <<-END
    Override the forwarder storage-account name. `null` computes a safe,
    globally-unique default from `name`/`region` plus a short deterministic
    hash. If set, must be 3-24 lowercase alphanumeric characters ([a-z0-9]);
    storage-account names are global, so an override must itself be unique.
  END
  type        = string

  validation {
    condition     = var.storage_account_name == null || can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "storage_account_name must be null or 3-24 lowercase alphanumeric characters ([a-z0-9])."
  }
}

variable "storage_account_sku" {
  default     = "Standard_LRS"
  description = "SKU for the forwarder storage account, passed through to the child module (e.g. `Standard_LRS`)."
  type        = string
}

variable "storage_account_retention_days" {
  default     = 7
  description = "Days blobs are retained on the forwarder storage account before the child module's lifecycle policy deletes them. Must be at least 1."
  type        = number

  validation {
    condition     = var.storage_account_retention_days >= 1
    error_message = "storage_account_retention_days must be at least 1."
  }
}

########################################
# Forwarder container image
########################################

variable "forwarder_image" {
  default     = "datadoghq.azurecr.io/forwarder:v118199712-710f8585"
  description = <<-END
    Datadog's published forwarder container image, pinned to a specific tag for
    supply-chain reproducibility. The child module's own default floats on
    `:latest`; pinning here fixes it. Bump this tag deliberately alongside the
    child module version. The registry is Datadog's public ACR (anonymous pull).
  END
  type        = string

  validation {
    condition     = can(regex(":", var.forwarder_image)) && !endswith(var.forwarder_image, ":latest")
    error_message = "forwarder_image must be pinned to a specific tag or digest (not `:latest`)."
  }
}
