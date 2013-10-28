# Git::Si

Git Svn Interface: a simple git extention to use git locally with a remote svn repo. It's like a simple version of git-svn which doesn't keep track of history locally.

## Installation

    $ gem install git-si

## Usage

    Commands:
    git-si add [FILES]     # Perform an svn and a git add on the files.
    git-si diff [FILES]    # Perform an svn diff piped through a colorizer. Also tests to be sure a rebase is not needed.
    git-si fetch           # Updates mirror branch to latest svn commit.
    git-si help [COMMAND]  # Describe available commands or one specific command
    git-si pull            # Fetch the latest svn commit and rebase the current branch.
    git-si rebase          # Rebases current branch to mirror branch.
    git-si status [FILES]  # Perform an svn status.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
