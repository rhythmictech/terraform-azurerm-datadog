variable "subscription_id" {
  description = "Azure subscription id for the azurerm provider (mandatory on azurerm v4)."
  type        = string
}

variable "datadog_api_key" {
  description = "Datadog API key for the datadog provider."
  type        = string
  sensitive   = true
}

variable "datadog_app_key" {
  description = "Datadog application key for the datadog provider."
  type        = string
  sensitive   = true
}

variable "datadog_client_id" {
  description = "Client (application) id of the client-created Datadog app registration."
  type        = string
}

variable "datadog_tenant_id" {
  description = "Entra tenant id of the client tenant."
  type        = string
}

variable "datadog_sp_object_id" {
  description = "Object id of the Datadog service principal."
  type        = string
}

variable "datadog_client_secret" {
  description = "Client secret of the client-created Datadog app registration."
  type        = string
  sensitive   = true
}

variable "role_assignment_scopes" {
  description = "Subscription scopes for the Datadog SP Monitoring Reader assignment."
  type        = list(string)
}
