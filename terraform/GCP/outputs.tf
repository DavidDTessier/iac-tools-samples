output "webserver_ip" {
    value = google_compute_instance.web-vm.network_interface.0.access_config.0.nat_ip
}