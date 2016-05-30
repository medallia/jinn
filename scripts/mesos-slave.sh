#! /bin/bash
# Copyright 2016 Medallia Inc. All rights reserved
# Use of this source code is governed by the Apache 2.0
# license that can be found in the LICENSE file.

set -e
set -x

if [[ -z "$ZK_HOSTS" || -z "$HOSTNAME" || -z "$RACK" || -z "$UNIT" ]]; then
  echo "Missing Parameter(s)"
  exit 1
fi

mkdir -p /var/lib/mesos
mkdir -p /var/log/mesos

cpus=$(bc <<< "scale=1; $(cat /proc/cpuinfo | grep processor | wc -l) - 0.1")
echo "CPU: ${cpus}"
mem=$(bc <<< "scale=0; total=$(cat /proc/meminfo | grep MemTotal | awk '{print $2}')/1024; if (total >= 2048) {total - 1024} else {total/2}")
echo "MEM: ${mem}"
disk=$(bc <<< "scale=0; avail=$(df --output=avail /var/lib/mesos | sed '2q;d')/1024; if (avail >= 10*1024) {avail - 5*1024} else {avail/2}")
echo "DISK: $disk"

MESOS_DEDICATED=$(get_property MESOS_DEDICATED)

attributes="host:${HOSTNAME};rack:${RACK};unit:${UNIT}"
if [[ -n ${MESOS_DEDICATED} ]]; then
	attributes="${attributes};dedicated:${MESOS_DEDICATED}"
fi

init_docker_conf "/etc/init/mesos-slave-docker.conf" \
  "Mesos Slave" \
  "mesosphere/mesos-slave" \
  "0.28.1-2.0.20.ubuntu1404" \
  "mesos_slave" \
  "" \
  "" \
  "--privileged" \
  "-e MESOS_PORT=5051" \
  "-e MESOS_SWITCH_USER=0" \
  "-e MESOS_LOG_DIR=/var/log/mesos" \
  "-e MESOS_WORK_DIR=/var/lib/mesos" \
  "-e MESOS_ATTRIBUTES=\"${attributes}\"" \
  "-e MESOS_RESOURCES=\"cpu:${cpus};mem:${mem};disk:${disk}\"" \
  "-e MESOS_CONTAINERIZERS=docker,mesos" \
  "-e MESOS_MASTER=zk://$ZK_HOSTS/mesos" \
  "-e MESOS_EXECUTOR_REGISTRATION_TIMEOUT=60mins" \
  "-e MESOS_GC_DELAY=2days" \
  "-v /var/log/mesos:/var/log/mesos" \
  "-v /var/lib/mesos:/var/lib/mesos" \
  "-v /var/run/docker.sock:/var/run/docker.sock" \
  "-v /cgroup:/cgroup" \
  "-v /sys:/sys" \
  "-v /usr/bin/docker:/usr/bin/docker" \
  "-v /root/.dockercfg:/root/.dockercfg"
