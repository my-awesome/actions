#!/bin/bash

set -euo pipefail

##############################

DATA_PATH=${1:?"Missing DATA_PATH"}

##############################

# global param: <DATA_PATH>
function count_messages {
  echo $(cat ${DATA_PATH} | jq '. | length')
}

# global param: <DATA_PATH>
function get_latest_offset {
  # expected format: [] or [{"update_id":123, ...}]
  # use "-r" to avoid printing quotes
  echo $(cat ${DATA_PATH} | jq -r '. | last | .update_id // ""')
}

function build_query_params {
  local OFFSET=$(get_latest_offset)

  # check if offset exists and increase it by 1
  [[ -z "${OFFSET}" ]] && echo "" || echo "?offset=$((${OFFSET} + 1))"
}

# global param: <TELEGRAM_API_TOKEN>
function build_url {
  local OFFSET_PARAM=$(build_query_params)

  # - when the offset parameter is passed, all the messages with a lower offset/update_id will be deleted from telegram "queue"
  # - messages are marked as read always on the next execution, when the latest offset is passed
  # - if there are only invalid messages always the latest known offset is passed, until a valid one is stored
  # - telegram has a retention period, so eventually invalid or not processed messages will be dropped anyway
  echo "https://api.telegram.org/bot${TELEGRAM_API_TOKEN}/getUpdates${OFFSET_PARAM}"
}

function request_latest_messages {
  local REQUEST_URL=$(build_url)

  echo $(curl -s ${REQUEST_URL})
}

# global param: <TELEGRAM_FROM_ID>
# global param: <TIMESTAMP>
function validate_messages {
  local RESPONSE=$(request_latest_messages)

  # sample response
  # {
  #   "ok": true,
  #   "result": [
  #    {
  #      "update_id": 123,
  #      "message": {
  #        "message_id": 42,
  #        "from": {
  #          "id": <TELEGRAM_FROM_ID>,
  #          "is_bot": false,
  #          "first_name": "<REDACTED>",
  #          "language_code": "en"
  #        },
  #        "chat": {
  #          "id": <TELEGRAM_FROM_ID>,
  #          "first_name": "<REDACTED>",
  #          "type": "private"
  #        },
  #        "date": 1622886765,
  #        "text": "test"
  #      }
  #    }
  #  ]
  # }
  # 
  # - filters messages from a specific user id
  # - "update_id" is used as offset parameter
  # - handles optional "text" field e.g. images
  # - converts whitespaces in new lines
  # - converts string to array splitting by new line
  echo ${RESPONSE} | jq -c \
    --arg TELEGRAM_FROM_ID "${TELEGRAM_FROM_ID}" \
    --arg TIMESTAMP "${TIMESTAMP}" \
    '[ .result[] | select(.message.from.id==($TELEGRAM_FROM_ID | tonumber)) ] |
      map({
        "update_id": .update_id,
        "timestamp": $TIMESTAMP,
        "message_text": [ try(.message.text) catch "" | gsub("\\s+";"\n") | splits("\n") ]
      })'
}

