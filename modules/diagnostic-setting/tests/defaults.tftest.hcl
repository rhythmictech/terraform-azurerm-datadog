mock_provider "azurerm" {
  source = "./tests/setup"
}

# A two-target map produces two settings, each named rhythmic-datadog, each
# shipping to the given storage account, each enabling the allLogs group.
run "two_targets_default_categories" {
  command = plan

  variables {
    storage_account_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/ddlogs"
    target_resource_ids = {
      sql_pool = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Sql/servers/srv/elasticPools/pool"
      app      = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Web/sites/app"
    }
  }

  assert {
    condition     = length(azurerm_monitor_diagnostic_setting.this) == 2
    error_message = "a two-key target map should produce two diagnostic settings"
  }

  assert {
    condition     = alltrue([for k, v in azurerm_monitor_diagnostic_setting.this : v.name == "rhythmic-datadog"])
    error_message = "every setting should be named rhythmic-datadog"
  }

  assert {
    condition     = alltrue([for k, v in azurerm_monitor_diagnostic_setting.this : v.storage_account_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/ddlogs"])
    error_message = "every setting should target the provided storage account id"
  }

  assert {
    condition     = alltrue([for k, v in azurerm_monitor_diagnostic_setting.this : contains([for l in v.enabled_log : l.category_group], "allLogs")])
    error_message = "every setting should enable the allLogs category group by default"
  }

  assert {
    condition     = azurerm_monitor_diagnostic_setting.this["app"].target_resource_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Web/sites/app"
    error_message = "each setting's target_resource_id should match its map value"
  }
}

# metric_categories = [] but a log group remains -> still valid, no metric block.
run "logs_only_no_metrics" {
  command = plan

  variables {
    storage_account_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/ddlogs"
    metric_categories  = []
    target_resource_ids = {
      app = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Web/sites/app"
    }
  }

  assert {
    condition     = length(azurerm_monitor_diagnostic_setting.this["app"].enabled_metric) == 0
    error_message = "an empty metric_categories should render no enabled_metric blocks"
  }
}
