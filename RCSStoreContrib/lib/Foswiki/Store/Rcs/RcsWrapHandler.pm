# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Store::Rcs::RcsWrapHandler

This class implements the pure methods of the Foswiki::Store::Rcs::Handler
superclass. See the superclass for detailed documentation of the methods.

Wrapper around the RCS commands required by Foswiki.
An object of this class is created for each file stored under RCS.

For readers who are familiar with Foswiki version 1.0, this class
is analagous to the old =Foswiki::Store::RcsWrap=.

=cut

package Foswiki::Store::Rcs::RcsWrapHandler;
use strict;
use warnings;
use Assert;

use Foswiki::Store::Rcs::Handler ();
our @ISA = ('Foswiki::Store::Rcs::Handler');

use Foswiki::Sandbox ();

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }

    *_decode = \&Foswiki::Store::decode;
    *_encode = \&Foswiki::Store::encode;
}

sub new {
    return shift->SUPER::new(@_);
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
    $this->SUPER::finish();
    undef $this->{binary};
}

# implements Rcs::Handler
sub initBinary {
    my ($this) = @_;

    $this->{binary} = 1;

    $this->mkPathTo( $this->{file} );

    return if $this->revisionHistoryExists();

    my ( $rcsOutput, $exit ) = Foswiki::Sandbox->sysCommand(
        $Foswiki::cfg{RCS}{initBinaryCmd},
        FILENAME => _encode( $this->{file}, 1 )
    );
    if ($exit) {
        throw Error::Simple( $Foswiki::cfg{RCS}{initBinaryCmd} . ' of '
              . $this->hidePath( $this->{file} )
              . ' failed: '
              . $rcsOutput );
    }
    elsif ( !$this->revisionHistoryExists() ) {

        # Sometimes (on Windows?) rcs file not formed, so check for it
        throw Error::Simple( $Foswiki::cfg{RCS}{initBinaryCmd} . ' of '
              . $this->hidePath( $this->{rcsFile} )
              . ' failed to create history file' );
    }
}

# implements Rcs::Handler
sub initText {
    my ($this) = @_;
    $this->{binary} = 0;

    $this->mkPathTo( $this->{file} );

    return if $this->revisionHistoryExists();

    my ( $rcsOutput, $exit, $stdErr ) = Foswiki::Sandbox->sysCommand(
        $Foswiki::cfg{RCS}{initTextCmd},
        FILENAME => _encode( $this->{file}, 1 )
    );
    if ($exit) {
        $rcsOutput ||= '';
        throw Error::Simple( $Foswiki::cfg{RCS}{initTextCmd} . ' of '
              . $this->hidePath( $this->{file} )
              . ' failed: '
              . $rcsOutput );
    }
    elsif ( !$this->revisionHistoryExists() ) {

        # Sometimes (on Windows?) rcs file not formed, so check for it
        throw Error::Simple( $Foswiki::cfg{RCS}{initTextCmd} . ' of '
              . $this->hidePath( $this->{rcsFile} )
              . ' failed to create history file' );
    }
}

# implements Rcs::Handler

# Designed for calling *only* from the Handler superclass and this class
sub ci {
    my ( $this, $isStream, $data, $comment, $user, $date ) = @_;

    _lock($this);
    if ($isStream) {
        $this->saveStream($data);
    }
    else {
        $this->saveFile( $this->{file}, $data );
    }

    $comment = 'none' unless $comment;

    undef $this->{numRevisions};

    my ( $cmd, $rcsOutput, $exit, $stderr );
    if ( defined($date) ) {
        require Foswiki::Time;
        $date = Foswiki::Time::formatTime( $date, '$rcs', 'gmtime' );
        $cmd = $Foswiki::cfg{RCS}{ciDateCmd};
        ( $rcsOutput, $exit, $stderr ) = Foswiki::Sandbox->sysCommand(
            $cmd,
            USERNAME => $user,
            FILENAME => _encode( $this->{file}, 1 ),
            COMMENT  => $comment,
            DATE     => $date
        );
    }
    else {
        $cmd = $Foswiki::cfg{RCS}{ciCmd};
        ( $rcsOutput, $exit, $stderr ) = Foswiki::Sandbox->sysCommand(
            $cmd,
            USERNAME => $user,
            FILENAME => _encode( $this->{file}, 1 ),
            COMMENT  => $comment
        );
    }
    $rcsOutput ||= '';

    if ($exit) {
        throw Error::Simple( $cmd . ' of '
              . $this->hidePath( $this->{file} )
              . ' failed: '
              . $exit . ' '
              . $rcsOutput
              . ( (DEBUG) ? $stderr : '' ) );
    }
    chmod( $Foswiki::cfg{Store}{filePermission}, _encode( $this->{file}, 1 ) );
}

