# logs-archive

Creates the Azure side of a Datadog log archive (storage account, private
container, retention lifecycle, and the blob-writer role grant) plus the
`datadog_logs_archive` that points at it. One archive serves every region.

## Contract

- **Only the Hot and Cool access tiers are usable.** Datadog states that
  archiving and Archive Search support the Hot and Cool access tiers only. A blob
  in Azure's **Cold** or **Archive** tier is written successfully and then cannot
  be rehydrated, so the failure is invisible until someone needs the data. The
  account is created `Hot` and the lifecycle rule offers `tier_to_cool` and
  `delete` and **nothing else**. The action set is fixed in code rather than
  exposed as a variable precisely so an unsupported tier cannot be selected by
  passing a number. Note that Azure's tier ladder is Hot, Cool, **Cold**, Archive:
  Cold is a distinct tier from Cool and is not supported.
- **No immutability policy, deliberately.** Datadog's documentation says: "Do not
  set immutability policies because the last data needs to be rewritten in some
  rare cases (typically a timeout)." Separately,
  `azurerm_storage_container_immutability_policy` with `locked = true` cannot be
  unlocked, its retention can only be increased, and it makes the container and
  storage account permanently undeletable. This module therefore uses **blob
  versioning plus soft delete** as its tamper-resistance mechanism. If you came
  here to add an immutability policy, this paragraph is the reason not to.
- **No new app registration.** The archive is written by the **same** app
  registration used for the Azure integration, which is what Datadog's own setup
  instructions direct you to use. Pass its `client_id` and tenant, plus the
  service principal's object id for the role grant. Where creating app
  registrations is a customer-side action, this module needs nothing from them.
- **The role grant is a data-plane grant.** `Storage Blob Data Contributor` is a
  DataAction role, so it cannot be granted through a management-plane-only
  delegation. The applying identity needs RBAC write on the scope. The assignment
  is scoped to the **storage account**, never the resource group.
- **No region on the archive.** `azure_archive` takes no region, unlike the
  per-region forwarder seam. `var.region` here places the storage account only.
- **Archives are ordered per Datadog org, and the first match wins.** This module
  does **not** manage `datadog_logs_archive_order`. In an org serving more than
  one account, adding an archive with a broad `query` can capture logs intended
  for another archive. Check the org's existing archives before applying, and
  treat reordering as a deliberate cross-account change rather than a side effect
  of onboarding.

## Caller requirements when `shared_access_key_enabled` is false (the default)

Account keys are disabled by default: Datadog writes as the app registration over
Entra auth, so a long-lived key on a store holding years of logs buys nothing.
Two consequences land on the caller:

- The applying identity manages the container over Entra data-plane auth, so the
  `azurerm` provider needs `storage_use_azuread = true` and the identity needs a
  blob data role. Without both, container creation fails.
- The azurerm provider documents that **updating** `container_access_type` always
  uses Shared Key. This module only ever sets `private`, so that path is not
  exercised, but changing it later requires keys back on.

Set `shared_access_key_enabled = true` if either constraint is unacceptable.

## Cost

A two-year retention archive accumulates. The defaults tier to Cool at 90 days
and delete at 731, which is the cheapest shape that keeps everything rehydratable.
`storage_account_replication_type` defaults to `LRS`; `GRS` or `GZRS` roughly
doubles storage cost for cross-region durability, which may be worth it for a
compliance archive and is not the default.

## Usage

```hcl
module "log_archive" {
  source = "rhythmictech/datadog/azurerm//modules/logs-archive"

  name                = "example"
  resource_group_name = azurerm_resource_group.monitoring.name
  region              = "eastus"

  # The existing Azure-integration app registration, reused.
  datadog_client_id    = var.datadog_client_id
  datadog_tenant_id    = var.datadog_tenant_id
  datadog_sp_object_id = var.datadog_sp_object_id

  tags = module.tags.tags
}
```

Narrowing what the archive captures, and keeping rehydrated logs distinguishable:

```hcl
module "log_archive" {
  # ...
  archive_query    = "env:prod"
  rehydration_tags = ["source:archive"]

  tier_to_cool_after_days = 30
  delete_after_days       = 365
}
```

## Rehydration

