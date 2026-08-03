# One query per requested type. `azurerm_resources` accepts `type` alone and
# scans the provider's whole subscription, so a caller monitoring several
# subscriptions instantiates this module once per subscription with an aliased
# provider.
data "azurerm_resources" "by_type" {
  for_each = toset(var.resource_types)

  type          = each.value
  required_tags = var.required_tags
}

locals {
  storage_type = "Microsoft.Storage/storageAccounts"

  # Region strings arrive in either display ("East US") or normalized ("eastus")
  # form depending on how a resource was created. Normalize both the destination
  # map and every discovered location so they always compare equal.
  destinations = {
    for region, id in var.storage_account_ids_by_region :
    replace(lower(region), " ", "") => id
  }

  excluded_groups = [for g in var.exclude_resource_groups : lower(g)]

  # Everything discovered, with exclusions applied, projected to a uniform shape.
  # The projection matters: concat() below requires identical object types, so
  # every branch must produce exactly {id, region, type}.
  discovered = flatten([
    for type, result in data.azurerm_resources.by_type : [
      for r in result.resources : {
        id     = r.id
        region = replace(lower(r.location), " ", "")
        type   = type
      }
      if !contains(local.excluded_groups, lower(r.resource_group_name))
      && !contains(var.exclude_resource_ids, r.id)
    ]
  ])

  # Storage accounts carry no diagnostic setting of their own; each expands into
  # its service scopes. Dropping the account scope is deliberate, not an
  # oversight: applying a setting to the account id fails.
  storage_scopes = flatten([
    for r in local.discovered : [
      for svc in var.storage_services : {
        id     = "${r.id}/${svc}/default"
        region = r.region
        type   = "${local.storage_type}/${svc}"
      }
    ]
    if r.type == local.storage_type
  ])

  plain_scopes = [
    for r in local.discovered : {
      id     = r.id
      region = r.region
      type   = r.type
    }
    if r.type != local.storage_type
  ]

  all_scopes = concat(local.plain_scopes, local.storage_scopes)

  # Regions holding scopes we have nowhere co-regional to send. Surfaced as an
  # output and, by default, a plan failure -- never dropped quietly.
  unmapped_regions = sort(distinct([
    for s in local.all_scopes : s.region
    if !contains(keys(local.destinations), s.region)
  ]))

  # Keyed by the scope's own resource id. That makes every state address
  # derivable from Azure alone, which is what lets pre-existing settings be
  # imported without a side table mapping friendly names to ids.
  scopes = {
    for s in local.all_scopes : s.id => s
    if contains(keys(local.destinations), s.region)
  }
}

# Guard rather than a variable validation, because the condition depends on
# discovered data and `validation {}` cannot see data sources.
resource "terraform_data" "region_coverage" {
  count = var.fail_on_unmapped_region ? 1 : 0

  input = local.unmapped_regions

  lifecycle {
    precondition {
      condition     = length(local.unmapped_regions) == 0
      error_message = <<-END
        Discovered resources in regions with no destination in storage_account_ids_by_region: ${join(", ", local.unmapped_regions)}.

        A diagnostic setting must target a storage account in the resource's own
        region, so these resources cannot be monitored by the destinations given.
        Add a forwarder and destination for each region listed, or exclude those
        resources. To proceed knowingly without them, set
        fail_on_unmapped_region = false; they will then be reported only in the
        unmapped_regions output.
      END
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  for_each = local.scopes

  name               = var.name
  target_resource_id = each.value.id
  storage_account_id = local.destinations[each.value.region]

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
