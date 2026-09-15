# terraform-azurerm-datadog//modules/eventhub-forwarder

Deploys Datadog's **Azure Event Hub log forwarder** as a consumption-plan Azure
Function, from a vendored, hash-pinned package. It is the consumer half of the
Event Hub seam: anything that can only export to an Event Hub (Microsoft Defender
for Cloud continuous export, Activity Log exports, diagnostic settings that target
a hub) lands in Datadog Log Management through this Function.

It is deliberately distinct from the [`log-forwarder`](../log-forwarder) submodule,
which is Datadog's blob-fed Container Apps forwarder for per-resource diagnostic
logs. Use that one for diagnostic settings; use this one for sources that cannot
write to blob.

## What it creates

- A hardened Standard LRS storage account for the Function runtime.
- A Linux consumption (Y1) App Service plan.
- A Linux Function App (Node 20, Functions v4, HTTPS only) running Datadog's
  forwarder, deployed with `zip_deploy_file` from `function/deploy.zip` and set
  to run from the package. The Function registers its own Event Hub trigger in
  code: hub `EVENTHUB_NAME`, consumer group `$Default`, connection from the
  `EVENTHUB_CONNECTION_STRING` app setting.

## The pinned package

`function/deploy.zip` is Datadog's `azure/activity_logs_monitoring` forwarder at a
fixed upstream commit, vendored verbatim; see [`function/PIN.md`](function/PIN.md)
for the commit, the forwarder's own `VERSION`, the sha256 and the refresh
procedure. The Function App carries a `precondition` comparing the file on disk to
that sha256, so a swapped or corrupted package fails the plan rather than being
deployed. Refresh the pin deliberately; never point the module at `master`.

## Inputs that matter

- **`event_hub_connection_string` must be a LISTEN-only credential.** Author a
  dedicated listen rule on the hub (or namespace) and pass its connection string.
  Never reuse the send rule an exporter writes with: the consumer must not be able
  to write to the hub. The `defender-export` submodule creates only the send rule
  for exactly this reason.
- **`datadog_api_key`**: a Datadog API key. Consider a key dedicated to the
  forwarder so it can be revoked without touching the integration.
- **`datadog_tags`**: appended to every forwarded record (comma-joined into
  `DD_TAGS`).
- **`parse_defender_logs`** (default `true`): the forwarder's built-in Microsoft
  Defender for Cloud handling. When a record is a Defender alert, assessment,
  sub-assessment or secure-score record, the forwarder sets
  `source:microsoft-defender-for-cloud` and a `service` of **`SecurityAlerts`**,
  **`SecurityRecommendations`**, **`SecurityFindings`** or **`SecureScore`**. Monitors
  that need to split alerts from recommendations should discriminate on that
  `service` tag.

## Pairing with `defender-export`

```hcl
module "defender_export" {
  source = "rhythmictech/datadog/azurerm//modules/defender-export"
  # ... creates the namespace, hub and the SEND rule
}

resource "azurerm_eventhub_authorization_rule" "datadog_listen" {
  name                = "datadog-listen"
  namespace_name      = "<namespace>"
  eventhub_name       = "<hub>"
  resource_group_name = "<rg>"
  listen              = true
  send                = false
  manage              = false
}

module "eventhub_forwarder" {
  source = "rhythmictech/datadog/azurerm//modules/eventhub-forwarder"

  name                = "example-defender"
  resource_group_name = "<rg>"
  location            = "eastus"

  event_hub_name              = "<hub>"
  event_hub_connection_string = azurerm_eventhub_authorization_rule.datadog_listen.primary_connection_string

  datadog_api_key = var.datadog_api_key
  datadog_tags    = ["subscription_name:example"]
}
```

## Secrets in state

The Datadog API key, the Event Hub listen connection string and the storage
account key are held in Terraform state and in the Function App's configuration.
Treat the state backend accordingly; this is the same posture as the other
submodules that configure Datadog credentials.

## Running the tests

Unit tests live in `tests/` and run plan-only against a mocked `azurerm`
provider. They assert the runtime pins, the app-settings contract, name
derivation, storage hardening, the input validations, and that the vendored
package matches its pinned hash.

