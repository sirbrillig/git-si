require "git/si/version"
require "git/si/errors"
require "git/si/svn-control"
require "git/si/git-control"
require "git/si/output"
require "thor"
require "pager"

module Git

  module Si

    class SvnInterface < Thor
      include Thor::Actions
      include Pager

      class_option :debug, :type => :boolean, :desc => 'Print lots of output', :default => false
      class_option :quiet, :type => :boolean, :desc => 'Print only the minimum output', :default => false
      class_option :svn, :type => :string, :desc => 'The path to the svn binary', :default => 'svn'
      class_option :git, :type => :string, :desc => 'The path to the git binary', :default => 'git'

      default_task :usage

      @@mirror_branch = 'MIRRORBRANCH'

      ##################
      # Action functions
      ##################

      ################
      # Action: version
      ################
      desc "version", "Print the version."
      def version
        say Git::Si::Version.version_string
      end

      desc "usage", "How does this thing work?"
      def usage
        say "#{Git::Si::Version.version_string}

Git Svn Interface: a simple git extention to use git locally with a remote svn
repo. It's like a simple version of git-svn which doesn't keep track of history
locally.

Start with the init command to set up the mirror branch and from there you can
use the commands below.

"
        help
      end

      ################
      # Action: status
      ################
      desc "status [FILES]", "Perform an svn status."
      def status(*args)
        configure
        on_local_branch do
          svn_status = get_command_output(Git::Si::SvnControl.status_command(args))
          raise SvnError.new("Failed to get the svn status. I'm not sure why. Check for any errors above.") if ! $?.success?
          print_colordiff Git::Si::Output.svn_status( svn_status )
        end
      end

      ################
      # Action: status
      ################
      desc "diff [FILES]", "Perform an svn diff piped through a colorizer. Also tests to be sure a rebase is not needed."
      def diff(*args)
        configure
        on_local_branch do
          return if do_revisions_differ()

          notice_message "Adding any files that are not already in svn to ensure an accurate diff."
          readd()

          print_colordiff get_command_output(Git::Si::SvnControl.diff_command(args))
        end
      end

      ################
      # Action: add
      ################
      desc "add [FILES]", "Perform an svn and a git add on the files."
      def add(*args)
        configure
        on_local_branch do
          run_command(Git::Si::SvnControl.add_command(args))
          run_command(Git::Si::GitControl.add_command(args))
        end
      end

      ################
      # Action: fetch
      ################
      desc "fetch", "Updates mirror branch to latest svn commit."
      def fetch
        configure
        stashed_changes = false
        on_local_branch do
          if are_there_git_changes?
            notice_message "Preserving uncommitted changed files"
            stashed_changes = true
            run_command(Git::Si::GitControl.stash_command)
          end
        end
        on_mirror_branch do
          notice_message "Fetching remote data from svn"
          updated_files = get_command_output( Git::Si::SvnControl.update_command )
          notice_message "Reverting any local changes in mirror branch"
          files_to_revert = Git::Si::SvnControl.parse_conflicted_files(updated_files)
          run_command(Git::Si::SvnControl.revert_command(files_to_revert)) unless files_to_revert.empty?
          notice_message "Updating mirror branch to match new data"
          files_to_add = Git::Si::SvnControl.parse_updated_files(updated_files)
          run_command(Git::Si::SvnControl.add_command(files_to_add)) unless files_to_add.empty?
          run_command( Git::Si::GitControl.commit_revision_command(get_svn_revision) )
        end
        if (stashed_changes)
          notice_message "Restoring uncommitted changed files"
          run_command(Git::Si::GitControl.unstash_command)
        end
        success_message "fetch complete!"
      end

      ################
      # Action: rebase
      ################
      desc "rebase", "Rebases current branch to mirror branch."
      def rebase
        configure
        on_local_branch do
          run_command(Git::Si::GitControl.rebase_command(@@mirror_branch))
          success_message "rebase complete!"
        end
      end

      ################
      # Action: pull
      ################
      desc "pull", "Fetch the latest svn commit and rebase the current branch."
      def pull
        fetch
        rebase
      end

      ################
      # Action: commit
      ################
      desc "commit", "Perform an svn commit and update the mirror branch."
      def commit
        configure

        on_local_branch do
          local_branch = get_local_branch()
          if local_branch == 'master'
            notice_message "Warning: you're using the master branch as working copy. This can
