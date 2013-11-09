require_relative "householder/version"
require_relative "householder/vbox"

module Householder
  def self.run(raw_argv)
    box_url, _, remote_host, _, user, _, fqdn, _, ip_address, _, public_key_path = raw_argv
    appliance_filename = File.basename(box_url)

    puts "\nImporting VM...\n\n"
    vm_name = Householder::Vbox.import(appliance_filename)
    vm      = Householder::Vbox.new(vm_name)

    puts "\nDone importing VM.\n\n"

    puts "Modifying VM configuration:"
    vm.remove_existing_network_adapters

    puts "Creating NAT on Network Adapter 1 and adding port forwarding..."
    vm.create_nat_with_port_forwarding(1, 2222, 22)

    puts "Creating Bridged Adapter on Network Adapter 2..."
    vm.create_bridge_adapter(2, 'eth0')

    puts "\nDone modifying VM.\n\n"
  end
end