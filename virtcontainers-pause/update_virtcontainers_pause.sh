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
VERSION=${1:-$virtcontainers_version}

hash_tag=$virtcontainers_hash
short_hashtag="${hash_tag:0:7}"
# If there is no tag matching $VERSION we'll get $VERSION as the reference
[ -z "$hash_tag" ] && hash_tag=$VERSION || :

OBS_PUSH=${OBS_PUSH:-false}
OBS_VC_REPO=${OBS_VC_REPO:-home:clearcontainers:clear-containers-3-staging/virtcontainers-pause}

echo "Running: $0 $@"
echo "Update virtcontainers-pause $VERSION: ${hash_tag:0:7}"

function changelog_update {
    d=$(date +"%a, %d %b %Y %H:%M:%S %z")
    git checkout debian.changelog
    cp debian.changelog debian.changelog-bk
    cat <<< "virtcontainers-pause ($VERSION) stable; urgency=medium

  * Update virtcontainers-pause $VERSION ${hash_tag:0:7}

 -- $AUTHOR <$AUTHOR_EMAIL>  $d
" > debian.changelog
    cat debian.changelog-bk >> debian.changelog
    rm debian.changelog-bk
}
changelog_update $VERSION

sed "s/@VERSION@/$VERSION/g;" virtcontainers-pause.spec-template > virtcontainers-pause.spec
sed -e "s/@VERSION@/$VERSION/g;" -e "s/@HASH_TAG@/$short_hashtag/g;" virtcontainers-pause.dsc-template > virtcontainers-pause.dsc
sed -e "s/@VERSION@/$VERSION/g;" -e "s/@HASH_TAG@/$short_hashtag/g;" debian.control-template > debian.control
sed "s/@VERSION@/$VERSION/g;" _service-template > _service

# Update and package OBS
if [ "$OBS_PUSH" = true ]
then
    temp=$(basename $0)
    TMPDIR=$(mktemp -d -t ${temp}.XXXXXXXXXXX) || exit 1
    osc co "$OBS_VC_REPO" -o $TMPDIR
    mv virtcontainers-pause.spec \
       virtcontainers-pause.dsc \
       debian.control \
        _service \
        $TMPDIR
    cp debian.changelog \
        debian.rules \
        debian.compat \
        $TMPDIR
    cd $TMPDIR
    osc addremove
    osc commit -m "Update virtcontainers-pause $VERSION: ${hash_tag:0:7}"
fi
