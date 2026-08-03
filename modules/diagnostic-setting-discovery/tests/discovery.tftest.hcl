mock_provider "azurerm" {
  source = "./tests/setup"
}

variables {
  storage_account_ids_by_region = {
    eastus  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/ddeastus"
    eastus2 = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/ddeastus2"
  }
}

# Two discovered resources in two regions each get one setting, routed to the
# destination for their OWN region. Cross-region routing is the failure mode that
# silently breaks delivery, so it is asserted per resource rather than in bulk.
run "routes_each_scope_to_its_own_region" {
  command = plan

  variables {
    resource_types = ["Microsoft.Web/sites"]
  }

  override_data {
    target = data.azurerm_resources.by_type["Microsoft.Web/sites"]
    values = {
      resources = [
        {
          id                  = "/subscriptions/s/resourceGroups/app/providers/Microsoft.Web/sites/one"
          name                = "one"
          resource_group_name = "app"
          type                = "Microsoft.Web/sites"
          location            = "eastus"
        },
        {
          id                  = "/subscriptions/s/resourceGroups/app/providers/Microsoft.Web/sites/two"
          name                = "two"
          resource_group_name = "app"
          type                = "Microsoft.Web/sites"
          location            = "eastus2"
        },
      ]
    }
  }

  assert {
    condition     = length(azurerm_monitor_diagnostic_setting.this) == 2
    error_message = "two discovered sites should produce two diagnostic settings"
  }

  assert {
    condition     = azurerm_monitor_diagnostic_setting.this["/subscriptions/s/resourceGroups/app/providers/Microsoft.Web/sites/one"].storage_account_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/ddeastus"
    error_message = "the eastus site should target the eastus destination"
  }

  assert {
    condition     = azurerm_monitor_diagnostic_setting.this["/subscriptions/s/resourceGroups/app/providers/Microsoft.Web/sites/two"].storage_account_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/ddeastus2"
    error_message = "the eastus2 site should target the eastus2 destination"
  }

  # The for_each key IS the scope id. This is what makes state addresses
  # derivable from Azure alone, so importing a pre-existing setting needs no
  # side table. Guard it: a switch to slug keys would break every import.
  assert {
    condition     = contains(keys(azurerm_monitor_diagnostic_setting.this), "/subscriptions/s/resourceGroups/app/providers/Microsoft.Web/sites/one")
    error_message = "settings must be keyed by the monitored scope's resource id"
  }

  assert {
    condition     = alltrue([for k, v in azurerm_monitor_diagnostic_setting.this : v.name == "rhythmic-datadog"])
    error_message = "every setting should default to the rhythmic-datadog name"
  }

  assert {
    condition     = alltrue([for k, v in azurerm_monitor_diagnostic_setting.this : contains([for l in v.enabled_log : l.category_group], "allLogs")])
    error_message = "every setting should enable the allLogs category group by default"
  }

  # Metrics default OFF here, unlike the sibling diagnostic-setting module.
  # Flipping this default would silently duplicate metric data across a whole
  # discovered estate at cost.
  assert {
    condition     = alltrue([for k, v in azurerm_monitor_diagnostic_setting.this : length(v.enabled_metric) == 0])
    error_message = "no metric categories should be enabled by default"
  }
}

