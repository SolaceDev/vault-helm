ARG BASE_IMAGE
FROM ${BASE_IMAGE}

ENV TF_CLI_ARGS_apply="--auto-approve"

WORKDIR vault

COPY helm ./helm
COPY *.sh ./
COPY terraform ./terraform

ENTRYPOINT ["./deploy.sh"]