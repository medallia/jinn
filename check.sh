#! /bin/bash
# Copyright 2016 Medallia Inc. All rights reserved
# Use of this source code is governed by the Apache 2.0
# license that can be found in the LICENSE file.
function vssh(){
	local vm=${1##*_}
	local port=$(VBoxManage showvminfo $1 |grep 'name = ssh' |sed -e 's/^.*host port = //' -e 's/,.*//')
	shift 1

	exec ssh -o Compression=yes -o DSAAuthentication=yes -o LogLevel=FATAL \
			 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
			 -o IdentitiesOnly=yes -i $DIR/.vagrant/machines/$vm/virtualbox/private_key \
			 $USER@127.0.0.1 -p $port $@
}

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
USER=$(cat $DIR/username)

echo "Running VMs"
vms=$(VBoxManage list runningvms | grep -E "jinn_" | awk -F'[\"|\"]' '{print $2}')
first_vm=""
while IFS= read -r line; do
	if [[ -z $first_vm ]]; then
		first_vm=$line
	fi
	interface=$(VBoxManage showvminfo ${line} --machinereadable | grep hostonlyadapter2 | awk -F"=" '{gsub(/\"/, "", $2);print $2}')
	ip=$(VBoxManage guestproperty get $line /VirtualBox/GuestInfo/Net/1/V4/IP | awk -F":" '{gsub(/ /, "", $2);print $2}')
	netmask=$(VBoxManage guestproperty get $line /VirtualBox/GuestInfo/Net/1/V4/Netmask | awk -F":" '{gsub(/ /, "", $2);print $2}')
	port=$(VBoxManage showvminfo $line |grep 'name = ssh' |sed -e 's/^.*host port = //' -e 's/,.*//')
	printf '%s:%s:%s:%s/%s\n' $line $interface $ip $port $netmask
done <<< "$vms"


printf "\nChecking local route to %s\n" $ip
gtw=$(sudo route get $ip | grep interface | awk -F':' '{gsub(/ /, "", $2);print $2}')
if [[ $gtw != $interface ]]; then
	printf "Wrong route to VMs: %s != %s" $gtw $interface
else
	printf "Found route %s" $gtw
fi

printf "\n\nChecking OSPF routes (dynamic routes)\n"
zkhosts=()
mesos=()
aurora=()

routes=$(vssh $first_vm 'sudo vtysh -c "show ip route ospf"'  | grep "O>\*" | awk '{print $2}')
while IFS= read -r line; do
	IFS='/' read ip suffix <<< "${line}"
	if [[ $ip == 192.* ]]; then
		zkhosts+=($ip)
	fi
	IFS=. read -r i1 i2 i3 i4 <<< "$ip"

	if [ "$i4" -lt "20" ]; then
		mesos+=($ip)
	fi

	if [ "$i4" -lt "30" ] && [ "$i4" -gt "20" ]; then
		aurora+=($ip)
	fi
	printf "%s/%s\n" $ip $suffix
done <<< "$routes"

printf "\n\nChecking Ceph \n"
(
	vssh $first_vm 'sudo ceph health' | tee
)
printf "\nChecking Monitors\n"
(
	vssh $first_vm 'sudo ceph mon stat' | tee
)
printf "\nChecking Zookeeper \n"

(
	count=0
	for ip in "${zkhosts[@]}"; do 
		mode=$(vssh $first_vm "echo stat | nc $ip 2181 | grep Mode")
		mode=${mode##*: }
		if [[ "${mode}" == "standalone" || "${mode}" == "Leader" ]]; then
			(( count ++ ))
		fi
		printf "%s: %s\n" $ip ${mode}
	done 
	if [ "$count" -lt "1" ]; then
		echo "No leader elected"
	else
		echo "leader elected"
	fi
)


printf "\nChecking Mesos \n"
(
	for ip in "${mesos[@]}"; do 
		mode=$(curl -s http://$ip:5050/metrics/snapshot | grep -oh "elected\"\:1.0")
		mode=${mode##*:}
		if [ "${mode%.*}" -gt "0" ]; then
			status=OK
		else
			status=NOK
		fi
		printf "%s: %s\n" $ip ${status}
	done 
)

printf "\nChecking Aurora \n"
(
	for ip in "${aurora[@]}"; do 
		mode=$(curl -s http://$ip:8081/vars | grep framework_registered)
		if [ "${mode#* }" -gt "0" ]; then
			status=OK
		else
			status=NOK
		fi
		printf "%s: %s\n" $ip ${status}
	done 
)
printf "\n"

