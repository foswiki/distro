# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Store::RcsWrap

This package does not publish any methods. It implements the
virtual methods of the =Foswiki::Store::RcsFile= superclass.

Wrapper around the RCS commands required by Foswiki.
There is one of these object for each file stored under RCS.

=cut

package Foswiki::Store::RcsWrap;
use base 'Foswiki::Store::RcsFile';

use strict;
use Assert;

require Foswiki::Store;
require Foswiki::Sandbox;

# implements RcsFile
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

# implements RcsFile
sub initBinary {
    my ($this) = @_;

    $this->{binary} = 1;

    Foswiki::Store::RcsFile::mkPathTo( $this->{file} );

    return if -e $this->{rcsFile};

    my $rcsOutput =
      $this->checkedSysCommand( $Foswiki::cfg{RCS}{initBinaryCmd},
        FILENAME => $this->{file} );

    if ( !-e $this->{rcsFile} ) {

        # Sometimes (on Windows?) rcs file not formed, so check for it
        throw Error::Simple( $Foswiki::cfg{RCS}{initBinaryCmd} . ' of '
              . $this->hidePath( $this->{rcsFile} )
              . ' failed to create history file' );
    }
}

# implements RcsFile
sub initText {
    my ($this) = @_;

    $this->{binary} = 0;

    Foswiki::Store::RcsFile::mkPathTo( $this->{file} );

    return if -e $this->{rcsFile};

    my $rcsOutput = $this->checkedSysCommand(
        $Foswiki::cfg{RCS}{initTextCmd},
        FILENAME => $this->{file} );

    if ( !-e $this->{rcsFile} ) {

        # Sometimes (on Windows?) rcs file not formed, so check for it
        throw Error::Simple( $Foswiki::cfg{RCS}{initTextCmd} . ' of '
              . $this->hidePath( $this->{rcsFile} )
              . ' failed to create history file' );
    }
}

# implements RcsFile
sub addRevisionFromText {
    my ( $this, $text, $comment, $user, $date ) = @_;
    $this->init();

    unless ( -e $this->{rcsFile} ) {
        _lock($this);
        _ci( $this, $comment, $user, $date );
    }
    Foswiki::Store::RcsFile::saveFile( $this, $this->{file}, $text );
    _lock($this);
    _ci( $this, $comment, $user, $date );
}

# implements RcsFile
sub addRevisionFromStream {
    my ( $this, $stream, $comment, $user, $date ) = @_;
    $this->init();

    _lock($this);
    Foswiki::Store::RcsFile::saveStream( $this, $stream );
    _ci( $this, $comment, $user, $date );
}

# implements RcsFile
sub replaceRevision {
    my ( $this, $text, $comment, $user, $date ) = @_;

    my $rev = $this->numRevisions();

    $comment ||= 'none';

    # update repository with same userName and date
    if ( $rev == 1 ) {

        # initial revision, so delete repository file and start again
        unlink $this->{rcsFile};
    }
    else {
        _deleteRevision( $this, $rev );
    }

    Foswiki::Store::RcsFile::saveFile( $this, $this->{file}, $text );
    require Foswiki::Time;
    $date = Foswiki::Time::formatTime( $date, '$rcs', 'gmtime' );

    _lock($this);
    my $rcsOut = $this->checkedSysCommand(
        $Foswiki::cfg{RCS}{ciDateCmd},
        DATE     => $date,
        USERNAME => $user,
        FILENAME => $this->{file},
        COMMENT  => $comment
    );
    chmod( $Foswiki::cfg{RCS}{filePermission}, $this->{file} );
}

# implements RcsFile
sub deleteRevision {
    my ($this) = @_;
    my $rev = $this->numRevisions();
    return undef if ( $rev <= 1 );
    return _deleteRevision( $this, $rev );
}

sub _deleteRevision {
    my ( $this, $rev ) = @_;

    # delete latest revision (unlock (may not be needed), delete revision)
    my $rcsOut = $this->checkedSysCommand(
        $Foswiki::cfg{RCS}{unlockCmd},
        FILENAME => $this->{file} );

    chmod( $Foswiki::cfg{RCS}{filePermission}, $this->{file} );

    $rcsOut = $this->checkedSysCommand(
        $Foswiki::cfg{RCS}{delRevCmd},
        REVISION => '1.' . $rev,
        FILENAME => $this->{file} );

    # Update the checkout
    $rev--;
    $rcsOut = $this->checkedSysCommand(
        $Foswiki::cfg{RCS}{coCmd},
        REVISION => '1.' . $rev,
        FILENAME => $this->{file} );
    Foswiki::Store::RcsFile::saveFile( $this, $this->{file}, $rcsOut );
}

