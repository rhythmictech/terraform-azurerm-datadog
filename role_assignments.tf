# Per-subscription Monitoring Reader for the Datadog service principal.
#
# Gated OFF by default (manage_datadog_sp_role_assignment = false): in many
# deployments this assignment is pre-created out-of-band during onboarding by a
# higher-privilege (Owner) identity, while the module itself runs under a
# lower-privilege identity that can only assign roles (RBAC Administrator).
# Owning this assignment here is therefore opt-in, to avoid an HTTP 409
# RoleAssignmentExists collision with a pre-existing assignment and to respect
# any ABAC condition on the deploying identity's role-assignment permission.
#
# principal_id is the SP OBJECT id (local.datadog_sp_object_id), NOT the client
# id -- which is why the consume path takes datadog_sp_object_id separately.
resource "azurerm_role_assignment" "datadog" {
  for_each = var.manage_datadog_sp_role_assignment ? toset(var.role_assignment_scopes) : toset([])

  scope                = each.value
  role_definition_name = var.role_definition_name
  principal_id         = local.datadog_sp_object_id
}

# OPTIONAL: additionally grant Storage Blob Data Contributor for a log archive.
# Also gated by manage_datadog_sp_role_assignment. Off by default; extension seam.
# WARNING: this reuses the subscription-level role_assignment_scopes, so enabling
# it grants blob write/delete to the external Datadog SP across the whole
# subscription. Introduce a narrower, archive-specific scope before enabling.
resource "azurerm_role_assignment" "datadog_blob" {
  for_each = (var.manage_datadog_sp_role_assignment && var.enable_log_archive_blob_role) ? toset(var.role_assignment_scopes) : toset([])

  scope                = each.value
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = local.datadog_sp_object_id
}
