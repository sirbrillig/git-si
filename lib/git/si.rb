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

      desc "version", "Print the version."
      def version
        say "git-si version #{Git::Si::VERSION}"
      end

      desc "usage", "How does this thing work?"
      def usage
        say "git-si #{Git::Si::VERSION}

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
            if last_fetched_version > last_rebased_version
              raise VersionError.new("This branch is out-of-date (rev #{last_rebased_version}; mirror branch is at #{last_fetched_version}). You should do a git si rebase.")
            elsif last_fetched_version < last_rebased_version
              return if ask("This branch is newer (rev #{last_rebased_version}) than the mirror branch (rev #{last_fetched_version}). That can happen when svn changes have been made directly and may be fine. Do you want to continue? [Y/n] ", :green) =~ /\s*^n/i
            end
          else
            notice_message "Could not determine last version information. This may be fine if you haven't used git-si before."
          end

          notice_message "Adding any files that are not already in svn to ensure an accurate diff."
          readd()

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
          updated_files = `svn up --accept theirs-full --ignore-externals`
          files_to_add = []
          updated_files.each_line do |line|
            say line
            case line.strip!
            when /^\w\s+(\S.+)/
              files_to_add << '"' + $1 + '"'
            end
          end
          notice_message "Reverting any local changes in mirror branch"
          run_command("svn revert -R ./")
          unless files_to_add.empty?
            files_to_add.each do |filename|
              say "Updating file in git: #{filename}"
            end
            system("git add " + files_to_add.join(' '))
          end
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
        mirror_is_updated = false

        on_local_branch do
          local_branch = get_local_branch()
          if local_branch == 'master'
            notice_message "Warning: you're using the master branch as working copy. This can
cause trouble because when your changes are committed and you try to
rebase on top of them, you may end up with merge errors as you are
trying to apply patches of previous versions of your code. If you
continue, it's wise to reset the master branch afterward."
            return if ask("Do you want to continue with this commit? [Y/n] ", :green) =~ /\s*^n/i
          end

          git_status = `git status --porcelain`
          raise GitError.new("There are local changes; please commit them before continuing.") if git_status.match(/^[^\?]/)

          notice_message "Adding any files that are not already in svn to ensure changes are committed."
          readd()

          svn_diff = `svn diff`
          raise SvnError.new("Failed to get the svn diff. I'm not sure why. Check for any errors above.") if ! $?.success?
          raise SvnError.new("There are no changes to commit.") if svn_diff.strip.empty?

          run_command("svn commit")
          success_message "commit complete!"

          files_unchanged = true
          git_status = `git status --porcelain`
          files_unchanged = false if git_status.match(/^[^\?]/)
          unless files_unchanged
            if yes? "Some files were added or modified during the commit; should I revert them? [y/N] ", :yellow
              run_command("git reset --hard HEAD")
              files_unchanged = true
            end
          end

          if files_unchanged and yes? "Do you want to update the mirror branch to the latest commit? [y/N] ", :green
            fetch
            mirror_is_updated = true
          end
        end

        if mirror_is_updated
          local_branch = get_local_branch()
          if local_branch == 'master'
            if yes? "Do you want to reset the current branch to the latest commit (losing all git history)? [y/N] ", :green
              run_command("git checkout #{@@mirror_branch}")
              run_command("git branch -D '#{local_branch}'")
              run_command("git checkout -b #{local_branch}")
              success_message "branch '#{local_branch}' reset!"
            end
          else
            if yes? "Do you want to switch to master and delete the committed branch '#{local_branch}'? [y/N] ", :green
              run_command("git checkout master")
              rebase
              run_command("git branch -D '#{local_branch}'")
              success_message "branch '#{local_branch}' deleted!"
            end
          end
        end
      end

      desc "readd", "Add files to svn that have been added to git."
      def readd()
        on_local_branch do
          command = "svn status --ignore-externals"
          svn_status = `#{command}`
          raise SvnError.new("Failed to get the svn status. I'm not sure why. Check for any errors above.") if ! $?.success?
          files_to_add = []
          using_stderr do
            svn_status.each_line do |line|
              case line.strip!
              when /^X/, /\.git/, /\.swp$/
              when /^\?\s+(\S.+)/
                filename = $1
                file_in_git = `git ls-files #{filename}`
                raise GitError.new("Failed to list git files. I'm not sure why. Check for any errors above.") unless $?.success?
                if not file_in_git.empty?
                  files_to_add << filename if file_in_git
                  say filename
                end
              end
            end
          end
          if files_to_add.empty?
            notice_message "There are no files to add."
            return
          end
          using_stderr do
            if yes? "Do you want to add the above files to svn? [y/N] ", :green
              command = "svn add " + files_to_add.join(' ')
              run_command(command)
              success_message "Added files to svn that had been added to git."
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
          gitignore = [".svn", "*.sw?", ".config", "*.err", "*.pid", "*.log", "svn-commit.*", "*.orig"]
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

      def get_svn_root
        svn_info = `svn info`
        results = svn_info.match(/Root Path:\s+(.+)/)
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

      def in_svn_root(&block)
        root_dir = get_svn_root
        raise SvnError.new("Could not find the svn root directory.") unless root_dir
        notice_message "Changing directory to svn root: #{root_dir}"
        Dir.chdir(root_dir) do
          yield
        end
      end

      def on_local_branch(&block)
        begin
          in_svn_root do
            yield
          end
        rescue GitSiError => err
          error_message err
          exit false
        end
      end

      def on_mirror_branch(&block)
        local_branch = get_local_branch()
        run_command("git checkout #{@@mirror_branch}")
        begin
          in_svn_root do
            yield
          end
        rescue GitSiError => err
          error_message err
          exit false
        ensure
          run_command("git checkout #{local_branch}")
        end
      end

      def using_stderr(&block)
        old_stdout = $stdout
        $stdout = $stderr
        @silent = true
        begin
          yield
        ensure
          $stdout = old_stdout
          @silent = false
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
        if STDOUT.tty? and not @silent
          run(command, options)
        else
          run(command, options.update(verbose: false, capture: true))
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