# implements Rcs::Handler
sub repRev {
    my ( $this, $text, $comment, $user, $date ) = @_;

    my $rev = $this->_numRevisions() || 0;

    $comment ||= 'none';

    # update repository with same userName and date
    if ( $rev <= 1 ) {

        # initial revision, so delete repository file and start again
        unlink $this->{rcsFile};
    }
    else {
        _deleteRevision( $this, $rev );
    }

    $this->saveFile( $this->{file}, $text );
    require Foswiki::Time;
    $date = Foswiki::Time::formatTime( $date, '$rcs', 'gmtime' );

    _lock($this);
    undef $this->{numRevisions};
    my ( $rcsOut, $exit ) = Foswiki::Sandbox->sysCommand(
        $Foswiki::cfg{RCS}{ciDateCmd},
        DATE     => $date,
        USERNAME => $user,
        FILENAME => _encode( $this->{file}, 1 ),
        COMMENT  => $comment
    );
    if ($exit) {
        $rcsOut = $Foswiki::cfg{RCS}{ciDateCmd} . "\n" . $rcsOut;
        return $rcsOut;
    }
    chmod( $Foswiki::cfg{Store}{filePermission}, _encode( $this->{file}, 1 ) );
}

# implements Rcs::Handler
sub deleteRevision {
    my ($this) = @_;
    my $rev = $this->_numRevisions();
    return if ( $rev <= 1 );
    return _deleteRevision( $this, $rev );
}

sub _deleteRevision {
    my ( $this, $rev ) = @_;

    # delete latest revision (unlock (may not be needed), delete revision)
    my ( $rcsOut, $exit, $stderr ) =
      Foswiki::Sandbox->sysCommand( $Foswiki::cfg{RCS}{unlockCmd},
        FILENAME => _encode( $this->{file}, 1 ) );
    if ($exit) {
        throw Error::Simple(
            "$Foswiki::cfg{RCS}{unlockCmd} failed: $rcsOut $stderr");
    }

    chmod( $Foswiki::cfg{Store}{filePermission}, _encode( $this->{file}, 1 ) );

    ( $rcsOut, $exit, $stderr ) = Foswiki::Sandbox->sysCommand(
        $Foswiki::cfg{RCS}{delRevCmd},
        REVISION => '1.' . $rev,
        FILENAME => _encode( $this->{file}, 1 )
    );

    if ($exit) {
        throw Error::Simple( $Foswiki::cfg{RCS}{delRevCmd} . ' of '
              . $this->hidePath( $this->{file} )
              . " failed: $rcsOut $stderr" );
    }

    # Update the checkout
    undef $this->{numRevisions};
    $rev--;
    ( $rcsOut, $exit, $stderr ) = Foswiki::Sandbox->sysCommand(
        $Foswiki::cfg{RCS}{coCmd},
        REVISION => '1.' . $rev,
        FILENAME => _encode( $this->{file}, 1 )
    );

    if ($exit) {
        throw Error::Simple( $Foswiki::cfg{RCS}{coCmd} . ' of '
              . $this->hidePath( $this->{file} )
              . " failed: $rcsOut $stderr" );
    }
    $this->saveFile( $this->{file}, $rcsOut );
}

