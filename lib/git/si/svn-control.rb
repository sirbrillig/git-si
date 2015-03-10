module Git
  module Si
    class SvnControl
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

      def self.diff_command(*args)
        command = "#{@@svn_binary} diff"
        if ( args.length > 0 )
          command += " " + args.join(' ')
        end
        command
      end

      def self.parse_last_revision(svn_info)
        results = svn_info.match(/^Revision:\s+(\d+)/)
        return results[1] if results
        return nil
      end

      def self.add_command(*files)
        raise GitSiError.new("Add command requires filenames") if ( files.length == 0 )
        "#{@@svn_binary} add " + files.join(' ')
      end

    end
  end
end

