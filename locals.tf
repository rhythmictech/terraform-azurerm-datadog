locals {
  create = var.create_app_registration

  # Id indirection: resolve either the consumed input vars (default/consume path)
  # OR the created azuread resource attributes (create path). This keeps the
  # datadog_integration_azure body identical on both paths.
  #
  # azuread v3 attribute names: `client_id` (was application_id), `object_id`,
  # and application_password.value.
  datadog_client_id     = local.create ? azuread_application.this[0].client_id : var.datadog_client_id
  datadog_tenant_id     = local.create ? data.azuread_client_config.current[0].tenant_id : var.datadog_tenant_id
  datadog_sp_object_id  = local.create ? azuread_service_principal.this[0].object_id : var.datadog_sp_object_id
  datadog_client_secret = local.create ? azuread_application_password.this[0].value : var.datadog_client_secret

  app_registration_display_name = coalesce(var.app_registration_display_name, "Datadog-${var.name}")
}
