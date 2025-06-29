#!/usr/bin/env bash

set -euo pipefail

# --- Configuration ---
# SSH_KEY_PATH="${HOME}/.ssh/id_rsa" # Example path to your private SSH key

# --- Script Usage ---
usage() {
    cat <<EOF
Usage: ./cicd.sh [TARGET_BRANCH] [--deploy] [-h|--help]

A simple CICD script for building, testing, and deploying code.

Arguments:
  TARGET_BRANCH      Optional. The branch to merge into (e.g., 'main').
                     If not provided, the script will only build and test the current branch.
  --deploy           Optional. If provided, the script will push the merge to the remote repository.
                     Requires TARGET_BRANCH to be set.
  -h, --help         Show this help message.
EOF
}

# --- Argument Parsing ---
TARGET_BRANCH=""
DEPLOY=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --deploy)
            DEPLOY=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
        *)
            if [[ -z "$TARGET_BRANCH" ]]; then
                TARGET_BRANCH="$1"
            else
                echo "Too many arguments. TARGET_BRANCH already set to '$TARGET_BRANCH'"
                usage
                exit 1
            fi
            shift
            ;;
    esac
done

if $DEPLOY && [[ -z "$TARGET_BRANCH" ]]; then
    echo "Error: --deploy requires a TARGET_BRANCH to be specified."
    usage
    exit 1
fi

# --- Initial Setup ---
LOCAL_REPO=$(pwd)
CURRENT_BRANCH=$(git branch --show-current)
TMP_BASE=""

# --- Cleanup Function ---
cleanup() {
    if [[ -n "$TMP_BASE" && -d "$TMP_BASE" ]]; then
        echo "Cleaning up temporary workspace..."
        rm -rf "$TMP_BASE"
    fi
    # The ssh-agent is started only if SSH_KEY_PATH is set
    if [[ -n "${SSH_AGENT_PID:-}" ]]; then
        echo "Stopping ssh-agent..."
        eval "$(ssh-agent -k)"
    fi
    echo "Logs can be found in the 'logs' directory if you have redirected them."
}
trap cleanup EXIT

# --- Main Script ---
echo "Starting CI/CD job at $(date)"

# --- SSH Agent Setup (if key is configured) ---
# if [[ -n "${SSH_KEY_PATH:-}" && -f "$SSH_KEY_PATH" ]]; then
#     echo "Starting ssh-agent and adding key..."
#     eval "$(ssh-agent -s)" > /dev/null
#     ssh-add "${SSH_KEY_PATH}"
# else
#     echo "SSH_KEY_PATH not set or key not found. Proceeding without SSH key."
# fi

echo "Ensuring remote repository is reachable..."
if ! git ls-remote --exit-code > /dev/null 2>&1; then
    echo "Error: Remote repository not reachable."
    exit 1
fi

echo
echo "============================="
echo " Starting CI/CD Pipeline "
echo "============================="
echo

if [[ -n "$TARGET_BRANCH" ]]; then
    echo "Job details: Merge ${CURRENT_BRANCH} -> ${TARGET_BRANCH}"
else
    echo "Job details: Build and test ${CURRENT_BRANCH}"
fi
echo "Deploy: ${DEPLOY}"
echo

# --- Create Temporary Workspace ---
echo "Creating temporary workspace..."
TMP_BASE=$(mktemp -d)
git clone --local "${LOCAL_REPO}" "${TMP_BASE}"

cd "${TMP_BASE}"

# --- Checkout and Update ---
echo
echo "================="
echo " Checking out... "
echo "================="
echo
git fetch origin
git checkout "$CURRENT_BRANCH"
git pull origin "$CURRENT_BRANCH"

# --- Build ---
echo
echo "===================="
echo " Building branch... "
echo "===================="
echo
if ! bash "./tools/build.sh"; then
    echo
    echo "❌ Build failed."
    exit 1
fi
echo "✅ Build successful."

# --- Test ---
echo
echo "================="
echo " Running tests.. "
echo "================="
echo
if ! bash "./tools/test.sh"; then
    echo
    echo "❌ Tests failed."
    exit 1
fi
echo "✅ Tests successful."

# --- Merge Logic ---
if [[ -z "$TARGET_BRANCH" ]]; then
    echo
    echo "Job finished. No target branch specified."
    exit 0
fi

echo
echo "============================="
echo " Testing merge with ${TARGET_BRANCH}... "
echo "============================="
echo

echo "Checking out ${TARGET_BRANCH} and merging ${CURRENT_BRANCH}..."
git checkout "$TARGET_BRANCH"
git pull origin "$TARGET_BRANCH"

if ! git merge --no-ff --no-edit "$CURRENT_BRANCH"; then
    echo
    echo "❌ Merge failed."
    exit 1
fi
echo "✅ Merge successful locally."

echo
echo "Building merged code..."
if ! bash "./tools/build.sh"; then
    echo
    echo "❌ Build failed after merge."
    exit 1
fi
echo "✅ Build successful after merge."

echo
echo "Testing merged code..."
if ! bash "./tools/test.sh"; then
    echo
    echo "❌ Tests failed after merge."
    exit 1
fi
echo "✅ Tests successful after merge."

# --- Deploy Logic ---
if ! $DEPLOY; then
    echo
    echo "Job finished. --deploy not specified."
    exit 0
fi

echo
echo "============="
echo " Deploying.. "
echo "============="
echo

echo "Pushing merge to remote origin/${TARGET_BRANCH}..."
if ! git push origin "$TARGET_BRANCH"; then
    echo
    echo "❌ Deployment failed: Could not push to remote."
    exit 1
fi

echo "✅ Deployment successful!"
echo
echo "Job finished."
exit 0
