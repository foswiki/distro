# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005-2007 TWiki Contributors. All Rights Reserved. 
# TWiki Contributors are listed in the AUTHORS file in the root of 
# this distribution. NOTE: Please extend that file, not this notice.
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

package TWiki::Store::Subversive;

use strict;
use Assert;

require File::Spec;

require TWiki::Sandbox;

sub new {
    my( $class, $session, $web, $topic, $attachment ) = @_;

    ASSERT($session->isa( 'TWiki')) if DEBUG;
    my $this = bless( {}, $class );
    $this->{session} = $session;

    $this->{web} = $web;

    if( $topic ) {
        $this->{topic} = $topic;

        if( $attachment ) {
            $this->{attachment} = $attachment;

            $this->{file} = $TWiki::cfg{PubDir}.'/'.$web.'/'.
              $this->{topic}.'/'.$attachment;

        } else {
            $this->{file} = $TWiki::cfg{DataDir}.'/'.$web.'/'.
              $topic.'.txt';
        }
    }

    return $this;
}

=begin twiki

---++ ObjectMethod finish()
Break circular references.

=cut

# Note to developers; please undef *all* fields in the object explicitly,
# whether they are references or not. That way this method is "golden
# documentation" of the live fields in the object.
sub finish {
    my $this = shift;
}

sub init {
    my $this = shift;

    return unless $this->{topic};

    unless( -e $this->{file} ) {
        _mkPathTo( $this, $this->{file} );

        unless( open(F, '>'.$this->{file})) {
            throw Error::Simple('svn add of '.$this->{file}.
                                  ' failed: '.$! );
        }
        close(F);

        my ($output, $exit) = $TWiki::sandbox->sysCommand(
            'svn add %FILENAME|F%',
            FILENAME => $this->{file});
        if( $exit ) {
            throw Error::Simple('svn add of '.$this->{file}.
                                  ' failed: '.$output );
        }
    }
}

# Make any missing paths on the way to this file
sub _mkPathTo {
    my( $this, $file) = @_;

    my @components = split( /(\/+)/, $file );
    pop( @components );
    my $path = '';
    for my $dir ( @components ) {
        if( $dir =~ /\/+/ ) {
            $path .= '/';
        } elsif( $path ) {
            if(  ! -e "$path$dir" && -e "$path/.svn" ) {
                my($output, $exit) = TWiki::sandbox->sysCommand(
                    'svn mkdir %FILENAME|F%',
                    FILENAME => $path.$dir);
                if( $exit ) {
                    throw Error::Simple('svn mkdir of '.$path.$dir.
                                          ' failed: '.$output );
                }
            }
            $path .= $dir;
        }
    }
}

=pod

---++ ObjectMethod getRevisionInfo($version) -> ($rev, $date, $user, $comment)

   * =$version= if 0 or undef, or out of range (version number > number of revs) will return info about the latest revision.

Returns (rev, date, user, comment) where rev is the number of the rev for which the info was recovered, date is the date of that rev (epoch s), user is the login name of the user who saved that rev, and comment is the comment associated with the rev.

Designed to be overridden by subclasses, which can call up to this method
if file-based rev info is required.

=cut

sub getRevisionInfo {
    my( $this ) = @_;
    my $fileDate = $this->getTimestamp();
    return ( 1, $fileDate, $TWiki::cfg{DefaultUserLogin},
             'Default revision information' );
}

=pod

---++ ObjectMethod getLatestRevision() -> $text

Get the text of the most recent revision

=cut

sub getLatestRevision {
    my $this = shift;
    return _readFile( $this, $this->{file} );
}

=pod

---++ ObjectMethod getLatestRevisionTime() -> $text

Get the time of the most recent revision

=cut

sub getLatestRevisionTime {
    return (stat shift->{file})[9];
}

=pod

---++ ObjectMethod readMetaData($name) -> $text

Get a meta-data block for this web

=cut

sub readMetaData {
    my( $this, $name ) = @_;
    my $file = $TWiki::cfg{DataDir}.'/'.$this->{web}.'/'.$name;
    if( -e $file ) {
        return _readFile( $this, $file );
    }
    return '';
}

=pod

---++ ObjectMethod saveMetaData( $web, $name ) -> $text

