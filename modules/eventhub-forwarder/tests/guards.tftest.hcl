mock_provider "azurerm" {
  source = "./tests/setup"
}

variables {
  name                        = "example-defender"
  resource_group_name         = "rg-monitoring"
  location                    = "eastus"
  event_hub_name              = "evh-defender-export"
  event_hub_connection_string = "Endpoint=sb://example.servicebus.windows.net/;SharedAccessKeyName=datadog-listen;SharedAccessKey=mock;EntityPath=evh-defender-export"
  datadog_api_key             = "00000000000000000000000000000000"
}

# Names feed global DNS names and storage account names, so the slug rules are
# enforced at the variable.
run "uppercase_name_rejected" {
  command = plan

  variables {
    name = "Example"
  }

  expect_failures = [
    var.name,
  ]
}

run "invalid_storage_account_override_rejected" {
  command = plan

  variables {
    storage_account_name = "Has-Hyphens"
  }

  expect_failures = [
    var.storage_account_name,
  ]
}

run "invalid_function_app_override_rejected" {
  command = plan

  variables {
    function_app_name = "-leading-hyphen"
  }

  expect_failures = [
    var.function_app_name,
  ]
}

# The vendored package must match the pinned hash for the plan to succeed at
# all; this run passing is the positive control for that precondition.
run "pinned_package_matches_its_hash" {
  command = plan

  assert {
    condition     = filesha256("${path.module}/function/deploy.zip") == "65699f41c64d507af88d8256d8638491eddc9b4195218926e18a825767a6c64c"
    error_message = "the vendored deploy.zip must match the pinned sha256 recorded in main.tf and function/PIN.md"
  }
}
