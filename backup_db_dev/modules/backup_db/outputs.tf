output db_ip {
  value = google_compute_instance.db.network_interface.0.access_config.0.nat_ip
}
output "db_dns" {
  value = google_dns_record_set.dev_pg_dns.name
}
output "db_password" {
  value = var.destiny_db_super_password
}

/*
output tst_ip {
  value = google_compute_global_address.tc2_address.address
}
*/