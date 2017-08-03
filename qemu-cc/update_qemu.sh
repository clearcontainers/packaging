#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh

# Automation script to create specs to build clear containers kernel
set -e

source ../versions.txt
source ../scripts/pkglib.sh

SCRIPT_NAME=$0
SCRIPT_DIR=$(dirname $0)
PKG_NAME="qemu-cc"
VERSION=$qemu_cc_version
RELEASE=$(cat release)
APPORT_HOOK="source_qemu-cc.py"

BUILD_DISTROS=(Fedora_26)

GENERATED_FILES=(_service qemu-cc.dsc qemu-cc.spec)
STATIC_FILES=(debian.compat debian.control *.patch debian.rules)

COMMIT=false
BRANCH=false
LOCAL_BUILD=false
OBS_PUSH=false
VERBOSE=false

# Parse arguments
cli "$@"

[ "$VERBOSE" == "true" ] && set -x || true
PROJECT_REPO=${PROJECT_REPO:-home:clearcontainers:clear-containers-3-staging/qemu-cc}
[ -n "$APIURL" ] && APIURL="-A ${APIURL}" || true

# Generate specs using templates
function template(){
    sed -e "s/@VERSION@/$VERSION/" \
        -e "s/@REVISION@/qemu-lite-v$VERSION/" \
        _service-template > _service

    sed -e "s/@QEMU_CC_HASH@/${qemu_cc_hash:0:10}/" \
        -e "s/@VERSION@/$VERSION/" \
        -e "s/@RELEASE@/$RELEASE/" \
        qemu-cc.spec-template > qemu-cc.spec

    sed -e "s/@VERSION@/$VERSION/" \
        -e "s/@VERSION@/$VERSION/" \
        -e "s/@QEMU_CC_HASH@/${qemu_cc_hash:0:10}/" \
        -e "s/@RELEASE@/$RELEASE/" \
        qemu-cc.dsc-template > qemu-cc.dsc
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
	obs_push "cc-runtime"
fi
echo "OBS working copy directory: ${OBS_WORKDIR}"
