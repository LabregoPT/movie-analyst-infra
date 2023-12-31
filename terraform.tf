terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
    google = {
      source  = "hashicorp/google"
      version = "4.76.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.67.0"
    }
  }
  cloud {
    organization = "LabregoPT"
    workspaces {
      name = "Movie-Analyst-Workspace"
    }
  }
  required_version = ">= 1.2.0"
}

provider "aws" {
  region     = "us-west-2"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_access_key
}

provider "google" {
  project     = "boxwood-faculty-392406"
  credentials = file(var.gcp_credentials_file)
  region      = "us-west2"
}

provider "azurerm" {
  client_id       = "f9ae7ab3-61e5-406e-aa53-b5b7b5d3b2d2"
  client_secret   = var.azure_secret_key
  tenant_id       = "e994072b-523e-4bfe-86e2-442c5e10b244"
  subscription_id = "c1ac00ec-44b7-4df4-ba3c-9c9d15421774"
  features {
  }
}

resource "local_file" "outputs" {
  filename = "./infra-output.json"
  content  = "{  \"backend_lb_public_ip\": {    \"value\": \"${google_compute_global_address.lb_ip.address}\"  },  \"db_private_ip\": {    \"value\": \"${azurerm_linux_virtual_machine.db_vm.private_ip_address}\"  },  \"db_public_ip\": {    \"value\": \"${azurerm_linux_virtual_machine.db_vm.public_ip_address}\"  },  \"frontend_lb_public_ip\": {    \"value\": \"${aws_lb.load_balancer.dns_name}\"  }}"
}