# implements Rcs::Handler
sub getRevision {
    my ( $this, $version ) = @_;

    # If there is no revision history, or if $version is not given,
    # or there is a checkin pending, then consult the .txt
    if (   !$this->revisionHistoryExists()
        || !$version
        || !$this->noCheckinPending() )
    {

        # Get the latest rev from the cache
        return ( $this->SUPER::getRevision($version), 1 );
    }

    # We've been asked for an explicit rev. The rev might be outside the
    # range of revs in RCS. RCS will return the latest, though it reports
    # the rev retrieved to STDERR
    $version = 2 ^ 31 if $version <= 0;

    my $tmpfile;
    my $tmpRevFile;
    my $coCmd = $Foswiki::cfg{RCS}{coCmd};
    my $file = _encode( $this->{file}, 1 );
    if ( $Foswiki::cfg{RCS}{coMustCopy} ) {

        # Need to take temporary copy of topic, check it out to file,
        # then read that. Need to put RCS into binary mode to avoid
        # extra \r appearing and read from binmode file rather than
        # stdout to avoid early file read termination
        # See http://twiki.org/cgi-bin/view/Codev/DakarRcsWrapProblem
        # for evidence that this code is needed.
        $tmpfile    = Foswiki::Store::Rcs::Handler::mkTmpFilename($this);
        $tmpRevFile = $tmpfile . ',v';
        $this->_copyFile( $this->{rcsFile}, $tmpRevFile );
        my ( $rcsOutput, $status ) =
          Foswiki::Sandbox->sysCommand( $Foswiki::cfg{RCS}{tmpBinaryCmd},
            FILENAME => $tmpRevFile );
        if ($status) {
            throw Error::Simple(
                $Foswiki::cfg{RCS}{tmpBinaryCmd} . ' failed: ' . $rcsOutput );
        }
        $file = $tmpfile;
        $coCmd =~ s/-p%REVISION/-r%REVISION/;
    }
    my ( $text, $status, $stderr ) = Foswiki::Sandbox->sysCommand(
        $coCmd,
        REVISION => '1.' . $version,
        FILENAME => $file
    );

    # The loaded version is reported on STDERR
    my $isLatest = 0;
    if ( defined $stderr
        && $stderr =~ /revision 1\.(\d+)/s )
    {
        if ( $version > $1 ) {
            $this->{numRevisions} = $1;
            $isLatest = 1;
        }
        elsif ( defined $this->{numRevisions} ) {
            $isLatest = ( $1 == $this->{numRevisions} );
        }
        else {
            $isLatest = ( $1 == $this->_numRevisions() );
        }
    }

    # otherwise we will have to resort to numRevisions to tell if
    # this is the latest rev, which is expensive. By returning false
    # for isLatest we will force a reload upstairs if the latest rev
    # is required.

    if ($tmpfile) {
        $text = $this->readFile($tmpfile);
        for ( $tmpfile, $tmpRevFile ) {
            my $f = Foswiki::Sandbox::untaintUnchecked($_);
            unlink $f or warn "Could not delete $f: $!";
        }
    }

    return ( $text, $isLatest );
}

# implements Rcs::Handler
sub getInfo {
    my ( $this, $version ) = @_;

    my $numRevs = $this->_numRevisions() || 0;
    if (   ( $this->noCheckinPending() )
        && ( !$version || $version > $numRevs ) )
    {
        $version = $numRevs;
    }
    else {
        $version = $numRevs + 1
          unless ( $version && $version <= $numRevs );
    }
    my ( $rcsOut, $exit ) = Foswiki::Sandbox->sysCommand(
        $Foswiki::cfg{RCS}{infoCmd},
        REVISION => '1.' . $version,
        FILENAME => _encode( $this->{rcsFile}, 1 )
    );
    if ( !$exit ) {
        if ( $rcsOut =~
            /^.*?date: ([^;]+);  author: ([^;]*);[^\n]*\n([^\n]*)\n/s )
        {
            require Foswiki::Time;
            my $info = {
                version => $version,
                date    => Foswiki::Time::parseTime($1),
                author  => $2,
                comment => $3,
            };
            if ( $rcsOut =~ /revision 1.([0-9]*)/ ) {
                $info->{version} = $1;
            }
            return $info;
        }
    }

    return $this->SUPER::getInfo($version);
}

