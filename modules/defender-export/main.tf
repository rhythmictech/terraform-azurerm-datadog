locals {
  # Resolved Event Hub identifiers: either the resources created here or the
  # existing ids passed in. eventhub_auth_id is the SEND authorization-rule id.
  # The built-in export policy calls listKeys() on THIS id (it is the
  # authorization-rule id, NOT the hub id) and reconstructs the hub path from it.
  eventhub_id      = var.create_event_hub ? azurerm_eventhub.this[0].id : var.existing_event_hub_id
  eventhub_auth_id = var.create_event_hub ? azurerm_eventhub_authorization_rule.export[0].id : var.existing_event_hub_authorization_rule_id

  # Assignment scope and the (optionally overridden) role-grant scope.
  assignment_scope = var.scope_type == "subscription" ? "/subscriptions/${var.subscription_id}" : var.management_group_id
  role_grant_scope = coalesce(var.dine_role_assignment_scope, local.assignment_scope)

  # Parameters for the built-in "Deploy export to Event Hub for Microsoft
  # Defender for Cloud data" definition (version 4.2.0). resourceGroupName and
  # resourceGroupLocation are REQUIRED (no default); eventHubDetails must be the
  # SEND authorization-rule id. Optional tunables are merged in only when their
  # input is non-null, so the policy keeps its own defaults otherwise. There is
  # no eventHubAuthorizationRuleId parameter in this definition; passing one is
  # rejected at deployment.
  policy_parameters = merge(
    {
      resourceGroupName     = { value = var.export_resource_group_name }
      resourceGroupLocation = { value = var.location }
      eventHubDetails       = { value = local.eventhub_auth_id }
    },
    var.alert_severities == null ? {} : { alertSeverities = { value = var.alert_severities } },
    var.recommendation_severities == null ? {} : { recommendationSeverities = { value = var.recommendation_severities } },
    var.exported_data_types == null ? {} : { exportedDataTypes = { value = var.exported_data_types } },
  )
}

########################################
# Central Event Hub (created here unless an existing hub is referenced)
########################################

resource "azurerm_eventhub_namespace" "this" {
  count = var.create_event_hub ? 1 : 0

  name                = var.event_hub_namespace_name
  resource_group_name = var.event_hub_resource_group_name
  location            = var.location
  sku                 = var.event_hub_sku
  tags                = var.tags
}

resource "azurerm_eventhub" "this" {
  count = var.create_event_hub ? 1 : 0

  name              = var.event_hub_name
  namespace_id      = azurerm_eventhub_namespace.this[0].id
  partition_count   = 2
  message_retention = 1
}

# SEND-only authorization rule for the export. Its id is passed to the policy's
# eventHubDetails parameter. A consumer (e.g. Datadog) must read the hub via a
# SEPARATE listen-only rule authored by the consumer; the send credential here
# is never reused for listening.
resource "azurerm_eventhub_authorization_rule" "export" {
  count = var.create_event_hub ? 1 : 0

  name                = "defender-export"
  namespace_name      = azurerm_eventhub_namespace.this[0].name
  eventhub_name       = azurerm_eventhub.this[0].name
  resource_group_name = var.event_hub_resource_group_name

  listen = false
  send   = true
  manage = false
}

########################################
# Subscription scope
########################################

resource "azurerm_subscription_policy_assignment" "defender_export" {
  count = var.scope_type == "subscription" ? 1 : 0

  name                 = var.policy_assignment_name
  subscription_id      = "/subscriptions/${var.subscription_id}"
  policy_definition_id = var.policy_definition_id
  location             = var.location # required because an identity block is set

  identity {
    type         = "UserAssigned"
    identity_ids = [var.user_assigned_identity_id]
  }

  parameters = jsonencode(local.policy_parameters)
}

# Gated OFF by default. Grants the dedicated remediation identity the rights to
# deploy the export and read the Event Hub keys, including across subscriptions
# when the central hub lives elsewhere (set dine_role_assignment_scope). The
# policy's portal-only auto-grant is not honored by Terraform, so this must be
# authored explicitly when the module owns the grant.
resource "azurerm_role_assignment" "dine_sub" {
  count = var.scope_type == "subscription" && var.manage_dine_role_assignment ? 1 : 0

  scope                = local.role_grant_scope
  role_definition_name = var.dine_role_definition_name
  principal_id         = var.user_assigned_identity_principal_id
}

resource "azurerm_subscription_policy_remediation" "defender_export" {
  count = var.scope_type == "subscription" && var.enable_remediation ? 1 : 0

  name                    = "${var.policy_assignment_name}-remediation"
  subscription_id         = "/subscriptions/${var.subscription_id}"
  policy_assignment_id    = azurerm_subscription_policy_assignment.defender_export[0].id
  resource_discovery_mode = "ReEvaluateCompliance" # legal at subscription scope; forces a re-scan so a fresh assignment backfills

  depends_on = [azurerm_role_assignment.dine_sub]
}

########################################
# Management-group scope
########################################

resource "azurerm_management_group_policy_assignment" "defender_export" {
  count = var.scope_type == "management_group" ? 1 : 0

  name                 = var.policy_assignment_name
  management_group_id  = var.management_group_id
  policy_definition_id = var.policy_definition_id
  location             = var.location # required because an identity block is set

  identity {
    type         = "UserAssigned"
    identity_ids = [var.user_assigned_identity_id]
  }

  parameters = jsonencode(local.policy_parameters)
}

resource "azurerm_role_assignment" "dine_mg" {
  count = var.scope_type == "management_group" && var.manage_dine_role_assignment ? 1 : 0

  scope                = local.role_grant_scope
  role_definition_name = var.dine_role_definition_name
  principal_id         = var.user_assigned_identity_principal_id
}

# The management-group remediation resource does not expose
# resource_discovery_mode (ReEvaluateCompliance is unavailable at this scope), so
# a fresh assignment backfills only after an asynchronous scan populates
# compliance. Backfill known subscriptions via a subscription-scoped remediation
# or an out-of-band re-evaluation.
resource "azurerm_management_group_policy_remediation" "defender_export" {
  count = var.scope_type == "management_group" && var.enable_remediation ? 1 : 0

  name                 = "${var.policy_assignment_name}-remediation"
  management_group_id  = var.management_group_id
  policy_assignment_id = azurerm_management_group_policy_assignment.defender_export[0].id

  depends_on = [azurerm_role_assignment.dine_mg]
}
