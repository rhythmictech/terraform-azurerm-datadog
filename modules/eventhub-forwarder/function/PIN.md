# Vendored forwarder package

`deploy-<sha256 prefix>.zip` is Datadog's Azure Event Hub log forwarder, vendored verbatim so the
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

The file name carries the first 8 characters of the sha256, and `main.tf`
derives the path from `local.package_sha256`. This is load-bearing: the azurerm
provider republishes the package only when the `zip_deploy_file` path changes,
not when the file's contents change, so a fixed name would leave an existing
Function App running the previous package after a refresh.

## Refreshing the pin

1. Pick the upstream commit deliberately (read its diff; the forwarder's
   environment contract is `DD_API_KEY`, `DD_SITE`, `DD_TAGS`, `DD_SOURCE`,
   `DD_SERVICE`, `DD_PARSE_DEFENDER_LOGS`, `EVENTHUB_NAME`,
   `EVENTHUB_CONNECTION_STRING`, and `main.tf` mirrors it).
2. Fetch the package at that commit:

   ```bash
   curl -fL -o /tmp/deploy.zip \
     https://raw.githubusercontent.com/DataDog/datadog-serverless-functions/<commit>/azure/activity_logs_monitoring/deploy.zip
   shasum -a 256 /tmp/deploy.zip
   unzip -p /tmp/deploy.zip index.js | grep "const VERSION"
   ```

3. Replace the vendored file with one named after the new hash:
   `git rm function/deploy-*.zip`, then move the download to
   `function/deploy-<first 8 of the new sha256>.zip`.
4. Update `local.package_sha256` and `local.package_source` in `main.tf`, the
   hash in `tests/guards.tftest.hcl`, and this table.
5. Run the module tests. On apply, the plan for an existing Function App must
   show `zip_deploy_file` changing; if it does not, the package will not be
   republished.
