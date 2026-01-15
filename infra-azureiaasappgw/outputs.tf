output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "application_gateway_name" {
  value = azurerm_application_gateway.appgw.name
}

output "public_ip_address" {
  value = azurerm_public_ip.pip.ip_address
}
