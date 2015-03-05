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
    end

  end
end

