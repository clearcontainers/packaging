#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh

# Automation script to create specs to build clear-containers-image
# Default image to build is the one specified in file versions.txt
# located at the root of the repository.
set -x
if [ $# -ne 1 ]; then
    cat << EOT
Usage:
$0 <clear-linux-version>

You need to provide the version to update the image
EOT
    exit
fi
script_dir=$(dirname "$0")
git checkout ${script_dir}/release ${script_dir}/debian.changelog ${script_dir}/../versions.txt
source ${script_dir}/../versions.txt

VERSION=${1}

AUTHOR=${AUTHOR:-$(git config user.name)}
AUTHOR_EMAIL=${AUTHOR_EMAIL:-$(git config user.email)}


OBS_PUSH=${OBS_PUSH:-false}
OBS_CC_IMAGE_REPO=${OBS_CC_IMAGE_REPO:-home:clearcontainers:clear-containers-3-staging/clear-containers-image}

last_release=$(cat ${script_dir}/release)
next_release=$(( $last_release + 1 ))

echo "Running: $0 $@"
echo "Update clear-containers-image to: $VERSION-$next_release"
image_changes=$(${script_dir}/../scripts/get-image-changes.sh $VERSION | awk '{if (/^version/) print "  * "$0; else print "  "$0"\n"}')

sed -i s/"clear_vm_image_version=${clear_vm_image_version}"/"clear_vm_image_version=${VERSION}"/ ${script_dir}/../versions.txt

function changelog_update {
    d=$(date +"%a, %d %b %Y %H:%M:%S %z")
    cp ${script_dir}/debian.changelog ${script_dir}/debian.changelog-bk
    cat <<< "clear-containers-image ($VERSION-$next_release) stable; urgency=medium

  * Update clear-containers-image from $clear_vm_image_version to $VERSION.
" > ${script_dir}/debian.changelog

    echo "${image_changes}

 -- $AUTHOR <$AUTHOR_EMAIL>  $d
" >> ${script_dir}/debian.changelog
    cat ${script_dir}/debian.changelog-bk >> ${script_dir}/debian.changelog
    rm ${script_dir}/debian.changelog-bk
}

changelog_update $VERSION
echo $next_release > ${script_dir}/release

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
    mv ${cc_image_dir}/clear-containers-image.spec .
    mv ${cc_image_dir}/clear-containers-image.dsc .
    mv ${cc_image_dir}/_service .
    mv ${cc_image_dir}/debian.rules .
    cp ${cc_image_dir}/LICENSE .
    cp ${cc_image_dir}/debian.control .
    cp ${cc_image_dir}/debian.compat .
    cp ${cc_image_dir}/debian.changelog .
    cp ${cc_image_dir}/debian.dirs .
    osc addremove
    osc commit -m "Update clear-containers-image to: $VERSION-$next_release"
fi
