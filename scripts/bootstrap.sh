#! /bin/bash
# Copyright 2016 Medallia Inc. All rights reserved
# Use of this source code is governed by the Apache 2.0
# license that can be found in the LICENSE file.

set -e
set -x
export DEBIAN_FRONTEND=noninteractive

env

if [[ -z "$NET_IP" || \
    -z "$NET_MASK" || \
    -z "$CONTROLLERS" || \
    -z "$SLAVES"  || \
    -z "$MONITORS"  || \
    -z "$ROLES" || \
    -z "$CIDR" || \
    -z "$QUORUM" ]]; then
  echo "Missing Parameter(s)"
  exit 1
fi

SCRIPT_PATH="${1:-/vagrant/scripts}"

# Hosts arrays computation
IFS=' ' read -a CTRLNODES <<< "${CONTROLLERS}"
IFS=' ' read -a SLNODES <<< "${SLAVES}"
IFS=' ' read -a CEPHNODES <<< "${MONITORS}"

# Roles
IFS=' ' read -a SRVROLES <<< "${ROLES}"

. /vagrant/scripts/properties.sh
. /vagrant/scripts/functions.sh

HOSTNAME=$(get_property HOSTNAME)
RACK=$(get_property RACK)
UNIT=$(get_property UNIT)

ZK_HOSTS=$(get_property ZK_HOSTS)

INTERFACE="eth1"

CONTROLLER_ID=$(get_property CONTROLLER_ID)
CEPH_MON_ID=$(get_property CEPH_MON_ID)
CLUSTER=$(get_property CLUSTER)

PGNUM=$(get_property PGNUM)

echo ">>> Updating APT sources"
call apt.sh

echo ">>> Updating Hostname and /etc/hosts"
call host.sh

echo ">>> Installing Quagga"
call quagga.sh

echo ">>> Installing Docker"
call docker.sh

echo ">>> Installing Ceph client"
call ceph.sh

if has "REGISTRY" "${SRVROLES[@]}"; then
  echo ">>> Installing Docker Registry"
  call registry.sh
fi

if has "MON" "${SRVROLES[@]}"; then
  echo ">>> Installing Ceph Monitors"
  call ceph-mon.sh
fi

if has "OSD" "${SRVROLES[@]}"; then
  echo ">>> Installing Ceph OSDs"
  call ceph-osd.sh

  set_pgnum ${PGNUM} || true

fi

if has "MESOS-SLAVE" "${SRVROLES[@]}"; then
  echo ">>> Installing Mesos nodes"
  call mesos-slave.sh
fi

if has "ZK" "${SRVROLES[@]}"; then
  echo ">>> Installing Zookeeper"
  call zookeeper.sh
fi

if has "MESOS-MASTER" "${SRVROLES[@]}"; then
  echo ">>> Installing Mesos Master"
  call mesos-master.sh
fi

if has "AURORA" "${SRVROLES[@]}"; then
  echo ">>> Installing Aurora Scheduler"
  call aurora.sh
fi
