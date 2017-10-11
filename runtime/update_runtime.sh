#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh
#
# Automation script to create specs to build cc-runtime
# Default: Build is the one specified in file configure.ac
# located at the root of the repository.
set -x
AUTHOR=${AUTHOR:-$(git config user.name)}
AUTHOR_EMAIL=${AUTHOR_EMAIL:-$(git config user.email)}

source ../versions.txt
VERSION=$cc_runtime_version

# If we are providing the branch or hash to build, assign it to OBS_REVISION
if [ -n "$1" ]; then
     OBS_REVISION=$1

     # Validate input is alphanumeric, commit ID
     # If a commit ID is provided, override versions.txt one
     if [[ "$OBS_REVISION" =~ ^[a-zA-Z0-9][-a-zA-Z0-9]{0,40}[a-zA-Z0-9]$  ]]; then
         hash_tag=$OBS_REVISION
     else
         hash_tag=$cc_runtime_hash
     fi
else
         hash_tag=$cc_runtime_hash
fi
short_hashtag="${hash_tag:0:7}"

OBS_PUSH=${OBS_PUSH:-false}
OBS_RUNTIME_REPO=${OBS_RUNTIME_REPO:-home:clearcontainers:clear-containers-3-staging/cc-runtime}
OBS_APIURL=${OBS_APIURL:-""}

# This allows to point to internal/private OBS instance
if [ "$OBS_APIURL" != "" ]; then
    APIURL="-A ${OBS_APIURL}"
else
    APIURL=""
fi

echo "Running: $0 $@"
echo "Update cc-runtime $VERSION: ${hash_tag:0:7}"

function changelog_update {
    d=$(date +"%a, %d %b %Y %H:%M:%S %z")
    git checkout debian.changelog
    cp debian.changelog debian.changelog-bk
    cat <<< "cc-runtime ($VERSION) stable; urgency=medium

  * Update cc-runtime $VERSION ${hash_tag:0:7}

 -- $AUTHOR <$AUTHOR_EMAIL>  $d
" > debian.changelog
    cat debian.changelog-bk >> debian.changelog
    rm debian.changelog-bk
}
changelog_update $VERSION

RELEASE=$(($(cat release) + 1))
echo $RELEASE > release

sed -e "s/@VERSION@/$VERSION/g" \
    -e "s/@RELEASE@/$RELEASE/g" \
    -e "s/@HASH@/$short_hashtag/g" \
    -e "s/@cc_proxy_version@/$proxy_obs_fedora_version/" \
    -e "s/@cc_shim_version@/$shim_obs_fedora_version/" \
    -e "s/@cc_image_version@/$image_obs_fedora_version/" \
    -e "s/@linux_container_version@/$linux_container_obs_fedora_version/" \
    -e "s/@qemu_lite_obs_fedora_version@/$qemu_lite_obs_fedora_version/g" cc-runtime.spec-template > cc-runtime.spec

sed -e "s/@VERSION@/$VERSION/" \
    -e "s/@HASH@/$short_hashtag/" debian.rules-template > debian.rules

sed -e "s/@VERSION@/$VERSION/g"\
    -e "s/@RELEASE@/$RELEASE/g" \
    -e "s/@HASH@/$short_hashtag/g" \
    -e "s/@cc_proxy_version@/$proxy_obs_ubuntu_version/" \
    -e "s/@cc_shim_version@/$shim_obs_ubuntu_version/" \
    -e "s/@cc_image_version@/$image_obs_ubuntu_version/" \
    -e "s/@qemu_lite_version@/$qemu_lite_obs_ubuntu_version/" \
    -e "s/@linux_container_version@/$linux_container_obs_ubuntu_version/" \
    -e "s/@qemu_lite_obs_ubuntu_version@/$qemu_lite_obs_ubuntu_version/" cc-runtime.dsc-template > cc-runtime.dsc

sed -e "s/@VERSION@/$VERSION/" \
    -e "s/@HASH_TAG@/$short_hashtag/" \
    -e "s/@cc_proxy_version@/$proxy_obs_ubuntu_version/" \
    -e "s/@cc_shim_version@/$shim_obs_ubuntu_version/" \
    -e "s/@cc_image_version@/$image_obs_ubuntu_version/" \
    -e "s/@qemu_lite_version@/$qemu_lite_obs_ubuntu_version/" \
    -e "s/@linux_container_version@/$linux_container_obs_ubuntu_version/" \
    -e "s/@qemu_lite_obs_ubuntu_version@/$qemu_lite_obs_ubuntu_version/"  debian.control-template > debian.control

# If OBS_REVISION is not empty, which means a branch or commit ID has been passed as argument,
# replace It as @REVISION@ it in the OBS _service file. Otherwise, use the VERSION variable,
# which uses the version from versions.txt.
# This will determine which source tarball will be retrieved from github.com
if [ -n "$OBS_REVISION" ]; then
    sed "s/@REVISION@/$OBS_REVISION/" _service-template > _service
else
    sed "s/@REVISION@/$VERSION/"  _service-template > _service
fi

# Update and package OBS
if [ "$OBS_PUSH" = true ]
then
    temp=$(basename $0)
    TMPDIR=$(mktemp -d -u -t ${temp}.XXXXXXXXXXX) || exit 1
    osc $APIURL co "$OBS_RUNTIME_REPO" -o $TMPDIR

    mv cc-runtime.spec \
       cc-runtime.dsc \
       debian.control \
       debian.rules \
        _service \
        $TMPDIR
    rm $TMPDIR/*.patch
    [ -f $TMPDIR/debian.series ] && rm $TMPDIR/debian.series || :
    cp debian.changelog \
        debian.compat \
        cc-runtime-bin.install \
        cc-runtime-config.install \
        *.patch \
        $TMPDIR

    cp ../scripts/apport_hook.py $TMPDIR/source_cc-runtime.py

    [ -f debian.series ] && cp debian.series $TMPDIR || :
    cd $TMPDIR

    if [ -e "go1.8.3.linux-amd64.tar.gz" ]; then
        rm go*.tar.gz
    fi
    osc $APIURL addremove
    osc $APIURL commit -m "Update cc-runtime $VERSION: ${hash_tag:0:7}"
fi
