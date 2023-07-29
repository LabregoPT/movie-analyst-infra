##--------------------------

## Terraform configuration file for GCP side of infrastructure

##---------------------------

#VPC Network
resource "google_compute_network" "vpc_network" {
    name = "terraform-created-network"
    auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnetwork" {
    name = "subnet"
    ip_cidr_range = "10.0.3.0/24"
    region = "us-west2"
    network = google_compute_network.vpc_network.id
}

resource "google_compute_firewall" "default_firewall" {
    name = "vpc-network-firewall"
    network = google_compute_network.vpc_network.self_link
    allow {
        protocol = "tcp"
        ports = [
            "8080", "22"
        ]
    }
    source_ranges = [ "0.0.0.0/0" ]
}