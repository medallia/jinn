#! /bin/bash
# Copyright 2016 Medallia Inc. All rights reserved
# Use of this source code is governed by the Apache 2.0
# license that can be found in the LICENSE file.

set -e
set -x


AURORA_SCHEDULER_IP=$(get_property AURORA_SCHEDULER_IP)

#Aurora needs mesos to initialiize the log
apt-get -y install mesos=0.28.0-2.0.16.ubuntu1404

echo manual >/etc/init/mesos-slave.override
echo manual >/etc/init/mesos-master.override
echo manual >/etc/init/zookeeper.override

if [[ -z "$CONTROLLER_ID" || -z "$AURORA_SCHEDULER_IP" || -z "$ZK_HOSTS" || -z "$QUORUM" || -z "$DC_NAME" ]]; then
  echo "Missing Parameter(s)"
  exit 1
fi

AURORA_PATH=$(create_image aurora-${CONTROLLER_ID})
if [[ -n "$AURORA_PATH" ]]; then
	mkdir -p $AURORA_PATH/scheduler/db
	chmod -R a+rwx $AURORA_PATH

	mesos-log initialize --path="${AURORA_PATH}/scheduler/db"
	unmount_image aurora-${CONTROLLER_ID}
fi

init_docker_conf "/etc/init/aurora-scheduler.conf" \
	"Aurora Scheduler" \
	"medallia/aurora-scheduler" \
	"0.11.0-medallia" \
	"aurora_scheduler" \
	"routed" \
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
