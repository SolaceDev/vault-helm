###############################################################################
#
# maas-vault-gcp-cluster
#
# A Terraform project that manages the resources needed for hosting a Vault
# cluster.
#
###############################################################################

# Terraform settings
terraform {
  backend "gcs" {
    # Bucket and Prefix are configured in the terraform.sh script since they
    # are derived from the project_id and cluster_id variables.
  }

  # Pessimistic version constraint meaning anything ≥ 0.12.0 and < 0.13.0
  required_version = "~> 0.12.0"
}

provider "google" {
  project = var.project_id
  region  = var.region
  version = "3.16.0"
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
  version = "3.16.0"
}
