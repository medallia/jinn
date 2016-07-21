#! /bin/bash
# Copyright 2016 Medallia Inc. All rights reserved
# Use of this source code is governed by the Apache 2.0
# license that can be found in the LICENSE file.

set -e
set -x


function set_hostname() {
  local hostname=$1
  local my_ip=$2
  cat >/etc/hosts <<END
$my_ip  $hostname 
127.0.0.1   localhost

# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
END
  echo "$1" >/etc/hostname
  hostname "$1"
}

function set_hosts() {
  declare -a _array=("${!1}")

  for i in "${_array[@]}"; do
    n=$(get_property HOSTNAME "$i")
    sed -i "/$n/d" /etc/hosts
    echo "$i $n" >> /etc/hosts
  done
}

if [[ -z "$NET_IP" || -z "$HOSTNAME" || -z "$CTRLNODES" || -z "$CEPHNODES" || -z "$SLNODES" || -z "$CIDR" ]]; then
  echo "Missing Parameter(s)"
  exit 1
fi

set_hostname "$HOSTNAME" "$NET_IP"

#create ZK hosts
echo ">>> Add Controllers to /etc/hosts"
set_hosts CTRLNODES[@]

#create CEPH node hostnames
echo ">>> Add CEPH nodes to /etc/hosts"
set_hosts CEPHNODES[@]

#create SLAVES node hostnames
echo ">>> Add Compute nodes to /etc/hosts"
set_hosts SLNODES[@]


cat <<'EOF' > /etc/rc.local
#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "exit 0" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.

# If "aa-complain" fails, it doesn't exec the "ip route" command.
aa-complain /etc/apparmor.d/docker || true

# Adding blackhole route to prevent loops between host and guest
# when trying to reach an unexistent IP.
# Left with higher metric in case we want to test a manual route
# in some scenario
ip route add blackhole $CIDR metric 50
exit 0
EOF
