# Shared mock defaults for `terraform test`. Referenced from every *.tftest.hcl
# via `mock_provider "azurerm" { source = "./tests/setup" }`, so all plan-only
# tests run with no live Azure tenant. The azurerm mock also covers the child
# forwarder module's own azurerm resources/data sources (storage account,
# management policy, Container App environment/job, resource group, client
# config) with generated values; only the overrides below are pinned.

# The child module hard-validates the Datadog API key at `length == 32`, so the
# Key Vault-sourced value must be exactly 32 characters for the KV path to plan.
mock_data "azurerm_key_vault_secret" {
  defaults = {
    value = "00000000000000000000000000000000"
  }
}
