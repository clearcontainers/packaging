#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh

# Automation script to create specs to build clear containers kernel
set -e

source ../versions.txt
source ../scripts/pkglib.sh

SCRIPT_NAME=$0
SCRIPT_DIR=$(dirname $0)
PKG_NAME="linux-container"
VERSION=$clear_vm_kernel_version
RELEASE=$(cat release)
BUILD_DISTROS=(Fedora_26 xUbuntu_16.04)

KR_CONFIG_FILENAME=kernel-config-4.9.x
KR_REL=https://www.kernel.org/releases.json
KR_SHA=https://cdn.kernel.org/pub/linux/kernel/v4.x/sha256sums.asc
KR_LTS=4.9

GENERATED_FILES=(linux-container.dsc linux-container.spec _service config)
STATIC_FILES=(debian.dirs debian.rules debian.compat debian.control debian.copyright patches-4.9.x/*.patch)
OBS_CC_KERNEL_REPO=${OBS_CC_KERNEL_REPO:-home:clearcontainers:clear-containers-3-staging/$PKG_NAME}

COMMIT=false
BRANCH=false
LOCAL_BUILD=false
OBS_PUSH=false
VERBOSE=false

# Parse arguments
cli "$@"

[ "$VERBOSE" == "true" ] && set -x || true
PROJECT_REPO=${PROJECT_REPO:-home:clearcontainers:clear-containers-3-staging/linux-container}
[ -n "$APIURL" ] && APIURL="-A ${APIURL}" || true
if [ "${VERSION}" == "latest" ]
then
    VERSION=$(curl -L -s -f ${KR_REL} | grep "${KR_LTS}" | grep version | cut -f 4 -d \" | grep "^${KR_LTS}")
fi

kernel_sha256=$(curl -L -s -f ${KR_SHA} | awk '/linux-'${VERSION}'.tar.xz/ {print $1}')

# Copy the kernel config file
cp $KR_CONFIG_FILENAME config

# Generate specs using templates
function template()
{
    sed "s/\@VERSION\@/$VERSION/g; s/\@RELEASE\@/$RELEASE/g" linux-container.spec-template > linux-container.spec
    sed "s/\@VERSION\@/$VERSION/g; s/\@RELEASE\@/$RELEASE/g" linux-container.dsc-template > linux-container.dsc
    sed "s/\@VERSION\@/$VERSION/g; s/\@KERNEL_SHA256\@/$kernel_sha256/g" _service-template > _service
}

verify
echo "Verify succeed."
get_git_info
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
	obs_push "linux-container"
fi
echo "OBS working copy directory: ${OBS_WORKDIR}"
