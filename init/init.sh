#!/bin/bash

# This script initializes the CICD tool in an existing git repository.

# It just copies files and can prompt user for necessary info
#   As submodule: server=true and then manual git submodule setup
#   Repository-wide: installer-setup for all machines (.gitignore will block key-components)

set -e

# The directory where this script is located
INIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The root directory of the cicdpipe tool
CICD_ROOT_DIR="$(dirname "$INIT_DIR")"

# The target directory where the tool will be initialized
TARGET_DIR="${1:-.}"

if [ ! -d "$TARGET_DIR/.git" ]; then
  echo "Error: Target directory is not a git repository."
  exit 1
fi

# The directory where the cicd tools will be copied
CICD_DIR="$TARGET_DIR/.cicd"
REPO_NAME=$(git remote get-url origin | sed -E 's/.*\/(.+)\.git$/\1/')

echo "\t< Deploy CICD tool for '${REPO_NAME}' >"

mkdir -vp "$CICD_DIR"

# Copy the cicd tools to the target directory
cp -vr "$CICD_ROOT_DIR/tools" "$CICD_DIR/"
cp -v  "$CICD_ROOT_DIR/cicd.sh" "$CICD_DIR/"

while read -p "Configure with server? [Y/n]" answr; do
if [[ "${answr:^^}" == 'Y' ]]; then 
  server=true
  break
elif [[ "${answr:^^}" == 'N' ]]; then
  server=false
  break
else
  echo "Bad choice '${answr}'."
fi;done

# With server?
if $server; then cp -v  "$CICD_ROOT_DIR/tailscale_server.py" "$CICD_DIR/"; fi

echo "Blank CICD tool initialized in $TARGET_DIR."

read -p "Configure cicd with installer? [Y/n]\n  > " answr

if [[ ${answr:^^} != 'Y' ]]; then exit 0; fi

cd "$CICD_DIR"

SSH_KEY_PATH=""
while read -p "Enter full path of ssh private key\n  > " keyPath; do
if [[ ! -f "$keyPath" ]]; then
  echo "File not found: ${keyPath}"
else
  echo "Chose ssh_key: ${keyPath}"
  if [[ $(read -p "Continue? [Y/n]\n  > "):^^ == 'N']]; then continue; fi
  SSH_KEY_PATH=$keyPath
fi
done

    cat <<EOF
What you still need to do:
  > Create an appropriate "build-call" in 'tools/build.sh' for main branch.
  > Create an appropriate "test-call" in 'tools/test.sh' for main branch.
  > Continously add branch-specific build/test-code and let git merge them with the application.

Usage: ./cicd.sh [TARGET_BRANCH] [--deploy] [-h|--help]

Arguments:
  TARGET_BRANCH      Optional. The branch to merge into (e.g., 'main').
                     If not provided, the script will only build and test the current branch.
  --deploy           Optional. If provided, the script will push to the remote repository on success.
  -h, --help         Show this help message.
EOF

