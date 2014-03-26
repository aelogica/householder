require 'optparse'
require 'net/ssh'

VBOX_HOST_PORT = "22"
VBOX_GUEST_PORT = "22"
VBOX_GUEST_TUNNEL_PORT = "7222"

module Householder
  module CLI
    def self.help
      opts = OptionParser.new do |o|
        o.banner = "Usage: house [-h] <box-url> <box-name> <remote-user> <remote-host> <box-ip> <guest-user> <guest-password> <bridge-interface>"
        o.separator ""
        o.on("-h", "--help", "Print this help.")
        o.separator ""
      end
      puts opts.help
    end

    def self.house(box_url, box_name, remote_user, remote_host, box_ip, guest_user, guest_password, bridge_interface)
      puts "House #{box_url} as #{box_name} under #{remote_user} at #{remote_host} accessible through #{box_ip}"

      # Connects to the remote host that runs VirtualBox
      Net::SSH.start(remote_host, remote_user) do |host_session|
        house_cache_dir = create_house_cache(remote_user, host_session)

        box_dir = download(host_session, house_cache_dir, box_url)

        import(host_session, box_dir, box_name)

        create_bridge_adapter(host_session, box_name, bridge_interface)
        start_vm(host_session, box_name)

        # Connects to the guest VM running on the remote host
        Net::SSH.start(remote_host, guest_user,
                       password: guest_password,
                       port: VBOX_GUEST_TUNNEL_PORT) do |guest_session|
          install_bridge_utils(guest_session)
          setup_guest_network_interface(guest_session, box_ip)
          guest_session.loop
        end

        shutdown_vm(host_session, box_name)
        sleep 10

        start_vm(host_session, box_name)
        sleep 10
        puts "Your VirtualBox '#{box_name}' has been given a home `ssh #{guest_user}@#{box_ip}`."

        host_session.loop
      end

    end

    private

    def self.create_house_cache(remote_user, session)
      dir = "/Users/#{remote_user}/.house"
      session.exec! "mkdir -p #{dir}"
      dir
    end

    def self.download(session, house_cache_dir, box_url)
      puts "Downloading #{box_url}"
      full_box_filename = box_url.rpartition("/").last
      box_filename = full_box_filename.rpartition(".").first
      box_dir = "#{house_cache_dir}/#{box_filename}"
      session.exec! "mkdir -p #{box_dir}"
      session.exec! "curl -o #{box_dir}/#{full_box_filename} #{box_url}"
      session.exec! "cd #{box_dir} && tar xvf #{full_box_filename} && rm #{full_box_filename}"
      box_dir
    end

    def self.import(session, box_dir, box_name)
      appliance_name = "#{box_dir}/box.ovf"
      puts "Importing #{appliance_name}"
      session.exec! %Q(VBoxManage import #{appliance_name} --vsys 0 --vmname #{box_name})
    end

    def self.create_bridge_adapter(session, box_name, bridge_interface)
      puts "Creating bridge adapter for #{box_name}"
      cmd = %Q(VBoxManage modifyvm #{box_name} --nic2 bridged --cableconnected1 on --bridgeadapter2 #{bridge_interface})
      session.exec! cmd
    end

    def self.start_vm(session, box_name)
      puts "Starting #{box_name}"
      cmd = %Q(VBoxManage startvm #{box_name} --type headless)
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

    def self.shutdown_vm(session, box_name)
      puts "Shutting down #{box_name}"
      cmd = %Q(VBoxManage controlvm #{box_name} poweroff)
      session.exec! cmd
    end

  end
end
