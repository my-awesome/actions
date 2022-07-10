FROM ubuntu:22.04

ARG YQ_VERSION=4.25.3
ARG PUP_VERSION=0.4.0

RUN apt-get update && apt-get install -y \
  curl \
  wget \
  unzip \
  jq

RUN wget "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64" -O /usr/bin/yq && \
  chmod +x /usr/bin/yq

RUN wget -q -o- "https://github.com/ericchiang/pup/releases/download/v${PUP_VERSION}/pup_v${PUP_VERSION}_linux_amd64.zip" && \
  unzip "pup_*.zip" -d /usr/local/bin/

COPY telegram.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
