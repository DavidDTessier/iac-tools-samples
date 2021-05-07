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