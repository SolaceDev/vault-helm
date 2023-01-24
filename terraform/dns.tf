
data "google_dns_managed_zone" "project" {
  name    = "${var.project_id}-mymaas-net"
  project = var.project_id
}


resource "google_dns_record_set" "cluster" {
  name         = "${var.cluster_id}.${data.google_dns_managed_zone.project.dns_name}"
  managed_zone = data.google_dns_managed_zone.project.name
  type         = "A"
  ttl          = 300

  rrdatas = [
    google_compute_address.cluster.address
  ]
}
