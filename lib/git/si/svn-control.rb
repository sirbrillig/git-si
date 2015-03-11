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

      def self.parse_root_path(svn_info)
        results = svn_info.match(/Root Path:\s+(.+)/)
        return results[1] if results
        return nil
      end

      def self.parse_updated_files(svn_update_output)
        svn_update_output.split(/\r?\n/).collect do |line|
          line.strip.match(Regexp.union(/^\s*[AGU]\s+(\S.+)/, /^Restored '(.+)'/, /^Resolved conflicted state of '(.+)'/)) do |pattern|
            pattern.to_a.compact.last
          end
        end.compact
      end

      def self.parse_conflicted_files(svn_update_output)
        svn_update_output.split(/\r?\n/).collect do |line|
          line.strip.match(Regexp.union(/^\s*C\s+(\S.+)/, /^Resolved conflicted state of '(.+)'/)) do |pattern|
            pattern.to_a.compact.last
          end
        end.compact
      end

      def self.parse_unknown_files(svn_update_output)
        svn_update_output.split(/\r?\n/).collect do |line|
          line.strip.match(/^\s*\?\s+(\S.+)/) do |pattern|
            pattern.to_a.compact.last
          end
        end.compact
      end

      def self.add_command(*files)
        raise GitSiError.new("Add command requires filenames") if ( files.length == 0 )
        "#{@@svn_binary} add " + files.join(' ')
      end

      def self.blame_command(*files)
        raise GitSiError.new("Blame command requires filenames") if ( files.length == 0 )
        "#{@@svn_binary} blame " + files.join(' ')
      end

      def self.update_command
        "#{@@svn_binary} up --accept theirs-full --ignore-externals"
      end

      def self.revert_command(*args)
        command = "#{@@svn_binary} revert -R"
        if ( args.length > 0 )
          command += " " + args.join(' ')
        else
          command += " ."
        end
        command
      end

      def self.commit_command(*args)
        command = "#{@@svn_binary} commit"
        if ( args.length > 0 )
          command += " " + args.join(' ')
        end
        command
      end

      def self.list_file_command
        "#{@@svn_binary} list -R"
      end

      def self.parse_file_list(list_output)
        list_output.split(/\r?\n/).collect do |filename|
          filename if filename !~ /\/$/
        end.compact
      end

    end
  end
end

