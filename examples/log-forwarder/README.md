# Example: regional log forwarder

Deploys a single regional Datadog log forwarder (Container App job + Storage)
via the `log-forwarder` module. The Datadog API key is sourced from an existing
Key Vault rather than passed as plaintext.

Deploy **one instance per region**: a diagnostic setting can only ship to a
storage account in the same region, so each monitored region needs its own
forwarder as the destination.

The module re-exports `storage_account_id`, which is the destination you feed to
the `diagnostic-setting` and `activity-log` modules.

## Usage

```hcl
module "log_forwarder" {
  source = "../../modules/log-forwarder"

  name                = "example-client"
  region              = "eastus"
  resource_group_name = "rg-monitoring"

  key_vault_id                = var.key_vault_id
  datadog_api_key_secret_name = "datadog-api-key"
}
```
