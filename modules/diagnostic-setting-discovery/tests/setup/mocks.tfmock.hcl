# Shared mock defaults for `terraform test`. Referenced from every *.tftest.hcl
# via `mock_provider "azurerm" { source = "./tests/setup" }`, so all plan-only
# tests run with no live Azure tenant.
#
# `azurerm_resources` defaults to an EMPTY resource list on purpose. Discovery
# for_eaches over whatever the data source returns, so a generated non-empty
# mock would make every count assertion depend on mock noise. Each run overrides
# the specific queries it cares about with `override_data`.
mock_data "azurerm_resources" {
  defaults = {
    resources = []
  }
}

mock_resource "azurerm_monitor_diagnostic_setting" {
  defaults = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock/providers/Microsoft.Insights/diagnosticSettings/rhythmic-datadog"
  }
}
