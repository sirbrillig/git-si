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

      def self.are_there_changes?(status_output)
        status_output.match(/^\s*[MAD]/)
      end

      def self.commit_revision_command(revision)
        "#{@@git_binary} commit --allow-empty -am 'svn update to version #{revision}'"
      end

      def self.stash_command
        "#{@@git_binary} stash"
      end

      def self.unstash_command
        "#{@@git_binary} stash pop"
      end

      def self.rebase_command(branch)
        raise GitSiError.new("Rebase command requires branch name") if branch.empty?
        "#{@@git_binary} rebase '#{branch}'"
      end

      def self.branch_command
        "#{@@git_binary} branch"
      end

      def self.parse_current_branch(git_branches)
        results = git_branches.match(/^\*\s+(\S+)/)
        return results[1] if results
      end
    end
  end
end


