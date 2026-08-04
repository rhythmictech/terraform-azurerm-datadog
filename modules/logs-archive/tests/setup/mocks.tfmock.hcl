# Shared mock defaults for `terraform test`. Referenced from every *.tftest.hcl
# via `mock_provider "<p>" { source = "./tests/setup" }`, so all plan-only tests
# run with no live Azure tenant or Datadog org. Each mock_provider only applies
# the blocks that match its own resource types.

########################################
# azurerm
########################################
mock_resource "azurerm_storage_account" {
  defaults = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock/providers/Microsoft.Storage/storageAccounts/mockarchive"
  }
}

mock_resource "azurerm_storage_container" {
  defaults = {
    id = "https://mockarchive.blob.core.windows.net/datadog-log-archive"
  }
}

mock_resource "azurerm_storage_management_policy" {
  defaults = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock/providers/Microsoft.Storage/storageAccounts/mockarchive/managementPolicies/default"
  }
}

mock_resource "azurerm_role_assignment" {
  defaults = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleAssignments/00000000-0000-0000-0000-0000000000ra"
  }
}

########################################
# datadog
########################################
mock_resource "datadog_logs_archive" {
  defaults = {
    id = "aAbBcCdDeEfFgGhHiIjJkKlLmM"
  }
}
