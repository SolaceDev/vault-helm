FROM alpine:3.11.5

RUN apk update && \
    apk add curl python3 bash unzip wget

ENV KUBE_VERSION="1.15.10"
RUN wget -q https://storage.googleapis.com/kubernetes-release/release/v${KUBE_VERSION}/bin/linux/amd64/kubectl -O /usr/local/bin/kubectl && \
    chmod +x /usr/local/bin/kubectl

ENV HELM_VERSION="v3.8.0"
RUN wget -q https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz -O - | tar -xzO linux-amd64/helm > /usr/local/bin/helm && \
    chmod +x /usr/local/bin/helm

ENV GCLOUD_VERSION=288.0.0
RUN curl -sSL https://sdk.cloud.google.com | bash
ENV PATH $PATH:/root/google-cloud-sdk/bin

ENV TERRAFORM_VERSION="0.12.24"
RUN cd /tmp && \
    wget -q https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip && \
    unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip -d /usr/bin && \
    rm -rf /tmp/* && \
    rm -rf /var/cache/apk/* && \
    rm -rf /var/tmp/*

ENV VAULT_VERSION=1.4.0
RUN wget -q https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip && \
    unzip vault_${VAULT_VERSION}_linux_amd64.zip -d /usr/bin

# Pre-install plugins
RUN mkdir -p /root/.terraform.d/plugins/linux_amd64
ENV TF_GOOGLE_PLUGIN_VERSION="3.16.0"
ENV TF_GOOGLE_BETA_PLUGIN_VERSION="3.16.0"
RUN wget -q https://releases.hashicorp.com/terraform-provider-google/${TF_GOOGLE_PLUGIN_VERSION}/terraform-provider-google_${TF_GOOGLE_PLUGIN_VERSION}_linux_amd64.zip && \
    unzip terraform-provider-google_${TF_GOOGLE_PLUGIN_VERSION}_linux_amd64.zip -d /root/.terraform.d/plugins/linux_amd64 && \
    wget -q https://releases.hashicorp.com/terraform-provider-google-beta/${TF_GOOGLE_BETA_PLUGIN_VERSION}/terraform-provider-google-beta_${TF_GOOGLE_BETA_PLUGIN_VERSION}_linux_amd64.zip && \
    unzip terraform-provider-google-beta_${TF_GOOGLE_BETA_PLUGIN_VERSION}_linux_amd64.zip -d /root/.terraform.d/plugins/linux_amd64

ENTRYPOINT ["/bin/bash"]
