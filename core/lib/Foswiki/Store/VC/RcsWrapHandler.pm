# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Store::VC::RcsWrapHandler

This class implements the pure methods of the Foswiki::Store::VC::Handler
superclass. See the superclass for detailed documentation of the methods.

Wrapper around the RCS commands required by Foswiki.
An object of this class is created for each file stored under RCS.

For readers who are familiar with Foswiki version 1.0, this class
is analagous to the old =Foswiki::Store::RcsWrap=.

=cut

package Foswiki::Store::VC::RcsWrapHandler;
use strict;
use warnings;

use Foswiki::Store::VC::Handler ();
our @ISA = ('Foswiki::Store::VC::Handler');

use Foswiki::Sandbox ();

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

# implements VC::Handler
sub initBinary {
    my ($this) = @_;

    $this->{binary} = 1;

    $this->mkPathTo( $this->{file} );

    return if -e $this->{rcsFile};

    my ( $rcsOutput, $exit ) =
      Foswiki::Sandbox->sysCommand( $Foswiki::cfg{RCS}{initBinaryCmd},
        FILENAME => $this->{file} );
    if ($exit) {
        throw Error::Simple( $Foswiki::cfg{RCS}{initBinaryCmd} . ' of '
              . $this->hidePath( $this->{file} )
              . ' failed: '
              . $rcsOutput );
    }
    elsif ( !-e $this->{rcsFile} ) {

        # Sometimes (on Windows?) rcs file not formed, so check for it
        throw Error::Simple( $Foswiki::cfg{RCS}{initBinaryCmd} . ' of '
              . $this->hidePath( $this->{rcsFile} )
              . ' failed to create history file' );
    }
}

# implements VC::Handler
sub initText {
    my ($this) = @_;
    $this->{binary} = 0;

    $this->mkPathTo( $this->{file} );

    return if -e $this->{rcsFile};

    my ( $rcsOutput, $exit ) =
      Foswiki::Sandbox->sysCommand( $Foswiki::cfg{RCS}{initTextCmd},
        FILENAME => $this->{file} );
    if ($exit) {
        $rcsOutput ||= '';
        throw Error::Simple( $Foswiki::cfg{RCS}{initTextCmd} . ' of '
              . $this->hidePath( $this->{file} )
              . ' failed: '
              . $rcsOutput );
    }
    elsif ( !-e $this->{rcsFile} ) {

        # Sometimes (on Windows?) rcs file not formed, so check for it
        throw Error::Simple( $Foswiki::cfg{RCS}{initTextCmd} . ' of '
              . $this->hidePath( $this->{rcsFile} )
              . ' failed to create history file' );
    }
}

# implements VC::Handler

# Designed for calling *only* from the Handler superclass and this class
sub ci {
    my ($this, $isStream, $data, $comment, $user, $date) = @_;
#    unless ( -e $this->{rcsFile} ) {    #
#                                        # SMELL: what is this for?
#        _lock($this);
#        _ci( $this, $comment, $user, $date );
#    }
    _lock($this);
    if ($isStream) {
	$this->saveStream( $data );
    } else {
	$this->saveFile( $this->{file}, $data );
    }
    _ci( $this, $comment, $user, $date );
}

# implements VC::Handler
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

    Foswiki::Store::VC::Handler::saveFile( $this, $this->{file}, $text );
    require Foswiki::Time;
    $date = Foswiki::Time::formatTime( $date, '$rcs', 'gmtime' );

    _lock($this);
    my ( $rcsOut, $exit ) = Foswiki::Sandbox->sysCommand(
        $Foswiki::cfg{RCS}{ciDateCmd},
        DATE     => $date,
        USERNAME => $user,
        FILENAME => $this->{file},
        COMMENT  => $comment
    );
    if ($exit) {
        $rcsOut = $Foswiki::cfg{RCS}{ciDateCmd} . "\n" . $rcsOut;
        return $rcsOut;
    }
    chmod( $Foswiki::cfg{RCS}{filePermission}, $this->{file} );
}

# implements VC::Handler
sub deleteRevision {
    my ($this) = @_;
    my $rev = $this->_numRevisions();
    return if ( $rev <= 1 );
    return _deleteRevision( $this, $rev );
}

