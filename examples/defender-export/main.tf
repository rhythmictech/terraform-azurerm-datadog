terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# azurerm v4 makes subscription_id mandatory in the provider block.
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# Subscription scope (the default): assign the export policy to a single
# subscription and create the central Event Hub here. The module also creates a
# send-only authorization rule whose id is passed to the policy.
module "defender_export_subscription" {
  source = "../../modules/defender-export"

  scope_type      = "subscription"
  subscription_id = var.subscription_id
  location        = var.location

  export_resource_group_name = var.export_resource_group_name

  create_event_hub              = true
  event_hub_namespace_name      = "defender-export-ns"
  event_hub_name                = "defender-export"
  event_hub_resource_group_name = var.event_hub_resource_group_name

  user_assigned_identity_id           = var.user_assigned_identity_id
  user_assigned_identity_principal_id = var.user_assigned_identity_principal_id

  tags = {
    managed_by = "terraform"
    module     = "terraform-azurerm-datadog"
  }
}

# Management-group scope (the documented future path): assign the export policy
# once at a management group and point it at an existing central Event Hub.
module "defender_export_management_group" {
  source = "../../modules/defender-export"

  scope_type          = "management_group"
  management_group_id = var.management_group_id
  location            = var.location

  export_resource_group_name = var.export_resource_group_name

  create_event_hub                         = false
  existing_event_hub_id                    = var.existing_event_hub_id
  existing_event_hub_authorization_rule_id = var.existing_event_hub_authorization_rule_id

  user_assigned_identity_id           = var.user_assigned_identity_id
  user_assigned_identity_principal_id = var.user_assigned_identity_principal_id
}
