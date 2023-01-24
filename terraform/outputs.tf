###############################################################################
#
# maas-vault-gcp-cluster output variables
#
# This file defines output variables that can be retrieved from this project.
#
###############################################################################

output "project_id" {
  description = "The project_id of the GCP project where this project is deployed."
  value       = var.project_id
}

output "static_ip_address" {
  description = "The IP address of the static address created for the GCP LoadBalancer generated for the Vault Kubernetes Service."
  value       = google_compute_address.cluster.address
}
