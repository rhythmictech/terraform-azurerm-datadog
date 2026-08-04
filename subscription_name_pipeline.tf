# Datadog custom log pipeline mapping an Azure subscription id to a human-readable
# subscription name. Cloud-agnostic (datadog provider only); the Azure analog of
# the AWS module's account-id-to-name mapper.
#
# Two processors, in order, because `lookup_processor` accepts a SINGLE `source`
# while the forwarded record shape is ambiguous:
#
#   1. An attribute_remapper collapses every candidate source path into one
#      normalized attribute. This is the same technique health.tf uses for the
#      wrapped (`records.*`) versus unwrapped delivery shapes, and it is why the
#      candidate paths are a list here.
#   2. A lookup_processor maps that normalized attribute through the caller's
#      id-to-name table.
#
# Stacking two lookup_processors on different sources instead would risk the
# second overwriting the first's result with `default_lookup` when its own source
# is absent, so the normalize-then-look-up order is deliberate.
#
# TODO: confirm the source attribute against a real forwarded record before
# relying on the derived facet. The default candidates are the likely paths, not
# verified ones, and a wrong path yields a pipeline that silently maps nothing.
resource "datadog_logs_custom_pipeline" "subscription_name" {
  count = var.manage_subscription_name_pipeline ? 1 : 0

  name       = var.subscription_name_pipeline_name
  is_enabled = true

  # Datadog custom pipelines are org-global. A broad query on an org serving more
  # than one account means this pipeline evaluates everyone's logs, so narrow it
  # when the org is shared.
  filter {
    query = var.subscription_name_pipeline_filter_query
  }

  processor {
    attribute_remapper {
      name                 = "Normalize the Azure subscription id path"
      is_enabled           = true
      source_type          = "attribute"
      sources              = var.subscription_name_sources
      target               = var.subscription_name_normalized_attribute
      target_type          = "attribute"
      preserve_source      = true
      override_on_conflict = false
    }
  }

  processor {
    lookup_processor {
      name       = "Map subscription id to subscription name"
      is_enabled = true
      source     = var.subscription_name_normalized_attribute
      target     = var.subscription_name_target_attribute

      # `lookup_table` entries are "key,value" strings.
      lookup_table = [
        for subscription_id, subscription_name in var.subscription_name_map :
        "${subscription_id},${subscription_name}"
      ]

      default_lookup = var.subscription_name_default
    }
  }
}
