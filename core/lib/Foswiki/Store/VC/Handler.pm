# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Store::VC::Handler

This class is PACKAGE PRIVATE to Store::VC, and should never be
used from anywhere else. It is the base class of implementations of
individual file handler objects used with stores that manipulate
files stored in a version control system (phew!).

The general contract of the methods on this class and its subclasses
calls for errors to be signalled by Error::Simple exceptions.

There are a number of references to RCS below; however this class is
useful as a base class for handlers for all kinds of version control
systems which use files on disk.

For readers who are familiar with Foswiki version 1.0.0, this class
is analagous to =Foswiki::Store::RcsFile=.

=cut

package Foswiki::Store::VC::Handler;

use strict;
use Assert;

use IO::File       ();
use File::Copy     ();
use File::Spec     ();
use File::Path     ();

use Foswiki::Store   ();
use Foswiki::Sandbox ();

=begin TML

---++ ClassMethod new($web, $topic, $attachment)

Constructor. There is one object per stored file.

Note that $web, $topic and $attachment must be untainted!

Can also be called on
a =Foswiki::Meta object=, =new($metaObject, $attachment)=

=cut

sub new {
    my ( $class, $web, $topic, $attachment ) = @_;
    if (UNIVERSAL::isa($web, 'Foswiki::Meta')) {
        # $web refers to a meta object
        $attachment = $topic;
        $topic = $web->topic();
        $web = $web->web();
    }
    my $this = bless( {
        web => $web, topic => $topic, attachment => $attachment }, $class );

    if ( $web && $topic ) {
        my $rcsSubDir = ( $Foswiki::cfg{RCS}{useSubDir} ? '/RCS' : '' );

        if ($attachment) {
            $this->{file} =
                $Foswiki::cfg{PubDir} . '/'
              . $web . '/'
              . $this->{topic} . '/'
              . $attachment;
            $this->{rcsFile} =
                $Foswiki::cfg{PubDir} . '/'
              . $web . '/' 
              . $topic
              . $rcsSubDir . '/'
              . $attachment . ',v';

        }
        else {
            $this->{file} =
              $Foswiki::cfg{DataDir} . '/' . $web . '/' . $topic . '.txt';
            $this->{rcsFile} =
                $Foswiki::cfg{DataDir} . '/'
              . $web
              . $rcsSubDir . '/'
              . $topic
              . '.txt,v';
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
}

# Make any missing paths on the way to this file
sub mkPathTo {

    my $file = shift;

    $file = Foswiki::Sandbox::untaintUnchecked($file);

    ASSERT(File::Spec->file_name_is_absolute($file)) if DEBUG;

    my ( $volume, $path, undef ) = File::Spec->splitpath( $file );
    $path = File::Spec->catpath( $volume, $path, '' );

    eval { File::Path::mkpath( $path, 0, $Foswiki::cfg{RCS}{dirPermission} ); };
    if ($@) {
        throw Error::Simple("VC::Handler: failed to create ${path}: $!");
    }
}

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

---++ ObjectMethod getInfo($version) -> \%info

   * =$version= if 0 or undef, or out of range (version number > number of revs) will return info about the latest revision.

Returns info where version is the number of the rev for which the info was recovered, date is the date of that rev (epoch s), user is the canonical user ID of the user who saved that rev, and comment is the comment associated with the rev.

Designed to be overridden by subclasses, which can call up to this method
if file-based rev info is required.

=cut

sub getInfo {
    my ($this) = @_;
    # SMELL: this is only required for the constant
    require Foswiki::Users::BaseUserMapping;
    return {
        version => 1,
        date    => $this->getTimestamp(),
        author  => $Foswiki::Users::BaseUserMapping::DEFAULT_USER_CUID,
        comment => 'Default revision information',
    };
}

=begin TML

---++ ObjectMethod getLatestRevision() -> $text

Get the text of the most recent revision

=cut

sub getLatestRevision {
    my $this = shift;

#SMELL: why is this assumption made rather than delegating to the impl? ($this->getRevision();)
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

---++ ObjectMethod getTopicNames() -> @topics

Get list of all topics in a web
   * =$web= - Web name, required, e.g. ='Sandbox'=
Return a topic list, e.g. =( 'WebChanges',  'WebHome', 'WebIndex', 'WebNotify' )=

=cut

sub getTopicNames {
    my $this = shift;
    my $dh;
    opendir( $dh, "$Foswiki::cfg{DataDir}/$this->{web}")
      or return ();

    # the name filter is used to ensure we don't return filenames
    # that contain illegal characters as topic names.
    my @topicList =
      sort
      map { /^(.*)\.txt$/; $1; }
      grep { !/$Foswiki::cfg{NameFilter}/ && /\.txt$/ } readdir($dh);
    closedir($dh);
    return @topicList;
}

=begin TML

---++ ObjectMethod getWebNames() -> @webs

Gets a list of names of subwebs in the current web

=cut

sub getWebNames {
    my $this = shift;
    my $dir  = $Foswiki::cfg{DataDir};
    $dir .= '/' . $this->{web} if defined $this->{web};
    my @tmpList;
    my $dh;
    if ( opendir( $dh, $dir ) ) {
        @tmpList =
          map { Foswiki::Sandbox::untaintUnchecked($_) }
          grep { !/\./ && !/$Foswiki::cfg{NameFilter}/ && -d $dir . '/' . $_ }
          readdir($dh);
        closedir($dh);
    }
    return @tmpList;
}

=begin TML

---++ ObjectMethod searchInWebContent($searchString, $web, $inputTopicSet, $session, \%options ) -> \%map

Search for a string in the content of a web. The search must be over all
content and all formatted meta-data, though the latter search type is
deprecated (use queries instead).

   * =$searchString= - the search string, in egrep format if regex
   * =$web= - The web to search in
   * $inputTopicSet is a reference to an iterator containing a list of topic in this web,
     if set to undef, the search/query algo will create a new iterator using eachTopic() 
     and the topic and excludetopics options
   * =$session= - the Foswiki session object that provides the context of this
     search
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
    my ( $this, $searchString, $web, $inputTopicSet, $session, $options ) = @_;
    ASSERT( defined $options ) if DEBUG;

    unless ( $this->{searchFn} ) {
        eval "require $Foswiki::cfg{Store}{SearchAlgorithm}";
        die <<BADALG if $@;
Bad {Store}{SearchAlgorithm}; suggest you run configure and select
a different algorithm
$@
BADALG
        $this->{searchFn} = $Foswiki::cfg{Store}{SearchAlgorithm} . '::search';
        die <<NOQUERY unless eval "defined &$this->{searchFn}";
Bad {Store}{SearchAlgorithm}; no search method. Suggest you run
configure and select a different algorithm
NOQUERY
    }

    no strict 'refs';
    return &{ $this->{searchFn} }(
        $searchString, $web, $inputTopicSet, $session, $options );
    use strict 'refs';
}

=begin TML

---++ ObjectMethod searchInWebMetaData($query, $web, $inputTopicSet, $session, \%options) -> $outputTopicSet

Search for a meta-data expression in the content of a web. =$query= must
be a =Foswiki::*::Node= object.
   * $inputTopicSet is a reference to an iterator containing a list of topic in this web,
     if set to undef, the search/query algo will create a new iterator using eachTopic() 
     and the topic and excludetopics options

Returns an Foswiki::Search::InfoCache iterator

This will become a 'query engine' factory that will allow us to plug in different
query 'types' (Sven has code for 'tag' and 'attachment' waiting for this)

TODO: needs a rename.

=cut

sub searchInWebMetaData {
    my ( $this, $query, $web, $inputTopicSet, $session, $options ) = @_;

    my $engine;
    if ( $options->{type} eq 'query' ) {
        unless ( $this->{queryFn} ) {
            eval "require $Foswiki::cfg{Store}{QueryAlgorithm}";
            die
"Bad {Store}{QueryAlgorithm}; suggest you run configure and select a different algorithm\n$@"
              if $@;
            $this->{queryFn} = $Foswiki::cfg{Store}{QueryAlgorithm} . '::query';
        }
        $engine = $this->{queryFn};
    }
    else {
        unless ( $this->{searchQueryFn} ) {
            eval "require $Foswiki::cfg{Store}{SearchAlgorithm}";
            die
"Bad {Store}{SearchAlgorithm}; suggest you run configure and select a different algorithm\n$@"
              if $@;
            $this->{searchQueryFn} =
              $Foswiki::cfg{Store}{SearchAlgorithm} . '::query';
        }
        $engine = $this->{searchQueryFn};
    }

    no strict 'refs';
    return &{$engine}( $query, $web, $inputTopicSet, $session, $options );
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
}

=begin TML

---++ ObjectMethod getRevision($version) -> $text

   * =$version= if 0 or undef, or out of range (version number > number of revs) will return the latest revision.

Get the text of the given revision.

Designed to be overridden by subclasses, which can call up to this method
if the main file revision is required.

=cut

sub getRevision {
    my ($this) = @_;
    return readFile( $this, $this->{file} );
}

=begin TML

---++ ObjectMethod storedDataExists() -> $boolean

Establishes if there is stored data associated with this handler.

=cut

sub storedDataExists {
    my $this = shift;
    return 0 unless $this->{file};
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

        # If the stat fails, stamp it with some arbitrary static
        # time in the past (00:40:05 on 5th Jan 1989)
        $date = ( stat $this->{file} )[9] || 600000000;
    }
    return $date;
}

=begin TML

---++ ObjectMethod restoreLatestRevision( $cUID )

Restore the plaintext file from the revision at the head.

=cut

sub restoreLatestRevision {
    my ( $this, $cUID ) = @_;

    my $rev  = $this->numRevisions();
    my $text = $this->getRevision($rev);

    # If there is no ,v, create it
    unless ( -e $this->{rcsFile} ) {
        $this->addRevisionFromText( $text, "restored", $cUID, time() );
    }
    else {
        saveFile( $this, $this->{file}, $text );
    }
}

=begin TML

---++ ObjectMethod remove()

Destroy, utterly. Remove the data and attachments in the web.

Use with great care! No backup is taken!

=cut

sub remove {
    my $this = shift;

    if ( !$this->{topic} ) {

        # Web
        _rmtree( $Foswiki::cfg{DataDir} . '/' . $this->{web} );
        _rmtree( $Foswiki::cfg{PubDir} . '/' . $this->{web} );
    }
    else {

        # Topic or attachment
        unlink( $this->{file} );
        unlink( $this->{rcsFile} );
        if ( !$this->{attachment} ) {
            _rmtree($Foswiki::cfg{PubDir} . '/'
                  . $this->{web} . '/'
                  . $this->{topic} );
        }
    }
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
      new Foswiki::Store::VC::Handler( $newWeb, $newTopic, '' );
    _moveFile( $this->{file}, $new->{file} );

    # Move history
    mkPathTo( $new->{rcsFile} );
    if ( -e $this->{rcsFile} ) {
        _moveFile( $this->{rcsFile}, $new->{rcsFile} );
    }

    # Move attachments
    my $from =
      $Foswiki::cfg{PubDir} . '/' . $this->{web} . '/' . $this->{topic};
    if ( -e $from ) {
        my $to = $Foswiki::cfg{PubDir} . '/' . $newWeb . '/' . $newTopic;
        _moveFile( $from, $to );
    }
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
      new Foswiki::Store::VC::Handler( $newWeb, $newTopic, '' );

    _copyFile( $this->{file}, $new->{file} );
    if ( -e $this->{rcsFile} ) {
        _copyFile( $this->{rcsFile}, $new->{rcsFile} );
    }

    my $dh;
    if (opendir( $dh, "$Foswiki::cfg{PubDir}/$this->{web}/$this->{topic}" )) {
        for my $att ( grep { !/^\./ } readdir $dh ) {
            $att = Foswiki::Sandbox::untaintUnchecked($att);
            my $oldAtt =
              new Foswiki::Store::VC::Handler(
                  $this->{web}, $this->{topic}, $att );
            $oldAtt->copyAttachment( $newWeb, $newTopic );
        }

        closedir $dh;
    }
}

=begin TML

---++ ObjectMethod moveAttachment( $newWeb, $newTopic, $newAttachment )

Move an attachment from one topic to another. The name is retained.

=cut

sub moveAttachment {
    my ( $this, $newWeb, $newTopic, $newAttachment ) = @_;

    # FIXME might want to delete old directories if empty
    my $new =
      Foswiki::Store::VC::Handler->new( $newWeb, $newTopic, $newAttachment );

    _moveFile( $this->{file}, $new->{file} );

    if ( -e $this->{rcsFile} ) {
        _moveFile( $this->{rcsFile}, $new->{rcsFile} );
    }
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
      Foswiki::Store::VC::Handler->new( $newWeb, $newTopic, $attachment );

    _copyFile( $this->{file}, $new->{file} );

    if ( -e $this->{rcsFile} ) {
        _copyFile( $this->{rcsFile}, $new->{rcsFile} );
    }
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

---++ ObjectMethod setLock($lock, $cUID)

Set a lock on the topic, if $lock, otherwise clear it.
$cUID is a cUID.

SMELL: there is a tremendous amount of potential for race
conditions using this locking approach.

It would be nice to use flock to do this, but the API is unreliable
(doesn't work on all platforms)

=cut

sub setLock {
    my ( $this, $lock, $cUID ) = @_;

    my $filename = _controlFileName( $this, 'lock' );
    if ($lock) {
        my $lockTime = time();
        saveFile( $this, $filename, $cUID . "\n" . $lockTime );
    }
    else {
        unlink $filename
          || throw Error::Simple(
            'VC::Handler: failed to delete ' . $filename . ': ' . $! );
    }
}

=begin TML

---++ ObjectMethod isLocked( ) -> ($cUID, $time)

See if a lock exists. Return the lock user and lock time if it does.

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
            'VC::Handler: failed to delete ' . $filename . ': ' . $! );
    }
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
    if ( opendir( W, $web ) ) {
        foreach my $f ( readdir(W) ) {
            if ( $f =~ /^(.*)\.lease$/ ) {
                if ( !-e "$1.txt,v" ) {
                    unlink($f);
                }
            }
        }
        closedir(W);
    }
}

