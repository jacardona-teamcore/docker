terraform {
  backend "gcs" {
    bucket = "tc-infra-tfstate"
    prefix = "tc_infra_db_backups"
  }
}

provider "google" {
  project = var.project
  region  = var.region
}

data "google_compute_network" "gke-01" {
  project = var.project
  name = var.network
}

data "google_compute_subnetwork" "gke-prod-nodes" {
  name    = var.subnetwork
  project = var.project
  region  = var.region
}

data "google_service_account" "db-backup-cloudsql" {
  project = var.project
  account_id = var.account_id
}

module "execute" {
  name= "execute"
  source = "../modules/backup_db"
  project = var.project
  env = var.env_name
  preemptible = false
  region = var.region
  zone = "${var.zone}"
  pub_key = var.pub_key
  origin_cloudsql_connection = "${var.origen_project}:${var.origen_region}:${var.origen_instance}"
  origin_db_name = var.origen_db
  origin_db_password = var.origen_password
  destiny_db_super_password = var.destinity_super_password
  destiny_db_user = var.destinity_user
  destiny_db_user_password = var.destinity_password
  pg_version = var.destinity_pg_version
  network = data.google_compute_network.gke-01.id
  subnetwork = data.google_compute_subnetwork.gke-prod-nodes.id
  machine_type = "n2d-standard-16"
  disks = 4
  pg_bouncer_pass = var.pg_bouncer_pass
  service_account = data.google_service_account.db-backup-cloudsql.email
  private_zone = var.private_zone  
}