#! /bin/bash
# Copyright 2016 Medallia Inc. All rights reserved
# Use of this source code is governed by the Apache 2.0
# license that can be found in the LICENSE file.

set -e
set -x


#for jdk8
add-apt-repository ppa:openjdk-r/ppa

DISTRO=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
CODENAME=$(lsb_release -cs)

apt-get update &>/dev/null

# Install a kernel more recent than 4.2.0-35
min="4.2.3-35-generic"
lowest=$(printf "%s\n%s\n" "$(uname -r)" $min | sort -V | head -1)
if [[ $min != $lowest ]]; then
  echo ">>> Upgrading kernel from ${lowest}"
  apt-get install -y linux-generic-lts-xenial linux-headers-generic-lts-xenial
fi
