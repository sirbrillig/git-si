module Git
  module Si
    class Svn
      @@default_svn_binary = 'svn'
      @@svn_binary = 'svn'

      def self.svn_binary=(binary)
        @@svn_binary = binary && binary.length > 0 ? binary : @@default_svn_binary
      end

      def self.status_command(*args)
        command = "#{@@svn_binary} status --ignore-externals"
        if ( args.length > 0 )
          command += " " + args.join(' ')
        end
        command
      end

      def self.info_command
        "#{@@svn_binary} info"
      end

    end
  end
end

