# -*- mode: ruby -*-
# vi: set ft=ruby :
# Copyright 2016 Medallia Inc. All rights reserved
# Use of this source code is governed by the Apache 2.0
# license that can be found in the LICENSE file.

require 'yaml'
require 'ipaddr'


def get_servers(name, role, fd)
  constraints = role['constraints']
  count = constraints['count']
  if count == nil
    raise Vagrant::Errors::VagrantError.new,"Incompatible constraints: #{name}: Missing count"
  end
  limit = constraints['limit']
  fd_choice = constraints['fd']
  if fd_choice != nil && (count > 1 && limit == 1)
    raise Vagrant::Errors::VagrantError.new,"Incompatible constraints: #{name}: fault domain specified with count(#{count}) >1 and limit = #{limit}"
  end
  if fd_choice != nil && fd[fd_choice] == nil
    raise Vagrant::Errors::VagrantError.new,"Incompatible constraints: #{name}: #{fd_choice} is unknown"
  end
  ru = constraints['unit']
  if !ru.to_i.between?(1, 48)
    raise Vagrant::Errors::VagrantError.new,"Incompatible constraints: #{name}: unit(#{ru}) not between 1 and 48"
  end
  if ru != nil && (count.to_f / fd.size) > 1
    raise Vagrant::Errors::VagrantError.new,"Incompatible constraints: #{name}: unit specified with count(#{count}) > nb fault domains(#{fd.size})"
  end

  fd_map = Hash.new
  server_ips = Array.new

  (1..count).each do |i|
    # go over all the slots
    fd.each do |f|

      subnet = IPAddr.new(f['subnet'])

      if fd_map[f['id']] == nil
        fd_map[f['id']] = Array.new
      end
      # is there a fd choice
      if fd_choice != nil && fd_choice != f['id']
        next
      end

      # is the limit for that fd reached
      if limit != nil && (fd_map[f['id']].size >= limit)
        next
      end

      # if there is a ru choice
      if ru != nil 
        # calculate IP based on RU based numbering
        ip = subnet | (ru.to_i*4)+2
        if fd_map[f['id']].include?(ip.to_s)
          next
        end
      else
        tries=0
        begin
          ip = subnet.to_range.to_a[1..-1].sample()
          tries = tries+1
        end while (fd_map[f['id']].include?(ip.to_s) || tries < 5)
        if tries == 5 
          raise Vagrant::Errors::VagrantError.new,"Cannot allocate IP: #{name}: too many tries"
        end
      end

      if ip != nil
        fd_map[f['id']] << ip.to_s
        server_ips << ip.to_s
        break
      end
    end
  end
  if server_ips.size == 0
    raise Vagrant::Errors::VagrantError.new,"Cannot allocate IP: #{name}: Could not satisfy constraints"
  end
  return server_ips
end

unless Vagrant.has_plugin?("vagrant-reload")
  raise 'vagrant-reload is not installed!'
end

jinn = YAML.load_file('jinn.yml')

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

VAGRANT_ROOT = File.dirname(File.expand_path(__FILE__))

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
  File.open('username', 'w') { |file| file.write(cluster.ssh.password) }

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
        box.vm.provider :virtualbox do |vb|
          vb.memory = resources['memory']
          vb.cpus = resources['cpu']
          vb.name = "jinn_"+name+index
          unless disks.nil?
            disks.each do |x, size|
              if ! File.exist?("disk-#{name}#{index}-#{x}.vdi")
                vb.customize [ "createhd", "--filename", "disk-#{name}#{index}-#{x}.vdi", "--size", 1024*size ]
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