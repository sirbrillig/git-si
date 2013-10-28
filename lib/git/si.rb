require "git/si/version"
require "thor"
require "pager"

module Git

  module Si

    class GitSiError < StandardError
    end

    class GitError < GitSiError
    end

    class SvnError < GitSiError
    end

    class VersionError < GitSiError
    end

    class SvnInterface < Thor
      include Thor::Actions
      include Pager

      @@mirror_branch = 'MIRRORBRANCH'

      desc "status [FILES]", "Perform an svn status."
      def status(*args)
        on_local_branch do
          command = "svn status --ignore-externals " + args.join(' ')
          run_command(command)
        end
      end

      desc "diff [FILES]", "Perform an svn diff piped through a colorizer. Also tests to be sure a rebase is not needed."
      def diff(*args)
        on_local_branch do
          last_fetched_version = get_svn_version()
          git_log = `git log --pretty=%B`
          results = git_log.match(/svn update to version (\d+)/i)
          last_rebased_version = results[1] if results
          if last_fetched_version and last_rebased_version
            raise VersionError.new("This branch is out-of-date (rev $OUR_PULLED_REV; mirror branch is at $LAST_PULLED_REV). You should do a git lt rebase.") if last_fetched_version != last_rebased_version
          else
            error_message "Could not determine version information"
          end

          command = "svn diff " + args.join(' ')
          results = `#{command}`
          if STDOUT.tty?
            page
            print_colordiff results
          else
            say results
          end
        end
      end

      desc "add [FILES]", "Perform an svn and a git add on the files."
      def add(*args)
        on_local_branch do
          command = "svn add " + args.join(' ')
          run_command(command)
          command = "git add " + args.join(' ')
          run_command(command)
        end
      end

      desc "fetch", "Updates mirror branch to latest svn commit."
      def fetch
        on_local_branch do
          git_status = `git status --porcelain`
          raise GitError.new("There are local changes; please commit them before continuing.") if git_status.match(/^[^\?]/)
        end
        on_mirror_branch do
          notice_message "Fetching remote data from svn"
          `svn up --accept theirs-full --ignore-externals && svn revert -R ./ && git add . && git commit -am "svn update to version #{get_svn_version}"`
          raise SvnError.new("The fetch failed. I'm not sure why, but look at any error messages above.") unless $?.success?
        end
        success_message "fetch complete!"
      end

      desc "rebase", "Rebases current branch to mirror branch."
      def rebase
        on_local_branch do
          `git rebase "#{@@mirror_branch}"`
          raise GitError.new("The rebase failed. I'm not sure why, but look at any error messages above.") unless $?.success?
          success_message "rebase complete!"
        end
      end

      desc "pull", "Fetch the latest svn commit and rebase the current branch."
      def pull
        fetch
        rebase
      end


      private

      def get_svn_version
        svn_info = `svn info`
        results = svn_info.match(/^Revision:\s+(\d+)/)
        return results[1] if results
        return nil
      end

      def get_local_branch
        git_branches = `git branch`
        results = git_branches.match(/^\*\s+(\S+)/)
        local_branch = results[1] if results
        raise GitError.new("Could not find local branch name.") unless local_branch
        return local_branch
      end

      def on_local_branch(&block)
        begin
          yield
        rescue GitSiError => err
          error_message err
          exit false
        end
      end

      def on_mirror_branch(&block)
        local_branch = get_local_branch()
        run_command("git checkout #{@@mirror_branch}")
        begin
          yield
        rescue GitSiError => err
          error_message err
          exit false
        ensure
          run_command("git checkout #{local_branch}")
        end
      end

      def success_message(message)
        $stderr.puts set_color message, :green
      end

      def notice_message(message)
        $stderr.puts set_color message, :yellow
      end

      def error_message(message)
        $stderr.puts set_color message, :red
      end

      def run_command(command, options={})
        if STDOUT.tty?
          run(command, options)
        else
          run(command, options.update(verbose: false))
        end
      end

      def print_colordiff(diff)
        diff.each_line do |line|
          line.strip!
          case line
          when /^\+/
            line = set_color line, :green
          when /^\-/
            line = set_color line, :red
          end
          say line
        end
      end

    end
  end
end
