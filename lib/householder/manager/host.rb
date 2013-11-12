module Householder
  module Manager
    class Host
      attr_reader :user, :host, :pass
      attr_accessor :ssh

      def initialize(user, host)
        @host = host
        @user = user

        puts "\nConnecting via SSH...\n"
        print "#{@user}@#{@host}'s password: "
        @pass = STDIN.noecho(&:gets).chomp
        puts "\n"
      end

      def net_ssh_exec!
        lambda do |cmd|
          stdout = ''
          @ssh.exec!(cmd) { |ch, stream, data| stdout << data }
          stdout
        end
      end

      def net_ssh_exec
        lambda { |cmd| @ssh.exec(cmd) }
      end
    end
  end
end