# implements RcsFile
sub getRevision {
    my ( $this, $version ) = @_;

    unless ( $version && -e $this->{rcsFile} ) {
        return $this->SUPER::getRevision($version);
    }

    my ($text, $exit);
    if ( $Foswiki::cfg{RCS}{coMustCopy} ) {

        # SMELL: is this really necessary? What evidence is there?
        # Need to take temporary copy of topic, check it out to file,
        # then read that
        # Need to put RCS into binary mode to avoid extra \r appearing and
        # read from binmode file rather than stdout to avoid early file
        # read termination
        my $coCmd      = $Foswiki::cfg{RCS}{coCmd};
        $coCmd =~ s/-p%REVISION/-r%REVISION/;
        my $tmpfile    = Foswiki::Store::RcsFile::mkTmpFilename();
        my $tmpRevFile = $tmpfile . ',v';
        copy( $this->{rcsFile}, $tmpRevFile );
        $this->checkedSysCommand(
              $Foswiki::cfg{RCS}{tmpBinaryCmd},
              FILENAME => $tmpRevFile );

        $this->checkedSysCommand(
            $coCmd,
            REVISION => '1.' . $version,
            FILENAME => $tmpfile
           );

        $text = Foswiki::Store::RcsFile::readFile( $this, $tmpfile );

        # SMELL: Is untainting really necessary here?
        unlink Foswiki::Sandbox::untaintUnchecked($tmpfile);
        unlink Foswiki::Sandbox::untaintUnchecked($tmpRevFile);
    } else {
        $text = $this->checkedSysCommand(
            $Foswiki::cfg{RCS}{coCmd},
            REVISION => '1.' . $version,
            FILENAME => $this->{file} );
    }

    return $text;
}

# implements RcsFile
sub numRevisions {
    my ($this) = @_;

    unless ( -e $this->{rcsFile} ) {
        return 1 if ( -e $this->{file} );
        return 0;
    }

    my $rcsOutput =
      $this->checkedSysCommand( $Foswiki::cfg{RCS}{histCmd},
        FILENAME => $this->{rcsFile} );

    if ( $rcsOutput =~ /head:\s+\d+\.(\d+)\n/ ) {
        return $1;
    }
    if ( $rcsOutput =~ /total revisions: (\d+)\n/ ) {
        return $1;
    }
    return 1;
}

# implements RcsFile
sub getRevisionInfo {
    my ( $this, $version ) = @_;

    if ( -e $this->{rcsFile} ) {
        if ( !$version || $version > $this->numRevisions() ) {
            $version = $this->numRevisions();
        }
        my $rcsOut = $this->checkedSysCommand(
            $Foswiki::cfg{RCS}{infoCmd},
            REVISION => '1.' . $version,
            FILENAME => $this->{rcsFile}
        );
        if ( $rcsOut =~
                /^.*?date: ([^;]+);  author: ([^;]*);[^\n]*\n([^\n]*)\n/s ) {
            my $user    = $2;
            my $comment = $3;
            require Foswiki::Time;
            my $date = Foswiki::Time::parseTime($1);
            my $rev  = $version;
            if ( $rcsOut =~ /revision 1.([0-9]*)/ ) {
                $rev = $1;
                return ( $rev, $date, $user, $comment );
            }
        }
    }

    return $this->SUPER::getRevisionInfo($version);
}

# implements RcsFile
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
| TODO: | move into RcsFile and add indirection in Store |

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
                    # Implicit untaint OK; data from diff
                    push @diffArray, [ '-', $1, '' ];
                }
                elsif (/^\+(.*)$/) {
                    # Implicit untaint OK; data from diff
                    push @diffArray, [ '+', '', $1 ];
                }
                else {
                    s/^ (.*)$/$1/g;
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
                # Implicit untaint OK; data from diff
                push @diffArray, [ '-', $1, '' ];
            }
            elsif (/^> (.*)$/) {
                # Implicit untaint OK; data from diff
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

    my $rcsOutput;
    if ( defined($date) ) {
        require Foswiki::Time;
        $date = Foswiki::Time::formatTime( $date, '$rcs', 'gmtime' );
        $rcsOutput = $this->checkedSysCommand(
            $Foswiki::cfg{RCS}{ciDateCmd},
            USERNAME => $user,
            FILENAME => $this->{file},
            COMMENT  => $comment,
            DATE     => $date );
    }
    else {
        $rcsOutput = $this->checkedSysCommand(
            $Foswiki::cfg{RCS}{ciCmd},
            USERNAME => $user,
            FILENAME => $this->{file},
            COMMENT  => $comment );
    }
    $rcsOutput ||= '';

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

# implements RcsFile
sub getRevisionAtTime {
    my ( $this, $date ) = @_;

    if ( !-e $this->{rcsFile} ) {
        return undef;
    }
    require Foswiki::Time;
    $date = Foswiki::Time::formatTime( $date, '$rcs', 'gmtime' );
    my $rcsOutput = $this->checkedSysCommand(
        $Foswiki::cfg{RCS}{rlogDateCmd},
        DATE     => $date,
        FILENAME => $this->{file}
    );

    if ( $rcsOutput =~ m/revision \d+\.(\d+)/ ) {
        return $1;
    }
    return 1;
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
