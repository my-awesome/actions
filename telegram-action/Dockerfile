FROM alpine:3.16

RUN apk upgrade --update && apk --no-cache add \
  bash \
  curl \
  jq \
  yq \
  unzip

RUN wget -q -o- "https://github.com/ericchiang/pup/releases/download/v0.4.0/pup_v0.4.0_linux_amd64.zip" && \
  unzip "pup_*.zip" -d /usr/local/bin/

COPY telegram.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
