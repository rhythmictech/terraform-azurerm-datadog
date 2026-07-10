output "activity_log_diagnostic_setting_id" {
  description = "ID of the subscription (or management-group) Activity Log diagnostic setting."
  value       = azurerm_monitor_diagnostic_setting.activity_log.id
}

output "entra_diagnostic_setting_id" {
  description = "ID of the tenant directory diagnostic setting (null unless enable_entra_diagnostics = true)."
  value       = try(azurerm_monitor_aad_diagnostic_setting.entra[0].id, null)
}
