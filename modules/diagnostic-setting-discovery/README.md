# diagnostic-setting-discovery

Discovers a subscription's log-emitting resources by type and creates one
controlled diagnostic setting (default name `rhythmic-datadog`) on each, routing
every resource to a destination storage account **in its own region**.

This is the first-time rollout path: point it at a subscription, list the types
worth monitoring, give it one forwarder destination per region, and apply. Use
the sibling [`diagnostic-setting`](../diagnostic-setting) module instead when the
target list is short, hand-picked, or deliberately surgical.

## Contract

- **Non-clobbering by name.** Azure keys diagnostic settings by name, so a
  distinct, dedicated name never overwrites a customer-owned setting on the same
  scope.
- **Five-setting cap.** A scope may hold at most **5** diagnostic settings.
  Discovery does not preflight this: if a scope already holds 5, the apply fails
  on that scope. Never evict an existing setting to make room.
- **Same-region rule, enforced.** A diagnostic setting can only target a storage
  account in the **same region** as the monitored resource. Destinations are
  therefore a map of region to storage account id, and a discovered region with
  no destination **fails the plan** by default rather than being skipped.
- **Storage is expanded, not monitored directly.** Azure attaches storage
  diagnostic settings to `<account-id>/<service>/default`, never to the account
  id. Passing `Microsoft.Storage/storageAccounts` in `resource_types` expands each
  account into `storage_services` and the account itself receives nothing.
  Enumerating accounts instead of service scopes monitors nothing while looking
  like success.
