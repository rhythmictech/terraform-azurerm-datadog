# One controlled diagnostic setting per target, all shipping to the same
# forwarder storage account. Azure keys settings by name, so a distinct name is
# non-clobbering by construction. `for_each` runs over an INPUT map, so the key
# set is known at plan time.
resource "azurerm_monitor_diagnostic_setting" "this" {
  for_each = var.target_resource_ids

  name               = var.name
  target_resource_id = each.value
  storage_account_id = var.storage_account_id

  dynamic "enabled_log" {
    for_each = toset(var.log_category_groups)
    content {
      category_group = enabled_log.value
    }
  }

  dynamic "enabled_log" {
    for_each = toset(var.log_categories)
    content {
      category = enabled_log.value
    }
  }

  dynamic "enabled_metric" {
    for_each = toset(var.metric_categories)
    content {
      category = enabled_metric.value
    }
  }
}
