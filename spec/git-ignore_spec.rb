require "git/si/git-ignore"

describe Git::Si::GitIgnore do
  describe ".ignore_patterns" do
    it "allows .gitignore files" do
      expect( Git::Si::GitIgnore.ignore_patterns ).to include( '!.gitignore' )
    end
  end
end

