mock_provider "azurerm" {
  source = "./tests/setup"
}

mock_provider "azuread" {
  source = "./tests/setup"
}

mock_provider "datadog" {
  source = "./tests/setup"
}

# Consume path with secretless auth: no client secret anywhere. The
# datadog_client_secret required-unless-secretless validation must pass, the
# integration must carry the flag, and its client_secret must be omitted.
run "consume_secretless_omits_secret" {
  command = plan

  variables {
    name                    = "example"
    datadog_client_id       = "11111111-1111-1111-1111-111111111111"
    datadog_tenant_id       = "22222222-2222-2222-2222-222222222222"
    datadog_sp_object_id    = "33333333-3333-3333-3333-333333333333"
    secretless_auth_enabled = true
    role_assignment_scopes  = []
  }

  assert {
    condition     = datadog_integration_azure.this.secretless_auth_enabled == true
    error_message = "the integration must carry secretless_auth_enabled"
  }

  assert {
    condition     = datadog_integration_azure.this.client_secret == null
    error_message = "no client secret may be sent on the secretless path"
  }
}

# Consume path WITHOUT secretless and WITHOUT a secret must fail the
# datadog_client_secret validation (the required-unless clause has teeth).
run "consume_without_secret_fails" {
  command = plan

  variables {
    name                   = "example"
    datadog_client_id      = "11111111-1111-1111-1111-111111111111"
    datadog_tenant_id      = "22222222-2222-2222-2222-222222222222"
    datadog_sp_object_id   = "33333333-3333-3333-3333-333333333333"
    role_assignment_scopes = []
  }

  expect_failures = [
    var.datadog_client_secret,
  ]
}

# Create path with secretless auth mints NO app password: the point of the
# path is that no standing credential exists, so the created registration must
# not quietly get one anyway.
run "create_secretless_mints_no_password" {
  command = plan

  variables {
    name                    = "example"
    create_app_registration = true
    secretless_auth_enabled = true
    role_assignment_scopes  = []
  }

  assert {
    condition     = length(azuread_application_password.this) == 0
    error_message = "the secretless create path must not mint an app password"
  }

  assert {
    condition     = datadog_integration_azure.this.secretless_auth_enabled == true
    error_message = "the integration must carry secretless_auth_enabled"
  }

  assert {
    condition     = length(azuread_application_federated_identity_credential.datadog) == 0
    error_message = "no federated credential should exist until issuer/subject are supplied (two-apply flow)"
  }
}

# DEFAULT-PATH GUARD: the classic create path (secretless off) still mints
# exactly one password, so the new gate cannot have broken it.
run "create_default_still_mints_password" {
  command = plan

  variables {
    name                    = "example"
    create_app_registration = true
    role_assignment_scopes  = []
  }

  assert {
    condition     = length(azuread_application_password.this) == 1
    error_message = "the classic create path must still mint exactly one app password"
  }
}

# Second apply of the two-apply flow: issuer/subject from Datadog's dialog
# produce the federated identity credential with the fixed audience.
run "create_secretless_fic" {
  command = plan

  variables {
    name                    = "example"
    create_app_registration = true
    secretless_auth_enabled = true
    role_assignment_scopes  = []
    datadog_federated_credential = {
      issuer  = "https://example-issuer.invalid/from-datadog-dialog"
      subject = "example-subject-from-datadog-dialog"
    }
  }

  assert {
    condition     = length(azuread_application_federated_identity_credential.datadog) == 1
    error_message = "supplying issuer/subject on the secretless create path must plan the federated credential"
  }

  assert {
    condition     = azuread_application_federated_identity_credential.datadog[0].issuer == "https://example-issuer.invalid/from-datadog-dialog"
    error_message = "the federated credential must carry the supplied issuer verbatim"
  }

  assert {
    condition     = azuread_application_federated_identity_credential.datadog[0].subject == "example-subject-from-datadog-dialog"
    error_message = "the federated credential must carry the supplied subject verbatim"
  }

  assert {
    condition     = contains(azuread_application_federated_identity_credential.datadog[0].audiences, "api://AzureADTokenExchange")
    error_message = "the federated credential audience must be api://AzureADTokenExchange"
  }
}

# datadog_federated_credential is meaningless on the consume path (the app
# registration lives in a tenant this module has no Graph access to).
run "fic_requires_create_and_secretless" {
  command = plan

  variables {
    name                    = "example"
    datadog_client_id       = "11111111-1111-1111-1111-111111111111"
    datadog_tenant_id       = "22222222-2222-2222-2222-222222222222"
    datadog_sp_object_id    = "33333333-3333-3333-3333-333333333333"
    secretless_auth_enabled = true
    role_assignment_scopes  = []
    datadog_federated_credential = {
      issuer  = "https://example-issuer.invalid"
      subject = "example-subject"
    }
  }

  expect_failures = [
    var.datadog_federated_credential,
  ]
}
