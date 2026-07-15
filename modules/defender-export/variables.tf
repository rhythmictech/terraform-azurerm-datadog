########################################
# Assignment scope
########################################

variable "scope_type" {
  default     = "subscription"
  description = <<-END
    Scope the continuous-export policy assignment (and its remediation) targets.
    `"subscription"` (the default) assigns per subscription and is the primary
    path for a small, rarely-changing subscription set. `"management_group"`
    assigns once at a management group and is the documented path for a larger,
    inheritance-driven estate. Drives which `azurerm_*_policy_assignment` /
    `_policy_remediation` pair is created and the default role-grant scope.
  END
  type        = string

  validation {
    condition     = contains(["subscription", "management_group"], var.scope_type)
    error_message = "scope_type must be either \"subscription\" or \"management_group\"."
  }

  # Cross-variable (>= 1.9): exactly one scope target is set, matching scope_type.
  # Both checks live on scope_type (rather than mutually on the two id inputs) so
  # the validations do not form a reference cycle.
  validation {
    condition     = var.scope_type != "subscription" || (var.subscription_id != null && var.management_group_id == null)
    error_message = "When scope_type = \"subscription\", set subscription_id (and leave management_group_id null)."
  }
  validation {
    condition     = var.scope_type != "management_group" || (var.management_group_id != null && var.subscription_id == null)
    error_message = "When scope_type = \"management_group\", set management_group_id (and leave subscription_id null)."
  }
}

variable "subscription_id" {
  default     = null
  description = "Subscription GUID the policy is assigned to. Required when `scope_type = \"subscription\"`; must be null when `scope_type = \"management_group\"`. The assignment scope is derived as `/subscriptions/<subscription_id>`."
  type        = string
}

variable "management_group_id" {
  default     = null
  description = "Management group id in full ARM form (`/providers/Microsoft.Management/managementGroups/<id>`). Required when `scope_type = \"management_group\"`; must be null when `scope_type = \"subscription\"`."
  type        = string
}

variable "location" {
  description = <<-END
    Azure region for the policy assignment. It is REQUIRED whenever an identity
    block is attached to the assignment (as it always is here), and it is also
    passed through as the export's `resourceGroupLocation` policy parameter and
    as the region of any Event Hub resources created by this module.
  END
  type        = string

  validation {
    condition     = var.location != null && trimspace(var.location) != ""
    error_message = "location must be a non-empty string."
  }
}

########################################
# Policy definition + export parameters
########################################

variable "policy_definition_id" {
  default     = "/providers/Microsoft.Authorization/policyDefinitions/cdfcce10-4578-4ecd-9703-530938e4abcb"
  description = <<-END
    ARM id of the built-in DeployIfNotExists policy that provisions a Defender
    for Cloud continuous-export configuration. The default targets "Deploy export
    to Event Hub for Microsoft Defender for Cloud data" (definition version
    4.2.0). Override to a trusted-service or Log Analytics variant if required;
    the parameter schema is versioned, so re-verify the schema when overriding.
  END
  type        = string
}

variable "export_resource_group_name" {
  description = <<-END
    Name of the resource group the per-scope export configuration
    (`Microsoft.Security/automations`) is deployed into. Maps to the policy's
    REQUIRED `resourceGroupName` parameter. Distinct from
    `event_hub_resource_group_name` (which is the Event Hub namespace's resource
    group). The policy's `createResourceGroup` default is true, so this group is
    created if it does not already exist.
  END
  type        = string

  validation {
    condition     = var.export_resource_group_name != null && trimspace(var.export_resource_group_name) != ""
    error_message = "export_resource_group_name must be a non-empty string."
  }
}

variable "policy_assignment_name" {
  default     = "rhythmic-defender-export"
  description = "Name of the policy assignment (and the base of the remediation resource name). A distinct, neutral name avoids clobbering a customer-owned assignment."
  type        = string
}

variable "alert_severities" {
  default     = null
  description = "Optional override for the policy's `alertSeverities` parameter (e.g. `[\"High\", \"Medium\"]`). `null` keeps the policy default (High/Medium/Low)."
  type        = list(string)
}

variable "recommendation_severities" {
  default     = null
  description = "Optional override for the policy's `recommendationSeverities` parameter. `null` keeps the policy default (High/Medium/Low)."
  type        = list(string)
}

variable "exported_data_types" {
  default     = null
  description = "Optional override for the policy's `exportedDataTypes` parameter (which data classes are exported). `null` keeps the policy default, which emits a single mixed stream (alerts + recommendations + secure score + regulatory compliance) split downstream by facet."
  type        = list(string)
}

########################################
# Remediation identity
########################################

variable "user_assigned_identity_id" {
  description = <<-END
    ARM id of a DEDICATED, low-value user-assigned managed identity used as the
    policy's remediation identity. This is deliberately NOT the identity that
    runs Terraform: the built-in policy fixes its remediation role to
    Contributor (non-narrowable), so isolating a purpose-built identity is the
    over-privilege mitigation. Provisioned out-of-band (client repo / onboarding).
  END
  type        = string

  validation {
    condition     = var.user_assigned_identity_id != null && trimspace(var.user_assigned_identity_id) != ""
    error_message = "user_assigned_identity_id must be a non-empty string."
  }
}

