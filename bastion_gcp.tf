# ----------------------------------------------------------
#
# GCP Bastion Host Configuration
#
# ----------------------------------------------------------

resource "google_compute_instance" "bastion_gcp" {
  name         = "bastion"
  machine_type = "e2-micro"
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
    }
  }
  zone = "us-west2-a"
  network_interface {
    network    = google_compute_network.vpc_network.self_link
    subnetwork = google_compute_subnetwork.subnetwork.self_link
    access_config {
    }
  }
  metadata = {
    "enable-oslogin" = "FALSE"
  }
  allow_stopping_for_update = true
}

output "gcp_bastion_ip" {
  value = google_compute_instance.bastion_gcp.network_interface[0].access_config[0].nat_ip
}
