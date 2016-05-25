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


FILE="docker-1.9.1-medallia-2-linux-amd64"
if [[ ! -e /vagrant/cached-files/${FILE} ]]; then
  mkdir -p /vagrant/cached-files
  DOCKER_URL="https://github.com/medallia/docker/releases/download/v1.9.1-medallia-2/$FILE"
  wget --quiet $DOCKER_URL -O /vagrant/cached-files/${FILE}
fi
sudo cp /vagrant/cached-files/${FILE} /usr/bin/docker && sudo chmod +x /usr/bin/docker

# Docker init-script has changed upstream, we expect -d, init script uses daemon
sed -i -e 's/exec \"$DOCKER\" daemon/exec \"$DOCKER\" -d/' /etc/init/docker.conf

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
