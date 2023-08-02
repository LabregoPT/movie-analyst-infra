##--------------------------

## Terraform configuration file for GCP side of infrastructure

##---------------------------

#VPC Network
resource "google_compute_network" "vpc_network" {
  name                    = "terraform-created-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnetwork" {
  name          = "subnet"
  ip_cidr_range = "10.0.3.0/24"
  region        = "us-west2"
  network       = google_compute_network.vpc_network.id
}

resource "google_compute_firewall" "default_firewall" {
  name    = "vpc-network-firewall"
  network = google_compute_network.vpc_network.self_link
  allow {
    protocol = "tcp"
    ports = [
      "8080", "22"
    ]
  }
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_instance_group_manager" "backend_servers" {
  base_instance_name = "server"
  name               = "backend-severs-managed-group"
  zone               = "us-west2-a"
  target_size        = 2
  version {
    instance_template = google_compute_instance_template.servers_template.self_link
    name              = "primary"
  }
  named_port {
    name = "http"
    port = 8080
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_instance_template" "servers_template" {
  name         = "servers-template"
  machine_type = "e2-micro"
  tags         = ["allow-health-check"]
  disk {
    source_image = "ubuntu-os-cloud/ubuntu-2004-lts"
  }
  network_interface {
    network    = google_compute_network.vpc_network.self_link
    subnetwork = google_compute_subnetwork.subnetwork.self_link
    access_config {
    }
  }
  labels = {
    "layer" = "back"
  }
  metadata = {
    "enable-oslogin" = "FALSE"
  }
  lifecycle {
    create_before_destroy = true
  }
}

##Load balancer Configuration
##Most of the code was taken from https://cloud.google.com/load-balancing/docs/https/ext-http-lb-tf-module-examples#with_mig_backend_and_custom_headers
resource "google_compute_global_address" "lb_ip" {
  name = "static-lb-ip"
}

resource "google_compute_global_forwarding_rule" "lb_forwarding_rule" {
  name                  = "lb-forwarding-rule"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL"
  port_range            = "8080"
  target                = google_compute_target_http_proxy.lb_target_proxy.id
  ip_address            = google_compute_global_address.lb_ip.id
}

resource "google_compute_target_http_proxy" "lb_target_proxy" {
  name    = "lb-target-http-proxy"
  url_map = google_compute_url_map.lb_url_map.id
}

resource "google_compute_url_map" "lb_url_map" {
  name            = "lb-url-map"
  default_service = google_compute_backend_service.lb_backend_service.id
}

resource "google_compute_backend_service" "lb_backend_service" {
  name                  = "lb-backend-service"
  protocol              = "HTTP"
  port_name             = "http"
  load_balancing_scheme = "EXTERNAL"
  health_checks         = [google_compute_health_check.lb_hc.id]

  backend {
    group          = google_compute_instance_group_manager.backend_servers.instance_group
    balancing_mode = "UTILIZATION"
  }
}

resource "google_compute_health_check" "lb_hc" {
  name = "lb-health-check"
  http_health_check {
    port_specification = "USE_SERVING_PORT"
  }
}

output "backend_lb_public_ip" {
  value = google_compute_global_address.lb_ip.address
}

## VPN Network config
resource "google_compute_address" "gcp_vpn_ip" {
  name = "gcp-vpn-ip"
}

resource "google_compute_vpn_gateway" "az_gcp_vpn_gateway" {
  name    = "az-gcp-vpn"
  network = google_compute_network.vpc_network.name
}

resource "google_compute_forwarding_rule" "fr_esp" {
  name   = "az-gcp-vpn-rule-esp"
  target = google_compute_vpn_gateway.az_gcp_vpn_gateway.id
}
resource "google_compute_forwarding_rule" "fr_udp500" {
  name   = "az-gcp-vpn-rule-udp4500"
  target = google_compute_vpn_gateway.az_gcp_vpn_gateway.id
}
resource "google_compute_forwarding_rule" "fr_udp4500" {
  name   = "az-gcp-vpn-rule-udp500"
  target = google_compute_vpn_gateway.az_gcp_vpn_gateway.id
}

resource "google_compute_vpn_tunnel" "gcp_vpn_tunnel_1" {
  name                            = "gcp-vpn-tunnel-1"
  shared_secret                   = var.vpn_secret
  local_traffic_selector          = ["0.0.0.0/0"]
  peer_external_gateway_interface = 0
  remote_traffic_selector         = ["0.0.0.0/0"]
  target_vpn_gateway              = google_compute_vpn_gateway.az_gcp_vpn_gateway.id
  vpn_gateway_interface           = 0
  peer_ip                         = azurerm_public_ip.ip.ip_address
}
