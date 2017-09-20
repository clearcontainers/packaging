#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh

# Automation script to create specs to build clear containers kernel
set -x

AUTHOR=${AUTHOR:-$(git config user.name)}
AUTHOR_EMAIL=${AUTHOR_EMAIL:-$(git config user.email)}

OBS_PUSH=${OBS_PUSH:-false}
OBS_CC_QEMU_REPO=${OBS_CC_QEMU_REPO:-home:clearcontainers:clear-containers-3-staging/qemu-lite}

source ../versions.txt

VERSION=${1:-$qemu_lite_version}

# If we are providing the branch or hash to build we'll take version as the hashtag
[ -n "$1" ] && hash_tag=$VERSION || hash_tag=$qemu_lite_hash
short_hashtag="${hash_tag:0:10}"

function changelog_update {
    d=$(date -R)
    cp debian.changelog debian.changelog-bk
    cat <<< "qemu-lite ($VERSION-$next_release) stable; urgency=medium

  * Update qemu-lite $VERSION+$short_hashtag-$next_release

 -- $AUTHOR <$AUTHOR_EMAIL>  $d
" > debian.changelog

    cat debian.changelog-bk >> debian.changelog
    rm debian.changelog-bk
}

echo "Running: $0 $@"

git checkout -- release debian.changelog
last_release=$(< release)
next_release=$(( $last_release + 1 ))
echo ${next_release} > release
echo "Update linux-container to: $VERSION-$next_release"

changelog_update ${VERSION}

sed "s/\@VERSION\@/${VERSION}/g; s/\@RELEASE\@/${next_release}/g; s/\@QEMU_LITE_HASH\@/${short_hashtag}/g" qemu-lite.spec-template > qemu-lite.spec
sed "s/\@VERSION\@/${VERSION}/g; s/\@RELEASE\@/${next_release}/g; s/\@QEMU_LITE_HASH\@/${short_hashtag}/g" qemu-lite.dsc-template > qemu-lite.dsc
sed "s/\@VERSION\@/${VERSION}/g; s/\@RELEASE\@/${next_release}/g; s/\@QEMU_LITE_HASH\@/${short_hashtag}/g" debian.rules-template > debian.rules

if [ $? = 0 ] && [ "$OBS_PUSH" = true ]
then
    temp=$(basename $0)
    TMPDIR=$(mktemp -d -t ${temp}.XXXXXXXXXXX) || exit 1
    osc co "$OBS_CC_QEMU_REPO" -o $TMPDIR
    mv qemu-lite.dsc \
       qemu-lite.spec \
       debian.rules \
        $TMPDIR
    rm -f $TMPDIR/*.patch
    rm -f $TMPDIR/debian.series
    cp debian.changelog \
        debian.compat \
        debian.control \
        _service \
        *.patch \
        $TMPDIR
    [ -f debian.series ] && cp debian.series $TMPDIR || :
    cd $TMPDIR
    osc addremove
    osc commit -m "Update qemu-lite to: $VERSION-$next_release"
fi
