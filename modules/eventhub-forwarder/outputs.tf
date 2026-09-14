output "function_app_id" {
  description = "Resource id of the forwarder Function App."
  value       = azurerm_linux_function_app.this.id
}

output "function_app_name" {
  description = "Name of the forwarder Function App."
  value       = azurerm_linux_function_app.this.name
}

output "function_app_default_hostname" {
  description = "Default hostname of the Function App (the Function has no HTTP trigger; useful only for diagnostics)."
  value       = azurerm_linux_function_app.this.default_hostname
}

output "storage_account_id" {
  description = "Resource id of the Function runtime's storage account."
  value       = azurerm_storage_account.function.id
}

output "package_source" {
  description = "Upstream identity of the vendored forwarder package this module deploys (repository, commit, path and the forwarder's own VERSION), for change tracking."
  value       = local.package_source
}

output "package_sha256" {
  description = "sha256 of the vendored forwarder package the Function App was deployed from."
  value       = local.package_sha256
}
