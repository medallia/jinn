#! /bin/bash
# Copyright 2016 Medallia Inc. All rights reserved
# Use of this source code is governed by the Apache 2.0
# license that can be found in the LICENSE file.

set -e
set -x

# local cache
mkdir -p /vagrant/registry-data

init_docker_conf "/etc/init/registry.conf" \
"Registry" \
"registry" \
"2.4.0" \
"registry" \
"routed" \
"10.112.255.254/32" \
"" \
"-v /vagrant/registry-data:/var/lib/registry"