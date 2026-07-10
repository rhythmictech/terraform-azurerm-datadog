mock_provider "azurerm" {
  source = "./tests/setup"
}

# Entra enabled -> exactly one directory diagnostic setting with the requested
# categories, plus the always-present Activity Log setting.
run "entra_enabled" {
  command = plan

  variables {
    subscription_id          = "44444444-4444-4444-4444-444444444444"
    storage_account_id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/ddlogs"
    enable_entra_diagnostics = true
    entra_log_categories     = ["SignInLogs", "AuditLogs"]
  }

  assert {
    condition     = length(azurerm_monitor_aad_diagnostic_setting.entra) == 1
    error_message = "enable_entra_diagnostics = true should create one directory setting"
  }

  assert {
    condition     = azurerm_monitor_aad_diagnostic_setting.entra[0].storage_account_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/ddlogs"
    error_message = "the directory setting should ship to the provided storage account"
  }

  assert {
    condition     = contains([for l in azurerm_monitor_aad_diagnostic_setting.entra[0].enabled_log : l.category], "SignInLogs")
    error_message = "the directory setting should enable SignInLogs"
  }

  assert {
    condition     = contains([for l in azurerm_monitor_aad_diagnostic_setting.entra[0].enabled_log : l.category], "AuditLogs")
    error_message = "the directory setting should enable AuditLogs"
  }
}
