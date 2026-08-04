mock_provider "azurerm" {
  source = "./tests/setup"
}

mock_provider "datadog" {
  source = "./tests/setup"
}

variables {
  name                 = "example"
  resource_group_name  = "rg-monitoring"
  region               = "eastus"
  datadog_client_id    = "11111111-1111-1111-1111-111111111111"
  datadog_tenant_id    = "22222222-2222-2222-2222-222222222222"
  datadog_sp_object_id = "33333333-3333-3333-3333-333333333333"
}

run "defaults_produce_one_of_each" {
  command = plan

  assert {
    condition     = azurerm_storage_account.archive.account_kind == "StorageV2" && azurerm_storage_account.archive.account_tier == "Standard"
    error_message = "Datadog requires a standard-performance StorageV2 account"
  }

  # Datadog supports only the Hot and Cool access tiers, so the account must be
  # created Hot. Cold or Premium here would break archiving outright.
  assert {
    condition     = azurerm_storage_account.archive.access_tier == "Hot"
    error_message = "the archive account must be created in the Hot access tier"
  }

  assert {
    condition     = azurerm_storage_container.archive.container_access_type == "private"
    error_message = "the archive container must be private"
  }

  assert {
    condition     = azurerm_storage_container.archive.name == "datadog-log-archive"
    error_message = "the container should default to datadog-log-archive"
  }

  assert {
    condition     = length(azurerm_role_assignment.datadog_archive_writer) == 1
    error_message = "the Datadog blob-writer role assignment should be created by default"
  }

  assert {
    condition     = datadog_logs_archive.archive.name == "example"
    error_message = "the Datadog archive name should default to var.name"
  }

  assert {
    condition     = datadog_logs_archive.archive.query == "*"
    error_message = "the archive query should default to *"
  }
}

# The storage account name has a hard 24-character cap and allows no hyphens, so
# it is derived rather than taken from `name` directly.
run "storage_account_name_is_derived_and_legal" {
  command = plan

  variables {
    name = "a-very-long-client-name-that-would-overflow"
  }

  assert {
    condition     = can(regex("^[a-z0-9]{3,24}$", azurerm_storage_account.archive.name))
    error_message = "the derived storage account name must be 3-24 lowercase alphanumeric characters"
  }
}

run "storage_account_name_override_is_used_verbatim" {
  command = plan

  variables {
    storage_account_name = "myownarchivename"
  }

  assert {
    condition     = azurerm_storage_account.archive.name == "myownarchivename"
    error_message = "an explicit storage_account_name should be used as given"
  }
}

# THE guard for this module. Datadog states that archiving and Archive Search
# support only the Hot and Cool access tiers, so a blob tiered to Cold or Archive
# is written successfully and then cannot be rehydrated. The AWS original tiers to
# GLACIER at 90 days; porting that naively is a silent data-recovery failure.
run "lifecycle_tiers_to_cool_only_never_cold_or_archive" {
  command = plan

  assert {
    condition     = azurerm_storage_management_policy.archive.rule[0].actions[0].base_blob[0].tier_to_cool_after_days_since_modification_greater_than == 90
    error_message = "blobs should tier to Cool at the configured day count"
  }

  assert {
    condition     = azurerm_storage_management_policy.archive.rule[0].actions[0].base_blob[0].delete_after_days_since_modification_greater_than == 731
    error_message = "blobs should be deleted at the configured day count"
  }

  # Unset day fields surface as null or a negative sentinel depending on provider
  # version, so assert "not a positive number" rather than equality with either.
  assert {
    condition     = coalesce(try(azurerm_storage_management_policy.archive.rule[0].actions[0].base_blob[0].tier_to_archive_after_days_since_modification_greater_than, -1), -1) < 0
    error_message = "the policy must NEVER tier to Archive: Datadog cannot rehydrate from the Archive access tier"
  }

  assert {
    condition     = coalesce(try(azurerm_storage_management_policy.archive.rule[0].actions[0].base_blob[0].tier_to_cold_after_days_since_modification_greater_than, -1), -1) < 0
    error_message = "the policy must NEVER tier to Cold: Cold is a distinct tier from Cool and is unsupported by Datadog"
  }

  assert {
    condition     = azurerm_storage_management_policy.archive.rule[0].filters[0].blob_types == toset(["blockBlob"])
    error_message = "the lifecycle rule should apply to block blobs"
  }
}

