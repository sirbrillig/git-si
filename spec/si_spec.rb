require "git/si/version"

describe Git::Si do
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
