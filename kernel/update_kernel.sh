#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh

# Automation script to create specs to build cc-oci-runtime
# Default image to build is the one specified in file configure.ac
# located at the root of the repository.
set -x
AUTHOR=${AUTHOR:-$(git config user.name)}
AUTHOR_EMAIL=${AUTHOR_EMAIL:-$(git config user.email)}

CC_VERSIONS_FILE="../versions.txt"
source "$CC_VERSIONS_FILE"
clear_vm_kernel_version=$(echo $clear_vm_kernel_version | cut -d'-' -f1)
VERSION=${1:-$clear_vm_kernel_version}

OBS_PUSH=${OBS_PUSH:-false}
OBS_CC_KERNEL_REPO=${OBS_CC_KERNEL_REPO:-home:clearlinux:preview:clear-containers-staging/linux-container}

git checkout debian.changelog
last_release=$(awk 'NR==1{ gsub(".*-|\).*",""); print $0}' debian.changelog)
next_release=$(( $last_release + 1 ))
kernel_sha256=$(curl -s  https://cdn.kernel.org/pub/linux/kernel/v4.x/sha256sums.asc | awk '/linux-'${VERSION}'.tar.xz/ {print $1}')

echo "Running: $0 $@"
echo "Update linux-container to: $VERSION-$next_release"

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

changelog_update $VERSION

sed "s/\@VERSION\@/$VERSION/g; s/\@RELEASE\@/$next_release/g" linux-container.spec-template > linux-container.spec
sed "s/\@VERSION\@/$VERSION/g" linux-container.dsc-template > linux-container.dsc
sed "s/\@VERSION\@/$VERSION/g; s/\@KERNEL_SHA256\@/$kernel_sha256/g" _service-template > _service

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
        config \
        $TMPDIR
    [ -f debian.series ] && cp debian.series $TMPDIR || :
    cd $TMPDIR
    osc addremove
    osc commit -m "Update linux-container to: $VERSION-$next_release"
fi
