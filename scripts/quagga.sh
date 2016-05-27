#! /bin/bash
# Copyright 2016 Medallia Inc. All rights reserved
# Use of this source code is governed by the Apache 2.0
# license that can be found in the LICENSE file.

set -e
set -x

if [[ -z "$NET_IP" || -z "$CIDR" || -z "$INTERFACE" ]]; then
  echo "Missing Parameter(s)"
  exit 1
fi

# Upgrade quagga
_QF="quagga_0.99.24.1-2ubuntu1_amd64.deb"
_F=$(wget_file $_QF "http://archive.ubuntu.com/ubuntu/pool/main/q/quagga")
dpkg -i "${_F}"

# Install quagga
# Mode is broadcast and not point to point

perl -p -i -e 's/(zebra)=no/$1=yes/' /etc/quagga/daemons
perl -p -i -e 's/(ospfd)=no/$1=yes/' /etc/quagga/daemons

cat <<EOF >/etc/quagga/zebra.conf
! Bootstrap Config
ip forwarding
!
log syslog
!
EOF

cat <<EOF >/etc/quagga/ospfd.conf
! Bootstrap Config
router ospf
 ospf router-id ${NET_IP}
 redistribute kernel
 passive-interface default
 no passive-interface ${INTERFACE}
 network ${CIDR} area 0.0.0.0
 network 192.168.0.0/16 area 0.0.0.0
 network 10.255.255.0/24 area 0.0.0.0
!
log syslog
!
interface ${INTERFACE}
!
EOF

cat <<EOF >/etc/sysctl.d/60-jinn-routing.conf
#Proxy ARP on container interfaces
net.ipv4.conf.default.proxy_arp = 1
#Forward IPv4
net.ipv4.ip_forward=1
#Increase netfilter limit
net.netfilter.nf_conntrack_max = 4194304
EOF
