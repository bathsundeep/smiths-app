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

# Storage Container for holding our archived app to deploy
resource "azurerm_storage_container" "storage_container" {
    name = "function-releases"
    storage_account_name = "${azurerm_storage_account.storage_account.name}"
    container_access_type = "private"
}

# Archive the Function App directory
data "archive_file" "file_function_app" {
  type        = "zip"
  source_dir  = "./test-function-app"
  output_path = "${var.archive_file_path}"
}

# Upload archive to Storage Blob
resource "azurerm_storage_blob" "storage_blob" {
  name = "${filesha256("${var.archive_file_path}")}.zip"
  storage_account_name = azurerm_storage_account.storage_account.name
  storage_container_name = azurerm_storage_container.storage_container.name
  type = "Block"
  source = "${var.archive_file_path}"
}

# Read only Shared Account Signature (SAS) to access our archive
data "azurerm_storage_account_blob_container_sas" "storage_account_blob_container_sas" {
  connection_string = azurerm_storage_account.storage_account.primary_connection_string
  container_name    = azurerm_storage_container.storage_container.name

  start = "2021-01-01T00:00:00Z"
  expiry = "2022-01-01T00:00:00Z"

  permissions {
    read   = true
    add    = false
    create = false
    write  = false
    delete = false
    list   = false
  }
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
  storage_account_name       = azurerm_storage_account.storage_account.name
  storage_account_access_key = azurerm_storage_account.storage_account.primary_access_key
  version                    = "~3"
  os_type = "linux"
  app_settings = {
    # Load the archived package from our Storage Blob in our Storage Container using the SAS
    "WEBSITE_RUN_FROM_PACKAGE" = "https://${azurerm_storage_account.storage_account.name}.blob.core.windows.net/${azurerm_storage_container.storage_container.name}/${azurerm_storage_blob.storage_blob.name}${data.azurerm_storage_account_blob_container_sas.storage_account_blob_container_sas.sas}"
    "FUNCTIONS_WORKER_RUNTIME" = "python"
    "AzureWebJobsDisableHomepage" = "true"
  }
  site_config {
    linux_fx_version          = "PYTHON|3.7"
    use_32_bit_worker_process = false
  }
}