Write a named meta-data string. If web is given the meta-data
is stored alongside a web.

=cut

sub saveMetaData {
    my ( $this, $name, $text ) = @_;

    my $file = $TWiki::cfg{DataDir}.'/'.$this->{web}.'/'.$name;

    return _saveFile( $this, $file, $text );
}

=pod

---++ ObjectMethod getTopicNames() -> @topics

Get list of all topics in a web
   * =$web= - Web name, required, e.g. ='Sandbox'=
Return a topic list, e.g. =( 'WebChanges',  'WebHome', 'WebIndex', 'WebNotify' )=

=cut

sub getTopicNames {
    my $this = shift;

    opendir DIR, $TWiki::cfg{DataDir}.'/'.$this->{web};
    # the name filter is used to ensure we don't return filenames
    # that contain illegal characters as topic names.
    my @topicList =
      sort
        map { TWiki::Sandbox::untaintUnchecked( $_ ) }
          grep { !/$TWiki::cfg{NameFilter}/ && s/\.txt$// }
            readdir( DIR );
    closedir( DIR );
    return @topicList;
}

=pod

---++ ObjectMethod getWebNames() -> @webs

Gets a list of names of subwebs in the current web

=cut

sub getWebNames {
    my $this = shift;
    my $dir = $TWiki::cfg{DataDir}.'/'.$this->{web};
    if( opendir( DIR, $dir ) ) {
        my @tmpList =
          grep { !/$TWiki::cfg{NameFilter}/ &&
                   !/^\./ &&
                     -d $dir.'/'.$_ } readdir( DIR );
        closedir( DIR );
        return @tmpList;
    }
    return ();
}

=pod

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
    my( $this, $searchString, $topics, $options ) = @_;
    ASSERT(defined $options) if DEBUG;
    my $type = $options->{type} || '';

    # I18N: 'grep' must use locales if needed,
    # for case-insensitive searching.  See TWiki::setupLocale.
    my $program = '';
    # FIXME: For Cygwin grep, do something about -E and -F switches
    # - best to strip off any switches after first space in
    # EgrepCmd etc and apply those as argument 1.
    if( $type eq 'regex' ) {
        $program = $TWiki::cfg{RCS}{EgrepCmd};
    } else {
        $program = $TWiki::cfg{RCS}{FgrepCmd};
    }

    $program =~ s/%CS{(.*?)\|(.*?)}%/$options->{casesensitive}?$1:$2/ge;
    $program =~ s/%DET{(.*?)\|(.*?)}%/$options->{files_without_match}?$2:$1/ge;

    my $sDir = $TWiki::cfg{DataDir}.'/'.$this->{web}.'/';
    my $seen = {};
    # process topics in sets, fix for Codev.ArgumentListIsTooLongForSearch
    my $maxTopicsInSet = 512; # max number of topics for a grep call
    my @take = @$topics;
    my @set = splice( @take, 0, $maxTopicsInSet );
    while( @set ) {
        @set = map { "$sDir/$_.txt" } @set;
        my ($matches, $exit ) = $TWiki::sandbox->sysCommand(
            $program,
            TOKEN => $searchString,
            FILES => \@set);
        foreach my $match ( split( /\r?\n/, $matches )) {
            if( $match =~ m/([^\/]*)\.txt(:(.*))?$/ ) {
                push( @{$seen->{$1}}, $3 );
            }
        }
        @set = splice( @take, 0, $maxTopicsInSet );
    }
    return $seen;
}

=pod

---++ ObjectMethod moveWeb(  $newWeb )

Move a web.

=cut

sub moveWeb {
    my( $this, $newWeb ) = @_;
    _moveFile( $this, $TWiki::cfg{DataDir}.'/'.$this->{web},
               $TWiki::cfg{DataDir}.'/'.$newWeb );
    if( -d $TWiki::cfg{PubDir}.'/'.$this->{web} ) {
        _moveFile( $this, $TWiki::cfg{PubDir}.'/'.$this->{web},
                   $TWiki::cfg{PubDir}.'/'.$newWeb );
    }
}

=pod

---++ ObjectMethod getRevision($version) -> $text

   * =$version= if 0 or undef, or out of range (version number > number of revs) will return the latest revision.

Get the text of the given revision.

