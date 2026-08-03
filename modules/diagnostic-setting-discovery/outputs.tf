output "diagnostic_setting_ids" {
  description = "Map of created diagnostic-setting ids keyed by the monitored scope's resource id."
  value       = { for k, v in azurerm_monitor_diagnostic_setting.this : k => v.id }
}

output "monitored_scope_ids" {
  description = "Resource ids that received a diagnostic setting, sorted. Also the `for_each` key set, so a state address is `module.<name>.azurerm_monitor_diagnostic_setting.this[\"<scope id>\"]`."
  value       = sort(keys(local.scopes))
}

output "scope_count_by_region" {
  description = "Count of monitored scopes per region. Worth eyeballing on the first plan: a region with a surprisingly large count usually means a resource type was discovered that nobody meant to pay to ingest."
  value = {
    for region in distinct([for s in local.scopes : s.region]) :
    region => length([for s in local.scopes : s if s.region == region])
  }
}

output "scope_count_by_type" {
  description = "Count of monitored scopes per resource type, with storage split by service scope."
  value = {
    for type in distinct([for s in local.scopes : s.type]) :
    type => length([for s in local.scopes : s if s.type == type])
  }
}

output "discovered_count_by_requested_type" {
  description = <<-END
    Count of resources discovered for EVERY entry in `var.resource_types`,
    including entries that matched nothing (reported as 0).

    Check this on the first plan. A misspelled or wrongly-cased type discovers
    nothing, and because that failure produces no resources rather than an error,
    it is otherwise indistinguishable from "the subscription genuinely has none of
    those". A `0` here is the only signal.

    Counts are of discovered RESOURCES, before storage accounts are expanded into
    service scopes, so a storage entry here is the account count while
    `scope_count_by_type` reports the expanded scopes.
  END
  value = {
    for type in var.resource_types :
    type => length([for r in local.discovered : r if r.type == type])
  }
}

output "unmapped_regions" {
  description = "Regions holding discovered scopes with no destination in `storage_account_ids_by_region`. Empty unless `fail_on_unmapped_region` is false, since otherwise the plan fails instead. A non-empty value means those resources are NOT monitored."
  value       = local.unmapped_regions
}
