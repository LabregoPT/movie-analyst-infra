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

## VPN NETWORK CONFIG
resource "azurerm_subnet" "VPN-gateway-subnet" {
  address_prefixes = [ "10.0.255.0/24" ]
  name = "GatewaySubnet"
  resource_group_name = azurerm_resource_group.db_rg.name
  virtual_network_name = azurerm_virtual_network.db_virtual_network.name
}

resource "azurerm_public_ip" "public_ip" {
  allocation_method = "Dynamic"
  location = azurerm_resource_group.db_rg.location
  name = "vpn-gateway-ip"
  resource_group_name = azurerm_resource_group.db_rg.name
}

resource "azurerm_virtual_network_gateway" "vpn-gateway" {
  name = "vpn-gateway"
  location = azurerm_resource_group.db_rg.location
  resource_group_name = azurerm_resource_group.db_rg.name

  type = "Vpn"
  vpn_type = "RouteBased" 
  sku = "VpnGw2"
  generation = "Generation2"

  ip_configuration {
    public_ip_address_id = azurerm_public_ip.public_ip.id
    subnet_id = azurerm_subnet.VPN-gateway-subnet.id
    private_ip_address_allocation = "Dynamic"
  }

  active_active = false
  enable_bgp = false
  vpn_client_configuration {
    address_space = [ "10.2.0.0/24" ]
  }
}

resource "azurerm_local_network_gateway" "local_network_gateway" {
  location = azurerm_resource_group.db_rg.location
  name = "local-network-gateway"
  resource_group_name = azurerm_resource_group.db_rg.name
  gateway_address = google_compute_ha_vpn_gateway.ha_gateway.vpn_interfaces[0].ip_address
  bgp_settings {
    asn = 64513
    bgp_peering_address = google_compute_router_peer.vpn_router_peer.ip_address
  }
  address_space = [ "169.254.1.0/24" ]
}

resource "azurerm_virtual_network_gateway_connection" "vpn_connection" {
  location = azurerm_resource_group.db_rg.location
  name = "azure-gcp-vpn-connection"
  resource_group_name = azurerm_resource_group.db_rg.name

  type = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.vpn-gateway.id
  enable_bgp = false
  local_azure_ip_address_enabled = false
  local_network_gateway_id = azurerm_local_network_gateway.local_network_gateway.id

  shared_key = var.vpn_secret
}