# implements Rcs::Handler
sub _numRevisions {
    my $this = shift;

    return $this->{numRevisions} if defined $this->{numRevisions};

    unless ( $this->revisionHistoryExists() ) {

        # If there is no history, there can only be one.
        return $this->{numRevisions} = $this->storedDataExists() ? 1 : 0;
    }

    my ( $rcsOutput, $exit ) =
      Foswiki::Sandbox->sysCommand( $Foswiki::cfg{RCS}{histCmd},
        FILENAME => _encode( $this->{rcsFile}, 1 ) );
    if ($exit) {
        throw Error::Simple( 'RCS: '
              . $Foswiki::cfg{RCS}{histCmd} . ' of '
              . $this->hidePath( $this->{rcsFile} )
              . ' failed: '
              . $rcsOutput );
    }
    if ( $rcsOutput =~ /head:\s+\d+\.(\d+)\n/ ) {
        return $this->{numRevisions} = $1;
    }
    if ( $rcsOutput =~ /total revisions: (\d+)\n/ ) {
        return $this->{numRevisions} = $1;
    }
    return $this->{numRevisions} = 1;
}

# implements Rcs::Handler
# rev1 is the lower, rev2 is the higher revision
sub revisionDiff {
    my ( $this, $rev1, $rev2, $contextLines ) = @_;
    my $tmp = '';
    my $exit;
    if ( $rev1 eq '1' && $rev2 eq '1' ) {
        my $text = $this->getRevision(1);
        $tmp = "1a1\n";
        foreach ( split( /\r?\n/, $text ) ) {
            $tmp = "$tmp> $_\n";
        }
    }
    else {
        $contextLines = 3 unless defined($contextLines);
        ( $tmp, $exit ) = Foswiki::Sandbox->sysCommand(
            $Foswiki::cfg{RCS}{diffCmd},
            REVISION1 => '1.' . $rev1,
            REVISION2 => '1.' . $rev2,
            FILENAME  => _encode( $this->{rcsFile}, 1 ),
            CONTEXT   => $contextLines
        );

        # prevent diffing TOPICINFO
        $tmp =~ s/^.%META:TOPICINFO\{(.*)\}%\n//mg;

        # comment out because we get a non-zero status for a good result!
        #if( $exit ) {
        #    throw Error::Simple( 'RCS: '.$Foswiki::cfg{RCS}{diffCmd}.
        #                           ' failed: '.$! );
        #}
    }

    return parseRevisionDiff($tmp);
}

=begin TML

---++ StaticMethod parseRevisionDiff( $text ) -> \@diffArray

| Description: | parse the text into an array of diff cells |
| #Description: | unlike Algorithm::Diff I concatinate lines of the same diffType that are sqential (this might be something that should be left up to the renderer) |
| Parameter: =$text= | currently unified or rcsdiff format |
| Return: =\@diffArray= | reference to an array of [ diffType, $right, $left ] |
| TODO: | move into Rcs::Handler and add indirection in Store |

=cut

