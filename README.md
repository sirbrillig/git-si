# Git::Si

Git Svn Interface: a simple git extention to use git locally with a remote svn repo. It's like a simple version of git-svn which doesn't keep track of history locally.

## Installation

    $ gem install git-si

## Usage

    git lt help  # How do I use this thing?
    git lt init  # Initializes a git repository with a gitignore and creates a special mirror branch
    git lt pull  # Fetch the latest svn commit and rebase the current branch.
    git lt push  # Make an svn commit for the most recent git commit. Kind of like a squash.
    git lt add   # Add a file to the git and svn repos.
    git lt diff  # Alias for svn diff, piped through a highlighter
    git lt blame # Alias for svn blame.
    git lt commit  # Perform an svn commit and run git lt pull
    git lt status  # Alias for svn status --ignore-externals
    git lt rebase  # Rebases current branch to mirror branch
    git lt fetch   # Updates mirror branch to latest svn commit

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
