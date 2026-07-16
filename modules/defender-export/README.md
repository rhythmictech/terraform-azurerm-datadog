# defender-export

Assigns the built-in **"Deploy export to Event Hub for Microsoft Defender for
Cloud data"** DeployIfNotExists policy (definition version 4.2.0), provisions (or
references) the **Event Hub** the export writes to, and optionally remediates the
scope so the export configuration is deployed. This is the Event Hub bridge that
carries Defender for Cloud alerts and recommendations into Datadog: Defender
continuous export cannot target blob storage, so it rides an Event Hub rather
than the blob-fed forwarder seam used by the other submodules.

## Contract

- **Scope is parameterized.** `scope_type` defaults to `"subscription"`, which
  assigns the policy per subscription. Set it to `"management_group"` to assign
  once at a management group; the module wires both the subscription and the
  management-group `*_policy_assignment` / `*_policy_remediation` pairs and
  activates the pair matching `scope_type`.
- **Corrected export parameters.** The policy takes three required parameters:
  `resourceGroupName` (`export_resource_group_name`), `resourceGroupLocation`
  (`location`), and `eventHubDetails`. `eventHubDetails` is the **send
  authorization-rule id** (the deployment reads the hub keys from it), not the
  hub id. Optional tunables (`alert_severities`, `recommendation_severities`,
  `exported_data_types`) are passed through only when set, so the policy keeps
  its own defaults otherwise. There is no `eventHubAuthorizationRuleId`
  parameter in this definition.
- **Dedicated remediation identity.** The built-in policy fixes its remediation
  role to Contributor (non-narrowable). Pass a **dedicated, low-value**
  user-assigned identity (`user_assigned_identity_id` /
  `user_assigned_identity_principal_id`) as the remediation identity, kept
  separate from the identity that runs Terraform. Isolating a purpose-built
  identity is the over-privilege mitigation.
- **Role assignment gated off by default.** `manage_dine_role_assignment`
  defaults `false`: the remediation identity's grant is normally pre-created
  out-of-band during a privileged bootstrap, avoiding an HTTP 409
  RoleAssignmentExists collision and respecting any ABAC condition on the
  deploying identity. Set it `true` for the module to own the grant. When a
  single central hub lives in a different subscription, set
  `dine_role_assignment_scope` to the hub's subscription so the identity can
  read the hub keys across subscriptions; narrow the role with
  `dine_role_definition_name` (`"Azure Event Hubs Data Owner"`), but never
  `"Azure Event Hubs Data Sender"` (that data-plane role cannot read the keys).
- **Remediation backfill.** A freshly assigned policy has no compliance data
  until an asynchronous scan runs. At subscription scope the remediation uses
  `ReEvaluateCompliance` to force a re-scan; that mode is unavailable at
  management-group scope, so the management-group remediation omits it and
  backfills only after the scan (or via a subscription-scoped re-evaluation).
- **Send vs listen are separate credentials.** When the module creates the hub
  it also creates a **send-only** authorization rule for the export. A consumer
  (for example Datadog) must read the hub through a **separate listen-only**
  rule authored by the consumer against `event_hub_namespace_id`; the send
  credential is never reused for listening.

## Secrets in state

