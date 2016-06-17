# -*- mode: ruby -*-
# vi: set ft=ruby :
# Copyright 2016 Medallia Inc. All rights reserved
# Use of this source code is governed by the Apache 2.0
# license that can be found in the LICENSE file.

require 'yaml'



unless Vagrant.has_plugin?("vagrant-reload")
  raise 'vagrant-reload is not installed!'
end

vagrant_root = File.dirname(__FILE__)

load(File.join(vagrant_root,'get_servers.rb'))

jinn = YAML.load_file(File.join(vagrant_root,'jinn.yml'))
cache_dir = File.join(vagrant_root, 'cached-files')
system("mkdir -p #{cache_dir}")
# maybe there is a way to get Vagrant's environment ?
venv = Vagrant::Environment.new(:ui_class => Vagrant::UI::Colored)

dc = jinn['DC']
cidr = dc['subnet'].split('/')

subnet = cidr[0]
netmask = IPAddr.new('255.255.255.255').mask(cidr[1]).to_s

fd = dc['fault_domains']

roles = jinn['roles']
roles.each do |name, params|
  roles[name]['servers'] = get_servers(name, params, fd)
  #venv.ui.info("#{name}: #{roles[name]['servers']}")
end


ENV['VAGRANT_NO_PARALLEL'] = 'yes'

QUORUM = (roles['controller']['servers'].length/2.0).ceil
CONTROLLERS = roles['controller']['servers'].join(" ")
SLAVES = roles['node']['servers'].join(" ")
CEPH_NODES = roles['ceph']['servers'].join(" ")

FSID = "07c965c8-fa90-4b17-9682-cad35a8e7bd6"

NICTYPE = "virtio"

IMAGE= jinn['OS']['image']
IMAGE_URL=jinn['OS']['image_url']

Vagrant.configure(2) do |cluster|
  cluster.ssh.shell = "bash -c 'BASH_ENV=/etc/profile exec bash'"

  cluster.ssh.guest_port =  jinn['OS']['ssh_port']
  cluster.vm.network "forwarded_port", guest: cluster.ssh.guest_port, host: 3333,  auto_correct: true, id: 'ssh'
  cluster.ssh.username = jinn['OS']['username']
  cluster.ssh.password = jinn['OS']['password']

  #saving username for further usage
  File.open(File.join(vagrant_root,'username'), 'w') { |file| file.write(cluster.ssh.username) }

  unless IMAGE_URL.nil?
      cluster.vm.box_url = IMAGE_URL
  end
  cluster.vm.box = IMAGE

  if Vagrant.has_plugin?("vagrant-cachier")
    cluster.cache.scope = :box
  end

  cluster.vm.provider "virtualbox" do |v|
    v.customize ['modifyvm', :id, '--nictype1', NICTYPE]
    v.linked_clone = true
  end

  roles.each do |name, profile|

    server_roles = profile['roles'].join(" ")
    resources = profile['resources']
    disks = resources['disks']
    servers = profile['servers']

    servers.each do |server|
      index = (servers.index(server)+1).to_s
      cluster.vm.define name+index do |box|
        box.vm.network "private_network", ip: server, netmask:netmask, nic_type: NICTYPE
        box.vm.synced_folder "cached-files", "/var/tmp/bootstrap"
        box.vm.provider :virtualbox do |vb|
          vb.memory = resources['memory']
          vb.cpus = resources['cpu']
          vb.name = "jinn_"+name+index
          unless disks.nil?
            disks.each do |x, size|
              diskfile=File.join(vagrant_root,"disk-#{name}#{index}-#{x}.vdi")
              if ! File.exist?(diskfile)
                vb.customize [ "createhd", "--filename", diskfile, "--size", 1024*size ]
              end
              vb.customize [ "storageattach", :id,
                  "--storagectl", jinn['OS']['storagectl'],
                  "--port", 3+x.to_i, 
                  "--device", 0, 
                  "--type", "hdd", 
                  "--medium", "disk-#{name}#{index}-#{x}.vdi" ]
            end
          end
        end
        box.vm.provision "shell" do |s|
          s.env = {
            "USER"        => cluster.ssh.username,
            "NET_IP"      => server,
            "CIDR"        => dc['subnet'],
            "NET_MASK"    => netmask,
            "DC_NAME"     => dc['name'],
            "QUORUM"      => QUORUM,
            "MONITORS"    => CEPH_NODES,
            "CONTROLLERS" => CONTROLLERS,
            "SLAVES"      => SLAVES,
            "FSID"        => FSID,
            "ROLES"       => server_roles}
            s.path = "scripts/bootstrap.sh"
            #s.inline = "env"
        end
        # restarting cause the re-execution of the provisioning which fail on disk creation
        if disks.nil?
          box.vm.provision :reload
        end
      end
    end
  end
end