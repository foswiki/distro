# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Store::VC::PlainFileHandler

=cut

package Foswiki::Store::VC::PlainFileHandler;

use strict;
use warnings;
use Assert;

use File::Copy::Recursive ();

use Foswiki::Iterator::NumberRangeIterator ();
use Foswiki::Users::BaseUserMapping;

use Foswiki::Store::VC::Handler ();
our @ISA = ( 'Foswiki::Store::VC::Handler' );

# use the locale if required to ensure sort order is correct
BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

# Override Handler
sub new {
    my ( $class, $store, $web, $topic, $attachment ) = @_;

    my $this = $class->SUPER::new($store, $web, $topic, $attachment);

    undef $this->{numRevisions};

    # GREAT CARE REQUIRED! {rcsFile} refers to a directory, not a
    # single file. Uses of {rcsFile} in the superclass must be
    # monitored to ensure this doesn't break.
    $this->{rcsFile} = "$this->{file}_versions" if $this->{file};

    return $this;
}

# Get the history file for the given revision (or the latest rev if not set_)
# Assume _saveDamage has been called
sub _versionFile {
    my ($this, $version) = @_;
    $version ||= $this->_numRevisions();
    return "$this->{rcsFile}/$version";
}

# Force a checkin when saving damage
sub _forceCheckin {
    my ($this, $rev) = @_;
    $rev = $this->_numRevisions() + 1 unless defined $rev;

    my $t = $this->readFile( $this->{file} );
		
    # If this is a topic, adjust the TOPICINFO
    if ( defined $this->{topic} && !defined $this->{attachment} ) {
	$t =~ s/^%META:TOPICINFO{(.*)}%$//m;
	$t =
	    '%META:TOPICINFO{author="'
	    . $Foswiki::Users::BaseUserMapping::UNKNOWN_USER_CUID
	    . '" comment="autosave" date="'
	    . time()
	    . '" format="1.1" version="'
	    . $rev . '"}%' . "\n$t";
    }

    my $hf = $this->{rcsFile};
    $this->saveFile( "$hf/$rev", $t );
    chmod( $Foswiki::cfg{RCS}{dirPermission}, $hf );
    chmod( $Foswiki::cfg{RCS}{filePermission}, "$hf/$rev" );
    $this->{numRevisions} = $rev;
}

