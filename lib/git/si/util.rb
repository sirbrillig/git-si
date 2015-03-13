module Git

  module Si

    module Util

      def did_last_command_succeed?
        $?.success?
      end

      def run_command(command, options={})
        output = ''
        debug "run_command `#{command}`, options: #{options}"
        if STDOUT.tty? and not @silent
          output = run(command, options)
        else
          output = run(command, options.update(verbose: false, capture: true))
        end
        raise ShellError.new("There was an error while trying to run the command: #{command}. Look above for any errors.") if not options[:allow_errors] and not did_last_command_succeed?
        return output
      end

      def get_command_output(command, options={})
        run_command(command, options.merge( capture: true ))
      end

      def batch_add_files_to_git( filenames )
        filenames.each_slice(10) do |batch|
          begin
            run_command( Git::Si::GitControl.add_command( batch ) )
          rescue
            # try to batch the files but add them individually if there is an error
            add_files_to_git( batch )
          end
        end
      end

      def add_files_to_git( filenames )
        filenames.each do |filename|
          begin
            run_command( Git::Si::GitControl.add_command(filename) )
          rescue
            # errors here are not important enough to stop the whole process
          end
        end
      end

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
        svn_info = get_command_output(Git::Si::SvnControl.info_command, {:allow_errors => true})
        root_dir = Git::Si::SvnControl.parse_root_path(svn_info)
        raise SvnError.new("Could not find the svn root directory.") unless root_dir
        root_dir
      end

      def get_local_branch
        git_branches = get_command_output(Git::Si::GitControl.branch_command)
        local_branch = Git::Si::GitControl.parse_current_branch(git_branches)
        raise GitError.new("Could not find local branch name.") unless local_branch
        return local_branch
      end

      def in_svn_root(&block)
        root_dir = get_svn_root
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

      def get_mirror_branch
        return 'MIRRORBRANCH'
      end

      def on_mirror_branch(&block)
        local_branch = get_local_branch()
        run_command( Git::Si::GitControl.checkout_command(get_mirror_branch) )
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

      def do_revisions_differ
        last_fetched_version = get_svn_revision()
        last_rebased_version = get_git_si_revision()

        if ! last_fetched_version or ! last_rebased_version
          notice_message "Could not determine last git-si version information. This may be fine if you haven't used git-si before."
          return
        end

        debug "comparing last fetched revision #{last_fetched_version} and last rebased revision #{last_rebased_version}"

        if last_fetched_version > last_rebased_version
          raise VersionError.new("This branch is out-of-date (svn revision #{last_rebased_version}; svn is at #{last_fetched_version}). You should do a git si rebase or git si pull.")
        elsif last_fetched_version < last_rebased_version
          return true if ask("This branch is newer (svn revision #{last_rebased_version}) than svn (rev #{last_fetched_version}). That can happen when svn changes have been made directly and may be fine. Do you want to continue? [Y/n] ", :green) =~ /\s*^n/i
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

      def create_git_repository
        if File.exist? '.git'
          notice_message "Looks like a git repository already exists here."
          return false
        end
        notice_message "Initializing git repository"
        run_command(Git::Si::GitControl.init_command, {:allow_errors => true})
        raise GitError.new("Failed to initialize git repository. I'm not sure why. Check for any errors above.") unless did_last_command_succeed?
        add_all_svn_files()
        true
      end

      def create_gitignore
        # add externals to gitignore
        gitignore_patterns = Git::Si::GitIgnore.ignore_patterns
        gitignore_patterns += Git::Si::Output.parse_external_repos( get_command_output( Git::Si::SvnControl.status_command ) )

        if not File.exist? '.gitignore'
          notice_message "Creating gitignore file."
          create_file('.gitignore', gitignore_patterns.join( "\n" ))
          run_command( Git::Si::GitControl.add_command('.gitignore') )
          return true
        end

        notice_message "Looks like a gitignore file already exists here."
        missing_patterns = Git::Si::GitIgnore.get_missing_lines_from( File.readlines( '.gitignore' ), gitignore_patterns )
        if not missing_patterns.empty?
          using_stderr do
            say "The .gitignore file is missing the following recommended patterns:\n#{missing_patterns.join( "\n" )}"
            if yes?("Do you want to add them? [Y/n] ", :green)
              append_to_file( '.gitignore', missing_patterns.join("\n") )
              run_command( Git::Si::GitControl.add_command('.gitignore') )
              return true
            end
          end
        end
        false
      end

      def add_all_svn_files
        notice_message "Adding all files present in the svn repository."
        all_svn_files = Git::Si::SvnControl.parse_file_list( get_command_output( Git::Si::SvnControl.list_file_command ) )
        raise GitSiError.new("No files could be found in the svn repository.") if all_svn_files.empty?
        batch_add_files_to_git( all_svn_files )
      end

      def create_mirror_branch
        begin
          run_command( Git::Si::GitControl.show_branch_command(get_mirror_branch) )
        rescue
          # no problem. It just means the branch does not exist.
        end
        if did_last_command_succeed?
          notice_message "Looks like the mirror branch already exists here."
        else
          notice_message "Creating mirror branch '#{get_mirror_branch}'."
          run_command( Git::Si::GitControl.create_branch_command(get_mirror_branch) )
        end
      end
    end
  end
end
