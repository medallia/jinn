require 'ipaddr'

def check_count(role_name, c)
  if c.count == nil
    raise Vagrant::Errors::VagrantError.new,"Incompatible constraints: #{role_name}: Missing count"
  end
end

def check_fd(role_name, c, fd)
  if c.fd_choice != nil && (c.count > 1 && c.limit == 1)
    raise Vagrant::Errors::VagrantError.new,"Incompatible constraints: #{role_name}: fault domain specified with count(#{c.count}) >1 and limit = #{c.limit}"
  end
  if c.fd_choice != nil && fd[c.fd_choice] == nil
    raise Vagrant::Errors::VagrantError.new,"Incompatible constraints: #{role_name}: #{c.fd_choice} is unknown"
  end
end

def check_ru(role_name, c, fd)
  if !c.ru.to_i.between?(1, 48)
    raise Vagrant::Errors::VagrantError.new,"Incompatible constraints: #{role_name}: unit(#{c.ru}) not between 1 and 48"
  end
  if c.ru != nil && (c.count.to_f / fd.size) > 1
    raise Vagrant::Errors::VagrantError.new,"Incompatible constraints: #{role_name}: unit specified with count(#{c.count}) > nb fault domains(#{fd.size})"
  end
end

def allocate_random(subnet, id, fd_map)
  ip = nil
  tries = 0
  begin
    ip = subnet.to_range.to_a[1..-1].sample()
    tries = tries+1
  end while (fd_map[id].include?(ip.to_s) || tries < 5)
  if tries == 5 
    return nil
  else
    return ip
  end
end

def get_server(fault_domains, fd_map, role_name, c)
  ip = nil
  fault_domains.each do |fd|

    subnet = IPAddr.new(fd['subnet'])
    id = fd['id']

    if fd_map[id] == nil
      fd_map[id] = Array.new
    end
    # is there a fd choice
    if c.fd_choice != nil && c.fd_choice != id
      next
    end

    # is the limit for that fd reached
    if c.limit != nil && (fd_map[id].size >= c.limit)
      next
    end

    # if there is a ru choice
    if c.ru != nil 
      # calculate IP based on RU based numbering
      ip = subnet | (c.ru.to_i*4)+2
      if fd_map[id].include?(ip.to_s)
        next
      end
    else
      ip = allocate_random(subnet, id, fd_map)
      if ip == nil
        raise Vagrant::Errors::VagrantError.new,"Cannot allocate IP: #{role_name}: too many tries"
      end
    end

    if ip != nil
      fd_map[id] << ip.to_s
      break
    end
  end
  return ip
end

def get_servers(role_name, role, fault_domains)
  role_constraints = role['constraints']

  c = Constraints.new(role_constraints['count'], role_constraints['limit'], role_constraints['fd'], role_constraints['unit'] )

  check_count(role_name, c)
  check_fd(role_name, c, fault_domains)
  check_ru(role_name, c, fault_domains)

  fd_map = Hash.new
  server_ips = Array.new

  (1..c.count).each do |i|
    # go over all the slots
    ip = get_server(fault_domains, fd_map, role_name, c)
    if ip != nil
      server_ips << ip.to_s
    end
  end
  if server_ips.size == 0
    raise Vagrant::Errors::VagrantError.new,"Cannot allocate IP: #{role_name}: Could not satisfy constraints"
  end
  return server_ips
end