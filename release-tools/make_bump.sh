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
script_dir="$(dirname $(realpath -s $0))"

#tools
project=$1
tmp_dir=$(mktemp -t -d cc-bump.XXXX)
release_tool="${tmp_dir}/release-tool"
hub_bin="${tmp_dir}/hub-bin"

function cleanup {
	rm  -rf "${tmp_dir}"
}

trap cleanup EXIT

die()
{
	msg="$*"
	echo "ERROR: ${msg}" >&2
	exit 1
}



function build_tools() {
	pushd ${script_dir}
	go build -o  "${release_tool}"
	popd
	git clone --depth 1 https://github.com/github/hub.git
	pushd hub
	./script/build -o "${hub_bin}"
	popd
}


function get_changes() {
	local current_version=$1

	git log --merges  "$current_version"..HEAD  | awk '/Merge pull/{getline; getline;print }'  | \
		while read -r pr
		do
			echo "- ${pr}"
		done

		echo ""

		for cr in  $(git log --merges  "$current_version"..HEAD  | grep 'Merge:' | awk '{print $2".."$3}');
		do
			git log --oneline "$cr"
		done

}

function generate_commit() {
	local new_version=$1
	local current_version=$2

	printf "release: Clear Containers %s\n\n" ${new_version}

	if [ "$(git log --oneline  ${current_version}..HEAD)"  == "" ]; then
		echo "Version bump no changes"
		return
	fi


	get_changes $current_version

}


function bump_project() {
	${hub_bin} clone "git@github.com:clearcontainers/${project}.git"

	pushd "${project}"
	${hub_bin} fork --remote-name=fork
	new_version=$(${release_tool} status --next-bump "${project}")
	current_version="$(cat VERSION)"

	release_notes_script="./scripts/release_notes.sh"
	notes_file=notes.md
	if [[ -x "${release_notes_script}" ]]
	then
		${release_notes_script} "${current_version}" "${new_version}" > "${notes_file}"
	else
		cat << EOT > ${notes_file}
# Clear Containers ${new_version}

## Changes

$(get_changes $current_version)
EOT
	fi

	echo "${new_version}" > VERSION
	if [ -f "configure.ac" ] ; then
		sed -i -e \
			"s|\(AC_INIT(\[[-a-zA-Z\_]*\],\s*\[\)${current_version}\(\]\)|\1${new_version}\2|g"\
			configure.ac
	fi
	branch="${new_version}-branch"
	${hub_bin} checkout -b "${branch}" master
	${hub_bin} add -u
	${hub_bin} commit -s -m "$(generate_commit $new_version $current_version)"
	echo "Push to fork"
	${hub_bin} push fork -f "${branch}"
	echo "Create PR"
	${hub_bin} pull-request -F ${notes_file}
	popd
}

if [ -z "${project}" ]; then
	echo need project
	exit 1
fi

pushd "$tmp_dir"
	build_tools
	bump_project
popd
