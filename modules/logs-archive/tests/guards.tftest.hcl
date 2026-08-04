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

# Deleting before tiering means the Cool-tier saving never happens and the day
# counts silently contradict each other, so it is rejected rather than applied.
run "delete_before_tier_is_rejected" {
  command = plan

  variables {
    tier_to_cool_after_days = 200
    delete_after_days       = 100
  }

  expect_failures = [
    var.delete_after_days,
  ]
}

run "equal_day_counts_are_rejected" {
  command = plan

  variables {
    tier_to_cool_after_days = 90
    delete_after_days       = 90
  }

  expect_failures = [
    var.delete_after_days,
  ]
}

# The role assignment is the only thing that lets Datadog write the archive, so
# skipping it must be an explicit choice, and choosing it must require a principal.
run "role_assignment_requires_a_principal" {
  command = plan

  variables {
    create_role_assignment = true
    datadog_sp_object_id   = null
  }

  expect_failures = [
    var.datadog_sp_object_id,
  ]
}

run "role_assignment_can_be_waived_without_a_principal" {
  command = plan

  variables {
    create_role_assignment = false
    datadog_sp_object_id   = null
  }

  assert {
    condition     = length(azurerm_role_assignment.datadog_archive_writer) == 0
    error_message = "no role assignment should be created when create_role_assignment is false"
  }

  assert {
    condition     = output.role_assignment_id == null
    error_message = "role_assignment_id should be null when the assignment is waived"
  }
}

# The grant must be scoped to the storage account, not the resource group: a wider
# scope hands Datadog blob write access to everything else in the group.
#
# `apply` rather than `plan`, because the storage account id is provider-computed
# and therefore unknown at plan time, so a plan-only comparison against it cannot
# be evaluated. Safe here: every provider is mocked, so nothing is created.
run "role_assignment_is_scoped_to_the_storage_account" {
  command = apply

  assert {
    condition     = azurerm_role_assignment.datadog_archive_writer[0].scope == azurerm_storage_account.archive.id
    error_message = "the role assignment must be scoped to the archive storage account itself"
  }

  assert {
    condition     = azurerm_role_assignment.datadog_archive_writer[0].role_definition_name == "Storage Blob Data Contributor"
    error_message = "Datadog's archive writer needs exactly Storage Blob Data Contributor"
  }

  assert {
    condition     = azurerm_role_assignment.datadog_archive_writer[0].principal_id == "33333333-3333-3333-3333-333333333333"
    error_message = "the assignment principal should be the Datadog service principal object id"
  }
}

run "invalid_name_rejected" {
  command = plan

  variables {
    name = "Has Capitals And Spaces"
  }

  expect_failures = [
    var.name,
  ]
}

run "illegal_storage_account_name_override_rejected" {
  command = plan

  variables {
    storage_account_name = "Not-A-Valid-Name"
  }

  expect_failures = [
    var.storage_account_name,
  ]
}

run "invalid_replication_type_rejected" {
  command = plan

  variables {
    storage_account_replication_type = "LRSS"
  }

  expect_failures = [
    var.storage_account_replication_type,
  ]
}

run "out_of_range_soft_delete_rejected" {
  command = plan

  variables {
    blob_soft_delete_retention_days = 400
  }

  expect_failures = [
    var.blob_soft_delete_retention_days,
  ]
}

# Keys can be turned back on for callers whose identity cannot do Entra
# data-plane auth, but it must be a visible decision.
run "shared_access_keys_can_be_re_enabled" {
  command = plan

  variables {
    shared_access_key_enabled = true
  }

  assert {
    condition     = azurerm_storage_account.archive.shared_access_key_enabled == true
    error_message = "shared_access_key_enabled should be settable back to true"
  }
}
