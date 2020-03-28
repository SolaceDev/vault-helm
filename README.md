# maas-vault-gcp-cluster
A Terraform project to provision and manage a GKE cluster and all related
resources for Vault.

This project is the second layer in building up a Vault cluster.  It requires
a Google Cloud Platform (GCP) project to be properly configured using the
[maas-vault-gcp-project][1] Terraform project to make sure that project wide
resources are in place.

This project provisions resources dedicated for a specific Vault cluster,
which can be easily provision and destroyed when no longer needed.  Some GCP
resources cannot be easily deleted, like KMS key rings (can't be deleted) and
IAM custom roles (can be soft-deleted but it can take up to 37 days before a
deleted role name can be used again).

## Description
This project creates a completely isolated set of resources for a Vault
cluster.  Here's a high level breakdown of the resources created:
#### Networking
* `google_compute_network` (VPC)
* `google_compute_subnetwork`
* `google_compute_router`
* `google_compute_router_nat` (NAT gateway)

#### Storage
* `google_storage_bucket`
* `google_storage_bucket_iam_binding` (Policy on bucket)

#### Kubernetes
* `google_container_cluster`
* `google_container_node_pool`
* `google_service_account` (for cluster nodes)
* `google_project_iam_binding` (Policy for service account)

## Deployment
This project is being initially designed to be manually deployed.  The reason
for this decision is that in order to remove all secrets and credentials from
the CI/CD platforms (Jenkins), a running Vault is needed.  Since this project
is critical to deploying a running Vault, automating its deployment would
introduce a circular dependency.

### Pipeline Stages
This project is currently aiming for a three-stage pipeline, with the option of
adding a fourth stage (`vault-staging`), should the need arise.

**Stages:**
1. `vault-dev`: Is a perpetual Vault cluster maintained in the **maas-vault-dev**
GCP project.  It allows the verification of updates made by changes in this
project to existing clusters.
2. `vault-dev-dr`: Is an ephmeral Vault cluster provisioned in the **maas-vault-dev** GCP project.  It allows the verification of provisioning a cluster from scratch.
3. `vault-staging`: (Not yet used) Is a perpetual Vault cluster maintained in the
**maas-vault-prod** GCP project.  It allows a second verification of updates
made by changes in this project to existing clusters, in a more secure GCP project.
4. `vault-prod`: Is the production Vault cluster maintained in the **maas-vault-prod**
GCP project.

## Credentials
In order to execute this Terraform project, credentials are needed with the IAM
role **Terraform maas-vault-gcp-cluster Permissions**.  The following command
can be used to obtain credentials for use by Terraform.

```
$ docker run -it --rm -v $HOME/.config/gcloud:/root/.config/gcloud \
    gcr.io/google.com/cloudsdktool/cloud-sdk gcloud auth application-default login
```

The command will display a URL that needs to be entered into a browser to
complete the OAuth 2 exchange.  When it's complete, the resulting code should
be entered at the prompt displayed by the command.  This will complete the
OAuth 2 exchance and setup credentials on your workstation.

When you are done with the credentials, they can be revoked with the following
command.

```
$ docker run -it --rm -v $HOME/.config/gcloud:/root/.config/gcloud \
    gcr.io/google.com/cloudsdktool/cloud-sdk gcloud auth application-default revoke
```

## Running
A convenience script called **terraform.sh** is provided to launch a properly
configured Docker container with the **hashicorp/terraform** Docker image.

```
$ terraform.sh [ [terraform_command] terraform_arguments...]
```

If no command is provided, the Terraform **help** command is executed.  For a
complete list of Terraform commands, refer to the [CLI documentation page][2].

## Testing
Once this project has been deployed, it can be verified using the **test.sh**
script.  If this is the initial deployment, the Vault software will need to be
deployed and the Vault initialized.

[1]: https://github.com/solacedev/maas-vault-gcp-project
[2]: https://www.terraform.io/docs/commands/index.html