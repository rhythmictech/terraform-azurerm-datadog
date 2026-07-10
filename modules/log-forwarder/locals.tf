locals {
  # Lowercase, alphanumeric-only slugs of the caller inputs. var.region may be a
  # display form ("East US") whose space is not a valid storage/Container-App name
  # character, so strip every non-[a-z0-9] rune (not just dashes/underscores).
  name_slug   = replace(lower(var.name), "/[^a-z0-9]/", "")
  region_slug = replace(lower(var.region), "/[^a-z0-9]/", "")

  # Safe, globally-unique storage-account name when not overridden: <= 24 chars,
  # [a-z0-9] only. A <=18-char cleaned prefix plus a 6-char deterministic hash of
  # name+region for global uniqueness. The child module's own name regex is
  # charset/length only and provides no uniqueness.
  storage_account_name = coalesce(
    var.storage_account_name,
    "${substr("${local.name_slug}dd${local.region_slug}", 0, 18)}${substr(sha1("${var.name}${var.region}"), 0, 6)}"
  )

  # Container App environment/job names must be unique within a resource group
  # (<= 60 / 32 chars). The child module defaults them to STATIC strings, so
  # uniquify per region to let multiple regional forwarders share one resource
  # group. trimsuffix() drops a hyphen the length cap might land on.
  forwarder_env_name = trimsuffix(substr("${local.name_slug}-ddfwd-env-${local.region_slug}", 0, 60), "-")
  forwarder_job_name = trimsuffix(substr("${local.name_slug}-ddfwd-${local.region_slug}", 0, 32), "-")

  # trimspace() guards against a Key Vault secret stored with a trailing newline
  # (the child module hard-validates length == 32). On valid input exactly one
  # source is set (enforced by variable validation), so this never trims null.
  datadog_api_key = trimspace(var.key_vault_id != null ? data.azurerm_key_vault_secret.dd[0].value : var.datadog_api_key)
}
