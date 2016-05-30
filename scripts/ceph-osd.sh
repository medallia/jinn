#! /bin/bash
# Copyright 2016 Medallia Inc. All rights reserved
# Use of this source code is governed by the Apache 2.0
# license that can be found in the LICENSE file.

set -e
set -x

function set_pgnum(){
  local _PGNUM=$1
  
  until timeout 5 ceph osd pool set rbd pg_num ${_PGNUM} || [ $? -ne 16 ]
  do
      echo "sleeping"
      sleep 1
  done
  until timeout 5 ceph osd pool set rbd pgp_num ${_PGNUM} || [ $? -ne 16 ]
  do
      echo "sleeping"
      sleep 1
  done
}


function clean_drive () {
    devnode="${1}"

    # Not a block device, so expansion trick won't hold true
    if [ ! -b "${devnode}" ]; then
        return 1
    fi

    # We have a drive, let's see if the kernel found any partitions
    # on it. If there's any partitions; there's "something" on the drive
    # so we'll leave it alone.
    expanded=(${devnode}[0-9]*)
    if [ "${expanded}" != "${devnode}[0-9]*" ]; then
        return 1
    else
        return 0
    fi
}

function whitelisted_drive () {
    block_stub=${1##*/} 
    grep -P 'VBOX HARDDISK' "/sys/block/${block_stub}/device/model" >/dev/null 2>&1
}

function whitelisted_controller () {
    block_stub=${1##*/}

    # This is kludge; essentially since there's a varying level of pci controllers/buses/bridges, essentially
    # resolve absolute path, pass to sed, pick out everything up to something that's xxxx:xx:xx.x (where x is in 0-9a-f)
    pci_dev_path_stub=$(readlink -e /sys/block/${block_stub} | sed -r -e 's/^(.*\/[0-9a-f]{4}:[0-9a-f]{2}:[0-9a-f]{2}\.[0-9a-f])\/.*$/\1/')
    controller_vendor=$(cat ${pci_dev_path_stub}/vendor)
    controller_device=$(cat ${pci_dev_path_stub}/device)
    # Virtualbox specific vendor
    if [ "${controller_vendor}" = "0x8086" -a "${controller_device}" = "0x2829" ]; then
        return 0
    fi
    return 1
}

if [[ -z "$RACK" || -z "$HOSTNAME" || -z "$PGNUM" ]]; then
  echo "Missing Parameter(s)"
  exit 1
fi


if ! grep -P '^\s*osd\s+crush\s+location\s*=' /etc/ceph/ceph.conf >/dev/null; then
    sed -i -e "/^\[global\]/a osd crush location = host=$HOSTNAME rack=$RACK root=default" /etc/ceph/ceph.conf
fi

for sysblock in /sys/block/sd*; do
    devnode=/dev/${sysblock##*/}

    if clean_drive "${devnode}" && whitelisted_drive "${devnode}" && whitelisted_controller "${devnode}"; then
        echo "Install ceph OSD on ${devnode}"
        ceph-disk -v prepare --fs-type xfs --cluster ceph -- "${devnode}"
    else
        echo "Skipping ${devnode}"
    fi
done

## Add here temporarily.
set_pgnum ${PGNUM} || true