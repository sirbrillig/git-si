module Git
  module Si
    class GitIgnore
      @@gitignore_patterns = [".*", "!.gitignore", ".svn", "*.sw?", ".config", "*.err", "*.pid", "*.log", "svn-commit.*", "*.orig", "node_modules"]

      def self.ignore_patterns
        @@gitignore_patterns
      end

      def self.get_missing_lines_from(lines, patterns=@@gitignore_patterns)
        patterns.reject do |pattern|
          lines.detect do |line|
            line.strip.eql? pattern.strip
          end
        end
      end

    end
  end
end



