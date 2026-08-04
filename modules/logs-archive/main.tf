locals {
  # Lowercase, alphanumeric-only slug of the caller's name. Storage account names
  # allow no hyphens and cap at 24 characters, so derive a <=18-char prefix plus a
  # 6-char deterministic hash for global uniqueness.
  name_slug = replace(lower(var.name), "/[^a-z0-9]/", "")

  storage_account_name = coalesce(
    var.storage_account_name,
    "${substr("${local.name_slug}ddarch", 0, 18)}${substr(sha1(var.name), 0, 6)}"
  )

  archive_name = coalesce(var.archive_name, var.name)
}

# Datadog requires a standard-performance (or Block-blobs premium) account whose
# access tier is Hot or Cool. Hot on creation; the lifecycle rule below moves
# aged blobs to Cool.
#
# Trivy ignores are deliberate tradeoffs for a log-archive store:
#   avd-azu-0012: Datadog's archive writer reaches the account over the public
#                 internet and is not an Azure trusted service, so a Deny default
#                 action would stop archiving. Locking it down means allowlisting
#                 Datadog's published egress ranges, which is a caller-side
#                 decision that has to be verified against those ranges and kept
#                 current; getting it wrong fails silently.
#   avd-azu-0057: request-level diagnostics belong on Azure Monitor diagnostic
#                 settings, not legacy Storage Analytics logging.
#   avd-azu-0058: LRS is a deliberate cost default for a multi-year store;
#                 storage_account_replication_type exposes GRS/GZRS for callers
#                 who want geo-redundancy and will pay for it.
#   avd-azu-0060: platform-managed keys. Customer-managed keys need a Key Vault,
#                 a key and an identity with wrap/unwrap, which is a caller-level
#                 decision rather than something this module should provision.
# (avd-azu-0061 is not ignored: infrastructure encryption is free and enabled
# below. It can only be set at creation.)
#trivy:ignore:avd-azu-0012
#trivy:ignore:avd-azu-0057
#trivy:ignore:avd-azu-0058
#trivy:ignore:avd-azu-0060
resource "azurerm_storage_account" "archive" {
  name                = local.storage_account_name
  resource_group_name = var.resource_group_name
  location            = var.region

  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = var.storage_account_replication_type
  access_tier              = "Hot"

  https_traffic_only_enabled        = true
  min_tls_version                   = "TLS1_2"
  allow_nested_items_to_be_public   = false
  public_network_access_enabled     = true
  infrastructure_encryption_enabled = true
  shared_access_key_enabled         = var.shared_access_key_enabled

  # Versioning plus soft delete is the deliberate substitute for an immutability
  # policy. Datadog documents that it may rewrite the trailing object, which an
  # immutability policy would block; see the README.
  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = var.blob_soft_delete_retention_days
    }

    container_delete_retention_policy {
      days = var.blob_soft_delete_retention_days
    }
  }

  tags = var.tags
}

resource "azurerm_storage_container" "archive" {
  name                  = var.container_name
  storage_account_id    = azurerm_storage_account.archive.id
  container_access_type = "private"
}

# Exactly two actions, and deliberately no `tier_to_cold` or `tier_to_archive`.
# Datadog supports only the Hot and Cool access tiers for archiving and Archive
# Search; blobs in Cold or Archive are written successfully and then cannot be
# rehydrated. The naive port of the AWS 90-day-to-Glacier rule is therefore a
# silent data-recovery failure, which is why the action set is fixed here rather
# than exposed as a variable.
resource "azurerm_storage_management_policy" "archive" {
  storage_account_id = azurerm_storage_account.archive.id

  rule {
    name    = "datadog-archive-retention"
    enabled = true

    filters {
      blob_types   = ["blockBlob"]
      prefix_match = var.archive_path != null ? ["${var.container_name}/${trimprefix(var.archive_path, "/")}"] : ["${var.container_name}/"]
    }

    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than = var.tier_to_cool_after_days
        delete_after_days_since_modification_greater_than       = var.delete_after_days
      }
    }
  }
}

# Storage Blob Data Contributor is a DataAction role, so this grant cannot be made
# through a management-plane-only delegation. The applying identity needs RBAC
# write on the scope.
resource "azurerm_role_assignment" "datadog_archive_writer" {
  count = var.create_role_assignment ? 1 : 0

  scope                = azurerm_storage_account.archive.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.datadog_sp_object_id
}

# The archive is configured Datadog-side and reads nothing from the forwarder
# seam; it captures logs already ingested into the org. `azure_archive` takes no
# region, so one archive covers every region.
resource "datadog_logs_archive" "archive" {
  name  = local.archive_name
  query = var.archive_query

  include_tags                    = var.include_tags
  rehydration_tags                = var.rehydration_tags
  rehydration_max_scan_size_in_gb = var.rehydration_max_scan_size_in_gb

  azure_archive {
    client_id       = var.datadog_client_id
    tenant_id       = var.datadog_tenant_id
    storage_account = azurerm_storage_account.archive.name
    container       = azurerm_storage_container.archive.name
    path            = var.archive_path
  }

  # The role assignment must exist before Datadog validates that it can write to
  # the container, and Datadog validates on archive creation.
  depends_on = [azurerm_role_assignment.datadog_archive_writer]
}
