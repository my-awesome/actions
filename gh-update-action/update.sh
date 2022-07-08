#!/bin/bash

set -euo pipefail

##############################

PARAM_GIT_USER_EMAIL=${1:?"Missing GIT_USER_EMAIL"}
PARAM_GIT_USER_NAME=${2:?"Missing GIT_USER_NAME"}

# uses TIMESTAMP and GITHUB_TOKEN from env
GIT_BRANCH="telegram-${TIMESTAMP//:/-}"
PR_TITLE="[telegram-bot] $TIMESTAMP"
PR_MESSAGE="Updates telegram: $TIMESTAMP"

##############################

echo "[+] update"

gh --version

# 1 line string
GIT_STATUS=$(git status)

# updates only if there are changes
if [[ -z "${GIT_STATUS##*nothing to commit*}" ]]; then
  echo "[-] No changes"
else
  echo "[-] Updating repository ..."
  echo "[*] TIMESTAMP=${TIMESTAMP}"

  # mandatory configs
  git config user.email $GIT_USER_EMAIL
  git config user.name $GIT_USER_NAME

  # must be on a different branch
  git checkout -b $GIT_BRANCH
  git add .
  git status

  # fails without quotes: "quote all values that have spaces"
  git commit -m "$PR_MESSAGE"
  git push origin $GIT_BRANCH
  gh pr create --head $GIT_BRANCH --title "$PR_TITLE" --body "$PR_MESSAGE"

  # automatically merge and cleanup
  gh pr merge $GIT_BRANCH --merge --delete-branch
fi

echo "[-] update"
