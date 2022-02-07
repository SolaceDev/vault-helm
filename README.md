# maas-vault-gcp-cluster
A repository containing code to manage the infrastructure using Terraform and
scripts to install or upgrade Helm releases for Vault and cert-manager.

## Terraform
The *terraform* subdirectory contains a [README.md](./terraform/README.md)
document to describe the Terraform project.

## Helm
The *helm* subdirectory contains a [README.md](./helm/README.md) document
to describe the Helm charts.

## Deployment
The *deploy_local.sh* scripts glues both of these projects together for a simple
user experience to deploy both the infrastructure and Helm charts together.

The *deploy_local.sh* script supports two operations:
1. **deploy**
2. **destroy**

The **deploy** operation handles running a Terraform **apply** command and then
runs either Helm **install** or **upgrade** depending on the state of the system.


The **destroy** operation runs a Helm **uninstall** command followed by a
Terraform **destroy** command.

### Pre-install setup

This repository has submodules for cert-manager and vault-helm.  When
cloning this repo, ensure you use the `--recurse-submodules` option:
```
git clone --recurse-submodules https://github.com/SolaceDev/maas-vault-gcp-cluster.git
```

Access to the GCP project maas-vault-dev is required (email invite).

### Reliance on Running Production Vault Server

The *deploy_local.sh* script will make use of the production Vault server to streamline
the deployment process by obtaining the necessary secrets (i.e. credentials, keys, etc...).

In the event that the production Vault server is not available, the following steps must
be followed ahead of running the *deploy_local.sh* script:

1. Obtain a Google Cloud Service Account key from the Google Cloud Console and save it in the file *~/.config/gcloud/application_default_credentials.json*
1. If including the DataDog component, obtain the DataDog API key and App key from PE and set the following environment variables:
* * **DD_API_KEY**: Set the DataDog API key
* * **DD_APP_KEY**: Set the DataDog APP key
1. If including the DataDog component, export the environment variables

The *deploy_local.sh* script can now be used.

## Datadog feature flag

To include the **datadog** component in the deployment, use `--enable_datadog` or
`-dd`.  Alternatively, the **DD_API_KEY** and **DD_APP_KEY** environment
variables can be set to provide the DataDog API key and App key.

