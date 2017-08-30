#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh

# Automation script to create specs to build clear containers kernel
set -x

KR_REL=https://www.kernel.org/releases.json
KR_SHA=https://cdn.kernel.org/pub/linux/kernel/v4.x/sha256sums.asc
KR_LTS=4.9

AUTHOR=${AUTHOR:-$(git config user.name)}
AUTHOR_EMAIL=${AUTHOR_EMAIL:-$(git config user.email)}

OBS_PUSH=${OBS_PUSH:-false}
OBS_CC_KERNEL_REPO=${OBS_CC_KERNEL_REPO:-home:clearcontainers:clear-containers-3-staging/linux-container}

VERSION=${1:-latest}

function changelog_update {
    d=$(date -R)
    cp debian.changelog debian.changelog-bk
    cat <<< "linux-container ($VERSION-$next_release) stable; urgency=medium

  * Update kernel $VERSION

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

if [ "${VERSION}" = "latest" ]
then
    VERSION=$(curl -L -s -f ${KR_REL} | grep "${KR_LTS}" | grep version | cut -f 4 -d \")
fi

kernel_sha256=$(curl -L -s -f ${KR_SHA} | awk '/linux-'${VERSION}'.tar.xz/ {print $1}')

echo "Update linux-container to: $VERSION-$next_release"

changelog_update ${VERSION}

sed "s/\@VERSION\@/${VERSION}/g; s/\@RELEASE\@/${next_release}/g" linux-container.spec-template > linux-container.spec
sed "s/\@VERSION\@/${VERSION}/g; s/\@RELEASE\@/${next_release}/g" linux-container.dsc-template > linux-container.dsc
sed "s/\@VERSION\@/${VERSION}/g; s/\@KERNEL_SHA256\@/${kernel_sha256}/g" _service-template > _service

if [ $? = 0 ] && [ "$OBS_PUSH" = true ]
then
    temp=$(basename $0)
    TMPDIR=$(mktemp -d -t ${temp}.XXXXXXXXXXX) || exit 1
    osc co "$OBS_CC_KERNEL_REPO" -o $TMPDIR
    mv linux-container.dsc \
       linux-container.spec \
        _service \
        $TMPDIR
    rm -f $TMPDIR/*.patch
    rm -f $TMPDIR/linux-container_*
    rm -f $TMPDIR/linux-*.tar.xz
    rm -f $TMPDIR/debian.series
    cp debian.changelog \
        debian.dirs \
        debian.rules \
        debian.compat \
        debian.control \
        debian.copyright \
        patches-4.9.x/*.patch \
        $TMPDIR
    cp kernel-config-4.9.x $TMPDIR/config
    [ -f debian.series ] && cp debian.series $TMPDIR || :
    cd $TMPDIR
    osc addremove
    osc commit -m "Update linux-container to: $VERSION-$next_release"
fi
