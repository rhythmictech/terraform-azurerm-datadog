mock_provider "azurerm" {
  source = "./tests/setup"
}

# Direct-key path: no Key Vault, a safe storage name is derived, and the region
# is echoed through. Assertions stay on config-derived outputs (the derived name
# and region), never on computed child-module attributes.
run "direct_key_defaults" {
  command = plan

  variables {
    name                = "example"
    region              = "eastus"
    resource_group_name = "rg-monitoring"
    datadog_api_key     = "00000000000000000000000000000000"
  }

  # No Key Vault secret is read on the direct path.
  assert {
    condition     = length(data.azurerm_key_vault_secret.dd) == 0
    error_message = "direct-key path must read zero Key Vault secrets"
  }

  # The derived storage name is a valid, <=24-char, [a-z0-9] global name.
  assert {
    condition     = can(regex("^[a-z0-9]{3,24}$", output.storage_account_name))
    error_message = "derived storage_account_name must be 3-24 lowercase alphanumeric characters"
  }

  # Pin the exact derivation: <=18-char cleaned "<name>dd<region>" prefix + a
  # 6-char sha1(name+region) suffix. A regression that drops region from either
  # the prefix or the hash changes this value (guards cross-region uniqueness).
  assert {
    condition     = output.storage_account_name == "exampleddeastuse95175"
    error_message = "storage_account_name derivation changed unexpectedly"
  }

  # Container App environment/job names are uniquified per region so two regional
  # forwarders can share one resource group (the child defaults them to statics).
  assert {
    condition     = output.forwarder_environment_name == "example-ddfwd-env-eastus"
    error_message = "forwarder environment name must be derived per region"
  }
  assert {
    condition     = output.forwarder_job_name == "example-ddfwd-eastus"
    error_message = "forwarder job name must be derived per region"
  }

  # The region is echoed for the same-region diagnostic-setting wiring.
  assert {
    condition     = output.region == "eastus"
    error_message = "region output should echo the input region"
  }
}

# An explicit storage-account override is passed straight through.
run "storage_name_override" {
  command = plan

  variables {
    name                 = "example"
    region               = "eastus"
    resource_group_name  = "rg-monitoring"
    datadog_api_key      = "00000000000000000000000000000000"
    storage_account_name = "myddlogstore01"
  }

  assert {
    condition     = output.storage_account_name == "myddlogstore01"
    error_message = "an explicit storage_account_name must be used verbatim"
  }
}
