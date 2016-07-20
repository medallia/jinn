require_relative "../get_servers"
require "test/unit"
require "ipaddr"
require "yaml"

Constraints = Struct.new(:count, :limit, :fd_choice, :ru)

# provide a mock error for tests
module Vagrant
	module Errors
		class VagrantError < Exception
		end
	end
end

class TestConstraints < Test::Unit::TestCase
	def setup
		spec = "
fault_domains:
- id: 'rack10'
  subnet: 10.112.10.0/24
- id: 'rack11'
  subnet: 10.112.11.0/24
- id: 'rack12'
  subnet: 10.112.12.0/24
"
		@dc = YAML.load(spec)
		@fd = @dc['fault_domains']
	end
	def test_count
		c = Constraints.new(nil, 1, "rack10", "8" )
		assert_raise Vagrant::Errors::VagrantError do
			check_count("test", c)
		end
	end
	def test_fd_incompatible
		c = Constraints.new(2, 1, "rack10", "8" )
		assert_raise(Vagrant::Errors::VagrantError) do
			check_fd("test", c)
		end
	end

	def test_ru_count
		c = Constraints.new(4, 1, nil, "8" )
		assert_raise Vagrant::Errors::VagrantError do
			check_ru("test", c, @fd)
		end
	end
end

class TestAllocateRandom < Test::Unit::TestCase
	def test_allocate_random_success
		subnet = IPAddr.new("10.10.10.0/24")
		fd_map = Hash.new
		# No IP previously allocated
		fd_map["test"] = Array.new
		# Try to allocate
		ip = allocate_random(subnet, "test", fd_map)
		# IP Allocation should be successful
		assert_not_nil(ip, "IP not allocated")
	end
	def test_allocate_random_collision
		subnet = IPAddr.new("10.10.10.0/30")
		fd_map = Hash.new
		fd_map["test"] = Array.new
		# Add all possible IP in the subnet except 1
		fd_map["test"] << "10.10.10.0"
		fd_map["test"] << "10.10.10.1"
		fd_map["test"] << "10.10.10.2"

		# Try to allocate
		ip = allocate_random(subnet, "test", fd_map)
		# Only one possible IP
		assert_not_nil(ip, "IP Collision error")
		assert_equal(ip.to_s, "10.10.10.3", "Wrong IP")
	end
end

class TestGetServers < Test::Unit::TestCase
	def setup
		spec = "
fault_domains:
- id: 'rack10'
  subnet: 10.112.10.0/24
- id: 'rack11'
  subnet: 10.112.11.0/24
- id: 'rack12'
  subnet: 10.112.12.0/24
"
		@dc = YAML.load(spec)
	end
	def test_get_server_success_fixed
		fd = @dc['fault_domains']
		assert_equal(fd.size,3, "wrong fd size")
		fd_map = Hash.new
		c = Constraints.new(1, 1, "rack10", "8" )
		ip = get_server(fd, fd_map, c)
		assert_not_nil(ip, "IP Allocation error")
		assert_equal(ip.to_s, "10.112.10.34")
	end

	def test_get_server_success_random
		fd = @dc['fault_domains']
		assert_equal(fd.size,3, "wrong fd size")
		fd_map = Hash.new
		c = Constraints.new(1, 1, "rack10", nil)
		ip = get_server(fd, fd_map, c)
		assert_not_nil(ip, "IP Allocation error")
	end
	# if there is an error and an exception is raised, there 
	def test_get_servers_success_distributed
		fd = @dc['fault_domains']
		role = YAML.load("constraints: {'count': 3, 'limit': 1, 'unit': '8'}")
		assert_equal(fd.size, 3, "wrong fd size")
		servers = get_servers("test", role, fd)

		assert_not_nil(servers, "Server allocation error")
		assert_equal(servers.size, 3, "Distribution error")
	end

end