sub _deleteRevision {
    my ( $this, $rev ) = @_;

    # delete latest revision (unlock (may not be needed), delete revision)
    my ( $rcsOut, $exit ) =
      Foswiki::Sandbox->sysCommand( $Foswiki::cfg{RCS}{unlockCmd},
        FILENAME => $this->{file} );

    chmod( $Foswiki::cfg{RCS}{filePermission}, $this->{file} );

    ( $rcsOut, $exit ) = Foswiki::Sandbox->sysCommand(
        $Foswiki::cfg{RCS}{delRevCmd},
        REVISION => '1.' . $rev,
        FILENAME => $this->{file}
    );

    if ($exit) {
        throw Error::Simple( $Foswiki::cfg{RCS}{delRevCmd} . ' of '
              . $this->hidePath( $this->{file} )
              . ' failed: '
              . $rcsOut );
    }

    # Update the checkout
    $rev--;
    ( $rcsOut, $exit ) = Foswiki::Sandbox->sysCommand(
        $Foswiki::cfg{RCS}{coCmd},
        REVISION => '1.' . $rev,
        FILENAME => $this->{file}
    );

    if ($exit) {
        throw Error::Simple( $Foswiki::cfg{RCS}{coCmd} . ' of '
              . $this->hidePath( $this->{file} )
              . ' failed: '
              . $rcsOut );
    }
    Foswiki::Store::VC::Handler::saveFile( $this, $this->{file}, $rcsOut );
}

