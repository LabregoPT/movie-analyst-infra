##_--------------------------------------------

## Azure Cloud Configuration files

##---------------------------------------------

## Network configurations

resource "azurerm_resource_group" "db_rg" {
  name     = "database-resource-group"
  location = "East US"
}

resource "azurerm_virtual_network" "db_virtual_network" {
  address_space       = ["10.128.0.0/9"]
  location            = azurerm_resource_group.db_rg.location
  name                = "db-vnet"
  resource_group_name = azurerm_resource_group.db_rg.name
}

resource "azurerm_subnet" "gateway_subnet" {
  address_prefixes     = ["10.128.0.0/24"]
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.db_rg.name
  virtual_network_name = azurerm_virtual_network.db_virtual_network.name

}

resource "azurerm_public_ip" "ip" {
  allocation_method   = "Static"
  location            = azurerm_resource_group.db_rg.location
  name                = "vpn-test"
  resource_group_name = azurerm_resource_group.db_rg.name
  sku                 = "Standard"
}

resource "azurerm_virtual_network_gateway" "db_vn_gateway" {
  name                       = "db-vpn-gateway"
  type                       = "Vpn"
  location                   = azurerm_resource_group.db_rg.location
  resource_group_name        = azurerm_resource_group.db_rg.name
  sku                        = "VpnGw1"
  active_active              = false
  enable_bgp                 = false
  generation                 = "Generation1"
  private_ip_address_enabled = false
  ip_configuration {
    name                 = "default"
    subnet_id            = azurerm_subnet.gateway_subnet.id
    public_ip_address_id = azurerm_public_ip.ip.id
  }
}

resource "azurerm_local_network_gateway" "vpn_lng" {
  location            = azurerm_resource_group.db_rg.location
  name                = "vpn-lng"
  resource_group_name = azurerm_resource_group.db_rg.name
  gateway_address     = google_compute_address.gcp_vpn_ip.address
  address_space = [ "10.0.3.0/24" ]
}

resource "azurerm_virtual_network_gateway_connection" "vpn_connection" {
  name = "az-gcp-connection"
  resource_group_name = azurerm_resource_group.db_rg.name
  location            = azurerm_resource_group.db_rg.location
  virtual_network_gateway_id = azurerm_virtual_network_gateway.db_vn_gateway.id
  local_network_gateway_id = azurerm_local_network_gateway.vpn_lng.id
  shared_key = var.vpn_secret
  type = "IPsec"
  connection_protocol = "IKEv2"
  dpd_timeout_seconds = 45
}