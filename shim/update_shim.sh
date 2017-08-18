#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh
#
# Automation script to create specs to build cc-shim
# Default: Build is the one specified in file configure.ac
# located at the root of the repository.
set -x
AUTHOR=${AUTHOR:-$(git config user.name)}
AUTHOR_EMAIL=${AUTHOR_EMAIL:-$(git config user.email)}

source ../versions.txt
VERSION=${1:-$cc_shim_version}

# If we are providing the branch or hash to build we'll take version as the hashtag
[ -n "$1" ] && hash_tag=$VERSION || hash_tag=$cc_shim_hash
short_hashtag="${hash_tag:0:7}"

if [[ ${VERSION::1} =~ [a-z] ]]; then
    ORIGINAL_VERSION=$VERSION
    VERSION=1${VERSION:1}
fi
VERSION_DEB_TRANSFORM=$(echo $VERSION | tr -d '-')

OBS_PUSH=${OBS_PUSH:-false}
OBS_SHIM_REPO=${OBS_SHIM_REPO:-home:clearcontainers:clear-containers-3-staging/cc-shim}
: ${OBS_APIURL:=""}

if [ $OBS_APIURL != '' ]; then
    APIURL="-A ${OBS_APIURL}"
else
    APIURL=""
fi

echo "Running: $0 $@"
echo "Update cc-shim $VERSION: ${hash_tag:0:7}"

function changelog_update {
    d=$(date +"%a, %d %b %Y %H:%M:%S %z")
    git checkout debian.changelog
    cp debian.changelog debian.changelog-bk
    cat <<< "cc-shim ($VERSION) stable; urgency=medium

  * Update cc-shim $VERSION ${hash_tag:0:7}

 -- $AUTHOR <$AUTHOR_EMAIL>  $d
" > debian.changelog
    cat debian.changelog-bk >> debian.changelog
    rm debian.changelog-bk
}
changelog_update $VERSION

sed "s/@VERSION@/$VERSION/g;" cc-shim.spec-template > cc-shim.spec
sed -e "s/@VERSION_DEB_TRANSFORM@/$VERSION_DEB_TRANSFORM/g;" -e "s/@HASH_TAG@/$short_hashtag/g;" cc-shim.dsc-template > cc-shim.dsc
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
    osc $APIURL co "$OBS_SHIM_REPO" -o $TMPDIR
    mv cc-shim.spec \
        cc-shim.dsc \
        _service \
        debian.control \
        $TMPDIR
    rm $TMPDIR/*.patch
    [ -f $TMPDIR/debian.series ] && rm $TMPDIR/debian.series || :
    cp debian.changelog \
        debian.rules \
        debian.compat \
        *.patch \
        $TMPDIR
    [ -f debian.series ] && cp debian.series $TMPDIR || :
    cd $TMPDIR
    osc $APIURL addremove
    osc $APIURL commit -m "Update cc-shim $VERSION: ${hash_tag:0:7}"
fi
