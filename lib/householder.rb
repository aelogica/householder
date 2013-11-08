require "householder/version"
require "householder/vbox"

module Householder
  def self.import(appliance_filename)
    puts "\nImporting VM...\n\n"
    vm_name = Householder::Vbox.import(appliance_filename)
    vm      = Householder::Vbox.new(vm_name)
    puts "\nDone importing VM.\n\n"

    puts "Modifying VM configuration:"
    vm.get_info.each do |key, value|
      # Remove existing port forwarding rules on Network Adapter 1
      if /NIC 1 Rule\(\d\)/.match(key)
        rule_name = /^name = (.+?),/.match(value)
        vm.remove_port_forwarding_rule(1, rule_name[1]) if !rule_name.nil? && rule_name.size > 1

      # Remove network adapters 3 & 4 to avoid conflict with NAT and Bridged Adapter
      elsif other_adapters = /^NIC (3|4)$/.match(key) && value != 'disabled'
        remove_network_adapter(other_adapters[1])
      end
    end

    puts "Creating NAT on Network Adapter 1 and adding port forwarding..."
    create_nat_with_port_forwarding(1, 2222, 22)

    puts "Creating Bridged Adapter on Network Adapter 2..."
    create_bridge_adapter(2, 'eth0')

    puts "\nDone modifying VM.\n\n"
  end
end
