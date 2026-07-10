locals {
  activity_log_scope = coalesce(var.target_scope_override, "/subscriptions/${var.subscription_id}")
}

# Subscription (or management-group) Activity Log -> forwarder storage. The
# scope is global, so any-region storage is acceptable.
resource "azurerm_monitor_diagnostic_setting" "activity_log" {
  name               = var.name
  target_resource_id = local.activity_log_scope
  storage_account_id = var.storage_account_id

  dynamic "enabled_log" {
    for_each = toset(var.activity_log_categories)
    content {
      category = enabled_log.value
    }
  }
}

# Optional tenant directory (sign-in / audit) diagnostic setting. Default OFF.
# Enabling requires a directory role that can manage directory diagnostic
# settings (Security Administrator or Global Administrator), granted out-of-band;
# it is a tenant directory operation, not a subscription ARM role assignment.
resource "azurerm_monitor_aad_diagnostic_setting" "entra" {
  count = var.enable_entra_diagnostics ? 1 : 0

  name               = var.name
  storage_account_id = var.storage_account_id

  dynamic "enabled_log" {
    for_each = toset(var.entra_log_categories)
    content {
      category = enabled_log.value
    }
  }
}