# A storage account becomes FOUR service scopes and contributes no setting of its
# own. Applying a setting to a storage account id fails in Azure, and enumerating
# accounts instead of service scopes monitors nothing while looking successful.
run "storage_expands_into_service_scopes" {
  command = plan

  variables {
    resource_types = ["Microsoft.Storage/storageAccounts"]
  }

  override_data {
    target = data.azurerm_resources.by_type["Microsoft.Storage/storageAccounts"]
    values = {
      resources = [
        {
          id                  = "/subscriptions/s/resourceGroups/data/providers/Microsoft.Storage/storageAccounts/acct"
          name                = "acct"
          resource_group_name = "data"
          type                = "Microsoft.Storage/storageAccounts"
          location            = "eastus"
        },
      ]
    }
  }

  assert {
    condition     = length(azurerm_monitor_diagnostic_setting.this) == 4
    error_message = "one storage account should expand into four service scopes"
  }

  assert {
    condition = alltrue([
      for svc in ["blobServices", "fileServices", "queueServices", "tableServices"] :
      contains(
        keys(azurerm_monitor_diagnostic_setting.this),
        "/subscriptions/s/resourceGroups/data/providers/Microsoft.Storage/storageAccounts/acct/${svc}/default"
      )
    ])
    error_message = "each of the four storage service scopes should be monitored"
  }

  assert {
    condition     = !contains(keys(azurerm_monitor_diagnostic_setting.this), "/subscriptions/s/resourceGroups/data/providers/Microsoft.Storage/storageAccounts/acct")
    error_message = "the storage ACCOUNT id must never receive a setting; only its service scopes do"
  }
}

# Narrowing storage_services narrows the expansion.
run "storage_services_subset_is_honoured" {
  command = plan

  variables {
    resource_types   = ["Microsoft.Storage/storageAccounts"]
    storage_services = ["blobServices"]
  }

  override_data {
    target = data.azurerm_resources.by_type["Microsoft.Storage/storageAccounts"]
    values = {
      resources = [
        {
          id                  = "/subscriptions/s/resourceGroups/data/providers/Microsoft.Storage/storageAccounts/acct"
          name                = "acct"
          resource_group_name = "data"
          type                = "Microsoft.Storage/storageAccounts"
          location            = "eastus"
        },
      ]
    }
  }

  assert {
    condition     = length(azurerm_monitor_diagnostic_setting.this) == 1
    error_message = "a single-service storage_services list should produce one scope per account"
  }
}

# Region strings arrive in display or normalized form depending on how a resource
# was created. A "East US" destination key must match an "eastus" location, and
# vice versa, or routing breaks on cosmetics.
run "region_matching_ignores_case_and_spaces" {
  command = plan

  variables {
    resource_types = ["Microsoft.Web/sites"]
    storage_account_ids_by_region = {
      "East US" = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/ddeastus"
    }
  }

  override_data {
    target = data.azurerm_resources.by_type["Microsoft.Web/sites"]
    values = {
      resources = [
        {
          id                  = "/subscriptions/s/resourceGroups/app/providers/Microsoft.Web/sites/one"
          name                = "one"
          resource_group_name = "app"
          type                = "Microsoft.Web/sites"
          location            = "eastus"
        },
      ]
    }
  }

  assert {
    condition     = length(azurerm_monitor_diagnostic_setting.this) == 1
    error_message = "an 'East US' destination key should match an 'eastus' resource location"
  }

  assert {
    condition     = length(output.unmapped_regions) == 0
    error_message = "region normalization should leave no region unmapped"
  }
}

# The mirror of the previous run, and it must be separate: normalizing only the
# destination map would still pass that one. Here the LOCATION is the display form
# and the destination key is already normalized, which exercises normalization on
# the discovered side.
run "region_matching_normalizes_the_discovered_location_too" {
  command = plan

  variables {
    resource_types = ["Microsoft.Web/sites"]
    storage_account_ids_by_region = {
      eastus = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/ddeastus"
    }
  }

  override_data {
    target = data.azurerm_resources.by_type["Microsoft.Web/sites"]
    values = {
      resources = [
        {
          id                  = "/subscriptions/s/resourceGroups/app/providers/Microsoft.Web/sites/one"
          name                = "one"
          resource_group_name = "app"
          type                = "Microsoft.Web/sites"
          location            = "East US"
        },
      ]
    }
  }

  assert {
    condition     = length(azurerm_monitor_diagnostic_setting.this) == 1
    error_message = "an 'East US' resource location should match an 'eastus' destination key"
  }

  assert {
    condition     = length(output.unmapped_regions) == 0
    error_message = "a display-form location should not be reported as unmapped"
  }

  assert {
    condition     = output.scope_count_by_region["eastus"] == 1
    error_message = "scope_count_by_region should report the normalized region name"
  }
}

