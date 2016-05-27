#! /bin/bash
# Copyright 2016 Medallia Inc. All rights reserved
# Use of this source code is governed by the Apache 2.0
# license that can be found in the LICENSE file.

set -e
set -x


AURORA_SCHEDULER_IP=$(get_property AURORA_SCHEDULER_IP)

if [[ -z "$CONTROLLER_ID" || -z "$AURORA_SCHEDULER_IP" || -z "$ZK_HOSTS" || -z "$QUORUM" || -z "$DC_NAME" ]]; then
  echo "Missing Parameter(s)"
  exit 1
fi

# TODO: Tune the size of the image created
AURORA_PATH=$(create_image aurora-${CONTROLLER_ID})
if [[ -n "$AURORA_PATH" ]]; then
  unmount_image aurora-${CONTROLLER_ID}
fi

init_docker_conf "/etc/init/aurora-scheduler.conf" \
  "Aurora Scheduler" \
  "docker.m8s.io/medallia/aurora-scheduler" \
  "0.12.0-medallia-2" \
  "aurora_scheduler" \
  "$AURORA_SCHEDULER_IP/32" \
  "-cluster_name=${DC_NAME} \
   -native_log_quorum_size=${QUORUM} \
   -zk_endpoints=${ZK_HOSTS} \
   -mesos_master_address=zk://${ZK_HOSTS}/mesos \
   -thermos_executor_resources=file:///root/.dockercfg \
   -initial_flapping_task_delay=5secs \
   -max_flapping_task_delay=15secs \
   -max_schedule_penalty=15secs" \
  "-v aurora-${CONTROLLER_ID}:/opt/aurora:rw,ceph"