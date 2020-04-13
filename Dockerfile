ARG BASE_IMAGE
FROM ${BASE_IMAGE}

# Pre-install plugins
RUN mkdir -p /root/.terraform.d/plugins/linux_amd64
ENV TF_GOOGLE_PLUGIN_VERSION="3.16.0"
ENV TF_GOOGLE_BETA_PLUGIN_VERSION="3.16.0"
RUN wget -q https://releases.hashicorp.com/terraform-provider-google/${TF_GOOGLE_PLUGIN_VERSION}/terraform-provider-google_${TF_GOOGLE_PLUGIN_VERSION}_linux_amd64.zip && \
    unzip terraform-provider-google_${TF_GOOGLE_PLUGIN_VERSION}_linux_amd64.zip -d /root/.terraform.d/plugins/linux_amd64 && \
    wget -q https://releases.hashicorp.com/terraform-provider-google-beta/${TF_GOOGLE_BETA_PLUGIN_VERSION}/terraform-provider-google-beta_${TF_GOOGLE_BETA_PLUGIN_VERSION}_linux_amd64.zip && \
    unzip terraform-provider-google-beta_${TF_GOOGLE_BETA_PLUGIN_VERSION}_linux_amd64.zip -d /root/.terraform.d/plugins/linux_amd64

ENV TF_CLI_ARGS_apply="--auto-approve"

WORKDIR vault

COPY helm ./helm
COPY *.sh ./
COPY terraform ./terraform

ENTRYPOINT ["./deploy.sh"]