# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Store::PlainFile

Single-file implementation of =Foswiki::Store= that uses normal
files in a standard directory structure to store versions.

Webs map to directories
Topics are stored in web/topic.txt
Topic histories are in web/topic,pfv/
Attachments are in web/topic/attachment
Attachment histories are in web/topic/attachment,pfv/
Histories consist of files numbered for the revision they store
The latest rev also has a history file (note: this means that
large attachments are stored twice; same as in the RCS stores)

Note that this store is well-behaved; there is no confusion about
the TOPICINFO, which is always up-to-date.

=cut

package Foswiki::Store::PlainFile;
use strict;
use warnings;

use File::Copy ();
use File::Copy::Recursive ();
use Fcntl qw( :DEFAULT :flock SEEK_SET );

use Foswiki::Store ();
our @ISA = ('Foswiki::Store');

use Assert;
use Error qw( :try );

use Foswiki          ();
use Foswiki::Meta    ();
use Foswiki::Sandbox ();
use Foswiki::Iterator::NumberRangeIterator ();
use Foswiki::Users::BaseUserMapping ();

BEGIN {

    # Do a dynamic 'use locale' for this module
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

sub finish {
    my $this = shift;
    $this->SUPER::finish();
    undef $this->{queryObj};
    undef $this->{searchQueryObj};
}

# Implement Foswiki::Store
sub readTopic {
    my ( $this, $meta, $version ) = @_;

    _saveDamage( $meta );

    my ( $gotRev, $isLatest ) = $this->askListeners( $meta, $version );

    if ( defined($gotRev) and ( $gotRev > 0 or ($isLatest) ) ) {
        return ( $gotRev, $isLatest );
    }
    ASSERT( not $isLatest ) if DEBUG;

    $isLatest = 0;

    # check that the requested revision actually exists
    if ( defined $version && $version =~ /^\d+$/ ) {
	my $nr = _numRevisions($meta);
        $version = $nr if ( $version == 0 || $version > $nr );
    }
    else {
        undef $version;
	# if it's a non-numeric string, we need to return undef
	# "...$version is defined but refers to a version that does
	# not exist, then $rev is undef"
    }

    ( my $text, $isLatest ) = _getRevision($meta, undef, $version);

    unless ( defined $text ) {
        ASSERT( not $isLatest ) if DEBUG;
        return ( undef, $isLatest );
    }

    $text =~ s/\r//g;    # Remove carriage returns
    $meta->setEmbeddedStoreForm($text);

    $gotRev = $version;
    unless ( defined $gotRev ) {

        # First try the just-loaded for the revision.
        my $ri = $meta->get('TOPICINFO');
        $gotRev = $ri->{version} if defined $ri;
    }
    if ( !defined $gotRev ) {

        # No revision from any other source; must be latest
        $gotRev = _numRevisions( $meta );
        ASSERT( defined $gotRev ) if DEBUG;
    }

    # Add attachments that are new from reading the pub directory.
    # Only check the currently requested topic.
    if (   $Foswiki::cfg{RCS}{AutoAttachPubFiles}
        && $meta->isSessionTopic() )
    {
	$this->_autoAttach($meta);
    }

    ASSERT( defined($gotRev) ) if DEBUG;
    return ( $gotRev, $isLatest );
}

# Implement Foswiki::Store
sub moveAttachment {
    my ( $this, $oldTopicObject, $oldAttachment, $newTopicObject,
        $newAttachment, $cUID )
      = @_;

    _saveDamage( $oldTopicObject );
    _saveDamage( $newTopicObject );

    my $oldbase = _getPub( $oldTopicObject );
    if ( -e "$oldbase/$oldAttachment" ) {
	my $newbase = _getPub($newTopicObject);
	_moveFile(_latestFile($oldTopicObject, $oldAttachment),
		  _latestFile($newTopicObject, $newAttachment));
	_moveFile(_historyDir($oldTopicObject, $oldAttachment),
		  _historyDir($newTopicObject, $newAttachment));
	
        $this->tellListeners(
            verb          => 'update',
            oldmeta       => $oldTopicObject,
            oldattachment => $oldAttachment,
            newmeta       => $newTopicObject,
            newattachment => $newAttachment
        );
        _recordChange( $oldTopicObject, $cUID, 0 );
    }
}

# Implement Foswiki::Store
sub copyAttachment {
    my ( $this, $oldTopicObject, $oldAttachment, $newTopicObject,
        $newAttachment, $cUID )
      = @_;

    _saveDamage( $oldTopicObject );
    _saveDamage( $newTopicObject );

    my $oldbase = _getPub( $oldTopicObject );
    if ( -e "$oldbase/$oldAttachment" ) {
	my $newbase = _getPub($newTopicObject);
	_copyFile(_latestFile($oldTopicObject, $oldAttachment),
		  _latestFile($newTopicObject, $newAttachment));
	_copyFile(_historyDir($oldTopicObject, $oldAttachment),
		  _historyDir($newTopicObject, $newAttachment));
	
        $this->tellListeners(
            verb          => 'insert',
            newmeta       => $newTopicObject,
            newattachment => $newAttachment
        );
	_recordChange( $oldTopicObject, $cUID, 0 );
    }
}

# Implement Foswiki::Store
sub attachmentExists {
    my ( $this, $meta, $att ) = @_;
    return -e _latestFile( $meta, $att);
}

# Implement Foswiki::Store
sub moveTopic {
    my ( $this, $oldTopicObject, $newTopicObject, $cUID ) = @_;

    _saveDamage( $oldTopicObject );

    my $rev = _numRevisions( $oldTopicObject );

    _moveFile( _latestFile( $oldTopicObject),
	       _latestFile( $newTopicObject ));
    _moveFile( _historyDir( $oldTopicObject),
	       _historyDir( $newTopicObject ));
    _moveFile( _getPub( $oldTopicObject ),
	       _getPub( $newTopicObject ) );

    $this->tellListeners(
        verb    => 'update',
        oldmeta => $oldTopicObject,
        newmeta => $newTopicObject
    );

    if ( $newTopicObject->web ne $oldTopicObject->web ) {

        # Record that it was moved away
        _recordChange( $oldTopicObject, $cUID, $rev );
    }

    _recordChange( $newTopicObject, $cUID, $rev );
}

# Implement Foswiki::Store
sub moveWeb {
    my ( $this, $oldWebObject, $newWebObject, $cUID ) = @_;

    my $oldbase = _getData ($oldWebObject );
    my $newbase = _getData ($newWebObject );

    _moveFile( $oldbase, $newbase );

    $oldbase = _getPub ($oldWebObject );
    $newbase = _getPub ($newWebObject );

    _moveFile( $oldbase, $newbase );

    $this->tellListeners(
        verb    => 'update',
        oldmeta => $oldWebObject,
        newmeta => $newWebObject
    );

    # We have to log in the new web, otherwise we would re-create the dir with
    # a useless .changes. See Item9278
    _recordChange( $newWebObject, $cUID, 0, 'Moved from ' . $oldWebObject->web );
}

# Implement Foswiki::Store
sub testAttachment {
    my ( $this, $meta, $attachment, $test ) = @_;
    my $fn = _latestFile( $meta, $attachment );
    return eval "-$test '$fn'";
}

# Implement Foswiki::Store
sub openAttachment {
    my ( $this, $meta, $att, $mode, @opts ) = @_;

    _saveDamage( $meta, $att );

    return _openStream( $meta, $att, $mode, @opts );
}

# Implement Foswiki::Store
sub getRevisionHistory {
    my ( $this, $meta, $attachment ) = @_;

    my $itr = $this->askListenersRevisionHistory( $meta, $attachment );
    return $itr if defined($itr);

    unless ( -e _historyDir($meta, $attachment) ) {
	my @list = ();
	require Foswiki::ListIterator;
	if ( -e _latestFile($meta, $attachment) ) {
	    push(@list, 1);
	}
	return Foswiki::ListIterator->new( \@list );
    }

    _saveDamage( $meta );

    return Foswiki::Iterator::NumberRangeIterator->new(
	_numRevisions( $meta, $attachment ), 1 );
}

# Implement Foswiki::Store
sub getNextRevision {
    my ( $this, $meta ) = @_;

    _saveDamage( $meta );

    return _numRevisions( $meta ) + 1;
}

# Implement Foswiki::Store
sub getRevisionDiff {
    my ( $this, $meta, $rev2, $contextLines ) = @_;

    _saveDamage( $meta );

    my $rev1 = $meta->getLoadedRev();
    my @list;
    my ($text1) = _getRevision($meta, undef, $rev1);
    my ($text2) = _getRevision($meta, undef, $rev2);

    my $lNew = _split($text1);
    my $lOld = _split($text2);
    require Algorithm::Diff;
    my $diff = Algorithm::Diff::sdiff( $lNew, $lOld );

    foreach my $ele (@$diff) {
        push @list, $ele;
    }
    return \@list;
}

# Implement Foswiki::Store
sub getVersionInfo {
    my ( $this, $meta, $rev, $attachment ) = @_;

    _saveDamage( $meta, $attachment );

    my $info = $this->askListenersVersionInfo($meta, $rev, $attachment);
    unless ( $info ) {
	$info = {};
	my $df;
	my $nr = _numRevisions( $meta, $attachment );
	if ($rev && $rev > 0 && $rev < $nr) {
	    $df = _historyFile($meta, $attachment, $rev);
	} else  {
	    $df = _latestFile( $meta, $attachment );
	    $rev = $nr;
	}
	unless ($attachment) {
	    # if it's a topic, try and retrieve TOPICINFO
	    _getTOPICINFO($df, $info);
	}
	$info->{date}    = _getTimestamp($df) unless defined $info->{date};
	$info->{version} = $rev || 1 unless defined $info->{version};
	$info->{comment} = '' unless defined $info->{comment};
	$info->{author} ||= $Foswiki::Users::BaseUserMapping::UNKNOWN_USER_CUID;
    }

    return $info;
}

# Implement Foswiki::Store
sub saveAttachment {
    my ( $this, $meta, $name, $stream, $cUID, $comment ) = @_;

    _saveDamage( $meta, $name );

    my $currentRev = _numRevisions( $meta, $name );
    my $nextRev    = $currentRev + 1;
    my $verb = ( $meta->hasAttachment($name) ) ? 'update' : 'insert';

    _ci( $meta, $name, 1, $stream, $comment, $cUID );

    $this->tellListeners(
        verb          => $verb,
        newmeta       => $meta,
        newattachment => $name
    );
    _recordChange( $meta, $cUID, $nextRev );
    return $nextRev;
}

# Implement Foswiki::Store
sub saveTopic {
    my ( $this, $meta, $cUID, $options ) = @_;

    _saveDamage( $meta );

    my $verb = ( -e _latestFile( $meta ) ) ? 'update' : 'insert';

    # just in case they are not sequential
    my $nextRev = _numRevisions( $meta ) + 1;
    my $ti      = $meta->get('TOPICINFO');
    $ti->{version} = $nextRev;
    $ti->{author}  = $cUID;

    _ci( $meta, undef, 0, $meta->getEmbeddedStoreForm(),
	 'save topic', $cUID, $options->{forcedate} );

    my $extra = $options->{minor} ? 'minor' : '';
    _recordChange( $meta, $cUID, $nextRev, $extra );

    $this->tellListeners( verb => $verb, newmeta => $meta );

    return $nextRev;
}

# Implement Foswiki::Store
sub repRev {
    my ( $this, $meta, $cUID, %options ) = @_;

    my $info    = $meta->getRevisionInfo();

    _saveDamage($meta);

    my $rn = _numRevisions($meta);
    ASSERT($rn, $meta->getPath) if DEBUG;
    unlink(_historyFile($meta, undef, $rn));

    my $ti      = $meta->get('TOPICINFO');
    $ti->{version} = $rn;
    $ti->{author}  = $cUID;
    _ci( $meta, undef, 0, $meta->getEmbeddedStoreForm(),
	 'reprev', $cUID, $info->{date} );

    _recordChange( $meta, $cUID, $rn, 'minor, reprev' );

    $this->tellListeners( verb => 'update', newmeta => $meta );

    return $rn;
}

# Implement Foswiki::Store
sub delRev {
    my ( $this, $meta, $cUID ) = @_;

    _saveDamage( $meta );

    my $rev = _numRevisions($meta);
    if ( $rev <= 1 ) {
        die 'PlainFile: Cannot delete initial revision of '
	    . $meta->web . '.'
	    . $meta->topic;
    }

    my $hf = _historyFile( $meta, undef, $rev );
    unlink $hf;

    # Get the new top rev - which may or may not be -1, depending if
    # the history is complete or not
    my $cur = _numRevisions($meta);
    $hf = _historyFile( $meta, undef, $cur);
    my $thf = _latestFile( $meta );
    # Copy it up to the latest file, then refresh the time on the history
    File::Copy::copy($hf, $thf)
	or die "PlainFile: failed to copy to $thf: $!";
    utime(undef, undef, $hf) # touch
	or die "PlainFile: could not touch $hf: $!";

    # reload the topic object
    $meta->unload();
    $meta->loadVersion();

    $this->tellListeners( verb => 'update', newmeta => $meta );

    _recordChange( $meta, $cUID, $rev );

    return $rev;
}

# Implement Foswiki::Store
sub atomicLockInfo {
    my ( $this, $meta ) = @_;
    my $filename = _getData( $meta ) . '.lock';
    if ( -e $filename ) {
        my $t = _readFile( $filename );
        return split( /\s+/, $t, 2 );
    }
    return ( undef, undef );
}

# It would be nice to use flock to do this, but the API is unreliable
# (doesn't work on all platforms)
sub atomicLock {
    my ( $this, $meta, $cUID ) = @_;
    my $filename = _getData( $meta ) . '.lock';
    _saveFile( $filename, $cUID . "\n" . time );
}

# Implement Foswiki::Store
sub atomicUnlock {
    my ( $this, $meta, $cUID ) = @_;

    my $filename = _getData( $meta ) . '.lock';
    unlink $filename
	or die "PlainFile: failed to delete $filename: $!";
}

# Implement Foswiki::Store
sub webExists {
    my ( $this, $web ) = @_;

    return 0 unless defined $web;
    $web =~ s#\.#/#go;

    # Foswiki ships with TWikiCompatibilityPlugin but if it is disabled we
    # do not want the TWiki web to appear as a valid web to anyone.
    if ( $web eq 'TWiki' ) {
        unless ( exists $Foswiki::cfg{Plugins}{TWikiCompatibilityPlugin}
            && defined $Foswiki::cfg{Plugins}{TWikiCompatibilityPlugin}{Enabled}
            && $Foswiki::cfg{Plugins}{TWikiCompatibilityPlugin}{Enabled} == 1 )
        {
            return 0;
        }
    }
    return -e _latestFile( $web, $Foswiki::cfg{WebPrefsTopicName} );
}

# Implement Foswiki::Store
sub topicExists {
    my ( $this, $web, $topic ) = @_;

    return 0 unless defined $web && $web ne '';
    $web =~ s#\.#/#go;
    return 0 unless defined $topic && $topic ne '';

    return -e _latestFile($web, $topic) ||
	-e _historyDir($web, $topic);
}

# Implement Foswiki::Store
sub getApproxRevTime {
    my ( $this, $web, $topic ) = @_;

    return (stat( _latestFile($web, $topic)))[9] || 0;
}

# Implement Foswiki::Store
sub eachChange {
    my ( $this, $webObject, $since ) = @_;

    my $file = _getData( $webObject ) . '/.changes';
    require Foswiki::ListIterator;

    if ( -r $file ) {

        # Could use a LineIterator to avoid reading the whole
        # file, but it hardly seems worth it.
        my @changes =
          map {

            # Create a hash for this line
            {
                topic => Foswiki::Sandbox::untaint(
                    $_->[0], \&Foswiki::Sandbox::validateTopicName
                ),
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
          reverse split( /[\r\n]+/, _readFile( $file ) );

        return Foswiki::ListIterator->new( \@changes );
    }
    else {
        my $changes = [];
        return Foswiki::ListIterator->new($changes);
    }
}

# Implement Foswiki::Store
sub eachAttachment {
    my ( $this, $meta ) = @_;

    my $dh;
    opendir( $dh, _getPub($meta) ) or return ();
    my @list = grep { !/^[.*_]/ && !/,v$/ } readdir($dh);
    closedir($dh);

    require Foswiki::ListIterator;
    return new Foswiki::ListIterator( \@list );
}

# Implement Foswiki::Store
sub eachTopic {
    my ( $this, $webObject ) = @_;

    my $dh;
    opendir( $dh, _getData( $webObject ) )
      or return ();

    # the name filter is used to ensure we don't return filenames
    # that contain illegal characters as topic names.
    my @list =
      map { /^(.*)\.txt$/; $1; }
      sort
      grep { !/$Foswiki::cfg{NameFilter}/ && /\.txt$/ } readdir($dh);
    closedir($dh);

    require Foswiki::ListIterator;
    return new Foswiki::ListIterator( \@list );
}

# Implement Foswiki::Store
sub eachWeb {
    my ( $this, $webObject, $all ) = @_;

    # Undocumented; this fn actually accepts a web name as well. This is
    # to make the recursion more efficient.
    my $web = ref($webObject) ? $webObject->web : $webObject;

    my $dir  = $Foswiki::cfg{DataDir};
    $dir .= '/' . $web if defined $web;
    my @list;
    my $dh;

    if ( opendir( $dh, $dir ) ) {
        @list = map {
            Foswiki::Sandbox::untaint( $_, \&Foswiki::Sandbox::validateWebName )
	}

	# The -e on the web preferences is used in preference to a
	# -d to avoid having to validate the web name each time. Since
	# the definition of a Web in this handler is "a directory with a
	# WebPreferences.txt in it", this works.
	grep { !/\./ && -e "$dir/$_/$Foswiki::cfg{WebPrefsTopicName}.txt" }
	readdir($dh);
        closedir($dh);
    }

    if ($all) {
        my $root = $web ? "$web/" : '';
        my @expandedList;
        while ( my $wp = shift(@list) ) {
            push( @expandedList, $wp );
            my $it = $this->eachWeb( $root . $wp, $all );
            push( @expandedList, map { "$wp/$_" } $it->all() );
        }
        @list = @expandedList;
    }
    @list = sort(@list);
    require Foswiki::ListIterator;
    return new Foswiki::ListIterator( \@list );
}

# Implement Foswiki::Store
sub remove {
    my ( $this, $cUID, $meta, $attachment ) = @_;
    my $f;
    if ($meta->topic) {
	# Topic or attachment
	unlink( _latestFile( $meta, $attachment ) );
	_rmtree( _historyDir( $meta, $attachment ) );
	unless ( $attachment ) {
	    # topic
	    _rmtree( _getPub( $meta ) );
	}
    } else {
	# Web
	_rmtree( _getData( $meta ) );
    }

    $this->tellListeners(
        verb          => 'remove',
        oldmeta       => $meta,
        oldattachment => $attachment
    );

    # Only log when deleting topics or attachment, otherwise we would re-create
    # an empty directory with just a .changes.
    if ($attachment) {
        _recordChange( $meta, $cUID, 0,
		       'Deleted attachment ' . $attachment );
    }
    elsif ( my $topic = $meta->topic ) {
        _recordChange( $meta, $cUID, 0,
		       'Deleted ' . $topic );
    }
}

# Implement Foswiki::Store
sub query {
    my ( $this, $query, $inputTopicSet, $session, $options ) = @_;

    my $engine;
    if ( $query->isa('Foswiki::Query::Node') ) {
        unless ( $this->{queryObj} ) {
            my $module = $Foswiki::cfg{Store}{QueryAlgorithm};
            eval "require $module";
            die
"Bad {Store}{QueryAlgorithm}; suggest you run configure and select a different algorithm\n$@"
              if $@;
            $this->{queryObj} = $module->new();
        }
        $engine = $this->{queryObj};
    }
    else {
        ASSERT( $query->isa('Foswiki::Search::Node') ) if DEBUG;
        unless ( $this->{searchQueryObj} ) {
            my $module = $Foswiki::cfg{Store}{SearchAlgorithm};
            eval "require $module";
            die
"Bad {Store}{SearchAlgorithm}; suggest you run configure and select a different algorithm\n$@"
              if $@;
            $this->{searchQueryObj} = $module->new();
        }
        $engine = $this->{searchQueryObj};
    }

    no strict 'refs';
    return $engine->query( $query, $inputTopicSet, $session, $options );
    use strict 'refs';
}

# Implement Foswiki::Store
sub getRevisionAtTime {
    my ( $this, $meta, $time ) = @_;

    my $hd = _historyDir( $meta );
    my $d;
    opendir($d, $hd) or return undef;
    my @revs = reverse sort grep { /^[0-9]+$/ } readdir($d);
    closedir($d);

    foreach my $rev (@revs) {
        return $rev if ( $time >= ( stat( "$hd/$rev" ) )[9] );
    }
    return undef;
}

# Implement Foswiki::Store
sub getLease {
    my ( $this, $meta ) = @_;

    my $filename = _getData( $meta ) . '.lease';
    my $lease;
    if ( -e $filename ) {
        my $t = _readFile( $filename );
        $lease = { split( /\r?\n/, $t ) };
    }
    return $lease;
}

# Implement Foswiki::Store
sub setLease {
    my ( $this, $meta, $lease ) = @_;

    my $filename = _getData( $meta ) . '.lease';
    if ($lease) {
        _saveFile( $filename, join( "\n", %$lease ) );
    }
    elsif ( -e $filename ) {
        unlink $filename
          or die "PlainFile: failed to delete $filename: $!";
    }
}

# Implement Foswiki::Store
sub removeSpuriousLeases {
    my ( $this, $web ) = @_;
    my $webdir = _getData( $web ) . '/';
    if ( opendir( my $W, $webdir ) ) {
        foreach my $f ( readdir($W) ) {
            my $file = $web . $f;
            if ( $file =~ /^(.*)\.lease$/ ) {
                if ( !-e "$1.txt,v" ) {
                    unlink($file);
                }
            }
        }
        closedir($W);
    }
}

#############################################################################
# PRIVATE FUNCTIONS
#############################################################################

# Get the absolute file path to a file in data. $what can be a Meta or
# a string path (e.g. a web name)
sub _getData {
    my ($what) = @_;
    my $path = "$Foswiki::cfg{DataDir}/";
    return "$path$what" unless ref($what);
    return $path.$what->web unless $what->topic;
    return $path.$what->web.'/'.$what->topic;
}

# Get the absolute file path to a file in pub. $what can be a Meta or
# a string path (e.g. a web name)
sub _getPub {
    my ($what) = @_;
    my $path = "$Foswiki::cfg{PubDir}/";
    return "$path$what" unless ref($what);
    return $path.$what->web unless $what->topic;
    return $path.$what->web.'/'.$what->topic;
}

# Get the absolute file path to the latest version of a topic or attachment
# _latestFile($meta [, $attachment])
#    - $meta is a Foswiki::Meta
# _latestFile( $web, $topic [, $attachment])
#    - web and topic are strings
sub _latestFile {
    my $p1 = shift;
    my $p2 = shift;

    unless (ref($p1)) {
	$p1 = "$p1/$p2";
	$p2 = shift;
    }
    return _getPub( $p1 ) . "/$p2" if $p2;
    return _getData( $p1 ) . ".txt";
}

# Get the absolute file path to the history dir for a topic or attachment
# _historyDir($meta [, $attachment])
#    - $meta is a Foswiki::Meta
# _historyDir( $web, $topic [, $attachment])
#    - web and topic are strings
sub _historyDir {
    my $p1 = shift;
    my $p2 = shift;

    unless (ref($p1)) {
	$p1 = "$p1/$p2";
	$p2 = shift;
    }
    return _getPub( $p1 ). "/${p2},pfv" if $p2;
    return _getData( $p1 ) . ",pfv";
}

# Get the absolute file path to the history for a topic or attachment
# _historyFile($meta, $attachment, $version)
#    - $meta is a Foswiki::Meta
# _historyFile( $web, $topic, $attachment, $version)
#    - web and topic are strings
sub _historyFile {
    my $ver = pop;
    return _historyDir( @_ ) . "/$ver";
}

# Get the number of revisions for a topic or attachment
sub _numRevisions {
    my ($meta, $attachment) = @_;
    my $dir = _historyDir($meta, $attachment);

    # _saveDamage is always called before _numRevisions, so
    # we know that if there is no history dir there can be no
    # latest file.
    return 0 unless -e $dir;

    my $d;
    opendir($d, $dir) or die "PlainFile: '$dir': $!";
    my @revs = sort grep { /^[0-9]+$/ } readdir($d);
    closedir($d);
    
    return 0 unless scalar @revs;
    return pop @revs;
}

# Read the TOPICINFO in a file and populate a record with it
sub _getTOPICINFO {
    my ( $fn, $info ) = @_;
    my $f;
    open( $f, '<', $fn ) or return;
    local $/ = "\n";
    my $ti = <$f>;
    close($f);
    if ( defined $ti && $ti =~ /^%META:TOPICINFO{(.*)}%/ ) {
	require Foswiki::Attrs;
	my $a = Foswiki::Attrs->new($1);
	
	# Default bad revs to 1, not 0, because this is coming from
	# a topic on disk, so we know it's a "real" rev.
	$info->{version} = Foswiki::Store::cleanUpRevID( $a->{version} )
	    || 1;
	$info->{date}    = $a->{date};
	$info->{author}  = $a->{author};
	$info->{comment} = $a->{comment};
    }
}

# If a latest file has a more recent file date than the corresponding
# history, then save the damage
sub _saveDamage {
    my ($meta, $attachment) = @_;
    my $d;

    my $latest = _latestFile( $meta, $attachment );
    if (-e $latest) {
	my $rev = 1;
	my $hd = _historyDir( $meta, $attachment );

	if (-e $hd) {
	    # Is there a history?
	    opendir($d, $hd) or die $!;
	    my @revs = sort grep { /^[0-9]+$/ } readdir($d);
	    closedir($d);
	    my $topRev = 0;
	    if (scalar(@revs)) {
		my $topRev = $revs[$#revs];
		my $hf = "$hd/$topRev";

		# Check the time on the history file; is the .txt newer?
		my $ht  = ( stat( $hf ) )[9] || time;
		my $lt = ( stat( $latest ) )[9];
		return if ( $ht >= $lt ); # up to date
		$rev = $topRev + 1;
	    }
	}
	# No existing revs; create
	_forceCheckin($meta, $attachment, $rev);
	ASSERT(-e $hd) if DEBUG;
	return;
    }

    my $hd = _historyDir( $meta, $attachment );
    if (-e $hd) {
	# Is there a history? If so, grab the latest
	opendir($d, $hd) or die($!);
	my @revs = sort grep { /^[0-9]+$/ } readdir($d);
	closedir($d);
	if (scalar(@revs)) {
	    my $topRev = $revs[$#revs];
	    my $hf = "$hd/$topRev";
	    File::Copy::copy($hf, $latest)
		or die "PlainFile: failed to move $hf to $latest: $!";
	    utime(undef, undef, $hf) # touch
		or die "PlainFile: could not touch $hf: $!";
	    ASSERT(-e $latest) if DEBUG;
	}
    }
}

# Checkin a pending change
sub _forceCheckin {
    my ($meta, $attachment, $rev) = @_;
    $rev = _numRevisions($meta, $attachment) + 1 unless defined $rev;

    my $latest = _latestFile( $meta, $attachment );
    # If this is a topic, adjust the TOPICINFO
    unless ( $attachment ) {
	my $t = _readFile( $latest );
		
	$t =~ s/^%META:TOPICINFO{(.*)}%$//m;
	$t =
	    '%META:TOPICINFO{author="'
	    . $Foswiki::Users::BaseUserMapping::UNKNOWN_USER_CUID
	    . '" comment="autosave" date="'
	    . time()
	    . '" format="1.1" version="'
	    . $rev . '"}%' . "\n$t";
	_saveFile( $latest, $t );
    }

    # Creating the history second ensures it is more recent than the
    # latest.
    my $hf = _historyFile( $meta, $attachment, $rev );
    _mkPathTo( $hf );
    File::Copy::copy($latest, $hf)
	or die "PlainFile: failed to copy to $hf: $!";
}

# Record a change in the web history
sub _recordChange {
    my ( $meta, $cUID, $rev, $more ) = @_;
    $more ||= '';

    my $file = _getData( $meta->web ) . '/.changes';

    my @changes = ();
    if (-e $file ) {
	@changes =
	    map {
		my @row = split( /\t/, $_, 5 );
		\@row
	}
	split( /[\r\n]+/, _readFile( $file ) );

	# Forget old stuff
	my $cutoff = time() - $Foswiki::cfg{Store}{RememberChangesFor};
	while ( scalar(@changes) && $changes[0]->[2] < $cutoff ) {
	    shift(@changes);
	}
    }

    # Add the new change to the end of the file
    push( @changes, [ $meta->topic || '.', $cUID, time(), $rev, $more ] );

    # Doing this using a Schwartzian transform sometimes causes a mysterious
    # undefined value, so had to unwrap it to a for loop.
    for ( my $i = 0 ; $i <= $#changes ; $i++ ) {
        $changes[$i] = join( "\t", @{ $changes[$i] } );
    }

    my $text = join( "\n", @changes );

    _saveFile( $file, $text );
}

# Read an entire file
sub _readFile {
    my ( $name ) = @_;

    my $data;
    my $IN_FILE;
    open( $IN_FILE, '<', $name ) or die "PlainFile: failed to read $name: $!";
    binmode($IN_FILE);
    local $/ = undef;
    $data = <$IN_FILE>;
    close($IN_FILE);
    $data = '' unless defined $data;
    return $data;
}

# Open a stream onto a file
sub _openStream {
    my ( $meta, $att, $mode, %opts ) = @_;
    my $stream;

    if ( $mode eq '<' && $opts{version} ) {

        # Bulk load the revision and tie a filehandle
        require Symbol;
        $stream = Symbol::gensym;    # create an anonymous glob
        tie( *$stream, 'Foswiki::Store::_MemoryFile',
            _getRevision( $meta, $att, $opts{version} ) );
    }
    else {
	ASSERT(!$opts{version}) if DEBUG;
	my $path = _latestFile( $meta, $att );
        if ( $mode =~ />/ ) {
            _mkPathTo( $path );
        }
        unless ( open( $stream, $mode, $path ) ) {
            die( "PlainFile: stream open '$path' failed: $!" );
        }
        binmode $stream;
    }
    return $stream;
}

# Save a file
sub _saveFile {
    my ( $file, $text ) = @_;

    _mkPathTo($file);
    my $fh;
    open( $fh, '>', $file )
      or die(
        "PlainFile: failed to create file $file: $!" );
    flock( $fh, LOCK_EX )
      or die(
        "PlainFile: failed to lock file $file: $!" );
    binmode($fh)
      or die(
        "PlainFile: failed to binmode $file: $!" );
    print $fh $text
      or die(
        "PlainFile: failed to print into $file: $!" );
    close($fh)
      or die(
        "PlainFile: failed to close file $file: $!" );

    chmod( $Foswiki::cfg{RCS}{filePermission}, $file );

    return;
}

# Save a stream to a file
sub _saveStream {
    my ( $file, $fh ) = @_;

    _mkPathTo( $file );
    my $F;
    open( $F, '>', $file ) or die "PlainFile: open $file failed: $!";
    binmode($F) or die "PlainFile: failed to binmode $file: $!";
    my $text;
    while ( read( $fh, $text, 1024 ) ) {
        print $F $text;
    }
    close($F) or die "PlainFile: close $file failed: $!";

    chmod( $Foswiki::cfg{RCS}{filePermission}, $file );
}

# Move a file or directory from one absolute file path to another.
# if the destination already exists it's an error.
sub _moveFile {
    my ( $from, $to ) = @_;
    die "PlainFile: move target $to already exists" if -e $to;
    _mkPathTo($to);
    my $ok;
    if (-d $from) {
	$ok = File::Copy::Recursive::dirmove($from, $to);
    } else {
	ASSERT( -e $from ) if DEBUG;
	$ok = File::Copy::move( $from, $to );
    }
    $ok or die "PlainFile: move $from to $to failed: $!";
}

# Copy a file or directory from one absolute file path to another.
# if the destination already exists it's an error.
sub _copyFile {
    my ( $from, $to ) = @_;

    die "PlainFile: move target $to already exists" if -e $to;
    _mkPathTo($to);
    my $ok;
    if (-d $from) {
	$ok = File::Copy::Recursive::dircopy($from, $to);
    } else {
	$ok = File::Copy::copy( $from, $to );
    }
    $ok or die "PlainFile: copy $from to $to failed: $!";
}

# Make all directories above the path
sub _mkPathTo {
    my $file = shift;

    ASSERT( File::Spec->file_name_is_absolute($file) ) if DEBUG;

    my ( $volume, $path, undef ) = File::Spec->splitpath($file);
    $path = File::Spec->catpath( $volume, $path, '' );

    # SMELL:  Sites running Apache with SuexecUserGroup will
    # have a forced "safe" umask. Override umask here to allow
    # correct dirPermissions to be applied
    umask( oct(777) - $Foswiki::cfg{RCS}{dirPermission} );

    eval { File::Path::mkpath( $path, 0, $Foswiki::cfg{RCS}{dirPermission} ); };
    if ($@) {
        die("PlainFile: failed to create ${path}: $!");
    }
}

# Remove an entire directory tree
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
                    die "PlainFile: Failed to delete file $entry: $!";
                }
                else {

                    # Windows sometimes fails to delete files when
                    # subprocesses haven't exited yet, because the
                    # subprocess still has the file open. Live with it.
                    print STDERR "WARNING: Failed to delete file $entry: $!\n";
                }
            }
        }
        closedir($D);

        if ( !rmdir($root) ) {
            if ( $Foswiki::cfg{OS} ne 'WINDOWS' ) {
                die "PlainFile: Failed to delete $root: $!";
            }
            else {
                print STDERR "WARNING: Failed to delete $root: $!\n";
            }
        }
    }
}

