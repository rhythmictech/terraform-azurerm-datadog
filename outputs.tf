output "integration_id" {
  description = "The datadog_integration_azure resource id."
  value       = datadog_integration_azure.this.id
}

output "datadog_tenant_id" {
  description = "Resolved Entra tenant id used by the integration (consumed input or created app's tenant)."
  value       = local.datadog_tenant_id
}

output "datadog_client_id" {
  description = "Resolved Datadog app client id used by the integration (consumed input or created app)."
  value       = local.datadog_client_id
}

output "datadog_sp_object_id" {
  description = "Resolved Datadog service-principal object id (the principal used for role assignments)."
  value       = local.datadog_sp_object_id
}

output "app_registration_object_id" {
  description = "Object id of the created Datadog app registration (null unless create_app_registration = true); the owner-rotation target."
  value       = try(azuread_application.this[0].object_id, null)
}

output "role_assignment_ids" {
  description = "Map of Monitoring Reader role-assignment ids keyed by subscription scope (empty unless manage_datadog_sp_role_assignment = true)."
  value       = { for k, v in azurerm_role_assignment.datadog : k => v.id }
}
