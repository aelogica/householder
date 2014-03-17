householder
===========

Give your VirtualBox a home.

householder allows you to spin up VirtualBox VMs with fixed IP addresses on a remote Mac.

"House a box under a remote Mac user accessible through an IP address."

Quickstart
==========

1. `gem install householder`
2. `house <box-url> <remote-user> <remote-host> <box-ip> <guest-username> <guest-password>`

Setup Password-less SSH
=======================

Copy your public key to your remote Mac using [ssh-forever](https://github.com/mattwynne/ssh-forever). To test:

    ssh-forever <remote-user>@<remote-host>
    ssh <remote-host> "echo 'Hello there from: `hostname`'"

Setup Testing Environment
=========================

Run a web server (e.g. nginx) on your local machine to serve the box file through a URL.

Copy the box file to `<path_to_your_homebrew>/var/www`.

Create and fill-in a `.env` file in the project's root directory (see [.env.sample](https://github.com/aelogica/householder/blob/master/.env.sample)).

Run the Test Suite
==================

    rake

Contributing
============

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
