#! /bin/bash
# Copyright 2016 Medallia Inc. All rights reserved
# Use of this source code is governed by the Apache 2.0
# license that can be found in the LICENSE file.

set -e
set -x
export DEBIAN_FRONTEND=noninteractive

if [[ -z "$CLUSTER" || -z "$HOSTNAME" || -z "$FSID" || -z "$PGNUM" ]]; then
  echo "Missing Parameter(s)"
  exit 1
fi

echo "Installing Ceph ..."

# Ceph Package Install
apt-get -y install ceph

mkdir -p /vagrant/ceph

if [ ! -e /vagrant/ceph/$CLUSTER.client.admin.keyring ]; then
  ceph-authtool --create-keyring /vagrant/ceph/ceph.client.admin.keyring --gen-key -n client.admin --set-uid=0 --cap mon 'allow *' --cap osd 'allow *' --cap mds 'allow'
fi

if [ ! -e /vagrant/ceph/bootstrap-osd.$CLUSTER.keyring ]; then
  ceph-authtool /vagrant/ceph/bootstrap-osd.$CLUSTER.keyring --create-keyring --gen-key -n client.bootstrap-osd --cap mon 'allow profile bootstrap-osd'
fi

if [ ! -e /vagrant/ceph/bootstrap-mds.$CLUSTER.keyring ]; then
  ceph-authtool /vagrant/ceph/bootstrap-mds.$CLUSTER.keyring --create-keyring --gen-key -n client.bootstrap-mds --cap mon 'allow profile bootstrap-mds'
fi

if [ ! -e /vagrant/ceph/bootstrap-rgw.$CLUSTER.keyring ]; then
  ceph-authtool /vagrant/ceph/bootstrap-rgw.$CLUSTER.keyring --create-keyring --gen-key -n client.bootstrap-rgw --cap mon 'allow profile bootstrap-rgw'
fi

NBMONS=$(get_property NBMONS)

cat > /etc/ceph/ceph.conf <<- END
  [global]
  fsid = $FSID
  mon_host = $(IFS=, ; echo "${CEPHNODES[*]}")
  auth_cluster_required = cephx
  auth_service_required = cephx
  auth_client_required = cephx
  filestore_xattr_use_omap = true
  osd crush chooseleaf type = 0
  osd journal size = 100
  osd pool default pg num = $PGNUM
  osd pool default pgp num = $PGNUM
  osd pool default size = $NBMONS
END

# Wrapper for Ceph RBD that prevents mapping an image already watched
#dpkg-divert --divert /usr/bin/rbd.original --rename /usr/bin/rbd
#install_web_file "/ceph/rbd-wrapper" "/usr/bin/rbd"
#chmod 755 /usr/bin/rbd

#install_web_file "/ceph/remove-rbd-own-locks" "/usr/bin/remove-rbd-own-locks"
#chmod 755 /usr/bin/remove-rbd-own-locks


if [ -e /vagrant/$CLUSTER/$CLUSTER.client.admin.keyring ]; then
  cp /vagrant/$CLUSTER/$CLUSTER.client.admin.keyring /etc/ceph/
  chown $USER:$GROUP /etc/ceph/$CLUSTER.client.admin.keyring
  chmod 0640 /etc/ceph/$CLUSTER.client.admin.keyring
else
  echo "CEPH not initialized. Cannot find admin keyring"
    exit 1
fi  
