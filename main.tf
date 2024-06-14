resource "azurerm_resource_group" "rg1" {
  name     = "rg3"
  location = "West us "
}

resource "azurerm_virtual_network" "vnet" {
  name                = "jaivnet"
  resource_group_name = azurerm_resource_group.rg1.name
  location            = azurerm_resource_group.rg1.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "snet1" {
  name                 = "frontend"
  resource_group_name  = azurerm_resource_group.rg1.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}
resource "azurerm_subnet" "snet2" {
  name                 = "backend"
  resource_group_name  = azurerm_resource_group.rg1.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}
resource "azurerm_subnet" "appgate" {
  name                 = "appgatesubnet"
  resource_group_name  = azurerm_resource_group.rg1.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.3.0/24"]
}
resource "azurerm_subnet" "bastionsub" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.rg1.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.0.0/27"]
}

resource "azurerm_public_ip" "bastionpip" {
  name                = "bastionpip"
  location            = azurerm_resource_group.rg1.location
  resource_group_name = azurerm_resource_group.rg1.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "host" {
  name                = "host"
  location            = azurerm_resource_group.rg1.location
  resource_group_name = azurerm_resource_group.rg1.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastionsub.id
    public_ip_address_id = azurerm_public_ip.bastionpip.id
  }
}
resource "azurerm_network_interface" "nic1" {
  name                = "pk-nic"
  location            = azurerm_resource_group.rg1.location
  resource_group_name = azurerm_resource_group.rg1.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.snet1.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "vm1" {
  name                = "pkvm-machine"
  resource_group_name = azurerm_resource_group.rg1.name
  location            = azurerm_resource_group.rg1.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  admin_password = "GDTF^&b%J"
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.nic1.id,
  ]

  

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}
resource "azurerm_network_interface" "nic2" {
  name                = "mk-nic"
  location            = azurerm_resource_group.rg1.location
  resource_group_name = azurerm_resource_group.rg1.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.snet2.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "vm2" {
  name                = "mk-machine"
  resource_group_name = azurerm_resource_group.rg1.name
  location            = azurerm_resource_group.rg1.location
  size                = "Standard_F2"
  admin_username      = "adminuser2"
  admin_password = "GEghm$^GKJS"
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.nic2.id,
  ]

  
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

resource "azurerm_public_ip" "gatepip" {
  name                = "appgate-pip"
  resource_group_name = azurerm_resource_group.rg1.name
  location            = azurerm_resource_group.rg1.location
  allocation_method   = "Static"
   sku                 = "Standard"
}


# since these variables are re-used - a locals block makes this more maintainable
# locals {
#   backend_address_pool_name      = "${azurerm_virtual_network.example.name}-beap"
#   frontend_port_name             = "${azurerm_virtual_network.example.name}-feport"
#   frontend_ip_configuration_name = "${azurerm_virtual_network.example.name}-feip"
#   http_setting_name              = "${azurerm_virtual_network.example.name}-be-htst"
#   listener_name                  = "${azurerm_virtual_network.example.name}-httplstn"
#   request_routing_rule_name      = "${azurerm_virtual_network.example.name}-rqrt"
#   redirect_configuration_name    = "${azurerm_virtual_network.example.name}-rdrcfg"
# }

resource "azurerm_application_gateway" "aapgate1" {
  name                = "appgateway1"
  resource_group_name = azurerm_resource_group.rg1.name
  location            = azurerm_resource_group.rg1.location

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "my-gateway-ip-configuration"
    subnet_id = azurerm_subnet.appgate.id
  }

  frontend_port {
    name = "frontend-port"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "frontend-ipconfiguration"
    public_ip_address_id = azurerm_public_ip.gatepip.id
  }

  backend_address_pool {
    name = "backend-addresspool"
  }

  backend_http_settings {
    name                  = "httpsetting"
    cookie_based_affinity = "Disabled"
    path                  = "/path1/"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  http_listener {
    name                           = "listener"
    frontend_ip_configuration_name = "frontend-ipconfiguration"
    frontend_port_name             = "frontend-port"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "request-routingrule"
    priority                   = 9
    rule_type                  = "Basic"
    http_listener_name         = "listener"
    backend_address_pool_name  = "backend-addresspool"
    backend_http_settings_name = "httpsetting"
  }
  
}
resource "azurerm_network_interface_application_gateway_backend_address_pool_association" "virtual1" {
  network_interface_id    = azurerm_network_interface.nic1.id
  ip_configuration_name   = "internal"
  backend_address_pool_id = tolist(azurerm_application_gateway.aapgate1.backend_address_pool).0.id
}
resource "azurerm_network_interface_application_gateway_backend_address_pool_association" "virtual2" {
  network_interface_id    = azurerm_network_interface.nic2.id
  ip_configuration_name   = "internal"
  backend_address_pool_id = tolist(azurerm_application_gateway.aapgate1.backend_address_pool).0.id
}