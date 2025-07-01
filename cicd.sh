#!/usr/bin/env bash

set -euo pipefail

# Must run this script with zero uncommited changes
if [[ -n $(git status --porcelain) ]]; then
  git status
  exit -1
fi

# --- Configuration ---
SSH_KEY="${HOME}/.ssh/id_rsa" # <-- if deploy: ask for or use this
GIT_URL=$(git ls-remote --get-url)

# --- Script Usage ---
usage() {
    cat <<EOF
Usage: ./cicd.sh [TARGET_BRANCH] [--deploy] [-h|--help]

A simple CICD script for building, testing, and deploying code.

Arguments:
  TARGET_BRANCH      Optional. The branch to merge into (e.g., 'main').
                     If not provided, the script will only build and test the current branch.
  --deploy           Optional. If provided, the script will push to the remote repository on success.
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
        -s|--sync)
            git add --patch
            git status --verbose
            git fetch --keep --all --verbose --prune origin
            git pull -ff --stat --edit
            git commit -a --amend --no-edit
            git push --force-with-lease
        -*)
            echo "Unknown option: $1"
            usage
            exit -1
            ;;
        *)
            if [[ -z "$TARGET_BRANCH" ]]; then
                TARGET_BRANCH="$1"
            else
                echo "Too many arguments. TARGET_BRANCH already set to '$TARGET_BRANCH'"
                usage
                exit -1
            fi
            shift
            ;;
    esac
done


# --- Initial Setup ---
LOCAL_REPO=$(pwd)
CURRENT_BRANCH=$(git branch --show-current)
TMP_BASE=$(cd .. ; mktemp -d)
LOG_DIR="${LOCAL_REPO}/.cicd/logs"
LOG_FILE="${LOG_DIR}/.cicd_$(date +'%Y%m%d_%H%M%S').log"

# --- Logging Setup ---
mkdir -p "$LOG_DIR"
# Redirect stdout and stderr to log file and console
exec > >(tee -a "${LOG_FILE}") 2>&1

# --- Cleanup Function ---
cleanup() {
    if [[ -n "$TMP_BASE" && -d "$TMP_BASE" ]]; then
        echo "Cleaning up temporary workspace..."
        rm -rf "$TMP_BASE"
    fi
    # If ssh-agent got started started by script: also close by script
    if [[ -n "${SSH_AGENT_PID:-}" ]]; then
        eval "$(ssh-agent -k)"
    fi
    echo "Log file saved to: ${LOG_FILE}"
    popd
}
trap cleanup EXIT

# --- Main Script ---
echo "Starting CI/CD job at $(date)"
if $deploy; then 
    # --- SSH Agent Setup (if key is configured) ---
    if [[ -n "${SSH_KEY:-}" && -f "$SSH_KEY" ]]; then
        eval "$(ssh-agent -s)"
        ssh-add "${SSH_KEY}"
    else
        echo "Key not set or found. Proceeding without."
    fi
fi

echo "Ensuring remote repository is reachable..."
if ! git ls-remote --exit-code > /dev/null 2>&1; then
    echo "Error: Remote repository not reachable."
    exit -1
fi

echo
echo "============================="
echo " Starting CI/CD Pipeline "
echo "============================="
echo


echo "Job details:"
if [[ -n "$TARGET_BRANCH" ]]; then
    echo "  Merge '$(git show-branch --sha1-name "$CURRENT_BRANCH")' into '$(git show-branch --sha1-name "$TARGET_BRANCH")'"
else
    echo "  Build and test '$(git show-branch --sha1-name "$CURRENT_BRANCH")'"
fi
if $deploy; then echo "  Deploy to ${GIT_URL}"; fi

echo "Entering temporary workspace..."
pushd "${TMP_BASE}"

# --- Checkout and Update ---
echo
echo "============================="
echo " Checking out.. "
echo "============================="
echo
git clone --local "${LOCAL_REPO}" "${TMP_BASE}" || exit 11
git fetch origin --prune || exit 12
git checkout "$CURRENT_BRANCH" || exit 13
git pull origin "$CURRENT_BRANCH"  || exit 14

# --- Build ---
echo
echo "============================="
echo " Building branch.. "
echo "============================="
echo
if ! "./.cicd/tools/build.sh"; then
    echo
    echo "❌ Build failed."
    exit 2
fi
echo "✅ Build successful."

# --- Test ---
echo
echo "============================="
echo " Running tests.. "
echo "============================="
echo
if ! "./.cicd/tools/test.sh"; then
    echo
    echo "❌ Tests failed."
    exit 3
fi
echo "✅ Tests successful."

# --- Merge Logic ---
if [[ -n "$TARGET_BRANCH" ]]; then

    echo
    echo "============================="
    echo " Merge with ${TARGET_BRANCH}.. "
    echo "============================="
    echo

    echo "Switching to ${TARGET_BRANCH} and merging ${CURRENT_BRANCH}..."
    git checkout "${TARGET_BRANCH}" &&
    git pull origin "$TARGET_BRANCH" || exit 41

    if ! git merge --no-ff --no-edit "$CURRENT_BRANCH"; then
        echo
        echo "❌ Merge failed."
        exit 42
    fi
    echo "✅ Merge successful locally."

    echo
    echo "Building merged code..."
    if ! "./.cicd/tools/build.sh"; then
        echo
        echo "❌ Build failed after merge."
        exit 43
    fi
    echo "✅ Build successful after merge."

    echo
    echo "Testing merged code..."
    if ! "./.cicd/tools/test.sh"; then
        echo
        echo "❌ Tests failed after merge."
        exit 44
    fi
    echo "✅ Tests successful after merge."
fi
# --- Deploy Logic ---
if ! $DEPLOY; then
    echo
    echo "Job finished. --deploy not specified."
    exit 0
fi

echo
echo "============================="
echo " Deploying.. "
echo "============================="
echo

if [[ -n $TARGET_BRANCH ]]; then
    # Send pull request
fi

echo "Pushing merge to remote origin/${TARGET_BRANCH}..."
if ! git push origin "$TARGET_BRANCH"; then
    echo
    echo "❌ Deployment failed: Could not push to remote."
    exit 51
fi

echo "✅ Deployment successful!"
echo
echo "Job finished."
exit 0