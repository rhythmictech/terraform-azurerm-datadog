mock_provider "azurerm" {
  source = "./tests/setup"
}

# Default (manage_dine_role_assignment = false): the module owns no role
# assignment. The grant is pre-created out-of-band.
run "role_assignment_gated_off" {
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
  }

  assert {
    condition     = length(azurerm_role_assignment.dine_sub) == 0
    error_message = "manage_dine_role_assignment defaults false, so no subscription role assignment should be created"
  }
  assert {
    condition     = length(azurerm_role_assignment.dine_mg) == 0
    error_message = "no management-group role assignment should be created on the default subscription path"
  }
}

# manage_dine_role_assignment = true at subscription scope: one role assignment,
# Contributor by default, scoped to the subscription.
run "role_assignment_gated_on" {
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
    manage_dine_role_assignment         = true
  }

  assert {
    condition     = length(azurerm_role_assignment.dine_sub) == 1
    error_message = "manage_dine_role_assignment = true should create exactly one subscription role assignment"
  }
  assert {
    condition     = azurerm_role_assignment.dine_sub[0].role_definition_name == "Contributor"
    error_message = "the role assignment should default to Contributor"
  }
  assert {
    condition     = azurerm_role_assignment.dine_sub[0].scope == "/subscriptions/44444444-4444-4444-4444-444444444444"
    error_message = "the role assignment should default to the subscription scope"
  }
  assert {
    condition     = azurerm_role_assignment.dine_sub[0].principal_id == "11111111-1111-1111-1111-111111111111"
    error_message = "the role assignment must target the remediation identity principal"
  }
}

# A cross-subscription hub: the grant scope is overridden to the hub's
# subscription and the role narrowed to an Event Hub data role.
run "role_assignment_scope_override" {
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
    manage_dine_role_assignment         = true
    dine_role_assignment_scope          = "/subscriptions/55555555-5555-5555-5555-555555555555"
    dine_role_definition_name           = "Azure Event Hubs Data Owner"
  }

  assert {
    condition     = azurerm_role_assignment.dine_sub[0].scope == "/subscriptions/55555555-5555-5555-5555-555555555555"
    error_message = "dine_role_assignment_scope should override the grant scope"
  }
  assert {
    condition     = azurerm_role_assignment.dine_sub[0].role_definition_name == "Azure Event Hubs Data Owner"
    error_message = "dine_role_definition_name should override the granted role"
  }
}
