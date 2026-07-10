terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    datadog = {
      source  = "DataDog/datadog"
      version = "~> 4.15"
    }
  }
}

# azurerm v4 makes subscription_id mandatory in the provider block.
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# The consumer configures the datadog provider. api_url is US1 by default; it
# must NOT end in "/api/". A mis-sited org fails loudly against this endpoint.
provider "datadog" {
  api_key = var.datadog_api_key
  app_key = var.datadog_app_key
  api_url = "https://api.datadoghq.com/"
}

# Default (consume) path: pass the client-created app-registration ids. The
# module creates no Entra objects, so this run needs no Graph credentials.
# Note: create_app_registration is intentionally NOT set (defaults to false).
module "datadog" {
  source = "../../"

  name = "example-client"

  # Client-created Datadog app registration (shared by the client at onboarding).
  datadog_client_id     = var.datadog_client_id
  datadog_tenant_id     = var.datadog_tenant_id
  datadog_sp_object_id  = var.datadog_sp_object_id
  datadog_client_secret = var.datadog_client_secret

  # Tag-based noise control: only hosts carrying datadog_managed:true are pulled.
  host_filters = ["datadog_managed:true"]

  # The Monitoring Reader assignment is pre-created out-of-band during onboarding,
  # so leave management off here (default). Scopes are still declared so flipping
  # the flag later requires no further wiring.
  manage_datadog_sp_role_assignment = false
  role_assignment_scopes            = var.role_assignment_scopes

  tags = {
    managed_by = "terraform"
    module     = "terraform-azurerm-datadog"
  }
}
