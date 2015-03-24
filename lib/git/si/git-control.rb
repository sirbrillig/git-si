require "git/si/version"

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
        status_output.match(/^\s*[MADRC]/)
      end

      def self.commit_revision_command(revision)
        version = Git::Si::Version.version
        "#{@@git_binary} commit --allow-empty -am 'git-si #{version} svn update to version #{revision}'"
      end

      def self.commit_all_command
        version = Git::Si::Version.version
        "#{@@git_binary} commit --allow-empty -am 'git-si #{version} atuned to current svn state'"
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

      def self.checkout_command(branch)
        raise GitSiError.new("Checkout command requires branch name") if branch.empty?
        "#{@@git_binary} checkout #{branch}"
      end

      def self.create_branch_command(branch)
        raise GitSiError.new("New branch command requires branch name") if branch.empty?
        "#{@@git_binary} branch #{branch}"
      end

      def self.delete_branch_command(branch)
        raise GitSiError.new("Delete branch command requires branch name") if branch.empty?
        "#{@@git_binary} branch -D #{branch}"
      end

      def self.branch_command
        "#{@@git_binary} branch"
      end

      def self.parse_current_branch(git_branches)
        results = git_branches.match(/^\*\s+(\S+)/)
        return results[1] if results
      end

      def self.hard_reset_command
        "#{@@git_binary} reset --hard HEAD"
      end

      def self.list_file_command(filename)
        raise GitSiError.new("List file command requires filename") if filename.empty?
        "#{@@git_binary} ls-files #{filename}"
      end

      def self.init_command
        "#{@@git_binary} init"
      end

      def self.show_branch_command(branch)
        raise GitSiError.new("Show branch command requires branch name") if branch.empty?
        "#{@@git_binary} show-ref refs/heads/#{branch}"
      end

      def self.delete_command(filename)
        raise GitSiError.new("Remove file command requires filename") if filename.empty?
        "#{@@git_binary} rm -r #{filename}"
      end

    end
  end
end


