# syntax=docker/dockerfile:experimental
FROM ubuntu:22.04 as baseline
RUN apt update && apt upgrade -y \
  && apt install -y python3 python3-dev python3-pip curl unzip \
  && update-alternatives --install /usr/bin/python python /usr/bin/python3 1 \
  && update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 1

FROM baseline as tool_builder
ARG kubectl_version=1.24.10

WORKDIR /build

RUN curl -sLO https://storage.googleapis.com/kubernetes-release/release/v{$kubectl_version}/bin/linux/amd64/kubectl && chmod 755 ./kubectl

# Installation
FROM baseline
ARG helm_version=3.9.4
ARG aws_cli_version=2.7.22
ARG gcp_cli_version=409.0.0

# Add extra packages
RUN apt install -y gzip wget git git-lfs jq sshpass skopeo rsync \
  && curl -ksLO https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 && chmod 755 get-helm-3 \
  && ./get-helm-3 --version v$helm_version --no-sudo \
  && helm plugin install https://github.com/databus23/helm-diff \
  # AWS
  && curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${aws_cli_version}.zip" -o "awscliv2.zip" \
  && unzip awscliv2.zip \
  && ./aws/install \
  # AZURE
  && curl -sL https://aka.ms/InstallAzureCLIDeb | bash \
  # GCP
  && curl "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-${gcp_cli_version}-linux-x86_64.tar.gz" -o gcpcli.tar.gz \
  && tar -xvf gcpcli.tar.gz \
  && ./google-cloud-sdk/install.sh

COPY --from=tool_builder /build/kubectl /usr/local/bin/kubectl

WORKDIR /viya4-deployment/
COPY . /viya4-deployment/

ENV HOME=/viya4-deployment

RUN pip install -r ./requirements.txt \
  && ansible-galaxy install -r ./requirements.yaml \
  && chmod -R g=u /etc/passwd /etc/group /viya4-deployment/ \
  && chmod 755 /viya4-deployment/docker-entrypoint.sh \
  && git config --system --add safe.directory /viya4-deployment

ENV PLAYBOOK=playbook.yaml
ENV VIYA4_DEPLOYMENT_TOOLING=docker
ENV ANSIBLE_CONFIG=/viya4-deployment/ansible.cfg
ENV PATH=$PATH:/google-cloud-sdk/bin/

VOLUME ["/data", "/config", "/vault"]
ENTRYPOINT ["/viya4-deployment/docker-entrypoint.sh"]
