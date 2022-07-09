# actions

Resouces
* [GitHub Actions](https://docs.github.com/en/actions)
* [Starter Workflows](https://github.com/actions/starter-workflows)

## gh-update

* [GitHub CLI](https://cli.github.com/manual)

How to test it locally
```bash
docker build -t my-awesome/gh-update-action ./gh-update-action
docker run --rm my-awesome/gh-update-action "my-email" "my-name"
```

## telegram

* [Telegram Bot API](https://core.telegram.org/bots/api#getupdates)

```bash
# an update is considered confirmed as soon as getUpdates
# is called with an offset higher than the latest update_id
http https://api.telegram.org/bot${TELEGRAM_API_TOKEN}/getUpdates?offset=${TELEGRAM_OFFSET}
```

How to test it locally
```bash
# test
docker run --rm --name ubuntu -it ubuntu:20.04

# build
docker build -t my-awesome/telegram-action ./telegram-action

# run
docker run --rm \
  --env TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --env-file ./telegram-action/telegram.secrets \
  --volume ${PWD}/telegram-action/telegram.json:/telegram.json \
  --volume ${PWD}/telegram-action/content:/content \
  my-awesome/telegram-action "/telegram.json"

# requires
cat ./telegram-action/telegram.secrets
#TELEGRAM_API_TOKEN=
#TELEGRAM_FROM_ID=
```
