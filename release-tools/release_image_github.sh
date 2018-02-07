#!/bin/bash
# Copyright (c) 2018 Intel Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e
readonly script_name="${0##*/}"
readonly script_dir=$(dirname $(realpath -s "$0"))

readonly tmp_dir=$(mktemp -t -d cc-bump.XXXX)
readonly release_tool="${tmp_dir}/release-tool"
readonly osbuilder_dir="${tmp_dir}/osbuilder/"
readonly workdir_builder=${osbuilder_dir}
readonly repo_owner="clearcontainers"
push=false

readonly versions_file="https://raw.githubusercontent.com/clearcontainers/runtime/master/versions.txt"
os_version="$(curl -Ls ${versions_file} | grep '^clear_vm_image_version=' | cut -d= -f 2)"
agent_version="$(curl -Ls ${versions_file} | grep '^cc_agent_version=' | cut -d= -f 2)"

function cleanup {
	if [ -d "${osbuilder_dir}" ]; then
		info "Remove temp dir: ${osbuilder_dir}"
		#osbuilder generated files are own by root
		sudo rm -rf "${osbuilder_dir}"
	fi

	rm -rf "${tmp_dir}"
}

trap cleanup EXIT

die() {
	echo >&2 -e "\e[1mERROR\e[0m: $*"
	exit 1
}

info() {
	echo -e "\e[1mINFO\e[0m: $*"
}



source "${script_dir}/../versions.txt"


build_image() {
	export USE_DOCKER=1
	export WORKDIR="${workdir_builder}"

	AGENT_VERSION="${agent_version}" OS_VERSION="${os_version}" make rootfs
	make image
}

build_release_tool() {
	pushd "${script_dir}/../release-tools/"
	info "build release tool"
	go build -o "${release_tool}"
	popd
}

get_image_version() {
	local agent_version="$1"
	local os_version="$2"

	[ -n ${agent_version} ] || die "need agent version"
	[ -n ${os_version} ] || die "need os version"

	echo "cc-${os_version}-agent-${agent_version:0:6}"
}

get_dist_name(){
	local image_version=$1
	[ -n ${image_version} ] || die "need image version"
	echo "image-${image_version}-binaries"
}

release_image() {
	info "Creating image tarball"
	image_version=$(get_image_version "$agent_version" "$os_version")
	dist_bin_name=$(get_dist_name "${image_version}")
	image_name="${image_version}.img"
	mkdir -p "${dist_bin_name}"

	cp ${workdir_builder}/container.img "${dist_bin_name}/${image_name}"
	cp ${workdir_builder}/image_info "${dist_bin_name}/${image_version}.info"
	sed \
		-e "s|@IMAGE@|${image_name}|g" \
		-e "s|@VMLINUX@|${dist_vmlinuz}|g" \
		"${script_dir}/Makefile.dist.install.image" > "${dist_bin_name}/Makefile"

	tarball_gz="${dist_bin_name}.tar.gz"
	tar -zvcf "${tarball_gz}" "${dist_bin_name}"
	shasum="SHA512SUMS"
	sha512sum "${tarball_gz}" > "${shasum}"

	if [ -n "${output_dir}" ]; then 
		[ -d "${output_dir}" ] || die "$output_dir not a directory"
		cp "${tarball_gz}" "${output_dir}"
		cp "${shasum}" "${output_dir}"
	fi
	if [ "${push}" = true ]; then
		[ -z "$GITHUB_TOKEN" ] && die "\$GITHUB_TOKEN is empty"
		build_release_tool
		info "creating release"
		${release_tool} --owner "${repo_owner}" \
			release \
			--asset "${tarball_gz}" \
			--asset "${shasum}" \
			--force-version \
			--version "${image_version}" "osbuilder"
	fi

}

get_image_tarball_url() {
	local agent_version="$1"
	local os_version="$2"

	[ -n ${agent_version} ] || die "need agent version"
	[ -n ${os_version} ] || die "need os version"

	local releases_url="https://github.com/${repo_owner}/osbuilder/releases"
	local image_version=$(get_image_version "$agent_version" "$os_version")
	local dist_name=$(get_dist_name $image_version)

	echo "${releases_url}/download/${image_version}/${dist_name}.tar.gz"
}

usage() { 
	cat << EOT
Usage: $0 [options] <subcommand>
Script to build and publish an new Clear Containers Image.

subcommands:
	release
	check-updated
	latest-version-url

release: Create a new image

check-updated: Checks if latest image is uptodate to runtime versions

Options:
-a <version>    : Agent version to use (default: runtime versions file)
-c <version>    : Clear Linux version to use (default: runtime versions file)
-h              : show this help
-o <dir>        : Create resulting image in <dir>
-p              : Push to git-repo default: ${push}
-r <repo-owner> : git repository to push image
-t <token>      : Github token to create new release. ENV: \$GITHUB_TOKEN
                  this option has higher priority than env variable
EOT
exit
}

while getopts a:c:hr:t:o:p opt
do
	case $opt in
		a)
			agent_version="${OPTARG}"
			;;
		c)
			os_version=${OPTARG}
			;;
		h)
			usage
			exit
			;;
		o)
			output_dir="${OPTARG}"
			[ -d "${output_dir}" ] || die "$output_dir not a directory"
			;;
		p)
			push=true
			;;
		r)
			repo_owner="${OPTARG}"
			;;
		t)
			export GITHUB_TOKEN=${OPTARG}
			;;
	esac
done

shift $(($OPTIND - 1))
subcmd="$1"
[ -n "${subcmd}" ] || usage

case "$subcmd" in
	release)
		pushd "$tmp_dir"

		git clone "https://github.com/${repo_owner}/osbuilder.git" "${osbuilder_dir}"
		pushd osbuilder

		build_image
		release_image

		popd
		popd
		;;

	check-updated)
		tarball_url=$(get_image_tarball_url "${agent_version}" "${os_version}")
		if curl -o /dev/null --silent --head --fail "$tarball_url"; then
			echo "Image uptodate: $tarball_url"
			exit
		else
			echo "Image not up-to-date: $tarball_url"
			exit -1
		fi
		;;
	latest-version-url)
		tarball_url=$(get_image_tarball_url "${agent_version}" "${os_version}")
		if curl -o /dev/null --silent --head --fail "$tarball_url"; then
			echo "$tarball_url"
			exit
		else
			echo "Image not updated use ${script_name} -p release"
		fi
		;;


	*)
		usage
esac

