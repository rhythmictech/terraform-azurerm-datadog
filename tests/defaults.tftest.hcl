mock_provider "azurerm" {
  source = "./tests/setup"
}

mock_provider "azuread" {
  source = "./tests/setup"
}

mock_provider "datadog" {
  source = "./tests/setup"
}

# Consume path (create_app_registration = false, all four consume vars set):
# exactly one integration, zero azuread resources, default host filter, automute.
run "consume_defaults" {
  command = plan

  variables {
    name                   = "example"
    datadog_client_id      = "11111111-1111-1111-1111-111111111111"
    datadog_tenant_id      = "22222222-2222-2222-2222-222222222222"
    datadog_sp_object_id   = "33333333-3333-3333-3333-333333333333"
    datadog_client_secret  = "consume-secret"
    role_assignment_scopes = ["/subscriptions/44444444-4444-4444-4444-444444444444"]
  }

  assert {
    condition     = datadog_integration_azure.this.host_filters == "datadog_managed:true"
    error_message = "host_filters should render the default datadog_managed:true"
  }

  assert {
    condition     = datadog_integration_azure.this.automute == true
    error_message = "automute should default to true"
  }

  assert {
    condition     = datadog_integration_azure.this.tenant_name == "22222222-2222-2222-2222-222222222222"
    error_message = "tenant_name should resolve to the consumed tenant id"
  }

  assert {
    condition     = datadog_integration_azure.this.client_id == "11111111-1111-1111-1111-111111111111"
    error_message = "client_id should resolve to the consumed client id"
  }

  assert {
    condition     = length(azuread_application.this) == 0
    error_message = "consume path must plan zero azuread_application resources"
  }

  assert {
    condition     = length(azuread_service_principal.this) == 0
    error_message = "consume path must plan zero azuread_service_principal resources"
  }

  assert {
    condition     = length(azuread_application_password.this) == 0
    error_message = "consume path must plan zero azuread_application_password resources"
  }

  assert {
    condition     = length(azurerm_role_assignment.datadog) == 0
    error_message = "role assignment must be gated off by default"
  }
}
