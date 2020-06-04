ARG BASE_IMAGE
FROM ${BASE_IMAGE}

WORKDIR vault

COPY helm/ ./helm
COPY *.sh ./
COPY terraform ./terraform

ENTRYPOINT ["./deploy.sh"]