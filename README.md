# maas-vault-gcp-cluster
A repository containing code to manage the infrastructure using Terraform and
scripts to install or upgrade Helm releases for Vault and cert-manager.

## Terraform
The **terraform** subdirectory contains a [README.md](./terraform/README.md)
document to describe the Terraform project.

## Helm
The **helm** subdirectory contains a [README.md](./helm/README.md) document
to describe the Helm charts.

## Deployment
The **deploy_local.sh** scripts glues both of these projects together for a simple
user experience to deploy both the infrastructure and Helm charts together.

The **deploy_local.sh** script supports two operations:
1. *deploy*; and
2. *destroy*.

The *deploy* operation handles running a **Terraform** *apply* command and then
runs either **Helm** *install* or *upgrade* depending on the state of the system.


The *destroy* operation simply runs a **Terraform** *destroy* command.  Since
the Helm releases don't need to be uninstalled when the entire GKE cluster is
deleted.

## Pre-install setup
This repository has sub-modules enabled for cert-manager and vault-helm.  When
cloning this repo please ensure you use the recursive option:
`git clone --recursive https://github.com/SolaceDev/maas-vault-gcp-cluster.git`

You will need to set up a new github personal access token.  Refer to github
documentation to perform this action.  We will require `read:org, repo` permissions.
(SAVE YOUR TOKEN!)

Access to the GCP project maas-vault-dev is required (email invite).

Log into gcloud:  `gcloud auth application-default login`
(this will open a browser window on Mac)

Export the vault env var:  `export VAULT_ADDR=http://vault.k8s.mymaas.net`

Log into vault using previously-created access token: `vault login -method=github token=${GITHUB_TOKEN}`

Finally, build the GCP credentials file:
`vault read -field=private_key_data gcp/key/maas-vault-gcp-cluster-maas-vault-dev | base64 -D > ~/.config/gcloud/application_default_credentials.json`

You should now be able to run gcloud and vault commands.

## Datadog feature flag
To enable datadog deployment for kubernetes/vault use "--enable_datadog=yes"

### Reference Environments
This project is designed to easily deploy ephemeral instances for development
(of Vault features) activities.  However, there are some well-known
environments that serve specific purposes in the development lifecycle and
delivery pipeline.  This table describes where they are provisioned and their
purpose.

Cluster ID | GCP Project ID | Perpetual | Purpose
-----------|----------------|-----------|---------
vault-dev  | maas-vault-dev | yes       | Reference environment consisting of the head of the develop branch
vault-dev-dr | maas-vault-dev | no      | An environment used to validate disaster recovery testing as well as backup/restore testing
vault-stage | maas-vault-prod | yes     | A staging environment in the production account to rehearse the production deployment
vault-prod | maas-vault-prod | yes      | The production environment used by all other Solace consumers