Designed to be overridden by subclasses, which can call up to this method
if the main file revision is required.

=cut

sub getRevision {
    my( $this ) = @_;
    return _readFile( $this, $this->{file} );
}

=pod

---++ ObjectMethod storedDataExists() -> $boolean

Establishes if there is stored data associated with this handler.

=cut

sub storedDataExists {
    my $this = shift;
    return -e $this->{file};
}

=pod

---++ ObjectMethod getTimestamp() -> $integer

Get the timestamp of the file
Returns 0 if no file, otherwise epoch seconds

=cut

sub getTimestamp {
    my( $this ) = @_;
    my $date = 0;
    if( -e $this->{file} ) {
        # SMELL: Why big number if fail?
        $date = (stat $this->{file})[9] || 600000000;
    }
    return $date;
}

=pod

---++ ObjectMethod restoreLatestRevision()

Restore the plaintext file from the revision at the head.

=cut

sub restoreLatestRevision {
    my( $this ) = @_;

    my $rev = $this->numRevisions();
    my $text = $this->getRevision( $rev );

    return _saveFile( $this, $this->{file}, $text );
}

=pod

---++ ObjectMethod removeWeb( $web )

   * =$web= - web being removed

Destroy a web, utterly. Removed the data and attachments in the web.

Use with great care! No backup is taken!

=cut

sub removeWeb {
    my $this = shift;

    # Just make sure of the context
    ASSERT(!$this->{topic}) if DEBUG;

    _rmtree( $this, $TWiki::cfg{DataDir}.'/'.$this->{web} );
    _rmtree( $this, $TWiki::cfg{PubDir}.'/'.$this->{web} );
}

=pod

---++ ObjectMethod moveTopic( $newWeb, $newTopic )

Move/rename a topic.

=cut

sub moveTopic {
    my( $this, $newWeb, $newTopic ) = @_;

    my $oldWeb = $this->{web};
    my $oldTopic = $this->{topic};

    # Move data file
    my $new = new TWiki::Store::Subversive( $this->{session},
                                            $newWeb, $newTopic, '' );
    _moveFile( $this, $this->{file}, $new->{file} );

    # Move attachments
    my $from = $TWiki::cfg{PubDir}.'/'.$this->{web}.'/'.$this->{topic};
    if( -e $from ) {
        my $to = $TWiki::cfg{PubDir}.'/'.$newWeb.'/'.$newTopic;
        _moveFile( $this, $from, $to );
    }
}

=pod

---++ ObjectMethod copyTopic( $newWeb, $newTopic )

Copy a topic.

=cut

sub copyTopic {
    my( $this, $newWeb, $newTopic ) = @_;

    my $oldWeb = $this->{web};
    my $oldTopic = $this->{topic};

    my $new = new TWiki::Store::Subversive( $this->{session},
                                         $newWeb, $newTopic, '' );

    _copyFile( $this, $this->{file}, $new->{file} );

    if( opendir(DIR, $TWiki::cfg{PubDir}.'/'.$this->{web}.'/'.
                  $this->{topic} )) {
        for my $att ( grep { !/^\./ } readdir DIR ) {
            $att = TWiki::Sandbox::untaintUnchecked( $att );
            my $oldAtt = new TWiki::Store::Subversive(
                $this->{session}, $this->{web}, $this->{topic}, $att );
            $oldAtt->copyAttachment( $newWeb, $newTopic );
        }

        closedir DIR;
    }
}

sub moveAttachment {
    my( $this, $newWeb, $newTopic, $newAttachment ) = @_;

    # FIXME might want to delete old directories if empty
    my $new = TWiki::Store::Subversive->new( $this->{session}, $newWeb,
                                          $newTopic, $newAttachment );

    _moveFile( $this, $this->{file}, $new->{file} );
}

sub copyAttachment {
    my( $this, $newWeb, $newTopic ) = @_;

    my $oldWeb = $this->{web};
    my $oldTopic = $this->{topic};
    my $attachment = $this->{attachment};

    my $new = TWiki::Store::Subversive->new( $this->{session}, $newWeb,
                                          $newTopic, $attachment );

    _copyFile( $this, $this->{file}, $new->{file} );
}

=pod

---++ ObjectMethod isAsciiDefault (   ) -> $boolean

