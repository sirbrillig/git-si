require "git/si/git-control"

describe Git::Si::GitControl do
  describe "#status_command" do
    it "returns the correct git command" do
      expected = "git status --porcelain"
      actual = Git::Si::GitControl.status_command
      expect(actual).to eq(expected)
    end

    it "includes extra arguments if specified" do
      expected = "git status --porcelain foobar"
      actual = Git::Si::GitControl.status_command( "foobar" )
      expect(actual).to eq(expected)
    end

    context "when a different binary is set" do
      before do
        Git::Si::GitControl.git_binary = "testbin"
      end

      after do
        Git::Si::GitControl.git_binary = nil
      end

      it "uses the different binary" do
        expected = "testbin status --porcelain"
        actual = Git::Si::GitControl.status_command
        expect(actual).to eq(expected)
      end
    end
  end

  describe "#are_there_changes?" do
    it "returns true if there are changes" do
      data = "
 M test1
"
      expect(Git::Si::GitControl.are_there_changes?( data )).to be_truthy
    end

    it "returns true if there are additions" do
      data = "
 A test1
"
      expect(Git::Si::GitControl.are_there_changes?( data )).to be_truthy
    end

    it "returns true if there are deletions" do
      data = "
 D test1
"
      expect(Git::Si::GitControl.are_there_changes?( data )).to be_truthy
    end

    it "returns false if there are no changes" do
      data = "
?? testdir/
"
      expect(Git::Si::GitControl.are_there_changes?( data )).to be_falsey
    end
  end

  describe "#log_command" do
    it "returns the correct git command" do
      expect( Git::Si::GitControl.log_command ).to eq( "git log" )
    end

    it "includes extra arguments if specified" do
      expect( Git::Si::GitControl.log_command( "--pretty=%B" ) ).to eq( "git log --pretty=%B" )
    end

    context "when a different binary is set" do
      before do
        Git::Si::GitControl.git_binary = "testbingit"
      end

      after do
        Git::Si::GitControl.git_binary = nil
      end

      it "uses the different binary" do
        expect(Git::Si::GitControl.log_command).to eq("testbingit log")
      end
    end
  end

  describe "#parse_last_svn_revision" do
    it "returns the correct svn version number" do
      data = "
git-si svn update to version 1015

some other commit

git-si svn update to version 1014
"
      expect(Git::Si::GitControl.parse_last_svn_revision( data )).to eq( '1015' )
    end

    it "returns nil if no version number could be found" do
      expect(Git::Si::GitControl.parse_last_svn_revision( 'foobar' )).to be_nil
    end
  end

  describe "#add_command" do
    it "raises an error if no files are specified" do
      expect { Git::Si::GitControl.add_command }.to raise_error
    end

    it "returns the correct command with files" do
      expect( Git::Si::GitControl.add_command( "foobar" ) ).to eq( "git add foobar" )
    end
  end
end
