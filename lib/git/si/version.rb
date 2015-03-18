module Git
  module Si
    VERSION = "0.4.0"

    class Version
      def self.version
        Git::Si::VERSION
      end

      def self.version_string
        "git-si version #{Git::Si::VERSION}"
      end
    end

  end
end