Check if this file type is known to be an ascii type file.

=cut

sub isAsciiDefault {
    my $this = shift;
    return ( $this->{attachment} =~
               /$TWiki::cfg{RCS}{asciiFileSuffixes}/ );
}

sub setLock {
}

sub isLocked {
    return ( undef, undef );
}

sub setLease {
}

sub getLease {
    return undef;
}

sub _saveStream {
    my( $this, $fh ) = @_;

    ASSERT($fh) if DEBUG;

    _mkPathTo( $this, $this->{file} );
    open( F, '>'.$this->{file} ) ||
        throw Error::Simple( 'RCS: open '.$this->{file}.' failed: '.$! );
    binmode( F ) ||
      throw Error::Simple( 'RCS: failed to binmode '.$this->{file}.': '.$! );
    my $text;
    binmode(F);
    while( read( $fh, $text, 1024 )) {
        print F $text;
    }
    close(F) ||
        throw Error::Simple( 'RCS: close '.$this->{file}.' failed: '.$! );;

    chmod( $TWiki::cfg{RCS}{filePermission}, $this->{file} );

    return '';
}

sub _copyFile {
    my( $this, $from, $to ) = @_;

    _mkPathTo( $this, $to );

    my($output, $exit) = $TWiki::sandbox->sysCommand(
        'svn cp %FROM|F% %TO|F%',
        FROM => $from, TO => $to);
    if( $exit ) {
        throw Error::Simple( 'Subversive: copy '.$from.
                               ' to '.$to.' failed: '.$! );
    }
}

sub _moveFile {
    my( $this, $from, $to ) = @_;

    _mkPathTo( $this, $to );
    my($output, $exit) = $TWiki::sandbox->sysCommand(
        'svn mv %FROM|F% %TO|F%',
        FROM => $from, TO => $to);
    if( $exit ) {
        throw Error::Simple( 'Subversive: move '.$from.
                               ' to '.$to.' failed: '.$! );
    }
}

sub _saveFile {
    my( $this, $name, $text ) = @_;

    _mkPathTo( $this, $name );

    open( FILE, '>'.$name ) ||
      throw Error::Simple( 'RCS: failed to create file '.$name.': '.$! );
    binmode( FILE ) ||
      throw Error::Simple( 'RCS: failed to binmode '.$name.': '.$! );
    print FILE $text;
    close( FILE) ||
      throw Error::Simple( 'RCS: failed to create file '.$name.': '.$! );

    return undef;
}

sub _readFile {
    my( $this, $name ) = @_;
    my $data;
    if( open( IN_FILE, '<'.$name )) {
        binmode( IN_FILE );
        local $/ = undef;
        $data = <IN_FILE>;
        close( IN_FILE );
    }
    $data ||= '';
    return $data;
}

sub _mkTmpFilename {
    my $tmpdir = File::Spec->tmpdir();
    my $file = _mktemp( 'twikiAttachmentXXXXXX', $tmpdir );
    return File::Spec->catfile($tmpdir, $file);
}