cause trouble because when your changes are committed and we try to
rebase on top of them, you may end up with merge errors as we are
trying to apply patches of previous versions of your code. If you
continue, it's wise to reset the master branch afterward."
            return if ask("Do you want to continue with this commit? [Y/n] ", :green) =~ /\s*^n/i
          end

          raise GitError.new("There are local changes; please commit them before continuing.") if are_there_git_changes?

          notice_message "Adding any files that are not already in svn to ensure changes are committed."
          readd()

          svn_diff = get_command_output(Git::Si::SvnControl.diff_command)
          raise SvnError.new("Failed to get the svn diff. I'm not sure why. Check for any errors above.") if ! $?.success?
          raise SvnError.new("There are no changes to commit.") if svn_diff.strip.empty?

          run_command(Git::Si::SvnControl.commit_command)
          success_message "commit complete!"

          if Git::Si::GitControl.are_there_changes?( get_command_output(Git::Si::GitControl.status_command()) )
            if yes? "Some files were added or modified during the commit; should I revert them? [y/N] ", :yellow
              run_command(Git::Si::GitControl.hard_reset_command)
            end
          end
        end

        notice_message "Updating mirror branch to latest commit"
        fetch

        local_branch = get_local_branch()
        if local_branch == 'master'
          if yes? "Do you want to reset the master branch to the latest commit (**losing all git history**)? [y/N] ", :green
            run_command(Git::Si::GitControl.checkout_command(@@mirror_branch))
            run_command(Git::Si::GitControl.delete_branch_command( 'master' ))
            run_command(Git::Si::GitControl.create_branch_command( 'master' ))
            run_command(Git::Si::GitControl.checkout_command('master'))
            success_message "master branch reset!"
          end
        else
          if yes? "Do you want to switch to the master branch and delete the committed branch '#{local_branch}'? [y/N] ", :green
            run_command(Git::Si::GitControl.checkout_command('master'))
            rebase
            run_command(Git::Si::GitControl.delete_branch_command(local_branch))
            success_message "branch '#{local_branch}' deleted!"
          end
        end
      end

      ################
      # Action: readd
      ################
      desc "readd", "Add files to svn that have been added to git."
      def readd()
        configure
        on_local_branch do
          svn_status = get_command_output(Git::Si::SvnControl.status_command(args))
          raise SvnError.new("Failed to get the svn status. I'm not sure why. Check for any errors above.") if ! $?.success?

          files_to_add = []
          using_stderr do
            Git::Si::SvnControl.parse_unknown_files(svn_status).each do |filename|
              if not get_command_output( Git::Si::GitControl.list_file_command(filename) ).empty?
                files_to_add << filename
                say filename
              end
            end
          end

          if files_to_add.empty?
            notice_message "There are no files to add."
            return
          end

          using_stderr do
            if yes? "Do you want to add the above files to svn? [y/N] ", :green
              run_command(Git::Si::SvnControl.add_command(files_to_add))
              success_message "Added files to svn that had been added to git."
            end
          end

        end
      end

      ################
      # Action: blame
      ################
      desc "blame <FILE>", "Alias for svn blame."
      def blame(*args)
        on_local_branch do
          run_command(Git::Si::SvnControl.blame_command(args))
        end
      end

      ################
      # Action: sync
      ################
      desc "sync", "Synchronize git repository to files in svn"
      def sync
        on_local_branch do
          command = "#{options[:svn]} ls -R"
          all_files = `#{command}`
          raise SvnError.new("Failed to list svn files. I'm not sure why. Check for any errors above.") unless $?.success?
          files_to_add = []
          using_stderr do
            all_files.each_line do |line|
              files_to_add << line.strip!
              say line
            end
          end
          if files_to_add.empty?
            notice_message "There are no files to add."
            return
          end
          using_stderr do
            if yes? "Do you want to add the above files to git? [y/N] ", :green
              files_to_add.each do |filename|
                command = "git add " + filename
                run_command(command)
              end
              success_message "Added all files to git that exist in svn."
            end
          end
        end
      end

      ################
      # Action: init
      ################
      desc "init", "Initializes git-si in this directory with a gitignore and creates a special mirror branch."
      def init
        on_local_branch do
          # check for svn repo
          `#{options[:svn]} info`
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
          gitignore = [".svn", "*.sw?", ".config", "*.err", "*.pid", "*.log", "svn-commit.*", "*.orig", "node_modules"]
          command = "#{options[:svn]} status --ignore-externals "
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
            run_command( Git::Si::GitControl.commit_revision_command(get_svn_revision) )
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


      ##################
      # Helper functions
      ##################
      private

      def configure
        Git::Si::SvnControl.svn_binary = options[:svn]
        Git::Si::GitControl.git_binary = options[:git]
      end

      # Return the most recent svn revision number stored in git
      def get_git_si_revision
        info = get_command_output(Git::Si::GitControl.log_command('--pretty=%B'))
        return Git::Si::GitControl.parse_last_svn_revision(info)
      end

      # Return the most recent svn revision number
      def get_svn_revision
        svn_info = get_command_output(Git::Si::SvnControl.info_command)
        return Git::Si::SvnControl.parse_last_revision(svn_info)
      end

      def get_svn_root
        svn_info = `#{options[:svn]} info`
        results = svn_info.match(/Root Path:\s+(.+)/)
        return results[1] if results
        return nil
      end

      def get_local_branch
        git_branches = get_command_output(Git::Si::GitControl.branch_command)
        local_branch = Git::Si::GitControl.parse_current_branch(git_branches)
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
        run_command( Git::Si::GitControl.checkout_command(@@mirror_branch) )
        begin
          in_svn_root do
            yield
          end
        rescue GitSiError => err
          error_message err
          exit false
        ensure
          run_command( Git::Si::GitControl.checkout_command(local_branch) )
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
        $stderr.puts set_color message, :yellow unless options[:quiet]
      end

      def error_message(message)
        $stderr.puts set_color message, :red
      end

      def debug(message)
        $stderr.puts message if options[:debug]
      end

      def run_command(command, options={})
        output = ''
        debug "run_command `#{command}`, options: #{options}"
        if STDOUT.tty? and not @silent
          output = run(command, options)
        else
          output = run(command, options.update(verbose: false, capture: true))
        end
        raise ShellError.new("There was an error while trying to run the command: #{command}. Look above for any errors.") unless $?.success?
        return output
      end

      def get_command_output(command, options={})
        run_command(command, options.merge( capture: true ))
      end

      def do_revisions_differ
        last_fetched_version = get_svn_revision()
        last_rebased_version = get_git_si_revision()

        if ! last_fetched_version or ! last_rebased_version
          notice_message "Could not determine last git-si version information. This may be fine if you haven't used git-si before."
        else
          if last_fetched_version > last_rebased_version
            raise VersionError.new("This branch is out-of-date (svn revision #{last_rebased_version}; svn is at #{last_fetched_version}). You should do a git si rebase or git si pull.")
          elsif last_fetched_version < last_rebased_version
            return if ask("This branch is newer (svn revision #{last_rebased_version}) than svn (rev #{last_fetched_version}). That can happen when svn changes have been made directly and may be fine. Do you want to continue? [Y/n] ", :green) =~ /\s*^n/i
          end
        end
      end

      def print_colordiff(diff)
        debug "print_colordiff"
        if ! STDOUT.tty?
          debug "print_colordiff returning without colorizing"
          return say diff
        end
        debug "print_colordiff colorizing..."
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

      def are_there_git_changes?
        Git::Si::GitControl.are_there_changes?( get_command_output(Git::Si::GitControl.status_command()) )
      end

    end
  end
end
