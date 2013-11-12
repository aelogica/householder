require 'net/ssh'
require 'highline/import'
require_relative "householder/version"

module Householder
  def self.run(raw_argv)
    box_url, _, remote_host, _, user, _, fqdn, _, ip_address, _, public_key_path = raw_argv

    appliance_filename = File.basename(box_url)

    puts "\nConnecting via SSH...\n\n"
    pass = ask("#{user}@#{remote_host}'s password: ") { |q| q.echo = false }

    Net::SSH.start(remote_host, user, password: pass ) do |ssh|
      puts "Importing VM...\n\n"
      ssh.exec!("VBoxManage import #{appliance_filename}")
      vms = ssh.exec!('VBoxManage list vms')
      vm_name = /\"(.*)\"/.match(vms.split("\n").last)[1]
      puts "Done importing VM.\n\n"

      puts "Modifying VM configuration:"

      # Get VM Info
      vm_info_raw = ssh.exec!(%Q(VBoxManage showvminfo "#{@vm_name}")).split("\n")
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
          puts ssh.exec!(%Q(VBoxManage modifyvm "#{vm_name}" --natpf1 delete "#{rule_name[1]}")) if !rule_name.nil? && rule_name.size > 1

        # Remove network adapters 3 & 4 to avoid conflict with NAT and Bridged Adapter
        elsif other_adapters = /^NIC (3|4)$/.match(key) && value != 'disabled'
          puts ssh.exec!(%Q(VBoxManage modifyvm "#{vm_name}" --nic#{other_adapters[1]} none))
        end
      end

      puts "Creating NAT on Network Adapter 1 and adding port forwarding..."
      host_port = 2222
      guest_port = 22
      ssh.exec!(%Q(VBoxManage modifyvm "#{vm_name}" --nic1 nat --cableconnected1 on --natpf1 "guestssh,tcp,,#{host_port},,#{guest_port}"))

      puts "Creating Bridged Adapter on Network Adapter 2..."
      bridge_adapter_type = 'en1: Wi-Fi (AirPort)'
      ssh.exec!(%Q(VBoxManage modifyvm "#{vm_name}" --nic2 bridged --bridgeadapter2 "#{bridge_adapter_type}"))

      puts "\nDone modifying VM.\n\n"
    end
  end
end