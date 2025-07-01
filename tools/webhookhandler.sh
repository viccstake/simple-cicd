#!/usr/bin/env bash

set -euo pipefail

echo "Running webhook action script..."

# --- Webhook Payload ---
# This script is expected to be called by an automation server (e.g., automation_server.py)
# that receives webhooks from your Git provider.
# The server might pass information from the webhook as arguments to this script.

PULLED_BRANCH=${1:-} # Default to empty string if no argument is provided

if [[ -z "$PULLED_BRANCH" ]]; then
    echo "No branch specified. Exiting."
    exit 0 # Exit gracefully if no action is needed
fi

echo "Webhook triggered for branch: $PULLED_BRANCH"

# --- Add your automated actions below ---

# Example action

echo "Switching to branch '$PULLED_BRANCH'..."
git fetch --keep --all --verbose origin
git checkout "$PULLED_BRANCH"
git pull origin "$PULLED_BRANCH"

# echo "Running CICD deployment to main..."
# ./cicd.sh main --deploy

echo "Webhook action script finished."

exit 0
