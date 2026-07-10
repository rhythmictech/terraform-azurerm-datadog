output "diagnostic_setting_ids" {
  description = "Map of created diagnostic-setting ids keyed by the input `target_resource_ids` key."
  value       = { for k, v in azurerm_monitor_diagnostic_setting.this : k => v.id }
}
