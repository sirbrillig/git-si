require "git/si/version"
require "git/si/errors"
require "git/si/svn-control"
require "git/si/git-control"
require "git/si/git-ignore"
require "git/si/output"
require "git/si/util"
require "git/si/actions"
require "thor"
require "pager"

module Git

  module Si

    class SvnInterface < Thor
      include Thor::Actions
      include Pager
      include Git::Si::Util
      include Git::Si::Actions

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

      ################
      # Action: usage
      ################
      desc "usage", "How does this thing work?"
      def usage
        say "#{Git::Si::Version.version_string}

Git Svn Interface: a simple git extention to use git locally with a remote svn
repository. It's like a simple version of git-svn just for using local
branching. It does not keep track of the full history of the svn repository.

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
        do_status_action( args )
      end

      ################
      # Action: diff
      ################
      desc "diff [FILES]", "Perform an svn diff piped through a colorizer. Also tests to be sure a rebase is not needed."
      def diff(*args)
        configure
        do_diff_action( args )
      end

      ################
      # Action: add
      ################
      desc "add [FILES]", "Perform an svn and a git add on the files."
      def add(*args)
        configure
        do_add_action( args )
      end

      ################
      # Action: fetch
      ################
      desc "fetch", "Updates mirror branch to latest svn commit."
      def fetch
        configure
        do_fetch_action
      end

      ################
      # Action: rebase
      ################
      desc "rebase", "Rebases current branch to mirror branch."
      def rebase
        configure
        do_rebase_action
      end

      ################
      # Action: pull
      ################
      desc "pull", "Fetch the latest svn commit and rebase the current branch."
      def pull
        do_pull_action
      end

      ################
      # Action: commit
      ################
      desc "commit", "Perform an svn commit and update the mirror branch."
      def commit
        configure
        do_commit_action
      end

      ################
      # Action: readd
      ################
      desc "readd", "Add files to svn that have been added to git."
      def readd
        configure
        do_readd_action
      end

      ################
      # Action: init
      ################
      desc "init", "Initializes git-si in this directory with a gitignore and creates a special mirror branch."
      def init
        configure
        do_init_action
      end

    end
  end
end
