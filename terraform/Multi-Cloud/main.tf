terraform {
  required_version = ">= 0.12, <=0.15"
  required_providers {
      aws = {
          version = "~> 3.0",
          source="hashicorp/aws"
      }
      google = {
          version = "~> 3.0",
          source="hashicorp/google"
      }
  }
}


# GCP Provider
provider "google" {
    project = "dtessier-hero-path-302118"
    region = "northamerica-northeast1"
    credentials = file("credentials.json")
}

# AWS Provider
provider "aws" {
    region = "ca-central-1"
}

# Generate a random vm name
resource "random_string" "bucketname" {
  length  = 8
  upper   = false
  number  = false
  lower   = true
  special = false
}

# AWS Storage Bucket
resource "aws_s3_bucket" "bucket" {
  bucket = "demoiac${random_string.bucketname.result}"
  acl    = "private"
}

resource "google_storage_bucket" "bucket" {
  name          = "demoiac${random_string.bucketname.result}"
  location      = "northamerica-northeast1"
  force_destroy = true
}