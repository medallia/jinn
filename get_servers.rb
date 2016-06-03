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