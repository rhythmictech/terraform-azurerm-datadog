# log-forwarder

A thin wrapper around Datadog's official
[`forwarder`](https://registry.terraform.io/modules/DataDog/log-forwarding-datadog/azurerm/latest/submodules/forwarder)
submodule (a Container App job plus a Storage account; logs are micro-batched
from blob storage to Datadog). The wrapper adds naming/tagging conventions,
sources the Datadog API key from Key Vault (or accepts it directly), pins the
forwarder container image, and re-exports `storage_account_id` as the stable
downstream seam.

## Design rationale

Datadog maintains the forwarder itself (the Container App job and its Storage
account). This module deliberately does **not** manage any diagnostic settings:
callers keep full ownership of a single, non-clobbering diagnostic setting and
point it at the re-exported `storage_account_id` (see the `diagnostic-setting`
and `activity-log` sibling modules). This preserves one controlled setting per
resource while offloading forwarder maintenance to the upstream module.

Deploy **one forwarder per region**: a diagnostic setting can only target a
storage account in the same region, so each monitored region needs its own
forwarder storage as the destination.

The Datadog API key is a plain input to the forwarder and therefore lands in
Terraform state; prefer the Key Vault path (`key_vault_id` +
`datadog_api_key_secret_name`) and rely on an encrypted state backend.

## Version pinning

The child module `source`/`version`
(`DataDog/log-forwarding-datadog/azurerm//modules/forwarder`, pinned to
`1.0.1`) and the `forwarder_image` tag are both pinned deliberately. The child
module's own image default floats on `:latest`; the wrapper fixes it to a
specific tag for supply-chain reproducibility. Bump the module version and the
image tag together, and re-verify the child module's input set on each bump.

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

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_forwarder"></a> [forwarder](#module\_forwarder) | DataDog/log-forwarding-datadog/azurerm//modules/forwarder | 1.0.1 |

## Resources

| Name | Type |
| ---- | ---- |
| [azurerm_key_vault_secret.dd](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secret) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_datadog_api_key"></a> [datadog\_api\_key](#input\_datadog\_api\_key) | The Datadog API key value passed to the forwarder. Provide this OR the Key<br/>Vault pair (`key_vault_id` + `datadog_api_key_secret_name`), not both and not<br/>neither. It lands in Terraform state, so prefer the Key Vault path and rely<br/>on an encrypted state backend. | `string` | `null` | no |
| <a name="input_datadog_api_key_secret_name"></a> [datadog\_api\_key\_secret\_name](#input\_datadog\_api\_key\_secret\_name) | Name of the secret within `key_vault_id` that holds the Datadog API key. Must be set together with `key_vault_id`. | `string` | `null` | no |
| <a name="input_datadog_site"></a> [datadog\_site](#input\_datadog\_site) | Datadog site the forwarder ships logs to (US1 = `datadoghq.com`). Passed to the child module's `datadog_site`, which validates it against the supported site list. | `string` | `"datadoghq.com"` | no |
| <a name="input_forwarder_image"></a> [forwarder\_image](#input\_forwarder\_image) | Datadog's published forwarder container image, pinned to a specific tag for<br/>supply-chain reproducibility. The child module's own default floats on<br/>`:latest`; pinning here fixes it. Bump this tag deliberately alongside the<br/>child module version. The registry is Datadog's public ACR (anonymous pull). | `string` | `"datadoghq.azurecr.io/forwarder:v118199712-710f8585"` | no |
| <a name="input_key_vault_id"></a> [key\_vault\_id](#input\_key\_vault\_id) | ARM id of an existing Key Vault holding the Datadog API key. Set together<br/>with `datadog_api_key_secret_name`; the wrapper reads the secret via a data<br/>source and passes the value through. Requires the deploying identity to hold<br/>Key Vault secret read access. Mutually exclusive with `datadog_api_key`. | `string` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | Moniker used to derive resource names and (optionally) the storage-account name. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Azure region for the forwarder resources; passed to the child module as<br/>`location`. Must match the region of every resource whose diagnostic setting<br/>targets this forwarder's storage account (a diagnostic setting can only<br/>reach a storage account in the same region), so deploy one forwarder per<br/>region. | `string` | n/a | yes |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Name of an EXISTING resource group for the forwarder resources. The child module requires it to pre-exist (it is read via a data source, not created). | `string` | n/a | yes |
| <a name="input_storage_account_name"></a> [storage\_account\_name](#input\_storage\_account\_name) | Override the forwarder storage-account name. `null` computes a safe,<br/>globally-unique default from `name`/`region` plus a short deterministic<br/>hash. If set, must be 3-24 lowercase alphanumeric characters ([a-z0-9]);<br/>storage-account names are global, so an override must itself be unique. | `string` | `null` | no |
| <a name="input_storage_account_retention_days"></a> [storage\_account\_retention\_days](#input\_storage\_account\_retention\_days) | Days blobs are retained on the forwarder storage account before the child module's lifecycle policy deletes them. Must be at least 1. | `number` | `7` | no |
| <a name="input_storage_account_sku"></a> [storage\_account\_sku](#input\_storage\_account\_sku) | SKU for the forwarder storage account, passed through to the child module (e.g. `Standard_LRS`). | `string` | `"Standard_LRS"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every resource the forwarder module creates (storage account, Container App environment, and job). | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_container_app_job_id"></a> [container\_app\_job\_id](#output\_container\_app\_job\_id) | ID of the forwarder Container App job (the scheduled forwarder). |
| <a name="output_forwarder_environment_name"></a> [forwarder\_environment\_name](#output\_forwarder\_environment\_name) | Name of the forwarder Container App environment (derived per region so multiple forwarders can share a resource group). |
| <a name="output_forwarder_job_name"></a> [forwarder\_job\_name](#output\_forwarder\_job\_name) | Name of the forwarder Container App job (derived per region). |
| <a name="output_region"></a> [region](#output\_region) | Region the forwarder was deployed to; echo the same value into the diagnostic settings that target this forwarder (same-region rule). |
| <a name="output_storage_account_id"></a> [storage\_account\_id](#output\_storage\_account\_id) | ID of the forwarder storage account. The primary downstream seam: feed it as the destination of every diagnostic-setting / activity-log helper. |
| <a name="output_storage_account_name"></a> [storage\_account\_name](#output\_storage\_account\_name) | Name of the forwarder storage account (the resolved override or computed default). |
| <a name="output_storage_account_primary_blob_endpoint"></a> [storage\_account\_primary\_blob\_endpoint](#output\_storage\_account\_primary\_blob\_endpoint) | Primary blob endpoint of the forwarder storage account. |
<!-- END_TF_DOCS -->