# Adapted from CPAN - File::MkTemp
sub _mktemp {
    my ($template,$dir,$ext,$keepgen,$lookup);
    my (@template,@letters);

    ASSERT(@_ == 1 || @_ == 2 || @_ == 3) if DEBUG;

    ($template,$dir,$ext) = @_;
    @template = split //, $template;

    ASSERT($template =~ /XXXXXX$/) if DEBUG;

    if ($dir){
        ASSERT(-e $dir) if DEBUG;
    }

    @letters =
      split(//,'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ');

    $keepgen = 1;

    while ($keepgen){
        for (my $i = $#template; $i >= 0 && ($template[$i] eq 'X'); $i--){
            $template[$i] = $letters[int(rand 52)];
        }

        undef $template;

        $template = pack 'a' x @template, @template;

        $template = $template . $ext if ($ext);

        if ($dir){
            $lookup = File::Spec->catfile($dir, $template);
            $keepgen = 0 unless (-e $lookup);
        } else {
            $keepgen = 0;
        }

        next if $keepgen == 0;
    }

    return($template);
}

sub _rmtree {
    my ($this, $root) = @_;

    my ($output, $exit) = $TWiki::sandbox->sysCommand(
        'svn rm %FILENAME|F%',
        FILENAME => $root);
    if( $exit ) {
        throw Error::Simple('svn rm of '.$root.' failed: '.$output );
    }
}

sub getStream {
    my( $this ) = shift;
    my $strm;
    unless( open( $strm, '<'.$this->{file} )) {
        throw Error::Simple( 'RCS: stream open '.$this->{file}.
                               ' failed: '.$! );
    }
    return $strm;
}

sub addRevisionFromText {
    my( $this, $text, $comment, $user, $date ) = @_;
    $this->init();

    _saveFile( $this, $this->{file}, $text );
}

sub addRevisionFromStream {
    my( $this, $stream, $comment, $user, $date ) = @_;
    $this->init();

    _saveStream( $this, $stream );
}

sub replaceRevision {
    throw Error::Simple("Not implemented");
}


sub deleteRevision {
    throw Error::Simple("Not implemented");
}

sub numRevisions {
    my $this = shift;

    my($output, $exit) = $TWiki::sandbox->sysCommand(
        'svn info %FILE|F%',
        FILE => $this->{file} );
    if( $exit ) {
        throw Error::Simple( 'Subversive: info failed: '.$! );
    }
    $output =~ /^Revision: (\d+)$/m;
    return $1 || 1;
}

sub revisionDiff {
    my( $this, $rev1, $rev2, $contextLines ) = @_;
    my $nr = $this->numRevisions();

    $rev1 = 1 if ( $rev1 < 1 );
    $rev1 = 'WORKING' if( $rev1 > $nr );
    $rev2 = 1 if ( $rev2 < 1 );
    $rev2 = 'WORKING' if( $rev2 > $nr );
    my $ft = "$rev1:$rev2";
    $ft = $rev2 if( $rev1 eq 'WORKING' );
    $ft = $rev1 if( $rev2 eq 'WORKING' );

    if( $rev1 == $rev2 || $ft eq 'WORKING' ) {
        return [];
    }

    my($output, $exit) = $TWiki::sandbox->sysCommand(
        'svn diff -r%FT|U% --non-interactive %FILE|F%',
        FT => $ft,
        FILE => $this->{file} );
    if( $exit ) {
        throw Error::Simple( 'Subversive: diff failed: '.$! );
    }
    $output =~ s/\nProperty changes on:.*$//s;
    require TWiki::Store::RcsWrap;
    return TWiki::Store::RcsWrap::parseRevisionDiff( "---\n".$output );
}

sub getRevisionAtTime {
    throw Error::Simple("Not implemented");
}

=pod

---++ ObjectMethod getAttachmentAttributes($web, $topic, $attachment)

returns [stat] for any given web, topic, $attachment
SMELL - should this return a hash of arbitrary attributes so that 
SMELL + attributes supported by the underlying filesystem are supported
SMELL + (eg: windows directories supporting photo "author", "dimension" fields)

=cut

sub getAttachmentAttributes {
	my( $this, $web, $topic, $attachment ) = @_;
    throw Error::Simple("AutoAttachments are not implemented on the Subversive store");

    ASSERT(defined $attachment) if DEBUG;
	
	my $dir = dirForTopicAttachments($web, $topic);
   	my @stat = stat ($dir."/".$attachment);

	return @stat;
}

=pod

---++ ObjectMethod getAttachmentList($web, $topic)

returns @($attachmentName => [stat]) for any given web, topic

=cut

sub getAttachmentList {
	my( $this, $web, $topic ) = @_;
	
    throw Error::Simple("AutoAttachments are not implemented on the Subversive store");
    	
	my $dir = dirForTopicAttachments($web, $topic);
    opendir DIR, $dir || return '';
    my %attachmentList;
    my @files = sort grep { m/^[^\.*_]/ } readdir( DIR );
    @files = grep { !/.*,v/ } @files;
    foreach my $attachment ( @files ) {
    	my @stat = stat ($dir."/".$attachment);
        $attachmentList{$attachment} = \@stat;
    }
    closedir( DIR );
    return %attachmentList;
}

sub dirForTopicAttachments {
   my ($web, $topic ) = @_;
   return $TWiki::cfg{PubDir}.'/'.$web.'/'.$topic;
}

1;
