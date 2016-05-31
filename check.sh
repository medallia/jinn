#! /bin/bash
# Copyright 2016 Medallia Inc. All rights reserved
# Use of this source code is governed by the Apache 2.0
# license that can be found in the LICENSE file.
set -u

pass(){
  printf $(tput setaf 2)
  printf "${@}"
  printf $(tput sgr0)
}
fail(){
  printf $(tput setaf 1)
  printf "${@}"
  printf $(tput sgr0)
}
title(){
  printf $(tput bold)
  printf "${@}"
  printf $(tput sgr0)
}


function vssh(){
  # inspired from https://github.com/filex/vagrant-ssh
  local vm=${1##*_}
  local port=$(VBoxManage showvminfo $1 |grep 'name = ssh' |sed -e 's/^.*host port = //' -e 's/,.*//')
  shift 1

  ssh -o Compression=yes -o DSAAuthentication=yes -o LogLevel=FATAL \
       -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
       -o IdentitiesOnly=yes -i $DIR/.vagrant/machines/$vm/virtualbox/private_key \
       $USER@127.0.0.1 -p $port $@
}

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
USER="$(cat $DIR/username)"

title "Running VMs\n"
read -a vms <<< $(VBoxManage list runningvms | grep -E "jinn_" | awk -v ORS=" " -F "[\"|\"]" '{print $2}')

if [ ${#vms[@]} -lt 1 ]; then
  fail "No runing VMs\n"
  exit
fi
count=0
for vm in "${vms[@]}"; do
  if [[ $count -lt 1 ]]; then
    printf '%s:%s:%s:%s:%s\n' "VM Name" Interface IP "SSH port" Netmask 
  fi
  interface=$(VBoxManage showvminfo ${vm} --machinereadable | grep hostonlyadapter2 | awk -F"=" '{gsub(/\"/, "", $2);print $2}')
  ip=$(VBoxManage guestproperty get $vm /VirtualBox/GuestInfo/Net/1/V4/IP | awk -F":" '{gsub(/ /, "", $2);print $2}')
  netmask=$(VBoxManage guestproperty get $vm /VirtualBox/GuestInfo/Net/1/V4/Netmask | awk -F":" '{gsub(/ /, "", $2);print $2}')
  port=$(VBoxManage showvminfo $vm |grep 'name = ssh' |sed -e 's/^.*host port = //' -e 's/,.*//')
  printf '%s:%s:%s:%s:%s\n' $vm $interface $ip $port $netmask 
  (( count ++ ))
done | column -s ':' -t

vm=${vms[0]}

ip=$(VBoxManage guestproperty get ${vm} /VirtualBox/GuestInfo/Net/1/V4/IP | awk -F":" '{gsub(/ /, "", $2);print $2}')
interface=$(VBoxManage showvminfo ${vm}  --machinereadable | grep hostonlyadapter2 | awk -F"=" '{gsub(/\"/, "", $2);print $2}')

title "\nChecking local route to %s\n" $ip

gtw=$(route get $ip | grep interface | awk -F':' '{gsub(/ /, "", $2);print $2}')
if [[ $gtw != $interface ]]; then
  fail "Wrong route to VMs: %s != %s \n" $gtw $interface
else
  pass "Found route %s \n" $gtw
fi

title "\n\nIP Hostnames \n"

hosts=$(vssh ${vm}  'cat /etc/hosts | grep jinn')
(while IFS= read -r line; do
  echo $line
done <<< "$hosts")

title "\n\nChecking OSPF routes (dynamic routes)\n"
zkhosts=()
mesos=()
aurora=()

routes=$(vssh ${vm}  'sudo vtysh -c "show ip route ospf"'  | grep "O>\*" | awk '{print $2}')
while IFS= read -r line; do
  IFS='/' read ip suffix <<< "${line}"
  IFS=. read -r i1 i2 i3 i4 <<< "$ip"

  if [[ "$i3" -eq "255" ]]; then
    if [[ $ip == 192.168.255.* ]]; then
      zkhosts+=($ip)
    fi

    if [[ "$i4" -lt "20" ]]; then
      mesos+=($ip)
    fi

    if [[ "$i4" -lt "30" ]] && [[ "$i4" -gt "20" ]]; then
      aurora+=($ip)
    fi
  fi
  printf "%s/%s\n" $ip $suffix
done <<< "$routes"

title "\n\nChecking Ceph \n"
(
  health=$(vssh ${vm} 'sudo timeout 5 ceph health')
  if [[ $health =~ "HEALTH_OK" || $health =~ "HEALTH_WARN" ]]; then
    pass "%s\n" "$health"
  else
    fail "%s\n" "$health"
  fi
)

title "\nChecking Monitors\n"
(
  vssh ${vm} 'sudo ceph mon stat' | tee
)

title "\nChecking Zookeeper \n"
(
  count=0
  for ip in "${zkhosts[@]-}"; do 
    # bash doesn't recognize empty arrays
    if [[ -n $ip ]]; then
      mode=$(vssh ${vm} "echo stat | nc $ip 2181 | grep Mode")
      mode=${mode##*: }
      if [[ "${mode}" == "standalone" || "${mode}" == "leader" ]]; then
        (( count ++ ))
      fi
      printf "%s: %s\n" $ip ${mode}
    fi
  done 
  if [ "$count" -lt "1" ]; then
    fail "No leader elected\n"
  else
    pass "leader elected\n"
  fi
)


title "\nChecking Mesos \n"
(
  count=0
  for ip in "${mesos[@]-}"; do 
    # bash doesn't recognize empty arrays
    if [[ -n $ip ]]; then
      mode=$(curl -s http://$ip:5050/metrics/snapshot | grep -oh "elected\"\:1.0")
      mode=${mode##*:}
      if [ -n "$mode" ] && [ "${mode%.*}" -gt "0" ]; then
        printf "%s: %s\n" $ip Leader
        (( count ++ ))
      else
        printf "%s: %s\n" $ip "Not Leader"
      fi
    fi
  done 
  if [ "$count" -lt "1" ]; then
    fail "No leader elected\n"
  else
    pass "leader elected\n"
  fi

)

title "\nChecking Aurora \n"
(
  count=0
  for ip in "${aurora[@]-}"; do 
    # bash doesn't recognize empty arrays
    if [[ -n $ip ]]; then
      mode=$(curl -s http://$ip:8081/vars | grep framework_registered)
    fi
    if [ -n "$mode" ] && [ "${mode#* }" -gt "0" ]; then
      printf "%s: %s\n" $ip Leader
      (( count ++ ))
    else
      printf "%s: %s\n" $ip "Not Leader"
    fi
  done 
  if [ "$count" -lt "1" ]; then
    fail "No leader elected\n"
  else
    pass "leader elected\n"
  fi
)
printf "\n"

