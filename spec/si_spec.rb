require "git/si/version"
require "git/si/svn-control"
require "git/si/git-control"
require "git/si/output"

describe Git::Si::Version do
  describe "#version" do
    it "returns the correct version" do
      version_string = Git::Si::VERSION
      expect(Git::Si::Version.version).to eq(version_string)
    end
  end

  describe "#version_string" do
    it "returns the correct version string" do
      version_string = "git-si version #{Git::Si::VERSION}"
      expect(Git::Si::Version.version_string).to eq(version_string)
    end
  end
end

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
end

describe Git::Si::Output do
  describe "#svn_status" do
    context "with typical output" do
      output = "Z foobar
X foobar
M foobar.git
M foobar.swp
M barfoo
A something
D something else
? whatever
"

      it "excludes lines beginning with 'X'" do
        expected = /X foobar/
        actual = Git::Si::Output.svn_status(output)
        expect(actual).to_not match(expected)
      end

      it "excludes lines ending with '.git'" do
        expected = /foobar\.git/
        actual = Git::Si::Output.svn_status(output)
        expect(actual).to_not match(expected)
      end

      it "excludes lines ending with '.swp'" do
        expected = /foobar\.swp/
        actual = Git::Si::Output.svn_status(output)
        expect(actual).to_not match(expected)
      end

      it "includes lines starting with 'M'" do
        expected = /M barfoo/
        actual = Git::Si::Output.svn_status(output)
        expect(actual).to match(expected)
      end

      it "includes lines starting with 'A'" do
        expected = /A something/
        actual = Git::Si::Output.svn_status(output)
        expect(actual).to match(expected)
      end

      it "includes lines starting with '?'" do
        expected = /\? whatever/
        actual = Git::Si::Output.svn_status(output)
        expect(actual).to match(expected)
      end
    end
  end
end
