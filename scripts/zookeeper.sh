#! /bin/bash
# Copyright 2016 Medallia Inc. All rights reserved
# Use of this source code is governed by the Apache 2.0
# license that can be found in the LICENSE file.

set -e
set -x

ZK_IP=$(get_property ZK_IP)

if [[ -z "$CONTROLLER_ID" || -z "$ZK_IP" || -z "$ZK_HOSTS" ]]; then
  echo "Missing Parameter(s)"
  exit 1
fi

# TODO: Tune the size of the image created
ZK_PATH=$(create_image "mesos-zookeeper-${CONTROLLER_ID}")
if [[ -n "$ZK_PATH" ]]; then
    unmount_image "mesos-zookeeper-${CONTROLLER_ID}"
fi

init_docker_conf "/etc/init/zookeeper-docker.conf" \
    "Zookeeper For Mesos Cluster" \
    "medallia/zookeeper" \
    "v2.0.2-zk-3.4.8" \
    "zookeeper" \
    "$ZK_IP/32" \
    "" \
    "-v mesos-zookeeper-$CONTROLLER_ID:/opt/zookeeper:rw,ceph" \
    "-e CNXTIMEOUT=500" \
    "-e ZK_HOSTS=${ZK_HOSTS}"
