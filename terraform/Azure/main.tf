terraform {
  required_version = ">= 0.12, <=0.15"
  required_providers {
      azurerm = {
          version = "=2.46.1",
          source="hashicorp/azurerm"
      }
  }
}

# Configuring the Provider
provider "azurerm" {
    features {}

    subscription_id = "00000000-0000-0000-0000-000000000000"
    client_id       = "00000000-0000-0000-0000-000000000000"
    client_secret   = var.client_secret
    tenant_id       = "00000000-0000-0000-0000-000000000000"

}

locals {
    resource_prefix = "demo-webserver"
    custom_data = <<CUSTOM_DATA
        #! /bin/bash
        sudo apt-get update
        sudo apt-get install -y apache2
        sudo systemctl start apache2
        sudo systemctl enable apache2
        echo "<h1>Azure Linux VM with Web Server</h1>" | sudo tee /var/www/html/index.html
    CUSTOM_DATA
}

# Generate random password
resource "random_password" "web-vm-password" {
  length           = 16
  min_upper        = 2
  min_lower        = 2
  min_special      = 2
  number           = true
  special          = true
  override_special = "!@#$%&"
}

# Generate a random vm name
resource "random_string" "web-vm-name" {
  length  = 8
  upper   = false
  number  = false
  lower   = true
  special = false
}

# Create a resource group for network
resource "azurerm_resource_group" "network-rg" {
  name     = "${local.resource_prefix}-${random_string.web-vm-name.result}-rg"
  location = "eastus"
}

# Create the network VNET
resource "azurerm_virtual_network" "network-vnet" {
  name                = "${local.resource_prefix}-${random_string.web-vm-name.result}-vnet"
  address_space       = ["10.0.0.0/16"]
  resource_group_name = azurerm_resource_group.network-rg.name
  location            = azurerm_resource_group.network-rg.location
}

# Create a subnet for Network
resource "azurerm_subnet" "network-subnet" {
  name                 = "${local.resource_prefix}-${random_string.web-vm-name.result}-subnet"
  address_prefixes       = ["10.0.2.0/24"]
  virtual_network_name = azurerm_virtual_network.network-vnet.name
  resource_group_name  = azurerm_resource_group.network-rg.name
}

# Create Security Group to access web
resource "azurerm_network_security_group" "web-vm-nsg" {
  depends_on=[azurerm_resource_group.network-rg]
  name                = "${local.resource_prefix}-${random_string.web-vm-name.result}-nsg"
  location            = azurerm_resource_group.network-rg.location
  resource_group_name = azurerm_resource_group.network-rg.name

  security_rule {
    name                       = "AllowWEB"
    description                = "Allow web"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

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


# Associate the web NSG with the subnet
resource "azurerm_subnet_network_security_group_association" "web-vm-nsg-association" {
  depends_on=[azurerm_resource_group.network-rg]

  subnet_id                 = azurerm_subnet.network-subnet.id
  network_security_group_id = azurerm_network_security_group.web-vm-nsg.id
}

# Get a Static Public IP
resource "azurerm_public_ip" "web-vm-ip" {
  depends_on=[azurerm_resource_group.network-rg]

  name                = "web-${random_string.web-vm-name.result}-ip"
  location            = azurerm_resource_group.network-rg.location
  resource_group_name = azurerm_resource_group.network-rg.name
  allocation_method   = "Static"

}

# Create Network Card for web VM
resource "azurerm_network_interface" "web-private-nic" {
  depends_on=[azurerm_resource_group.network-rg]

  name                = "web-${random_string.web-vm-name.result}-nic"
  location            = azurerm_resource_group.network-rg.location
  resource_group_name = azurerm_resource_group.network-rg.name
  
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.network-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.web-vm-ip.id
  }
}

# Create Linux VM with web server
resource "azurerm_linux_virtual_machine" "web-vm" {
  depends_on=[azurerm_network_interface.web-private-nic]

  location              = azurerm_resource_group.network-rg.location
  resource_group_name   = azurerm_resource_group.network-rg.name
  name                  = "web-${random_string.web-vm-name.result}-vm"
  network_interface_ids = [azurerm_network_interface.web-private-nic.id]
  admin_username = "adminUser"
  size = "Standard_B2s"
  computer_name  = "web-${random_string.web-vm-name.result}-vm"
  admin_password = random_password.web-vm-password.result

  source_image_reference {
    offer     = "UbuntuServer"
    publisher = "Canonical"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_disk {
    caching           = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  disable_password_authentication = false

}

resource "azurerm_virtual_machine_extension" "web-vm-extension" {
  name = "web-${random_string.web-vm-name.result}-vm-ext"
  virtual_machine_id = azurerm_linux_virtual_machine.web-vm.id
  publisher = "Microsoft.Azure.Extensions"
  type = "CustomScript"
  type_handler_version ="2.0"

  settings = <<SETTINGS
    {
      "script" : "${base64encode(local.custom_data)}" 
    }
    SETTINGS
 }

output "public_ip" {
   value       = azurerm_public_ip.web-vm-ip.ip_address
   description = "This is the asigned public ip to our VM"
}