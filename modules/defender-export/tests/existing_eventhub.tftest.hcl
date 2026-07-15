mock_provider "azurerm" {
  source = "./tests/setup"
}

# create_event_hub = false: reference an existing hub; create no Event Hub
# resources; the event_hub_id output echoes the existing hub id.
run "existing_event_hub" {
  command = plan

  variables {
    subscription_id                          = "44444444-4444-4444-4444-444444444444"
    location                                 = "eastus"
    export_resource_group_name               = "rg-defender-export"
    user_assigned_identity_id                = "/subscriptions/44444444-4444-4444-4444-444444444444/resourceGroups/rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/dine-remediation"
    user_assigned_identity_principal_id      = "11111111-1111-1111-1111-111111111111"
    create_event_hub                         = false
    existing_event_hub_id                    = "/subscriptions/55555555-5555-5555-5555-555555555555/resourceGroups/central/providers/Microsoft.EventHub/namespaces/central-ns/eventhubs/defender"
    existing_event_hub_authorization_rule_id = "/subscriptions/55555555-5555-5555-5555-555555555555/resourceGroups/central/providers/Microsoft.EventHub/namespaces/central-ns/eventhubs/defender/authorizationRules/send"
  }

  assert {
    condition     = length(azurerm_eventhub_namespace.this) == 0
    error_message = "create_event_hub = false must create no Event Hub namespace"
  }
  assert {
    condition     = length(azurerm_eventhub.this) == 0
    error_message = "create_event_hub = false must create no Event Hub"
  }
  assert {
    condition     = length(azurerm_eventhub_authorization_rule.export) == 0
    error_message = "create_event_hub = false must create no authorization rule"
  }

  assert {
    condition     = output.event_hub_id == "/subscriptions/55555555-5555-5555-5555-555555555555/resourceGroups/central/providers/Microsoft.EventHub/namespaces/central-ns/eventhubs/defender"
    error_message = "event_hub_id output must echo existing_event_hub_id"
  }
  assert {
    condition     = output.event_hub_authorization_rule_id == "/subscriptions/55555555-5555-5555-5555-555555555555/resourceGroups/central/providers/Microsoft.EventHub/namespaces/central-ns/eventhubs/defender/authorizationRules/send"
    error_message = "event_hub_authorization_rule_id output must echo the existing send rule id"
  }
  assert {
    condition     = output.event_hub_namespace_id == null
    error_message = "event_hub_namespace_id must be null when no namespace is created"
  }

  # The existing send rule id flows into the policy eventHubDetails parameter.
  assert {
    condition     = jsondecode(azurerm_subscription_policy_assignment.defender_export[0].parameters).eventHubDetails.value == "/subscriptions/55555555-5555-5555-5555-555555555555/resourceGroups/central/providers/Microsoft.EventHub/namespaces/central-ns/eventhubs/defender/authorizationRules/send"
    error_message = "eventHubDetails must be the existing send authorization-rule id"
  }
}

# Default create path: namespace + hub + send-only authorization rule.
run "create_event_hub_default" {
  # apply so the created namespace id is known for the output assertion below.
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

  assert {
    condition     = length(azurerm_eventhub_namespace.this) == 1
    error_message = "create_event_hub defaults true, so one namespace should be created"
  }
  assert {
    condition     = length(azurerm_eventhub.this) == 1
    error_message = "create_event_hub defaults true, so one hub should be created"
  }
  assert {
    condition     = length(azurerm_eventhub_authorization_rule.export) == 1
    error_message = "create_event_hub defaults true, so one authorization rule should be created"
  }

  # The rule is send-only (send credential for the export; not for listeners).
  assert {
    condition     = azurerm_eventhub_authorization_rule.export[0].send == true
    error_message = "the export authorization rule must grant send"
  }
  assert {
    condition     = azurerm_eventhub_authorization_rule.export[0].listen == false
    error_message = "the export authorization rule must not grant listen"
  }
  assert {
    condition     = azurerm_eventhub_authorization_rule.export[0].manage == false
    error_message = "the export authorization rule must not grant manage"
  }

  # The namespace id is surfaced for consumer/listen-rule wiring.
  assert {
    condition     = output.event_hub_namespace_id == azurerm_eventhub_namespace.this[0].id
    error_message = "event_hub_namespace_id must expose the created namespace id"
  }
}
