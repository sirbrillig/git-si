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
"
  }

  subject { test_mixin_host.new( runner_spy ) }

  describe "#get_command_output" do
    it "calls run_command" do
      expect( runner_spy ).to receive( :run_command ).once
      subject.get_command_output( 'test' )
    end

    it "passes :capture option to run_command" do
      expect( runner_spy ).to receive( :run_command ).with( anything, hash_including( capture: true ) )
      subject.get_command_output( 'test' )
    end

    it "passes command to run_command" do
      expect( runner_spy ).to receive( :run_command ).with( 'test', anything )
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
      expect( runner_spy ).to receive( :run_command ).with( /git log/, anything )
      subject.get_git_si_revision
    end

    it "returns the last svn revision logged in git" do
      allow( subject ).to receive( :run_command ).and_return( "git-si 0.4.0 svn update to version 1011" )
      expect( subject.get_git_si_revision ).to eq( '1011' )
    end
  end

  describe "#get_svn_revision" do
    it "calls svn info command" do
      expect( runner_spy ).to receive( :run_command ).with( /svn info/, anything )
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
      allow( subject ).to receive( :run_command ).with( /svn info/, anything ).and_return( svn_info_output )
      allow( subject ).to receive( :run_command ).with( /git log/, anything ).and_return( "svn update to version 1012" )
      expect( subject.do_revisions_differ ).to be_falsey
    end

    it "raises an exception if last logged svn revision is less than current svn revision" do
      allow( subject ).to receive( :run_command ).with( /svn info/, anything ).and_return( svn_info_output )
      allow( subject ).to receive( :run_command ).with( /git log/, anything ).and_return( "svn update to version 1000" )
      expect { subject.do_revisions_differ }.to raise_error
    end

    it "returns true if last logged svn revision is greater than current svn revision (if user says not to continue)" do
      allow( subject ).to receive( :ask ).and_return( 'n' )
      allow( subject ).to receive( :run_command ).with( /svn info/, anything ).and_return( svn_info_output )
      allow( subject ).to receive( :run_command ).with( /git log/, anything ).and_return( "svn update to version 2000" )
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
        expect( runner_spy ).to receive( :run_command ).with( /git init/, anything )
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
        expect( runner_spy ).to receive( :run_command ).with( /git add \.gitignore/, anything ).once
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
          expect( runner_spy ).to receive( :run_command ).with( /git add \.gitignore/, anything ).once
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
      expect( runner_spy ).not_to receive( :run_command ).with( /git branch \w+/, anything )
      subject.create_mirror_branch
    end

    it "creates the mirror branch if it does not exist" do
      allow( subject ).to receive( :did_last_command_succeed? ).and_return( false )
      expect( runner_spy ).to receive( :run_command ).with( /git branch \w+/, anything )
      subject.create_mirror_branch
    end
  end

end

