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

resource "google_storage_bucket" "primary" {
  name          = "${var.project_id}-${var.cluster_id}-data"
  force_destroy = true
  location      = "US"
  project       = var.project_id
}
