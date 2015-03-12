module Git
  module Si
    class Output

      def self.svn_status(status_string)
        return '' unless status_string
        output_lines = status_string.split(/\r?\n/).select do |line|
          line.strip !~ /(^X|\.git|\.swp$)/
        end
        output_lines.join("\n")
      end

      def self.parse_external_repos(status_string)
        status_string.split(/\r?\n/).collect do |line|
          line.strip.match(/^\s*X\s+(\S.+)/) do |pattern|
            pattern.to_a.compact.last
          end
        end.compact
      end

    end
  end
end

