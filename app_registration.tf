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
  # No password is minted on the secretless path: the whole point of
  # secretless_auth_enabled is that no standing credential exists, so creating
  # one here would silently reintroduce the thing the caller opted out of.
  count = var.create_app_registration && !var.secretless_auth_enabled ? 1 : 0

  # application_id takes the Application object's *resource id* (azuread v3);
  # the secret therefore lives on the Application object's passwordCredentials,
  # which is the owner-rotatable object.
  application_id = azuread_application.this[0].id
  end_date       = var.app_registration_password_end_date
}

# Federated identity credential for the secretless path. Datadog surfaces the
# per-org Issuer and Subject values during integration setup (they are NOT
# exported by datadog_integration_azure), which forces a two-apply flow on the
# create path:
#   1. apply with secretless_auth_enabled = true and
#      datadog_federated_credential = null -- the integration exists but does
#      not authenticate yet;
#   2. read Issuer/Subject from the integration's Secretless Auth dialog in
#      Datadog, set datadog_federated_credential, and apply again.
# On the consume path the app registration lives in a tenant this module has
# no Graph access to, so the credential is added by the client instead (see
# the README).
resource "azuread_application_federated_identity_credential" "datadog" {
  count = var.create_app_registration && var.secretless_auth_enabled && var.datadog_federated_credential != null ? 1 : 0

  application_id = azuread_application.this[0].id
  display_name   = "datadog-secretless"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = var.datadog_federated_credential.issuer
  subject        = var.datadog_federated_credential.subject
}
