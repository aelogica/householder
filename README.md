# Householder

This gem helps you take a Vagrant "box" style virtual machine base and deploy it to a host server with a fixed IP address.

## Installation

We recommend you install it yourself as:

    $ gem install householder

## Prerequesites

You must have:

  * A remote Mac OS X host with VirtualBox installed
  * ssh-access to an account on said host with the ability to run VirtualBox
  * An ssh keypair whose public key will be installed for root on the new server

## Usage

To create a box instance with a public-IP or fixed-IP address:

    $ house <box-url> on <remote-host> under <user> as <fully-qualified-domain-name> for <path-to-my-public-key>

Where the FQDN must resolve to the IP you want the host to use.  If your DNS is not set up yet, add the IP like so:

    $ house <box-url> on <remote-host> under <user> as <fully-qualified-domain-name> with <ip-address> for <path-to-my-public-key>

These commands will cause the following to happen:

1. download the box file to remote-host
2. create a virtual machine on the remote host.
3. modify the ovf definition in the box file, setting interface 0 to have a p.rtmapped SSH where the port number is 2200 + the last octet of the IPv4 address.
4. Install a plist file: /Library/LaunchDaemons/<reverse-fqdn>.<hostname>V.rtualbox.plist which will cause the vm to start automatically on boot running u.der the <user>.
5. Start the virtual machine via launchctl
6. Set the IP address and hostname and reboot the virtual machine
7. Run any bootstrap_server.sh or bootstrap.sh script within the newly homesteaded VM. (if the latter, it will substitute references to "vagrant" with "deploy")
8. Reboot the VM again and wait for it to come up.

Your boostrap_server.sh script should prepare the server with everything necessary to perform a cap deploy:cold if you are using Capistrano for deployment.



## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
