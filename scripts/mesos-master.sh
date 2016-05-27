#! /bin/bash
# Copyright 2016 Medallia Inc. All rights reserved
# Use of this source code is governed by the Apache 2.0
# license that can be found in the LICENSE file.

set -e
set -x

MESOS_MASTER_IP=$(get_property MESOS_MASTER_IP)

if [[ -z "$ZK_HOSTS" || -z "$CONTROLLER_ID" || -z "$DC_NAME" || -z "$QUORUM" || -z "$MESOS_MASTER_IP" ]]; then
  echo "Missing Parameter(s)"
  exit 1
fi

# TODO: Tune the size of the image created
MESOS_PATH=$(create_image mesos-master-${CONTROLLER_ID})
if [[ -n "$MESOS_PATH" ]]; then
  unmount_image mesos-master-${CONTROLLER_ID}
fi

init_docker_conf "/etc/init/mesos-master-docker.conf" \
  "Mesos Master" \
  "mesosphere/mesos-master" \
  "0.28.0-2.0.16.ubuntu1404" \
  "mesos_master" \
  "$MESOS_MASTER_IP/32" \
  "--registry=replicated_log" \
  "-v mesos-master-$CONTROLLER_ID:/opt/mesos:rw,ceph" \
  "-e MESOS_CLUSTER=${DC_NAME}" \
  "-e MESOS_QUORUM=${QUORUM}" \
  "-e MESOS_WORK_DIR=/opt/mesos/workdir" \
  "-e MESOS_LOG_DIR=/opt/mesos/logs" \
  "-e MESOS_ZK=zk://$ZK_HOSTS/mesos" \
  "-e MESOS_HOSTNAME=$MESOS_MASTER_IP"
