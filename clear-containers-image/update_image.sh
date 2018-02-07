#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh

# Automation script to create specs to build clear-containers-image
# Default image to build is the one specified in file versions.txt
# located at the root of the repository.
set -e

source ../versions.txt
source ../scripts/pkglib.sh

# get versions from clearcontainers/runtime repository
runtime_versions_url="https://raw.githubusercontent.com/clearcontainers/runtime/master/versions.txt"
source <(curl -sL "${runtime_versions_url}")

SCRIPT_NAME=$0
SCRIPT_DIR=$(dirname $0)
PKG_NAME="clear-containers-image"
VERSION=$clear_vm_image_version
RELEASE=$(cat release)

BUILD_DISTROS=(Fedora_26 xUbuntu_16.04)

GENERATED_FILES=(clear-containers-image.spec clear-containers-image.dsc _service debian.rules)
STATIC_FILES=(LICENSE debian.control debian.compat debian.changelog debian.dirs debian.preinst)

COMMIT=false
BRANCH=false
LOCAL_BUILD=false
OBS_PUSH=false
VERBOSE=false

# Parse arguments
cli "$@"

[ "$VERBOSE" == "true" ] && set -x || true
PROJECT_REPO=${PROJECT_REPO:-home:clearcontainers:clear-containers-3-staging/clear-containers-image}
[ -n "$APIURL" ] && APIURL="-A ${APIURL}" || true

# Generate specs using templates
function template()
{
    sed -i s/"clear_vm_image_version=${clear_vm_image_version}"/"clear_vm_image_version=${VERSION}"/ ${SCRIPT_DIR}/../versions.txt

    sed -e "s/\@VERSION\@/$VERSION/g" \
        -e "s/\@RELEASE\@/$RELEASE/g" \
        -e "s/@AGENT_SHA@/${cc_agent_version:0:6}/g" clear-containers-image.spec-template > clear-containers-image.spec

    sed -e "s/\@VERSION\@/$VERSION/g" \
        -e "s/\@RELEASE\@/$RELEASE/g" \
        -e "s/@AGENT_SHA@/${cc_agent_version:0:6}/g" clear-containers-image.dsc-template > clear-containers-image.dsc

    sed -e "s/\@VERSION\@/$VERSION/g" \
        -e "s/@AGENT_SHA@/${cc_agent_version:0:6}/g" debian.rules-template > debian.rules

    sed -e "s/@VERSION@/$VERSION/g" \
        -e "s/@AGENT_SHA@/${cc_agent_version:0:6}/g" _service-template > _service
}

verify
echo "Verify succeed."
get_git_info
image_changes=$(${SCRIPT_DIR}/../scripts/get-image-changes.sh $VERSION | awk '{if (/^version/) print "  * "$0; else print "  "$0"\n"}')
changelog_update $VERSION
template

if [ "$LOCAL_BUILD" == "true" ] && [ "$OBS_PUSH" == "true" ]
then
	die "--local-build and --push are mutually exclusive."
elif [ "$LOCAL_BUILD" == "true" ]
then
	checkout_repo $PROJECT_REPO
	local_build
	
elif [ "$OBS_PUSH" == "true" ]
then
	checkout_repo $PROJECT_REPO
	obs_push $PKG_NAME
fi
echo "OBS working copy directory: ${OBS_WORKDIR}"
