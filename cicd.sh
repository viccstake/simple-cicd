#!/usr/bin/env bash

set -euo pipefail

# Usages:
#    Build / test[depth]                      -  Test current branch locally
#    Build / test[depth] / merge              -  Test merge current branch with masterBranch 
#    Build / test[depth] / merge / deploy     -  Try merge current branch with masterBranch on remote

SSHKEY="${HOME}/.ssh/<private-ssh-key-here"
SSHPW=

usage () {
    echo "Usage: cicd [-h]"
    echo "-h:\t Show this message"
}

localRepo=$(pwd)
pulledBranch=$(git branch --show-current)
masterBranch=$1
testingDepth=0
deploy=false
mode='backend'

while getopts 'h' opt; do 
    case "$opt" in
        h) usage ; exit 0;;
        *) usage >&2; exit 1;;
    esac
done
shift $((OPTIND - 1))

cleanup() {
    eval "$(ssh-agent -k)"
    rm -rf "$tmpbase"
    echo "Logs saved at: ${localRepo}/cicd/logs/"
}
trap cleanup EXIT

date ; echo "Starting job.." 
echo "Retrieving credentials.."
eval "$(ssh-agent -s)"
ssh-add "${SSHKEY}" # <-- dk how to do this securely
echo "Ensuring CICD prerequisites.."
if ! (cd "$localRepo" && git ls-remote --exit-code -h); then
    echo "Remote repo not reachable"
    exit 1
fi


echo
echo "\t==========================="
echo "\t Starting CI/CD Pipeline.. "
echo "\t==========================="

echo 
echo "${masterBranch} <-- ${pulledBranch}" || echo "--> ${pulledBranch}"

echo
echo "Creating temporary workspace.."
cd "${localRepo}/.." ; pwd
tmpbase=$(mktemp -d)
cp -vr "${localRepo}" "${tmpbase}"


echo
echo "\t================"
echo "\t Checking out.. "
echo "\t================"

# We assume for now this script might run on any machine in the development area 
#   - Probably just one server in the future
pushd $tmpbase > "/dev/null"
echo
git fetch
git switch "$pulledBranch"
git pull


echo
echo "\t==================="
echo "\t Building branch.. "
echo "\t==================="

# Compile source code and create executables or runnable modules
#   - Must create e.g. .exe files to run/test/deploy
if bash './cicd/resources/build.sh' "$mode"; then 
    echo
    echo "oOo   > Build succesfull <   oOo"
else 
    echo
    echo "xXx  > Build failed <   xXx"
    exit 1
fi


echo
echo "\t================="
echo "\t Running tests.. "
echo "\t================="

# Run different tests for the source code and runnables
if bash './cicd/resources/test.sh' "$mode" "$testingDepth"; then
    echo
    echo "oOo   > Testing succesfull <   oOo"
else
    echo
    echo "xXx  > Testing failed <   xXx"
    exit 1
fi 

if [[ -z "$masterBranch" ]]; then 
    echo
    echo "Closing job.."
    exit 0
fi


echo
echo "\t============================="
echo "\t Testing merge with master.. "
echo "\t============================="

echo
echo "Merging ${pulledBranch} into ${masterBranch}.."
git switch "$masterBranch"
git merge "$pulledBranch" --verify-signatures -v -s subtree || echo ; echo "xXx   > Merge failed <   xXx" ; exit 1

echo 
echo "Building ${masterBranch}.."
if ! './cicd/resources/build.sh'; then 
    echo
    echo "xXx  > Build failed at merge <   xXx"
    exit 1
fi

echo
echo "Testing ${masterBranch}.."
if ! './cicd/resources/test.sh' "$testingDepth"; then
    echo
    echo "xXx  > Testing failed at merge <   xXx"
    exit 1
fi 

echo
echo "oOo   > Merge succesfull <   oOo"

if ! $deploy; then
    echo
    echo "Closing job.."
    exit 0
fi


echo
echo "\t============="
echo "\t Deploying.. "
echo "\t============="

echo
echo "Attempting merge '${masterBranch} <-- ${pulledBranch}' on upstream repository.."
status_code=$(curl(
    ...
))
if [[ $status_code -ne 200 ]]; then 
    echo
    echo "xXx   > Merge failed on origin <   xXx"
    exit 1
else 
    echo
    echo "oOo   > Merge succesfull on origin <   oOo"

echo
echo "Deploying on endpoint.."
if ! './cicd/resources/deploy.sh'; then 
    echo 
    echo "xXx   > Deployment failed on endpoint <   xXx"
    exit 1
fi

echo
echo "oOo   > Deployment succesfull on endpoint <   oOo"

echo
echo "Closing job.."
exit 0