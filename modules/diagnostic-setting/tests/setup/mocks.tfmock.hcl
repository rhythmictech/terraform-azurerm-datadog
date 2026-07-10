# Shared mock defaults for `terraform test`. Referenced from every *.tftest.hcl
# via `mock_provider "azurerm" { source = "./tests/setup" }`, so all plan-only
# tests run with no live Azure tenant.
mock_resource "azurerm_monitor_diagnostic_setting" {
  defaults = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock/providers/Microsoft.Insights/diagnosticSettings/rhythmic-datadog"
  }
}