# Resource-group exclusion, matched case-insensitively so a caller does not have
# to reproduce Azure's casing exactly.
run "excludes_resource_groups_case_insensitively" {
  command = plan

  variables {
    resource_types          = ["Microsoft.Web/sites"]
    exclude_resource_groups = ["Datadog-Log-Forwarding"]
  }

  override_data {
    target = data.azurerm_resources.by_type["Microsoft.Web/sites"]
    values = {
      resources = [
        {
          id                  = "/subscriptions/s/resourceGroups/datadog-log-forwarding/providers/Microsoft.Web/sites/control"
          name                = "control"
          resource_group_name = "datadog-log-forwarding"
          type                = "Microsoft.Web/sites"
          location            = "eastus"
        },
        {
          id                  = "/subscriptions/s/resourceGroups/app/providers/Microsoft.Web/sites/keep"
          name                = "keep"
          resource_group_name = "app"
          type                = "Microsoft.Web/sites"
          location            = "eastus"
        },
      ]
    }
  }

  assert {
    condition     = length(azurerm_monitor_diagnostic_setting.this) == 1
    error_message = "the excluded resource group's site should be dropped regardless of casing"
  }

  assert {
    condition     = contains(keys(azurerm_monitor_diagnostic_setting.this), "/subscriptions/s/resourceGroups/app/providers/Microsoft.Web/sites/keep")
    error_message = "the non-excluded site should survive"
  }
}

# Excluding a storage ACCOUNT id must remove all of its expanded service scopes,
# not just an account scope that never existed.
run "excluding_a_storage_account_drops_all_its_service_scopes" {
  command = plan

  variables {
    resource_types       = ["Microsoft.Storage/storageAccounts"]
    exclude_resource_ids = ["/subscriptions/s/resourceGroups/data/providers/Microsoft.Storage/storageAccounts/skipme"]
  }

  override_data {
    target = data.azurerm_resources.by_type["Microsoft.Storage/storageAccounts"]
    values = {
      resources = [
        {
          id                  = "/subscriptions/s/resourceGroups/data/providers/Microsoft.Storage/storageAccounts/skipme"
          name                = "skipme"
          resource_group_name = "data"
          type                = "Microsoft.Storage/storageAccounts"
          location            = "eastus"
        },
        {
          id                  = "/subscriptions/s/resourceGroups/data/providers/Microsoft.Storage/storageAccounts/keepme"
          name                = "keepme"
          resource_group_name = "data"
          type                = "Microsoft.Storage/storageAccounts"
          location            = "eastus"
        },
      ]
    }
  }

  assert {
    condition     = length(azurerm_monitor_diagnostic_setting.this) == 4
    error_message = "excluding one of two storage accounts should leave exactly four service scopes"
  }

  assert {
    condition = alltrue([
      for k, v in azurerm_monitor_diagnostic_setting.this :
      !strcontains(k, "/storageAccounts/skipme/")
    ])
    error_message = "no service scope of the excluded account should remain"
  }
}

