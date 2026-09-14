terraform {
  # >= 1.9 for parity with the module family (cross-variable `validation {}`)
  # and `terraform test` `mock_provider` (>= 1.7).
  required_version = ">= 1.9"

  required_providers {
    # azurerm for everything this module creates. The forwarder code is a
    # vendored, pinned zip (function/deploy.zip), so no archive provider is
    # needed, and the Function talks to Datadog's HTTP intake at runtime, so no
    # datadog provider is needed either.
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}
