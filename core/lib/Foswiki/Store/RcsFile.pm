# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Store::RcsFile

This class is PACKAGE PRIVATE to Store, and should never be
used from anywhere else. It is the base class of implementations of stores
that manipulate RCS format files.

The general contract of the methods on this class and its subclasses
calls for errors to be signalled by Error::Simple exceptions.

Refer to Store.pm for models of usage.

=cut

package Foswiki::Store::RcsFile;

use strict;
use warnings;
use Assert;

require File::Copy;
require File::Spec;
require File::Path;

require Foswiki::Store;
require Foswiki::Sandbox;

=begin TML

---++ ClassMethod new($session, $web, $topic, $attachment)

Constructor. There is one object per stored file.

Note that $web, $topic and $attachment must be untainted!

=cut

sub new {
    my ( $class, $session, $web, $topic, $attachment ) = @_;
    my $this = bless( { session => $session }, $class );

    # Normalise web path (replace [./]+ with /)
    $web =~ tr#/.#/#s if $web;

    $this->{web} = $web;

    if ($topic) {

        $this->{topic} = $topic;

        if ($attachment) {
            $this->{attachment} = $attachment;

            $this->{file} =
                $Foswiki::cfg{PubDir} . '/' 
              . $web . '/' 
              . $topic . '/'
              . $attachment;
            $this->{rcsFile} = $this->{file} . ',v';

        }
        else {
            $this->{file} =
              $Foswiki::cfg{DataDir} . '/' . $web . '/' . $topic . '.txt';
            $this->{rcsFile} = $this->{file} . ',v';
        }
    }

    # Default to remembering changes for a month
    $Foswiki::cfg{Store}{RememberChangesFor} ||= 31 * 24 * 60 * 60;

    return $this;
}

=begin TML

---++ ObjectMethod finish()
Break circular references.

=cut

# Note to developers; please undef *all* fields in the object explicitly,
# whether they are references or not. That way this method is "golden
# documentation" of the live fields in the object.
sub finish {
    my $this = shift;
    undef $this->{file};
    undef $this->{rcsFile};
    undef $this->{web};
    undef $this->{topic};
    undef $this->{attachment};
    undef $this->{searchFn};
    undef $this->{session};

    return;
}

# Used in subclasses for late initialisation during object creation
# (after the object is blessed into the subclass)
sub init {
    my $this = shift;

    return unless $this->{topic};

    unless ( -e $this->{file} ) {
        if ( $this->{attachment} && !$this->isAsciiDefault() ) {
            $this->initBinary();
        }
        else {
            $this->initText();
        }
    }

    return;
}

# Make any missing paths on the way to this file
sub mkPathTo {

    my $file = shift;
    ASSERT(UNTAINTED($file)) if DEBUG;

    my ( $volume, $path, undef ) = File::Spec->splitpath( $file );
    $path = File::Spec->catpath( $volume, $path, '' );

    eval { File::Path::mkpath( $path, 0, $Foswiki::cfg{RCS}{dirPermission} ); };
    if ($@) {
        throw Error::Simple("RCS: failed to create ${path}: $!");
    }

    return;
}

# SMELL: this should use Foswiki::Time
sub _epochToRcsDateTime {
    my ($dateTime) = @_;

    # TODO: should this be gmtime or local time?
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday ) =
      gmtime($dateTime);
    $year += 1900 if ( $year > 99 );
    my $rcsDateTime = sprintf '%d.%02d.%02d.%02d.%02d.%02d',
      ( $year, $mon + 1, $mday, $hour, $min, $sec );
    return $rcsDateTime;
}

# filenames for lock and lease files
sub _controlFileName {
    my ( $this, $type ) = @_;

    my $fn = $this->{file} || '';
    $fn =~ s/txt$/$type/;
    return $fn;
}

=begin TML

---++ ObjectMethod getRevisionInfo($version) -> ($rev, $date, $user, $comment)

   * =$version= if 0 or undef, or out of range (version number > number of revs) will return info about the latest revision.

Returns (rev, date, user, comment) where rev is the number of the rev for which the info was recovered, date is the date of that rev (epoch s), user is the login name of the user who saved that rev, and comment is the comment associated with the rev.

Designed to be overridden by subclasses, which can call up to this method
if file-based rev info is required.

