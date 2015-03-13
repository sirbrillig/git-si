require "git/si/version"
require "git/si/errors"
require "git/si/svn-control"
require "git/si/git-control"
require "git/si/git-ignore"
require "git/si/output"
require "git/si/util"
require "thor"
require "pager"

module Git

  module Si

    class SvnInterface < Thor
      include Thor::Actions
      include Pager
      include Git::Si::Util

      class_option :debug, :type => :boolean, :desc => 'Print lots of output', :default => false
      class_option :quiet, :type => :boolean, :desc => 'Print only the minimum output', :default => false
      class_option :svn, :type => :string, :desc => 'The path to the svn binary', :default => 'svn'
      class_option :git, :type => :string, :desc => 'The path to the git binary', :default => 'git'

      default_task :usage

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
          return if do_revisions_differ()
          svn_status = get_command_output(Git::Si::SvnControl.status_command(args))
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
          # revert everything, but sometimes that doesn't work, so revert conflicts too.
          run_command(Git::Si::SvnControl.revert_command)
          Git::Si::SvnControl.parse_conflicted_files(updated_files).each do |filename|
            run_command(Git::Si::SvnControl.revert_command(filename))
          end
          # delete deleted files.
          Git::Si::SvnControl.parse_deleted_files(updated_files).each do |filename|
            run_command(Git::Si::GitControl.delete_command(filename))
          end
          notice_message "Updating mirror branch to match new data"
          # add updated files
          Git::Si::SvnControl.parse_updated_files(updated_files).each do |filename|
            begin
              run_command(Git::Si::GitControl.add_command(filename))
            rescue
              # an error here is not worth it to stop the process.
            end
          end
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
          stashed_changes = false
          if are_there_git_changes?
            notice_message "Preserving uncommitted changed files"
            stashed_changes = true
            run_command(Git::Si::GitControl.stash_command)
          end
          run_command(Git::Si::GitControl.rebase_command(get_mirror_branch))
          if (stashed_changes)
            notice_message "Restoring uncommitted changed files"
            run_command(Git::Si::GitControl.unstash_command)
          end
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
            run_command(Git::Si::GitControl.checkout_command(get_mirror_branch))
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

          files_to_add = []
          using_stderr do
            Git::Si::SvnControl.parse_unknown_files(svn_status).each do |filename|
              if not get_command_output( Git::Si::GitControl.list_file_command(filename) ).empty?
                if filename != '.gitignore'
                  files_to_add << filename
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
        configure
        on_local_branch do
          run_command(Git::Si::SvnControl.blame_command(args))
        end
      end

      ################
      # Action: init
      ################
      desc "init", "Initializes git-si in this directory with a gitignore and creates a special mirror branch."
      def init
        configure
        on_local_branch do
          # check for svn repo
          run_command(Git::Si::SvnControl.info_command, {:allow_errors => true})
          raise SvnError.new("No svn repository was found here. Maybe you're in the wrong directory?") unless $?.success?

          # make sure svn repo is up-to-date
          run_command( Git::Si::SvnControl.update_command )

          make_a_commit = false

          # check for existing .git repo
          make_a_commit = true if create_git_repository()

          # check for existing .gitignore
          make_a_commit = true if create_gitignore()

          # make initial commit
          if make_a_commit
            notice_message "Making initial commit."
            run_command( Git::Si::GitControl.commit_revision_command(get_svn_revision) )
          end

          # check for exiting mirror branch
          create_mirror_branch()

          success_message "init complete!"
        end
      end

    end
  end
end
