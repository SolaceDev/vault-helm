#!/bin/bash

# this script simply automated the steps necessary to run deploy_local.sh

gcloud auth login

export VAULT_ADDR=http://vault.k8s.mymaas.net

vault login -method=github token=${GITHUB_TOKEN}

vault read -field=private_key_data gcp/key/maas-vault-gcp-cluster-maas-vault-dev | base64 -D > ~/.config/gcloud/application_default_credentials.json

echo "end of script"
