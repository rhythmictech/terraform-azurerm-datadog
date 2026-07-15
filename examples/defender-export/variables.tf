variable "subscription_id" {
  description = "Azure subscription id for the azurerm provider (mandatory on azurerm v4) and the subscription-scoped assignment."
  type        = string
}

variable "location" {
  description = "Azure region for the policy assignment identity, the export resource group, and any created Event Hub resources."
  type        = string
  default     = "eastus"
}

variable "export_resource_group_name" {
  description = "Resource group the export configuration is deployed into (the policy's resourceGroupName parameter)."
  type        = string
  default     = "rg-defender-export"
}

variable "event_hub_resource_group_name" {
  description = "Existing resource group for the created Event Hub namespace."
  type        = string
  default     = "rg-monitoring"
}

variable "user_assigned_identity_id" {
  description = "ARM id of the dedicated, low-value remediation identity (NOT the Terraform identity)."
  type        = string
}

variable "user_assigned_identity_principal_id" {
  description = "Object (principal) id of the dedicated remediation identity above."
  type        = string
}

variable "management_group_id" {
  description = "Management group id in full ARM form, for the management-group-scoped example."
  type        = string
  default     = "/providers/Microsoft.Management/managementGroups/example-root"
}

variable "existing_event_hub_id" {
  description = "ARM id of an existing Event Hub for the management-group-scoped example."
  type        = string
  default     = null
}

variable "existing_event_hub_authorization_rule_id" {
  description = "ARM id of an existing SEND authorization rule for the management-group-scoped example."
  type        = string
  default     = null
}
