# TODO: Initial script for importing a vbox vm. Need to refactor.

appliance_filename  = 'Ubuntuserver1204-Test.ova'

puts "\nImporting VM...\n\n"
`VBoxManage import #{appliance_filename}`
puts "\nDone importing VM.\n\n"

puts "Modifying VM configuration:"

vms             = `VBoxManage list vms`.split("\n")
vm_name         = /\"(.*)\"/.match(vms.last)[1]
vm_info_stdout  = IO.popen(%Q(VBoxManage showvminfo "#{vm_name}"))

vm_info_stdout.readlines.each do |l|
  key, value = l.split(':', 2).map(&:strip)

  if !value.nil?

    # Remove existing port forwarding rules on Network Adapter 1
    if /NIC 1 Rule\(\d\)/.match(key)
      rule_name = /^name = (.+?),/.match(value)
      `VBoxManage modifyvm "#{vm_name}" --natpf1 delete "#{rule_name[1]}"` if !rule_name.nil? && rule_name.size > 1

    # Remove network adapters 3 & 4 to avoid conflict with NAT and Bridged Adapter
    elsif other_adapters = /^NIC (3|4)$/.match(key) && value != 'disabled'
      `VBoxManage modifyvm "#{vm_name}" --nic#{other_adapters[1]}`
    end
  end
end
vm_info_stdout.close

puts "Creating NAT on Network Adapter 1 and adding port forwarding..."
`VBoxManage modifyvm "#{vm_name}" --nic1 nat --cableconnected1 on --natpf1 "guestssh,tcp,,2222,,22"`

puts "Creating Bridged Adapter on Network Adapter 2..."
`VBoxManage modifyvm "#{vm_name}" --nic2 bridged --bridgeadapter1 eth0`

puts "\nDone modifying VM.\n\n"