env                = "lab-nonprod-we"
azure_subscription = "lab-subscription"
location           = "West Europe"

application_gateway_details = {
  shared01 = {
    sku                    = "Standard_v2"
    autoscale_min_capacity = 1
    autoscale_max_capacity = 2
    subnet                 = "LabNetworkIaaS-LAB_IaaS-we/LAB-IAAS-SHARED-NONPROD-we/LAB-IAAS-SHARED-NONPROD-APPGW-NONPROD-we"
    waf_enabled            = false
    enable_http2           = false

    frontend_ports = {
      80 = {}
    }

    frontend_private_ip_address = null

    backends = {
      app1-80 = {
        fqdns                               = []
        ip_addresses                        = ["10.0.12.10", "10.0.12.11"]
        cookie_based_affinity               = "Disabled"
        port                                = 80
        path                                = "/"
        protocol                            = "Http"
        request_timeout                     = 30
        host_name_override                  = true
        pick_host_name_from_backend_address = true
        host_name                           = ""
        probe_host_name_override            = false
        probe_host_name_override_hostname   = ""
      }

    }

    listeners = {
      app1-80 = {
        host_names            = ["app1.lab.example.com"]
        public                = true
        port                  = 80
        protocol              = "Http"
        ssl_certificate_name  = ""
        custom_error_page_url = ""
        firewall_policy_id    = ""
      }

    }

    basic_routing_rules = {
      app1-80-rule = {
        listener = "app1-80"
        backend  = "app1-80"
        priority = 1
      }
    }


    redirect_routing_ruless   = {}
    imported_ssl_certificates = {}
  }
}
