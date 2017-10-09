#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh

# Automation script to create specs to build clear-containers-image
# Default image to build is the one specified in file versions.txt
# located at the root of the repository.
set -x
AUTHOR=${AUTHOR:-$(git config user.name)}
AUTHOR_EMAIL=${AUTHOR_EMAIL:-$(git config user.email)}

CC_VERSIONS_FILE="../versions.txt"
source "$CC_VERSIONS_FILE"
VERSION=${1:-$clear_vm_image_version}

OBS_PUSH=${OBS_PUSH:-false}
OBS_CC_IMAGE_REPO=${OBS_CC_IMAGE_REPO:-home:clearcontainers:clear-containers-3-staging/clear-containers-image}

git checkout debian.changelog
last_release=$(cat release)
next_release=$(( $last_release + 1 ))

echo "Running: $0 $@"
echo "Update clear-containers-image to: $VERSION-$next_release"

function changelog_update {
    d=$(date +"%a, %d %b %Y %H:%M:%S %z")
    cp debian.changelog debian.changelog-bk
    cat <<< "clear-containers-image ($VERSION-$next_release) stable; urgency=medium

  * Update clear-containers-image $VERSION.

 -- $AUTHOR <$AUTHOR_EMAIL>  $d
" > debian.changelog
    cat debian.changelog-bk >> debian.changelog
    rm debian.changelog-bk
}

changelog_update $VERSION

sed "s/\@VERSION\@/$VERSION/g; s/\@RELEASE\@/$next_release/g" clear-containers-image.spec-template > clear-containers-image.spec
sed "s/\@VERSION\@/$VERSION/g; s/\@RELEASE\@/$next_release/g" clear-containers-image.dsc-template > clear-containers-image.dsc
sed "s/\@VERSION\@/$VERSION/g" debian.rules-template > debian.rules
sed "s/@VERSION@/$VERSION/g" _service-template > _service

chmod +x debian.rules

if [ $? = 0 ] && [ "$OBS_PUSH" = true ]
then
    temp=$(basename $0)
    TMPDIR=$(mktemp -d -t ${temp}.XXXXXXXXXXX) || exit 1
    cc_image_dir=$(pwd)
    osc co "$OBS_CC_IMAGE_REPO" -o $TMPDIR
    cd $TMPDIR
    rm -rf *.img.xz \
        *tar.xz \
        *orig.tar.xz
    mv $cc_image_dir/clear-containers-image.spec .
    mv $cc_image_dir/clear-containers-image.dsc .
    mv $cc_image_dir/_service .
    mv $cc_image_dir/debian.rules .
    cp $cc_image_dir/LICENSE .
    cp $cc_image_dir/debian.control .
    cp $cc_image_dir/debian.compat .
    cp $cc_image_dir/debian.changelog .
    cp $cc_image_dir/debian.dirs .
    osc addremove
    osc commit -m "Update clear-containers-image to: $VERSION-$next_release"
fi
