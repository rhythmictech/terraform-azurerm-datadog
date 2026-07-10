mock_provider "azurerm" {
  source = "./tests/setup"
}

# Key Vault path: key_vault_id + datadog_api_key_secret_name set (and no direct
# key) -> exactly one Key Vault secret data source is planned.
run "key_vault_path_reads_secret" {
  command = plan

  variables {
    name                        = "example"
    region                      = "eastus"
    resource_group_name         = "rg-monitoring"
    key_vault_id                = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-kv/providers/Microsoft.KeyVault/vaults/kv-monitoring"
    datadog_api_key_secret_name = "datadog-api-key"
  }

  assert {
    condition     = length(data.azurerm_key_vault_secret.dd) == 1
    error_message = "Key Vault path must read exactly one secret data source"
  }

  assert {
    condition     = data.azurerm_key_vault_secret.dd[0].name == "datadog-api-key"
    error_message = "the Key Vault secret name should match datadog_api_key_secret_name"
  }
}

# Direct-key path: no Key Vault -> zero secret data sources.
run "direct_key_reads_no_secret" {
  command = plan

  variables {
    name                = "example"
    region              = "eastus"
    resource_group_name = "rg-monitoring"
    datadog_api_key     = "00000000000000000000000000000000"
  }

  assert {
    condition     = length(data.azurerm_key_vault_secret.dd) == 0
    error_message = "direct-key path must read zero Key Vault secret data sources"
  }
}

# Both sources set -> the exactly-one-source validation fails.
run "both_sources_rejected" {
  command = plan

  variables {
    name                        = "example"
    region                      = "eastus"
    resource_group_name         = "rg-monitoring"
    datadog_api_key             = "00000000000000000000000000000000"
    key_vault_id                = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-kv/providers/Microsoft.KeyVault/vaults/kv-monitoring"
    datadog_api_key_secret_name = "datadog-api-key"
  }

  expect_failures = [
    var.datadog_api_key,
  ]
}

# Key Vault id without the secret name -> the set-together validation fails.
run "kv_pair_incomplete_rejected" {
  command = plan

  variables {
    name                = "example"
    region              = "eastus"
    resource_group_name = "rg-monitoring"
    key_vault_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-kv/providers/Microsoft.KeyVault/vaults/kv-monitoring"
  }

  expect_failures = [
    var.key_vault_id,
  ]
}
