#! /bin/bash
# Copyright 2016 Medallia Inc. All rights reserved
# Use of this source code is governed by the Apache 2.0
# license that can be found in the LICENSE file.

set -e
set -x


if [[ -z "$CLUSTER" || -z "$HOSTNAME" || -z "$FSID" ]]; then
  echo "Missing Parameter(s)"
  exit 1
fi

USER="ceph"
GROUP="ceph"




# Initialize CEPH config

mkdir -p /vagrant/ceph

if [ ! -e /vagrant/ceph/$CLUSTER.mon.keyring ]; then
	ceph-authtool --create-keyring /vagrant/ceph/$CLUSTER.mon.keyring --gen-key -n mon. --cap mon 'allow *'

	ceph-authtool /vagrant/ceph/$CLUSTER.mon.keyring --import-keyring /vagrant/ceph/$CLUSTER.client.admin.keyring
	ceph-authtool /vagrant/ceph/$CLUSTER.mon.keyring --import-keyring /vagrant/ceph/bootstrap-osd.$CLUSTER.keyring
	ceph-authtool /vagrant/ceph/$CLUSTER.mon.keyring --import-keyring /vagrant/ceph/bootstrap-mds.$CLUSTER.keyring
	ceph-authtool /vagrant/ceph/$CLUSTER.mon.keyring --import-keyring /vagrant/ceph/bootstrap-rgw.$CLUSTER.keyring

	chmod 0755 /vagrant/ceph/$CLUSTER.mon.keyring
fi


mkdir -p /var/lib/ceph/mon/$CLUSTER-$HOSTNAME
chown $USER:$GROUP /var/lib/ceph/mon/$CLUSTER-$HOSTNAME
chmod 0755 /var/lib/ceph/mon/$CLUSTER-$HOSTNAME

temp="$(mktemp /tmp/$CLUSTER.XXXX)"

counter=1
array=()
for i in "${CEPHNODES[@]}"; do 
	array+=("--add $(get_property HOSTNAME $i) $i:6789")
	(( counter++ ))
done

monmaptool --create $( echo "${array[*]}" ) --fsid $FSID --clobber $temp

mv $temp /etc/ceph/monmap
chown $USER:$GROUP /etc/ceph/monmap
chmod 0640 /etc/ceph/monmap

mkdir -p /var/lib/ceph/bootstrap-{osd,mds,rgw}

sudo cp /vagrant/ceph/bootstrap-osd.$CLUSTER.keyring /var/lib/ceph/bootstrap-osd/$CLUSTER.keyring
chown $USER:$GROUP /var/lib/ceph/bootstrap-osd/$CLUSTER.keyring
sudo cp /vagrant/ceph/bootstrap-mds.$CLUSTER.keyring /var/lib/ceph/bootstrap-mds/$CLUSTER.keyring 
chown $USER:$GROUP /var/lib/ceph/bootstrap-mds/$CLUSTER.keyring 
sudo cp /vagrant/ceph/bootstrap-rgw.$CLUSTER.keyring /var/lib/ceph/bootstrap-rgw/$CLUSTER.keyring
chown $USER:$GROUP /var/lib/ceph/bootstrap-rgw/$CLUSTER.keyring

ceph-mon --setuser $USER --setgroup $GROUP --mkfs -i $HOSTNAME --monmap /etc/ceph/monmap --keyring /vagrant/ceph/$CLUSTER.mon.keyring


touch /var/lib/ceph/mon/$CLUSTER-$HOSTNAME/done

touch /var/lib/ceph/mon/$CLUSTER-$HOSTNAME/upstart

stop ceph-mon cluster=$CLUSTER id=$HOSTNAME || true
start ceph-mon cluster=$CLUSTER id=$HOSTNAME