variable "user_assigned_identity_principal_id" {
  description = "Object (principal) id of the dedicated remediation identity above. Kept as a separate input so the module needs no identity data source; used only by the gated role assignment."
  type        = string

  validation {
    condition     = var.user_assigned_identity_principal_id != null && trimspace(var.user_assigned_identity_principal_id) != ""
    error_message = "user_assigned_identity_principal_id must be a non-empty string."
  }
}

########################################
# Remediation
########################################

variable "enable_remediation" {
  default     = true
  description = <<-END
    Create the policy remediation resource. A freshly created assignment has no
    compliance data yet (the evaluation scan is asynchronous), so under the
    subscription scope the remediation uses `ReEvaluateCompliance` to force a
    re-scan and backfill. `ReEvaluateCompliance` is not available at the
    management-group scope, so the management-group remediation omits it.
  END
  type        = bool
}

########################################
# Remediation role assignment (gated OFF by default)
########################################

variable "manage_dine_role_assignment" {
  default     = false
  description = <<-END
    Own the role assignment that grants the remediation identity the rights it
    needs to deploy the export and read the Event Hub keys. Default OFF: in most
    deployments this grant is pre-created out-of-band during a privileged
    bootstrap, so owning it here is opt-in to avoid an HTTP 409
    RoleAssignmentExists collision and to respect any ABAC condition on the
    deploying identity's role-assignment permission. Mirrors the root module's
    `manage_datadog_sp_role_assignment` gate.
  END
  type        = bool
}

variable "dine_role_assignment_scope" {
  default     = null
  description = <<-END
    Optional scope override for the remediation identity's role grant. `null`
    uses the assignment scope (the subscription or management group). Set it to
    the Event Hub's subscription id when a single central hub lives in a
    different subscription, so the identity can read the hub's keys across
    subscriptions. Only used when `manage_dine_role_assignment = true`.
  END
  type        = string
}

variable "dine_role_definition_name" {
  default     = "Contributor"
  description = <<-END
    Built-in role granted to the remediation identity when
    `manage_dine_role_assignment = true`. "Contributor" (the default) covers
    both the export deployment and reading the Event Hub keys. "Azure Event Hubs
    Data Owner" is a narrower option for a cross-subscription hub-only grant. Do
    NOT use "Azure Event Hubs Data Sender": that data-plane role cannot read the
    authorization-rule keys the export requires.
  END
  type        = string
}

########################################
# Event Hub (created here, or an existing hub is referenced)
########################################

variable "create_event_hub" {
  default     = true
  description = "Create the Event Hub namespace, hub, and a send-only authorization rule here. When false, reference an existing hub via `existing_event_hub_id` and `existing_event_hub_authorization_rule_id`."
  type        = bool

  validation {
    # Cross-variable (>= 1.9): the create-path inputs and the existing-path
    # inputs are consistent with the chosen mode.
    condition = var.create_event_hub ? (
      var.event_hub_namespace_name != null && var.event_hub_name != null && var.event_hub_resource_group_name != null
      ) : (
      var.existing_event_hub_id != null && var.existing_event_hub_authorization_rule_id != null
    )
    error_message = "When create_event_hub = true set event_hub_namespace_name, event_hub_name and event_hub_resource_group_name; when false set existing_event_hub_id and existing_event_hub_authorization_rule_id."
  }
}

variable "event_hub_namespace_name" {
  default     = null
  description = "Name of the Event Hub namespace to create. Required when `create_event_hub = true`."
  type        = string
}

variable "event_hub_name" {
  default     = null
  description = "Name of the Event Hub (topic) to create within the namespace. Required when `create_event_hub = true`."
  type        = string
}

variable "event_hub_sku" {
  default     = "Standard"
  description = "SKU for a created Event Hub namespace. Standard is recommended; Basic caps message retention at 1 day and offers no consumer-group control."
  type        = string
}

variable "event_hub_resource_group_name" {
  default     = null
  description = "Name of an EXISTING resource group for a created Event Hub namespace. Required when `create_event_hub = true`. Distinct from `export_resource_group_name`."
  type        = string
}

variable "existing_event_hub_id" {
  default     = null
  description = "ARM id of an existing Event Hub the export writes to. Required when `create_event_hub = false`."
  type        = string
}

variable "existing_event_hub_authorization_rule_id" {
  default     = null
  description = "ARM id of an existing SEND authorization rule on the target hub, passed to the policy's `eventHubDetails` parameter. Required when `create_event_hub = false`. This is the export (send) credential, not the consumer (listen) credential."
  type        = string
}

########################################
# Tags
########################################

variable "tags" {
  default     = {}
  description = "Tags applied to the Event Hub resources created by this module (namespace and hub)."
  type        = map(string)
}
