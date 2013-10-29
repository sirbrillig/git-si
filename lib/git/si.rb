require "git/si/version"
require "thor"
require "pager"

module Git

  module Si

    class GitSiError < StandardError
    end

    class ShellError < GitSiError
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

      default_task :usage

      @@mirror_branch = 'MIRRORBRANCH'

      desc "usage", "How does this thing work?"
      def usage
        say "git-si

Git Svn Interface: a simple git extention to use git locally with a remote svn
repo. It's like a simple version of git-svn which doesn't keep track of history
locally.

Start with the init command to set up the mirror branch and from there you can
use the commands below.

"
        help
      end

      desc "status [FILES]", "Perform an svn status."
      def status(*args)
        on_local_branch do
          command = "svn status --ignore-externals " + args.join(' ')
          svn_status = `#{command}`
          raise SvnError.new("Failed to get the svn status. I'm not sure why. Check for any errors above.") if ! $?.success?
          svn_status.each_line do |line|
            case line.strip!
            when /^X/, /\.git/, /\.swp$/
            else
              if STDOUT.tty?
                print_colordiff line
              else
                say line
              end
            end
          end
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
            raise VersionError.new("This branch is out-of-date (rev #{last_rebased_version}; mirror branch is at #{last_fetched_version}). You should do a git si rebase.") if last_fetched_version != last_rebased_version
          else
            notice_message "Could not determine last version information. This may be fine if you haven't used git-si before."
          end

          command = "svn diff " + args.join(' ')
          notice_message "Running #{command}"
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
          run_command("svn up --accept theirs-full --ignore-externals")
          run_command("svn revert -R ./")
          system("git add .")
          run_command("git commit --allow-empty -am 'svn update to version #{get_svn_version}'")
        end
        success_message "fetch complete!"
      end

      desc "rebase", "Rebases current branch to mirror branch."
      def rebase
        on_local_branch do
          run_command("git rebase '#{@@mirror_branch}'")
          success_message "rebase complete!"
        end
      end

      desc "pull", "Fetch the latest svn commit and rebase the current branch."
      def pull
        fetch
        rebase
      end

      desc "commit", "Perform an svn commit and update the mirror branch."
      def commit
        on_local_branch do
          `svn commit`
          raise SvnError.new("svn commit failed. I'm not sure why, but look at any error messages above.") unless $?.success?
          success_message "commit complete!"
          if yes? "Do you want to update the mirror branch to the latest commit? [y/N] "
            on_mirror_branch do
              fetch
            end
          end
        end
      end

      desc "blame <FILE>", "Alias for svn blame."
      def blame(*args)
        on_local_branch do
          command = "svn blame " + args.join(' ')
          run_command(command)
        end
      end

      desc "init", "Initializes git-si in this directory with a gitignore and creates a special mirror branch."
      def init
        on_local_branch do
          # check for svn repo
          `svn info`
          raise SvnError.new("No svn repository was found here. Maybe you're in the wrong directory?") unless $?.success?
          make_a_commit = false

          # check for existing .git repo
          if File.exist? '.git'
            notice_message "Looks like a git repository already exists here."
          else
            notice_message "Initializing git repository"
            `git init`
            raise GitError.new("Failed to initialize git repository. I'm not sure why. Check for any errors above.") unless $?.success?
            make_a_commit = true
          end

          # check for existing .gitingore
          gitignore = [".svn", "*.swp", ".config", "*.err", "*.pid", "*.log"]
          command = "svn status --ignore-externals "
          svn_status = `#{command}`
          raise SvnError.new("Failed to get the svn status. I'm not sure why. Check for any errors above.") if ! $?.success?
          externals = []
          svn_status.each_line do |line|
            externals << $1 if line.strip.match(/^X\s+(\S.+)/)
          end
          gitignore += externals
          gitignore = gitignore.join("\n")

          if File.exist? '.gitignore'
            notice_message "Looks like a gitignore file already exists here."
            error_message "Be SURE that the gitignore contains the following:\n#{gitignore}"
          else
            notice_message "Creating gitignore file."
            create_file('.gitignore', gitignore)
            run_command("git add .gitignore")
            make_a_commit = true
          end

          # make initial commit
          if make_a_commit
            notice_message "Making initial commit."
            run_command("git add .")
            run_command("git commit -am 'initial commit by git-si'")
          end

          # check for exiting mirror branch
          `git show-ref refs/heads/#{@@mirror_branch}`
          if $?.success?
            notice_message "Looks like the mirror branch already exists here."
          else
            notice_message "Creating mirror branch '#{@@mirror_branch}'."
            run_command("git branch '#{@@mirror_branch}'")
          end

          success_message "init complete!"
        end
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
        raise ShellError.new("There was an error while trying to run the command: #{command}. Look above for any errors.") unless $?.success?
      end

      def print_colordiff(diff)
        diff.each_line do |line|
          line.rstrip!
          case line
          when /^\+/, /^A/
            line = set_color line, :green
          when /^\-/, /^M/
            line = set_color line, :red
          when /^\?/
            line = set_color line, :yellow
          end
          say line
        end
      end

    end
  end
end
