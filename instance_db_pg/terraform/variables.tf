variable "project" {
  description = "The project ID to host the cluster in"
}

variable "region" {
  description = "The region to host the cluster in"
}

variable "network_name"{}
variable "subnetwork"{}
variable "machine_type"{}
variable "zone"{}
variable "env"{}
variable "preemptible"{
  default = false
}
variable "size_disk"{}
variable "bucket"{}
variable "db_name"{}
variable "name"{}
variable "pub_key"{}
variable "private_key"{}
variable "folder_user"{}
variable "version_pg"{}
variable "account_service_pg"{}
variable "pwd_user_database"{}
variable "pwd_pgbouncer"{}
variable "private_zone"{}