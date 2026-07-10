mock_provider "azurerm" {
  source = "./tests/setup"
}

mock_provider "azuread" {
  source = "./tests/setup"
}

mock_provider "datadog" {
  source = "./tests/setup"
}

# Create path (create_app_registration = true, consume vars null): the azuread
# app/SP/password are planned and the integration references the created app.
run "create_path" {
  command = plan

  variables {
    name                    = "example"
    create_app_registration = true
    role_assignment_scopes  = []
  }

  assert {
    condition     = length(azuread_application.this) == 1
    error_message = "create path must plan exactly one azuread_application"
  }

  assert {
    condition     = length(azuread_service_principal.this) == 1
    error_message = "create path must plan exactly one azuread_service_principal"
  }

  assert {
    condition     = length(azuread_application_password.this) == 1
    error_message = "create path must plan exactly one azuread_application_password"
  }

  assert {
    condition     = azuread_application.this[0].display_name == "Datadog-example"
    error_message = "created app display name should default to Datadog-<name>"
  }
}

# Custom display name override is honored.
run "create_path_custom_display_name" {
  command = plan

  variables {
    name                          = "example"
    create_app_registration       = true
    app_registration_display_name = "Datadog-Custom-Name"
    role_assignment_scopes        = []
  }

  assert {
    condition     = azuread_application.this[0].display_name == "Datadog-Custom-Name"
    error_message = "explicit app_registration_display_name should be used verbatim"
  }
}
