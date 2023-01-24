###############################################################################
#
# maas-vault-gcp-cluster
#
# networking.tf:
#
# All resources related to networking for a Vault cluster: e.g. vpc, subnets,
# firewall rules, etc...
#
###############################################################################

resource "google_compute_network" "cluster" {
  name = var.cluster_id

  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_address" "cluster" {
  provider = google-beta

  name    = var.cluster_id
  region  = var.region
  project = var.project_id

  labels = {
    retention = var.retention_type
  }
}

resource "google_compute_subnetwork" "cluster" {
  ip_cidr_range = "10.1.0.0/20"
  name          = "${var.cluster_id}-${var.region}"
  network       = google_compute_network.cluster.self_link
  region        = var.region
  project       = var.project_id

  private_ip_google_access = true

  # Turns on Subnet flow logs with defaults
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }

  secondary_ip_range {
    range_name    = "service-ip-range"
    ip_cidr_range = "10.128.0.0/20"
  }

  secondary_ip_range {
    range_name    = "pod-ip-range"
    ip_cidr_range = "10.64.0.0/20"
  }
}

resource "google_compute_router" "cluster" {
  name    = var.cluster_id
  region  = google_compute_subnetwork.cluster.region
  network = google_compute_network.cluster.self_link
  project = var.project_id

  bgp {
    asn = 64514
  }
}

resource "google_compute_router_nat" "cluster" {
  name                               = var.cluster_id
  router                             = google_compute_router.cluster.name
  region                             = google_compute_router.cluster.region
  project                            = var.project_id
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ALL"
  }
}
