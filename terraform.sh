#!/bin/bash
set -eu${DEBUG+x}o pipefail

terraform_image=${TERRAFORM_IMAGE:-hashicorp/terraform:0.12.23}

if [[ $# == 0 ]]; then
    set -- help
fi

command=$1
shift

while [[ -z ${TF_VAR_cluster_id:-} ]]; do
    echo "No Vault cluster ID specified."
    read -p "Specify the Vault cluster ID: " TF_VAR_cluster_id
done

export TF_VAR_cluster_id

init_required=false

case $command in
    apply|destroy|force-unlock|import|plan|refresh)
        init_required=true
        ;;
esac

if [[ $init_required == true ]]; then
    # Remove any previous .terraform; it will be recreated by the Terraform init
    # command.
    if [[ -z ${SKIP_REMOVE_DOT_TERRAFORM:-} ]]; then
        rm -rf .terraform
    fi

    docker run \
            -it \
            --rm \
            -v $HOME/.config/gcloud:/root/.config/gcloud:ro \
            -v $(pwd):/work \
#            -v $GOOGLE_APPLICATION_CREDENTIALS:/root/service-account.json \
            -w /work \
#            -e GOOGLE_APPLICATION_CREDENTIALS=/root/service-account.json \
            $terraform_image \
            init \
            -backend-config="bucket=${TF_VAR_project_id:-"maas-vault-dev"}" \
            -backend-config="prefix=terraform/maas-vault-gcp-cluster/$TF_VAR_cluster_id/" \
            -upgrade \
            -lock=true
fi

docker run \
        -it \
        --rm \
        -e TF_VAR_project_id \
        -e TF_VAR_region \
        -e TF_VAR_cluster_id \
        -v $HOME/.config/gcloud:/root/.config/gcloud:ro \
        -v $(pwd):/work \
#        -v $GOOGLE_APPLICATION_CREDENTIALS:/root/service-account.json \
        -w /work \
#        -e GOOGLE_APPLICATION_CREDENTIALS=/root/service-account.json \
        $terraform_image \
        $command "$@"
