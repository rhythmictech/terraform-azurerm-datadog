# activity-log

Exports a subscription's (or a management group's) **Activity Log** to a
storage-account destination (a log-forwarder's `storage_account_id`), plus an
**optional, default-off** tenant directory (sign-in / audit) diagnostic setting.

## Contract

- **Subscription/MG scope is global.** The Activity Log setting is created at
  `/subscriptions/<id>` (or a `target_scope_override` management-group scope).
  Because the scope is global, its storage destination may be in **any** region.
- **Non-clobbering by name.** A distinct, dedicated setting name (default
  `rhythmic-datadog`) never overwrites a customer-owned setting.
- **Optional directory diagnostics (default OFF).** Set
  `enable_entra_diagnostics = true` to ship the tenant directory sign-in / audit
  logs. This is a **tenant directory operation**: it requires the deploying
  identity to hold a directory role that can manage directory diagnostic
  settings (a **Security Administrator** or **Global Administrator** directory
  role), granted out-of-band as a one-time bootstrap. It is **not** a
  subscription ARM role assignment. Several directory categories also require a
  directory premium (P1/P2) license; validate availability before enabling.

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
| [azurerm_monitor_aad_diagnostic_setting.entra](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_aad_diagnostic_setting) | resource |
| [azurerm_monitor_diagnostic_setting.activity_log](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_diagnostic_setting) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_activity_log_categories"></a> [activity\_log\_categories](#input\_activity\_log\_categories) | Activity Log categories to export (rendered as `enabled_log { category = ... }`). | `list(string)` | <pre>[<br/>  "Administrative",<br/>  "Security",<br/>  "ServiceHealth",<br/>  "Alert",<br/>  "Recommendation",<br/>  "Policy",<br/>  "Autoscale",<br/>  "ResourceHealth"<br/>]</pre> | no |
| <a name="input_enable_entra_diagnostics"></a> [enable\_entra\_diagnostics](#input\_enable\_entra\_diagnostics) | Ship the tenant directory (sign-in / audit) diagnostic setting. Default OFF.<br/>The directory setting is a tenant-wide operation and requires the deploying<br/>identity to hold a directory role that can manage directory diagnostic<br/>settings (a Security Administrator or Global Administrator directory role),<br/>granted out-of-band as a one-time bootstrap; it is not a subscription ARM<br/>role assignment. | `bool` | `false` | no |
| <a name="input_entra_log_categories"></a> [entra\_log\_categories](#input\_entra\_log\_categories) | Directory diagnostic categories to export when `enable_entra_diagnostics = true`. Several categories require a directory premium (P1/P2) license; validate availability against the live tenant before enabling. | `list(string)` | <pre>[<br/>  "SignInLogs",<br/>  "AuditLogs",<br/>  "NonInteractiveUserSignInLogs",<br/>  "ServicePrincipalSignInLogs"<br/>]</pre> | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the Activity Log (and optional directory) diagnostic setting. A distinct name is non-clobbering. | `string` | `"rhythmic-datadog"` | no |
| <a name="input_storage_account_id"></a> [storage\_account\_id](#input\_storage\_account\_id) | Destination storage account id, typically a log-forwarder's `storage_account_id` output. The Activity Log scope is global, so the storage may be in any region. | `string` | n/a | yes |
| <a name="input_subscription_id"></a> [subscription\_id](#input\_subscription\_id) | Subscription whose Activity Log is exported. The setting is created at scope `/subscriptions/<subscription_id>` unless `target_scope_override` is set. | `string` | n/a | yes |
| <a name="input_target_scope_override"></a> [target\_scope\_override](#input\_target\_scope\_override) | Optional scope override, e.g. a management group `/providers/Microsoft.Management/managementGroups/<id>`. `null` uses the subscription scope derived from `subscription_id`. | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_activity_log_diagnostic_setting_id"></a> [activity\_log\_diagnostic\_setting\_id](#output\_activity\_log\_diagnostic\_setting\_id) | ID of the subscription (or management-group) Activity Log diagnostic setting. |
| <a name="output_entra_diagnostic_setting_id"></a> [entra\_diagnostic\_setting\_id](#output\_entra\_diagnostic\_setting\_id) | ID of the tenant directory diagnostic setting (null unless enable\_entra\_diagnostics = true). |
<!-- END_TF_DOCS -->