Rehydration is a Datadog-side operation, not a Terraform one. What this module
controls is whether it can succeed: blobs stay in Hot or Cool, `include_tags`
defaults to `true` so rehydrated records come back with their tags, and
`rehydration_max_scan_size_in_gb` can cap how much a single rehydration scans.
Verify a rehydration once against a real archive; a green apply proves the archive
exists, not that it can be read back.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 4.0 |
| <a name="requirement_datadog"></a> [datadog](#requirement\_datadog) | ~> 4.15 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | ~> 4.0 |
| <a name="provider_datadog"></a> [datadog](#provider\_datadog) | ~> 4.15 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [azurerm_role_assignment.datadog_archive_writer](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_storage_account.archive](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account) | resource |
| [azurerm_storage_container.archive](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_container) | resource |
| [azurerm_storage_management_policy.archive](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_management_policy) | resource |
| [datadog_logs_archive.archive](https://registry.terraform.io/providers/DataDog/datadog/latest/docs/resources/logs_archive) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_archive_name"></a> [archive\_name](#input\_archive\_name) | Datadog archive name. Defaults to `name`. | `string` | `null` | no |
| <a name="input_archive_path"></a> [archive\_path](#input\_archive\_path) | Optional prefix within the container for archived objects. | `string` | `null` | no |
| <a name="input_archive_query"></a> [archive\_query](#input\_archive\_query) | Datadog log query selecting what this archive receives. `*` archives everything reaching the org, which is the usual intent for a retention archive. NOTE: archives in a Datadog org are ORDERED and the first match wins, so a broad query on a shared org can capture logs intended for another archive. | `string` | `"*"` | no |
| <a name="input_blob_soft_delete_retention_days"></a> [blob\_soft\_delete\_retention\_days](#input\_blob\_soft\_delete\_retention\_days) | Blob soft-delete retention window. Together with versioning this is the tamper-resistance mechanism used INSTEAD of an immutability policy; see the module README for why immutability is deliberately not offered. | `number` | `7` | no |
| <a name="input_container_name"></a> [container\_name](#input\_container\_name) | Blob container that receives the archive. | `string` | `"datadog-log-archive"` | no |
| <a name="input_create_role_assignment"></a> [create\_role\_assignment](#input\_create\_role\_assignment) | Grant the Datadog service principal `Storage Blob Data Contributor` on the archive storage account. This is a data-plane (DataAction) grant, so the applying identity needs RBAC write plus data-plane rights, not Lighthouse delegation. Set false when the grant is made out of band. | `bool` | `true` | no |
| <a name="input_datadog_client_id"></a> [datadog\_client\_id](#input\_datadog\_client\_id) | Client (application) id of the Datadog Azure integration app registration. Datadog authenticates to the archive container as this identity. | `string` | n/a | yes |
| <a name="input_datadog_sp_object_id"></a> [datadog\_sp\_object\_id](#input\_datadog\_sp\_object\_id) | Object id of the Datadog app registration's service principal, used as the role-assignment principal. Required when `create_role_assignment` is true. | `string` | `null` | no |
| <a name="input_datadog_tenant_id"></a> [datadog\_tenant\_id](#input\_datadog\_tenant\_id) | Entra tenant id containing the Datadog app registration. | `string` | n/a | yes |
| <a name="input_delete_after_days"></a> [delete\_after\_days](#input\_delete\_after\_days) | Days after last modification before archive blobs are deleted. Defaults to roughly two years, matching the retention of the AWS-side equivalent. | `number` | `731` | no |
| <a name="input_include_tags"></a> [include\_tags](#input\_include\_tags) | Store log tags in the archived records. Defaults true so rehydrated logs come back with their tags, which is what makes an archive searchable after the fact. | `bool` | `true` | no |
| <a name="input_name"></a> [name](#input\_name) | Short name for this archive, used to derive resource names and as the default Datadog archive name. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Azure region for the archive storage account. Unlike the log forwarder, the archive has no co-regional constraint: `azure_archive` takes no region, so a single archive serves every region. | `string` | n/a | yes |
| <a name="input_rehydration_max_scan_size_in_gb"></a> [rehydration\_max\_scan\_size\_in\_gb](#input\_rehydration\_max\_scan\_size\_in\_gb) | Cap on how much archived data a single rehydration may scan. null leaves it unlimited. | `number` | `null` | no |
| <a name="input_rehydration_tags"></a> [rehydration\_tags](#input\_rehydration\_tags) | Tags applied to logs rehydrated from this archive, for distinguishing them from live ingestion. | `list(string)` | `[]` | no |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Existing resource group that holds the archive storage account. | `string` | n/a | yes |
| <a name="input_shared_access_key_enabled"></a> [shared\_access\_key\_enabled](#input\_shared\_access\_key\_enabled) | Allow Shared Key (account key) authorization on the archive storage account.<br/><br/>Defaults to **false**: Datadog writes the archive as the app registration over<br/>Entra auth, so account keys are not needed for the data path, and disabling<br/>them removes a long-lived credential from a store holding two years of logs.<br/><br/>Two caller-side consequences of the default:<br/><br/>- The applying identity manages the container over Entra data-plane auth, so<br/>  the `azurerm` provider needs `storage_use_azuread = true` and the identity<br/>  needs a blob data role. Without that, container creation fails.<br/>- The azurerm provider documents that **updating** `container_access_type`<br/>  always uses Shared Key. This module only ever sets `private`, so that path<br/>  is not exercised, but a caller who later changes it will need keys back on.<br/><br/>Set true if either constraint is unacceptable. | `bool` | `false` | no |
| <a name="input_storage_account_name"></a> [storage\_account\_name](#input\_storage\_account\_name) | Override the derived storage account name. Must be globally unique, 3 to 24 characters, lowercase alphanumeric only. Leave null to derive it from `name` plus a deterministic hash. | `string` | `null` | no |
| <a name="input_storage_account_replication_type"></a> [storage\_account\_replication\_type](#input\_storage\_account\_replication\_type) | Replication for the archive storage account. `GRS` or `GZRS` is worth considering for a two-year retention store, at roughly double the cost. | `string` | `"LRS"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the created Azure resources. | `map(string)` | `{}` | no |
| <a name="input_tier_to_cool_after_days"></a> [tier\_to\_cool\_after\_days](#input\_tier\_to\_cool\_after\_days) | Days after last modification before archive blobs move to the Cool tier. | `number` | `90` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_archive_id"></a> [archive\_id](#output\_archive\_id) | Datadog archive id. Useful when managing archive ORDER separately: archives are ordered per org and the first match wins, so a broad archive added to a shared org can capture logs intended for another. |
| <a name="output_container_name"></a> [container\_name](#output\_container\_name) | Blob container receiving the archive. |
| <a name="output_role_assignment_id"></a> [role\_assignment\_id](#output\_role\_assignment\_id) | Id of the Storage Blob Data Contributor assignment granted to the Datadog service principal, or null when `create_role_assignment` is false. |
| <a name="output_storage_account_id"></a> [storage\_account\_id](#output\_storage\_account\_id) | Resource id of the archive storage account. |
| <a name="output_storage_account_name"></a> [storage\_account\_name](#output\_storage\_account\_name) | Name of the archive storage account, as passed to Datadog's `azure_archive` block. |
<!-- END_TF_DOCS -->
