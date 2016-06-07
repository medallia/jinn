#! /bin/bash
# Copyright 2016 Medallia Inc. All rights reserved
# Use of this source code is governed by the Apache 2.0
# license that can be found in the LICENSE file.

set -e
set -x

if [[ -z "$NET_IP" || -z "$CIDR" || -z "$USER" ]]; then
  echo "Missing Parameter(s)"
  exit 1
fi

apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
add-repo docker https://apt.dockerproject.org/repo ubuntu-trusty main

apt-get -y install docker-engine=1.9.1-0~trusty

service docker stop || true

for f in docker.override docker-iptables.conf; do
  copy_file "/docker/$f" "/etc/init/$f"
done


FILE="docker-1.9.1-medallia-2-linux-amd64"
_F=$(wget_file $FILE "https://github.com/medallia/docker/releases/download/v1.9.1-medallia-2")
sudo cp ${_F} /usr/bin/docker && sudo chmod +x /usr/bin/docker

chmod a+x /usr/bin/docker

# Docker access for medallia user
gpasswd -a $USER docker

# TODO replace with appropriate hub configuration
cat /vagrant/.dockercfg > /etc/dockercfg

rm -f /root/.dockercfg

ln -s /etc/dockercfg /root/.dockercfg

mkdir -p /var/lib/docker

cat >>/etc/default/docker << EOF
DOCKER_OPTS="-s overlay --insecure-registry 10.112.255.254:5000 --iptables=false"
EOF
service docker start || true
