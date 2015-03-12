module Git
  module Si
    class GitIgnore
      @@gitignore_patterns = [".*", "!.gitignore", ".svn", "*.sw?", ".config", "*.err", "*.pid", "*.log", "svn-commit.*", "*.orig", "node_modules"]

      def self.ignore_patterns
        @@gitignore_patterns
      end

    end
  end
end



