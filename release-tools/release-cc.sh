#!/bin/bash
#
# Copyright (c) 2017 Intel Corporation
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
script_name="${0##*/}"
script_dir="$(dirname $(realpath -s "$0"))"
release_tool="${script_dir}/release-tool"
owner=${OWNER:-clearcontainers}

function usage() {
cat << EOT
Usage: ${script_name}
This script creates a new release for Clear Containers
It tags and create release for:

  - Proxy
  - Shim
  - Runtime

Environment variables:

GITHUB_TOKEN: Export GITHUB_TOKEN variable with a valid token and repository permissions
       See: https://help.github.com/articles/creating-a-personal-access-token-for-the-command-line/
EOT
}

die()
{
	msg="$*"
	echo "ERROR: ${msg}" >&2
	exit 1
}

function build_release_tool() {
	go build -o  "${release_tool}"
}

function check_token() {
	if [ -z "$GITHUB_TOKEN" ]; then
		echo "token is empty"
		usage
		exit
	fi
}

function release(){
	commit="master"
	local URL_RAW_FILE="https://raw.githubusercontent.com/clearcontainers"

	expected_next_version="$(${release_tool} status --next-bump runtime)"
	runtime_version=$(curl -Ls ${URL_RAW_FILE}/runtime/${commit}/VERSION)
	shim_version=$(curl -Ls ${URL_RAW_FILE}/shim/${commit}/VERSION)
	proxy_version=$(curl -Ls ${URL_RAW_FILE}/proxy/${commit}/VERSION)

	echo "runtime version ${runtime_version}"
	echo "shim version ${shim_version}"
	echo "proxy version ${proxy_version}"

	[ "${runtime_version}" == "${expected_next_version}" ] || die "Expected new version ${expected_next_version}"
	[ "${runtime_version}" == "${shim_version}" ] || die "shim version is not equals to runtime version"
	[ "${runtime_version}" == "${proxy_version}" ] || die "proxy version is not equals to runtime version"

	repos=( shim proxy runtime )
	clearcontainers_version="${runtime_version}"
	for repo in "${repos[@]}"; do
		echo "Release ${repo}"
		echo ${release_tool} --owner "${owner}" release --version "${clearcontainers_version}" "${repo}"
	done
}

build_release_tool
check_token
release
