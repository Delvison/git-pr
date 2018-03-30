#!/bin/bash 

# this script can be used to submit a PR to Github.

# terminal colors
GREEN='\033[92m'
RED='\033[91m'
BLUE='\033[94m'
YELLOW='\033[0;33m'
RESET='\033[0m'

# is_branch_in_remote() {
#   GITHUB_BRANCHES=$(git ls-remote --heads)
#   if [ -z $(echo $GITHUB_BRANCHES | grep $CURRENT_BRANCH) ]; then
#     echo "Are you sure $CURRENT_REMOTE_CHECK is in origin?"
#   fi
#   if [ -z $(echo $GITHUB_BRANCHES | grep $TARGET_BRANCH) ]; then
#     echo "Are you sure $TARGET_REMOTE_CHECK is in origin?"
#   fi
# }

if [ ! -d .git ]; then
  echo "Usage: $0 need to be in root of a git repo"
  exit 1
fi

TARGET_BRANCH=$1
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
OWNER=$(git remote -v | cut -d$'\t' -f2 | cut -d' ' -f1 | cut -d':' -f2 | cut -d'/' -f1 | head -n1)
REPO_PATH=$(git rev-parse --show-toplevel)
CURRENT_REPO=$(basename $REPO_PATH)

if [ $# -lt 1 ]; then
  echo "Usage: $0 [target branch to merge to]"
  exit 1
fi

# check for jq
if [ -z $(which jq) ]; then
  echo "please install jq"
fi

if [ -z $GITHUB_USER ]; then
  echo -n "GITHUB_USERNAME > "
  read GITHUB_USER
fi

if [ -z $GITHUB_PASSWORD ]; then
  echo -n "GITHUB_PASSWORD > "
  read -s GITHUB_PASSWORD
  printf "\n"
fi

LAST_COMMIT_MSG=$(git log -1 --pretty=%B)
ALL_COMMITS_ON_BRANCH=$(git log $TARGET_BRANCH..$CURRENT_BRANCH --pretty=%B)

echo "TITLE (leave blank to use last commit message):"
read TITLE

if [ -z $TITLE ]; then
  TITLE=$LAST_COMMIT_MSG
  printf "$YELLOW(defaulted to title):$RESET "
  printf "$BLUE$TITLE$RESET \n"
fi

echo "BODY(leave blank to use all commits on $CURRENT_BRANCH):"
read BODY

if [ -z $BODY ]; then
  BODY=$ALL_COMMITS_ON_BRANCH
  printf "$YELLOW(defaulted to body):$RESET "
  printf "$BLUE$BODY$RESET \n"
fi

url="https://api.github.com/repos/$OWNER/$CURRENT_REPO/pulls"

printf '%80s\n' | tr ' ' -
printf "SUBMITTING: ($GREEN $TARGET_BRANCH $RESET <- $BLUE $CURRENT_BRANCH $RESET)\n"
echo "...sending request to $url"
printf '%80s\n' | tr ' ' -

RES=$(curl -s -u "$GITHUB_USER:$GITHUB_PASSWORD" -X POST -H "Content-Type: application/json" \
$url \
-d  "{ \"title\": \"$TITLE\", \
\"body\": \"$BODY\", \
\"base\": \"$TARGET_BRANCH\", \
\"head\": \"$CURRENT_BRANCH\"}")

PR_URL=$(echo $RES| jq '.html_url'| sed 's/"//g') 

if [ $PR_URL == "null" ]; then 
  echo $RES | jq
  printf "$RED\nFAILED$RESET Are you sure both branches are in origin? Does this PR already exist? Did you forget your password again?\n"
  exit 1
else
  printf "$GREEN SUCCESS$RESET pull request created! \n\n$PR_URL\n"
fi

