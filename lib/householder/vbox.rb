module Householder
  class Vbox
    attr_reader :vm_name, :downloaded_appliance_filename

    def initialize(ssh, pass=nil)
      @ssh = ssh
      @pass = pass
    end

    def download(box_url)
      appliance_filename              = File.basename(box_url)
      appliance_file_ext              = File.extname(appliance_filename)
      appliance_name                  = File.basename(appliance_filename, appliance_file_ext)
      @downloaded_appliance_filename  = "#{appliance_name}_#{Time.now.to_i}.#{appliance_file_ext}"

      @ssh.exec!("curl -o #{@downloaded_appliance_filename} #{box_url}")
    end

    def import(appliance_name = nil)
      result = @ssh.exec!("VBoxManage import --options keepallmacs #{appliance_name || @downloaded_appliance_filename}")
      @vm_name = all_vms.last
      result
    end

    def all_vms
      vms_raw = @ssh.exec!('VBoxManage list vms')
      vms_raw.split("\n").map { |v| /\"(.*)\"/.match(v)[1] }
    end

    def remove_existing_network_adapters
      @vm_info.each do |key, value|
        # Remove existing port forwarding rules on Network Adapter 1
        if /NIC 1 Rule\(\d\)/.match(key)
          rule_name = /^name = (.+?),/.match(value)
          puts @ssh.exec!(%Q(VBoxManage modifyvm "#{@vm_name}" --natpf1 delete "#{rule_name[1]}")) if !rule_name.nil? && rule_name.size > 1

        # Remove network adapters 3 & 4 to avoid conflict with NAT and Bridged Adapter
        elsif other_adapters = /^NIC (3|4)$/.match(key) && value != 'disabled'
          puts @ssh.exec!(%Q(VBoxManage modifyvm "#{@vm_name}" --nic#{other_adapters[1]} none))
        end
      end
    end

    def create_nat_adapter(n, remote_host_port, guest_port)
      @ssh.exec!(%Q(VBoxManage modifyvm "#{@vm_name}" --nic#{n} nat --cableconnected#{n} on --natpf#{n} "guestssh,tcp,,#{remote_host_port},,#{guest_port}"))
    end

    def create_bridge_network_adapter(n, bridge_adapter_type)
      @ssh.exec!(%Q(VBoxManage modifyvm "#{@vm_name}" --nic#{n} bridged --cableconnected1 on --bridgeadapter#{n} "#{bridge_adapter_type}"))
    end

    def start_vm(is_headless = true)
      cmd = %Q(VBoxManage startvm "#{@vm_name}") << (is_headless ? " --type headless" : '')
      @ssh.exec!(cmd)
    end

    def remove_vm
      @ssh.exec!(%Q(VBoxManage unregistervm #{@vm_name} --delete))
    end

    def send_acpi_shutdown_to_vm
      @ssh.exec!(%Q(VBoxManage controlvm "#{@vm_name}" acpipowerbutton))
    end

    def get_vm_info
      return @vm_info unless @vm_info.nil?

      vm_info_raw = @ssh.exec!(%Q(VBoxManage showvminfo "#{@vm_name}")).split("\n")

      @vm_info = vm_info_raw.inject({}) do |memo, obj|
        key, value = obj.split(':', 2).map(&:strip)
        memo[key] = value unless value.nil?
        memo
      end
    end

    def install_bridge_utils
      ch_exec(%Q(sudo apt-get install uml-utilities bridge-utils),
              "Done installing uml-utilties and bridge-utils.")
    end

    def backup_network_interfaces_config
      ch_exec(%Q(sudo cp /etc/network/interfaces /etc/network/interfaces-orig-backup),
              "Done creating backup for network interfaces config file.")
    end

    def config_network_interfaces(static_address, static_network)
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

      ch_exec(%Q(string="#{interfaces}" && printf "%b\n" "$string" | sudo tee /etc/network/interfaces),
              "Done modifying VM's network interfaces.")
    end

    def config_fqdn(fqdn)
      hostname = @ssh.exec!('hostname')
      ch_exec(%Q(echo "127.0.0.1  #{fqdn}  hostname" | sudo tee -a /etc/hosts ),
              "FQDN added.")
    end

    def add_to_authorized_keys(pub_key)
      @ssh.exec!('[ ! -f ~/.ssh/authorized_keys ] && touch ~/.ssh/authorized_keys')
      @ssh.exec!(%Q(echo "#{pub_key}" >> ~/.ssh/authorized_keys))
    end

    def remove_downloaded_appliance
      @ssh.exec!("rm -f #{downloaded_appliance_filename}")
    end


    private

    def ch_exec(cmd, on_close_message = nil)
      @ssh.open_channel do |channel|
        channel.request_pty do |channel , success|
          raise "I can't get pty rquest" unless success

          channel.exec(cmd)

          channel.on_data do |ch , data|
            if data.inspect.include?("[sudo]")
              channel.send_data("#{@pass}\n")
              sleep 0.1
            end
          end

          channel.on_close { |ch| puts on_close_message unless on_close_message.nil? }
        end
      end
    end

  end
end