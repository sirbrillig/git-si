require "git/si/util"
require "git/si/actions"

describe Git::Si::Actions do
  let( :runner_spy ) { spy( 'runner_spy' ) }
  let( :test_mixin_host ) {
    Class.new do
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
  }

  let( :svn_status_output ) { "Z foobar
X foobar
? .git
M foobar.git
M foobar.swp
M barfoo
A something
D something else
? whatever
" }

  let( :svn_update_output ) { "
Restored 'bin/tests/importantthing'
A    bin/tests/foobar
U    bin/tests/api/goobar
G    bin/tests/api/special
U    bin/tests/api/anotherfile
A    bin/tests/barfoo
?    unknownfile.md
D    byefile
   C myimage.png
D    badjs.js
   C something/javascript.js
   A something/newjs.js
C    css/_base.scss
Updated to revision 113333.
" }

  subject { test_mixin_host.new( runner_spy ) }

  describe "#do_status_action" do
    before do
      allow( subject ).to receive( :run_command ).and_return( '' )
    end

    it "sends status output to print_colordiff" do
      data = "Z foobar
M something else"
      allow( subject ).to receive( :run_command ).with( /svn status/, any_args ).and_return( data )
      allow( subject ).to receive( :print_colordiff )
      expect( subject ).to receive( :print_colordiff ).with( data )
      subject.do_status_action
    end

    it "calls svn status with passed arguments" do
      expect( subject ).to receive( :run_command ).with( /svn status .+ foobar barfoo/, any_args )
      subject.do_status_action( [ 'foobar', 'barfoo' ] )
    end
  end

  describe "#do_diff_action" do
    before do
      allow( subject ).to receive( :do_readd_action )
      allow( subject ).to receive( :run_command ).and_return( '' )
    end

    it "calls do_revisions_differ" do
      allow( subject ).to receive( :do_revisions_differ )
      expect( subject ).to receive( :do_revisions_differ ).once
      subject.do_diff_action
    end

    it "calls the readd action" do
      expect( subject ).to receive( :do_readd_action ).once
      subject.do_diff_action
    end

    it "sends diff output to print_colordiff" do
      data = "+ foobar
- something else"
      allow( subject ).to receive( :run_command ).with( /svn diff/, any_args ).and_return( data )
      allow( subject ).to receive( :print_colordiff )
      expect( subject ).to receive( :print_colordiff ).with( data )
      subject.do_diff_action
    end

    it "calls svn diff with passed arguments" do
      expect( subject ).to receive( :run_command ).with( /svn diff.+foobar barfoo/, any_args )
      subject.do_diff_action( [ 'foobar', 'barfoo' ] )
    end
  end

  describe "#do_add_action" do
    it "calls git add with the passed arguments" do
      allow( subject ).to receive( :run_command ).and_return( '' )
      expect( subject ).to receive( :run_command ).with( /git add.+foobar barfoo/ )
      subject.do_add_action( [ 'foobar', 'barfoo' ] )
    end

    it "calls svn add with the passed arguments" do
      allow( subject ).to receive( :run_command ).and_return( '' )
      expect( subject ).to receive( :run_command ).with( /svn add.+foobar barfoo/ )
      subject.do_add_action( [ 'foobar', 'barfoo' ] )
    end
  end

  describe "#do_atune_action" do
    it "calls git commit all" do
      expect( runner_spy ).to receive( :run_command ).with( /git commit.*-a/, any_args )
      subject.do_atune_action
    end

    it "operates in the mirror branch" do
      expect( subject ).to receive( :on_mirror_branch ).once
      subject.do_atune_action
    end
  end

  describe "#do_fetch_action" do
    it "calls stash_local_changes" do
      expect( subject ).to receive( :stash_local_changes ).once
      subject.do_fetch_action
    end

    it "calls svn update" do
      expect( runner_spy ).to receive( :run_command ).with( /svn up/, any_args )
      subject.do_fetch_action
    end

    it "calls revert_files_to_svn_update with update output" do
      allow( subject ).to receive( :run_command ).and_return( '' )
      allow( subject ).to receive( :run_command ).with( /svn up/, any_args ).and_return( svn_update_output )
      expect( subject ).to receive( :revert_files_to_svn_update ).with( svn_update_output )
      subject.do_fetch_action
    end

    it "calls delete_files_after_svn_update with update output" do
      allow( subject ).to receive( :run_command ).and_return( '' )
      allow( subject ).to receive( :run_command ).with( /svn up/, any_args ).and_return( svn_update_output )
      expect( subject ).to receive( :delete_files_after_svn_update ).with( svn_update_output )
      subject.do_fetch_action
    end

    it "calls add_files_after_svn_update with update output" do
      allow( subject ).to receive( :run_command ).and_return( '' )
      allow( subject ).to receive( :run_command ).with( /svn up/, any_args ).and_return( svn_update_output )
      expect( subject ).to receive( :add_files_after_svn_update ).with( svn_update_output )
      subject.do_fetch_action
    end

    it "makes a git commit with the svn revision" do
      allow( subject ).to receive( :get_svn_revision ).and_return( '1012' )
      expect( runner_spy ).to receive( :run_command ).with( /git commit .+1012/, any_args )
      subject.do_fetch_action
    end

    it "calls unstash_local_changes with true if changes were stashed" do
      allow( subject ).to receive( :stash_local_changes ).and_return( true )
      expect( subject ).to receive( :unstash_local_changes ).with( true ).once
      subject.do_fetch_action
    end

    it "calls unstash_local_changes with false if no changes were stashed" do
      allow( subject ).to receive( :stash_local_changes ).and_return( false )
      expect( subject ).to receive( :unstash_local_changes ).with( false ).once
      subject.do_fetch_action
    end
  end

  describe "#do_rebase_action" do
    it "calls stash_local_changes" do
      expect( subject ).to receive( :stash_local_changes ).once
      subject.do_rebase_action
    end

    it "calls unstash_local_changes with true if changes were stashed" do
      allow( subject ).to receive( :stash_local_changes ).and_return( true )
      expect( subject ).to receive( :unstash_local_changes ).with( true ).once
      subject.do_rebase_action
    end

    it "calls unstash_local_changes with false if no changes were stashed" do
      allow( subject ).to receive( :stash_local_changes ).and_return( false )
      expect( subject ).to receive( :unstash_local_changes ).with( false ).once
      subject.do_rebase_action
    end

    it "calls rebase command with the mirror branch" do
      allow( subject ).to receive( :get_mirror_branch ).and_return( 'testbranch' )
      expect( runner_spy ).to receive( :run_command ).with( /git rebase .+testbranch/, any_args )
      subject.do_rebase_action
    end
  end

  describe "#do_pull_action" do
    it "calls fetch action" do
      expect( subject ).to receive( :do_fetch_action ).once
      subject.do_pull_action
    end

    it "calls rebase action" do
      expect( subject ).to receive( :do_rebase_action ).once
      subject.do_pull_action
    end
  end

  describe "#do_commit_action" do
    before do
      allow( subject ).to receive( :get_local_branch ).and_return( 'testbranch' )
      allow( subject ).to receive( :yes? ).and_return( 'y' )
    end

    it "calls the readd action" do
      expect( subject ).to receive( :do_readd_action ).once
      subject.do_commit_action
    end

    it "runs a commit if the local branch is not master" do
      expect( runner_spy ).to receive( :run_command ).with( /svn commit/, any_args )
      subject.do_commit_action
    end

    it "does not run a commit if the local branch is master" do
      allow( subject ).to receive( :get_local_branch ).and_return( 'master' )
      expect( runner_spy ).not_to receive( :run_command ).with( /svn commit/, any_args )
      subject.do_commit_action
    end

    it "does not run a commit if there are git changes pending" do
      allow( subject ).to receive( :are_there_git_changes? ).and_return( true )
      expect( runner_spy ).not_to receive( :run_command ).with( /svn commit/, any_args )
      expect { subject.do_commit_action }.to raise_error
    end

    it "does not run a commit if there are no svn changes" do
      allow( subject ).to receive( :run_command ).and_return( '' )
      allow( subject ).to receive( :run_command ).with( /svn diff/, any_args ).and_return( '' )
      expect( runner_spy ).not_to receive( :run_command ).with( /svn commit/, any_args )
      expect { subject.do_commit_action }.to raise_error
    end

    it "calls delete_committed_branch" do
      expect( subject ).to receive( :delete_committed_branch ).once
      subject.do_commit_action
    end

    it "calls the fetch action" do
      expect( subject ).to receive( :do_fetch_action ).once
      subject.do_commit_action
    end
  end

  describe "#do_readd_action" do
    before do
      allow( subject ).to receive( :yes? ).and_return( 'y' )
      allow( subject ).to receive( :run_command ).and_return( '' )
      allow( subject ).to receive( :run_command ).with( /svn status/, any_args ).and_return( svn_status_output )
    end

    it "does not run svn add if there are no git files unknown to svn" do
      allow( subject ).to receive( :is_file_in_git? ).and_return( false )
      expect( subject ).not_to receive( :run_command ).with( /svn add/, any_args )
      subject.do_readd_action
    end

    it "runs svn add if there are git files unknown to svn" do
      allow( subject ).to receive( :is_file_in_git? ).and_return( true )
      expect( subject ).to receive( :run_command ).with( /svn add.+whatever/, any_args )
      subject.do_readd_action
    end

    it "includes the correct files in the svn add command" do
      allow( subject ).to receive( :is_file_in_git? ).and_return( false )
      allow( subject ).to receive( :is_file_in_git? ).with( 'whatever' ).and_return( true )
      expect( subject ).to receive( :run_command ).with( /svn add.+whatever/, any_args )
      subject.do_readd_action
    end

    it "does not include the incorrect files in the svn add command" do
      allow( subject ).to receive( :is_file_in_git? ).and_return( true )
      allow( subject ).to receive( :is_file_in_git? ).with( 'whatever' ).and_return( false )
      expect( subject ).not_to receive( :run_command ).with( /svn add.+something/, any_args )
      subject.do_readd_action
    end
  end

  describe "#do_init_action" do
    before do
      allow( subject ).to receive( :create_file )
      allow( subject ).to receive( :append_to_file )
      allow( subject ).to receive( :yes? ).and_return( 'y' )
      allow( subject ).to receive( :run_command ).and_return( '' )
    end

    it "raises an error if not in an svn repo" do
      allow( subject ).to receive( :did_last_command_succeed? ).and_return( false )
      expect { subject.do_init_action }.to raise_error
    end

    it "runs an svn update" do
      expect( subject ).to receive( :run_command ).with( /svn up/, any_args )
      subject.do_init_action
    end

    it "calls create_git_repository" do
      expect( subject ).to receive( :create_git_repository ).once
      subject.do_init_action
    end

    it "calls create_gitignore" do
      expect( subject ).to receive( :create_gitignore ).once
      subject.do_init_action
    end

    it "calls create_mirror_branch" do
      expect( subject ).to receive( :create_mirror_branch ).once
      subject.do_init_action
    end

    it "runs git commit with the initial commit message" do
      allow( subject ).to receive( :get_svn_revision ).and_return( '1012' )
      expect( subject ).to receive( :run_command ).with( /git commit.+1012/, any_args )
      subject.do_init_action
    end
  end

end


