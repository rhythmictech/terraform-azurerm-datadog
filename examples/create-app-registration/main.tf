terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
    datadog = {
      source  = "DataDog/datadog"
      version = "~> 4.15"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# The azuread provider IS used on this path and needs an identity with Microsoft
# Graph write (Application Administrator) to create the app registration.
provider "azuread" {}

provider "datadog" {
  api_key = var.datadog_api_key
  app_key = var.datadog_app_key
  api_url = "https://api.datadoghq.com/"
}

# Self-service / sandbox path: the module creates the Datadog app registration,
# service principal, and client secret itself. This is NOT the production path
# (production consumes a client-created app registration -- see examples/consume).
module "datadog" {
  source = "../../"

  name                    = "sandbox"
  create_app_registration = true

  # No datadog_client_* / secret / sp_object_id vars are passed: the module
  # derives them from the resources it creates.

  host_filters = ["datadog_managed:true"]

  # Sandbox tenants often let the same identity own the role assignment.
  manage_datadog_sp_role_assignment = true
  role_assignment_scopes            = var.role_assignment_scopes

  tags = {
    managed_by = "terraform"
    module     = "terraform-azurerm-datadog"
  }
}
