# OPTIONAL create path (count-gated, default OFF).
#
# Only exercised when create_app_registration = true (sandbox / self-service
# tenants). On the default (consume) path every resource here is count = 0, so
# the azuread provider makes no Graph calls and consumers need no Entra/Graph
# credentials.
#
# WARNING: enabling this requires the deploying identity to hold Microsoft Graph
# write (Application Administrator). Do not enable it on a pipeline whose
# identity has no Graph access -- these resources would simply fail.

data "azuread_client_config" "current" {
  count = var.create_app_registration ? 1 : 0
}

resource "azuread_application" "this" {
  count        = var.create_app_registration ? 1 : 0
  display_name = local.app_registration_display_name
}

resource "azuread_service_principal" "this" {
  count     = var.create_app_registration ? 1 : 0
  client_id = azuread_application.this[0].client_id
}

resource "azuread_application_password" "this" {
  count = var.create_app_registration ? 1 : 0

  # application_id takes the Application object's *resource id* (azuread v3);
  # the secret therefore lives on the Application object's passwordCredentials,
  # which is the owner-rotatable object.
  application_id = azuread_application.this[0].id
  end_date       = var.app_registration_password_end_date
}
