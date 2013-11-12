require 'net/ssh'
require_relative "householder/version"
require_relative "householder/vbox"

module Householder
  def self.run(raw_argv)
    box_url, _, remote_host, _, user, _, fqdn, _, ip_address, _, public_key_path = raw_argv
    appliance_filename = File.basename(box_url)

    host = Householder::Manager::Host.new(user, host)
    Net::SSH.start(@host, @user, password: host.pass ) do |ssh|
      host.ssh = ssh

      puts "\nImporting VM...\n\n"
      host.net_ssh_exec!("VBoxManage import #{filename}")
      vms = net_ssh_exec!('VBoxManage list vms').split("\n")
      vm_name = /\"(.*)\"/.match(vms)[1]
      puts "\nDone importing VM.\n\n"

      puts "Modifying VM configuration:"

      # Get VM Info
      vm_info_raw = net_ssh_exec!(%Q(VBoxManage showvminfo "#{@vm_name}")).split("\n")
      vm_info = {}
      vm_info_raw.each do |l|
        key, value = l.split(':', 2).map(&:strip)
        vm_info[key] = value unless value.nil?
      end
      vm_info

      vm_info.each do |key, value|
        # Remove existing port forwarding rules on Network Adapter 1
        if /NIC 1 Rule\(\d\)/.match(key)
          rule_name = /^name = (.+?),/.match(value)
          net_ssh_exec('VBoxManage modifyvm "#{vm_name}" --natpf1 delete "#{rule_name[1]}"') if !rule_name.nil? && rule_name.size > 1

        # Remove network adapters 3 & 4 to avoid conflict with NAT and Bridged Adapter
        elsif other_adapters = /^NIC (3|4)$/.match(key) && value != 'disabled'
          net_ssh_exec('VBoxManage modifyvm "#{vm_name}" --nic#{other_adapters[1]} none')
        end
      end
    end

    puts "Creating NAT on Network Adapter 1 and adding port forwarding..."
    host_port = 2222
    guest_port = 22
    net_ssh_exec('VBoxManage modifyvm "#{vm_name}" --nic1 nat --cableconnected1 on --natpf1 "guestssh,tcp,,#{host_port},,#{guest_port}"')

    puts "Creating Bridged Adapter on Network Adapter 2..."
    bridge_adapter_type = 'en1: Wi-Fi (AirPort)'
    net_ssh_exec('VBoxManage modifyvm "#{vm_name}" --nic2 bridged --bridgeadapter2 #{bridge_adapter_type}')

    puts "\nDone modifying VM.\n\n"
  end
end