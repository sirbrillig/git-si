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
      it "uses a different binary if one is specified" do
        expected = "testbin status --ignore-externals"
        Git::Si::Svn.svn_binary = "testbin"
        actual = Git::Si::Svn.status_command
        expect(actual).to eq(expected)
      end
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
