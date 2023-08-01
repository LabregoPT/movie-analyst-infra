##_--------------------------------------------

## Azure Cloud Configuration files

##---------------------------------------------

## Network configurations

resource "azurerm_resource_group" "db_rg" {
  name     = "database-resource-group"
  location = "East US"
}

resource "azurerm_virtual_network" "db_virtual_network" {
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.db_rg.location
  name                = "db-vnet"
  resource_group_name = azurerm_resource_group.db_rg.name
}

resource "azurerm_subnet" "db_subnet" {
  address_prefixes     = ["10.0.2.0/24"]
  name                 = "db-subnet"
  resource_group_name  = azurerm_resource_group.db_rg.name
  virtual_network_name = azurerm_virtual_network.db_virtual_network.name
  service_endpoints    = ["Microsoft.Storage"]
}

resource "azurerm_mysql_flexible_server" "db_server" {
  location              = azurerm_resource_group.db_rg.location
  name                  = "movie-analyst-db-server"
  resource_group_name   = azurerm_resource_group.db_rg.name
  backup_retention_days = 1
  sku_name              = "B_Standard_B1s"
  version               = "8.0.21"
  zone = 1
  storage {
    iops    = 360
    size_gb = 20
  }
  administrator_login    = var.db_user
  administrator_password = var.db_password
}

resource "azurerm_mysql_flexible_database" "database" {
  charset             = "utf8mb4"
  collation           = "utf8mb4_unicode_ci"
  name                = "movie-analyst-database"
  resource_group_name = azurerm_resource_group.db_rg.name
  server_name         = azurerm_mysql_flexible_server.db_server.name
}

resource "azurerm_mysql_flexible_server_configuration" "db_server_config" {
  name = "require_secure_transport"
  resource_group_name = azurerm_resource_group.db_rg.name
  server_name = azurerm_mysql_flexible_server.db_server.name
  value = "OFF"
}