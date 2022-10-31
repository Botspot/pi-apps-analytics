#!/bin/bash

# this script will attempt to parse the pi-apps repository and generate a json file with the current pi-apps apps
# each app will have a standard format in the json including architecture support (or package app), description, credits, current version (if applicable)

applist="$(ls /tmp/pi-apps/apps | grep .)"
echo "$applist"

# generate repository json from scratch
jq --null-input '[]' >"$GITHUB_WORKSPACE/package_data.json"

#install links
IFS=$'\n'
for app in $applist; do
  cd "/tmp/pi-apps/apps/$app"
  name="$app"
  version_number=""
  #check for the first version variable
  if [ -f install-32 ]; then
    version="$(cat 'install-32' | grep -m 1 "^version${version_number}=" | sed "s/version${version_number}=//" | xargs)"
  fi

  if [ -f install-64 ] && [ -z "$version" ]; then
    version="$(cat 'install-64' | grep -m 1 "^version${version_number}=" | sed "s/version${version_number}=//" | xargs)"
  fi

  if [ -f install ]; then
    version="$(cat 'install' | grep -m 1 "^version${version_number}=" | sed "s/version${version_number}=//" | xargs)"
  fi
  unset version_number

  read -r 2>/dev/null description <"description" || description="Description unavailable"
  url="$(cat website)"
  if [ -f install-64 ] && [ -f install-32 ]; then
    arch="ARM32/ARM64"
  elif [ -f install-64 ]; then
    arch="ARM64"
  elif [ -f install-32 ]; then
    arch="ARM32"
  elif [ -f install ]; then
    arch="ARM32/ARM64"
  elif [ -f packages ]; then
    arch="package"
  fi
  users=$(cat "$GITHUB_WORKSPACE/clicklist" | grep "[0-9] "$app""'$' | awk '{print $1}' | head -n1)
  cat "$GITHUB_WORKSPACE/package_data.json" | jq -s '.[] + [{"Name": "'"$name"'", "Version": "'"$version"'", "Description": "'"$description"'", "URL": "'"$url"'", "Architecture": "'"$arch"'", "Users": "'"$users"'"}]' | sponge "$GITHUB_WORKSPACE/package_data.json"
  unset url arch description version
done
cd $GITHUB_WORKSPACE
