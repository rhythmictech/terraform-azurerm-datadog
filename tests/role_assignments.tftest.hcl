mock_provider "azurerm" {
  source = "./tests/setup"
}

mock_provider "azuread" {
  source = "./tests/setup"
}

mock_provider "datadog" {
  source = "./tests/setup"
}

# Default: manage flag off -> zero role assignments, even with scopes supplied.
run "off_by_default" {
  command = plan

  variables {
    name                  = "example"
    datadog_client_id     = "11111111-1111-1111-1111-111111111111"
    datadog_tenant_id     = "22222222-2222-2222-2222-222222222222"
    datadog_sp_object_id  = "33333333-3333-3333-3333-333333333333"
    datadog_client_secret = "consume-secret"
    role_assignment_scopes = [
      "/subscriptions/44444444-4444-4444-4444-444444444444",
      "/subscriptions/55555555-5555-5555-5555-555555555555",
    ]
  }

  assert {
    condition     = length(azurerm_role_assignment.datadog) == 0
    error_message = "manage_datadog_sp_role_assignment defaults false -> zero assignments"
  }

  assert {
    condition     = length(azurerm_role_assignment.datadog_blob) == 0
    error_message = "blob role must also be off by default"
  }
}

# Flag on + two scopes -> exactly two Monitoring Reader assignments.
run "on_two_scopes" {
  command = plan

  variables {
    name                              = "example"
    datadog_client_id                 = "11111111-1111-1111-1111-111111111111"
    datadog_tenant_id                 = "22222222-2222-2222-2222-222222222222"
    datadog_sp_object_id              = "33333333-3333-3333-3333-333333333333"
    datadog_client_secret             = "consume-secret"
    manage_datadog_sp_role_assignment = true
    role_assignment_scopes = [
      "/subscriptions/44444444-4444-4444-4444-444444444444",
      "/subscriptions/55555555-5555-5555-5555-555555555555",
    ]
  }

  assert {
    condition     = length(azurerm_role_assignment.datadog) == 2
    error_message = "flag on + 2 scopes should produce 2 assignments"
  }

  assert {
    condition     = alltrue([for k, v in azurerm_role_assignment.datadog : v.role_definition_name == "Monitoring Reader"])
    error_message = "all assignments should use the Monitoring Reader role"
  }

  assert {
    condition     = alltrue([for k, v in azurerm_role_assignment.datadog : v.principal_id == "33333333-3333-3333-3333-333333333333"])
    error_message = "assignments should target the Datadog SP object id"
  }

  assert {
    condition     = length(azurerm_role_assignment.datadog_blob) == 0
    error_message = "blob role should stay off unless explicitly enabled"
  }
}

# Flag on + blob role enabled -> the 2 base + 2 blob assignments.
run "on_with_blob_role" {
  command = plan

  variables {
    name                              = "example"
    datadog_client_id                 = "11111111-1111-1111-1111-111111111111"
    datadog_tenant_id                 = "22222222-2222-2222-2222-222222222222"
    datadog_sp_object_id              = "33333333-3333-3333-3333-333333333333"
    datadog_client_secret             = "consume-secret"
    manage_datadog_sp_role_assignment = true
    enable_log_archive_blob_role      = true
    role_assignment_scopes = [
      "/subscriptions/44444444-4444-4444-4444-444444444444",
      "/subscriptions/55555555-5555-5555-5555-555555555555",
    ]
  }

  assert {
    condition     = length(azurerm_role_assignment.datadog) == 2
    error_message = "base Monitoring Reader assignments should still be 2"
  }

  assert {
    condition     = length(azurerm_role_assignment.datadog_blob) == 2
    error_message = "blob role enabled -> 2 Storage Blob Data Contributor assignments"
  }

  assert {
    condition     = alltrue([for k, v in azurerm_role_assignment.datadog_blob : v.role_definition_name == "Storage Blob Data Contributor"])
    error_message = "blob assignments should use Storage Blob Data Contributor"
  }
}
