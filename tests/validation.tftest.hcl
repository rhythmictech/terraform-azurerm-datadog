mock_provider "azurerm" {
  source = "./tests/setup"
}

mock_provider "azuread" {
  source = "./tests/setup"
}

mock_provider "datadog" {
  source = "./tests/setup"
}

# Consume path with a required var left null -> the datadog_client_id validation
# must fail (all other consume vars are supplied so only this one trips).
run "consume_missing_client_id" {
  command = plan

  variables {
    name                    = "example"
    create_app_registration = false
    datadog_client_id       = null
    datadog_tenant_id       = "22222222-2222-2222-2222-222222222222"
    datadog_sp_object_id    = "33333333-3333-3333-3333-333333333333"
    datadog_client_secret   = "consume-secret"
    role_assignment_scopes  = []
  }

  expect_failures = [
    var.datadog_client_id,
  ]
}

# Create path with a consume var provided -> the datadog_client_id "must be
# null" validation must fail.
run "create_with_stray_consume_var" {
  command = plan

  variables {
    name                    = "example"
    create_app_registration = true
    datadog_client_id       = "11111111-1111-1111-1111-111111111111"
    role_assignment_scopes  = []
  }

  expect_failures = [
    var.datadog_client_id,
  ]
}

# CSPM requires resource collection.
run "cspm_requires_resource_collection" {
  command = plan

  variables {
    name                       = "example"
    datadog_client_id          = "11111111-1111-1111-1111-111111111111"
    datadog_tenant_id          = "22222222-2222-2222-2222-222222222222"
    datadog_sp_object_id       = "33333333-3333-3333-3333-333333333333"
    datadog_client_secret      = "consume-secret"
    role_assignment_scopes     = []
    enable_cspm                = true
    enable_resource_collection = false
  }

  expect_failures = [
    var.enable_cspm,
  ]
}

# Blank (non-null) app registration display name is rejected.
run "blank_display_name_rejected" {
  command = plan

  variables {
    name                          = "example"
    create_app_registration       = true
    app_registration_display_name = "   "
    role_assignment_scopes        = []
  }

  expect_failures = [
    var.app_registration_display_name,
  ]
}
