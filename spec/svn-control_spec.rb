require "git/si/svn-control"

describe Git::Si::SvnControl do
  let( :svn_diff_output ) {
    "Z foobar
X foobar
M foobar.git
M foobar.swp
M barfoo
A something
D something else
? whatever
" }

  let( :svn_info_output ) {
      "
Path: .
Working Copy Root Path: /path/place
URL: file:///Users/path/place
Relative URL: ^/test
Repository Root: file:///Users/path/place
Repository UUID: 0101010101
Revision: 1014
Node Kind: directory
Schedule: normal
Last Changed Author: me
Last Changed Rev: 1
" }

  let( :svn_update_output ) {
      "
Restored 'bin/tests/importantthing'
A    bin/tests/foobar
U    bin/tests/api/goobar
G    bin/tests/api/special
U    bin/tests/api/anotherfile
A    bin/tests/barfoo
?    unknownfile.md
D    byefile
   C myimage.png
D    badjs.js
   C something/javascript.js
   A something/newjs.js
C    css/_base.scss
Updated to revision 113333.
Resolved conflicted state of 'weirdthing/weird.php'
" }

  describe ".status_command" do
    it "returns the correct svn command" do
      expected = "svn status --ignore-externals"
      actual = Git::Si::SvnControl.status_command
      expect(actual).to eq(expected)
    end

    it "includes extra arguments if specified" do
      expected = "svn status --ignore-externals --verbose"
      actual = Git::Si::SvnControl.status_command( "--verbose" )
      expect(actual).to eq(expected)
    end

    context "when a different binary is set" do
      before do
        Git::Si::SvnControl.svn_binary = "testbin"
      end

      after do
        Git::Si::SvnControl.svn_binary = nil
      end

      it "uses the different binary" do
        expected = "testbin status --ignore-externals"
        actual = Git::Si::SvnControl.status_command
        expect(actual).to eq(expected)
      end
    end
  end

  describe ".diff_command" do
    it "returns the correct svn command" do
      expected = "svn diff"
      actual = Git::Si::SvnControl.diff_command
      expect(actual).to eq(expected)
    end

    it "includes extra arguments if specified" do
      expected = "svn diff foobar"
      actual = Git::Si::SvnControl.diff_command( "foobar" )
      expect(actual).to eq(expected)
    end
  end

  describe ".info_command" do
    it "returns the correct svn command" do
      expected = "svn info"
      actual = Git::Si::SvnControl.info_command
      expect(actual).to eq(expected)
    end
  end

  describe ".parse_last_revision" do
    it "returns nil from incorrect data" do
      actual = Git::Si::SvnControl.parse_last_revision('foobar 12345')
      expect(actual).to be_nil
    end

    it "returns the revision number from correct data" do
      expected = "1014"
      actual = Git::Si::SvnControl.parse_last_revision( svn_info_output )
      expect(actual).to eq(expected)
    end
  end

  describe ".add_command" do
    it "raises an error if no files are specified" do
      expect { Git::Si::SvnControl.add_command }.to raise_error
    end

    it "returns the correct command with a file" do
      expect( Git::Si::SvnControl.add_command( "foobar" ) ).to eq( "svn add foobar" )
    end

    it "returns the correct command with an array of files" do
      expect( Git::Si::SvnControl.add_command( ["foobar", "barfoo"] ) ).to eq( "svn add foobar barfoo" )
    end
  end

  describe ".update_command" do
    it "returns the correct command" do
      expect( Git::Si::SvnControl.update_command ).to eq( "svn up --accept theirs-full --ignore-externals" )
    end
  end

  describe ".parse_updated_files" do
    it "returns files that have been added" do
      expected = [
        'bin/tests/foobar',
        'bin/tests/barfoo'
      ]
      expect( Git::Si::SvnControl.parse_updated_files( svn_update_output ) ).to include( *expected )
    end

    it "returns files that have been restored" do
      expected = [
        'bin/tests/importantthing'
      ]
      expect( Git::Si::SvnControl.parse_updated_files( svn_update_output ) ).to include( *expected )
    end

    it "returns files that are updated" do
      expected = [
        'bin/tests/api/goobar',
        'bin/tests/api/special',
        'bin/tests/api/anotherfile'
      ]
      expect( Git::Si::SvnControl.parse_updated_files( svn_update_output ) ).to include( *expected )
    end

    it "returns files that are resolved conflicts" do
      expected = [
        'weirdthing/weird.php'
      ]
      expect( Git::Si::SvnControl.parse_updated_files( svn_update_output ) ).to include( *expected )
    end

    it "does not return files that are in conflict" do
      expected = [
        'myimage.png',
        'css/_base.scss',
        'something/javascript.js'
      ]
      expect( Git::Si::SvnControl.parse_updated_files( svn_update_output ) ).not_to include( *expected )
    end

    it "does not return files that are deleted" do
      expected = [
        'byefile',
        'badjs.js'
      ]
      expect( Git::Si::SvnControl.parse_updated_files( svn_update_output ) ).not_to include( *expected )
    end

    it "returns files whose properties have been updated" do
      expected = [
        'something/newjs.js'
      ]
      expect( Git::Si::SvnControl.parse_updated_files( svn_update_output ) ).to include( *expected )
    end
  end

  describe ".parse_deleted_files" do
    it "does not return files that are deleted" do
      expected = [
        'byefile',
        'badjs.js'
      ]
      expect( Git::Si::SvnControl.parse_deleted_files( svn_update_output ) ).to include( *expected )
    end
  end

  describe ".parse_conflicted_files" do
    it "returns files that are resolved conflicts" do
      expected = [
        'weirdthing/weird.php'
      ]
      expect( Git::Si::SvnControl.parse_conflicted_files( svn_update_output ) ).to include( *expected )
    end

    it "returns files which have conflicts" do
      expected = [
        'myimage.png',
        'css/_base.scss',
        'something/javascript.js'
      ]
      expect( Git::Si::SvnControl.parse_conflicted_files( svn_update_output ) ).to include( *expected )
    end
  end

  describe ".parse_unknown_files" do
    it "returns files that are not tracked" do
      expected = [
        'unknownfile.md'
      ]
      expect( Git::Si::SvnControl.parse_unknown_files( svn_update_output ) ).to include( *expected )
    end

    it "does not return files that are tracked" do
      expected = [
        'myimage.png',
        'css/_base.scss',
        'something/javascript.js'
      ]
      expect( Git::Si::SvnControl.parse_unknown_files( svn_update_output ) ).not_to include( *expected )
    end
  end

  describe ".revert_command" do
    it "returns the correct command for all files" do
      expect( Git::Si::SvnControl.revert_command ).to eq('svn revert -R .')
    end

    it "returns the correct command for some files" do
      expect( Git::Si::SvnControl.revert_command(['foobar', 'barfoo']) ).to eq('svn revert -R foobar barfoo')
    end
  end

  describe ".commit_command" do
    it "returns the correct command for all files" do
      expect( Git::Si::SvnControl.commit_command ).to eq('svn commit')
    end

    it "returns the correct command for some files" do
      expect( Git::Si::SvnControl.commit_command(['foobar', 'barfoo']) ).to eq('svn commit foobar barfoo')
    end
  end

  describe ".blame_command" do
    it "raises an error with no files" do
      expect { Git::Si::SvnControl.blame_command }.to raise_error
    end

    it "returns the correct command" do
      expect( Git::Si::SvnControl.blame_command('foobar') ).to eq( 'svn blame foobar' )
    end
  end

  describe ".parse_root_path" do
    it "raises an error with no data" do
      expect { Git::Si::SvnControl.parse_root_path }.to raise_error
    end

    it "returns the correct root path" do
      data = "
Path: .
Working Copy Root Path: /Users/foobar/git-si/testdir/test-copy
URL: file:///Users/foobar/git-si/testdir/SVNrep/test
Relative URL: ^/test
Repository Root: file:///Users/foobar/git-si/testdir/SVNrep
Repository UUID: 0101010101
Revision: 1432
"
      expect( Git::Si::SvnControl.parse_root_path(data) ).to eq( '/Users/foobar/git-si/testdir/test-copy' )
    end
  end

  describe ".list_file_command" do
    it "returns the correct command" do
      expect( Git::Si::SvnControl.list_file_command ).to eq( 'svn list -R' )
    end
  end

  describe ".parse_file_list" do
    let ( :svn_list_output ) { "
.hiddenfile
.hiddendir/
.hiddendir/regularfile.txt
myimage.png
something/
something/.subhidden/
something/.subhidden/regularfile.txt
something/javascript.js
" }

    it "returns files in the list" do
      expected = [
        'myimage.png',
        'something/javascript.js'
      ]
      expect( Git::Si::SvnControl.parse_file_list( svn_list_output ) ).to include( *expected )
    end

    it "does not return directories" do
      expected = [
        'something/'
      ]
      expect( Git::Si::SvnControl.parse_file_list( svn_list_output ) ).not_to include( *expected )
    end

    it "does not return empty strings" do
      expected = [
        '',
        ' ',
      ]
      expect( Git::Si::SvnControl.parse_file_list( svn_list_output ) ).not_to include( *expected )
    end

    it "does not return hidden files or files in hidden directories" do
      expected = [
        '.hiddenfile',
        '.hiddendir/regularfile.txt',
        'something/.subhidden/regularfile.txt'
      ]
      expect( Git::Si::SvnControl.parse_file_list( svn_list_output ) ).not_to include( *expected )
    end
  end
end


