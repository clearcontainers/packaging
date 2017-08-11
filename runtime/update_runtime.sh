#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh
#
# Automation script to create specs to build cc-runtime
# Default: Build is the one specified in file configure.ac
# located at the root of the repository.
set -x
AUTHOR=${AUTHOR:-$(git config user.name)}
AUTHOR_EMAIL=${AUTHOR_EMAIL:-$(git config user.email)}

source ../versions.txt
VERSION=${1:-$cc_runtime_version}
VERSION_DEB_TRANSFORM=$(echo $VERSION | tr -d '-')

hash_tag=$cc_runtime_hash
short_hashtag="${hash_tag:0:7}"
# If there is no tag matching $VERSION we'll get $VERSION as the reference
[ -z "$hash_tag" ] && hash_tag=$VERSION || :

OBS_PUSH=${OBS_PUSH:-false}
STAGING=${STAGING:-true}
OBS_RUNTIME_REPO=${OBS_RUNTIME_REPO:-home:clearcontainers:clear-containers-3-staging/cc-runtime}
: ${OBS_APIURL:=""}

if [ $OBS_APIURL != "" ]; then
    APIURL="-A ${OBS_APIURL}"
else
    APIURL=""
fi


GO_VERSION=${GO_VERSION:-"1.8.3"}

echo "Running: $0 $@"
echo "Update cc-runtime $VERSION: ${hash_tag:0:7}"

function changelog_update {
    d=$(date +"%a, %d %b %Y %H:%M:%S %z")
    git checkout debian.changelog
    cp debian.changelog debian.changelog-bk
    cat <<< "cc-runtime ($VERSION) stable; urgency=medium

  * Update cc-runtime $VERSION ${hash_tag:0:7}

 -- $AUTHOR <$AUTHOR_EMAIL>  $d
" > debian.changelog
    cat debian.changelog-bk >> debian.changelog
    rm debian.changelog-bk
}
changelog_update $VERSION

function templating_non_staging(){
    sed -e "s/@VERSION@/$VERSION/" \
        -e "s/@GO_VERSION@/$GO_VERSION/g;" \
        -e "s/@cc_proxy_version@/$proxy_obs_fedora_version/" \
        -e "s/@cc_shim_version@/$shim_obs_fedora_version/" \
        -e "s/@cc_image_version@/$image_obs_fedora_version/" \
        -e "s/@linux_container_version@/$linux_container_obs_fedora_version/" cc-runtime.spec-template > cc-runtime.spec

    sed -e "s/@VERSION_DEB_TRANSFORM@/$VERSION_DEB_TRANSFORM/g;" \
        -e "s/@HASH_TAG@/$short_hashtag/g;" \
        -e "s/@cc_proxy_version@/$proxy_obs_ubuntu_version/" \
        -e "s/@cc_shim_version@/$shim_obs_ubuntu_version/" \
        -e "s/@cc_image_version@/$image_obs_ubuntu_version/" \
        -e "s/@linux_container_version@/$linux_container_obs_ubuntu_version/" cc-runtime.dsc-template > cc-runtime.dsc

    sed -e "s/@VERSION_DEB_TRANSFORM@/$VERSION_DEB_TRANSFORM/g;" \
        -e "s/@HASH_TAG@/$short_hashtag/g;" \
        -e "s/@cc_proxy_version@/$proxy_obs_ubuntu_version/" \
        -e "s/@cc_shim_version@/$shim_obs_ubuntu_version/" \
        -e "s/@cc_image_version@/$image_obs_ubuntu_version/" \
        -e "s/@linux_container_version@/$linux_container_obs_ubuntu_version/" debian.control-template > debian.control

    sed "s/@VERSION@/$VERSION/g;" _service-template > _service
}

function templating_staging(){

    sed -e "s/@VERSION@/$VERSION/" \
        -e "s/@GO_VERSION@/$GO_VERSION/g;" cc-runtime.spec-template > cc-runtime.spec

    sed -e "s/@VERSION_DEB_TRANSFORM@/$VERSION_DEB_TRANSFORM/g;" \
        -e "s/@HASH_TAG@/$short_hashtag/g;" cc-runtime.dsc-template > cc-runtime.dsc

    sed -e "s/@VERSION_DEB_TRANSFORM@/$VERSION_DEB_TRANSFORM/g;" \
        -e "s/@HASH_TAG@/$short_hashtag/g;" debian.control-template > debian.control

    sed "s/@VERSION@/$VERSION/g;" _service-template > _service

    sed -e "s/^Depends:.*/Depends: \${shlibs:Depends}, \${misc:Depends}, \${perl:Depends}/" \
        -e "/clear-containers-image*/d" \
        -e "/cc-proxy*/d" -i cc-runtime.dsc debian.control

    sed -e '/Requires: cc-*/d' \
        -e '/Requires: clear-containers-*/d' \
        -e '/Requires: linux-container*/d' -i cc-runtime.spec
}

if [ "$STAGING" == false ]; then
    templating_non_staging
else
    templating_staging
fi

# Update and package OBS
if [ "$OBS_PUSH" = true ]
then
    temp=$(basename $0)
    TMPDIR=$(mktemp -d -u -t ${temp}.XXXXXXXXXXX) || exit 1
    osc $APIURL co "$OBS_RUNTIME_REPO" -o $TMPDIR
    mv cc-runtime.spec \
       cc-runtime.dsc \
       debian.control \
        _service \
        $TMPDIR
    cp debian.changelog \
        debian.compat \
        debian.rules \
        cc-runtime-bin.install \
        cc-runtime-config.install \
        $TMPDIR
    cd $TMPDIR

    if [ ! -e "go${GO_VERSION}.linux-amd64.tar.gz" ]; then
        rm go*.tar.gz
        curl -OkL https://storage.googleapis.com/golang/go$GO_VERSION.linux-amd64.tar.gz
    fi
    osc $APIURL addremove
    osc $APIURL commit -m "Update cc-runtime $VERSION: ${hash_tag:0:7}"
fi