sub test {
    my ( $this, $test ) = @_;
    return eval "-$test '$this->{file}'";
}

# Used by subclasses
sub saveStream {
    my ( $this, $fh ) = @_;

    ASSERT($fh) if DEBUG;

    mkPathTo( $this->{file} );
    my $F;
    open( $F, '>', $this->{file} )
      || throw Error::Simple(
        'VC::Handler: open ' . $this->{file} . ' failed: ' . $! );
    binmode($F)
      || throw Error::Simple(
        'VC::Handler: failed to binmode ' . $this->{file} . ': ' . $! );
    my $text;
    while ( read( $fh, $text, 1024 ) ) {
        print $F $text;
    }
    close($F)
      || throw Error::Simple(
        'VC::Handler: close ' . $this->{file} . ' failed: ' . $! );

    chmod( $Foswiki::cfg{RCS}{filePermission}, $this->{file} );
}

sub _copyFile {
    my ( $from, $to ) = @_;

    mkPathTo($to);
    unless ( File::Copy::copy( $from, $to ) ) {
        throw Error::Simple(
            'VC::Handler: copy ' . $from . ' to ' . $to . ' failed: ' . $! );
    }
}

sub _moveFile {
    my ( $from, $to ) = @_;
    ASSERT(-e $from) if DEBUG;
    mkPathTo($to);
    unless ( File::Copy::move( $from, $to ) ) {
        throw Error::Simple(
            'VC::Handler: move ' . $from . ' to ' . $to . ' failed: ' . $! );
    }
}

