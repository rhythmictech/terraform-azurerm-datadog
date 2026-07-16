# Shared mock defaults for `terraform test`. Referenced from every *.tftest.hcl
# via `mock_provider "azurerm" { source = "./tests/setup" }`, so all plan-only
# tests run with no live Azure tenant. Ids are pinned so the plan-time values are
# deterministic and the parameter/output assertions can compare against them.
mock_resource "azurerm_eventhub_namespace" {
  defaults = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.EventHub/namespaces/ns"
  }
}

mock_resource "azurerm_eventhub" {
  defaults = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.EventHub/namespaces/ns/eventhubs/hub"
  }
}

mock_resource "azurerm_eventhub_authorization_rule" {
  defaults = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.EventHub/namespaces/ns/eventhubs/hub/authorizationRules/defender-export"
  }
}

mock_resource "azurerm_subscription_policy_assignment" {
  defaults = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/policyAssignments/rhythmic-defender-export"
  }
}

mock_resource "azurerm_management_group_policy_assignment" {
  defaults = {
    id = "/providers/Microsoft.Management/managementGroups/example-root/providers/Microsoft.Authorization/policyAssignments/rhythmic-defender-export"
  }
}

mock_resource "azurerm_subscription_policy_remediation" {
  defaults = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.PolicyInsights/remediations/rhythmic-defender-export-remediation"
  }
}

mock_resource "azurerm_management_group_policy_remediation" {
  defaults = {
    id = "/providers/Microsoft.Management/managementGroups/example-root/providers/Microsoft.PolicyInsights/remediations/rhythmic-defender-export-remediation"
  }
}

mock_resource "azurerm_role_assignment" {
  defaults = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleAssignments/00000000-0000-0000-0000-000000000001"
  }
}
