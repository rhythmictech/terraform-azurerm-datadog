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

# One regional forwarder. The Datadog API key is sourced from an existing Key
# Vault (preferred over passing the plaintext value), and the storage-account
# name is derived automatically. Deploy one instance per region.
module "log_forwarder" {
  source = "../../modules/log-forwarder"

  name                = "example-client"
  region              = var.region
  resource_group_name = var.resource_group_name

  # Source the Datadog API key from Key Vault (single source of truth).
  key_vault_id                = var.key_vault_id
  datadog_api_key_secret_name = var.datadog_api_key_secret_name

  tags = {
    managed_by = "terraform"
    module     = "terraform-azurerm-datadog"
  }
}
