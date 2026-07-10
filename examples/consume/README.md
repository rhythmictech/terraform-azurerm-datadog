# Example: consume a client-created Datadog app registration

This is the **default** integration path. The client creates the Datadog app
registration (the one operation that requires a Microsoft Graph write) and
shares its `client_id`, `tenant_id`, service-principal **object id**, and
`client_secret`. The module consumes those ids and creates no Entra objects, so
the run needs **no Graph credentials**.

## Datadog site (US1)

The `datadog` provider is pinned to US1: `api_url = "https://api.datadoghq.com/"`
(the provider default). The URL must not end in `/api/`. If your org is on a
different site, change `api_url` accordingly, otherwise the integration call
fails loudly.

## Noise control via tag filters

Azure has no per-namespace metric toggles. Which hosts Datadog pulls in is
controlled entirely by tag filters. This example uses the
`datadog_managed:true` convention via `host_filters`, so only resources tagged
that way are monitored.

## Role assignment

`manage_datadog_sp_role_assignment` is left `false`: the Monitoring Reader
assignment for the Datadog SP is expected to be pre-created out-of-band during
onboarding. `role_assignment_scopes` is still provided so the flag can be
flipped later with no further wiring.

## Usage

```hcl
module "datadog" {
  source = "../../"

  name                  = "example-client"
  datadog_client_id     = var.datadog_client_id
  datadog_tenant_id     = var.datadog_tenant_id
  datadog_sp_object_id  = var.datadog_sp_object_id
  datadog_client_secret = var.datadog_client_secret

  host_filters                      = ["datadog_managed:true"]
  manage_datadog_sp_role_assignment = false
  role_assignment_scopes            = var.role_assignment_scopes
}
```
