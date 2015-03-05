module Git
  module Si
    class Svn
      @@svn_binary = 'svn'

      def self.svn_binary=(binary)
        @@svn_binary = binary
      end

      def self.status_command(*args)
        command = "#{@@svn_binary} status --ignore-externals"
        if ( args.length > 0 )
          command += " " + args.join(' ')
        end
        command
      end
    end

  end
end
