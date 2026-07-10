mock_provider "azurerm" {
  source = "./tests/setup"
}

# An empty target map produces zero settings (INPUT-map for_each), which is the
# safe no-op the caller relies on when a region has no in-scope targets.
run "empty_target_map" {
  command = plan

  variables {
    storage_account_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/ddlogs"
    target_resource_ids = {}
  }

  assert {
    condition     = length(azurerm_monitor_diagnostic_setting.this) == 0
    error_message = "an empty target_resource_ids map should produce zero diagnostic settings"
  }
}

# All category inputs empty -> the at-least-one validation fails.
run "no_categories_rejected" {
  command = plan

  variables {
    storage_account_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/ddlogs"
    log_category_groups = []
    log_categories      = []
    metric_categories   = []
    target_resource_ids = {
      app = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Web/sites/app"
    }
  }

  expect_failures = [
    var.metric_categories,
  ]
}