An `azurerm_eventhub_authorization_rule` persists its SAS connection string in
Terraform state, and the export uses SAS (local authentication stays enabled).
This is an accepted secret-in-state, mitigated by an encrypted state backend.
Configuration scanners flag it as a documented exception rather than a fix.

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
| [azurerm_eventhub.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/eventhub) | resource |
| [azurerm_eventhub_authorization_rule.export](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/eventhub_authorization_rule) | resource |
| [azurerm_eventhub_namespace.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/eventhub_namespace) | resource |
| [azurerm_management_group_policy_assignment.defender_export](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/management_group_policy_assignment) | resource |
| [azurerm_management_group_policy_remediation.defender_export](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/management_group_policy_remediation) | resource |
| [azurerm_role_assignment.dine_mg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.dine_sub](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_subscription_policy_assignment.defender_export](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subscription_policy_assignment) | resource |
| [azurerm_subscription_policy_remediation.defender_export](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subscription_policy_remediation) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_alert_severities"></a> [alert\_severities](#input\_alert\_severities) | Optional override for the policy's `alertSeverities` parameter (e.g. `["High", "Medium"]`). `null` keeps the policy default (High/Medium/Low). | `list(string)` | `null` | no |
| <a name="input_create_event_hub"></a> [create\_event\_hub](#input\_create\_event\_hub) | Create the Event Hub namespace, hub, and a send-only authorization rule here. When false, reference an existing hub via `existing_event_hub_id` and `existing_event_hub_authorization_rule_id`. | `bool` | `true` | no |
| <a name="input_dine_role_assignment_scope"></a> [dine\_role\_assignment\_scope](#input\_dine\_role\_assignment\_scope) | Optional scope override for the remediation identity's role grant. `null`<br/>uses the assignment scope (the subscription or management group). Set it to<br/>the Event Hub's subscription id when a single central hub lives in a<br/>different subscription, so the identity can read the hub's keys across<br/>subscriptions. Only used when `manage_dine_role_assignment = true`. | `string` | `null` | no |
| <a name="input_dine_role_definition_name"></a> [dine\_role\_definition\_name](#input\_dine\_role\_definition\_name) | Built-in role granted to the remediation identity when<br/>`manage_dine_role_assignment = true`. "Contributor" (the default) covers<br/>both the export deployment and reading the Event Hub keys. "Azure Event Hubs<br/>Data Owner" is a narrower option for a cross-subscription hub-only grant. Do<br/>NOT use "Azure Event Hubs Data Sender": that data-plane role cannot read the<br/>authorization-rule keys the export requires. | `string` | `"Contributor"` | no |
| <a name="input_enable_remediation"></a> [enable\_remediation](#input\_enable\_remediation) | Create the policy remediation resource. A freshly created assignment has no<br/>compliance data yet (the evaluation scan is asynchronous), so under the<br/>subscription scope the remediation uses `ReEvaluateCompliance` to force a<br/>re-scan and backfill. `ReEvaluateCompliance` is not available at the<br/>management-group scope, so the management-group remediation omits it. | `bool` | `true` | no |
| <a name="input_event_hub_name"></a> [event\_hub\_name](#input\_event\_hub\_name) | Name of the Event Hub (topic) to create within the namespace. Required when `create_event_hub = true`. | `string` | `null` | no |
| <a name="input_event_hub_namespace_name"></a> [event\_hub\_namespace\_name](#input\_event\_hub\_namespace\_name) | Name of the Event Hub namespace to create. Required when `create_event_hub = true`. | `string` | `null` | no |
| <a name="input_event_hub_resource_group_name"></a> [event\_hub\_resource\_group\_name](#input\_event\_hub\_resource\_group\_name) | Name of an EXISTING resource group for a created Event Hub namespace. Required when `create_event_hub = true`. Distinct from `export_resource_group_name`. | `string` | `null` | no |
| <a name="input_event_hub_sku"></a> [event\_hub\_sku](#input\_event\_hub\_sku) | SKU for a created Event Hub namespace. Standard is recommended; Basic caps message retention at 1 day and offers no consumer-group control. | `string` | `"Standard"` | no |
| <a name="input_existing_event_hub_authorization_rule_id"></a> [existing\_event\_hub\_authorization\_rule\_id](#input\_existing\_event\_hub\_authorization\_rule\_id) | ARM id of an existing SEND authorization rule on the target hub, passed to the policy's `eventHubDetails` parameter. Required when `create_event_hub = false`. This is the export (send) credential, not the consumer (listen) credential. | `string` | `null` | no |
| <a name="input_existing_event_hub_id"></a> [existing\_event\_hub\_id](#input\_existing\_event\_hub\_id) | ARM id of an existing Event Hub the export writes to. Required when `create_event_hub = false`. | `string` | `null` | no |
| <a name="input_export_resource_group_name"></a> [export\_resource\_group\_name](#input\_export\_resource\_group\_name) | Name of the resource group the per-scope export configuration<br/>(`Microsoft.Security/automations`) is deployed into. Maps to the policy's<br/>REQUIRED `resourceGroupName` parameter. Distinct from<br/>`event_hub_resource_group_name` (which is the Event Hub namespace's resource<br/>group). The policy's `createResourceGroup` default is true, so this group is<br/>created if it does not already exist. | `string` | n/a | yes |
| <a name="input_exported_data_types"></a> [exported\_data\_types](#input\_exported\_data\_types) | Optional override for the policy's `exportedDataTypes` parameter (which data classes are exported). `null` keeps the policy default, which emits a single mixed stream (alerts + recommendations + secure score + regulatory compliance) split downstream by facet. | `list(string)` | `null` | no |
| <a name="input_location"></a> [location](#input\_location) | Azure region for the policy assignment. It is REQUIRED whenever an identity<br/>block is attached to the assignment (as it always is here), and it is also<br/>passed through as the export's `resourceGroupLocation` policy parameter and<br/>as the region of any Event Hub resources created by this module. | `string` | n/a | yes |
| <a name="input_manage_dine_role_assignment"></a> [manage\_dine\_role\_assignment](#input\_manage\_dine\_role\_assignment) | Own the role assignment that grants the remediation identity the rights it<br/>needs to deploy the export and read the Event Hub keys. Default OFF: in most<br/>deployments this grant is pre-created out-of-band during a privileged<br/>bootstrap, so owning it here is opt-in to avoid an HTTP 409<br/>RoleAssignmentExists collision and to respect any ABAC condition on the<br/>deploying identity's role-assignment permission. Mirrors the root module's<br/>`manage_datadog_sp_role_assignment` gate. | `bool` | `false` | no |
| <a name="input_management_group_id"></a> [management\_group\_id](#input\_management\_group\_id) | Management group id in full ARM form (`/providers/Microsoft.Management/managementGroups/<id>`). Required when `scope_type = "management_group"`; must be null when `scope_type = "subscription"`. | `string` | `null` | no |
| <a name="input_policy_assignment_name"></a> [policy\_assignment\_name](#input\_policy\_assignment\_name) | Name of the policy assignment (and the base of the remediation resource name). A distinct, neutral name avoids clobbering a customer-owned assignment. | `string` | `"rhythmic-defender-export"` | no |
| <a name="input_policy_definition_id"></a> [policy\_definition\_id](#input\_policy\_definition\_id) | ARM id of the built-in DeployIfNotExists policy that provisions a Defender<br/>for Cloud continuous-export configuration. The default targets "Deploy export<br/>to Event Hub for Microsoft Defender for Cloud data" (definition version<br/>4.2.0). Override to a trusted-service or Log Analytics variant if required;<br/>the parameter schema is versioned, so re-verify the schema when overriding. | `string` | `"/providers/Microsoft.Authorization/policyDefinitions/cdfcce10-4578-4ecd-9703-530938e4abcb"` | no |
| <a name="input_recommendation_severities"></a> [recommendation\_severities](#input\_recommendation\_severities) | Optional override for the policy's `recommendationSeverities` parameter. `null` keeps the policy default (High/Medium/Low). | `list(string)` | `null` | no |
| <a name="input_scope_type"></a> [scope\_type](#input\_scope\_type) | Scope the continuous-export policy assignment (and its remediation) targets.<br/>`"subscription"` (the default) assigns per subscription and is the primary<br/>path for a small, rarely-changing subscription set. `"management_group"`<br/>assigns once at a management group and is the documented path for a larger,<br/>inheritance-driven estate. Drives which `azurerm_*_policy_assignment` /<br/>`_policy_remediation` pair is created and the default role-grant scope. | `string` | `"subscription"` | no |
| <a name="input_subscription_id"></a> [subscription\_id](#input\_subscription\_id) | Subscription GUID the policy is assigned to. Required when `scope_type = "subscription"`; must be null when `scope_type = "management_group"`. The assignment scope is derived as `/subscriptions/<subscription_id>`. | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the Event Hub resources created by this module (namespace and hub). | `map(string)` | `{}` | no |
| <a name="input_user_assigned_identity_id"></a> [user\_assigned\_identity\_id](#input\_user\_assigned\_identity\_id) | ARM id of a DEDICATED, low-value user-assigned managed identity used as the<br/>policy's remediation identity. This is deliberately NOT the identity that<br/>runs Terraform: the built-in policy fixes its remediation role to<br/>Contributor (non-narrowable), so isolating a purpose-built identity is the<br/>over-privilege mitigation. Provisioned out-of-band (client repo / onboarding). | `string` | n/a | yes |
| <a name="input_user_assigned_identity_principal_id"></a> [user\_assigned\_identity\_principal\_id](#input\_user\_assigned\_identity\_principal\_id) | Object (principal) id of the dedicated remediation identity above. Kept as a separate input so the module needs no identity data source; used only by the gated role assignment. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_event_hub_authorization_rule_id"></a> [event\_hub\_authorization\_rule\_id](#output\_event\_hub\_authorization\_rule\_id) | ID of the SEND authorization rule used by the export policy. This is the send credential only; a consumer (e.g. Datadog) must use a separate listen-only rule and never this id. |
| <a name="output_event_hub_id"></a> [event\_hub\_id](#output\_event\_hub\_id) | ID of the Event Hub the export writes to (created here, or the referenced existing hub). Feed this to the Datadog Azure Event Hub log integration. |
| <a name="output_event_hub_namespace_id"></a> [event\_hub\_namespace\_id](#output\_event\_hub\_namespace\_id) | ID of the created Event Hub namespace (null when create\_event\_hub = false). Use it to author consumer-group, diagnostic, or listen-rule resources. |
| <a name="output_policy_assignment_id"></a> [policy\_assignment\_id](#output\_policy\_assignment\_id) | ID of the active policy assignment (subscription- or management-group-scoped, per scope\_type). Useful for remediation status checks and imports. |
<!-- END_TF_DOCS -->
