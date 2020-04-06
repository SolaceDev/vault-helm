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

    release_channel {
        channel = "STABLE"
    }

    subnetwork = google_compute_subnetwork.cluster.self_link
}

resource "google_container_node_pool" "gke" {
    name_prefix = var.cluster_id
    location    = var.region
    cluster     = google_container_cluster.gke.name
    node_count  = 1

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
        machine_type = var.worker_machine_type
        service_account = google_service_account.cluster.email

        oauth_scopes = [
            "cloud-platform",
        ]
    }

}

resource "google_service_account" "cluster" {
    account_id   = var.cluster_id
    display_name = "${var.cluster_id} Cluster Noces Service Account"
    project      = var.project_id
}

resource "google_project_iam_member" "cluster_log_writer" {
    project = var.project_id
    role    = "roles/logging.logWriter"
    member  = "serviceAccount:${google_service_account.cluster.email}"
}

resource "google_project_iam_member" "cluster_metrics_writer" {
    project = var.project_id
    role    = "roles/monitoring.metricWriter"
    member  = "serviceAccount:${google_service_account.cluster.email}"
}

resource "google_project_iam_member" "cluster_storage_object_admin" {
    project = var.project_id
    role    = "roles/storage.objectAdmin"
    member  = "serviceAccount:${google_service_account.cluster.email}"
}