# Get the timestamp on a file. 0 indicates the file was not found.
sub _getTimestamp {
    my ($file) = @_;

    my $date = 0;
    if ( -e $file ) {

        # If the stat fails, stamp it with some arbitrary static
        # time in the past (00:40:05 on 5th Jan 1989)
        $date = ( stat $file )[9] || 600000000;
    }
    return $date;
}

# Get a specific revision of a topic or attachment
sub _getRevision {
    my ( $meta, $attachment, $version ) = @_;

    my $nr = _numRevisions($meta, $attachment);
    if ($nr && $version && $version <= $nr) {
	my $fn = _historyDir( $meta, $attachment ) . "/$version";
	if ( -e $fn ) {
	    return ( _readFile( $fn ), $version == $nr);
	}
    }
    my $latest = _latestFile($meta, $attachment);
    return (undef, 0) unless -e $latest;
    # no version given, give latest (may not be checked in yet)
    return ( _readFile( $latest ), 1 );
}

# Look for possible attachments that have appeared in the attachments
# dir an add them as attachments.
sub _autoAttach {
    my ($this, $meta ) = @_;

    my @knownAttachments = $meta->find('FILEATTACHMENT');
    my %filesListedInPub = ();
    my $dir            = _getPub( $meta );
    my $dh;
    return unless opendir( $dh, $dir );

    foreach my $attachment ( grep { !/^[.*_]/ && !/,v$/ } readdir($dh) ) {
        my @stat = stat( "$dir/$attachment" );
	if ( $#stat > 0 ) {
	    $filesListedInPub{$attachment} = {
		name    => $attachment,
		version => '',
		path    => $attachment,
		size    => $stat[7],
		date    => $stat[9],
		comment      => '',
		attr         => '',
		autoattached => '1'
	    };
	} else {
	    $filesListedInPub{$attachment} = undef;
	}
    }
    closedir($dh);
    my %filesListedInMeta = ();

    # You need the following lines if you want metadata to supplement
    # the filesystem
    if ( scalar @knownAttachments ) {
        %filesListedInMeta =
	    map { $_->{name} => $_ } @knownAttachments;
    }

    foreach my $file ( keys %filesListedInPub ) {
        if ( $filesListedInMeta{$file} ) {

            # Bring forward any missing yet wanted attributes
            foreach my $field (qw(comment attr user version)) {
                if ( $filesListedInMeta{$file}{$field} ) {
                    $filesListedInPub{$file}{$field} =
                      $filesListedInMeta{$file}{$field};
                }
            }
        }
    }

    # A comparison of the keys of the $filesListedInMeta and %filesListedInPub
    # would show files that were in Meta but have disappeared from Pub.
    my @attachmentsFoundInPub = values(%filesListedInPub);

    my @validAttachmentsFound;
    foreach my $foundAttachment (@attachmentsFoundInPub) {

	# test if the attachment filename is valid without having to
	# be sanitized. If not, ignore it.
	my $validated = Foswiki::Sandbox::validateAttachmentName(
	    $foundAttachment->{name} );
	unless ( defined $validated
		 && $validated eq $foundAttachment->{name} )
	{
	    
	    print STDERR 'AutoAttachPubFiles ignoring '
		. $foundAttachment->{name} . ' in '
		. $meta->getPath()
		. ' - not a valid Foswiki Attachment filename';
	}
	else {
	    push @validAttachmentsFound, $foundAttachment;
	    $this->tellListeners(
		verb          => 'autoattach',
		newmeta       => $meta,
		newattachment => $foundAttachment
                );
	}
    }

    $meta->putAll( 'FILEATTACHMENT', @validAttachmentsFound )
	if @validAttachmentsFound;
}

# Check in a new revision
sub _ci {
    my ( $meta, $att, $isStream, $data, $log, $author, $date ) = @_;

    my $latest = _latestFile( $meta, $att );
    if ($isStream) {
        _saveStream($latest, $data);
    }
    else {
        _saveFile( $latest, $data );
    }

    my $rn = _numRevisions($meta, $att) + 1;
    my $hf = _historyFile( $meta, $att, $rn );
    _mkPathTo( $hf );
    File::Copy::copy( $latest, $hf )
	or die "PlainFile: failed to copy $latest to $hf: $!";

    return $rn;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2012 Crawford Currie http://c-dot.co.uk

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
