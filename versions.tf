terraform {
  # >= 1.9 is REQUIRED: input-variable `validation {}` blocks reference *other*
  # variables (cross-variable rules), which is only legal on >= 1.9, and
  # `terraform test` uses `mock_provider` (>= 1.7). No `aws` provider here;
  # state/KMS stay in the client repo's `common/`.
  required_version = ">= 1.9"

  required_providers {
    # v4 is the current major (subscription_id is mandatory in the provider
    # block on v4 -> examples set it). Do not leave >= 3.x, which silently
    # resolves to v4.
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }

    # VERIFIED 2026-07-09: latest 4.15.0. v4.0.0 was a breaking major
    # (Plugin Protocol v6, Terraform >= 1.1.5). Do NOT carry the AWS module's
    # >= 3.39 forward -- it resolves to v4 with breaking changes unguarded.
    datadog = {
      source  = "DataDog/datadog"
      version = "~> 4.15"
    }

    # v3-only HCL (client_id / application_password.application_id renames
    # landed in v3.0, not v2.x). Only exercised when create_app_registration
    # = true; declared unconditionally is fine (count = 0 on the consume path).
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
  }
}
