# maas-vault-helm
Install Vault using Helm 3.

## Pre-requisites
* GCP infrastructure is created, which includes
    * GKE cluster
    * GCS bucket
    * KMS keyring
    * TLS key, certificate, and CA
* [Kubectl installed](https://kubernetes.io/docs/tasks/tools/install-kubectl/) and [configured for the GKE cluster](https://cloud.google.com/kubernetes-engine/docs/how-to/cluster-access-for-kubectl#generate_kubeconfig_entry)
* [Helm 3 installed](https://helm.sh/docs/intro/install/)
    * `helm version` should display v3.x.x

## Configuration
* [maas-values.yaml](https://github.com/SolaceDev/maas-vault-gcp-cluster/blob/master/helm/maas-values.yaml) contains all the Helm Value overrides required
    * The only changes required are to the `maas` object

## Installation
`helm install --set <Overridden configuration values> -f maas-values.yaml <Vault instance name> vault-helm`
* Vault instance name should be in format `vault-<env>` where env is dev, prod, etc.
* Overridden configuration values are in the format: `maas.gcpProject=maas-vault-prod,maas.lbAddress=1.2.3.4`