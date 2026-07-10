# Example: subscription Activity Log export

Wires a subscription's Activity Log to a regional forwarder's storage account.
It instantiates the `log-forwarder` module for the storage destination and
feeds its `storage_account_id` output into the `activity-log` module.

The optional tenant directory (Entra sign-in / audit) setting is left **off**
(its default); enabling it requires a directory role granted out-of-band (see
the `activity-log` module README).

## Usage

```hcl
module "log_forwarder" {
  source = "../../modules/log-forwarder"

  name                        = "example-client"
  region                      = "eastus"
  resource_group_name         = "rg-monitoring"
  key_vault_id                = var.key_vault_id
  datadog_api_key_secret_name = "datadog-api-key"
}

module "activity_log" {
  source = "../../modules/activity-log"

  subscription_id    = var.subscription_id
  storage_account_id = module.log_forwarder.storage_account_id
}
```
