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

# If we are providing the branch or hash to build we'll take version as the hashtag
[ -n "$1" ] && hash_tag=$VERSION || hash_tag=$cc_proxy_hash
short_hashtag="${hash_tag:0:7}"

if [[ ${VERSION::1} =~ [a-z] ]]; then
    ORIGINAL_VERSION=$VERSION
    VERSION=1${VERSION:1}
fi
VERSION_DEB_TRANSFORM=$(echo $VERSION | tr -d '-')

OBS_PUSH=${OBS_PUSH:-false}
OBS_PROXY_REPO=${OBS_PROXY_REPO:-home:clearcontainers:clear-containers-3-staging/cc-proxy}
: ${OBS_APIURL:=""}

if [ $OBS_APIURL != '' ]; then
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
sed -e "s/@VERSION@/$VERSION/" cc-proxy.spec-template > cc-proxy.spec
sed -e "s/@VERSION_DEB_TRANSFORM@/$VERSION_DEB_TRANSFORM/g;" -e "s/@HASH_TAG@/$short_hashtag/g;" cc-proxy.dsc-template > cc-proxy.dsc
sed -e "s/@VERSION_DEB_TRANSFORM@/$VERSION_DEB_TRANSFORM/g;" -e "s/@HASH_TAG@/$short_hashtag/g;" debian.control-template > debian.control

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
        _service \
        $TMPDIR
    rm $TMPDIR/*.patch
    [ -f $TMPDIR/debian.series ] && rm $TMPDIR/debian.series || :
    cp debian.changelog \
        debian.compat \
        debian.rules \
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
