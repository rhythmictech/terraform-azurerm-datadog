# diagnostic-setting

Creates one controlled diagnostic setting (default name `rhythmic-datadog`) on
each of a set of target resources, all shipping to a single storage-account
destination (a log-forwarder's `storage_account_id`).

## Contract

- **Non-clobbering by name.** Azure keys diagnostic settings by name, so a
  distinct, dedicated name never overwrites a customer-owned setting on the same
  resource.
- **Five-setting cap.** A resource may hold at most **5** diagnostic settings.
  Preflight each target: if it already holds 5, adding a 6th fails at apply.
  Never evict an existing setting to make room.
- **Same-region rule.** A diagnostic setting can only target a storage account
  in the **same region** as the monitored resource, so `storage_account_id`
  must be a forwarder in that region.
- **One category config per instance.** `for_each` runs over the input
  `target_resource_ids` map and applies the same log/metric category selection
  to every target. Heterogeneous targets (different supported categories) need
  multiple instantiations.

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
| [azurerm_monitor_diagnostic_setting.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_diagnostic_setting) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_log_categories"></a> [log\_categories](#input\_log\_categories) | Individual log CATEGORIES to enable (rendered as `enabled_log { category = ... }`) for targets addressed by category rather than group. | `list(string)` | `[]` | no |
| <a name="input_log_category_groups"></a> [log\_category\_groups](#input\_log\_category\_groups) | Log category GROUPS to enable (rendered as `enabled_log { category_group = ... }`). `allLogs` captures every category the target supports. | `list(string)` | <pre>[<br/>  "allLogs"<br/>]</pre> | no |
| <a name="input_metric_categories"></a> [metric\_categories](#input\_metric\_categories) | Metric categories to enable (rendered as `enabled_metric { category = ... }`). Set to `[]` where the target supports no metrics; at least one enabled\_log or enabled\_metric must remain. | `list(string)` | <pre>[<br/>  "AllMetrics"<br/>]</pre> | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the diagnostic setting created on each target. Azure keys diagnostic settings by name, so a distinct name never clobbers a customer-owned setting (there is a hard cap of 5 settings per resource). | `string` | `"rhythmic-datadog"` | no |
| <a name="input_storage_account_id"></a> [storage\_account\_id](#input\_storage\_account\_id) | Destination storage account id for the diagnostic setting, typically a log-forwarder module's `storage_account_id` output. It must be in the same region as each target resource. | `string` | n/a | yes |
| <a name="input_target_resource_ids"></a> [target\_resource\_ids](#input\_target\_resource\_ids) | Map of `friendly_key => resource_id` for the resources that get the single<br/>diagnostic setting; drives `for_each`. Use static/config-derived values<br/>only (never a data-source or otherwise computed collection), so the key set<br/>is known at plan time. One instance applies one category config across all<br/>targets; heterogeneous targets need multiple instantiations. | `map(string)` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_diagnostic_setting_ids"></a> [diagnostic\_setting\_ids](#output\_diagnostic\_setting\_ids) | Map of created diagnostic-setting ids keyed by the input `target_resource_ids` key. |
<!-- END_TF_DOCS -->
