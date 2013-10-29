# Git::Si

Git Svn Interface: a simple git extention to use git locally with a remote svn
repo. It's like a simple version of git-svn which doesn't keep track of history
locally.

## Installation

    $ gem install git-si

or locally if you don't have access to the global gem directory:

    $ gem install --user-install git-si

## Usage

To begin, enter a directory versioned by svn and run `git si init`. This will
set up git, the mirror branch, and a gitignore if you don't have one already.

Use git locally as you would normally, making branches for your features as you
like. To update your local branch with changes made on the svn server, run `git
si pull`. (If there are conflicts you can use `git mergetool` to handle them.)

Compare your local copy to the server with `git si diff`. It even colorizes and
pages the output for you!

When you are ready to push your changes to the svn server, run `git si commit`.
This will take you into your favorite editor to enter a commit message.

All commands:

    git si add [FILES]     # Perform an svn and a git add on the files.
    git si blame <FILE>    # Alias for svn blame.
    git si commit          # Perform an svn commit and update the mirror branch.
    git si diff [FILES]    # Perform an svn diff piped through a colorizer. Also tests to be sure a rebase is not needed.
    git si fetch           # Updates mirror branch to latest svn commit.
    git si help [COMMAND]  # Describe available commands or one specific command
    git si init            # Initializes git-si in this directory with a gitignore and creates a special mirror branch.
    git si pull            # Fetch the latest svn commit and rebase the current branch.
    git si rebase          # Rebases current branch to mirror branch.
    git si status [FILES]  # Perform an svn status.
    git si usage           # How does this thing work?


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
