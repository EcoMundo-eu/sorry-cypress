#!/bin/bash

set -e

BRANCH=$(echo ${GITHUB_REF} | sed -e "s/refs\/heads\///g" | sed -e "s/\//-/g")
TAGS=""

echo BRANCH $BRANCH
echo GITHUB_REF $GITHUB_REF

function isGitTag() {
  [ $(echo "${GITHUB_REF}" | sed -e "s/refs\/tags\///g") != "${GITHUB_REF}" ]
}

function isOnMaster() {
  [ "${BRANCH}" = "master" ]
}

function getCleanTags() {
  echo $(echo ${GITHUB_REF} | sed -e "s/refs\/tags\///g")
}
function isSemver() {
  local cleanTags="$(getCleanTags)"
  local isSemver=$(./scripts/isSemver.js $cleanTags)
  [ "$isSemver" == "true" ]
}

function setDockerTags() {
  if isOnMaster; then
    TAGS="$TAGS latest"
  fi;

  if isGitTag && isSemver "${GITHUB_REF}"; then
    local cleanTags="$(getCleanTags)"
    TAGS=$(./scripts/generateSemverTags.js $cleanTags)
  fi;
}

function getTagsArg() {
  for TAG in ${TAGS}
  do
    echo "--tag ${1}:${TAG} "
  done
}

function dockerBuildAndPush() {
  echo 🔨 Building ${2} from ${1}: docker buildx --file ${1}/Dockerfile --platform=linux/arm64,linux/amd64 $(getTagsArg ${2}) --provenance=false --push
  echo ========================
  docker buildx create --use
  docker buildx build --file ${1}/Dockerfile --platform=linux/arm64,linux/amd64 $(getTagsArg ${2}) --provenance=false --push .
  echo ========================
  echo ✅ Build \& push completed ${2} from ${1}
}

# ./scripts/release-dockerhub.sh -t cypress-v5
while getopts t:s: flag
do
    case "${flag}" in
        t) explicitTag=${OPTARG};;
        s) service=${OPTARG};;
    esac
done

if [ -z "${service}" ]; then
  echo "Missing service: -s api|dashboard|director";
  exit 1;
fi

if [ -z "${BRANCH}" ]
then
  echo "Explicit tag: $explicitTag";
  TAGS=${explicitTag}
else
  echo "Gettings tags from git data"
  setDockerTags
fi

echo 🚀 Releasing tags: $TAGS
echo ========================

dockerBuildAndPush "packages/${service}" "ecomundoit/sorry-cypress-${service}"
# dockerBuildAndPush "packages/api" "ecomundoit/sorry-cypress-api"
# dockerBuildAndPush "packages/dashboard" "ecomundoit/sorry-cypress-dashboard"

echo ========================
echo 🎉 Released to Dockerhub: $TAGS