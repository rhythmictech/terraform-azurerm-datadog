mock_provider "azurerm" {
  source = "./tests/setup"
}

mock_provider "azuread" {
  source = "./tests/setup"
}

mock_provider "datadog" {
  source = "./tests/setup"
}

variables {
  name                   = "example"
  datadog_client_id      = "11111111-1111-1111-1111-111111111111"
  datadog_tenant_id      = "22222222-2222-2222-2222-222222222222"
  datadog_sp_object_id   = "33333333-3333-3333-3333-333333333333"
  datadog_client_secret  = "consume-secret"
  role_assignment_scopes = []
}

# Off by default. Pipelines are org-global, so a default-on pipeline would appear
# in every org the module is instantiated against.
run "subscription_name_pipeline_off_by_default" {
  command = plan

  assert {
    condition     = length(datadog_logs_custom_pipeline.subscription_name) == 0
    error_message = "the subscription-name pipeline must be gated off by default"
  }
}

run "subscription_name_pipeline_on" {
  command = plan

  variables {
    manage_subscription_name_pipeline = true
    subscription_name_map = {
      "00000000-0000-0000-0000-000000000001" = "example-prod"
      "00000000-0000-0000-0000-000000000002" = "example-dev"
    }
  }

  assert {
    condition     = length(datadog_logs_custom_pipeline.subscription_name) == 1
    error_message = "enabling the flag should plan exactly one pipeline"
  }

  assert {
    condition     = datadog_logs_custom_pipeline.subscription_name[0].name == "Azure Subscription Name Mapper"
    error_message = "the pipeline should take the default display name"
  }

  assert {
    condition     = datadog_logs_custom_pipeline.subscription_name[0].is_enabled == true
    error_message = "the pipeline should be enabled when managed"
  }

  # Normalize first, then look up. The remapper collapses the candidate source
  # paths into one attribute; the lookup reads that attribute. Order matters, so
  # assert it rather than just asserting both processors exist.
  assert {
    condition     = length(datadog_logs_custom_pipeline.subscription_name[0].processor) == 2
    error_message = "the pipeline should hold exactly two processors"
  }

  assert {
    condition     = length(datadog_logs_custom_pipeline.subscription_name[0].processor[0].attribute_remapper) == 1
    error_message = "the FIRST processor must be the attribute remapper that normalizes the source path"
  }

  assert {
    condition     = length(datadog_logs_custom_pipeline.subscription_name[0].processor[1].lookup_processor) == 1
    error_message = "the SECOND processor must be the lookup"
  }

  # The remapper's target and the lookup's source must be the same attribute, or
  # the lookup reads something the remapper never wrote and maps nothing.
  assert {
    condition = (datadog_logs_custom_pipeline.subscription_name[0].processor[0].attribute_remapper[0].target ==
    datadog_logs_custom_pipeline.subscription_name[0].processor[1].lookup_processor[0].source)
    error_message = "the remapper target and the lookup source must be the same attribute"
  }

  assert {
    condition     = datadog_logs_custom_pipeline.subscription_name[0].processor[1].lookup_processor[0].target == "subscription_name"
    error_message = "the lookup should write to subscription_name by default, matching the metrics integration tag"
  }

  # lookup_table entries are "key,value" strings built from the input map.
  assert {
    condition     = length(datadog_logs_custom_pipeline.subscription_name[0].processor[1].lookup_processor[0].lookup_table) == 2
    error_message = "a two-entry map should render two lookup_table entries"
  }

  assert {
    condition = contains(
      datadog_logs_custom_pipeline.subscription_name[0].processor[1].lookup_processor[0].lookup_table,
      "00000000-0000-0000-0000-000000000001,example-prod"
    )
    error_message = "lookup_table entries must be rendered as 'id,name'"
  }

  # preserve_source keeps the original attribute, so normalizing does not destroy
  # the raw subscription id on the record.
  assert {
    condition     = datadog_logs_custom_pipeline.subscription_name[0].processor[0].attribute_remapper[0].preserve_source == true
    error_message = "normalizing must not consume the original subscription id attribute"
  }
}

# Both wrapped and unwrapped delivery shapes are covered by default, which is the
# whole reason the sources input is a list.
run "default_sources_cover_wrapped_and_unwrapped_records" {
  command = plan

  variables {
    manage_subscription_name_pipeline = true
    subscription_name_map             = { "00000000-0000-0000-0000-000000000001" = "example-prod" }
  }

  assert {
    condition = contains(
      datadog_logs_custom_pipeline.subscription_name[0].processor[0].attribute_remapper[0].sources,
      "records.subscriptionId"
    )
    error_message = "the records-wrapped path must be a default candidate source"
  }

  assert {
    condition = contains(
      datadog_logs_custom_pipeline.subscription_name[0].processor[0].attribute_remapper[0].sources,
      "subscriptionId"
    )
    error_message = "the unwrapped path must be a default candidate source"
  }
}

run "custom_names_and_filter_flow_through" {
  command = plan

  variables {
    manage_subscription_name_pipeline       = true
    subscription_name_map                   = { "00000000-0000-0000-0000-000000000001" = "example-prod" }
    subscription_name_pipeline_name         = "Custom Mapper"
    subscription_name_pipeline_filter_query = "source:azure"
    subscription_name_target_attribute      = "sub_display_name"
    subscription_name_normalized_attribute  = "normalized_sub_id"
    subscription_name_default               = "unmapped"
  }

  assert {
    condition     = datadog_logs_custom_pipeline.subscription_name[0].name == "Custom Mapper"
    error_message = "a custom pipeline name should be used"
  }

  assert {
    condition     = datadog_logs_custom_pipeline.subscription_name[0].filter[0].query == "source:azure"
    error_message = "a custom filter query should be used"
  }

  assert {
    condition     = datadog_logs_custom_pipeline.subscription_name[0].processor[1].lookup_processor[0].target == "sub_display_name"
    error_message = "a custom target attribute should be used"
  }

  assert {
    condition = (datadog_logs_custom_pipeline.subscription_name[0].processor[0].attribute_remapper[0].target == "normalized_sub_id" &&
    datadog_logs_custom_pipeline.subscription_name[0].processor[1].lookup_processor[0].source == "normalized_sub_id")
    error_message = "a custom normalized attribute should be used by both processors"
  }

  assert {
    condition     = datadog_logs_custom_pipeline.subscription_name[0].processor[1].lookup_processor[0].default_lookup == "unmapped"
    error_message = "default_lookup should carry subscription_name_default"
  }
}

# An enabled pipeline with an empty map would map nothing while looking configured.
run "enabled_with_empty_map_rejected" {
  command = plan

  variables {
    manage_subscription_name_pipeline = true
    subscription_name_map             = {}
  }

  expect_failures = [
    var.subscription_name_map,
  ]
}

run "empty_sources_rejected" {
  command = plan

  variables {
    manage_subscription_name_pipeline = true
    subscription_name_map             = { "00000000-0000-0000-0000-000000000001" = "example-prod" }
    subscription_name_sources         = []
  }

  expect_failures = [
    var.subscription_name_sources,
  ]
}
