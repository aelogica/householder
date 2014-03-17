require 'optparse'
require 'net/ssh'

HOUSE_CACHE = "#{ENV['HOME']}/.house"
BRIDGE_INTERFACE = "en0"
VBOX_HOST_PORT = "22"
VBOX_GUEST_PORT = "22"
VBOX_GUEST_TUNNEL_PORT = "7222"

module Householder
  module CLI
    def self.help
      opts = OptionParser.new do |o|
        o.banner = "Usage: house [-h] <box-url> <remote-user> <remote-host> <box-ip> <guest-user> <guest-password>"
        o.separator ""
        o.on("-h", "--help", "Print this help.")
        o.separator ""
      end
      puts opts.help
    end

    def self.house(box_url, remote_user, remote_host, box_ip, guest_user, guest_password)
      puts "House #{box_url} under #{remote_user} at #{remote_host} accessible through #{box_ip}"

      # Connects to the remote host that runs VirtualBox
      Net::SSH.start(remote_host, remote_user) do |host_session|
        create_house_cache(host_session)

        box_dir = download(host_session, box_url)

        vm_name = import(host_session, box_dir)

        create_bridge_adapter(host_session, vm_name)
        start_vm(host_session, vm_name)

        # Connects to the guest VM running on the remote host
        Net::SSH.start(remote_host, guest_user,
                       password: guest_password,
                       port: VBOX_GUEST_TUNNEL_PORT) do |guest_session|
          install_bridge_utils(guest_session)
          setup_guest_network_interface(guest_session, box_ip)
          guest_session.loop
        end

        shutdown_vm(host_session, vm_name)
        sleep 10

        start_vm(host_session, vm_name)
        sleep 10
        puts "Your VirtualBox '#{vm_name}' has been given a home `ssh #{guest_user}@#{box_ip}`."

        host_session.loop
      end

    end

    private

    def self.create_house_cache(session)
      session.exec! "mkdir -p #{HOUSE_CACHE}"
    end

    def self.download(session, box_url)
      puts "Downloading from #{box_url}"
      box_filename = box_url.rpartition("/").last
      box_dir = "#{HOUSE_CACHE}/#{box_filename.rpartition(".").first}"
      box_filepath = "#{box_dir}/#{box_filename}"
      session.exec! "mkdir -p #{box_dir}"
      session.exec! "curl -o #{box_filepath} #{box_url}"
      session.exec! "cd #{box_dir} && tar xvf #{box_filepath} && rm #{box_filename}"
      box_dir
    end

    def self.import(session, box_dir)
      appliance_name = "#{box_dir}/box.ovf"
      puts "Importing #{appliance_name}"
      session.exec! "VBoxManage import #{appliance_name}"
      result = session.exec! "VBoxManage list vms"
      vms = result.split("\n").map { |vm| /\"(.*)\"/.match(vm)[1] }
      box_name = vms.last
      puts "Imported as #{box_name}"
      box_name
    end

    def self.create_bridge_adapter(session, vm_name)
      puts "Creating bridge adapter for #{vm_name}"
      cmd = %Q(VBoxManage modifyvm #{vm_name} --nic2 bridged --cableconnected1 on --bridgeadapter2 en0)
      session.exec! cmd
    end

    def self.start_vm(session, vm_name)
      puts "Starting #{vm_name}"
      cmd = %Q(VBoxManage startvm #{vm_name} --type headless)
      session.exec! cmd
    end

    def self.port_forward_for(box_ip)
      last_octet = box_ip.split(".").last
      "#{VBOX_HOST_PORT}#{last_octet}"
    end

    def self.box_dir_exists?(box_dir)
      File.directory?(box_dir)
    end

    def self.channel_exec!(session, command)
      session.open_channel do |c|
        c.request_pty do |channel, success|
          raise "Householder cannot get a pseudo tty!" unless success

          channel.exec command

          channel.on_data do |ch , data|
            if data.inspect.include?("Password:")
              channel.send_data("#{VBOX_GUEST_PASSWORD}\n")
              sleep 0.1
            end
          end
        end
      end
    end

    def self.install_bridge_utils(session)
      puts "Installing bridge-utils"
      cmd = %Q(sudo apt-get install uml-utilities bridge-utils)
      channel_exec! session, cmd
    end

    def self.setup_guest_network_interface(session, box_ip)
      puts "Setting up guest network interface"
      static_address = box_ip
      static_network = box_ip.split(".")[0...3].join(".")
      cfg = <<-CONFIG

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

      cmd = %Q(string="#{cfg}" && printf "%b\n" "$string" | sudo tee /etc/network/interfaces)
      channel_exec! session, cmd
    end

    def self.shutdown_vm(session, vm_name)
      puts "Shutting down #{vm_name}"
      cmd = %Q(VBoxManage controlvm #{vm_name} poweroff)
      session.exec! cmd
    end

  end
end