function parse_messages {
  local MESSAGES=$(validate_messages)

  # this keeps all invalid messages
  # "url": (.message_text[] | select(. | startswith("http")) // "INVALID_URL")

  # - expected format: [{"update_id":123,"message_text":["hello","world"]}]
  # - discard messages without text e.g. images: [{"update_id":123,"message_text":[""]}]
  # - set as "url" only the first item that starts with "http", remove ending "/" to avoid "301 Moved Permanently"
  # - "description" value (url) is just a placeholder, it's replaced with the <title> of the page afterwards with "pup"
  # - set as "source" only the first item that starts with "&", default is "unknown"
  # - set as "path" only the first item that starts with "_", default is "/random"
  # - set as "tags" all the items that starts with "#"
  # - set auto tags
  echo $MESSAGES | jq \
    '. | map(select(.message_text[0] != "")) |
      map({
        "update_id": .update_id,
        "timestamp": .timestamp,
        "url": .message_text[] | select(. | startswith("http")) | rtrimstr("/"),
        "description": .message_text[] | select(. | startswith("http")),
        "client": "telegram",
        "source": ((.message_text | map(select(. | startswith("&")) | gsub("&";"") | ascii_downcase) | first ) // "unknown"),
        "path": ((.message_text | map(select(. | startswith("_")) | gsub("_";"/") | ascii_downcase) | first ) // "/random"),
        "tags": (
          (if isempty(.message_text[] | select(. | startswith("https://github.com"))) then [] else [{ "name": "github", "auto": true }] end) +
          (if isempty(.message_text[] | select(. | contains("youtube.com"))) then [] else [{ "name": "youtube", "auto": true }] end) +
          (.message_text | map(select(. | startswith("#"))) | map({ "name": . | gsub("#";"") | ascii_downcase, "auto": false }))
        )
      })'
}

function add_description {
  local VALUES=$(parse_messages)
  local TMP_DATA=$(mktemp)
  echo $VALUES > $TMP_DATA

  # shell commands not supported
  # https://github.com/stedolan/jq/issues/147
  # https://stackoverflow.com/questions/36565295/jq-to-replace-text-directly-on-file-like-sed-i
  # https://unix.stackexchange.com/questions/327394/using-a-command-inside-a-sed-substitution

  # curl -s <URL> | pup 'title json{}' | jq '.[].text'
  # echo "TEST" | sed -e "s/TEST/###$(date)###/"

  for URL in $(cat ${TMP_DATA} | jq -r '.[].description'); do
    # get html title: assumes always the first
    DESCRIPTION=$(curl -s ${URL} | pup 'title json{}' | jq -r '.[0].text // "INVALID_DESCRIPTION"')
    # replace url with title and ignore failures
    sed -i -e 's;"description": "'"${URL}"'",;"description": "'"${DESCRIPTION:=INVALID_DESCRIPTION}"'",;g' $TMP_DATA || true
  done

  echo $(cat ${TMP_DATA})
}

# global param: <DATA_PATH>
# param #1: <json_array>
function append_messages {
  local VALUES=$1
  local TMP_FILE=$(mktemp --suffix ".json")

  # ISSUE getting "Argument list too long" on large input file when using "--argjson"
  # solution: read input, append messages, output to a tmp file and replace input
  # mandatory quotes on argjson value
  cat ${DATA_PATH} | jq \
    --argjson NEW_MESSAGES "${VALUES}" \
    '. += $NEW_MESSAGES' \
    > ${TMP_FILE} && \
    cat ${TMP_FILE} > ${DATA_PATH}
}

function update_front_matter {
  local INDEX_PATH="content/_index.md"
  # extract yaml between "---" (hugo front matter)
  local TITLE=$(cat ${INDEX_PATH} | cut -d'-' -f 1 | yq '.title')
  # all unique sorted tags
  local TAGS="$(cat ${DATA_PATH} | jq '[.[] .tags[] .name] | unique')"
  # convert path to slug
  local FOLDERS="$(cat ${DATA_PATH} | jq '[.[] .path | ltrimstr("/") | rtrimstr("/") | gsub("/";"-")] | unique')"

  echo "---" > ${INDEX_PATH}

  # override tags
  # --null-input tells jq not to read any input at all (it's used when constructing JSON data from scratch)
  jq -n \
    --arg TITLE "${TITLE}" \
    --argjson TAGS "${TAGS}" \
    --argjson FOLDERS "${FOLDERS}" \
    '{"title": $TITLE, "tags": $TAGS, "folders": $FOLDERS}' | \
    yq -P '.' >> ${INDEX_PATH}
  
  echo "---" >> ${INDEX_PATH}
}

##############################

function main {
  echo "[*] current offset: $(get_latest_offset)"
  echo "[*] current count: $(count_messages)"

  local MESSAGES=$(add_description)
  echo -e "[*] new messages:\n${MESSAGES}"

  append_messages "${MESSAGES}"
  update_front_matter

  echo "[*] latest offset: $(get_latest_offset)"
  echo "[*] latest count: $(count_messages)"
}

echo "[+] telegram"
# global
echo "[*] TIMESTAMP=${TIMESTAMP}"
echo "[*] TELEGRAM_API_TOKEN=${TELEGRAM_API_TOKEN}"
echo "[*] TELEGRAM_FROM_ID=${TELEGRAM_FROM_ID}"
# parameter
echo "[*] DATA_PATH=${DATA_PATH}"

curl --version
jq --version
yq --version
pup --version

# TODO interactive bot e.g. suggest latest tags, edit description
# TODO notify success/failure on telegram 
# TODO read DATA_PATH from .awesome.yaml (e.g. version, path, format, template)
# TODO sanitize tags and paths e.g. `[a-zA-Z0-0_\-]`
# TODO gh-action: create archive (e.g. Wayback Machine) and periodically check broken links and replace them
main

echo "[-] telegram"
