require 'net/ssh'
require 'highline/import'
require_relative 'householder/vbox'
require_relative 'householder/version'


module Householder
  REMOTE_HOST_PF_IP = '127.0.0.1'

  def self.run(raw_argv)
    box_url, _, remote_host, _, user, _, fqdn, _, ip_address, _, public_key_path = raw_argv

    ip_address_arr    = ip_address.split('.')
    ip_last_octet     = ip_address_arr.last.to_i
    static_network    = ip_address_arr[0...3].join('.')
    static_address    = "#{static_network}.#{ip_last_octet}"
    remote_host_port  = 2200 + ip_last_octet


    puts ""
    puts "Connecting to #{remote_host} via SSH..."

    pass = ask("Enter password for #{user}@#{remote_host}: ") { |q| q.echo = false }

    Net::SSH.start(remote_host, user, password: pass ) do |ssh|
      remote_host_ssh_vbox = Householder::Vbox.new(ssh)

      puts "Downloading VBox Appliance..."
      puts remote_host_ssh_vbox.download(box_url)
      puts ""

      puts "Importing VBox appliance..."
      puts ""
      puts remote_host_ssh_vbox.import

      puts ""
      puts "Modifying VBox configuration:"

      puts "Creating NAT on Network Adapter 1 and adding port forwarding..."
      remote_host_ssh_vbox.create_nat_adapter(1, remote_host_port, 22)

      puts "Creating Bridged Adapter on Network Adapter 2 and adding port forwarding..."
      #  TODO: Need to detect if host is using wifi or cable  (en1 or en0)
      remote_host_ssh_vbox.create_bridge_network_adapter(2, 'en1: Wi-Fi (AirPort)')

      puts ""
      puts "Done creating your VBox (#{remote_host_ssh_vbox.vm_name})."

      puts ""
      puts "Starting VM..."
      puts remote_host_ssh_vbox.start_vm

      sleep 10

      puts ""
      puts "Connecting to VM via SSH..."

      guest_user = ask("User for guest VM: ")
      guest_pass = ask("Enter password for #{guest_user}@#{Householder::REMOTE_HOST_PF_IP}: ") { |q| q.echo = false }

      Net::SSH.start(Householder::REMOTE_HOST_PF_IP, guest_user, password: guest_pass, port: remote_host_port) do |guest_ssh|
        remote_guest_ssh_vbox = Householder::Vbox.new(guest_ssh, guest_pass)

        puts "Installing uml-utilties and bridge-utils..."
        remote_guest_ssh_vbox.install_bridge_utils
        puts ""

        puts "Creating backup for network interfaces config file..."
        remote_guest_ssh_vbox.backup_network_interfaces_config

        puts "Modifying VM's network interfaces..."
        remote_guest_ssh_vbox.config_network_interfaces(static_address, static_network)

        guest_ssh.loop
      end

      puts "Shutting down VM..."
      puts remote_host_ssh_vbox.send_acpi_shutdown_to_vm
      sleep 8

      puts "Starting VM..."
      puts remote_host_ssh_vbox.start_vm
      sleep 10

      puts ""
      puts "Done."

      ssh.loop
    end
  end
end