```bash
terraform init -backend=false
terraform test
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 4.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | ~> 4.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [azurerm_linux_function_app.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_function_app) | resource |
| [azurerm_service_plan.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/service_plan) | resource |
| [azurerm_storage_account.function](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_datadog_api_key"></a> [datadog\_api\_key](#input\_datadog\_api\_key) | Datadog API key the Function submits logs with. | `string` | n/a | yes |
| <a name="input_datadog_service"></a> [datadog\_service](#input\_datadog\_service) | Optional service tag the forwarder assigns to records it cannot classify. Passed as DD\_SERVICE when set. | `string` | `null` | no |
| <a name="input_datadog_site"></a> [datadog\_site](#input\_datadog\_site) | Datadog site the Function submits to (`datadoghq.com` for US1). Passed as DD\_SITE. | `string` | `"datadoghq.com"` | no |
| <a name="input_datadog_source"></a> [datadog\_source](#input\_datadog\_source) | Optional override for the source the forwarder assigns to records it cannot classify from their resource id (`azure` by default). Passed as DD\_SOURCE when set. | `string` | `null` | no |
| <a name="input_datadog_tags"></a> [datadog\_tags](#input\_datadog\_tags) | Tags appended to every forwarded log, passed to the Function as the comma-joined DD\_TAGS. | `list(string)` | `[]` | no |
| <a name="input_event_hub_connection_string"></a> [event\_hub\_connection\_string](#input\_event\_hub\_connection\_string) | Connection string of a LISTEN-only authorization rule on the hub or its namespace. Never pass a send or manage credential: the consumer must not be able to write to the hub. Passed to the Function as EVENTHUB\_CONNECTION\_STRING. | `string` | n/a | yes |
| <a name="input_event_hub_name"></a> [event\_hub\_name](#input\_event\_hub\_name) | Name of the Event Hub (topic) the Function consumes. Passed to the Function as EVENTHUB\_NAME. | `string` | n/a | yes |
| <a name="input_function_app_name"></a> [function\_app\_name](#input\_function\_app\_name) | Override the derived Function App name. Function App names are global DNS names (`<name>.azurewebsites.net`); leave null to derive `<name>-datadog-forwarder`. | `string` | `null` | no |
| <a name="input_location"></a> [location](#input\_location) | Azure region for the Function App. Event Hub triggers work across regions, but co-locating with the hub avoids egress. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Short name for this forwarder, used to derive the Function App, plan and storage account names. | `string` | n/a | yes |
| <a name="input_parse_defender_logs"></a> [parse\_defender\_logs](#input\_parse\_defender\_logs) | Enable the forwarder's built-in Microsoft Defender for Cloud parsing, which sets `source:microsoft-defender-for-cloud` and a `service` of SecurityAlerts, SecurityRecommendations, SecurityFindings or SecureScore per record. Passed as DD\_PARSE\_DEFENDER\_LOGS. | `bool` | `true` | no |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Existing resource group that receives the Function App, its plan and its storage account. | `string` | n/a | yes |
| <a name="input_storage_account_name"></a> [storage\_account\_name](#input\_storage\_account\_name) | Override the derived storage account name for the Function runtime. Must be globally unique, 3 to 24 characters, lowercase alphanumeric only. Leave null to derive it from `name` plus a deterministic hash. | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the created Azure resources. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_function_app_default_hostname"></a> [function\_app\_default\_hostname](#output\_function\_app\_default\_hostname) | Default hostname of the Function App (the Function has no HTTP trigger; useful only for diagnostics). |
| <a name="output_function_app_id"></a> [function\_app\_id](#output\_function\_app\_id) | Resource id of the forwarder Function App. |
| <a name="output_function_app_name"></a> [function\_app\_name](#output\_function\_app\_name) | Name of the forwarder Function App. |
| <a name="output_package_sha256"></a> [package\_sha256](#output\_package\_sha256) | sha256 of the vendored forwarder package the Function App was deployed from. |
| <a name="output_package_source"></a> [package\_source](#output\_package\_source) | Upstream identity of the vendored forwarder package this module deploys (repository, commit, path and the forwarder's own VERSION), for change tracking. |
| <a name="output_storage_account_id"></a> [storage\_account\_id](#output\_storage\_account\_id) | Resource id of the Function runtime's storage account. |
<!-- END_TF_DOCS -->
