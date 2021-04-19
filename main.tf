terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "~>2.0"
    }
  }
}

# Cloud Provider
provider "azurerm" {
  features {}
}

# Resource Group to manage container
resource "azurerm_resource_group" "resource_group" {
  name = "${var.project}_resource_group"
  location = "${var.location}"
}

# Storage Account for container file system
resource "azurerm_storage_account" "storage_account" {
    name = "${var.project}storage" # this can only be lowercase letters and numbers...
    resource_group_name = azurerm_resource_group.resource_group.name
    location = "${var.location}"
    account_tier = "Standard"
    account_replication_type = "LRS"
}

# App Service Plan for defining compute resources on container (resource_group)
resource "azurerm_app_service_plan" "app_service_plan" {
  name                = "${var.project}_app_service_plan"
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = var.location
  kind                = "FunctionApp"
  reserved = true
  sku {
    # Linux Consumption plan
    tier = "Dynamic"
    size = "Y1"
  }
}

# Function App itself
resource "azurerm_function_app" "function_app" {
  name                       = "${var.project}-function-app" # this cant take underscores...
  resource_group_name        = azurerm_resource_group.resource_group.name
  location                   = var.location
  app_service_plan_id        = azurerm_app_service_plan.app_service_plan.id
  app_settings = {
    "WEBSITE_RUN_FROM_PACKAGE" = "",
    "FUNCTIONS_WORKER_RUNTIME" = "node",
  }
  os_type = "linux"
  site_config {
    linux_fx_version          = "node|14"
    use_32_bit_worker_process = false
  }
  storage_account_name       = azurerm_storage_account.storage_account.name
  storage_account_access_key = azurerm_storage_account.storage_account.primary_access_key
  version                    = "~3"

  lifecycle {
    ignore_changes = [
      app_settings["WEBSITE_RUN_FROM_PACKAGE"],
    ]
  }
}