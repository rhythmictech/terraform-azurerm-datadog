mock_provider "azurerm" {
  source = "./tests/setup"
}

# Primary path (scope_type defaults to "subscription"): exactly one
# subscription-scoped assignment, the corrected DINE parameters, and a
# ReEvaluateCompliance remediation.
run "subscription_scope_defaults" {
  # apply (mock-backed, offline) so the created send-rule id is known and the
  # decoded-parameter assertions below are meaningful; plan leaves the
  # jsonencode(parameters) string unknown because it embeds a computed id.
  command = apply

  variables {
    subscription_id                     = "44444444-4444-4444-4444-444444444444"
    location                            = "eastus"
    export_resource_group_name          = "rg-defender-export"
    user_assigned_identity_id           = "/subscriptions/44444444-4444-4444-4444-444444444444/resourceGroups/rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/dine-remediation"
    user_assigned_identity_principal_id = "11111111-1111-1111-1111-111111111111"
    event_hub_namespace_name            = "defender-export-ns"
    event_hub_name                      = "hub"
    event_hub_resource_group_name       = "rg"
  }

  # Exactly one subscription assignment, and no management-group assignment.
  assert {
    condition     = length(azurerm_subscription_policy_assignment.defender_export) == 1
    error_message = "the subscription scope should create exactly one subscription policy assignment"
  }
  assert {
    condition     = length(azurerm_management_group_policy_assignment.defender_export) == 0
    error_message = "the subscription scope must not create a management-group policy assignment"
  }

  # location is set (required whenever an identity block is present).
  assert {
    condition     = azurerm_subscription_policy_assignment.defender_export[0].location == "eastus"
    error_message = "the assignment location must be set to var.location"
  }

  # The built-in continuous-export definition is the default.
  assert {
    condition     = azurerm_subscription_policy_assignment.defender_export[0].policy_definition_id == "/providers/Microsoft.Authorization/policyDefinitions/cdfcce10-4578-4ecd-9703-530938e4abcb"
    error_message = "policy_definition_id should default to the built-in continuous-export definition"
  }

  # A user-assigned identity is attached.
  assert {
    condition     = azurerm_subscription_policy_assignment.defender_export[0].identity[0].type == "UserAssigned"
    error_message = "the assignment must attach a UserAssigned identity"
  }
  assert {
    condition     = contains(azurerm_subscription_policy_assignment.defender_export[0].identity[0].identity_ids, "/subscriptions/44444444-4444-4444-4444-444444444444/resourceGroups/rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/dine-remediation")
    error_message = "the assignment identity must reference the dedicated remediation identity"
  }

  # DINE parameters: the two REQUIRED params and eventHubDetails = the SEND
  # authorization-rule id. Decoding the opaque jsonencode string is the only
  # thing that catches a wrong parameter block in CI (plan/mocks stay green).
  assert {
    condition     = jsondecode(azurerm_subscription_policy_assignment.defender_export[0].parameters).resourceGroupName.value == "rg-defender-export"
    error_message = "resourceGroupName must map to var.export_resource_group_name"
  }
  assert {
    condition     = jsondecode(azurerm_subscription_policy_assignment.defender_export[0].parameters).resourceGroupLocation.value == "eastus"
    error_message = "resourceGroupLocation must map to var.location"
  }
  assert {
    condition     = jsondecode(azurerm_subscription_policy_assignment.defender_export[0].parameters).eventHubDetails.value == azurerm_eventhub_authorization_rule.export[0].id
    error_message = "eventHubDetails must be the SEND authorization-rule id, not the hub id"
  }

  # There is no eventHubAuthorizationRuleId parameter in this definition; passing
  # one is rejected at deployment, so it must never appear.
  assert {
    condition     = !contains(keys(jsondecode(azurerm_subscription_policy_assignment.defender_export[0].parameters)), "eventHubAuthorizationRuleId")
    error_message = "the parameter block must not contain an eventHubAuthorizationRuleId key"
  }

  # Optional tunables are omitted (left to the policy defaults) unless set.
  assert {
    condition     = !contains(keys(jsondecode(azurerm_subscription_policy_assignment.defender_export[0].parameters)), "alertSeverities")
    error_message = "alertSeverities must be omitted unless alert_severities is set"
  }

  # enable_remediation defaults true -> one remediation forcing re-evaluation.
  assert {
    condition     = length(azurerm_subscription_policy_remediation.defender_export) == 1
    error_message = "enable_remediation defaults true, so one subscription remediation should be created"
  }
  assert {
    condition     = azurerm_subscription_policy_remediation.defender_export[0].resource_discovery_mode == "ReEvaluateCompliance"
    error_message = "the subscription remediation must use ReEvaluateCompliance"
  }
}

# Optional tunables flow into the parameter block only when set.
run "optional_tunables_applied" {
  # apply: the parameters string embeds the created send-rule id, so it is only
  # known after apply under the mock provider.
  command = apply

  variables {
    subscription_id                     = "44444444-4444-4444-4444-444444444444"
    location                            = "eastus"
    export_resource_group_name          = "rg-defender-export"
    user_assigned_identity_id           = "/subscriptions/44444444-4444-4444-4444-444444444444/resourceGroups/rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/dine-remediation"
    user_assigned_identity_principal_id = "11111111-1111-1111-1111-111111111111"
    event_hub_namespace_name            = "defender-export-ns"
    event_hub_name                      = "hub"
    event_hub_resource_group_name       = "rg"
    alert_severities                    = ["High", "Medium"]
  }

  assert {
    condition     = jsondecode(azurerm_subscription_policy_assignment.defender_export[0].parameters).alertSeverities.value[0] == "High"
    error_message = "alertSeverities should carry the provided override when set"
  }
}

# enable_remediation = false removes the remediation resource.
run "remediation_disabled" {
  command = plan

  variables {
    subscription_id                     = "44444444-4444-4444-4444-444444444444"
    location                            = "eastus"
    export_resource_group_name          = "rg-defender-export"
    user_assigned_identity_id           = "/subscriptions/44444444-4444-4444-4444-444444444444/resourceGroups/rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/dine-remediation"
    user_assigned_identity_principal_id = "11111111-1111-1111-1111-111111111111"
    event_hub_namespace_name            = "defender-export-ns"
    event_hub_name                      = "hub"
    event_hub_resource_group_name       = "rg"
    enable_remediation                  = false
  }

  assert {
    condition     = length(azurerm_subscription_policy_remediation.defender_export) == 0
    error_message = "enable_remediation = false should create no remediation resource"
  }
}