run "day_counts_flow_through" {
  command = plan

  variables {
    tier_to_cool_after_days = 30
    delete_after_days       = 400
  }

  assert {
    condition     = azurerm_storage_management_policy.archive.rule[0].actions[0].base_blob[0].tier_to_cool_after_days_since_modification_greater_than == 30
    error_message = "tier_to_cool_after_days should flow into the policy"
  }

  assert {
    condition     = azurerm_storage_management_policy.archive.rule[0].actions[0].base_blob[0].delete_after_days_since_modification_greater_than == 400
    error_message = "delete_after_days should flow into the policy"
  }
}

# Versioning plus soft delete is the deliberate substitute for an immutability
# policy, which Datadog tells you not to use because it may rewrite the trailing
# object, and which is irreversible once locked.
run "versioning_and_soft_delete_stand_in_for_immutability" {
  command = plan

  assert {
    condition     = azurerm_storage_account.archive.blob_properties[0].versioning_enabled == true
    error_message = "blob versioning should be enabled on the archive account"
  }

  assert {
    condition     = azurerm_storage_account.archive.blob_properties[0].delete_retention_policy[0].days == 7
    error_message = "blob soft delete should default to a 7 day window"
  }
}

# Account keys are off by default: Datadog writes as the app registration over
# Entra auth, so a long-lived key on a two-year log store buys nothing.
run "account_keys_are_disabled_by_default" {
  command = plan

  assert {
    condition     = azurerm_storage_account.archive.shared_access_key_enabled == false
    error_message = "shared access keys should be disabled by default"
  }

  assert {
    condition     = azurerm_storage_account.archive.min_tls_version == "TLS1_2"
    error_message = "the archive account should require TLS 1.2"
  }

  assert {
    condition     = azurerm_storage_account.archive.allow_nested_items_to_be_public == false
    error_message = "the archive account must not allow public blobs"
  }

  # Infrastructure encryption is free, is the one trivy finding worth fixing
  # rather than accepting, and can ONLY be set at account creation. Losing it
  # would need a destroy and recreate of the archive to restore.
  assert {
    condition     = azurerm_storage_account.archive.infrastructure_encryption_enabled == true
    error_message = "infrastructure encryption must be enabled; it cannot be added after creation"
  }
}

# The four required azure_archive fields, wired from the right places: the storage
# account and container come from the resources this module creates, the identity
# from the caller's existing integration app registration.
run "azure_archive_block_is_wired_correctly" {
  command = plan

  assert {
    condition     = datadog_logs_archive.archive.azure_archive[0].client_id == "11111111-1111-1111-1111-111111111111"
    error_message = "azure_archive.client_id should come from the integration app registration"
  }

  assert {
    condition     = datadog_logs_archive.archive.azure_archive[0].tenant_id == "22222222-2222-2222-2222-222222222222"
    error_message = "azure_archive.tenant_id should be the caller's tenant"
  }

  assert {
    condition     = datadog_logs_archive.archive.azure_archive[0].storage_account == azurerm_storage_account.archive.name
    error_message = "azure_archive.storage_account should reference the created account"
  }

  assert {
    condition     = datadog_logs_archive.archive.azure_archive[0].container == azurerm_storage_container.archive.name
    error_message = "azure_archive.container should reference the created container"
  }

  # include_tags defaults on: rehydrated logs are far less useful without tags.
  assert {
    condition     = datadog_logs_archive.archive.include_tags == true
    error_message = "include_tags should default to true"
  }
}

run "archive_path_is_optional_and_flows_through" {
  command = plan

  variables {
    archive_path = "/pm/logs"
  }

  assert {
    condition     = datadog_logs_archive.archive.azure_archive[0].path == "/pm/logs"
    error_message = "archive_path should flow into azure_archive.path"
  }
}
