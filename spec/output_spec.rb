require "git/si/output"

describe Git::Si::Output do
  describe ".svn_status" do
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

