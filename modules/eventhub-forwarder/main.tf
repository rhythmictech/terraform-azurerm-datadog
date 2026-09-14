locals {
  # Lowercase, alphanumeric-only slug of the caller's name. Storage account names
  # allow no hyphens and cap at 24 characters, so derive a <=18-char prefix plus a
  # 6-char deterministic hash for global uniqueness.
  name_slug = replace(lower(var.name), "/[^a-z0-9]/", "")

  storage_account_name = coalesce(
    var.storage_account_name,
    "${substr("${local.name_slug}ddfwd", 0, 18)}${substr(sha1(var.name), 0, 6)}"
  )

  function_app_name = coalesce(var.function_app_name, "${var.name}-datadog-forwarder")

  # The vendored forwarder package. PINNED: see function/PIN.md for the upstream
  # commit, the forwarder's own VERSION constant and the refresh procedure. The
  # Function App below refuses to plan if the file on disk does not match this
  # hash, so a silently swapped or corrupted package cannot be deployed.
  package_path   = "${path.module}/function/deploy.zip"
  package_sha256 = "65699f41c64d507af88d8256d8638491eddc9b4195218926e18a825767a6c64c"
  package_source = "DataDog/datadog-serverless-functions@8e5e22ac6d88f7f0b3204965ad8d7a080a8b50c1 azure/activity_logs_monitoring (index.js VERSION 2.2.0)"

  # The Function's environment contract, from the upstream index.js. Optional
  # overrides are merged in only when set so the upstream defaults apply.
  app_settings = merge(
    {
      DD_API_KEY                 = var.datadog_api_key
      DD_SITE                    = var.datadog_site
      DD_TAGS                    = join(",", var.datadog_tags)
      DD_PARSE_DEFENDER_LOGS     = var.parse_defender_logs ? "true" : "false"
      EVENTHUB_NAME              = var.event_hub_name
      EVENTHUB_CONNECTION_STRING = var.event_hub_connection_string
      # The package already carries node_modules, so it runs from the zip as
      # deployed; no remote build step.
      WEBSITE_RUN_FROM_PACKAGE = "1"
    },
    var.datadog_source == null ? {} : { DD_SOURCE = var.datadog_source },
    var.datadog_service == null ? {} : { DD_SERVICE = var.datadog_service },
  )
}

# Backing storage for the Function runtime. Hardened: TLS 1.2 floor, HTTPS only,
# no public blob access, infrastructure encryption.
#
# A Y1 consumption Function App reaches its backing storage (content share, run
# state) over the public endpoint, and the Functions runtime is not covered by
# the storage account's trusted-service bypass, so a Deny network default action
# would break the Function. Access stays gated on account keys held only by the
# Function's own configuration.
#
# Trivy ignores are deliberate tradeoffs for an ephemeral Function runtime store:
#   avd-azu-0012: public reachability is required by the consumption runtime.
#   avd-azu-0057: request-level diagnostics belong on Azure Monitor diagnostic
#                 settings, not legacy Storage Analytics logging.
#   avd-azu-0058: LRS is a deliberate cost choice; the contents are ephemeral
#                 runtime state, not data needing geo-redundancy.
# avd-azu-0012 additionally needs the repo-root `.trivyignore`, because the trivy
# version CI pins does not honor the inline form for that check.
#trivy:ignore:avd-azu-0012
#trivy:ignore:avd-azu-0057
#trivy:ignore:avd-azu-0058
resource "azurerm_storage_account" "function" {
  name                = local.storage_account_name
  resource_group_name = var.resource_group_name
  location            = var.location

  account_tier             = "Standard"
  account_replication_type = "LRS"

  min_tls_version                   = "TLS1_2"
  https_traffic_only_enabled        = true
  allow_nested_items_to_be_public   = false
  infrastructure_encryption_enabled = true

  tags = var.tags
}

# Linux consumption plan (Y1): the forwarder is event-driven and idle between
# batches, so consumption keeps it close to free.
resource "azurerm_service_plan" "this" {
  name                = local.function_app_name
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "Y1"
  tags                = var.tags
}

# Datadog's Event Hub log forwarder, deployed from the vendored, hash-pinned
# package. The Function registers its own Event Hub trigger in code (v4
# programming model): EVENTHUB_NAME on consumer group `$Default`, connection
# taken from the EVENTHUB_CONNECTION_STRING app setting.
resource "azurerm_linux_function_app" "this" {
  name                = local.function_app_name
  resource_group_name = var.resource_group_name
  location            = var.location
  service_plan_id     = azurerm_service_plan.this.id

  storage_account_name       = azurerm_storage_account.function.name
  storage_account_access_key = azurerm_storage_account.function.primary_access_key
  https_only                 = true

  functions_extension_version = "~4"

  site_config {
    application_stack {
      node_version = "20"
    }
  }

  app_settings = local.app_settings

  zip_deploy_file = local.package_path

  tags = var.tags

  lifecycle {
    precondition {
      condition     = filesha256(local.package_path) == local.package_sha256
      error_message = "function/deploy.zip does not match the pinned sha256 (${local.package_sha256}). Refresh the pin deliberately per function/PIN.md, or restore the vendored package."
    }
  }
}
