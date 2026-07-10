variable "subscription_id" {
  description = "Azure subscription id for the azurerm provider (mandatory on azurerm v4)."
  type        = string
}

variable "region" {
  description = "Azure region for the forwarder (deploy one forwarder per region)."
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Name of an existing resource group for the forwarder resources."
  type        = string
}

variable "key_vault_id" {
  description = "ARM id of an existing Key Vault holding the Datadog API key."
  type        = string
}

variable "datadog_api_key_secret_name" {
  description = "Name of the secret within key_vault_id that holds the Datadog API key."
  type        = string
  default     = "datadog-api-key"
}
