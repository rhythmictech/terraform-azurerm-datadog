# Example: create the Datadog app registration (sandbox / self-service)

This path sets `create_app_registration = true`, so the module creates the
`azuread_application` + `service_principal` + `application_password` itself
instead of consuming client-provided ids.

> **Not the production path.** Creating the app registration is a Microsoft
> Graph write and requires the deploying identity to hold **Application
> Administrator**. Use it only in sandbox / self-service tenants where the same
> identity that runs Terraform can also write to Entra. Production deployments
> should use [`examples/consume`](../consume), where the client owns the app
> registration and the Terraform identity needs no Graph access.

## Datadog site (US1)

As with the consume example, the `datadog` provider is pinned to US1
(`api_url = "https://api.datadoghq.com/"`).

## Usage

```hcl
module "datadog" {
  source = "../../"

  name                    = "sandbox"
  create_app_registration = true

  host_filters                      = ["datadog_managed:true"]
  manage_datadog_sp_role_assignment = true
  role_assignment_scopes            = var.role_assignment_scopes
}
```
