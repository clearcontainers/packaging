#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh
#
# Automation script to create specs to build cc-runtime
# Default: Build is the one specified in file configure.ac
# located at the root of the repository.
set -e

source ../versions.txt
source ../scripts/pkglib.sh

SCRIPT_NAME=$0
SCRIPT_DIR=$(dirname $0)
PKG_NAME="cc-runtime"
VERSION=$cc_runtime_version
RELEASE=$(cat release)
APPORT_HOOK="source_cc-runtime.py"

BUILD_DISTROS=(Fedora_26 xUbuntu_16.04)

GENERATED_FILES=(cc-runtime.spec cc-runtime.dsc debian.control debian.rules _service)
STATIC_FILES=(debian.compat cc-runtime-bin.install cc-runtime-config.install debian.postinst)

COMMIT=false
BRANCH=false
LOCAL_BUILD=false
OBS_PUSH=false
VERBOSE=false

# Parse arguments
cli "$@"

[ "$VERBOSE" == "true" ] && set -x || true
PROJECT_REPO=${PROJECT_REPO:-home:clearcontainers:clear-containers-3-staging/cc-runtime}
[ -n "$APIURL" ] && APIURL="-A ${APIURL}" || true

# Generate specs using templates
function template()
{
    sed -e "s/@VERSION@/$VERSION/g" \
	    -e "s/@RELEASE@/$RELEASE/g" \
	    -e "s/@HASH@/$short_hashtag/g" \
	    -e "s/@cc_proxy_version@/$proxy_obs_fedora_version/" \
	    -e "s/@cc_shim_version@/$shim_obs_fedora_version/" \
	    -e "s/@cc_image_version@/$image_obs_fedora_version/" \
	    -e "s/@linux_container_version@/$linux_container_obs_fedora_version/" \
	    -e "s/@qemu_lite_obs_fedora_version@/$qemu_lite_obs_fedora_version/g" \
	    -e "s/@GO_VERSION@/$go_version/" \
	    cc-runtime.spec-template > cc-runtime.spec

    sed -e "s/@VERSION@/$VERSION/" \
        -e "s/@HASH@/$short_hashtag/" \
        -e "s/@GO_VERSION@/$go_version/" \
        debian.rules-template > debian.rules

    sed -e "s/@VERSION@/$VERSION/g"\
	    -e "s/@RELEASE@/$RELEASE/g" \
	    -e "s/@HASH@/$short_hashtag/g" \
	    -e "s/@cc_proxy_version@/$proxy_obs_ubuntu_version/" \
	    -e "s/@cc_shim_version@/$shim_obs_ubuntu_version/" \
	    -e "s/@cc_image_version@/$image_obs_ubuntu_version/" \
	    -e "s/@qemu_lite_version@/$qemu_lite_obs_ubuntu_version/" \
	    -e "s/@linux_container_version@/$linux_container_obs_ubuntu_version/" \
	    -e "s/@qemu_lite_obs_ubuntu_version@/$qemu_lite_obs_ubuntu_version/" \
	    cc-runtime.dsc-template > cc-runtime.dsc

    sed -e "s/@VERSION@/$VERSION/" \
	    -e "s/@HASH_TAG@/$short_hashtag/" \
	    -e "s/@cc_proxy_version@/$proxy_obs_ubuntu_version/" \
	    -e "s/@cc_shim_version@/$shim_obs_ubuntu_version/" \
	    -e "s/@cc_image_version@/$image_obs_ubuntu_version/" \
	    -e "s/@qemu_lite_version@/$qemu_lite_obs_ubuntu_version/" \
	    -e "s/@linux_container_version@/$linux_container_obs_ubuntu_version/" \
	    -e "s/@qemu_lite_obs_ubuntu_version@/$qemu_lite_obs_ubuntu_version/"  \
	    debian.control-template > debian.control

    # If OBS_REVISION is not empty, which means a branch or commit ID has been passed as argument,
    # replace It as @REVISION@ it in the OBS _service file. Otherwise, use the VERSION variable,
    # which uses the version from versions.txt.
    # This will determine which source tarball will be retrieved from github.com
    if [ -n "$OBS_REVISION" ]; then
        sed -e "s/@REVISION@/$OBS_REVISION/" \
            -e "s/@GO_VERSION@/$go_version/g" \
            -e "s/@GO_CHECKSUM@/$go_checksum/" \
            _service-template > _service
    else
        sed -e "s/@REVISION@/$VERSION/" \
            -e "s/@GO_VERSION@/$go_version/g" \
            -e "s/@GO_CHECKSUM@/$go_checksum/" \
            _service-template > _service
    fi
}

verify
echo "Verify succeed."
get_git_info
set_versions $cc_runtime_hash
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
