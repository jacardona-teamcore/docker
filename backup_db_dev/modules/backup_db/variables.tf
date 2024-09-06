variable "project" {
  default = "teamcore-multi"
}
variable "env" {
  default = "prod"
}

variable "region" {
  default = "us-central1"
}
variable "pub_key" {

}
variable "preemptible" {

}

variable "zone" {
  default = "us-central1-b"
}


variable "origin_cloudsql_connection" {}
variable "origin_db_password" {}
variable "origin_db_name" {}
variable "destiny_db_super_password" {}
variable "destiny_db_user" {}
variable "destiny_db_user_password" {}

variable "pg_version" {
  default = "12"
}

variable "db_mem" {
  default = "32"
}
variable "network" {}
variable "subnetwork" {}
variable "name" {}
variable "pg_bouncer_pass" {
  default = "NjgzOTg0ZWE5MmY2NmEwMjYyMjcyYmQ3"
}
variable "machine_type" {
  default = "n2d-standard-16"
}
variable "disks" {
  default = 3
}
variable "service_account" {}
variable "private_zone" {}