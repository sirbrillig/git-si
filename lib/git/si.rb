require "git/si/version"
require "thor"
require "pager"

module Git

  module Si

    class SvnInterface < Thor
      include Thor::Actions
      include Pager

      desc "hello <name>", "say hello"
      def hello(name)
        puts "Hello #{name}"
      end

      desc "status [FILES]", "Perform an svn status."
      def status(*args)
        command = "svn status --ignore-externals " + args.join(' ')
        run_command(command)
      end

      desc "diff [FILES]", "Perform an svn diff piped through a colorizer. Also tests to be sure a rebase is not needed."
      def diff(*args)
        svn_info = `svn info`
        results = svn_info.match(/^Revision:\s+(\d+)/)
        last_fetched_version = results[1] if results
        git_log = `git log --pretty=%B`
        results = git_log.match(/svn update to version (\d+)/i)
        last_rebased_version = results[1] if results
        if last_fetched_version and last_rebased_version
          if last_fetched_version != last_rebased_version
            error_message "This branch is out-of-date (rev $OUR_PULLED_REV; mirror branch is at $LAST_PULLED_REV). You should do a git lt rebase."
            exit
          end
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

      desc "add [FILES]", "Perform an svn and a git add on the files."
      def add(*args)
        command = "svn add " + args.join(' ')
        run_command(command)
        command = "git add " + args.join(' ')
        run_command(command)
      end

      private

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
