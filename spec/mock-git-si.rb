require "git/si/util"
require "git/si/actions"

module Git

  module Si

    class Mock
      include Git::Si::Util
      include Git::Si::Actions

      def initialize( spy )
        @spy = spy
      end

      def say(toss)
      end

      def debug(toss)
      end

      def in_svn_root
        yield
      end

      def on_mirror_branch
        yield
      end

      def error_message(toss)
      end

      def success_message(toss)
      end

      def notice_message(toss)
      end

      def did_last_command_succeed?
        true
      end

      def run_command( command, options={} )
        @spy.run_command( command, options )
        raise "test error" if command =~ /raise/
        "testing run_command"
      end
    end
  end
end
