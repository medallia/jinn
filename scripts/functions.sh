#! /bin/bash
# Copyright 2016 Medallia Inc. All rights reserved
# Use of this source code is governed by the Apache 2.0
# license that can be found in the LICENSE _file.

set -e
set -x


has () {
	# thanks to http://stackoverflow.com/a/8574392
	local e
	for e in "${@:2}"; do [ "$e" == "$1" ] && return 0; done
	return 1
}


function create_image(){
	local _IMG=$1
	local _size=${2:-4G}	
	if [[ -z  $(rbd ls | grep ${_IMG}) ]] ; then
		rbd create ${_IMG} --size "${_size}"
		dev=$(rbd map ${_IMG})
		if [ -n "${dev}" ]; then
			mkfs.ext4 -m0 $dev &>/dev/null
			mkdir -p /mnt/${_IMG}
			mount /dev/rbd/rbd/${_IMG} /mnt/${_IMG}
			echo "/mnt/${_IMG}"
			return 0
		fi
	fi
	echo ""
}


function unmount_image(){
	local _IMG=$1
	local _device="$(rbd showmapped | grep ${_IMG} | awk '{print $5}')"
	if [[ -n ${_device} ]]; then
		umount /mnt/${_IMG} || true
		rbd unmap ${_device} 
	fi
}

function init_docker_conf() {
	local _FILE=$1
	local _DESCRIPTION=$2
	local _IMAGE=$3
	local _TAG=$4
	local _CONTAINER=$5
	local _NETWORK=$6
	local _IP=$7
	local _ARGS=$8
	shift 8
cat <<EOF> "$_FILE"
description "$_DESCRIPTION"
start on filesystem and started docker
stop on runlevel [!2345]
respawn
respawn limit unlimited
env TAG=$_TAG
script
  [ -f /etc/default/$CONTAINER ] && . /etc/default/$_CONTAINER
  /usr/bin/docker rm --force=true $_CONTAINER || true
  exec docker run --rm -t $@ --net=$_NETWORK --ip-address=$_IP \
    --name=$_CONTAINER \
    $_IMAGE:\$TAG $_ARGS
end script
pre-start script
  [ -f /etc/default/$_CONTAINER ] && . /etc/default/$_CONTAINER
  /usr/bin/docker pull $_IMAGE:\$TAG || true
end script
pre-stop script
  /usr/bin/docker rm --force=true $_CONTAINER || true
end script
EOF
}