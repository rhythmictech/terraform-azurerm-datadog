output "storage_account_id" {
  description = "Resource id of the archive storage account."
  value       = azurerm_storage_account.archive.id
}

output "storage_account_name" {
  description = "Name of the archive storage account, as passed to Datadog's `azure_archive` block."
  value       = azurerm_storage_account.archive.name
}

output "container_name" {
  description = "Blob container receiving the archive."
  value       = azurerm_storage_container.archive.name
}

output "archive_id" {
  description = "Datadog archive id. Useful when managing archive ORDER separately: archives are ordered per org and the first match wins, so a broad archive added to a shared org can capture logs intended for another."
  value       = datadog_logs_archive.archive.id
}

output "role_assignment_id" {
  description = "Id of the Storage Blob Data Contributor assignment granted to the Datadog service principal, or null when `create_role_assignment` is false."
  value       = try(azurerm_role_assignment.datadog_archive_writer[0].id, null)
}
