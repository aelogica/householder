require 'dotenv'
require 'householder/cli'
require 'householder/version'

module Householder
  def self.run(argv)
    Dotenv.load

    if argv.length == 7
      box_url, remote_user, remote_host, box_ip, guest_user, guest_password, bridge = argv
      Householder::CLI.house(box_url, remote_user, remote_host, box_ip,
                             guest_user, guest_password, bridge)
    else
      puts Householder::CLI.help
    end

  end
end
