
resource "google_project_service" "compute" {
  project            = var.project
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "sqladmin" {
  project            = var.project
  service            = "sqladmin.googleapis.com"
  provider           = google-beta
  disable_on_destroy = false
}

data google_service_account "sa_cloudsql" {
  account_id = var.service_account
}
resource "google_service_account_key" "sa_key" {
  service_account_id = data.google_service_account.sa_cloudsql.name
  public_key_type    = "TYPE_X509_PEM_FILE"
}

resource "local_file" "sa_json" {
  content  = base64decode(google_service_account_key.sa_key.private_key)
  filename = abspath("./${var.env}-db-${var.region}-${var.name}.json")
}

resource "google_compute_instance" "db" {
  project = var.project
  name = format("%s", "${var.env}-db-${var.region}-${var.name}")

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
      size  = 40
    }
  }

  dynamic "scratch_disk" {
    for_each = range(1, (var.disks + 1))
    content {
      interface = "NVME"
    }
  }

  network_interface {
    network = var.network
    subnetwork = var.subnetwork
    access_config {
      // Include this section to give the VM an external ip address
    }
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.pub_key)}"
  }
  service_account {
    email  = var.service_account
    scopes = ["cloud-platform"]
  }
  connection {
    type  = "ssh"
    port  = 22
    user  = "ubuntu"
    agent = "true"
    host  = google_compute_instance.db.network_interface.0.access_config.0.nat_ip
  }

  provisioner "file" {
    source      = local_file.sa_json.filename
    destination = "/home/ubuntu/sa.json"
  }

  provisioner "file" {
    source      = "${path.module}/install_db.sh"
    destination = "/home/ubuntu/install_db.sh"
  }
  provisioner "file" {
    source      = "${path.module}/ssd_disk.sh"
    destination = "/home/ubuntu/ssd_disk.sh"
  }
  provisioner "file" {
    source      = "${path.module}/backup_db.sh"
    destination = "/home/ubuntu/backup_db.sh"
  }
  provisioner "file" {
    source      = "${path.module}/restore_db.sh"
    destination = "/home/ubuntu/restore_db.sh"
  }
  provisioner "file" {
    source      = "${path.module}/users_db.sh"
    destination = "/home/ubuntu/users_db.sh"
  }
  provisioner "file" {
    source      = "${path.module}/users_privileges.sh"
    destination = "/home/ubuntu/users_privileges.sh"
  }
  provisioner "file" {
    source      = "${path.module}/basebackup_db.sh"
    destination = "/home/ubuntu/basebackup_db.sh"
  }
  provisioner "file" {
    source      = "${path.module}/upload_backup.sh"
    destination = "/home/ubuntu/upload_backup.sh"
  }

  provisioner "file" {
    source      = "${path.module}/${var.pg_version}/postgresql.conf"
    destination = "/home/ubuntu/postgresql.conf"
  }
  provisioner "file" {
    source      = "${path.module}/${var.pg_version}/pg_hba.conf"
    destination = "/home/ubuntu/pg_hba.conf"
  }

  provisioner "remote-exec" {
    inline = [
      "export SQLCLOUD_CONNECTION=${var.origin_cloudsql_connection}",
      "bash $HOME/ssd_disk.sh ${var.disks}",
      "bash $HOME/install_db.sh ${var.pg_version}",
      "sleep 20",
      "gcloud config set 'auth/service_account_use_self_signed_jwt' false",
      "gcloud auth activate-service-account --key-file $HOME/sa.json",
      "gcloud config set project teamcore-multi",
      "export PG_HOME=$(sudo -H -u postgres bash -c \"echo \\$HOME\")",
      "sudo cp -f backup_db.sh $PG_HOME",
      "sudo cp -f users_db.sh $PG_HOME",
      "sudo cp -f users_privileges.sh $PG_HOME",
      "sudo cp -f restore_db.sh $PG_HOME",
      "sudo cp -f basebackup_db.sh $PG_HOME",
      "sudo chown postgres:postgres $PG_HOME/backup_db.sh",
      "sudo chown postgres:postgres $PG_HOME/users_db.sh",
      "sudo chown postgres:postgres $PG_HOME/users_privileges.sh",
      "sudo chown postgres:postgres $PG_HOME/restore_db.sh",
      "sudo chown postgres:postgres $PG_HOME/basebackup_db.sh",
      "sudo -H -u postgres bash -c \"cd \\$HOME && bash backup_db.sh ${var.origin_db_password} ${var.origin_db_name}\"",
      "sudo -H -u postgres bash -c \"cd \\$HOME && bash backup_db.sh ${var.origin_db_password} ${var.origin_db_name}_cubo\"",
      "sudo -H -u postgres bash -c \"cd \\$HOME && bash users_db.sh ${var.destiny_db_super_password} ${var.destiny_db_user} ${var.destiny_db_user_password}\"",
      "sudo -H -u postgres bash -c \"cd \\$HOME && bash restore_db.sh ${var.origin_db_name}\"",
      "sudo -H -u postgres bash -c \"cd \\$HOME && bash restore_db.sh ${var.origin_db_name}_cubo\"",
      "sudo -H -u postgres bash -c \"cd \\$HOME && bash users_privileges.sh ${var.origin_db_name} ${var.destiny_db_user} ${var.destiny_db_user_password} ${var.pg_bouncer_pass}\"",
      "sudo -H -u postgres bash -c \"cd \\$HOME && bash basebackup_db.sh ${var.destiny_db_super_password} ${var.destiny_db_user}\"",
      "sudo chown ubuntu:ubuntu /mnt/disks/ssd-array/${var.destiny_db_user}.tar",
      "bash $HOME/upload_backup.sh ${var.destiny_db_user} /mnt/disks/ssd-array/${var.destiny_db_user}.tar",
    ]
  }

  depends_on = [
    google_project_service.compute
  ]
}

data "google_dns_managed_zone" "private_zone" {
  project = var.project
  name = var.private_zone
}

resource "google_dns_record_set" "dev_pg_dns" {
  name = "${var.name}.dev.pg.${data.google_dns_managed_zone.private_zone.dns_name}"
  type = "A"
  ttl  = 300

  managed_zone = data.google_dns_managed_zone.private_zone.name

  rrdatas = [google_compute_instance.db.network_interface.0.access_config.0.nat_ip]
}
