###############################################################################
#
# maas-vault-gcp-cluster
#
# k8s.tf:
#
# All resources related to the Kubernetes cluster for a Vault cluster: e.g. 
# container_cluster, container_node_pool, service_account, etc...
#
###############################################################################

locals {
  identity_namespace = var.project_id == "maas-vault-dev" ? "${var.project_id}.svc.id.goog" : ""
}

resource "google_container_cluster" "gke" {
  provider = google-beta

  name     = var.cluster_id
  location = var.region

  remove_default_node_pool = true
  initial_node_count       = 1

  ip_allocation_policy {
    cluster_secondary_range_name  = "pod-ip-range"
    services_secondary_range_name = "service-ip-range"
  }

  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0" # <-- Find what the real CIDR is.
      display_name = "Solace Kanata Office"
    }
  }

  network = google_compute_network.cluster.self_link

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "10.0.0.0/28"
  }

  min_master_version = var.min_master_version

  workload_identity_config {
    identity_namespace = local.identity_namespace
  }

  subnetwork = google_compute_subnetwork.cluster.self_link
}

resource "google_container_node_pool" "gke" {
  name_prefix = var.cluster_id
  location    = var.region
  cluster     = google_container_cluster.gke.name
  node_count  = 1

  version = var.min_master_version

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }

  node_config {
    disk_size_gb = var.worker_disk_size
    labels = {
      retention = var.retention_type
    }
    machine_type    = var.worker_machine_type
    service_account = google_service_account.cluster.email

    oauth_scopes = [
      "cloud-platform",
    ]
  }

}

resource "google_service_account" "cluster" {
  account_id   = "${var.cluster_id}-sa"
  display_name = "${var.cluster_id} Cluster Noces Service Account"
  project      = var.project_id
}

resource "google_project_iam_member" "worker_node_role" {
  project = var.project_id
  role    = "projects/${var.project_id}/roles/gkeWorkerNode"
  member  = "serviceAccount:${google_service_account.cluster.email}"
}
