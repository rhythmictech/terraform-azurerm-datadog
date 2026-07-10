output "storage_account_id" {
  description = "ID of the forwarder storage account. The primary downstream seam: feed it as the destination of every diagnostic-setting / activity-log helper."
  value       = module.forwarder.storage_account_id
}

output "storage_account_name" {
  description = "Name of the forwarder storage account (the resolved override or computed default)."
  value       = module.forwarder.storage_account_name
}

output "storage_account_primary_blob_endpoint" {
  description = "Primary blob endpoint of the forwarder storage account."
  value       = module.forwarder.storage_account_primary_blob_endpoint
}

output "container_app_job_id" {
  description = "ID of the forwarder Container App job (the scheduled forwarder)."
  value       = module.forwarder.container_app_job_id
}

output "forwarder_environment_name" {
  description = "Name of the forwarder Container App environment (derived per region so multiple forwarders can share a resource group)."
  value       = local.forwarder_env_name
}

output "forwarder_job_name" {
  description = "Name of the forwarder Container App job (derived per region)."
  value       = local.forwarder_job_name
}

output "region" {
  description = "Region the forwarder was deployed to; echo the same value into the diagnostic settings that target this forwarder (same-region rule)."
  value       = var.region
}
