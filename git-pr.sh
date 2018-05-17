#!/bin/bash 

# this script can be used to submit a PR to Github.

# terminal colors
GREEN='\033[92m'
RED='\033[91m'
BLUE='\033[94m'
YELLOW='\033[0;33m'
RESET='\033[0m'

GITHUB_BASE="https://api.github.com"
REPO_CHECK=$(git rev-parse --is-inside-work-tree 2> /dev/null)

if [ "$REPO_CHECK" != "true" ]; then
  echo "Usage: $0 need to be in root of a git repo"
  exit 1
fi

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
OWNER=$(git remote -v | cut -d$'\t' -f2 | cut -d' ' -f1 | cut -d':' -f2 | cut -d'/' -f1 | head -n1)
REPO_PATH=$(git rev-parse --show-toplevel)
CURRENT_REPO=$(basename $REPO_PATH)

usage() {
  printf "Usage: $0 <command> [args]\n\n"
  printf "A script used for github users to lazy to submit pull requests via github.com\n"
  printf "\nCommands:\n"
  printf "%-30s %s\n" 'help' 'print this help menu'
  printf "%-30s %s\n" 'list' 'list all pull requests open for this repo'
  printf "%-30s %s\n" 'create [target_branch]' 'create a pull request from the current branch to the target branch specified'
  printf "%-30s %s\n" 'merge [pr number]' 'merge PR with given ID number'
  exit 1
}

check_credentials() {
  if [ -z "$GITHUB_USER" ]; then
    echo -n "GITHUB_USERNAME > "
    read GITHUB_USER
  fi

  if [ -z "$GITHUB_PASSWORD" ]; then
    echo -n "GITHUB_PASSWORD (or token) > "
    read -s GITHUB_PASSWORD
    printf "\n"
  fi
}

check_dependencies() {
  # check for jq
  if [ -z $(which jq) ]; then
    if [ ! -z $(which brew) ]; then
      brew install jq
    else
      echo "$RED please install jq. $RESET"
      exit 1
    fi
  fi
}

list_open_prs() {
  check_credentials
  check_dependencies
  url="$GITHUB_BASE/repos/$OWNER/$CURRENT_REPO/pulls?state=open"
  echo $url
  RES=$(curl -s -u "$GITHUB_USER:$GITHUB_PASSWORD" $url)
  printf "$YELLOW Open Pull Requests: $RESET \n"
  echo $RES | jq '.[] | { title: .title, url: .html_url, creator: .user.login  }' 2> /dev/null
}

submit_pr() {
  check_dependencies
  check_credentials
  if [ -z "$TARGET_BRANCH" ]; then
    usage
    exit 1
  fi
  ALL_COMMITS_ON_BRANCH=$(git log $TARGET_BRANCH..$CURRENT_BRANCH --pretty=%B)
  LAST_COMMIT_MSG=$(git log -1 --pretty=%B)

  echo "TITLE (leave blank to use last commit message):"
  read TITLE

  if [ -z "$TITLE" ]; then
    TITLE=$LAST_COMMIT_MSG
    printf "$YELLOW(defaulted to title):$RESET "
    printf "$BLUE$TITLE$RESET \n"
  fi

  echo "BODY(leave blank to use all commits on $CURRENT_BRANCH):"
  read BODY

  if [ -z "$BODY" ]; then
    BODY=$ALL_COMMITS_ON_BRANCH
    printf "$YELLOW(defaulted to body):$RESET "
    printf "$BLUE$BODY$RESET \n"
  fi

  url="$GITHUB_BASE/repos/$OWNER/$CURRENT_REPO/pulls"

  printf '%80s\n' | tr ' ' -
  printf "SUBMITTING: ($GREEN $TARGET_BRANCH $RESET <- $BLUE $CURRENT_BRANCH $RESET)\n"
  echo "...sending request to $url"
  printf '%80s\n' | tr ' ' -

  JSON=$(jq --raw-output --arg key0 'title' --arg value0 "$TITLE" --arg key1 'body' --arg value1 "$BODY" --arg key2 'base' --arg value2 "$TARGET_BRANCH" --arg key3 'head' --arg value3 "$CURRENT_BRANCH" '.  | .[$key0]=$value0 | .[$key1]=$value1 | .[$key2]=$value2 | .[$key3]=$value3 ' <<<'{}' )

  RES=$(curl -s -u "$GITHUB_USER:$GITHUB_PASSWORD" -X POST -H "Content-Type: application/json" \
  $url \
  -d "$JSON")

  PR_URL=$(echo $RES | jq '.html_url'| sed 's/"//g') 

  if [ $PR_URL == "null" ]; then 
    echo $RES | jq
    printf "$RED\nFAILED$RESET Are you sure both branches are in origin? Does this PR already exist? Did you forget your password again?\n"
    exit 1
  else
    printf "$GREEN SUCCESS$RESET pull request created! \n\n$PR_URL\n"
  fi
}

# TODO: fixme
# $ curl -su "$GITHUB_USER:$GITHUB_PASSWORD" https://api.github.com/repos/JCrew-Engineering/terraform-modules/pulls/19 | jq -r '.url'
# https://api.github.com/repos/JCrew-Engineering/terraform-modules/pulls/19
# $ curl -su "$GITHUB_USER:$GITHUB_PASSWORD" https://api.github.com/repos/JCrew-Engineering/terraform-modules/pulls/19/merge
# {
#   "message": "Not Found",
#   "documentation_url": "https://developer.github.com/v3/pulls/#get-if-a-pull-request-has-been-merged"
# }
merge_pr() {
  check_credentials
  check_dependencies
  url="$GITHUB_BASE/repos/$OWNER/$CURRENT_REPO/pulls?state=open"
  PRS=$(curl -s -u "$GITHUB_USER:$GITHUB_PASSWORD" $url)
  SHA=$(echo $PRS | jq -r ".[] | .number=$PR_NUM | .head.sha")
  COMMIT_MSG="merged via script"
  COMMIT_TITLE="merged via script"
  url="$GITHUB_BASE/repos/$OWNER/$CURRENT_REPO/pulls/$PR_NUM/merge"
  echo $url
  JSON=$(jq --raw-output --arg key0 'sha' --arg value0 "$SHA" --arg key1 'commit_title' --arg value1 "$COMMIT_TITLE" --arg key2 'merge_method' --arg value2 "squash" --arg key3 'commit_message' --arg value3 "$COMMIT_MSG" '.  | .[$key0]=$value0 | .[$key1]=$value1 |.[$key2]=$value2|.[$key3]=$value3' <<<'{}' )
  echo $JSON

  RES=$(curl -s -u "$GITHUB_USER:$GITHUB_PASSWORD" -X PUT -H "Content-Type: application/json" \
  $url \
  -d "$JSON")

  echo $RES
}

if [ $# -lt 1 ]; then
  usage
fi

while test $# -gt 0; do
   case "$1" in
        create)
          shift
          TARGET_BRANCH=$1
          submit_pr
          shift
          ;;
        list)
          list_open_prs
          shift
          ;;
        merge)
          shift
          PR_NUM=$1
          merge_pr
          shift
          ;;
        *)
          usage
          return 1;
          ;;
  esac
done  



