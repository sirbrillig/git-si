module Git
  module Si

    class GitSiError < StandardError
    end

    class ShellError < GitSiError
    end

    class GitError < GitSiError
    end

    class SvnError < GitSiError
    end

    class VersionError < GitSiError
    end

  end
end