sub parseRevisionDiff {
    my ($text) = @_;

    my ($diffFormat) = 'normal';    #or rcs, unified...
    my (@diffArray)  = ();

    $diffFormat = 'unified' if ( $text =~ /^---/s );

    $text =~ s/\r//go;              # cut CR

    my $lineNumber = 1;
    if ( $diffFormat eq 'unified' ) {
        foreach ( split( /\r?\n/, $text ) ) {
            if ( $lineNumber > 2 ) {    #skip the first 2 lines (filenames)
                if (/@@ [-+]([0-9]+)([,0-9]+)? [-+]([0-9]+)(,[0-9]+)? @@/) {

                    #line number
                    push @diffArray, [ 'l', $1, $3 ];
                }
                elsif (/^\-(.*)$/) {
                    push @diffArray, [ '-', $1, '' ];
                }
                elsif (/^\+(.*)$/) {
                    push @diffArray, [ '+', '', $1 ];
                }
                else {
                    s/^ (.*)$/$1/go;
                    push @diffArray, [ 'u', $_, $_ ];
                }
            }
            $lineNumber++;
        }
    }
    else {

        #'normal' rcsdiff output
        foreach ( split( /\r?\n/, $text ) ) {
            if (/^([0-9]+)[0-9\,]*([acd])([0-9]+)/) {

                #line number
                push @diffArray, [ 'l', $1, $3 ];
            }
            elsif (/^< (.*)$/) {
                push @diffArray, [ '-', $1, '' ];
            }
            elsif (/^> (.*)$/) {
                push @diffArray, [ '+', '', $1 ];
            }
            else {

                #push @diffArray, ['u', '', ''];
            }
        }
    }
    return \@diffArray;
}

sub _lock {
    my $this = shift;

    return unless $this->revisionHistoryExists();

    # Try and get a lock on the file
    my ( $rcsOutput, $exit ) =
      Foswiki::Sandbox->sysCommand( $Foswiki::cfg{RCS}{lockCmd},
        FILENAME => _encode( $this->{file}, 1 ) );

    if ($exit) {

        # if the lock has been set more than 24h ago, let's try to break it
        # and then retry.  Should not happen unless in Cairo upgrade
        # scenarios - see Item2102
        if ( ( time - ( stat( _encode( $this->{rcsFile}, 1 ) ) )[9] ) > 3600 ) {
            warn 'Automatic recovery: breaking lock for ' . $this->{file};
            Foswiki::Sandbox->sysCommand(
                $Foswiki::cfg{RCS}{breaklockCmd},
                FILENAME => _encode( $this->{file}, 1 )
            );
            ( $rcsOutput, $exit ) =
              Foswiki::Sandbox->sysCommand( $Foswiki::cfg{RCS}{lockCmd},
                FILENAME => _encode( $this->{file}, 1 ) );
        }
        if ($exit) {

            # still no luck - bailing out
            $rcsOutput ||= '';
            throw Error::Simple( 'RCS: '
                  . $Foswiki::cfg{RCS}{lockCmd}
                  . ' failed: '
                  . $rcsOutput );
        }
    }
    chmod( $Foswiki::cfg{Store}{filePermission}, _encode( $this->{file}, 1 ) );
}

# implements Rcs::Handler
sub getRevisionAtTime {
    my ( $this, $date ) = @_;

    unless ( $this->revisionHistoryExists() ) {
        return ( $date >= ( stat( _encode( $this->{file}, 1 ) ) )[9] )
          ? 1
          : undef;
    }

    require Foswiki::Time;
    my $sdate = Foswiki::Time::formatTime( $date, '$rcs', 'gmtime' );
    my ( $rcsOutput, $exit ) = Foswiki::Sandbox->sysCommand(
        $Foswiki::cfg{RCS}{rlogDateCmd},
        DATE     => $sdate,
        FILENAME => _encode( $this->{file}, 1 )
    );

    my $version = undef;
    if ( $rcsOutput =~ m/revision \d+\.(\d+)/ ) {
        $version = $1;
    }

    if ( $version && !$this->noCheckinPending() ) {

        # Check the file date
        $version++ if ( $date >= ( stat( _encode( $this->{file}, 1 ) ) )[9] );
    }
    return $version;
}

1;
__END__

Copyright (C) 2008-2015 Foswiki Contributors. All Rights Reserved.
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
