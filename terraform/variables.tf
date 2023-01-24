###############################################################################
#
# maas-vault-gcp-cluster variables
#
# This file defines all variables used in this Terraform project.
#
###############################################################################

variable "project_id" {
  description = "The GCP project ID where the resources will be provisioned."
  default     = "maas-vault-dev"
}

variable "region" {
  description = "The GCP region where the resources will be provisioned."
  default     = "us-east1"
}

variable "cluster_id" {
  description = "The unique identifier for the Vault cluster being deployed."
}

#
# Label related variables
#
variable "retention_type" {
  description = "The value for the retention label.  Should be set to production or dev."
  default     = "dev"
}

#
# Worker node related variables
#
variable "worker_machine_type" {
  description = "The machine type for worker nodes."
  default     = "n1-standard-2"
}

variable "worker_disk_size" {
  description = "The size in GB of the boot disk attached to worker nodes."
  default     = 10
}
