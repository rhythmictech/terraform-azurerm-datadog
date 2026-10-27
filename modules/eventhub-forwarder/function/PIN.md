# Vendored forwarder package

`deploy.zip` is Datadog's Azure Event Hub log forwarder, vendored verbatim so the
module deploys a known artifact rather than whatever `master` holds on apply day.

| Field | Value |
|---|---|
| Upstream repository | `DataDog/datadog-serverless-functions` |
| Path | `azure/activity_logs_monitoring/deploy.zip` |
| Commit | `8da5d723783280362f1468c39d6c990d27282b31` (2026-10-14, "Remove local.settings.json from activity logs deploy.zip (#1226)") |
| Forwarder `VERSION` constant in `index.js` | `2.2.0` |
| `package.json` version | `2.1.1` |
| sha256 | `61c29b66398e549429e289e943a148b98194131b3e7e22d0b7d658bca709ef51` |
| Runtime | Node 22 (the package requires Node >= 20), Azure Functions v4, extension bundle `[4.*, 5.0.0)` |

The module's Function App carries a `precondition` comparing the file on disk to
the sha256 above, so a swapped or corrupted package fails the plan instead of
being deployed.

## Refreshing the pin

1. Pick the upstream commit deliberately (read its diff; the forwarder's
   environment contract is `DD_API_KEY`, `DD_SITE`, `DD_TAGS`, `DD_SOURCE`,
   `DD_SERVICE`, `DD_PARSE_DEFENDER_LOGS`, `EVENTHUB_NAME`,
   `EVENTHUB_CONNECTION_STRING`, and `main.tf` mirrors it).
2. Fetch the package at that commit:

   ```bash
   curl -fL -o function/deploy.zip \
     https://raw.githubusercontent.com/DataDog/datadog-serverless-functions/<commit>/azure/activity_logs_monitoring/deploy.zip
   shasum -a 256 function/deploy.zip
   unzip -p function/deploy.zip index.js | grep "const VERSION"
   ```

3. Update `local.package_sha256` and `local.package_source` in `main.tf`, and
   this table.
4. Run the module tests, then apply; `zip_deploy_file` redeploys the Function
   when the package changes.
