mock_provider "azurerm" {
  source = "./tests/setup"
}

# Default path: one subscription-scoped Activity Log setting, Entra off.
run "subscription_scope_entra_off" {
  command = plan

  variables {
    subscription_id    = "44444444-4444-4444-4444-444444444444"
    storage_account_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/ddlogs"
  }

  assert {
    condition     = azurerm_monitor_diagnostic_setting.activity_log.target_resource_id == "/subscriptions/44444444-4444-4444-4444-444444444444"
    error_message = "the Activity Log setting should target the subscription scope"
  }

  assert {
    condition     = azurerm_monitor_diagnostic_setting.activity_log.name == "rhythmic-datadog"
    error_message = "the Activity Log setting should be named rhythmic-datadog"
  }

  assert {
    condition     = azurerm_monitor_diagnostic_setting.activity_log.storage_account_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/ddlogs"
    error_message = "the Activity Log setting should ship to the provided storage account"
  }

  assert {
    condition     = length(azurerm_monitor_aad_diagnostic_setting.entra) == 0
    error_message = "the Entra directory setting must be off by default"
  }
}

# A management-group scope override replaces the subscription scope.
run "scope_override" {
  command = plan

  variables {
    subscription_id       = "44444444-4444-4444-4444-444444444444"
    target_scope_override = "/providers/Microsoft.Management/managementGroups/example-root"
    storage_account_id    = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/ddlogs"
  }

  assert {
    condition     = azurerm_monitor_diagnostic_setting.activity_log.target_resource_id == "/providers/Microsoft.Management/managementGroups/example-root"
    error_message = "target_scope_override should replace the subscription scope"
  }
}
