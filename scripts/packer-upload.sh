#!/usr/bin/env bash

# thank you for this script ladar: https://github.com/hashicorp/packer/issues/6615#issuecomment-424422764
# had to fix something, because they were either uncessary or apparently not applicable any more in 2.2.4 of vagrant

# normal
set -eo pipefail
# debug
# set -exo pipefail

ORG="$1"
NAME="$2"
PROVIDER="$3"
VERSION="$4"
FILE="$5"

if [[ ! -z $CIRCLECI ]] ; then
  CIRCLECI=''
fi

# declaring after passed args because they are "undeclared"
set -u

CURL='curl'

help(){
  printf "Example:,%s,double16,linux-dev-workstation,virtualbox,201809.1,box/virtualbox/linux-dev-workstation-201809.1.box\n" "$(basename ${0})" | column -s ',' -t -N " ,Script Name,Org Name,Name of box,Provider,Version,File Path"
  printf "\nOther Arguments/flags:\n"
  printf "\t%s) print this help section\n" '-h|--help'
  exit 1
}

if [[ $# -eq 0 ]] ; then
  help
else
  case $1 in
    -h|--help)
        help
      ;;
  esac
fi

# Cross platform scripting directory plus munchie madness.
pushd $(dirname $0) > /dev/null
BASE="$(pwd -P)VAGRANT_CLOUD_TOKEN"
popd > /dev/null

# The jq tool is needed to parse JSON responses.
if [ ! -f /usr/bin/jq ]; then
  tput setaf 1; printf "\n\nThe 'jq' utility is not installed.\n\n\n"; tput sgr0
  exit 1
fi

# Ensure the credentials file is available.
if [[ -z $CIRCLECI ]] ; then
  if [ -f $BASE/.credentialsrc ]; then
    source $BASE/.credentialsrc
  else
    tput setaf 1; printf "\nError. The credentials file is missing.\n\n"; tput sgr0
    exit 1
  fi
fi

if [ -z ${VAGRANT_CLOUD_TOKEN} ]; then
  tput setaf 1; printf "\nError. The vagrant cloud token is missing. Add it to the credentials file.\n\n"; tput sgr0
fi
  
# these don't seem to exist in version 2.2.4
# CURL=/opt/vagrant/embedded/bin/curl
# LD_PRELOAD="/opt/vagrant/embedded/lib/libcrypto.so:/opt/vagrant/embedded/lib/libssl.so"

# don't appear to be needed since repeated from above
# # Cross platform scripting directory plus munchie madness.
# pushd $(dirname $0) > /dev/null
# BASE=$(pwd -P)
# popd > /dev/null
#
# # The jq tool is needed to parse JSON responses.
# if [ ! -f /usr/bin/jq ]; then
#   tput setaf 1; printf "\n\nThe 'jq' utility is not installed.\n\n\n"; tput sgr0
#   exit 1
# fi
#
# # Ensure the credentials file is available.
# if [ -f $BASE/../../.credentialsrc ]; then
#   source $BASE/../../.credentialsrc
# else
#   tput setaf 1; printf "\nError. The credentials file is missing.\n\n"; tput sgr0
#   exit 1
# fi
#
# if [ -z ${VAGRANT_CLOUD_TOKEN} ]; then
#   tput setaf 1; printf "\nError. The vagrant cloud token is missing. Add it to the credentials file.\n\n"; tput sgr0
#   exit 1
# fi

printf "\n\n"

# Assume the position, while you create the version.
${CURL} \
  --tlsv1.2 \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
  "https://app.vagrantup.com/api/v1/box/$ORG/$NAME/versions" \
  --data "
    {
      \"version\": {
        \"version\": \"$VERSION\",
        \"description\": \"A build environment for use in cross platform development.\"
      }
    }
  "
printf "\n\n"

# Create the provider, while become one with your inner child.
${CURL} \
  --tlsv1.2 \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
  https://app.vagrantup.com/api/v1/box/$ORG/$NAME/version/$VERSION/providers \
  --data "{ \"provider\": { \"name\": \"$PROVIDER\" } }"

printf "\n\n"

# Prepare an upload path, and then extract that upload path from the JSON
# response using the jq command.
UPLOAD_PATH=$(${CURL} \
  --tlsv1.2 \
  --silent \
  --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
  https://app.vagrantup.com/api/v1/box/$ORG/$NAME/version/$VERSION/provider/$PROVIDER/upload | jq -r .upload_path)

# Perform the upload, and see the bits boil.
${CURL} --tlsv1.2 --include --max-time 7200 --expect100-timeout 7200 --request PUT --output "$FILE.upload.log.txt" --upload-file "$FILE" "$UPLOAD_PATH"

printf "\n-----------------------------------------------------\n"
tput setaf 5
cat "$FILE.upload.log.txt"
tput sgr0
printf -- "-----------------------------------------------------\n\n"

# Release the version, and watch the party rage.
${CURL} \
  --tlsv1.2 \
  --silent \
  --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
  https://app.vagrantup.com/api/v1/box/$ORG/$NAME/version/$VERSION/release \
  --request PUT | jq '.status,.version,.providers[]' | grep -vE "hosted|hosted_token|original_url|created_at|updated_at|\}|\{"

printf "\n\n"
