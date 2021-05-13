terraform {
  required_version = ">= 0.12, <=0.15"
  required_providers {
      google = {
          version = "~> 3.0",
          source="hashicorp/google"
      }
  }
}

provider "google" {
    project = var.project_id
    region = var.region
    credentials = file("credentials.json")
}

variable "project_id" {
    description = "The GCP Project"
    type = string
}

variable "region" {
    description = "The region to deploy the webserver in."
    type = string
    default = "northamerica-northeast1"
}

variable "zone" {
    description = "The zone associated to the region to provision the web server in"
    type = string
    default = "northamerica-northeast1-a"
}

variable "webservername" {
    description = "The name to associate with the webserver"
    type = string
}

variable "machine_type" {
    description = "The machine type that will be used to create the vm."
    type = string
    default = "f1-micro"
}


data "google_compute_image" "debian" {
    family = "ubuntu-1804-lts"
    project = "ubuntu-os-cloud"
}

data "template_file" "nginx" {
  template = "${file("${path.module}/template/install_nginx.tpl")}"

  vars = {
    ufw_allow_nginx = "Nginx HTTP"
  }
}

# Create the GCP Compute Engine Instance that will be our webserver
resource "google_compute_instance" "web-vm" {
    name = var.webservername
    machine_type = var.machine_type
    zone = var.zone
    tags = ["http-server"]
    labels = {
        "environment" = "test"
        "team"        = "devops"
        "application" = "webserver"
    }

    boot_disk {
        initialize_params {
            image = data.google_compute_image.debian.self_link
        }
    }

    # every project comes standard with a "default" network...recommended to remove in a prodcution environment and create a secure one.
    network_interface {
        network = "default"
        access_config {
            // Ephemeral IP
        }
    }

    metadata_startup_script = data.template_file.nginx.rendered
}

output "webserver_ip" {
    value = google_compute_instance.web-vm.network_interface.0.access_config.0.nat_ip
}