require 'dotenv'
require 'householder/cli'
require 'householder/version'

module Householder
  def self.run(argv)
    Dotenv.load

    if argv.length == 4
      box_url, remote_user, remote_host, box_ip = argv
      Householder::CLI.house(box_url, remote_user, remote_host, box_ip)
    else
      puts Householder::CLI.help
    end

  end
end
