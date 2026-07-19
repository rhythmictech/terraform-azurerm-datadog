# Datadog custom log pipeline for forwarded Azure Service Health / Resource
# Health records. Cloud-agnostic (datadog provider only); the Azure analog of the
# AWS module's `health.tf` remapper. It normalizes the health events that arrive
# via the Activity Log -> storage -> forwarder seam so downstream monitors can
# filter on stable attributes (e.g. @properties.incidentType,
# @properties.currentHealthStatus, @properties.cause).
#
# Field paths target the STORAGE-STREAMED JSON shape (records[].properties.*),
# NOT the Azure portal field names. The forwarder may or may not unwrap the
# top-level `records[]` array, so each remapper lists both the wrapped
# (`records.properties.*`) and unwrapped (`properties.*`) source path and the
# filter matches `category` at either depth. The remapper `target` is the
# unwrapped path the monitors query, so the field resolves consistently whichever
# way the forwarder delivers it.
#
# TODO: confirm every field path below against a real forwarded record before
# relying on the derived facets in production.
resource "datadog_logs_custom_pipeline" "health" {
  count = var.manage_health_pipeline ? 1 : 0

  name       = "Azure Service Health and Resource Health"
  is_enabled = true

  # Scope the pipeline to Activity Log health categories only. `category` is a
  # top-level record field in the storage-streamed JSON; match it at both the
  # unwrapped and records-wrapped depth.
  # TODO: confirm field path against a real forwarded record.
  filter {
    query = "@category:(ServiceHealth OR ResourceHealth) OR @records.category:(ServiceHealth OR ResourceHealth)"
  }

  # Group health logs by the affected Azure service (ServiceHealth records).
  # TODO: confirm field path against a real forwarded record.
  processor {
    service_remapper {
      name       = "Set service from the affected Azure service"
      is_enabled = true
      sources    = ["properties.service", "records.properties.service"]
    }
  }

  # Surface the human-readable health communication / title as the log message.
  # TODO: confirm field path against a real forwarded record.
  processor {
    message_remapper {
      name       = "Set message from the health communication"
      is_enabled = true
      sources = [
        "properties.communication",
        "properties.title",
        "records.properties.communication",
        "records.properties.title",
      ]
    }
  }

  # Expose the Service Health incident classification (Incident, Maintenance,
  # Informational, ActionRequired, Security) at the @properties.incidentType path
  # the monitors query.
  # TODO: confirm field path against a real forwarded record.
  processor {
    attribute_remapper {
      name                 = "Normalize Service Health incident type"
      is_enabled           = true
      source_type          = "attribute"
      sources              = ["records.properties.incidentType"]
      target               = "properties.incidentType"
      target_type          = "attribute"
      preserve_source      = false
      override_on_conflict = false
    }
  }

  # Expose the Resource Health status (Available, Unavailable, Degraded, Unknown)
  # at the @properties.currentHealthStatus path the monitors query.
  # TODO: confirm field path against a real forwarded record.
  processor {
    attribute_remapper {
      name                 = "Normalize Resource Health status"
      is_enabled           = true
      source_type          = "attribute"
      sources              = ["records.properties.currentHealthStatus"]
      target               = "properties.currentHealthStatus"
      target_type          = "attribute"
      preserve_source      = false
      override_on_conflict = false
    }
  }

  # Expose the Resource Health cause (PlatformInitiated, UserInitiated, ...) at
  # the @properties.cause path so monitors can exclude user-initiated events.
  # TODO: confirm field path against a real forwarded record.
  processor {
    attribute_remapper {
      name                 = "Normalize Resource Health cause"
      is_enabled           = true
      source_type          = "attribute"
      sources              = ["records.properties.cause"]
      target               = "properties.cause"
      target_type          = "attribute"
      preserve_source      = false
      override_on_conflict = false
    }
  }
}
