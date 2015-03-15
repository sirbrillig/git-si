require "git/si/git-ignore"
require "git/si/util"

describe Git::Si::Util do
  let( :runner_spy ) { spy( 'runner_spy' ) }
  let( :test_mixin_host ) {
    Class.new do
      include Git::Si::Util

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

  let( :svn_info_output ) {
    "Path: .
Working Copy Root Path: /path/place
URL: file:///Users/path/place
Relative URL: ^/test
Repository Root: file:///Users/path/place
Repository UUID: 0101010101
Revision: 1012
Node Kind: directory
Schedule: normal
Last Changed Author: me
Last Changed Rev: 1
" }

  let( :svn_status_output ) { "Z foobar
X foobar
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

  describe "#get_command_output" do
    it "calls run_command" do
      expect( runner_spy ).to receive( :run_command ).once
      subject.get_command_output( 'test' )
    end

    it "passes :capture option to run_command" do
      expect( runner_spy ).to receive( :run_command ).with( any_args, hash_including( capture: true ) )
      subject.get_command_output( 'test' )
    end

    it "passes command to run_command" do
      expect( runner_spy ).to receive( :run_command ).with( 'test', any_args )
      subject.get_command_output( 'test' )
    end
  end

  describe "#batch_add_files_to_git" do
    it "calls run_command once for 10 filenames" do
      expect( runner_spy ).to receive( :run_command ).exactly( 1 ).times
      subject.batch_add_files_to_git( [ 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j' ] )
    end

    it "calls run_command twice for 11 filenames" do
      expect( runner_spy ).to receive( :run_command ).exactly( 2 ).times
      subject.batch_add_files_to_git( [ 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k' ] )
    end

    it "calls run_command 4 times for 3 filenames if a filename includes an error" do
      expect( runner_spy ).to receive( :run_command ).exactly( 4 ).times
      subject.batch_add_files_to_git( [ 'a', 'b', 'raise' ] )
    end
  end

  describe "#add_files_to_git" do
    it "calls run_command once for each filename" do
      expect( runner_spy ).to receive( :run_command ).exactly( 3 ).times
      subject.add_files_to_git( [ 'a', 'b', 'c' ] )
    end
  end

  describe "#get_git_si_revision" do
    it "calls git log command" do
      expect( runner_spy ).to receive( :run_command ).with( /git log/, any_args )
      subject.get_git_si_revision
    end

    it "returns the last svn revision logged in git" do
      allow( subject ).to receive( :run_command ).and_return( "git-si 0.4.0 svn update to version 1011" )
      expect( subject.get_git_si_revision ).to eq( '1011' )
    end
  end

  describe "#get_svn_revision" do
    it "calls svn info command" do
      expect( runner_spy ).to receive( :run_command ).with( /svn info/, any_args )
      subject.get_svn_revision
    end

    it "returns the current svn revision" do
      allow( subject ).to receive( :run_command ).and_return( svn_info_output )
      expect( subject.get_svn_revision ).to eq( '1012' )
    end
  end

  describe "#get_svn_root" do
    it "returns the svn root" do
      allow( subject ).to receive( :run_command ).and_return( svn_info_output )
      expect( subject.get_svn_root ).to eq( '/path/place' )
    end
  end

  describe "#get_local_branch" do
    it "returns the current branch name" do
      data = "
  MIRRORBRANCH
* master
      "
      allow( subject ).to receive( :run_command ).and_return( data )
      expect( subject.get_local_branch ).to eq( 'master' )
    end
  end

  describe "#do_revisions_differ" do
    it "returns false if last logged svn revision is equal to current svn revision" do
      allow( subject ).to receive( :run_command ).with( /svn info/, any_args ).and_return( svn_info_output )
      allow( subject ).to receive( :run_command ).with( /git log/, any_args ).and_return( "svn update to version 1012" )
      expect( subject.do_revisions_differ ).to be_falsey
    end

    it "raises an exception if last logged svn revision is less than current svn revision" do
      allow( subject ).to receive( :run_command ).with( /svn info/, any_args ).and_return( svn_info_output )
      allow( subject ).to receive( :run_command ).with( /git log/, any_args ).and_return( "svn update to version 1000" )
      expect { subject.do_revisions_differ }.to raise_error
    end

    it "returns true if last logged svn revision is greater than current svn revision (if user says not to continue)" do
      allow( subject ).to receive( :ask ).and_return( 'n' )
      allow( subject ).to receive( :run_command ).with( /svn info/, any_args ).and_return( svn_info_output )
      allow( subject ).to receive( :run_command ).with( /git log/, any_args ).and_return( "svn update to version 2000" )
      expect( subject.do_revisions_differ ).to be_truthy
    end
  end

  describe "#are_there_git_changes" do
    it "returns true if there are git changes" do
      data = "
 M test1
"
      allow( subject ).to receive( :run_command ).and_return( data )
      expect( subject.are_there_git_changes? ).to be_truthy
    end

    it "returns false if there are no git changes" do
      data = "
?? test1
"
      allow( subject ).to receive( :run_command ).and_return( data )
      expect( subject.are_there_git_changes? ).to be_falsey
    end
  end

  describe "#create_git_repository" do

    it "returns false if the repository already exists" do
      allow( subject ).to receive( :did_last_command_succeed? ).and_return( true )
      allow( File ).to receive( :exist? ).and_return( true )
      expect( subject.create_git_repository ).to be_falsey
    end

    context "when the repository does not exist" do

      before do
        allow( File ).to receive( :exist? ).and_return( false )
      end

      it "returns true" do
        expect( subject.create_git_repository ).to be_truthy
      end

      it "calls git init" do
        expect( runner_spy ).to receive( :run_command ).with( /git init/, any_args )
        subject.create_git_repository
      end

      it "calls add_all_svn_files" do
        expect( subject ).to receive( :add_all_svn_files ).once
        subject.create_git_repository
      end

    end
  end

  describe "#create_gitignore" do
    before do
      allow( subject ).to receive( :create_file )
      allow( subject ).to receive( :append_to_file )
    end

    context "when the gitignore file does not exist" do
      before do
        allow( File ).to receive( :exist? ).and_return( false )
      end

      it "creates the file" do
        expect( subject ).to receive( :create_file ).with( '.gitignore', /\*\.log/ )
        subject.create_gitignore
      end

      it "returns true" do
        expect( subject.create_gitignore ).to be_truthy
      end

      it "adds external repos to the file" do
        data = "Z foobar
X foobar
M something else
? whatever
"
        allow( subject ).to receive( :run_command ).and_return( data )
        expect( subject ).to receive( :create_file ).with( '.gitignore', /foobar/ )
        subject.create_gitignore
      end

      it "adds the file to git" do
        expect( runner_spy ).to receive( :run_command ).with( /git add \.gitignore/, any_args ).once
        subject.create_gitignore
      end
    end

    context "when the gitignore file already exists" do
      before do
        allow( File ).to receive( :exist? ).and_return( true )
      end

      context "and there are lines missing" do
        before do
          data = ['.*', '*.config']
          allow( File ).to receive( :readlines ).and_return( data )
          allow( subject ).to receive( :yes? ).and_return( 'y' )
        end

        it "adds those lines to the file" do
          expect( subject ).to receive( :append_to_file ).with( '.gitignore', /\*\.log/ )
          subject.create_gitignore
        end

        it "returns true" do
          expect( subject.create_gitignore ).to be_truthy
        end

        it "adds the file to git" do
          expect( runner_spy ).to receive( :run_command ).with( /git add \.gitignore/, any_args ).once
          subject.create_gitignore
        end
      end

      context "and all lines are present in the file" do
        before do
          data = Git::Si::GitIgnore.ignore_patterns
          allow( File ).to receive( :readlines ).and_return( data )
          allow( subject ).to receive( :yes? ).and_return( 'y' )
        end

        it "returns false" do
          expect( subject.create_gitignore ).to be_falsey
        end
      end
    end
  end

  describe "#add_all_svn_files" do
    it "adds all the svn files to git" do
      data = "file1
file2
dir1/
dir1/file3
"
      allow( subject ).to receive( :run_command ).and_return( data )
      allow( subject ).to receive( :batch_add_files_to_git )
      expect( subject ).to receive( :batch_add_files_to_git ).with( [ 'file1', 'file2', 'dir1/file3' ] )
      subject.add_all_svn_files
    end
  end

  describe "#create_mirror_branch" do
    it "does not create the mirror branch if it already exists" do
      expect( runner_spy ).not_to receive( :run_command ).with( /git branch \w+/, any_args )
      subject.create_mirror_branch
    end

    it "creates the mirror branch if it does not exist" do
      allow( subject ).to receive( :did_last_command_succeed? ).and_return( false )
      expect( runner_spy ).to receive( :run_command ).with( /git branch \w+/, any_args )
      subject.create_mirror_branch
    end
  end

  describe "#stash_local_changes" do
    it "does not call stash_command if there are no changes" do
      allow( subject ).to receive( :are_there_git_changes? ).and_return( false )
      expect( runner_spy ).not_to receive( :run_command ).with( /git stash/, any_args )
      subject.stash_local_changes
    end

    it "calls the stash_command if there are changes" do
      allow( subject ).to receive( :are_there_git_changes? ).and_return( true )
      expect( runner_spy ).to receive( :run_command ).with( /git stash/, any_args )
      subject.stash_local_changes
    end

    it "returns true if there are changes" do
      allow( subject ).to receive( :are_there_git_changes? ).and_return( true )
      expect( subject.stash_local_changes ).to eq( true )
    end

    it "returns false if there are no changes" do
      allow( subject ).to receive( :are_there_git_changes? ).and_return( false )
      expect( subject.stash_local_changes ).to eq( false )
    end
  end

  describe "#unstash_local_changes" do
    it "does not call unstash_command if there are no changes" do
      expect( runner_spy ).not_to receive( :run_command ).with( /git stash/, any_args )
      subject.unstash_local_changes( false )
    end

    it "calls the unstash_command if there are changes" do
      expect( runner_spy ).to receive( :run_command ).with( /git stash/, any_args )
      subject.unstash_local_changes( true )
    end
  end

  describe "#revert_files_to_svn_update" do
    before do
      allow( subject ).to receive( :run_command )
    end

    it "runs the revert command for all files" do
      expect( subject ).to receive( :run_command ).with( /svn revert -R \./ )
      subject.revert_files_to_svn_update( svn_update_output )
    end

    it "runs the revert command for every conflicted file in the input string" do
      expect( subject ).to receive( :run_command ).with( /svn revert/ ).exactly( 4 ).times
      subject.revert_files_to_svn_update( svn_update_output )
    end
  end

  describe "#delete_files_after_svn_update" do
    before do
      allow( subject ).to receive( :run_command )
    end

    it "runs the delete command for every deleted file in the input string" do
      expect( subject ).to receive( :run_command ).with( /git rm/ ).exactly( 2 ).times
      subject.delete_files_after_svn_update( svn_update_output )
    end
  end

  describe "#add_files_after_svn_update" do
    before do
      allow( subject ).to receive( :run_command )
    end

    it "runs the add command for every updated file in the input string" do
      expect( subject ).to receive( :batch_add_files_to_git ).with( [ 'bin/tests/importantthing', 'bin/tests/foobar', 'bin/tests/api/goobar', 'bin/tests/api/special', 'bin/tests/api/anotherfile', 'bin/tests/barfoo', 'something/newjs.js' ] )
      subject.add_files_after_svn_update( svn_update_output )
    end
  end

  describe "#delete_committed_branch" do
    before do
      allow( subject ).to receive( :do_rebase_action )
    end

    it "checks out the master branch" do
      expect( runner_spy ).to receive( :run_command ).with( /git checkout master/, any_args )
      subject.delete_committed_branch( 'foobar' )
    end

    it "rebases onto the mirror branch" do
      expect( subject ).to receive( :do_rebase_action ).once
      subject.delete_committed_branch( 'foobar' )
    end

    it "deletes the passed branch" do
      expect( runner_spy ).to receive( :run_command ).with( /git branch -D.+foobar/, any_args )
      subject.delete_committed_branch( 'foobar' )
    end
  end

  describe "#is_file_in_git?" do
    it "returns true if the file is listed by git" do
      allow( subject ).to receive( :run_command ).with( /git ls-files.+foobar/, any_args ).and_return( 'foobar' )
      expect( subject.is_file_in_git?( 'foobar' ) ).to be_truthy
    end

    it "returns false if the file is not listed by git" do
      allow( subject ).to receive( :run_command ).with( /git ls-files.+foobar/, any_args ).and_return( '' )
      expect( subject.is_file_in_git?( 'foobar' ) ).to be_falsey
    end
  end

end

