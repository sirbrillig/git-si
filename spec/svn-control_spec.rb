require "git/si/svn-control"

describe Git::Si::SvnControl do
  describe "#status_command" do
    it "returns the correct svn command" do
      expected = "svn status --ignore-externals"
      actual = Git::Si::SvnControl.status_command
      expect(actual).to eq(expected)
    end

    it "includes extra arguments if specified" do
      expected = "svn status --ignore-externals --verbose"
      actual = Git::Si::SvnControl.status_command( "--verbose" )
      expect(actual).to eq(expected)
    end

    context "when a different binary is set" do
      before do
        Git::Si::SvnControl.svn_binary = "testbin"
      end

      after do
        Git::Si::SvnControl.svn_binary = nil
      end

      it "uses the different binary" do
        expected = "testbin status --ignore-externals"
        actual = Git::Si::SvnControl.status_command
        expect(actual).to eq(expected)
      end
    end
  end

  describe "#diff_command" do
    it "returns the correct svn command" do
      expected = "svn diff"
      actual = Git::Si::SvnControl.diff_command
      expect(actual).to eq(expected)
    end

    it "includes extra arguments if specified" do
      expected = "svn diff foobar"
      actual = Git::Si::SvnControl.diff_command( "foobar" )
      expect(actual).to eq(expected)
    end
  end

  describe "#info_command" do
    it "returns the correct svn command" do
      expected = "svn info"
      actual = Git::Si::SvnControl.info_command
      expect(actual).to eq(expected)
    end
  end

  describe "#parse_last_revision" do
    it "returns nil from incorrect data" do
      actual = Git::Si::SvnControl.parse_last_revision('foobar 12345')
      expect(actual).to be_nil
    end

    it "returns the revision number from correct data" do
      expected = "1014"
      data = "
Path: .
Working Copy Root Path: /path/place
URL: file:///Users/path/place
Relative URL: ^/test
Repository Root: file:///Users/path/place
Repository UUID: 0101010101
Revision: 1014
Node Kind: directory
Schedule: normal
Last Changed Author: me
Last Changed Rev: 1
"
      actual = Git::Si::SvnControl.parse_last_revision(data)
      expect(actual).to eq(expected)
    end
  end

  describe "#add_command" do
    it "raises an error if no files are specified" do
      expect { Git::Si::SvnControl.add_command }.to raise_error
    end

    it "returns the correct command with files" do
      expect( Git::Si::SvnControl.add_command( "foobar" ) ).to eq( "svn add foobar" )
    end
  end

  describe "#update_command" do
    it "returns the correct command" do
      expect( Git::Si::SvnControl.update_command ).to eq( "svn up --accept theirs-full --ignore-externals" )
    end
  end
end


