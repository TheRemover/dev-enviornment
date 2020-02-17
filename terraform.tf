variable "gcp_account_file" {
  type        = string
  description = "GCP account file location"
}

variable "gcp_project_id" {
  type        = string
  description = "GCP project ID"
}

variable "gcp_zone" {
  type        = string
  description = "GCP zone"
}

resource "random_id" "instance_id" {
 byte_length = 8
}

provider "google" {
  credentials = var.gcp_account_file
  project     = var.gcp_project_id
  region      = var.gcp_zone
}