# Used by subclasses
sub saveFile {
    my ( $this, $name, $text ) = @_;

    mkPathTo($name);
    my $FILE;
    open( $FILE, '>', $name )
      || throw Error::Simple(
        'VC::Handler: failed to create file ' . $name . ': ' . $! );
    binmode($FILE)
      || throw Error::Simple(
        'VC::Handler: failed to binmode ' . $name . ': ' . $! );
    print $FILE $text;
    close($FILE)
      || throw Error::Simple(
        'VC::Handler: failed to create file ' . $name . ': ' . $! );
    return;
}

# Used by subclasses
sub readFile {
    my ( $this, $name ) = @_;
    ASSERT($name) if DEBUG;
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

# Used by subclasses
sub mkTmpFilename {
    my $tmpdir = File::Spec->tmpdir();
    my $file = _mktemp( 'foswikiAttachmentXXXXXX', $tmpdir );
    return File::Spec->catfile( $tmpdir, $file );
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
    my $D;

    if ( opendir( $D, $root ) ) {
        foreach my $entry ( grep { !/^\.+$/ } readdir($D) ) {
            $entry =~ /^(.*)$/;
            $entry = $root . '/' . $1;
            if ( -d $entry ) {
                _rmtree($entry);
            }
            elsif ( !unlink($entry) && -e $entry ) {
                if ( $Foswiki::cfg{OS} ne 'WINDOWS' ) {
                    throw Error::Simple( 'VC::Handler: Failed to delete file ' 
                          . $entry . ': '
                          . $! );
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
                    'VC::Handler: Failed to delete ' . $root . ': ' . $! );
            }
            else {
                print STDERR 'WARNING: Failed to delete ' . $root . ': ' . $!,
                  "\n";
            }
        }
    }
}

{

    # Package that ties a filehandle to a memory string for reading
    package Foswiki::Store::_MemoryFile;

    sub TIEHANDLE {
        my ( $class, $data ) = @_;
        return
          bless( { data => $data, size => length($data), ptr => 0 }, $class );
    }

    sub READ {
        my $this = shift;
        my ( undef, $len, $offset ) = @_;
        if ( $this->{size} - $this->{ptr} < $len ) {
            $len = $this->{size} - $this->{ptr};
        }
        return 0 unless $len;
        $_[0] = substr( $this->{data}, $this->{ptr}, $len );
        $this->{ptr} += $len;
        return $len;
    }

    sub READLINE {
        my $this = shift;
        return if $this->{ptr} == $this->{size};
        return substr( $this->{data}, $this->{ptr} ) if !defined $/;
        my $start = $this->{ptr};
        while ( $this->{ptr} < $this->{size}
            && substr( $this->{data}, $this->{ptr}, 1 ) ne $/ )
        {
            $this->{ptr}++;
        }
        $this->{ptr}++ if $this->{ptr} < $this->{size};
        return substr( $this->{data}, $start, $this->{ptr} - $start );
    }

    sub CLOSE {
        my $this = shift;
        $this->{data} = undef;
    }
}

=begin TML

---++ ObjectMethod openStream($mode, %opts) -> $fh

Opens a file handle onto the store. This method is primarily to
support virtual file systems.

=$mode= can be '&lt;', '&gt;' or '&gt;&gt;' for read, write, and append
respectively. %

=%opts= can take different settings depending on =$mode=.
   * =$mode='&lt;'=
      * =version= - revision of the object to open e.g. =version => 6=
        Default behaviour is to return the latest revision. Note that it is
        much more efficient to pass undef than to pass the number of the
        latest revision.
   * =$mode='&gt;'= or ='&gt;&gt;'
      * no options

=cut

sub openStream {
    my ( $this, $mode, %opts ) = @_;
    my $stream;
    if ( $mode eq '<' && $opts{version} ) {

        # Bulk load the revision and tie a filehandle
        require Symbol;
        $stream = Symbol::gensym;    # create an anonymous glob
        tie( *$stream, 'Foswiki::Store::_MemoryFile',
            $this->getRevision( $opts{version} ) );
    }
    else {
        if ( $mode =~ />/ ) {
            mkPathTo( $this->{file} );
        }
        unless ( open( $stream, $mode, $this->{file} ) ) {
            throw Error::Simple(
                'VC::Handler: stream open ' . $this->{file} . ' failed: ' . $! );
        }
    }
    return $stream;
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

---++ ObjectMethod synchroniseAttachmentsList(\@old) -> @new

Synchronise the attachment list from meta-data with what's actually
stored in the DB. Returns an ARRAY of FILEATTACHMENTs. These can be
put in the new tom.

This function is only called when the {RCS}{AutoAttachPubFiles} configuration
option is set.

=cut

# IDEA On Windows machines where the underlying filesystem can store arbitary
# meta data against files, this might replace/fulfil the COMMENT purpose
#
# TODO consider logging when things are added to metadata

sub synchroniseAttachmentsList {
    my ( $this, $attachmentsKnownInMeta ) = @_;

    my %filesListedInPub  = $this->_getAttachmentStats();
    my %filesListedInMeta = ();

    # You need the following lines if you want metadata to supplement
    # the filesystem
    if ( defined $attachmentsKnownInMeta ) {
        %filesListedInMeta =
          map { $_->{name} => $_ } @$attachmentsKnownInMeta;
    }

    foreach my $file ( keys %filesListedInPub ) {
        if ( $filesListedInMeta{$file} ) {

            # Bring forward any missing yet wanted attributes
            foreach my $field qw(comment attr user version) {
                if ( $filesListedInMeta{$file}{$field} ) {
                    $filesListedInPub{$file}{$field} =
                      $filesListedInMeta{$file}{$field};
                }
            }
        }
    }

    # A comparison of the keys of the $filesListedInMeta and %filesListedInPub
    # would show files that were in Meta but have disappeared from Pub.

    # Do not change this from array to hash, you would lose the
    # proper attachment sequence
    my @deindexedBecauseMetaDoesnotIndexAttachments = values(%filesListedInPub);

    return @deindexedBecauseMetaDoesnotIndexAttachments;
}

=begin TML

---++ ObjectMethod getAttachmentList() -> @list

Get list of attachment names actually stored for topic.

=cut

sub getAttachmentList {
    my $this = shift;
    my $dir  = "$Foswiki::cfg{PubDir}/$this->{web}/$this->{topic}";
    my $dh;
    opendir($dh, $dir) || return ();
    my @files = grep { !/^[.*_]/ && !/,v$/ } readdir($dh);
    closedir($dh);
    return @files;
}

# returns {} of filename => { key => value, key2 => value }
# for any given web, topic
sub _getAttachmentStats {
    my $this           = shift;
    my %attachmentList = ();
    my $dir            = "$Foswiki::cfg{PubDir}/$this->{web}/$this->{topic}";
    foreach my $attachment ( $this->getAttachmentList() ) {
        my @stat = stat( $dir . "/" . $attachment );
        $attachmentList{$attachment} =
          _constructAttributesForAutoAttached( $attachment, \@stat );
    }
    return %attachmentList;
}

sub _dirForTopicAttachments {
    my ( $web, $topic ) = @_;
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
    $erf =~ s#.*(/\w+/\w+\.[\w,]*)$#...$1#;
    return $erf;
}

=begin TML

---++ ObjectMethod recordChange($cUID, $rev, $more)
Record that the file changed, and who changed it

=cut

sub recordChange {
    my ( $this, $cUID, $rev, $more ) = @_;
    $more ||= '';
    ASSERT($cUID) if DEBUG;

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
    push( @changes, [ $this->{topic}, $cUID, time(), $rev, $more ] );
    my $text = join( "\n", map { join( "\t", @$_ ); } @changes );

    saveFile( $this, $file, $text );
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

        # Could use a LineIterator to avoid reading the whole
        # file, but it hardly seems worth it.
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

1;

__END__

Copyright (C) 2008-2009 Foswiki Contributors. All Rights Reserved.
Foswiki Contributors are listed in the AUTHORS file in the root of
this distribution. NOTE: Please extend that file, not this notice.

Additional copyrights apply to some of the code in this file, as follows

Copyright (C) 2002 John Talintyre, john.talintyre@btinternet.com
Copyright (C) 2001-2007 Peter Thoeny, peter@thoeny.org
Copyright (C) 2001-2008 TWiki Contributors. All Rights Reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.

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

---++ ObjectMethod addRevisionFromText($text, $comment, $cUID, $date)

Add new revision. Replace file with text.
   * =$text= of new revision
   * =$comment= checkin comment
   * =$cUID= is a cUID.
   * =$date= in epoch seconds; may be ignored

*Virtual method* - must be implemented by subclasses

=begin TML

---++ ObjectMethod addRevisionFromStream($fh, $comment, $cUID, $date)

Add new revision. Replace file with contents of stream.
   * =$fh= filehandle for contents of new revision
   * =$cUID= is a cUID.
   * =$date= in epoch seconds; may be ignored

*Virtual method* - must be implemented by subclasses

=cut

=begin TML

---++ ObjectMethod replaceRevision($text, $comment, $cUID, $date)

Replace the top revision.
   * =$text= is the new revision
   * =$date= is in epoch seconds.
   * =$cUID= is a cUID.
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
