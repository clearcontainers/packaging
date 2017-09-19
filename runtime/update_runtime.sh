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
VERSION=${1:-$cc_runtime_version}
# 3.0.0-beta.X format cause errors while packaging.
# Remove the dash in order to be able to build. The
# original string will remain in the packages and
# in the binary's version.
DASHLESS_VERSION=$(echo $VERSION | tr -d '-')

# If we are providing the branch or hash to build we'll take version as the hashtag
[ -n "$1" ] && hash_tag=$VERSION || hash_tag=$cc_runtime_hash
short_hashtag="${hash_tag:0:7}"

if [[ ${VERSION::1} =~ [a-z] ]]; then
    ORIGINAL_VERSION=$VERSION
    VERSION=1${VERSION:1}
fi

OBS_PUSH=${OBS_PUSH:-false}
STAGING=${STAGING:-true}
OBS_RUNTIME_REPO=${OBS_RUNTIME_REPO:-home:clearcontainers:clear-containers-3-staging/cc-runtime}
: ${OBS_APIURL:=""}

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

function templating_non_staging(){
    sed -e "s/@DASHLESS_VERSION@/$DASHLESS_VERSION/g" \
        -e "s/@RELEASE@/$RELEASE/g" \
        -e "s/@VERSION@/$VERSION/g" \
        -e "s/@HASH@/$short_hashtag/g" \
        -e "s/@cc_proxy_version@/$proxy_obs_fedora_version/" \
        -e "s/@cc_shim_version@/$shim_obs_fedora_version/" \
        -e "s/@cc_image_version@/$image_obs_fedora_version/" \
        -e "s/@linux_container_version@/$linux_container_obs_fedora_version/" cc-runtime.spec-template > cc-runtime.spec

    sed -e "s/@VERSION@/$VERSION/" \
        -e "s/@HASH@/$short_hashtag/" debian.rules-template > debian.rules

    sed -e "s/@VERSION@/$VERSION/g"\
        -e "s/@RELEASE@/$RELEASE/g" \
        -e "s/@DASHLESS_VERSION@/$DASHLESS_VERSION/g" \
        -e "s/@HASH@/$short_hashtag/g" \
        -e "s/@cc_proxy_version@/$proxy_obs_ubuntu_version/" \
        -e "s/@cc_shim_version@/$shim_obs_ubuntu_version/" \
        -e "s/@cc_image_version@/$image_obs_ubuntu_version/" \
        -e "s/@qemu_lite_version@/$qemu_lite_obs_ubuntu_version/" \
        -e "s/@linux_container_version@/$linux_container_obs_ubuntu_version/" cc-runtime.dsc-template > cc-runtime.dsc

    sed -e "s/@DASHLESS_VERSION@/$DASHLESS_VERSION/" \
        -e "s/@HASH_TAG@/$short_hashtag/" \
        -e "s/@cc_proxy_version@/$proxy_obs_ubuntu_version/" \
        -e "s/@cc_shim_version@/$shim_obs_ubuntu_version/" \
        -e "s/@cc_image_version@/$image_obs_ubuntu_version/" \
        -e "s/@qemu_lite_version@/$qemu_lite_obs_ubuntu_version/" \
        -e "s/@linux_container_version@/$linux_container_obs_ubuntu_version/" debian.control-template > debian.control

    if [ -z "$ORIGINAL_VERSION" ]; then
        sed "s/@VERSION@/$VERSION/g;" _service-template > _service
    else
        sed "s/@VERSION@/$ORIGINAL_VERSION/g;" _service-template > _service
    fi

    [ -n "$1" ] && sed -e "s/@PARENT_TAG@/$VERSION/" -i _service || :
}

function templating_staging(){
    sed -e "s/@DASHLESS_VERSION@/$DASHLESS_VERSION/g" \
        -e "s/@RELEASE@/$RELEASE/g" \
        -e "s/@VERSION@/$VERSION/g" \
        -e "s/@HASH@/$short_hashtag/g"  cc-runtime.spec-template > cc-runtime.spec

    sed -e "s/@VERSION@/$VERSION/g" \
        -e "s/@HASH@/$short_hashtag/" debian.rules-template > debian.rules

    sed -e "s/@VERSION@/$VERSION/"\
        -e "s/@RELEASE@/$RELEASE/" \
        -e "s/@DASHLESS_VERSION@/$DASHLESS_VERSION/" \
        -e "s/@HASH@/$short_hashtag/"  cc-runtime.dsc-template > cc-runtime.dsc

    sed -e "s/@DASHLESS_VERSION@/$DASHLESS_VERSION/" \
        -e "s/@HASH_TAG@/$short_hashtag/"  debian.control-template > debian.control

    if [ -z "$ORIGINAL_VERSION" ]; then
        sed "s/@VERSION@/$VERSION/g;" _service-template > _service
    else
        sed "s/@VERSION@/$ORIGINAL_VERSION/g;" _service-template > _service
    fi

    [ -n "$1" ] && sed -e "s/@PARENT_TAG@/$VERSION/" -i _service || :

    sed -e '/^Package: cc-runtime$/{n;n;s/^Depends: .*/Depends: \${shlibs:Depends}, \${misc:Depends}, \${perl:Depends}, cc-runtime-bin, cc-runtime-config/}' \
        -e "/clear-containers-image*/d" \
        -e "/cc-proxy*/d" -i cc-runtime.dsc debian.control

    sed -e '/Requires: cc-proxy/d' \
        -e '/Requires: cc-shim/d' \
        -e '/Requires: clear-containers-*/d' \
        -e '/Requires: linux-container*/d' -i cc-runtime.spec

}

if [ "$STAGING" == false ]; then
    templating_non_staging "$@"
else
    templating_staging "$@"
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
    [ -f debian.series ] && cp debian.series $TMPDIR || :
    cd $TMPDIR

    if [ -e "go1.8.3.linux-amd64.tar.gz" ]; then
        rm go*.tar.gz
    fi
    osc $APIURL addremove
    osc $APIURL commit -m "Update cc-runtime $VERSION: ${hash_tag:0:7}"
fi
