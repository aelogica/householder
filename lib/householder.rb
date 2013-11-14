require 'net/ssh'
require 'highline/import'
require_relative "householder/version"

module Householder
  HOST_IP = '127.0.0.1'

  def self.run(raw_argv)
    box_url, _, remote_host, _, user, _, fqdn, _, ip_address, _, public_key_path = raw_argv

    appliance_filename = File.basename(box_url)
    appliance_file_ext = File.extname(appliance_filename)
    appliance_name = File.basename(appliance_filename, appliance_file_ext)
    new_appliance_filename = "#{appliance_name}_#{Time.now.to_i}.#{appliance_file_ext}"

    puts ""
    puts "Connecting to #{remote_host} via SSH..."

    pass = ask("Enter password for #{user}@#{remote_host}: ") { |q| q.echo = false }

    Net::SSH.start(remote_host, user, password: pass ) do |ssh|
      puts "Downloading VBox Appliance..."
      puts ssh.exec!("curl -o #{new_appliance_filename} #{box_url}")
      puts ""

      puts "Importing VBox appliance..."
      puts ""
      puts ssh.exec!("VBoxManage import --options keepallmacs #{new_appliance_filename}")
      vms = ssh.exec!('VBoxManage list vms')
      vm_name = /\"(.*)\"/.match(vms.split("\n").last)[1]

      puts ""
      puts "Modifying VBox configuration:"

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
      host_port = 2233
      guest_port = 22
      puts ssh.exec!(%Q(VBoxManage modifyvm "#{vm_name}" --nic1 nat --cableconnected1 on --natpf1 "guestssh,tcp,,#{host_port},,#{guest_port}"))

      puts "Creating Bridged Adapter on Network Adapter 2 and adding port forwarding..."
      #  TODO: Need to detect if host is using wifi or cable  (en1 or en0)
      bridge_adapter_type = 'en1: Wi-Fi (AirPort)'
      puts ssh.exec!(%Q(VBoxManage modifyvm "#{vm_name}" --nic2 bridged --cableconnected1 on --bridgeadapter2 "#{bridge_adapter_type}"))

      puts ""
      puts "Done creating your VBox (#{vm_name})."

      puts ""
      puts "Starting VM..."
      puts ssh.exec!(%Q(VBoxManage startvm "#{vm_name}" --type headless))

      puts ""
      puts "Connecting to VM via SSH..."

      static_network = "10.0.1"
      static_host = "222"
      static_address = "#{static_network}.#{static_host}"
      interfaces = <<-CONFIG

# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

# The loopback network interface
auto lo
iface lo inet loopback

auto br1
iface br1 inet static
   address #{static_address}
   netmask 255.255.255.0
   network #{static_network}.0
   broadcast #{static_network}.255
   gateway #{static_network}.1
   bridge_ports eth1
   bridge_stp off
   bridge_fd 0
   bridge_maxwait 0

CONFIG

      guest_user = ask("User for guest VM: ")
      guest_pass = ask("Enter password for #{guest_user}@#{Householder::HOST_IP}: ") { |q| q.echo = false }

      sleep 10

      Net::SSH.start(Householder::HOST_IP, guest_user, password: guest_pass, port: host_port) do |guest_ssh|
        guest_ssh.open_channel do |channel|
          channel.request_pty do |channel , success|
            raise "I can't get pty rquest" unless success

            puts ""
            puts "Creating backup for network interfaces config file..."
            channel.exec('sudo cp /etc/network/interfaces /etc/network/interfaces-orig-backup')

            channel.on_data do |ch , data|
              if data.inspect.include?("[sudo]")
                channel.send_data("#{guest_pass}\n")
                sleep 0.1
              end
              ch.wait
            end
          end
        end

        guest_ssh.open_channel do |channel|
          channel.request_pty do |channel , success|
            raise "I can't get pty rquest" unless success

            puts "Modifying VM's network interfaces..."
            channel.exec(%Q(string="#{interfaces}" && printf "%b\n" "$string" | sudo tee /etc/network/interfaces))

            channel.on_data do |ch , data|
              if data.inspect.include?("[sudo]")
                channel.send_data("#{guest_pass}\n")
                sleep 0.1
              end
              ch.wait
            end
          end
        end

        guest_ssh.open_channel do |channel|
          channel.request_pty do |channel , success|
            raise "I can't get pty rquest" unless success

            puts "Installing uml-utilties and bridge-utils..."
            channel.exec(%Q(sudo apt-get install uml-utilities bridge-utils))

            channel.on_data do |ch , data|
              if data.inspect.include?("[sudo]")
                channel.send_data("#{guest_pass}\n")
                sleep 0.1
              end
              ch.wait
            end
          end
        end

        guest_ssh.open_channel do |channel|
          channel.request_pty do |channel , success|
            raise "I can't get pty rquest" unless success

            puts "Restarting VM's network..."
            channel.exec(%Q(sudo init 6))

            channel.on_data do |ch , data|
              if data.inspect.include?("[sudo]")
                channel.send_data("#{guest_pass}\n")
                sleep 0.1
              end
              ch.wait
            end
          end
        end

        guest_ssh.loop
      end
    end
  end
end