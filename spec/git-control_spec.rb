require "git/si/git-control"

describe Git::Si::GitControl do
  describe "#status_command" do
    it "returns the correct git command" do
      expected = "git status --porcelain"
      actual = Git::Si::GitControl.status_command
      expect(actual).to eq(expected)
    end

    it "includes extra arguments if specified" do
      expected = "git status --porcelain foobar"
      actual = Git::Si::GitControl.status_command( "foobar" )
      expect(actual).to eq(expected)
    end

    context "when a different binary is set" do
      before do
        Git::Si::GitControl.git_binary = "testbin"
      end

      after do
        Git::Si::GitControl.git_binary = nil
      end

      it "uses the different binary" do
        expected = "testbin status --porcelain"
        actual = Git::Si::GitControl.status_command
        expect(actual).to eq(expected)
      end
    end
  end

  describe "#are_there_changes?" do
    it "returns true if there are changes" do
      data = "
 M test1
"
      expect(Git::Si::GitControl.are_there_changes?( data )).to be_truthy
    end

    it "returns true if there are additions" do
      data = "
 A test1
"
      expect(Git::Si::GitControl.are_there_changes?( data )).to be_truthy
    end

    it "returns true if there are deletions" do
      data = "
 D test1
"
      expect(Git::Si::GitControl.are_there_changes?( data )).to be_truthy
    end

    it "returns true if there are renamed files" do
      data = "
 R test1
"
      expect(Git::Si::GitControl.are_there_changes?( data )).to be_truthy
    end

    it "returns true if there are copied files" do
      data = "
 C test1
"
      expect(Git::Si::GitControl.are_there_changes?( data )).to be_truthy
    end

    it "returns false if there are no changes" do
      data = "
?? testdir/
"
      expect(Git::Si::GitControl.are_there_changes?( data )).to be_falsey
    end
  end

  describe "#log_command" do
    it "returns the correct git command" do
      expect( Git::Si::GitControl.log_command ).to eq( "git log" )
    end

    it "includes extra arguments if specified" do
      expect( Git::Si::GitControl.log_command( "--pretty=%B" ) ).to eq( "git log --pretty=%B" )
    end

    context "when a different binary is set" do
      before do
        Git::Si::GitControl.git_binary = "testbingit"
      end

      after do
        Git::Si::GitControl.git_binary = nil
      end

      it "uses the different binary" do
        expect(Git::Si::GitControl.log_command).to eq("testbingit log")
      end
    end
  end

  describe "#parse_last_svn_revision" do
    it "returns the correct svn version number" do
      data = "
git-si svn update to version 1015

some other commit

git-si svn update to version 1014
"
      expect(Git::Si::GitControl.parse_last_svn_revision( data )).to eq( '1015' )
    end

    it "returns nil if no version number could be found" do
      expect(Git::Si::GitControl.parse_last_svn_revision( 'foobar' )).to be_nil
    end
  end

  describe "#add_command" do
    it "raises an error if no files are specified" do
      expect { Git::Si::GitControl.add_command }.to raise_error
    end

    it "returns the correct command with files" do
      expect( Git::Si::GitControl.add_command( "foobar" ) ).to eq( "git add foobar" )
    end
  end

  describe "#commit_revision_command" do
    it "raises an error if no version is specified" do
      expect { Git::Si::GitControl.commit_revision_command}.to raise_error
    end

    it "returns the correct command with the revision" do
      expect( Git::Si::GitControl.commit_revision_command( 21356 ) ).to eq( "git commit --allow-empty -am 'svn update to version 21356'" )
    end
  end

  describe "#stash_command" do
    it "returns the correct command" do
      expect(Git::Si::GitControl.stash_command).to eq( "git stash" )
    end
  end

  describe "#unstash_command" do
    it "returns the correct command" do
      expect(Git::Si::GitControl.unstash_command).to eq( "git stash pop" )
    end
  end

  describe "#rebase_command" do
    it "raises an error if no branch is specified" do
      expect { Git::Si::GitControl.rebase_command }.to raise_error
    end

    it "returns the correct command with the branch" do
      expect( Git::Si::GitControl.rebase_command( 'master' ) ).to eq( "git rebase 'master'" )
    end
  end

  describe "#create_branch_command" do
    it "returns the correct command" do
      expect(Git::Si::GitControl.create_branch_command('foo')).to eq( "git branch foo" )
    end

    it "raises an error if no branch is specified" do
      expect { Git::Si::GitControl.create_branch_command }.to raise_error
    end
  end

  describe "#delete_branch_command" do
    it "returns the correct command" do
      expect(Git::Si::GitControl.delete_branch_command('foo')).to eq( "git branch -D foo" )
    end

    it "raises an error if no branch is specified" do
      expect { Git::Si::GitControl.delete_branch_command}.to raise_error
    end
  end

  describe "#branch_command" do
    it "returns the correct command" do
      expect(Git::Si::GitControl.branch_command).to eq( "git branch" )
    end
  end

  describe "#parse_current_branch" do
    it "returns the correct branch" do
      data = "
  MIRRORBRANCH
* master
"
      expect(Git::Si::GitControl.parse_current_branch( data )).to eq( 'master' )
    end

    it "returns nil if no branch could be found" do
      expect(Git::Si::GitControl.parse_current_branch( 'foobar' )).to be_nil
    end
  end

  describe "#checkout_command" do
    it "raises an error if no branch is specified" do
      expect { Git::Si::GitControl.checkout_command}.to raise_error
    end

    it "returns the correct command with the branch" do
      expect( Git::Si::GitControl.checkout_command( 'master' ) ).to eq( "git checkout master" )
    end
  end

  describe "#hard_reset_command" do
    it "returns the correct command" do
      expect(Git::Si::GitControl.hard_reset_command).to eq( "git reset --hard HEAD" )
    end
  end

  describe "#list_file_command" do
    it "raises an error if no filename is specified" do
      expect { Git::Si::GitControl.list_file_command}.to raise_error
    end

    it "returns the correct command" do
      expect(Git::Si::GitControl.list_file_command('foobar')).to eq( "git ls-files foobar" )
    end
  end
end
