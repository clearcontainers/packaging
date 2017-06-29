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
VERSION_DEB_TRANSFORM=$(echo $VERSION | tr -d '-')

hash_tag=$cc_proxy_hash
short_hashtag="${hash_tag:0:7}"
# If there is no tag matching $VERSION we'll get $VERSION as the reference
[ -z "$hash_tag" ] && hash_tag=$VERSION || :

OBS_PUSH=${OBS_PUSH:-false}
OBS_PROXY_REPO=${OBS_PROXY_REPO:-home:clearcontainers:clear-containers-3-staging/cc-proxy}
: ${OBS_APIURL:=""}

if [ $OBS_APIURL != '' ]; then
    APIURL="-A ${OBS_APIURL}"
else
    APIURL=""
fi

GO_VERSION=${GO_VERSION:-"1.8.3"}

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
sed -e "s/@VERSION@/$VERSION/g;" -e "s/@GO_VERSION@/$GO_VERSION/g;" cc-proxy.spec-template > cc-proxy.spec
sed -e "s/@VERSION_DEB_TRANSFORM@/$VERSION_DEB_TRANSFORM/g;" -e "s/@HASH_TAG@/$short_hashtag/g;" cc-proxy.dsc-template > cc-proxy.dsc
sed -e "s/@VERSION_DEB_TRANSFORM@/$VERSION_DEB_TRANSFORM/g;" -e "s/@HASH_TAG@/$short_hashtag/g;" debian.control-template > debian.control
sed "s/@VERSION@/$VERSION/g;" _service-template > _service

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
    cp debian.changelog \
        debian.compat \
        debian.rules \
        debian.series \
        disable-systemd-check.patch \
        $TMPDIR
    cd $TMPDIR

    if [ ! -e "go${GO_VERSION}.linux-amd64.tar.gz" ]; then
        rm go*.tar.gz
        curl -OkL https://storage.googleapis.com/golang/go$GO_VERSION.linux-amd64.tar.gz
    fi
    osc $APIURL addremove
    osc $APIURL commit -m "Update cc-proxy $VERSION: ${hash_tag:0:7}"
fi
