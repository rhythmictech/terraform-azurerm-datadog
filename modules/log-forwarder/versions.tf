terraform {
  # >= 1.9 is REQUIRED: input-variable `validation {}` blocks reference *other*
  # variables (cross-variable rules), which is only legal on >= 1.9, and
  # `terraform test` uses `mock_provider` (>= 1.7).
  required_version = ">= 1.9"

  required_providers {
    # azurerm-only. This wrapper reads a Key Vault secret (data source) and
    # calls a child module that creates the storage + Container Apps forwarder;
    # the child module itself requires `azurerm ~> 4.0`, so this pin must not
    # narrow below it. No datadog/azuread/archive providers are used here.
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}
