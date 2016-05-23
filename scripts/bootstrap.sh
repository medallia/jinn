#! /bin/bash
# Copyright 2016 Medallia Inc. All rights reserved
# Use of this source code is governed by the Apache 2.0
# license that can be found in the LICENSE file.

set -e
set -x
export DEBIAN_FRONTEND=noninteractive

if [[ -z "$NET_IP" || \
	  -z "$NET_MASK" || \
	  -z "$CONTROLLERS" || \
	  -z "$SLAVES"  || \
	  -z "$MONITORS"  || \
	  -z "$ROLES" || \
	  -z "$CIDR" || \
	  -z "$QUORUM" ]]; then
	echo "Missing Parameter(s)"
	env
	exit 1
fi

# Hosts computation

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

set_hostname () {
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


set_hostname $HOSTNAME $NET_IP


#create ZK hosts
array=()
for i in "${CTRLNODES[@]}"; do 
	n=$(get_property HOSTNAME $i)
	sed -i "/$n/d" /etc/hosts
	echo "$i $n" >> /etc/hosts
	array+=("$(get_property ZK_IP $i):2181")
done

ZK_HOSTS=$( IFS=, ; echo "${array[*]}" )


#create CEPH node hostnames
for i in "${CEPHNODES[@]}"; do 
	n=$(get_property HOSTNAME $i)
	sed -i "/$n/d" /etc/hosts
	echo "$i $n" >> /etc/hosts
done

#create SLAVES node hostnames
for i in "${SLNODES[@]}"
do
	n=$(get_property HOSTNAME $i)
    sed -i "/$n/d" /etc/hosts
    echo "$i $n" >> /etc/hosts
done

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

#for jdk8
sudo add-apt-repository ppa:openjdk-r/ppa

DISTRO=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
CODENAME=$(lsb_release -cs)

# DOCKER repo
cat >/etc/apt/sources.list.d/docker.list <<END
deb https://apt.dockerproject.org/repo ubuntu-trusty main
END

apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D

# CEPH repo
echo >/etc/apt/sources.list.d/ceph.list "deb http://ceph.com/debian-infernalis/ $(lsb_release -sc) main"
wget --quiet -O - 'https://ceph.com/git/?p=ceph.git;a=blob_plain;f=keys/release.asc' | sudo apt-key add -

#Mesos Repo
echo "deb http://repos.mesosphere.io/${DISTRO} ${CODENAME} main" >/etc/apt/sources.list.d/mesosphere.list
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv E56151BF

apt-get update &>/dev/null


CONTROLLER_ID=$(get_property CONTROLLER_ID)
CEPH_MON_ID=$(get_property CEPH_MON_ID)
CLUSTER=$(get_property CLUSTER)
PGNUM=$(get_property PGNUM)


. /vagrant/scripts/quagga.sh

. /vagrant/scripts/docker.sh

. /vagrant/scripts/ceph-client.sh

if has "REGISTRY" "${SRVROLES[@]}"; then
	. /vagrant/scripts/registry.sh
fi

if has "MON" "${SRVROLES[@]}"; then
	. /vagrant/scripts/ceph-mon.sh
fi

if has "OSD" "${SRVROLES[@]}"; then
	. /vagrant/scripts/ceph-osd.sh

	set_pgnum ${PGNUM} || true

fi

if has "MESOS-SLAVE" "${SRVROLES[@]}"; then
	. /vagrant/scripts/mesos-slave.sh
fi

if has "ZK" "${SRVROLES[@]}"; then
	. /vagrant/scripts/zookeeper.sh
fi

if has "MESOS-MASTER" "${SRVROLES[@]}"; then
	. /vagrant/scripts/mesos-master.sh
fi

if has "AURORA" "${SRVROLES[@]}"; then
	. /vagrant/scripts/aurora.sh
fi
