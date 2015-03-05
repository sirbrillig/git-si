require "git/si/version"
require "git/si/svn"
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

describe Git::Si::Svn do
  describe "#status_command" do
    it "returns the correct svn command" do
      expected = "svn status --ignore-externals"
      actual = Git::Si::Svn.status_command
      expect(actual).to eq(expected)
    end

    it "includes extra arguments if specified" do
      expected = "svn status --ignore-externals --verbose"
      actual = Git::Si::Svn.status_command( "--verbose" )
      expect(actual).to eq(expected)
    end

    context "when a different binary is set" do
      before do
        Git::Si::Svn.svn_binary = "testbin"
      end

      after do
        Git::Si::Svn.svn_binary = nil
      end

      it "uses the different binary" do
        expected = "testbin status --ignore-externals"
        actual = Git::Si::Svn.status_command
        expect(actual).to eq(expected)
      end
    end
  end

  describe "#info_command" do
    it "returns the correct svn command" do
      expected = "svn info"
      actual = Git::Si::Svn.info_command
      expect(actual).to eq(expected)
    end
  end

  describe "#parse_last_revision" do
    it "returns nil from incorrect data" do
      actual = Git::Si::Svn.parse_last_revision('foobar 12345')
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
      actual = Git::Si::Svn.parse_last_revision(data)
      expect(actual).to eq(expected)
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