=cut

sub getRevisionInfo {
    my ($this) = @_;
    my $fileDate = $this->getTimestamp();
    return (
        1,
        $fileDate,
        $this->{session}->{users}
          ->getCanonicalUserID( $Foswiki::cfg{DefaultUserLogin} ),
        'Default revision information'
    );
}

=begin TML

---++ ObjectMethod getLatestRevision() -> $text

Get the text of the most recent revision

=cut

sub getLatestRevision {
    my $this = shift;
    return readFile( $this, $this->{file} );
}

=begin TML

---++ ObjectMethod getLatestRevisionTime() -> $text

Get the time of the most recent revision

=cut

sub getLatestRevisionTime {
    my @e = stat( shift->{file} );
    return $e[9] || 0;
}

=begin TML

---+++ ObjectMethod getWorkArea( $key ) -> $directorypath

Gets a private directory uniquely identified by $key. The directory is
intended as a work area for plugins.

The standard is a directory named the same as "key" under
$Foswiki::cfg{WorkingDir}/work_areas

=cut

sub getWorkArea {
    my ( $this, $key ) = @_;

    # untaint and detect nasties
    $key = Foswiki::Sandbox::normalizeFileName($key);
    throw Error::Simple("Bad work area name $key") unless ($key);

    my $dir = "$Foswiki::cfg{WorkingDir}/work_areas/$key";

    unless ( -d $dir ) {
        mkdir($dir) || throw Error::Simple(<<ERROR);
Failed to create $key work area. Check your setting of {RCS}{WorkAreaDir}
in =configure=.
ERROR
    }
    return $dir;
}

=begin TML

---++ ObjectMethod getTopicNames() -> @topics

Get list of all topics in a web
   * =$web= - Web name, required, e.g. ='Sandbox'=
Return a topic list, e.g. =( 'WebChanges',  'WebHome', 'WebIndex', 'WebNotify' )=

=cut

sub getTopicNames {
    my $this = shift;

    opendir my $DIR, $Foswiki::cfg{DataDir} . '/' . $this->{web};

    my @topicList;
    foreach my $f (readdir($DIR)) {
        # Validate and untaint
        next unless $f =~ /^(.*)\.txt$/;
        $f = $1;
        # Second parameter allows non-wiki-word topic names
        if ( Foswiki::isValidTopicName($f, 1)) {
            push(@topicList, $1);
        }
    }
    closedir($DIR);
    return sort @topicList;
}

=begin TML

---++ ObjectMethod getWebNames() -> @webs

Gets a list of names of subwebs in the current web

=cut

sub getWebNames {
    my $this = shift;
    my $dir  = $Foswiki::cfg{DataDir} . '/' . $this->{web};
    if ( opendir( my $DIR, $dir ) ) {
        my @list;
        foreach my $web (readdir($DIR)) {
            # Second parameter validates hidden web names
            if ( Foswiki::isValidWebName($web, 1)
                && -d $dir . '/' . $web ) {
                $web =~ /^(.*)$/; # untaint validated web name
                push(@list, $1);
            }
        }
        closedir($DIR);
        return sort @list;
    }
    return ();
}

=begin TML

---++ ObjectMethod searchInWebContent($searchString, $web, \@topics, \%options ) -> \%map

Search for a string in the content of a web. The search must be over all
content and all formatted meta-data, though the latter search type is
deprecated (use searchMetaData instead).

   * =$searchString= - the search string, in egrep format if regex
   * =$web= - The web to search in
   * =\@topics= - reference to a list of topics to search
   * =\%options= - reference to an options hash
The =\%options= hash may contain the following options:
   * =type= - if =regex= will perform a egrep-syntax RE search (default '')
   * =casesensitive= - false to ignore case (defaulkt true)
   * =files_without_match= - true to return files only (default false)

The return value is a reference to a hash which maps each matching topic
name to a list of the lines in that topic that matched the search,
as would be returned by 'grep'. If =files_without_match= is specified, it will
return on the first match in each topic (i.e. it will return only one
match per topic, and will not return matching lines).

=cut

