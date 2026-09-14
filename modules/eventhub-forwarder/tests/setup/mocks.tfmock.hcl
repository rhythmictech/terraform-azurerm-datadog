# Shared mock defaults for `terraform test`. Referenced from every *.tftest.hcl
# via `mock_provider "azurerm" { source = "./tests/setup" }`, so the plan-only
# suite runs with no live Azure tenant. Ids are pinned so plan-time values are
# deterministic.
mock_resource "azurerm_storage_account" {
  defaults = {
    id                 = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock/providers/Microsoft.Storage/storageAccounts/mockddfwd"
    primary_access_key = "bW9jaw=="
  }
}

mock_resource "azurerm_service_plan" {
  defaults = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock/providers/Microsoft.Web/serverFarms/mock-datadog-forwarder"
  }
}

mock_resource "azurerm_linux_function_app" {
  defaults = {
    id               = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock/providers/Microsoft.Web/sites/mock-datadog-forwarder"
    default_hostname = "mock-datadog-forwarder.azurewebsites.net"
  }
}
