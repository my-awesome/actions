FROM alpine:3.16

ENV TIMESTAMP=${TIMESTAMP}
ENV GITHUB_TOKEN=${GITHUB_TOKEN}

RUN apk upgrade --update && apk --no-cache add \
  bash \
  github-cli

COPY update.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
