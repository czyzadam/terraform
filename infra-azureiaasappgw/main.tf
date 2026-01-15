terraform {
  required_version = ">= 1.1"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.58"
    }
  }

  # Single backend and single key (workspaces create separate blobs automatically)
  backend "azurerm" {
    resource_group_name  = "A838492_adamczyz"
    storage_account_name = "terraformbackendadam"
    container_name       = "tfstate"
    key                  = "infra-azureiaasappgw.tfstate"
  }
}

provider "azurerm" {
  features {}
}

# -----------------------------
# Variables (kept here for clarity; also declared in variables.tf)
# -----------------------------
variable "env" {}
variable "azure_subscription" {}
variable "location" {}
variable "application_gateway_details" {
  default = {}
}

# -----------------------------
# Resource group and network prerequisites
# -----------------------------
resource "azurerm_resource_group" "rg" {
  name     = "${var.env}-appgw-rg"
  location = var.location
}
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.env}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "${var.env}-appgw-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "pip" {
  name                = "${var.env}-appgw-pip"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# -----------------------------
# Locals derived from application_gateway_details
# We mirror prod structure but simplify: HTTP only, Standard_v2
# Expecting a single entry (e.g., shared01). If multiple provided, first is used.
# -----------------------------

locals {
  # A safe default that mirrors your prod structure but simplified for the lab
  default_appgw_details = {
    sku                         = "Standard_v2"
    autoscale_min_capacity      = 1
    autoscale_max_capacity      = 2
    frontend_ports              = { "80" = {} } # use string key for safety
    backends                    = {}
    listeners                   = {}
    basic_routing_rules         = {}
    path_based_routing_rules    = {}
    frontend_private_ip_address = null
    waf_enabled                 = false
    enable_http2                = false
  }

  # Pick the specific key you use in tfvars (shared01), or fall back to default
  appgw_details = try(var.application_gateway_details.shared01, local.default_appgw_details)

  # Derived maps used by dynamic blocks
  frontend_ports_map = try(local.appgw_details.frontend_ports, { "80" = {} })
  backends_map       = try(local.appgw_details.backends, {})
  listeners_map      = try(local.appgw_details.listeners, {})
  basic_rules_map    = try(local.appgw_details.basic_routing_rules, {})
  path_rules_map     = try(local.appgw_details.path_based_routing_rules, {})
}


# -----------------------------
# Application Gateway (no module)
# -----------------------------
resource "azurerm_application_gateway" "appgw" {
  name                = "${var.env}-appgw"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  sku {
    name = "Standard_v2"
    tier = "Standard_v2"
  }

 ssl_policy {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20220101"
  }
  autoscale_configuration {
    min_capacity = try(local.appgw_details.autoscale_min_capacity, 1)
    max_capacity = try(local.appgw_details.autoscale_max_capacity, 2)
  }

  gateway_ip_configuration {
    name      = "appgw-ip-config"
    subnet_id = azurerm_subnet.subnet.id
  }

  frontend_ip_configuration {
    name                 = "appgw-frontend-ip"
    public_ip_address_id = azurerm_public_ip.pip.id
  }

  # Frontend ports from map (keys are port numbers like 80)
  dynamic "frontend_port" {
    for_each = local.frontend_ports_map
    content {
      name = "port-${frontend_port.key}"
      port = tonumber(frontend_port.key)
    }
  }


  # Backend pools for each backend entry
  dynamic "backend_address_pool" {
    for_each = local.backends_map
    content {
      name = backend_address_pool.key

      #  Provide addresses directly as attributes
      ip_addresses = try(backend_address_pool.value.ip_addresses, [])
      fqdns        = try(backend_address_pool.value.fqdns, [])
    }
  }

  # HTTP settings per backend
  dynamic "backend_http_settings" {
    for_each = local.backends_map
    content {
      name                                = "${backend_http_settings.key}-settings"
      cookie_based_affinity               = try(backend_http_settings.value.cookie_based_affinity, "Disabled")
      port                                = try(backend_http_settings.value.port, 80)
      protocol                            = try(backend_http_settings.value.protocol, "Http")
      request_timeout                     = try(backend_http_settings.value.request_timeout, 30)
      pick_host_name_from_backend_address = try(backend_http_settings.value.pick_host_name_from_backend_address, true)
      host_name                           = try(backend_http_settings.value.host_name, "") != "" ? backend_http_settings.value.host_name : null
    }
  }

  # Listeners per listeners_map (HTTP only). We bind by port number in each listener.
  dynamic "http_listener" {
    for_each = local.listeners_map
    content {
      name                           = http_listener.key
      frontend_ip_configuration_name = "appgw-frontend-ip"
      frontend_port_name             = "port-${try(http_listener.value.port, 80)}"
      protocol                       = "Http"
      # Hostname is optional for HTTP; omit for portability
      host_name = length(try(http_listener.value.host_names, [])) > 0 ? http_listener.value.host_names[0] : null
    }
  }

  # Basic routing rules mapping listener -> backend
  dynamic "request_routing_rule" {
    for_each = local.basic_rules_map
    content {
      name                       = request_routing_rule.key
      rule_type                  = "Basic"
      http_listener_name         = request_routing_rule.value.listener
      backend_address_pool_name  = request_routing_rule.value.backend
      backend_http_settings_name = "${request_routing_rule.value.backend}-settings"
      priority                   = try(request_routing_rule.value.priority, null)
    }
  }

  # Path-based rules: create a url_path_map and a routing rule of type PathBasedRouting
  dynamic "url_path_map" {
    for_each = local.path_rules_map
    content {
      name                               = url_path_map.key
      default_backend_address_pool_name  = try(url_path_map.value.default_backend, null)
      default_backend_http_settings_name = try(url_path_map.value.default_backend, null) != null ? "${url_path_map.value.default_backend}-settings" : null

      dynamic "path_rule" {
        for_each = try(url_path_map.value.paths_rules, {})
        content {
          name                       = path_rule.key
          paths                      = try(path_rule.value.paths, ["/"])
          backend_address_pool_name  = path_rule.value.backend
          backend_http_settings_name = "${path_rule.value.backend}-settings"
        }
      }
    }
  }

  # Create companion request_routing_rule entries pointing at url_path_map
  dynamic "request_routing_rule" {
    for_each = local.path_rules_map
    content {
      name               = "${request_routing_rule.key}-rule"
      rule_type          = "PathBasedRouting"
      http_listener_name = try(request_routing_rule.value.listener, "app1-80")
      url_path_map_name  = request_routing_rule.key
      priority           = try(request_routing_rule.value.priority, null)
    }
  }
}
