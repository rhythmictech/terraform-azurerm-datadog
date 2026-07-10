terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# azurerm v4 makes subscription_id mandatory in the provider block.
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# A regional forwarder provides the storage destination.
module "log_forwarder" {
  source = "../../modules/log-forwarder"

  name                = "example-client"
  region              = var.region
  resource_group_name = var.resource_group_name

  key_vault_id                = var.key_vault_id
  datadog_api_key_secret_name = var.datadog_api_key_secret_name

  tags = {
    managed_by = "terraform"
    module     = "terraform-azurerm-datadog"
  }
}

# Export the subscription Activity Log to the forwarder's storage account. The
# optional tenant directory (Entra) setting is left off (its default).
module "activity_log" {
  source = "../../modules/activity-log"

  subscription_id    = var.subscription_id
  storage_account_id = module.log_forwarder.storage_account_id
}
