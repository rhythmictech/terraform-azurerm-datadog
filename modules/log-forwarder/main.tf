# Optional Key Vault source for the Datadog API key. When key_vault_id is set,
# read the secret and pass its value through; otherwise the direct var is used.
data "azurerm_key_vault_secret" "dd" {
  count = var.key_vault_id != null ? 1 : 0

  name         = var.datadog_api_key_secret_name
  key_vault_id = var.key_vault_id
}

# Thin wrapper around Datadog's official forwarder submodule (Container App job +
# Storage; blob micro-batch transport). Datadog maintains the forwarder; callers
# keep ownership of their own diagnostic settings, which target the re-exported
# storage_account_id. Pinned exactly (young module) and bumped deliberately.
module "forwarder" {
  source  = "DataDog/log-forwarding-datadog/azurerm//modules/forwarder"
  version = "1.0.1"

  resource_group_name            = var.resource_group_name
  location                       = var.region
  storage_account_name           = local.storage_account_name
  environment_name               = local.forwarder_env_name # uniquified per region (child defaults to a static name)
  job_name                       = local.forwarder_job_name # so multiple regional forwarders can share one resource group
  storage_account_sku            = var.storage_account_sku
  storage_account_retention_days = var.storage_account_retention_days
  forwarder_image                = var.forwarder_image
  datadog_api_key                = local.datadog_api_key
  datadog_site                   = var.datadog_site
  tags                           = var.tags
}
