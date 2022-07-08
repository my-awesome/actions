FROM alpine:3.16

RUN apk upgrade --update && apk --no-cache add \
  bash \
  github-cli

COPY update.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