# Override 
# Detect and repair the following states:
# {file} exists but no {rcsFile}
# {file} exists and {rcsFile} exists but {rcsFile} is empty
# {file} exists but is more recent than latest file in {rcsFile}
# {file} does not exist but there is at least one file in {rcsFile}
sub _saveDamage {
    my $this = shift;
    my $d;

    if (-e $this->{file}) {
	my $rev = 1;
	$this->{numRevisions} = 0;
	if (-d $this->{rcsFile}) {
	    # Is there a file in {rcsFile}?
	    opendir($d, $this->{rcsFile}) || die $!;
	    my @revs = sort grep { /^[0-9]+$/ } readdir($d);
	    closedir($d);
	    my $topRev = 0;
	    if (scalar(@revs)) {
		my $topRev = $revs[$#revs];
		$this->{numRevisions} = $topRev;
		my $hf = "$this->{rcsFile}/$topRev";

		# Check the time on the history file; is the .txt newer?
		my $revTime  = ( stat( $hf ) )[9] || time;
		my $fileTime = ( stat( $this->{file} ) )[9];
		return if ( $revTime >= $fileTime ); # up to date
		$rev = $topRev + 1;
	    }
	}
	# No existing revs; create 1
	$this->_forceCheckin($rev);
    } elsif (-d $this->{rcsFile}) {
	# Is there a file in {rcsFile}? If so, grab the latest
	opendir($d, $this->{rcsFile}) || die $!;
	my @revs = sort grep { /^[0-9]+$/ } readdir($d);
	closedir($d);
	if (scalar(@revs)) {
	    my $topRev = $revs[$#revs];
	    $this->{numRevisions} = $topRev;
	    my $hf = "$this->{rcsFile}/$topRev";

	    # move and copy to get the revision times right
	    # (history file must always be same time or newer)
	    File::Copy::move($hf, $this->{file});
	    File::Copy::copy($this->{file}, $hf);
	}
    }
}

# Break circular references.
sub finish {
    my $this = shift;
    $this->SUPER::finish();
    undef $this->{rcsFile};
    undef $this->{numRevisions};
}

# Override Handler::noCheckinPending
# After the function has run the store state should be consistent,
# and so the function always returns 1.
sub noCheckinPending {
    shift->_saveDamage();
    return 1;
}

# Override because superclass treats $this->{rcsFile} as a plain file
sub remove {
    my $this = shift;

    # No need to save damage; we're killing it
    if ($this->{rcsFile} && -e $this->{rcsFile}) {
	Foswiki::Store::VC::Handler::_rmtree( $this->{rcsFile} );
    }
    $this->SUPER::remove();
}

# moveFile and copyFile must handle directories
sub moveFile {
    my ($this, $from, $to) = @_;
    if (-d $from) {
	$this->mkPathTo($to);
	File::Copy::Recursive::dirmove($from, $to);
    } else {
	$this->SUPER::moveFile($from, $to);
    }
}

sub copyFile {
    my ($this, $from, $to) = @_;
    if (-d $from) {
	$this->mkPathTo($to);
	File::Copy::Recursive::dircopy($from, $to);
    } else {
	$this->SUPER::copyFile($from, $to);
    }
}

sub initBinary {}

sub initText {}

# get the number of revisions. Repairs damage on the fly.
sub _numRevisions {
    my ($this) = @_;

    $this->_saveDamage();
    if ( !defined $this->{numRevisions} ) {
	$this->{numRevisions} = 0;
	if (-d $this->{rcsFile}) {
	    my $d;
	    opendir($d, $this->{rcsFile}) || die $!;
	    my @revs = sort grep { /^[0-9]+$/ } readdir($d);
	    closedir($d);
	    $this->{numRevisions} = $revs[$#revs] if (scalar(@revs));
	}
    }
    return $this->{numRevisions};
}

# Check in a new revision, after repairing damage
sub ci {
    my ( $this, $isStream, $data, $log, $author, $date ) = @_;

    my $rn = $this->_numRevisions() + 1;

    if ($isStream) {
        $this->saveStream($data);
        $data = $this->readFile( $this->{file} );
    }
    else {
        $this->saveFile( $this->{file}, $data );
    }

    my $hf = $this->{rcsFile};
    mkdir $hf unless -d $hf;
    chmod( $Foswiki::cfg{RCS}{dirPermission}, $hf );
    $hf .= "/$rn";
    my $out;
    unless ( open( $out, '>', $hf ) ) {
        throw Error::Simple(
            'Cannot open ' . $hf . ' for write: ' . $! );
    }
    else {
	$this->saveFile( $hf, $data );
    }
    chmod( $Foswiki::cfg{RCS}{filePermission}, $hf );
    $this->{numRevisions} = $rn;
}

# implements VC::Handler
sub repRev {
    my ( $this, $text, $comment, $user, $date ) = @_;
    # Reduce the revision count by 1, then check in the data; it will
    # overwrite the existing top revision
    $this->{numRevisions} = $this->_numRevisions() - 1;
    return $this->ci( 0, $text, $comment, $user, $date );
}

# implements VC::Handler
sub deleteRevision {
    my ($this) = @_;

    my $cur = $this->_numRevisions();
    return if $cur == 1; # veto deletion of rev 1
    unlink $this->_versionFile($cur);
    undef $this->{numRevisions};
    $cur = $this->_numRevisions();
    File::Copy::copy($this->_versionFile($cur), $this->{file})
	if -e $this->_versionFile($cur);
}

# implements VC::Handler
# Recovers the two revisions and uses sdiff on them. Simplest way to do
# this operation.
# rev1 is the lower, rev2 is the higher revision
sub revisionDiff {
    my ( $this, $rev1, $rev2, $contextLines ) = @_;
    my @list;
    my ($text1) = $this->getRevision($rev1);
    my ($text2) = $this->getRevision($rev2);

    my $lNew = _split($text1);
    my $lOld = _split($text2);
    require Algorithm::Diff;
    my $diff = Algorithm::Diff::sdiff( $lNew, $lOld );

    foreach my $ele (@$diff) {
        push @list, $ele;
    }
    return \@list;
}

# implements VC::Handler
sub getInfo {
    my ( $this, $version ) = @_;

    $this->_saveDamage();

    # If there is a .txt file, grab the TOPICINFO from it.
    # Note that we only peek at the first line of the file,
    # which is where a "proper" save will have left the tag.
    my $info = {};
    $this->_getTOPICINFO($info, $version) if -e $this->{file};

    $info->{date}    = $this->getTimestamp() unless defined $info->{date};
    $info->{version} = 1                     unless defined $info->{version};
    $info->{comment} = ''                    unless defined $info->{comment};
    $info->{author} ||= $Foswiki::Users::BaseUserMapping::UNKNOWN_USER_CUID;
    return $info;
}

sub getRevision {
    my ( $this, $version ) = @_;
    $this->_saveDamage();
    return (undef, 0) unless -e $this->{file};
    if ($version && $version <= $this->_numRevisions()) {
	my $fn = $this->_versionFile($version);
	return ( $this->readFile( $fn ), $version == $this->_numRevisions());
    }
    # no version given, give latest (may not be checked in yet)
    return ( $this->readFile( $this->{file} ), 1 );
}

sub getRevisionAtTime {
    my ( $this, $date ) = @_;

    $this->_saveDamage();
    my $d;
    return undef unless opendir($d, $this->{rcsFile});
    my @revs = reverse sort grep { /^[0-9]+$/ } readdir($d);
    closedir($d);

    foreach my $rev (@revs) {
        return $rev if ( $date >= ( stat( "$this->{rcsFile}/$rev" ) )[9] );
    }
    return undef;
}

1;
__END__
Module of Foswiki Enterprise Collaboration Platform, http://Foswiki.org/

Author: Crawford Currie

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