# Mixed types in one instantiation, with the per-type census exposed for review.
run "counts_by_type_and_region_are_reported" {
  command = plan

  variables {
    resource_types = ["Microsoft.Web/sites", "Microsoft.KeyVault/vaults"]
  }

  override_data {
    target = data.azurerm_resources.by_type["Microsoft.Web/sites"]
    values = {
      resources = [
        {
          id                  = "/subscriptions/s/resourceGroups/app/providers/Microsoft.Web/sites/one"
          name                = "one"
          resource_group_name = "app"
          type                = "Microsoft.Web/sites"
          location            = "eastus"
        },
      ]
    }
  }

  override_data {
    target = data.azurerm_resources.by_type["Microsoft.KeyVault/vaults"]
    values = {
      resources = [
        {
          id                  = "/subscriptions/s/resourceGroups/sec/providers/Microsoft.KeyVault/vaults/kv1"
          name                = "kv1"
          resource_group_name = "sec"
          type                = "Microsoft.KeyVault/vaults"
          location            = "eastus"
        },
        {
          id                  = "/subscriptions/s/resourceGroups/sec/providers/Microsoft.KeyVault/vaults/kv2"
          name                = "kv2"
          resource_group_name = "sec"
          type                = "Microsoft.KeyVault/vaults"
          location            = "eastus2"
        },
      ]
    }
  }

  assert {
    condition     = length(azurerm_monitor_diagnostic_setting.this) == 3
    error_message = "three resources across two types should produce three settings"
  }

  assert {
    condition     = output.scope_count_by_type["Microsoft.KeyVault/vaults"] == 2
    error_message = "scope_count_by_type should report two key vaults"
  }

  assert {
    condition     = output.scope_count_by_region["eastus"] == 2
    error_message = "scope_count_by_region should report two eastus scopes"
  }

  assert {
    condition     = length(output.monitored_scope_ids) == 3
    error_message = "monitored_scope_ids should list every monitored scope"
  }
}

# A resource type that matches nothing produces no error and no resources, which
# is indistinguishable from a subscription that genuinely has none. The
# per-requested-type census is the only signal a reviewer gets, so it must report
# the zero rather than omitting the key.
run "requested_type_that_matches_nothing_is_reported_as_zero" {
  command = plan

  variables {
    resource_types = ["Microsoft.Web/sites", "Microsoft.Web/sitez"]
  }

  override_data {
    target = data.azurerm_resources.by_type["Microsoft.Web/sites"]
    values = {
      resources = [
        {
          id                  = "/subscriptions/s/resourceGroups/app/providers/Microsoft.Web/sites/one"
          name                = "one"
          resource_group_name = "app"
          type                = "Microsoft.Web/sites"
          location            = "eastus"
        },
      ]
    }
  }

  override_data {
    target = data.azurerm_resources.by_type["Microsoft.Web/sitez"]
    values = {
      resources = []
    }
  }

  assert {
    condition     = output.discovered_count_by_requested_type["Microsoft.Web/sitez"] == 0
    error_message = "a requested type that matched nothing must appear with a count of 0, not be omitted"
  }

  assert {
    condition     = output.discovered_count_by_requested_type["Microsoft.Web/sites"] == 1
    error_message = "a requested type that matched should report its discovered count"
  }

  assert {
    condition     = length(keys(output.discovered_count_by_requested_type)) == 2
    error_message = "every requested type should appear in the census, matched or not"
  }
}

# Storage is counted as ACCOUNTS in the requested-type census and as expanded
# SERVICE SCOPES in scope_count_by_type. Conflating the two would misreport
# coverage by a factor of four.
run "storage_census_counts_accounts_not_expanded_scopes" {
  command = plan

  variables {
    resource_types = ["Microsoft.Storage/storageAccounts"]
  }

  override_data {
    target = data.azurerm_resources.by_type["Microsoft.Storage/storageAccounts"]
    values = {
      resources = [
        {
          id                  = "/subscriptions/s/resourceGroups/data/providers/Microsoft.Storage/storageAccounts/acct"
          name                = "acct"
          resource_group_name = "data"
          type                = "Microsoft.Storage/storageAccounts"
          location            = "eastus"
        },
      ]
    }
  }

  assert {
    condition     = output.discovered_count_by_requested_type["Microsoft.Storage/storageAccounts"] == 1
    error_message = "the requested-type census should count one storage ACCOUNT"
  }

  assert {
    condition     = output.scope_count_by_type["Microsoft.Storage/storageAccounts/blobServices"] == 1
    error_message = "scope_count_by_type should report expanded service scopes, keyed per service"
  }

  assert {
    condition     = length(keys(output.scope_count_by_type)) == 4
    error_message = "one storage account should yield four distinct service-scope types"
  }
}