# implements VC::Handler
sub getRevision {
    my ( $this, $version ) = @_;

    unless ( $version && -e $this->{rcsFile} ) {

        # Get the latest rev from the cache
        return ($this->SUPER::getRevision($version));
    }

    # We've been asked for an explicit rev. The rev might be outside the
    # range of revs in RCS. RCS will return the latest, though it reports
    # the rev retrieved to STDERR (no use to us, as we have no access
    # to STDERR)

    # SMELL: we need to determine if the rev we are returning is the latest.
    # co prints the retrieved revision, but unfortunately it prints it
    # to STDERR, which the Sandbox can't retrieve.

    my $tmpfile;
    my $tmpRevFile;
    my $coCmd = $Foswiki::cfg{RCS}{coCmd};
    my $file  = $this->{file};
    if ( $Foswiki::cfg{RCS}{coMustCopy} ) {

        # Need to take temporary copy of topic, check it out to file,
        # then read that. Need to put RCS into binary mode to avoid
        # extra \r appearing and read from binmode file rather than
        # stdout to avoid early file read termination
        # See http://twiki.org/cgi-bin/view/Codev/DakarRcsWrapProblem
        # for evidence that this code is needed.
        $tmpfile    = Foswiki::Store::VC::Handler::mkTmpFilename($this);
        $tmpRevFile = $tmpfile . ',v';
        require File::Copy;
        File::Copy::copy( $this->{rcsFile}, $tmpRevFile );
        my ( $tmp, $status ) =
          Foswiki::Sandbox->sysCommand( $Foswiki::cfg{RCS}{tmpBinaryCmd},
            FILENAME => $tmpRevFile );
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
    if (defined $stderr
          && $stderr =~ /revision 1\.(\d+)/s) {
        $isLatest = ($version >= $1);
    }
    # otherwise we will have to resort to numRevisions to tell if
    # this is the latest rev, which is expensive. By returning false
    # for isLatest we will force a reload upstairs if the latest rev
    # is required.

    if ($tmpfile) {
        $text = Foswiki::Store::VC::Handler::readFile( $this, $tmpfile );
        unlink Foswiki::Sandbox->untaintUnchecked($tmpfile);
        unlink Foswiki::Sandbox->untaintUnchecked($tmpRevFile);
    }

    return ($text, $isLatest);
}

# implements VC::Handler
sub getInfo {
    my ( $this, $version ) = @_;

    if ( $this->noCheckinPending() ) {
        if ( !$version || $version > $this->_numRevisions() ) {
            $version = $this->_numRevisions();
        }
        my ( $rcsOut, $exit ) = Foswiki::Sandbox->sysCommand(
            $Foswiki::cfg{RCS}{infoCmd},
            REVISION => '1.' . $version,
            FILENAME => $this->{rcsFile}
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
    }
    return $this->SUPER::getInfo($version);
}

# implements VC::Handler
sub _numRevisions {
    my $this = shift;

    unless ( -e $this->{rcsFile} ) {

        # If there is no history, there can only be one.
        return 1 if -e $this->{file};
        return 0;
    }

    my ( $rcsOutput, $exit ) =
      Foswiki::Sandbox->sysCommand( $Foswiki::cfg{RCS}{histCmd},
        FILENAME => $this->{rcsFile} );
    if ($exit) {
        throw Error::Simple( 'RCS: '
              . $Foswiki::cfg{RCS}{histCmd} . ' of '
              . $this->hidePath( $this->{rcsFile} )
              . ' failed: '
              . $rcsOutput );
    }
    if ( $rcsOutput =~ /head:\s+\d+\.(\d+)\n/ ) {
        return $1;
    }
    if ( $rcsOutput =~ /total revisions: (\d+)\n/ ) {
        return $1;
    }
    return 1;
}

# implements VC::Handler
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
            FILENAME  => $this->{rcsFile},
            CONTEXT   => $contextLines
        );

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
| TODO: | move into VC::Handler and add indirection in Store |

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

sub _ci {
    my ( $this, $comment, $user, $date ) = @_;

    $comment = 'none' unless $comment;

    my ( $cmd, $rcsOutput, $exit );
    if ( defined($date) ) {
        require Foswiki::Time;
        $date = Foswiki::Time::formatTime( $date, '$rcs', 'gmtime' );
        $cmd = $Foswiki::cfg{RCS}{ciDateCmd};
        ( $rcsOutput, $exit ) = Foswiki::Sandbox->sysCommand(
            $cmd,
            USERNAME => $user,
            FILENAME => $this->{file},
            COMMENT  => $comment,
            DATE     => $date
        );
    }
    else {
        $cmd = $Foswiki::cfg{RCS}{ciCmd};
        ( $rcsOutput, $exit ) = Foswiki::Sandbox->sysCommand(
            $cmd,
            USERNAME => $user,
            FILENAME => $this->{file},
            COMMENT  => $comment
        );
    }
    $rcsOutput ||= '';

    if ($exit) {
        throw Error::Simple( $cmd . ' of '
              . $this->hidePath( $this->{file} )
              . ' failed: '
              . $exit . ' '
              . $rcsOutput );
    }

    chmod( $Foswiki::cfg{RCS}{filePermission}, $this->{file} );
}

sub _lock {
    my $this = shift;

    return unless -e $this->{rcsFile};

    # Try and get a lock on the file
    my ( $rcsOutput, $exit ) =
      Foswiki::Sandbox->sysCommand( $Foswiki::cfg{RCS}{lockCmd},
        FILENAME => $this->{file} );

    if ($exit) {

        # if the lock has been set more than 24h ago, let's try to break it
        # and then retry.  Should not happen unless in Cairo upgrade
        # scenarios - see Item2102
        if ( ( time - ( stat( $this->{rcsFile} ) )[9] ) > 3600 ) {
            warn 'Automatic recovery: breaking lock for ' . $this->{file};
            Foswiki::Sandbox->sysCommand( $Foswiki::cfg{RCS}{breaklockCmd},
                FILENAME => $this->{file} );
            ( $rcsOutput, $exit ) =
              Foswiki::Sandbox->sysCommand( $Foswiki::cfg{RCS}{lockCmd},
                FILENAME => $this->{file} );
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
    chmod( $Foswiki::cfg{RCS}{filePermission}, $this->{file} );
}

# implements VC::Handler
sub getRevisionAtTime {
    my ( $this, $date ) = @_;

    unless( -e $this->{rcsFile} ) {
	return ($date >= (stat($this->{file}))[9]) ? 1 : undef;
    }

    require Foswiki::Time;
    my $sdate = Foswiki::Time::formatTime( $date, '$rcs', 'gmtime' );
    my ( $rcsOutput, $exit ) = Foswiki::Sandbox->sysCommand(
        $Foswiki::cfg{RCS}{rlogDateCmd},
        DATE     => $sdate,
        FILENAME => $this->{file}
    );

    my $version = undef;
    if ( $rcsOutput =~ m/revision \d+\.(\d+)/ ) {
        $version = $1;
    }

    if ($version && !$this->noCheckinPending()) {
	# Check the file date
	$version++ if ($date >= (stat($this->{file}))[9]);
    }
    return $version;
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
