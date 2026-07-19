# Shared mock defaults for `terraform test`. Referenced from every *.tftest.hcl
# via `mock_provider "<p>" { source = "./tests/setup" }`, so all plan-only tests
# run with no live Azure tenant or Datadog org. Each mock_provider only applies
# the blocks that match its own resource/data types.

########################################
# datadog
########################################
mock_resource "datadog_integration_azure" {
  defaults = {
    id = "00000000-0000-0000-0000-0000000000dd"
  }
}

mock_resource "datadog_monitor" {
  defaults = {
    id = 123456
  }
}

mock_resource "datadog_logs_index" {
  defaults = {
    id = "main"
  }
}

mock_resource "datadog_logs_custom_pipeline" {
  defaults = {
    id = "00000000000000000000000000"
  }
}

########################################
# azuread
########################################
mock_data "azuread_client_config" {
  defaults = {
    tenant_id = "22222222-2222-2222-2222-222222222222"
    object_id = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
  }
}

mock_resource "azuread_application" {
  defaults = {
    client_id = "11111111-1111-1111-1111-111111111111"
    object_id = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
  }
}

mock_resource "azuread_service_principal" {
  defaults = {
    object_id = "cccccccc-cccc-cccc-cccc-cccccccccccc"
  }
}

mock_resource "azuread_application_password" {
  defaults = {
    value = "mock-generated-secret"
  }
}

########################################
# azurerm
########################################
mock_resource "azurerm_role_assignment" {
  defaults = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleAssignments/mock"
  }
}
