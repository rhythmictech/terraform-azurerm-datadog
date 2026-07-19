mock_provider "azurerm" {
  source = "./tests/setup"
}

mock_provider "azuread" {
  source = "./tests/setup"
}

mock_provider "datadog" {
  source = "./tests/setup"
}

# Pipeline off (default) -> zero custom pipelines.
run "health_pipeline_off_by_default" {
  command = plan

  variables {
    name                   = "example"
    datadog_client_id      = "11111111-1111-1111-1111-111111111111"
    datadog_tenant_id      = "22222222-2222-2222-2222-222222222222"
    datadog_sp_object_id   = "33333333-3333-3333-3333-333333333333"
    datadog_client_secret  = "consume-secret"
    role_assignment_scopes = []
  }

  assert {
    condition     = length(datadog_logs_custom_pipeline.health) == 0
    error_message = "health pipeline must be gated off by default"
  }
}

# Pipeline on -> exactly one enabled custom pipeline is planned.
run "health_pipeline_on" {
  command = plan

  variables {
    name                   = "example"
    datadog_client_id      = "11111111-1111-1111-1111-111111111111"
    datadog_tenant_id      = "22222222-2222-2222-2222-222222222222"
    datadog_sp_object_id   = "33333333-3333-3333-3333-333333333333"
    datadog_client_secret  = "consume-secret"
    role_assignment_scopes = []
    manage_health_pipeline = true
  }

  assert {
    condition     = length(datadog_logs_custom_pipeline.health) == 1
    error_message = "health pipeline should be planned when manage_health_pipeline = true"
  }

  assert {
    condition     = datadog_logs_custom_pipeline.health[0].is_enabled == true
    error_message = "health pipeline should be enabled when managed"
  }
}
