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
        run(command)
      end

      desc "diff [FILES]", "Perform an svn diff piped through a colorizer. Also tests to be sure a rebase is not needed."
      def diff(*args)
        command = "svn diff " + args.join(' ')
        results = `#{command}`
        if STDOUT.tty?
          page
          print_colordiff results
        else
          say results
        end
      end

      private

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
