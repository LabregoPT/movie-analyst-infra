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
  #target_tags = [ "allow-health-check" ]
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_instance_group_manager" "backend_servers" {
  base_instance_name = "server"
  name               = "backend-severs-managed-group"
  zone               = "us-west2-a"
  target_size        = 2
  version {
    instance_template = google_compute_instance_template.servers_template.self_link
    name = "primary"
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
  machine_type = "e2-micro"
  tags = [ "allow-health-check" ]
  disk {
    source_image = "ubuntu-os-cloud/ubuntu-2004-lts"
  }
  network_interface {
    network    = google_compute_network.vpc_network.self_link
    subnetwork = google_compute_subnetwork.subnetwork.self_link
    access_config {
    }
  }
  metadata = {
    "enable-oslogin" = "FALSE"
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
    name = "lb-target-http-proxy"
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

output "lb_public_ip" {
  value = google_compute_global_address.lb_ip.address
}
