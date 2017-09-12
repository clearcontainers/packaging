#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh
#
# Automation script to create specs to build cc-proxy
# Default: Build is the one specified in file configure.ac
# located at the root of the repository.
set -x
AUTHOR=${AUTHOR:-$(git config user.name)}
AUTHOR_EMAIL=${AUTHOR_EMAIL:-$(git config user.email)}

source ../versions.txt
VERSION=${1:-$cc_proxy_version}
# 3.0.0-beta.X format cause errors while packaging.
# Remove the dash in order to be able to build. The
# original string will remain in the packages and
# in the binary's version.
DASHLESS_VERSION=$(echo $VERSION | tr -d '-')

# If we are providing the branch or hash to build we'll take version as the hashtag
[ -n "$1" ] && hash_tag=$VERSION || hash_tag=$cc_proxy_hash
short_hashtag="${hash_tag:0:7}"

if [[ ${VERSION::1} =~ [a-z] ]]; then
    ORIGINAL_VERSION=$VERSION
    VERSION=1${VERSION:1}
fi

OBS_PUSH=${OBS_PUSH:-false}
OBS_PROXY_REPO=${OBS_PROXY_REPO:-home:clearcontainers:clear-containers-3-staging/cc-proxy}
: ${OBS_APIURL:=""}

# This allows to point to internal/private OBS instance
if [ "$OBS_APIURL" != "" ]; then
    APIURL="-A ${OBS_APIURL}"
else
    APIURL=""
fi

echo "Running: $0 $@"
echo "Update cc-proxy $VERSION: ${hash_tag:0:7}"

function changelog_update {
    d=$(date +"%a, %d %b %Y %H:%M:%S %z")
    git checkout debian.changelog
    cp debian.changelog debian.changelog-bk
    cat <<< "cc-proxy ($VERSION) stable; urgency=medium

  * Update cc-proxy $VERSION ${hash_tag:0:7}

 -- $AUTHOR <$AUTHOR_EMAIL>  $d
" > debian.changelog
    cat debian.changelog-bk >> debian.changelog
    rm debian.changelog-bk
}
changelog_update $VERSION

RELEASE=$(($(cat release) + 1))
echo $RELEASE > release

sed -e "s/@DASHLESS_VERSION@/$DASHLESS_VERSION/g" \
    -e "s/@RELEASE@/$RELEASE/g" \
    -e "s/@HASH@/$short_hashtag/g" \
    -e "s/@VERSION@/${VERSION}-${short_hashtag}/g" cc-proxy.spec-template > cc-proxy.spec

sed -e "s/@VERSION@/${VERSION}-${short_hashtag}/" debian.rules-template > debian.rules

sed -e "s/@DASHLESS_VERSION@/$DASHLESS_VERSION/g" \
    -e "s/@VERSION@/$VERSION/g" \
    -e "s/@HASH@/$short_hashtag/g" \
    -e "s/@RELEASE@/$RELEASE/g" cc-proxy.dsc-template > cc-proxy.dsc

sed -e "s/@DASHLESS_VERSION@/$DASHLESS_VERSION/g" debian.control-template > debian.control

if [ -z "$ORIGINAL_VERSION" ]; then
    sed "s/@VERSION@/$VERSION/g;" _service-template > _service
else
    sed "s/@VERSION@/$ORIGINAL_VERSION/g;" _service-template > _service
fi

[ -n "$1" ] && sed -e "s/@PARENT_TAG@/$VERSION/" -i _service || :

# Update and package OBS
if [ "$OBS_PUSH" = true ]
then
    temp=$(basename $0)
    TMPDIR=$(mktemp -d -t ${temp}.XXXXXXXXXXX) || exit 1
    osc $APIURL co "$OBS_PROXY_REPO" -o $TMPDIR

    mv cc-proxy.spec \
       cc-proxy.dsc \
       debian.control \
       debian.rules \
        _service \
        $TMPDIR
    rm $TMPDIR/*.patch
    [ -f $TMPDIR/debian.series ] && rm $TMPDIR/debian.series || :
    cp debian.changelog \
        debian.compat \
        *.patch \
        $TMPDIR
    [ -f debian.series ] && cp debian.series $TMPDIR || :
    cd $TMPDIR

    if [ -e "go1.8.3.linux-amd64.tar.gz" ]; then
        rm go*.tar.gz
    fi
    osc $APIURL addremove
    osc $APIURL commit -m "Update cc-proxy $VERSION: ${hash_tag:0:7}"
fi
