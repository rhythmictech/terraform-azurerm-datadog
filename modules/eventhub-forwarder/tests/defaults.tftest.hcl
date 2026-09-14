mock_provider "azurerm" {
  source = "./tests/setup"
}

variables {
  name                        = "example-defender"
  resource_group_name         = "rg-monitoring"
  location                    = "eastus"
  event_hub_name              = "evh-defender-export"
  event_hub_connection_string = "Endpoint=sb://example.servicebus.windows.net/;SharedAccessKeyName=datadog-listen;SharedAccessKey=mock;EntityPath=evh-defender-export"
  datadog_api_key             = "00000000000000000000000000000000"
}

run "defaults_deploy_the_pinned_forwarder" {
  command = plan

  # Node 20 on Functions v4 is what the vendored package targets.
  assert {
    condition     = azurerm_linux_function_app.this.site_config[0].application_stack[0].node_version == "20"
    error_message = "the forwarder must run on Node 20"
  }

  assert {
    condition     = azurerm_linux_function_app.this.functions_extension_version == "~4"
    error_message = "the forwarder must run on Azure Functions v4"
  }

  assert {
    condition     = azurerm_linux_function_app.this.https_only == true
    error_message = "the Function App must be HTTPS only"
  }

  # Consumption plan, Linux.
  assert {
    condition     = azurerm_service_plan.this.sku_name == "Y1" && azurerm_service_plan.this.os_type == "Linux"
    error_message = "the plan should be a Linux consumption (Y1) plan"
  }

  # The package deployed is the vendored one, and it runs from the package.
  assert {
    condition     = endswith(azurerm_linux_function_app.this.zip_deploy_file, "/function/deploy.zip")
    error_message = "zip_deploy_file must point at the vendored function/deploy.zip"
  }

  assert {
    condition     = azurerm_linux_function_app.this.app_settings["WEBSITE_RUN_FROM_PACKAGE"] == "1"
    error_message = "the Function must run from the deployed package"
  }

  # The Function's environment contract, mirrored from upstream index.js.
  assert {
    condition = alltrue([
      azurerm_linux_function_app.this.app_settings["DD_SITE"] == "datadoghq.com",
      azurerm_linux_function_app.this.app_settings["DD_TAGS"] == "",
      azurerm_linux_function_app.this.app_settings["DD_PARSE_DEFENDER_LOGS"] == "true",
      azurerm_linux_function_app.this.app_settings["EVENTHUB_NAME"] == "evh-defender-export",
    ])
    error_message = "DD_SITE, DD_TAGS, DD_PARSE_DEFENDER_LOGS and EVENTHUB_NAME must carry their defaults"
  }

  assert {
    condition     = !contains(keys(azurerm_linux_function_app.this.app_settings), "DD_SOURCE") && !contains(keys(azurerm_linux_function_app.this.app_settings), "DD_SERVICE")
    error_message = "DD_SOURCE and DD_SERVICE must be absent unless set, so upstream defaults apply"
  }

  # Derived names.
  assert {
    condition     = azurerm_linux_function_app.this.name == "example-defender-datadog-forwarder" && azurerm_service_plan.this.name == "example-defender-datadog-forwarder"
    error_message = "the Function App and plan should derive <name>-datadog-forwarder"
  }

  assert {
    condition     = can(regex("^[a-z0-9]{3,24}$", azurerm_storage_account.function.name)) && startswith(azurerm_storage_account.function.name, "exampledefenderddf")
    error_message = "the storage account name must be a valid derived name from the slug"
  }

  # Storage hardening.
  assert {
    condition = alltrue([
      azurerm_storage_account.function.min_tls_version == "TLS1_2",
      azurerm_storage_account.function.https_traffic_only_enabled == true,
      azurerm_storage_account.function.allow_nested_items_to_be_public == false,
      azurerm_storage_account.function.infrastructure_encryption_enabled == true,
    ])
    error_message = "the Function storage account must be hardened (TLS 1.2, HTTPS only, no public blobs, infrastructure encryption)"
  }
}

run "tags_and_overrides_flow_through" {
  command = plan

  variables {
    datadog_tags        = ["env:prod", "client:example"]
    parse_defender_logs = false
    datadog_source      = "azure-custom"
    datadog_service     = "custom-service"
    datadog_site        = "datadoghq.eu"
  }

  assert {
    condition     = azurerm_linux_function_app.this.app_settings["DD_TAGS"] == "env:prod,client:example"
    error_message = "datadog_tags must be comma-joined into DD_TAGS"
  }

  assert {
    condition     = azurerm_linux_function_app.this.app_settings["DD_PARSE_DEFENDER_LOGS"] == "false"
    error_message = "parse_defender_logs = false must render the literal string false"
  }

  assert {
    condition     = azurerm_linux_function_app.this.app_settings["DD_SOURCE"] == "azure-custom" && azurerm_linux_function_app.this.app_settings["DD_SERVICE"] == "custom-service"
    error_message = "DD_SOURCE and DD_SERVICE must appear when set"
  }

  assert {
    condition     = azurerm_linux_function_app.this.app_settings["DD_SITE"] == "datadoghq.eu"
    error_message = "datadog_site must flow through to DD_SITE"
  }
}

run "explicit_names_are_honored" {
  command = plan

  variables {
    function_app_name    = "custom-forwarder"
    storage_account_name = "customfwdstore"
  }

  assert {
    condition     = azurerm_linux_function_app.this.name == "custom-forwarder" && azurerm_storage_account.function.name == "customfwdstore"
    error_message = "explicit function_app_name and storage_account_name must be used verbatim"
  }
}
