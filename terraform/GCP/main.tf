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