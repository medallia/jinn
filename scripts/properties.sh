#! /bin/bash
# Copyright 2016 Medallia Inc. All rights reserved
# Use of this source code is governed by the Apache 2.0
# license that can be found in the LICENSE file.

set -ex

# get_property returns a computed parameter
# example :
# MESOS_NODE_ID=$(get_property MESOS_NODE_ID)
# usage: get_property VARIABLE
# Input: VARIABLE one of COLLECTD_NODE_ID, MESOS_NODE_ID, MESOS_SLAVE, CEPH_OSD, HOSTNAME, RACK, DC, DC_NAME, DC_PREFIX
# expected environment variables NET_IP
# Returns:
#     success: value and sets $? to 0
#     failure: "" and sets $? to 1

# The function return 0 in case of success and 1 otherwise
# If the script calling the function is using set -e this will cause the script to exit.
# This is probably OK as the result of ignoring the error is likely very bad

function get_property()
{
  local _CONTROLLER_ID=""
    local _HOSTNAME="" 
  local _DC="" 
  local _RACK="" 
  local _UNIT=""
  local _ZK_IP=""
  local _ZK_HOSTS=""
  local _MESOS_MASTER_IP=""
  local _AURORA_SCHEDULER_IP=""
  local _MESOS_DEDICATED=""
  local _CEPH_MON_ID=""
  local _NBMONS=""
  local _PGNUMS=256
  local _CLUSTER="${CLUSTER:-ceph}"
  local _var=$1
  local _NET_IP=$2
  local property
  local i1 i2 i3 i4
  local m1 m2 m3 m4

  if [ -z "$1" ]; then
    return 1
  fi

  if [ -n "${_NET_IP}" ]; then
    NET_IP=${_NET_IP}
  fi


  if [[ -z "${NET_IP}" ||  -z "${NET_MASK}"  ||  -z "${DC_NAME}" || -z "${CTRLNODES}" || -z ${NET_MASK} ]]; then
    echo "Missing Parameter(s)"
    exit 1
  fi

  # Calculate Network value based on a netmask and IP
  IFS=. read -r i1 i2 i3 i4 <<< "${NET_IP}"
  #remove leading 0 to avoid octal confusion
  NET_IP="${i1#0}.${i2#0}.${i3#0}.${i4#0}"
  IFS=. read -r i1 i2 i3 i4 <<< "${NET_IP}"
  IFS=. read -r m1 m2 m3 m4 <<< "${NET_MASK}"
  _DC_PREFIX=$(printf "%d.%d.%d.%d\n" "$((i1 & m1))" "$((i2 & m2))" "$((i3 & m3))" "$((i4 & m4))")

  _DC=$(echo ${_DC_PREFIX} | cut -d. -f2)
  _RACK=$(echo ${NET_IP} | cut -d. -f3)
  _UNIT=$(( ($(echo ${NET_IP} | cut -d. -f4) - 2) / 4))

  _HOSTNAME=$(printf '%s-r%02d-u%02d' "${DC_NAME}" "${_RACK}" "${_UNIT}")

  # calculate  controller id
  counter=1
  array=()
  for ip in "${CTRLNODES[@]}"; do 
    if [ "$ip" = "$NET_IP" ]; then
      _CONTROLLER_ID=$counter
    fi
    zk_ip="192.168.255.$(( counter + 30 ))"
    array+=("$zk_ip:2181")
    (( counter ++ ))
  done

  _ZK_HOSTS=$( IFS=, ; echo "${array[*]}" )

  if [[ -n "${_CONTROLLER_ID}" ]]; then
    _ZK_IP="192.168.255.$((_CONTROLLER_ID + 30))"
    _MESOS_MASTER_IP="10.${_DC}.255.$((_CONTROLLER_ID + 10))"
    _AURORA_SCHEDULER_IP="10.${_DC}.255.$((_CONTROLLER_ID + 20))"
    _MESOS_DEDICATED="controller"
  fi

  # calculate  monitor id
  counter=1
  for ip in "${CEPHNODES[@]}"; do 
    if [ "$ip" = "$NET_IP" ]; then
      _CEPH_MON_ID=$counter
    fi
    (( counter ++ ))
  done
  (( _NBMONS = counter - 1 ))

  if [[ $_NBMONS -lt 3 ]]; then
    _PGNUM=128
  else
    _PGNUM=256
  fi

  if [[ -n "${_CEPH_MON_ID}" ]]; then
    #placeholder to calculate monitor IP
    _MON_IP=""
  fi

  # check if the local variable equivalent to the property is set
  property=_$_var
  if [[ ${!property+isset} = isset ]]; then
    # property is known, return value
    echo ${!property}
  else
    # property is not known
    return 1
  fi

  return 0
}
