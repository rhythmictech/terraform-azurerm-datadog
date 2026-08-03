mock_provider "azurerm" {
  source = "./tests/setup"
}

variables {
  resource_types = ["Microsoft.Web/sites"]
  storage_account_ids_by_region = {
    eastus = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/ddeastus"
  }
}

# Discovering nothing is a clean no-op, which is what a caller relies on when a
# type exists in the list but the subscription has none of it. The shared mock
# returns an empty resource list, so no override is needed here.
run "no_discovered_resources_is_a_no_op" {
  command = plan

  assert {
    condition     = length(azurerm_monitor_diagnostic_setting.this) == 0
    error_message = "discovering nothing should produce zero diagnostic settings"
  }

  assert {
    condition     = length(output.monitored_scope_ids) == 0
    error_message = "monitored_scope_ids should be empty when nothing is discovered"
  }
}

# THE important guard. A resource in a region with no co-regional destination
# cannot be monitored, and the dangerous outcome is dropping it quietly, which is
# indistinguishable from success. Default behavior must be a hard plan failure.
run "unmapped_region_fails_the_plan_by_default" {
  command = plan

  override_data {
    target = data.azurerm_resources.by_type["Microsoft.Web/sites"]
    values = {
      resources = [
        {
          id                  = "/subscriptions/s/resourceGroups/app/providers/Microsoft.Web/sites/orphan"
          name                = "orphan"
          resource_group_name = "app"
          type                = "Microsoft.Web/sites"
          location            = "westeurope"
        },
      ]
    }
  }

  expect_failures = [
    terraform_data.region_coverage,
  ]
}

# The escape hatch works, and when taken the dropped regions are still reported
# rather than vanishing. A caller that sets this flag must be able to see the
# cost of having set it.
run "unmapped_region_can_be_waived_but_stays_visible" {
  command = plan

  variables {
    fail_on_unmapped_region = false
  }

  override_data {
    target = data.azurerm_resources.by_type["Microsoft.Web/sites"]
    values = {
      resources = [
        {
          id                  = "/subscriptions/s/resourceGroups/app/providers/Microsoft.Web/sites/orphan"
          name                = "orphan"
          resource_group_name = "app"
          type                = "Microsoft.Web/sites"
          location            = "westeurope"
        },
        {
          id                  = "/subscriptions/s/resourceGroups/app/providers/Microsoft.Web/sites/mapped"
          name                = "mapped"
          resource_group_name = "app"
          type                = "Microsoft.Web/sites"
          location            = "eastus"
        },
      ]
    }
  }

  assert {
    condition     = length(azurerm_monitor_diagnostic_setting.this) == 1
    error_message = "only the resource in a mapped region should be monitored"
  }

  # Compared element-wise, not with `== ["westeurope"]`: the output is a
  # list(string) and the literal is a tuple, so direct equality is a type
  # mismatch rather than a value comparison.
  assert {
    condition     = length(output.unmapped_regions) == 1 && one(output.unmapped_regions) == "westeurope"
    error_message = "the waived region must still be reported in unmapped_regions"
  }

  assert {
    condition     = contains(keys(azurerm_monitor_diagnostic_setting.this), "/subscriptions/s/resourceGroups/app/providers/Microsoft.Web/sites/mapped")
    error_message = "waiving an unmapped region must not disturb the mapped one"
  }
}

# An empty resource_types list would discover nothing while looking configured.
run "empty_resource_types_rejected" {
  command = plan

  variables {
    resource_types = []
  }

  expect_failures = [
    var.resource_types,
  ]
}

# All three category inputs empty -> no enabled log or metric, which Azure rejects.
run "no_categories_rejected" {
  command = plan

  variables {
    log_category_groups = []
    log_categories      = []
    metric_categories   = []
  }

  expect_failures = [
    var.metric_categories,
  ]
}

# A storage_services typo would silently monitor nothing for that service.
run "invalid_storage_service_rejected" {
  command = plan

  variables {
    storage_services = ["blobServices", "blobService"]
  }

  expect_failures = [
    var.storage_services,
  ]
}

# An empty name would produce an unnamed setting and defeat the
# never-clobber-a-customer-setting property the distinct name provides.
run "empty_name_rejected" {
  command = plan

  variables {
    name = "   "
  }

  expect_failures = [
    var.name,
  ]
}
