require "git/si/errors"

module Git

  module Si

    module Actions

      def do_status_action( args=[] )
        on_local_branch do
          return if do_revisions_differ()
          svn_status = get_command_output( Git::Si::SvnControl.status_command( args ) )
          print_colordiff Git::Si::SvnControl.parse_svn_status( svn_status ).join( "\n" )
        end
      end

      def do_diff_action( args=[] )
        on_local_branch do
          return if do_revisions_differ()

          notice_message "Adding any files that are not already in svn to ensure an accurate diff."
          do_readd_action

          print_colordiff get_command_output( Git::Si::SvnControl.diff_command( args ) )
        end
      end

      def do_add_action( args=[] )
        on_local_branch do
          run_command( Git::Si::SvnControl.add_command( args ) )
          run_command( Git::Si::GitControl.add_command( args ) )
        end
      end

      def do_readd_action
        on_local_branch do
          files_to_add = []
          Git::Si::SvnControl.parse_unknown_files( get_command_output( Git::Si::SvnControl.status_command ) ).each do |filename|
            if is_file_in_git?( filename )
              files_to_add << filename if filename != '.gitignore'
            end
          end

          if files_to_add.empty?
            notice_message "There are no files to add."
            return
          end

          using_stderr do
            files_to_add.each do |filename|
              say filename
            end
            if yes? "Do you want to add the above files to svn? [y/N] ", :green
              run_command( Git::Si::SvnControl.add_command( files_to_add ) )
              success_message "Added files to svn that had been added to git."
            end
          end

        end
      end

      def do_fetch_action
        stashed_changes = stash_local_changes
        on_mirror_branch do
          notice_message "Fetching remote data from svn"
          updated_files = get_command_output( Git::Si::SvnControl.update_command )
          revert_files_to_svn_update( updated_files )
          delete_files_after_svn_update( updated_files )
          add_files_after_svn_update( updated_files )
          run_command( Git::Si::GitControl.commit_revision_command( get_svn_revision ) )
        end
        unstash_local_changes( stashed_changes )
        success_message "fetch complete!"
      end

      def do_rebase_action
        on_local_branch do
          stashed_changes = stash_local_changes
          run_command( Git::Si::GitControl.rebase_command( get_mirror_branch ) )
          unstash_local_changes( stashed_changes )
          success_message "rebase complete!"
        end
      end

      def do_pull_action
        do_fetch_action
        do_rebase_action
      end

      def do_commit_action
        local_branch = get_local_branch()
        if local_branch == 'master'
          error_message "Please do not commit changes on the master branch"
          return
        end

        on_local_branch do
          raise Git::Si::GitError.new("There are local changes; please commit them before continuing.") if are_there_git_changes?

          notice_message "Adding any files that are not already in svn to ensure changes are committed."
          do_readd_action

          svn_diff = get_command_output( Git::Si::SvnControl.diff_command )
          raise Git::Si::SvnError.new("There are no changes to commit.") if svn_diff.strip.empty?

          run_command( Git::Si::SvnControl.commit_command )
          success_message "commit complete!"

          if are_there_git_changes? and yes?( "Some files were added or modified during the commit; should I revert them? [y/N] ", :yellow )
            run_command( Git::Si::GitControl.hard_reset_command )
          end
        end

        notice_message "Updating mirror branch to latest commit"
        do_fetch_action

        delete_committed_branch( local_branch ) if yes?( "Do you want to switch to the master branch and delete the committed branch '#{local_branch}'? [y/N] ", :green )
      end

      def do_init_action
        on_local_branch do
          # check for svn repo
          run_command( Git::Si::SvnControl.info_command, { :allow_errors => true } )
          raise Git::Si::SvnError.new("No svn repository was found here. Maybe you're in the wrong directory?") unless did_last_command_succeed?

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

