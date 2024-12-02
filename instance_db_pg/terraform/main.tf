terraform {
  backend "gcs" {
  }
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "6.2.0"
    }
  }
}

provider "google" {
  project = var.project
  region  = var.region
}

data "google_compute_network" "network" {
  project = var.project
  name = var.network_name
}

data "google_compute_subnetwork" "subnetwork" {
  name    = var.subnetwork
  project = var.project
  region  = var.region
}

data "google_service_account" "restore_pg_arch360" {
  project      = var.project
  account_id   = var.account_service_pg
}

data "google_dns_managed_zone" "private_zone" {
  project = var.project
  name    = var.private_zone
}

resource "google_service_account_key" "sa_key" {
  service_account_id = data.google_service_account.restore_pg_arch360.name
  public_key_type    = "TYPE_X509_PEM_FILE"
}

resource "local_file" "sa_json" {
  content  = base64decode(google_service_account_key.sa_key.private_key)
  filename = abspath("./${var.env}-db-${var.region}-${var.name}.json")
}

resource "google_compute_address" "address_instance" {
  name         = "${var.name}-${var.region}-address"
  subnetwork   = data.google_compute_subnetwork.subnetwork.id
  region       = data.google_compute_subnetwork.subnetwork.region
  address_type = "INTERNAL"
}

resource "google_compute_instance" "db" {
  project = var.project
  name = format("%s", "${var.env}-pg-${var.region}-${var.name}")

  tags         = ["ssh", "postgresql"]
  zone         = format("%s", var.zone)
  machine_type = var.machine_type

  scheduling {
    automatic_restart = false
    preemptible       = var.preemptible
  }

  boot_disk {
    auto_delete = true
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      type  = "pd-standard"
      size  = var.size_disk
    }
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.pub_key)}"
  }

  network_interface {
    network = data.google_compute_network.network.name
    subnetwork = data.google_compute_subnetwork.subnetwork.name
    network_ip = google_compute_address.address_instance.address
  }

  service_account {
    email = data.google_service_account.restore_pg_arch360.email
    scopes = ["https://www.googleapis.com/auth/devstorage.read_only", "https://www.googleapis.com/auth/logging.write", "https://www.googleapis.com/auth/monitoring.write", "https://www.googleapis.com/auth/service.management.readonly", "https://www.googleapis.com/auth/servicecontrol", "https://www.googleapis.com/auth/trace.append"]
  }

  provisioner "file" {
    source      = local_file.sa_json.filename
    destination = "${var.folder_user}/sa.json"
  }

  provisioner "file" {
    source = "./configurations/${var.machine_type}.conf"
    destination = "${var.folder_user}/postgresql_machine.conf"
  }

  provisioner "file" {
    source = "./configurations/pg_hba.conf"
    destination = "${var.folder_user}/pg_hba.conf"
  }

  provisioner "file" {
    source = "./commands/install.sh"
    destination = "${var.folder_user}/install.sh"
  }

  provisioner "file" {
    source = "./commands/restore_db.sh"
    destination = "${var.folder_user}/restore_db.sh"
  }

  provisioner "file" {
    source = "./commands/users_privileges.sh"
    destination = "/home/users_privileges.sh"
  }

  provisioner "file" {
    source = "./configurations/authorized_keys"
    destination = "${var.folder_user}/authorized_keys"
  }

  provisioner "remote-exec" {
    inline = [
      "bash ${var.folder_user}/install.sh ${var.version_pg} ${var.folder_user}",
      "gcloud auth activate-service-account --key-file ${var.folder_user}/sa.json",
      "gcloud config set project ${var.project} --quiet",
      "bash ${var.folder_user}/restore_db.sh ${var.version_pg} ${var.db_name} ${var.folder_user} ${var.bucket} ${var.pwd_user_database} ${var.pwd_pgbouncer}",
      "sleep 20",
      "rm -f ${var.folder_user}/sa.json"
    ]
  }
}

resource "google_dns_record_set" "database_dns" {
  name = "pg-${var.name}.${data.google_dns_managed_zone.private_zone.dns_name}"
  type = "A"
  ttl  = 300

  managed_zone = data.google_dns_managed_zone.private_zone.name

  rrdatas = [google_compute_address.address_instance.address]
}