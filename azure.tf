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
  address_space       = ["10.0.3.0/24"]
}

resource "azurerm_virtual_network_gateway_connection" "vpn_connection" {
  name                       = "az-gcp-connection"
  resource_group_name        = azurerm_resource_group.db_rg.name
  location                   = azurerm_resource_group.db_rg.location
  virtual_network_gateway_id = azurerm_virtual_network_gateway.db_vn_gateway.id
  local_network_gateway_id   = azurerm_local_network_gateway.vpn_lng.id
  shared_key                 = var.vpn_secret
  type                       = "IPsec"
  connection_protocol        = "IKEv2"
  dpd_timeout_seconds        = 45
}

# -----------------------------
# Database server configuration
# -----------------------------

resource "azurerm_public_ip" "db_server_ip" {
  name                = "db-server-ip"
  resource_group_name = azurerm_resource_group.db_rg.name
  location            = azurerm_resource_group.db_rg.location
  allocation_method   = "Dynamic"
}

resource "azurerm_subnet" "db_subnet" {
  address_prefixes     = ["10.128.1.0/24"]
  name                 = "subnetwork"
  resource_group_name  = azurerm_resource_group.db_rg.name
  virtual_network_name = azurerm_virtual_network.db_virtual_network.name
}

resource "azurerm_network_security_group" "db_nsg" {
  name                = "db-nsg"
  resource_group_name = azurerm_resource_group.db_rg.name
  location            = azurerm_resource_group.db_rg.location
  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "db_server_nic" {
  name                = "db-server-nic"
  resource_group_name = azurerm_resource_group.db_rg.name
  location            = azurerm_resource_group.db_rg.location

  ip_configuration {
    name                          = "db-server-ipconfig"
    subnet_id                     = azurerm_subnet.db_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.db_server_ip.id
  }
}

resource "azurerm_network_interface_security_group_association" "db_nic_nsg_assoc" {
  network_interface_id      = azurerm_network_interface.db_server_nic.id
  network_security_group_id = azurerm_network_security_group.db_nsg.id
}

resource "azurerm_linux_virtual_machine" "db_vm" {
  name                  = "db-vm"
  resource_group_name   = azurerm_resource_group.db_rg.name
  location              = azurerm_resource_group.db_rg.location
  network_interface_ids = [azurerm_network_interface.db_server_nic.id]
  size                  = "Standard_DS1_v2"
  os_disk {
    name                 = "myOsDisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  computer_name  = "db-server"
  admin_username = "jhone"

  admin_ssh_key {
    username   = "jhone"
    public_key = file("./id_rsa.pub")
  }
}

output "db_public_ip" {
  value = azurerm_linux_virtual_machine.db_vm.public_ip_address
}
output "db_private_ip" {
  value = azurerm_linux_virtual_machine.db_vm.private_ip_address
}