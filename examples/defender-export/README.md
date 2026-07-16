# Example: Defender for Cloud continuous export

Shows both scopes of the `defender-export` module:

- **Subscription scope** (the default): assign the built-in continuous-export
  policy to one subscription and create the central Event Hub in the module,
  including its send-only authorization rule.
- **Management-group scope**: assign the policy once at a management group and
  point it at an existing central Event Hub.

Both calls take a **dedicated, low-value** remediation identity, separate from
the identity that runs Terraform. A consumer (for example Datadog) reads the hub
through its own separate listen-only authorization rule, never the send rule the
export uses.

## Usage

```hcl
module "defender_export_subscription" {
  source = "../../modules/defender-export"

  scope_type      = "subscription"
  subscription_id = var.subscription_id
  location        = "eastus"

  export_resource_group_name = "rg-defender-export"

  create_event_hub              = true
  event_hub_namespace_name      = "defender-export-ns"
  event_hub_name                = "defender-export"
  event_hub_resource_group_name = "rg-monitoring"

  user_assigned_identity_id           = var.user_assigned_identity_id
  user_assigned_identity_principal_id = var.user_assigned_identity_principal_id
}

module "defender_export_management_group" {
  source = "../../modules/defender-export"

  scope_type          = "management_group"
  management_group_id = "/providers/Microsoft.Management/managementGroups/example-root"
  location            = "eastus"

  export_resource_group_name = "rg-defender-export"

  create_event_hub                         = false
  existing_event_hub_id                    = var.existing_event_hub_id
  existing_event_hub_authorization_rule_id = var.existing_event_hub_authorization_rule_id

  user_assigned_identity_id           = var.user_assigned_identity_id
  user_assigned_identity_principal_id = var.user_assigned_identity_principal_id
}
```