- **Keyed by scope resource id.** The `for_each` key is the monitored scope's own
  resource id, so a state address is
  `module.<name>.azurerm_monitor_diagnostic_setting.this["<scope id>"]`. That is
  deliberate: it makes addresses derivable from Azure alone, so a pre-existing
  setting can be imported with no side table mapping names to ids (see
  [Adopting pre-existing settings](#adopting-pre-existing-settings)).
- **One category config per instance.** Every discovered scope gets the same
  log/metric selection. `allLogs` is the default because it stays correct as
  Azure adds categories; a type that rejects the group needs its own
  instantiation with explicit `log_categories`.
- **One subscription per instance.** Discovery scans the subscription the
  provider is configured for. Monitoring several subscriptions means one
  instantiation each, with an aliased provider.

## Discovery is plan-time, not continuous

Coverage is recomputed on every plan, so a resource created after the last apply
is unmonitored until the next one. That is the deliberate trade against a
control-plane agent that reconciles continuously: coverage becomes a reviewable
diff in a pull request, and nothing in the subscription needs standing write
access to achieve it.

Two outputs exist to make that trade auditable rather than invisible:
`scope_count_by_type` and `scope_count_by_region`. Read them on the first plan. A
type with a surprisingly large count is usually something nobody intended to pay
to ingest.

## Cost warning

With `required_tags` empty (the default) this discovers **every** resource of the
listed types. On a large estate that is a lot of log volume, and log ingestion is
billed. Prefer narrowing `resource_types` to what is actually wanted, and scope
with `required_tags` once a tagging convention exists. Broad discovery is a
reasonable starting point for an untagged estate; it is a poor steady state.

## Usage

```hcl
module "log_forwarder_eastus" {
  source = "rhythmictech/datadog/azurerm//modules/log-forwarder"

  name                = "example"
  region              = "eastus"
  resource_group_name = azurerm_resource_group.monitoring.name
  datadog_api_key     = var.datadog_api_key
}

module "diagnostic_settings" {
  source = "rhythmictech/datadog/azurerm//modules/diagnostic-setting-discovery"

  resource_types = [
    "Microsoft.Web/sites",
    "Microsoft.Sql/servers/databases",
    "Microsoft.KeyVault/vaults",
    "Microsoft.Storage/storageAccounts", # expanded into service scopes
  ]

  storage_account_ids_by_region = {
    eastus = module.log_forwarder_eastus.storage_account_id
  }

  # Never monitor the forwarding infrastructure's own storage.
  exclude_resource_groups = [azurerm_resource_group.monitoring.name]
}
```

## Adopting pre-existing settings

When a scope already carries a setting this module would own (a previous vendor's
forwarding, or an earlier tool), import it rather than creating a second one
alongside. Two settings on one scope means two destinations, so the same records
are ingested and billed twice.

The import id format is `{resourceId}|{settingName}`, and because the `for_each`
key is the scope id, the address is mechanical:

```bash
terraform import \
  'module.diagnostic_settings.azurerm_monitor_diagnostic_setting.this["<scope id>"]' \
  '<scope id>|<existing setting name>'
```

`name` is `ForceNew`, so if the imported setting's name differs from `var.name`
the next apply **replaces** it: destroy, then create. That is usually what is
wanted (the setting ends up named to convention) and it costs a brief per-scope
window with no setting. Terraform destroys before creating, so the two never
coexist and nothing is double-billed. To adopt with no gap at all, set `var.name`
to the existing name and accept the inherited naming.

Stop any agent that manages those settings before importing, or it will recreate
them underneath Terraform.

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
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [azurerm_monitor_diagnostic_setting.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_diagnostic_setting) | resource |
| [terraform_data.region_coverage](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [azurerm_resources.by_type](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resources) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_exclude_resource_groups"></a> [exclude\_resource\_groups](#input\_exclude\_resource\_groups) | Resource group names to exclude from discovery. Matched case-insensitively. Typically the group holding the log-forwarding infrastructure itself, so the forwarder does not monitor its own storage. | `list(string)` | `[]` | no |
| <a name="input_exclude_resource_ids"></a> [exclude\_resource\_ids](#input\_exclude\_resource\_ids) | Individual resource ids to exclude from discovery, for carve-outs that a type or resource-group filter cannot express. For a storage account, excluding the ACCOUNT id removes all of its expanded service scopes. | `list(string)` | `[]` | no |
| <a name="input_fail_on_unmapped_region"></a> [fail\_on\_unmapped\_region](#input\_fail\_on\_unmapped\_region) | Fail the plan when a discovered scope sits in a region with no entry in `storage_account_ids_by_region`. Defaults to true because the alternative is silently leaving those resources unmonitored, which looks identical to success. Set false only to deliberately, and visibly, monitor a subset of regions. | `bool` | `true` | no |
| <a name="input_log_categories"></a> [log\_categories](#input\_log\_categories) | Individual log CATEGORIES to enable (rendered as `enabled_log { category = ... }`). Only useful when every discovered type supports the same category names, so prefer `log_category_groups` for heterogeneous discovery. | `list(string)` | `[]` | no |
| <a name="input_log_category_groups"></a> [log\_category\_groups](#input\_log\_category\_groups) | Log category GROUPS to enable (rendered as `enabled_log { category_group = ... }`). `allLogs` captures every category the scope supports, which keeps coverage correct as Azure adds categories. Set to `[]` and use `log_categories` for any type that rejects the group. | `list(string)` | <pre>[<br/>  "allLogs"<br/>]</pre> | no |
| <a name="input_metric_categories"></a> [metric\_categories](#input\_metric\_categories) | Metric categories to enable (rendered as `enabled_metric { category = ... }`).<br/><br/>Defaults to `[]`, unlike the sibling `diagnostic-setting` module. This module<br/>routes to a blob destination consumed by a log forwarder, and platform<br/>metrics normally reach Datadog through the metrics integration instead;<br/>enabling `AllMetrics` across a whole discovered estate duplicates that data<br/>at cost. Set explicitly if the blob path really is the intended metric route. | `list(string)` | `[]` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the diagnostic setting created on each discovered scope. Azure keys diagnostic settings by name, so a distinct name never clobbers a customer-owned setting (there is a hard cap of 5 settings per scope). | `string` | `"rhythmic-datadog"` | no |
| <a name="input_required_tags"></a> [required\_tags](#input\_required\_tags) | Tag filter applied to discovery; only resources carrying all of these tag key/value pairs are matched. Empty (the default) discovers everything of the given types, which is the correct starting point for an untagged estate but is also unbounded, so prefer scoping once a tagging convention exists. | `map(string)` | `{}` | no |
| <a name="input_resource_types"></a> [resource\_types](#input\_resource\_types) | Azure resource types to discover, e.g. `["Microsoft.Web/sites",<br/>"Microsoft.Sql/servers/databases"]`. Each is queried across the whole<br/>subscription the provider is configured for.<br/><br/>`Microsoft.Storage/storageAccounts` is special-cased: Azure exposes storage<br/>diagnostic settings only on the child service scopes, so a storage account is<br/>expanded into `var.storage_services` and the account itself never receives a<br/>setting. | `list(string)` | n/a | yes |
| <a name="input_storage_account_ids_by_region"></a> [storage\_account\_ids\_by\_region](#input\_storage\_account\_ids\_by\_region) | Destination storage account id per region, e.g.<br/>`{ eastus = "/subscriptions/.../ddlogseastus" }`. A diagnostic setting can<br/>only target a storage account in the monitored resource's OWN region, so one<br/>destination per region is required rather than one overall.<br/><br/>Keys are matched case- and space-insensitively, so `"East US"` and `"eastus"`<br/>are equivalent. Any region that has discovered scopes but no entry here is<br/>reported in the `unmapped_regions` output and, unless<br/>`fail_on_unmapped_region` is false, fails the plan. | `map(string)` | n/a | yes |
| <a name="input_storage_services"></a> [storage\_services](#input\_storage\_services) | Storage sub-service scopes to expand each discovered storage account into. Azure attaches storage diagnostic settings to `<account-id>/<service>/default`, never to the account id, so enumerating accounts alone silently monitors nothing. | `list(string)` | <pre>[<br/>  "blobServices",<br/>  "fileServices",<br/>  "queueServices",<br/>  "tableServices"<br/>]</pre> | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_diagnostic_setting_ids"></a> [diagnostic\_setting\_ids](#output\_diagnostic\_setting\_ids) | Map of created diagnostic-setting ids keyed by the monitored scope's resource id. |
| <a name="output_discovered_count_by_requested_type"></a> [discovered\_count\_by\_requested\_type](#output\_discovered\_count\_by\_requested\_type) | Count of resources discovered for EVERY entry in `var.resource_types`,<br/>including entries that matched nothing (reported as 0).<br/><br/>Check this on the first plan. A misspelled or wrongly-cased type discovers<br/>nothing, and because that failure produces no resources rather than an error,<br/>it is otherwise indistinguishable from "the subscription genuinely has none of<br/>those". A `0` here is the only signal.<br/><br/>Counts are of discovered RESOURCES, before storage accounts are expanded into<br/>service scopes, so a storage entry here is the account count while<br/>`scope_count_by_type` reports the expanded scopes. |
| <a name="output_monitored_scope_ids"></a> [monitored\_scope\_ids](#output\_monitored\_scope\_ids) | Resource ids that received a diagnostic setting, sorted. Also the `for_each` key set, so a state address is `module.<name>.azurerm_monitor_diagnostic_setting.this["<scope id>"]`. |
| <a name="output_scope_count_by_region"></a> [scope\_count\_by\_region](#output\_scope\_count\_by\_region) | Count of monitored scopes per region. Worth eyeballing on the first plan: a region with a surprisingly large count usually means a resource type was discovered that nobody meant to pay to ingest. |
| <a name="output_scope_count_by_type"></a> [scope\_count\_by\_type](#output\_scope\_count\_by\_type) | Count of monitored scopes per resource type, with storage split by service scope. |
| <a name="output_unmapped_regions"></a> [unmapped\_regions](#output\_unmapped\_regions) | Regions holding discovered scopes with no destination in `storage_account_ids_by_region`. Empty unless `fail_on_unmapped_region` is false, since otherwise the plan fails instead. A non-empty value means those resources are NOT monitored. |
<!-- END_TF_DOCS -->
