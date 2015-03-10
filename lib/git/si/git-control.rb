module Git
  module Si
    class GitControl
      @@default_git_binary = 'git'
      @@git_binary = 'git'

      def self.git_binary=(binary)
        @@git_binary = binary && binary.length > 0 ? binary : @@default_git_binary
      end

      def self.status_command(*args)
        command = "#{@@git_binary} status --porcelain"
        if ( args.length > 0 )
          command += " " + args.join(' ')
        end
        command
      end

      def self.log_command(*args)
        command = "#{@@git_binary} log"
        if ( args.length > 0 )
          command += " " + args.join(' ')
        end
        command
      end

      def self.parse_last_svn_revision(info)
        results = info.match(/svn update to version (\d+)/i)
        return results[1] if results
      end

      def self.add_command(*files)
        raise GitSiError.new("Add command requires filenames") if ( files.length == 0 )
        "#{@@git_binary} add " + files.join(' ')
      end

    end
  end
end


