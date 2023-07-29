terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
    google = {
      source  = "hashicorp/google"
      version = "4.51.0"
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
  project = "boxwood-faculty-392406"
  credentials = file(var.gcp_credentials_file)
}
