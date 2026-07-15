output "event_hub_id" {
  description = "ID of the Event Hub the export writes to (created here, or the referenced existing hub). Feed this to the Datadog Azure Event Hub log integration."
  value       = local.eventhub_id
}

output "event_hub_authorization_rule_id" {
  description = "ID of the SEND authorization rule used by the export policy. This is the send credential only; a consumer (e.g. Datadog) must use a separate listen-only rule and never this id."
  value       = local.eventhub_auth_id
}

output "event_hub_namespace_id" {
  description = "ID of the created Event Hub namespace (null when create_event_hub = false). Use it to author consumer-group, diagnostic, or listen-rule resources."
  value       = try(azurerm_eventhub_namespace.this[0].id, null)
}

output "policy_assignment_id" {
  description = "ID of the active policy assignment (subscription- or management-group-scoped, per scope_type). Useful for remediation status checks and imports."
  value       = try(azurerm_subscription_policy_assignment.defender_export[0].id, azurerm_management_group_policy_assignment.defender_export[0].id, null)
}