sub searchInWebContent {
    my ( $this, $searchString, $topics, $options ) = @_;
    ASSERT( defined $options ) if DEBUG;
    my $sDir = $Foswiki::cfg{DataDir} . '/' . $this->{web} . '/';

    unless ( $this->{searchFn} ) {
        eval "require $Foswiki::cfg{RCS}{SearchAlgorithm}";
        die
"Bad {RCS}{SearchAlgorithm}; suggest you run configure and select a different algorithm\n$@"
          if $@;
        $this->{searchFn} = $Foswiki::cfg{RCS}{SearchAlgorithm} . '::search';
    }

    no strict 'refs';
    return &{ $this->{searchFn} }(
        # the undef was previously the sandbox
        $searchString, $topics, $options, $sDir, undef, $this->{web}
    );
    use strict 'refs';
}

=begin TML

---++ ObjectMethod searchInWebMetaData($query, \@topics) -> \%matches

Search for a meta-data expression in the content of a web. =$query= must be a =Foswiki::Query= object.

Returns a reference to a hash that maps the names of topics that all matched
to the result of the query expression (e.g. if the query expression is
'TOPICPARENT.name' then you will get back a hash that maps topic names
to their parent.

SMELL: this is *really* inefficient!

=cut

sub searchInWebMetaData {
    my ( $this, $query, $topics ) = @_;

    my $store = $this->{session}->{store};

    unless ( $this->{queryFn} ) {
        eval "require $Foswiki::cfg{RCS}{QueryAlgorithm}";
        die
"Bad {RCS}{QueryAlgorithm}; suggest you run configure and select a different algorithm\n$@"
          if $@;
        $this->{queryFn} = $Foswiki::cfg{RCS}{QueryAlgorithm} . '::query';
    }

    no strict 'refs';
    return &{ $this->{queryFn} }( $query, $this->{web}, $topics, $store );
    use strict 'refs';
}

=begin TML

---++ ObjectMethod moveWeb(  $newWeb )

Move a web.

=cut

sub moveWeb {
    my ( $this, $newWeb ) = @_;
    _moveFile(
        $Foswiki::cfg{DataDir} . '/' . $this->{web},
        $Foswiki::cfg{DataDir} . '/' . $newWeb
    );
    if ( -d $Foswiki::cfg{PubDir} . '/' . $this->{web} ) {
        _moveFile(
            $Foswiki::cfg{PubDir} . '/' . $this->{web},
            $Foswiki::cfg{PubDir} . '/' . $newWeb
        );
    }

    return;
}

=begin TML

---++ ObjectMethod getRevision($version) -> $text

   * =$version= if 0 or undef, or out of range (version number > number of revs) will return the latest revision.

Get the text of the given revision.

Designed to be overridden by subclasses, which can call up to this method
if the main file revision is required.

=cut

sub getRevision {
    my $this = shift;
    ASSERT( defined($this->{file}) ) if DEBUG;

    return readFile( $this, $this->{file} );
}

=begin TML

---++ ObjectMethod storedDataExists() -> $boolean

Establishes if there is stored data associated with this handler.

=cut

sub storedDataExists {
    my $this = shift;
    ASSERT( defined($this->{file}) ) if DEBUG;
    
    return -e $this->{file};
}

=begin TML

---++ ObjectMethod getTimestamp() -> $integer

Get the timestamp of the file
Returns 0 if no file, otherwise epoch seconds

=cut

sub getTimestamp {
    my ($this) = @_;
    my $date = 0;
    if ( -e $this->{file} ) {

        # SMELL: Why big number if fail?
        $date = ( stat $this->{file} )[9] || 600000000;
    }
    return $date;
}

=begin TML

---++ ObjectMethod restoreLatestRevision( $user )

Restore the plaintext file from the revision at the head.

=cut

sub restoreLatestRevision {
    my ( $this, $user ) = @_;

    my $rev  = $this->numRevisions();
    my $text = $this->getRevision($rev);

    # If there is no ,v, create it
    unless ( -e $this->{rcsFile} ) {
        $this->addRevisionFromText( $text, "restored", $user, time() );
    }
    else {
        saveFile( $this, $this->{file}, $text );
    }

    return;
}

=begin TML

---++ ObjectMethod removeWeb( $web )

   * =$web= - web being removed

Destroy a web, utterly. Removed the data and attachments in the web.

Use with great care! No backup is taken!

=cut

sub removeWeb {
    my $this = shift;

    # Just make sure of the context
    ASSERT( !$this->{topic} ) if DEBUG;

    _rmtree( $Foswiki::cfg{DataDir} . '/' . $this->{web} );
    _rmtree( $Foswiki::cfg{PubDir} . '/' . $this->{web} );

    return;
}

=begin TML

---++ ObjectMethod moveTopic( $newWeb, $newTopic )

Move/rename a topic.

=cut

sub moveTopic {
    my ( $this, $newWeb, $newTopic ) = @_;

    my $oldWeb   = $this->{web};
    my $oldTopic = $this->{topic};

    # Move data file
    my $new =
      new Foswiki::Store::RcsFile( $this->{session}, $newWeb, $newTopic, '' );
    _moveFile( $this->{file}, $new->{file} );

    # Move history
    mkPathTo( $new->{rcsFile} );
    if ( -e $this->{rcsFile} ) {
        _moveFile( $this->{rcsFile}, $new->{rcsFile} );
    }

    # Move attachments
    my $from = $Foswiki::cfg{PubDir} . '/' . $this->{web} . '/' . $this->{topic};
    if ( -e $from ) {
        my $to = $Foswiki::cfg{PubDir} . '/' . $newWeb . '/' . $newTopic;
        _moveFile( $from, $to );
    }

    return;
}

=begin TML

---++ ObjectMethod copyTopic( $newWeb, $newTopic )

Copy a topic.

=cut

sub copyTopic {
    my ( $this, $newWeb, $newTopic ) = @_;

    my $oldWeb   = $this->{web};
    my $oldTopic = $this->{topic};

    my $new =
      new Foswiki::Store::RcsFile( $this->{session}, $newWeb, $newTopic, '' );

    _copyFile( $this->{file}, $new->{file} );
    if ( -e $this->{rcsFile} ) {
        _copyFile( $this->{rcsFile}, $new->{rcsFile} );
    }

    if (
        opendir(
            my $DIR,
            $Foswiki::cfg{PubDir} . '/' . $this->{web} . '/' . $this->{topic}
        )
      )
    {
        foreach my $att ( readdir $DIR ) {
            next if $att =~ /^\./;
            # Read from attachment store, can assume valid
            $att = Foswiki::Sandbox::untaintUnchecked($att);
            my $oldAtt =
              new Foswiki::Store::RcsFile( $this->{session}, $this->{web},
                $this->{topic}, $att );
            $oldAtt->copyAttachment( $newWeb, $newTopic );
        }

        closedir $DIR;
    }

    return;
}

=begin TML

---++ ObjectMethod moveAttachment( $newWeb, $newTopic, $newAttachment )

Move an attachment from one topic to another. The name is retained.

=cut

sub moveAttachment {
    my ( $this, $newWeb, $newTopic, $newAttachment ) = @_;

    # FIXME might want to delete old directories if empty
    my $new =
      Foswiki::Store::RcsFile->new( $this->{session}, $newWeb, $newTopic,
        $newAttachment );

    _moveFile( $this->{file}, $new->{file} );

    if ( -e $this->{rcsFile} ) {
        _moveFile( $this->{rcsFile}, $new->{rcsFile} );
    }

    return;
}

=begin TML

---++ ObjectMethod copyAttachment( $newWeb, $newTopic )

Copy an attachment from one topic to another. The name is retained.

=cut

sub copyAttachment {
    my ( $this, $newWeb, $newTopic ) = @_;

    my $oldWeb     = $this->{web};
    my $oldTopic   = $this->{topic};
    my $attachment = $this->{attachment};

    my $new =
      Foswiki::Store::RcsFile->new( $this->{session}, $newWeb, $newTopic,
        $attachment );

    _copyFile( $this->{file}, $new->{file} );

    if ( -e $this->{rcsFile} ) {
        _copyFile( $this->{rcsFile}, $new->{rcsFile} );
    }

    return;
}

=begin TML

---++ ObjectMethod isAsciiDefault (   ) -> $boolean

Check if this file type is known to be an ascii type file.

=cut

sub isAsciiDefault {
    my $this = shift;
    return ( $this->{attachment} =~ /$Foswiki::cfg{RCS}{asciiFileSuffixes}/ );
}

=begin TML

---++ ObjectMethod setLock($lock, $user)

Set a lock on the topic, if $lock, otherwise clear it.
$user is a wikiname.

SMELL: there is a tremendous amount of potential for race
conditions using this locking approach.

=cut

sub setLock {
    my ( $this, $lock, $user ) = @_;

    $user = $this->{session}->{user} unless $user;

    my $filename = _controlFileName( $this, 'lock' );
    if ($lock) {
        my $lockTime = time();
        saveFile( $this, $filename, $user . "\n" . $lockTime );
    }
    else {
        unlink $filename
          || throw Error::Simple(
            'RCS: failed to delete ' . $filename . ': ' . $! );
    }

    return;
}

=begin TML

---++ ObjectMethod isLocked( ) -> ($user, $time)

See if a twiki lock exists. Return the lock user and lock time if it does.

=cut

sub isLocked {
    my ($this) = @_;

    my $filename = _controlFileName( $this, 'lock' );
    if ( -e $filename ) {
        my $t = readFile( $this, $filename );
        return split( /\s+/, $t, 2 );
    }
    return ( undef, undef );
}

=begin TML

---++ ObjectMethod setLease( $lease )

   * =$lease= reference to lease hash, or undef if the existing lease is to be cleared.

Set an lease on the topic.

=cut

sub setLease {
    my ( $this, $lease ) = @_;

    my $filename = _controlFileName( $this, 'lease' );
    if ($lease) {
        saveFile( $this, $filename, join( "\n", %$lease ) );
    }
    elsif ( -e $filename ) {
        unlink $filename
          || throw Error::Simple(
            'RCS: failed to delete ' . $filename . ': ' . $! );
    }
    return;
}

=begin TML

---++ ObjectMethod getLease() -> $lease

Get the current lease on the topic.

=cut

sub getLease {
    my ($this) = @_;

    my $filename = _controlFileName( $this, 'lease' );
    if ( -e $filename ) {
        my $t = readFile( $this, $filename );
        my $lease = { split( /\r?\n/, $t ) };
        return $lease;
    }
    return;
}

=begin TML

---++ ObjectMethod removeSpuriousLeases( $web )

Remove leases that are not related to a topic. These can get left behind in
some store implementations when a topic is created, but never saved.

=cut

sub removeSpuriousLeases {
    my ($this) = @_;
    my $web = $Foswiki::cfg{DataDir} . '/' . $this->{web} . '/';
    my $W;
    if ( opendir( $W, $web ) ) {
        foreach my $f ( readdir($W) ) {
            # Validate, untaint, and unlink
            if ( $f =~ /^(.*)\.lease$/ ) {
                if ( !-e "$1.txt,v" ) {
                    unlink("$1.lease");
                }
            }
        }
        closedir($W);
    }
    return;
}

sub saveStream {
    my ( $this, $fh ) = @_;

    ASSERT($fh) if DEBUG;

    mkPathTo( $this->{file} );
    my $F;
    open( $F, '>', $this->{file} )
      || throw Error::Simple( 'RCS: open ' . $this->{file} . ' failed: ' . $! );
    binmode($F)
      || throw Error::Simple(
        'RCS: failed to binmode ' . $this->{file} . ': ' . $! );
    my $text;
    binmode($F);

    while ( read( $fh, $text, 1024 ) ) {
        print $F $text;
    }
    close($F)
      || throw Error::Simple(
        'RCS: close ' . $this->{file} . ' failed: ' . $! );

    chmod( $Foswiki::cfg{RCS}{filePermission}, $this->{file} );

    return '';
}

sub _copyFile {
    my ( $from, $to ) = @_;

    mkPathTo($to);
    unless ( File::Copy::copy( $from, $to ) ) {
        throw Error::Simple(
            'RCS: copy ' . $from . ' to ' . $to . ' failed: ' . $! );
    }

    return;
}

sub _moveFile {
    my ( $from, $to ) = @_;

    mkPathTo($to);
    unless ( File::Copy::move( $from, $to ) ) {
        throw Error::Simple(
            'RCS: move ' . $from . ' to ' . $to . ' failed: ' . $! );
    }

    return;
}

sub saveFile {
    my ( $this, $name, $text ) = @_;

    ASSERT(UNTAINTED($name)) if DEBUG;

    mkPathTo($name);

    my $FILE;
    open( $FILE, '>', $name )
      || throw Error::Simple(
        'RCS: failed to create file ' . $name . ': ' . $! );
    binmode($FILE)
      || throw Error::Simple( 'RCS: failed to binmode ' . $name . ': ' . $! );
    print $FILE $text;
    close($FILE)
      || throw Error::Simple(
        'RCS: failed to create file ' . $name . ': ' . $! );
    return;
}

sub readFile {
    my ( $this, $name ) = @_;

    ASSERT(UNTAINTED($name)) if DEBUG;

    my $data;
    my $IN_FILE;
    if ( open( $IN_FILE, '<', $name ) ) {
        binmode($IN_FILE);
        local $/ = undef;
        $data = <$IN_FILE>;
        close($IN_FILE);
    }
    $data ||= '';
    return $data;
}

sub mkTmpFilename {
    my $tmpdir = $Foswiki::cfg{WorkingDir}.'/tmp';
    my $file = _mktemp( 'twikiAttachmentXXXXXX', $tmpdir );
    # Constructed, so known to be valid
    return Foswiki::Sandbox::untaintUnchecked(
        File::Spec->catfile( $tmpdir, $file ));
}

# Adapted from CPAN - File::MkTemp
sub _mktemp {
    my ( $template, $dir, $ext, $keepgen, $lookup );
    my ( @template, @letters );

    ASSERT( @_ == 1 || @_ == 2 || @_ == 3 ) if DEBUG;

    ( $template, $dir, $ext ) = @_;
    @template = split //, $template;

    ASSERT( $template =~ /XXXXXX$/ ) if DEBUG;

    if ($dir) {
        ASSERT( -e $dir ) if DEBUG;
    }

    @letters =
      split( //, 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ' );

    $keepgen = 1;

    while ($keepgen) {
        for ( my $i = $#template ; $i >= 0 && ( $template[$i] eq 'X' ) ; $i-- )
        {
            $template[$i] = $letters[ int( rand 52 ) ];
        }

        undef $template;

        $template = pack 'a' x @template, @template;

        $template = $template . $ext if ($ext);

        if ($dir) {
            $lookup = File::Spec->catfile( $dir, $template );
            $keepgen = 0 unless ( -e $lookup );
        }
        else {
            $keepgen = 0;
        }

        next if $keepgen == 0;
    }

    return ($template);
}

# remove a directory and all subdirectories.
sub _rmtree {
    my $root = shift;

    if ( opendir( my $D, $root ) ) {
        foreach my $entry ( readdir($D) ) {
            next if $entry =~ /^\.+$/;
            $entry = Foswiki::Sandbox::untaintUnchecked( $entry );
            $entry = $root . '/' . $entry;
            if ( -d $entry ) {
                _rmtree($entry);
            }
            elsif ( !unlink($entry) && -e $entry ) {
                if ( $Foswiki::cfg{OS} ne 'WINDOWS' ) {
                    throw Error::Simple(
                        'RCS: Failed to delete file ' . $entry . ': ' . $! );
                }
                else {

                    # Windows sometimes fails to delete files when
                    # subprocesses haven't exited yet, because the
                    # subprocess still has the file open. Live with it.
                    print STDERR 'WARNING: Failed to delete file ',
                      $entry, ": $!\n";
                }
            }
        }
        closedir($D);

        if ( !rmdir($root) ) {
            if ( $Foswiki::cfg{OS} ne 'WINDOWS' ) {
                throw Error::Simple(
                    'RCS: Failed to delete ' . $root . ': ' . $! );
            }
            else {
                print STDERR 'WARNING: Failed to delete ' . $root . ': ' . $!,
                  "\n";
            }
        }
    }
    return;
}

=begin TML

---++ ObjectMethod getStream() -> \*STREAM

Return a text stream that will supply the text stored in the topic.

=cut

sub getStream {
    my ($this) = shift;
    my $strm;
    unless ( open( $strm, '<', $this->{file} ) ) {
        throw Error::Simple(
            'RCS: stream open ' . $this->{file} . ' failed: ' . $! );
    }
    return $strm;
}

=begin TML

---++ ObjectMethod numRevisions() -> $integer

Must be provided by subclasses.

Find out how many revisions there are. If there is a problem, such
as a nonexistent file, returns 0.

*Virtual method* - must be implemented by subclasses

=cut

=begin TML

---++ ObjectMethod initBinary()

Initialise a binary file.

Must be provided by subclasses.

*Virtual method* - must be implemented by subclasses

=cut

=begin TML

---++ ObjectMethod initText()

Initialise a text file.

Must be provided by subclasses.

*Virtual method* - must be implemented by subclasses

=cut

=begin TML

---++ ObjectMethod addRevisionFromText($text, $comment, $user, $date)

Add new revision. Replace file with text.
   * =$text= of new revision
   * =$comment= checkin comment
   * =$user= is a wikiname.
   * =$date= in epoch seconds; may be ignored

*Virtual method* - must be implemented by subclasses

=begin TML

---++ ObjectMethod addRevisionFromStream($fh, $comment, $user, $date)

Add new revision. Replace file with contents of stream.
   * =$fh= filehandle for contents of new revision
   * =$comment= checkin comment
   * =$user= is a wikiname.
   * =$date= in epoch seconds; may be ignored

*Virtual method* - must be implemented by subclasses

=cut

=begin TML

---++ ObjectMethod replaceRevision($text, $comment, $user, $date)

Replace the top revision.
   * =$text= is the new revision
   * =$date= is in epoch seconds.
   * =$user= is a wikiname.
   * =$comment= is a string

*Virtual method* - must be implemented by subclasses

=cut

=begin TML

---++ ObjectMethod deleteRevision()

Delete the last revision - do nothing if there is only one revision

*Virtual method* - must be implemented by subclasses

=cut to implementation

=begin TML

---++ ObjectMethod revisionDiff (   $rev1, $rev2, $contextLines  ) -> \@diffArray

rev2 newer than rev1.
Return reference to an array of [ diffType, $right, $left ]

*Virtual method* - must be implemented by subclasses

=cut

=begin TML

---++ ObjectMethod getRevision($version) -> $text

Get the text for a given revision. The version number must be an integer.

*Virtual method* - must be implemented by subclasses

=cut

=begin TML

---++ ObjectMethod getRevisionAtTime($time) -> $rev

Get a single-digit version number for the rev that was alive at the
given epoch-secs time, or undef it none could be found.

*Virtual method* - must be implemented by subclasses

=cut

=begin TML

---++ ObjectMethod getAttachmentAttributes($web, $topic, $attachment)

returns [stat] for any given web, topic, $attachment
SMELL - should this return a hash of arbitrary attributes so that 
SMELL + attributes supported by the underlying filesystem are supported
SMELL + (eg: windows directories supporting photo "author", "dimension" fields)

=cut

sub getAttachmentAttributes {
    my ( $this, $web, $topic, $attachment ) = @_;
    ASSERT( defined $attachment ) if DEBUG;

    my $dir = dirForTopicAttachments( $web, $topic );
    my @stat = stat( $dir . "/" . $attachment );

    return @stat;
}

# as long as stat is defined, return an emulated set of attributes for that
# attachment.
sub _constructAttributesForAutoAttached {
    my ( $file, $stat ) = @_;

    my %pairs = (
        name    => $file,
        version => '',
        path    => $file,
        size    => $stat->[7],
        date    => $stat->[9],

#        user    => 'UnknownUser',  #safer _not_ to default - Foswiki will fill it in when it needs to
        comment      => '',
        attr         => '',
        autoattached => '1'
    );

    if ( $#$stat > 0 ) {
        return \%pairs;
    }
    else {
        return;
    }
}

=begin TML

---++ ObjectMethod getAttachmentList($web, $topic)

returns {} of filename => { key => value, key2 => value } for any given web, topic
Ignores files starting with _ or ending with ,v

=cut

sub getAttachmentList {
    my ( $this, $web, $topic ) = @_;
    my $dir = dirForTopicAttachments( $web, $topic );

    my %attachmentList = ();
    if ( opendir( my $DIR, $dir ) ) {
        my @files = sort grep { m/^[^\.*_]/ } readdir($DIR);
        @files = grep { !/.*,v/ } @files;
        foreach my $attachment (@files) {
            my @stat = stat( $dir . "/" . $attachment );
            $attachmentList{$attachment} =
              _constructAttributesForAutoAttached( $attachment, \@stat );
        }
        closedir($DIR);
    }
    return %attachmentList;
}

sub dirForTopicAttachments {
    my ( $web, $topic ) = @_;
    return $Foswiki::cfg{PubDir} . '/' . $web . '/' . $topic;
}

=begin TML

---++ ObjectMethod stringify()

Generate string representation for debugging

=cut

sub stringify {
    my $this = shift;
    my @reply;
    foreach my $key qw(web topic attachment file rcsFile) {
        if ( defined $this->{$key} ) {
            push( @reply, "$key=$this->{$key}" );
        }
    }
    return join( ',', @reply );
}

# Chop out recognisable path components to prevent hacking based on error
# messages
sub hidePath {
    my ( $this, $erf ) = @_;
    return $erf if DEBUG;
    $erf =~ s#.*(/\w+/\w+\.[\w,]*)$#...$1#;
    return $erf;
}

=begin TML

---++ ObjectMethod recordChange($user, $rev, $more)
Record that the file changed

=cut

sub recordChange {
    my ( $this, $user, $rev, $more ) = @_;
    $more ||= '';

    # Store wikiname in the change log
    $user = $this->{session}->{users}->getWikiName($user);

    my $file = $Foswiki::cfg{DataDir} . '/' . $this->{web} . '/.changes';

    my @changes =
      map {
        my @row = split( /\t/, $_, 5 );
        \@row
      }
      split( /[\r\n]+/, readFile( $this, $file ) );

    # Forget old stuff
    my $cutoff = time() - $Foswiki::cfg{Store}{RememberChangesFor};
    while ( scalar(@changes) && $changes[0]->[2] < $cutoff ) {
        shift(@changes);
    }

    # Add the new change to the end of the file
    push( @changes, [ $this->{topic}, $user, time(), $rev, $more ] );
    my $text = join( "\n", map { join( "\t", @$_ ); } @changes );

    saveFile( $this, $file, $text );
    return;
}

=begin TML

---++ ObjectMethod eachChange($since) -> $iterator

Return iterator over changes - see Store for details

=cut

sub eachChange {
    my ( $this, $since ) = @_;
    my $file = $Foswiki::cfg{DataDir} . '/' . $this->{web} . '/.changes';
    require Foswiki::ListIterator;

    if ( -r $file ) {

        # SMELL: could use a LineIterator to avoid reading the whole
        # file, but it hardle seems worth it.
        my @changes =
          map {

            # Create a hash for this line
            {
                topic    => $_->[0],
                user     => $_->[1],
                time     => $_->[2],
                revision => $_->[3],
                more     => $_->[4]
            };
          }
          grep {

            # Filter on time
            $_->[2] && $_->[2] >= $since
          }
          map {

            # Split line into an array
            my @row = split( /\t/, $_, 5 );
            \@row;
          }
          reverse split( /[\r\n]+/, readFile( $this, $file ) );

        return new Foswiki::ListIterator( \@changes );
    }
    else {
        my $changes = [];
        return new Foswiki::ListIterator($changes);
    }
}

=begin TML

---++ ObjectMethod checkedSysCommand($command, ...) -> $result

Executes a system command, throwing an error if a non-zero exit
code is returned.

=cut

sub checkedSysCommand {
    my $this = shift;
    my $command = shift;
    my ( $result, $exit ) = Foswiki::Sandbox->sysCommand( $command, @_ );
    if ($exit) {
        my %p = @_;
        my $params = join(' ', map { "$_=>$p{$_}" } keys %p);
        if (DEBUG) {
            # Throw a proper wobbly
            throw Error::Simple( $command . ' '.$params
                                 . ' failed: ' . $result );
        } else {
            print STDERR $command . ' ' . $params
              . ' failed: ' . $result;
            # Throw a sanitised version
            throw Error::Simple( $command . ' of '
                                   . $this->hidePath( $this->{file} )
                                     . ' failed: ' . $result );
        }
    }
    return $result;
}

1;
__DATA__
# Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008-2009 Foswiki Contributors. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 2002 John Talintyre, john.talintyre@btinternet.com
# Copyright (C) 2002-2007 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.
