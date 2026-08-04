terraform {
  # >= 1.9 for parity with the module family (cross-variable `validation {}`,
  # used here to reject a delete-before-tier day ordering) and `terraform test`
  # `mock_provider` (>= 1.7).
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
