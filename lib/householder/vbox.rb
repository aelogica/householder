module Householder
  class Vbox
    attr_reader :vm_name

    def initialize(vm_name)
      @vm_name = vm_name
    end

    def self.import(filename)
      `VBoxManage import #{filename}`
      Vbox.get_last_created
    end

    def self.get_vms
      `VBoxManage list vms`.split("\n")
    end

    def self.get_last_created
      /\"(.*)\"/.match(Vbox.get_vms.last)[1]
    end

    def self.get_raw_vm_info(name)
      stdout  = IO.popen(%Q(VBoxManage showvminfo "#{name}"))
      raw     = stdout.readlines
      stdout.close
      raw
    end

    def create_bridge_adapter(n, name)
      `VBoxManage modifyvm "#{@vm_name}" --nic#{n} bridged --bridgeadapter#{n} #{name}`
    end

    def get_raw_info
      stdout  = IO.popen(%Q(VBoxManage showvminfo "#{@vm_name}"))
      raw     = stdout.readlines
      stdout.close
      raw
    end

    def get_info
      info = {}

      get_raw_info.each do |l|
        key, value = l.split(':', 2).map(&:strip)
        info[key] = value unless value.nil?
      end

      info
    end

    def create_nat_with_port_forwarding(n, host_port, guest_port)
      `VBoxManage modifyvm "#{@vm_name}" --nic#{n} nat --cableconnected1 on --natpf#{n} "guestssh,tcp,,#{host_port},,#{guest_port}"`
    end

    def create_bridge_adapter(n, name)
      `VBoxManage modifyvm "#{@vm_name}" --nic#{n} bridged --bridgeadapter#{n} #{name}`
    end

    def remove_port_forwarding_rule(n, name)
      `VBoxManage modifyvm "#{@vm_name}" --natpf#{n} delete "#{name}"`
    end

    def remove_network_adapter(n)
      `VBoxManage modifyvm "#{@vm_name}" --nic#{n} none`
    end
  end
end