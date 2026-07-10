# Core Datadog <-> Azure integration. Argument names VERIFIED against
# DataDog/datadog provider v4.15.0 docs (2026-07-09):
#   tenant_name (NOT tenant/tenant_id), client_id, client_secret (sensitive),
#   comma-joined string filters, and the *_enabled flags below.
# There is NO host_tags and NO excluded_regions argument (those were AWS-only).
resource "datadog_integration_azure" "this" {
  tenant_name = local.datadog_tenant_id
  client_id   = local.datadog_client_id

  # Omit the client secret when using the (Preview) secretless federated path.
  client_secret           = var.secretless_auth_enabled ? null : local.datadog_client_secret
  secretless_auth_enabled = var.secretless_auth_enabled

  # Send null (omit) when an optional filter list is empty so we don't churn
  # "" <-> null on every plan. host_filters has a non-empty default, so join()
  # is always safe there.
  host_filters             = join(",", var.host_filters)
  app_service_plan_filters = length(var.app_service_plan_filters) > 0 ? join(",", var.app_service_plan_filters) : null
  container_app_filters    = length(var.container_app_filters) > 0 ? join(",", var.container_app_filters) : null

  automute                    = var.automute
  resource_collection_enabled = var.enable_resource_collection
  cspm_enabled                = var.enable_cspm # requires resource_collection_enabled = true (validated on enable_cspm)
  custom_metrics_enabled      = var.enable_custom_metrics
  metrics_enabled             = var.metrics_enabled
}
