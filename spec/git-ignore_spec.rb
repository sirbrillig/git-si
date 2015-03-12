require "git/si/git-ignore"

describe Git::Si::GitIgnore do
  describe ".ignore_patterns" do
    it "allows .gitignore files" do
      expect( Git::Si::GitIgnore.ignore_patterns ).to include( '!.gitignore' )
    end
  end

  describe ".get_missing_lines_from" do
    it "returns lines not present in the passed arguments" do
      data = ["svn-commit.*", "*.orig"]
      expect( Git::Si::GitIgnore.get_missing_lines_from( data ) ).to include( '*.log' )
    end

    it "does not return lines present in the passed arguments" do
      data = ["svn-commit.*", "*.orig"]
      expect( Git::Si::GitIgnore.get_missing_lines_from( data ) ).not_to include( '*.orig' )
    end

    it "returns an empty array if all the lines are present" do
      data = Git::Si::GitIgnore.ignore_patterns
      expect( Git::Si::GitIgnore.get_missing_lines_from( data ) ).to be_empty
    end

    it "returns lines not present in the passed arguments from the passed patterns" do
      data = ["foo", "bar"]
      expect( Git::Si::GitIgnore.get_missing_lines_from( data, ['baz'] ) ).to include( 'baz' )
    end

    it "does not return lines not present in the passed arguments from the passed patterns" do
      data = ["foo", "bar"]
      expect( Git::Si::GitIgnore.get_missing_lines_from( data, ['foo'] ) ).not_to include( 'bar' )
    end
  end
end

