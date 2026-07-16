mock_provider "azurerm" {
  source = "./tests/setup"
}

# Management-group scope (the documented future path): exactly one
# management-group assignment, no subscription assignment, and a remediation
# with no resource_discovery_mode (unavailable at this scope).
run "management_group_scope" {
  # apply (mock-backed, offline) so the created send-rule id is known for the
  # decoded-parameter assertions.
  command = apply

  variables {
    scope_type                          = "management_group"
    management_group_id                 = "/providers/Microsoft.Management/managementGroups/example-root"
    location                            = "eastus"
    export_resource_group_name          = "rg-defender-export"
    user_assigned_identity_id           = "/subscriptions/44444444-4444-4444-4444-444444444444/resourceGroups/rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/dine-remediation"
    user_assigned_identity_principal_id = "11111111-1111-1111-1111-111111111111"
    event_hub_namespace_name            = "defender-export-ns"
    event_hub_name                      = "hub"
    event_hub_resource_group_name       = "rg"
  }

  # Exactly one management-group assignment, and no subscription assignment.
  assert {
    condition     = length(azurerm_management_group_policy_assignment.defender_export) == 1
    error_message = "the management-group scope should create exactly one management-group policy assignment"
  }
  assert {
    condition     = length(azurerm_subscription_policy_assignment.defender_export) == 0
    error_message = "the management-group scope must not create a subscription policy assignment"
  }

  # The assignment targets the management group and sets location + identity.
  assert {
    condition     = azurerm_management_group_policy_assignment.defender_export[0].management_group_id == "/providers/Microsoft.Management/managementGroups/example-root"
    error_message = "the assignment must target the provided management group"
  }
  assert {
    condition     = azurerm_management_group_policy_assignment.defender_export[0].location == "eastus"
    error_message = "the management-group assignment location must be set"
  }
  assert {
    condition     = azurerm_management_group_policy_assignment.defender_export[0].identity[0].type == "UserAssigned"
    error_message = "the management-group assignment must attach a UserAssigned identity"
  }

  # Same corrected DINE parameter block as the subscription path.
  assert {
    condition     = jsondecode(azurerm_management_group_policy_assignment.defender_export[0].parameters).resourceGroupName.value == "rg-defender-export"
    error_message = "resourceGroupName must map to var.export_resource_group_name"
  }
  assert {
    condition     = jsondecode(azurerm_management_group_policy_assignment.defender_export[0].parameters).eventHubDetails.value == azurerm_eventhub_authorization_rule.export[0].id
    error_message = "eventHubDetails must be the SEND authorization-rule id"
  }
  assert {
    condition     = !contains(keys(jsondecode(azurerm_management_group_policy_assignment.defender_export[0].parameters)), "eventHubAuthorizationRuleId")
    error_message = "the parameter block must not contain an eventHubAuthorizationRuleId key"
  }

  # One management-group remediation is created (enable_remediation defaults true).
  assert {
    condition     = length(azurerm_management_group_policy_remediation.defender_export) == 1
    error_message = "enable_remediation defaults true, so one management-group remediation should be created"
  }
  assert {
    condition     = length(azurerm_subscription_policy_remediation.defender_export) == 0
    error_message = "the management-group scope must not create a subscription remediation"
  }
}
