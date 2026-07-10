mock_provider "azurerm" {
  source = "./tests/setup"
}

mock_provider "azuread" {
  source = "./tests/setup"
}

mock_provider "datadog" {
  source = "./tests/setup"
}

# Detection off (default) -> zero usage monitors.
run "usage_off_by_default" {
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
    condition     = length(datadog_monitor.anomaly_usage) == 0
    error_message = "no anomaly monitors when detection is off"
  }

  assert {
    condition     = length(datadog_monitor.estimated_usage) == 0
    error_message = "no estimated-usage monitors when detection is off"
  }

  assert {
    condition     = length(datadog_monitor.limit_exceeded) == 0
    error_message = "no limit-exceeded monitor when log_limit_exceeded_message is null"
  }
}

# Detection on with the `hosts` metric enabled for both anomaly + threshold ->
# one anomaly monitor and one estimated-usage monitor.
run "usage_on_hosts" {
  command = plan

  variables {
    name                             = "example"
    datadog_client_id                = "11111111-1111-1111-1111-111111111111"
    datadog_tenant_id                = "22222222-2222-2222-2222-222222222222"
    datadog_sp_object_id             = "33333333-3333-3333-3333-333333333333"
    datadog_client_secret            = "consume-secret"
    role_assignment_scopes           = []
    enable_estimated_usage_detection = true
    estimated_usage_detection_config = {
      hosts = {
        anomaly_enabled         = true
        estimated_usage_enabled = true
      }
    }
  }

  assert {
    condition     = length(datadog_monitor.anomaly_usage) == 1
    error_message = "hosts anomaly monitor should be planned"
  }

  assert {
    condition     = length(datadog_monitor.estimated_usage) == 1
    error_message = "hosts estimated-usage monitor should be planned"
  }
}

# log_limit_exceeded_message set -> the event-v2 limit_exceeded monitor appears.
run "limit_exceeded_monitor" {
  command = plan

  variables {
    name                       = "example"
    datadog_client_id          = "11111111-1111-1111-1111-111111111111"
    datadog_tenant_id          = "22222222-2222-2222-2222-222222222222"
    datadog_sp_object_id       = "33333333-3333-3333-3333-333333333333"
    datadog_client_secret      = "consume-secret"
    role_assignment_scopes     = []
    log_limit_exceeded_message = "Daily log quota reached"
  }

  assert {
    condition     = length(datadog_monitor.limit_exceeded) == 1
    error_message = "limit_exceeded monitor should be planned when the message is set"
  }
}
