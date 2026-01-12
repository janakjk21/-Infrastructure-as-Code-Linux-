
terraform{
    required_providers{
        azurerm={source="hashicorp/azurerm",version="~>3.0"}
       
    }
}

provider "azurerm" {
 features {
    resource_group {
      # This is the magic line
      prevent_deletion_if_contains_resources = false
    }
  }
}

resource "azurerm_resource_group" "new_resource"{
name ="terraform_rg_v2"
location = "ukwest"   
}

# 3. Create Network Security Group (NSG) with Rules

resource "azurerm_network_security_group"  "nsg" {
    name                  = "terraform-nsg"
    location              = azurerm_resource_group.new_resource.location
    resource_group_name   = azurerm_resource_group.new_resource.name


# rule to allow Ssh port 22

    security_rule{
    name = "Allow_ssh"
    priority = 100
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "22"
    source_address_prefix = "*"
    destination_address_prefix = "*"
   


}
# rule to allow HTTP port 80
    security_rule{
    name = "Allow_http"
    priority = 200
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "80"
    source_address_prefix = "*"
    destination_address_prefix = "*"
    }



}
 #create virtual network 
resource "azurerm_virtual_network" "vnet"{
    name ="terraform_vnet"
    location= azurerm_resource_group.new_resource.location
    resource_group_name= azurerm_resource_group.new_resource.name
   address_space       = ["10.0.0.0/16"]
}

# create subnet
resource "azurerm_subnet" "subnet"{
    name ="terraform_subnet"
    resource_group_name= azurerm_resource_group.new_resource.name
    virtual_network_name= azurerm_virtual_network.vnet.name
    address_prefixes     = ["10.0.1.0/24"]
}

# associate nsg to subnet
resource "azurerm_subnet_network_security_group_association" "nsg_association"{
    subnet_id = azurerm_subnet.subnet.id
    network_security_group_id = azurerm_network_security_group.nsg.id
}


# creating a public ip 

resource "azurerm_public_ip" "public_ip" {
    name               = "terraform_public_ip"
    location            = azurerm_resource_group.new_resource.location
    resource_group_name = azurerm_resource_group.new_resource.name
    allocation_method   = "Static"
    sku                = "Standard"
}

#creating virtula network interface 
resource "azurerm_network_interface" "nic"{
    name = "terraform_nic"
    location = azurerm_resource_group.new_resource.location
    resource_group_name = azurerm_resource_group.new_resource.name
    ip_configuration{
        name = "internal"
    subnet_id = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.public_ip.id
    }
}

#9 create sssh key pair 
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

#10 create a linux virtual machine
resource "azurerm_linux_virtual_machine" "vm" {
    name = "terraform_vm"
    resource_group_name = azurerm_resource_group.new_resource.name
    location = azurerm_resource_group.new_resource.location
    size = "Standard_B1s"
    admin_username = "azure_user"
    network_interface_ids = [azurerm_network_interface.nic.id]
    computer_name = "terraformvm"

    #cloud init to install apache server
    admin_ssh_key{
        username = "azure_user"
        public_key = tls_private_key.ssh_key.public_key_openssh
    }
    os_disk{
        caching = "ReadWrite"
        storage_account_type = "Standard_LRS"
    }
    source_image_reference{
        publisher = "Canonical"
        offer = "UbuntuServer"
        sku = "18.04-LTS"
        version = "latest"
    }
}

# output the public ip address of the vm
output "vm_public_ip" {
    value = azurerm_public_ip.public_ip.ip_address
}
output "ssh_private_key" {
    value = tls_private_key.ssh_key.private_key_pem
    sensitive = true
}