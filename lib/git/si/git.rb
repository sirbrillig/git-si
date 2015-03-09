module Git
  module Si
    class GitControl
      @@default_git_binary = 'git'
      @@git_binary = 'git'

      def self.git_binary=(binary)
        @@git_binary = binary && binary.length > 0 ? binary : @@default_git_binary
      end

      def self.log_command(*args)
        command = "#{@@git_binary} log"
        if ( args.length > 0 )
          command += " " + args.join(' ')
        end
        command
      end

    end
  end
end


