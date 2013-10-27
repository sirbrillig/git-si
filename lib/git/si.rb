require "git/si/version"
require "thor"

module Git

  module Si

    class SvnInterface < Thor

      desc "hello <name>", "say hello"
      def hello(name)
        puts "Hello #{name}"
      end

      desc "status [FILES]", "Perform an svn status."
      def status(*args)
        command = "svn status " + args.join(' ')
        puts "running> #{command}"
        `#{command}`
      end

    end

  end

end
