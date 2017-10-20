#!/bin/bash

# This is a helper library for the setup scripts of each package
# in this repository.

source ../versions.txt
PACKAGING_DIR=/var/packaging
LOG_DIR=${PACKAGING_DIR}/build_logs
BUILD_ARCH=x86_64

function display_help()
{
	cat <<-EOL 
	$SCRIPT_NAME

	This script is intended to create Clear Containers 3.X packages for the OBS 
	(Open Build Service) platform.

    Usage:
        $SCRIPT_NAME [options]

	Options:

    -l         --local-build     Build the runtime locally
    -w	       --workdir         Repository directory
    -c         --commit-id       Build with a given commit ID
    -b         --branch          Build with a given branch name
    -p         --push            Push changes to OBS
    -a         --api-url         Especify an OBS API (e.g. custom private OBS)
    -r         --obs-repository  An OBS repository to push the changes.
    -w         --workdir         Directory of a working copy of the OBS runtime repo
    -v         --verbose         Set the -x flag for verbosity
    -C         --clean           Clean the repository
    -V         --verify          Verify the environment
    -h         --help            Display this help message

    Usage examples:

    $SCRIPT_NAME --local-build --branch staging
    $SCRIPT_NAME --commit-id a76f45c --push --api-url http://127.0.0.1
    $SCRIPT_NAME --commit-id a76f45c --push --obs-repository home:userx/repository
    $SCRIPT_NAME --commit-id a76f45c --push

	EOL
	exit 1
}

die()
{
	msg="$*"
	echo >&2 "ERROR: $msg"
	exit 1
}

function verify()
{
    # This function perform some checks in order to make sure
    # the script will run flawlessly.

    # Make sure this script is called from ./
    [ "$SCRIPT_DIR" != "." ] && die "The script must be called from its base dir." || true
    
    # Verify if osc is installed, exit otherwise.
    [ ! -x "$(command -v osc)" ] && die "osc is not installed." || true
}

function clean()
{
    # This function clean generated files
    for file in "$@"
    do
        [ -e $file ] && rm -v $file || true
    done
    [ -e ./debian.changelog ] && git checkout ./debian.changelog || true
    [ -e ./release ] && git checkout ./release || true
    echo "Clean done."
}

function get_git_info()
{
    AUTHOR=${AUTHOR:-$(git config user.name)}
    AUTHOR_EMAIL=${AUTHOR_EMAIL:-$(git config user.email)}
}

function set_versions()
{
    local commit_hash="$1"

    if [ -n "$OBS_REVISION" ]
    then
	# Validate input is alphanumeric, commit ID
	# If a commit ID is provided, override versions.txt one
	if [ -n "$COMMIT" ] && [[ "$OBS_REVISION" =~ ^[a-zA-Z0-9][-a-zA-Z0-9]{0,40}[a-zA-Z0-9]$  ]]; then
            hash_tag=$OBS_REVISION
	elif [ -n "$BRANCH" ]
	then
            hash_tag=$commit_hash
	fi
    else
        hash_tag=$commit_hash
    fi
    short_hashtag="${hash_tag:0:7}"	
}

function changelog_update {
    d=$(date -R)
    git checkout debian.changelog
    cp debian.changelog debian.changelog-bk
    cat <<< "$PKG_NAME ($VERSION) stable; urgency=medium

  * Update $PKG_NAME $VERSION ${hash_tag:0:7}

 -- $AUTHOR <$AUTHOR_EMAIL>  $d
" > debian.changelog
    cat debian.changelog-bk >> debian.changelog
    rm debian.changelog-bk

	# Append, so it can be copied to the OBS repository
	STATIC_FILES+=('debian.changelog')
}

function local_build()
{
    [ ! -e $PACKAGING_DIR ] && mkdir $PACKAGING_DIR || true
    [ ! -e $LOG_DIR ] && mkdir $LOG_DIR || true

    pushd $OBS_WORKDIR

    BUILD_ARGS=('--local-package' '--no-verify' '--noservice' '--trust-all-projects' '--keep-pkgs=/var/packaging/results')
    [ "$OFFLINE" == "true" ] && BUILD_ARGS+=('--offline') || true

    osc service run
    for distro in ${BUILD_DISTROS[@]}
    do
        # If more distros are supported, add here the relevant validations.
        if [[ "$distro" =~ ^Fedora.* ]]
        then
	    echo "Perform a local build for ${distro}"
	    osc build ${BUILD_ARGS[@]} \
                ${distro} $BUILD_ARCH *.spec | tee ${LOG_DIR}/${distro}_${PKG_NAME}_build.log

        elif [[ "$distro" =~ ^xUbuntu.* ]]
        then
	    echo "Perform a local build for ${distro}"
	    osc build ${BUILD_ARGS[@]} \
		${distro} $BUILD_ARCH *.dsc | tee ${LOG_DIR}/${distro}_${PKG_NAME}_build.log
        fi
    done
}

function checkout_repo()
{
    local REPO="$1"
    if [ -z "$OBS_WORKDIR" ]
    then
        # If no workdir is provided, use a temporary directory.
        temp=$(basename $0)
        OBS_WORKDIR=$(mktemp -d -u -t ${temp}.XXXXXXXXXXX) || exit 1
        osc $APIURL co $REPO -o $OBS_WORKDIR
    fi

    mv ${GENERATED_FILES[@]} $OBS_WORKDIR
    cp ${STATIC_FILES[@]} $OBS_WORKDIR
    cp ../scripts/apport_hook.py $OBS_WORKDIR/$APPORT_HOOK
}

function obs_push()
{
    pushd $OBS_WORKDIR
    osc $APIURL addremove
    osc $APIURL commit -m "Update ${PKG_NAME} $VERSION: ${hash_tag:0:7}"
    popd
}

function cli()
{
	OPTS=$(getopt -o abclprwvCVh: --long api-url,branch,commit-id,local-build,push,obs-repository,workdir,verbose,clean,verify,help -- "$@")
	while true; do
		case "${1}" in
			-a | --api-url )        APIURL="$2"; shift 2;;
			-b | --branch )         BRANCH="true"; OBS_REVISION="$2"; shift 2;;
			-c | --commit-id )      COMMIT="true"; OBS_REVISION="$2"; shift 2;;
			-l | --local-build )    LOCAL_BUILD="true"; shift;;
			-p | --push )           OBS_PUSH="true"; shift;;
			-r | --obs-repository ) PROJECT_REPO="$2"; shift 2;;
			-w | --workdir )        OBS_WORKDIR="$2"; shift 2;;
			-v | --verbose )        VERBOSE="true"; shift;;
			-o | --offline )        OFFLINE="true"; shift;;
			-C | --clean )          clean ${GENERATED_FILES[@]}; exit $?;;
			-V | --verify )         verify; exit $?;;
			-h | --help )           display_help; exit $?;;
			-- )               shift; break ;;
			* )                break ;;
		esac
	done

}
