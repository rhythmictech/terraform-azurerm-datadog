mock_provider "azurerm" {
  source = "./tests/setup"
}

mock_provider "azuread" {
  source = "./tests/setup"
}

mock_provider "datadog" {
  source = "./tests/setup"
}

# Guardrail for the consume (default) input shape: consuming an externally
# created app registration must create NO Entra objects, so
# app_registration_object_id is null. NOTE: this exercises the module directly
# with consume-shape inputs; it does not instantiate examples/consume/main.tf
# (a mock-provider FQN conflict blocks referencing the example as a submodule),
# so it validates module behavior for these inputs, not the example file itself.
run "consume_shape_creates_no_app_registration" {
  command = plan

  variables {
    name                              = "example-client"
    datadog_client_id                 = "11111111-1111-1111-1111-111111111111"
    datadog_tenant_id                 = "22222222-2222-2222-2222-222222222222"
    datadog_sp_object_id              = "33333333-3333-3333-3333-333333333333"
    datadog_client_secret             = "consume-secret"
    host_filters                      = ["datadog_managed:true"]
    manage_datadog_sp_role_assignment = false
    role_assignment_scopes            = ["/subscriptions/44444444-4444-4444-4444-444444444444"]
  }

  assert {
    condition     = output.app_registration_object_id == null
    error_message = "the consume path must not create an app registration"
  }

  assert {
    condition     = length(azuread_application.this) == 0
    error_message = "the consume path must plan zero azuread objects"
  }
}
