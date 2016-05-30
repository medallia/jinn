#  Jinn: A datacenter experiementation and development environment

## Description

## Dependencies
- Vagrant (with Virtualbox)
- vagrant_cashier (optional)
- vagrant_reload

## Installation
- install vagrant
https://www.vagrantup.com/downloads.html

- install plugins
``` 
vagrant plugin install vagrant-reload 
vagrant plugin install vagrant-cachier 
```

- add box to vagrant
```
vagrant box add ubuntu/trusty64
```

- create configuration
```
cp jinn-small.yml jinn.yml
```

- start environment
```
vagrant up
```
## Test

- ssh to a controller and launch the example
```
vagrant ssh controller1

aurora job create jinn/test/devel/dockerTest /vagrant/examples/dockertest.aurora
```
Use your browser and go to the following URL:
http://10.112.100.10:8000/

## Troubleshooting

You can use the check.sh script, or run the tests manually:
```
bash check.sh
```

- verify the routes to the vagrant machines
```
$ route get 10.112.0.0
   route to: 10.112.0.0
destination: 10.112.0.0
       mask: 255.240.0.0
  interface: vboxnet1
      flags: <UP,DONE,CLONING>
 recvpipe  sendpipe  ssthresh  rtt,msec    rttvar  hopcount      mtu     expire
       0         0         0         0         0         0      1500   -288604
 ```

- verify zookeeper health. Mode can be either standalone for 1 controller, or leader/follower for 3 controllers.
```
vagrant@jinn-r10-u08:/$ echo stat | nc 192.168.255.31 2181 | grep Mode:
Mode: standalone
```

- verify mesos election status:
```
vagrant@jinn-r10-u08:/$ curl -s http://10.112.255.11:5050/metrics/snapshot | grep -oh "elected\"\:1.0"
elected":1.0
```

- verify Aurora election status
```
agrant@jinn-r10-u08:/$ curl -s http://10.112.255.21:8081/vars | grep registered
framework_registered 1
```

- verify ceph health (Warning for clock skew may sometime happen - it's not critical):
```
vagrant@jinn-r10-u08:/$ sudo ceph -s
    cluster 07c965c8-fa90-4b17-9682-cad35a8e7bd6
     health HEALTH_OK
     monmap e1: 1 mons at {jinn-r10-u23=10.112.10.94:6789/0}
            election epoch 1, quorum 0 jinn-r10-u23
     osdmap e24: 3 osds: 3 up, 3 in
            flags sortbitwise
      pgmap v71: 128 pgs, 1 pools, 415 MB data, 147 objects
            505 MB used, 29881 MB / 30386 MB avail
                 128 active+clean
  client io 163 B/s wr, 0 op/s
```

- verify network routes. For one controller, should have something like:
```
vagrant@jinn-r10-u08:/$ sudo vtysh -c 'show ip ospf database' | grep 10.112.10.34
       OSPF Router with ID (10.112.10.34)
10.112.10.34    10.112.10.34     761 0x8000000a 0xc5d6 1
10.112.255.11   10.112.10.34     605 0x80000001 0x840e E2 10.112.255.11/32 [0x0]
10.112.255.21   10.112.10.34     545 0x80000001 0x2068 E2 10.112.255.21/32 [0x0]
192.168.255.31  10.112.10.34     595 0x80000001 0xd1bd E2 192.168.255.31/32 [0x0]
```

- verify controller logs under /var/log/upstart:
```
zookeeper-docker.log
mesos-slave-docker.log
mesos-master-docker.log
aurora-scheduler.log
```

## Starting a fresh environment
If you have errors that you cannot diagnose and solve, you may want to start from zero. To speed things up, some state is preserved on the host.
To clear the state:
```
vagrant destroy -f
rm -rf ceph
rm -rf cached-files
rm -rf registry-data
vagrant up
```
___________________________________________________
*Copyright 2016 Medallia Inc. All rights reserved*

