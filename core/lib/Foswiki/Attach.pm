# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Attach

A singleton object of this class is used to deal with attachments to topics.

=cut

package Foswiki::Attach;

use strict;
use warnings;
use Assert;
use Unicode::Normalize;

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

our $MARKER = "\0";

=begin TML

---++ ClassMethod new($session)

Constructor.

=cut

sub new {
    my ( $class, $session ) = @_;
    my $this = bless( { session => $session }, $class );

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
    undef $this->{session};
}

=begin TML

---++ ObjectMethod renderMetaData( $topicObject, $args ) -> $text

Generate a table of attachments suitable for the bottom of a topic
view, using templates for the header, footer and each row.
   * =$topicObject= the topic
   * =$args= hash of attachment arguments
   
Renders these tokens for each attachment:
   * %<nop>A_ATTRS% - attributes
   * %<nop>A_COMMENT% - comment
   * %<nop>A_DATE% - upload date in user friendly format
   * %<nop>A_EPOCH% - upload date in epoch seconds
   * %<nop>A_EFILE% - encoded file name
   * %<nop>A_EXT% - file extension
   * %<nop>A_FILE% - file name
   * %<nop>A_FILESIZE% - filesize in bytes to be used in sorting
   * %<nop>A_ICON% - =%<nop>ICON{}%= macro around file extension
   * %<nop>A_REV% - revision
   * %<nop>A_SIZE% - filesize in user friendly notation
   * %<nop>A_URL% - attachment file url 
   * %<nop>A_USER% - user who has uploaded the last version in 'web.usertopic' notation
   * %<nop>A_USERNAME% - user who has uploaded the last version in 'usertopic' notation
   * %<nop>A_COUNT% - attachment number (starting from 1)

Renders these row helper tokens:
   * %<nop>R_STARTROW_N% - where N is the desired number of attachments in a row; true if a new row should be started
   * %<nop>R_ENDROW_N% - where N is the desired number of attachments in a row; true if a row should be closed
=cut

sub renderMetaData {
    my ( $this, $topicObject, $attrs ) = @_;

    my $showAll = $attrs->{all} || '';
    my $showAttr = $showAll    ? 'h'  : '';
    my $A        = ($showAttr) ? ':A' : '';
    my $title    = $attrs->{title}    || '';
    my $tmplname = $attrs->{template} || 'attachtables';

    my @attachments = $topicObject->find('FILEATTACHMENT');
    return '' unless @attachments;

    my $templates = $this->{session}->templates;
    $templates->readTemplate($tmplname);

    my $rows            = '';
    my $row             = $templates->expandTemplate( 'ATTACH:files:row' . $A );
    my $attachmentCount = scalar(@attachments);
    my $attachmentNum   = 1;
    foreach my $attachment (
        sort { ( NFKD( $a->{name} ) || '' ) cmp( NFKD( $b->{name} ) || '' ) }
        @attachments )
    {
        my $attrAttr = $attachment->{attr};

        if ( !$attrAttr || ( $showAttr && $attrAttr =~ m/^[$showAttr]*$/ ) ) {
            $rows .=
              _formatRow( $this, $topicObject, $attachment, $row,
                $attachmentNum, ( $attachmentNum == $attachmentCount ) );
            $attachmentNum++;
        }
        else {
            # not a visible attachment
            $attachmentCount--;
        }
    }

    my $text = '';

    if ( $showAll || $rows ne '' ) {
        my $header = $templates->expandTemplate( 'ATTACH:files:header' . $A );
        my $footer = $templates->expandTemplate( 'ATTACH:files:footer' . $A );

        $text = $header . $rows . $footer;
    }
    return $title . $text;
}

=begin TML

---++ ObjectMethod formatVersions ( $topicObject, $attrs ) -> $text

Generate a version history table for a single attachment
   * =$topicObject= - the topic
   * =$attrs= - Hash of meta-data attributes

=cut

sub formatVersions {
    my ( $this, $topicObject, %attrs ) = @_;

    my $users = $this->{session}->{users};

    $attrs{name} =
      Foswiki::Sandbox::untaint( $attrs{name},
        \&Foswiki::Sandbox::validateAttachmentName );

    my $revIt = $topicObject->getRevisionHistory( $attrs{name} );

    my $templates = $this->{session}->templates;
    $templates->readTemplate('attachtables');

    my $header = $templates->expandTemplate('ATTACH:versions:header');
    my $footer = $templates->expandTemplate('ATTACH:versions:footer');
    my $row    = $templates->expandTemplate('ATTACH:versions:row');

    my @rows;
    my $attachmentNum = 1;

    while ( $revIt->hasNext() ) {
        my $rev = $revIt->next();
        my $info = $topicObject->getRevisionInfo( $attrs{name}, $rev );
        $info->{name} = $attrs{name};
        $info->{attr} = $attrs{attr};
        $info->{size} = $attrs{size};

        push(
            @rows,
            _formatRow(
                $this, $topicObject,   $info,
                $row,  $attachmentNum, $revIt->hasNext()
            )
        );
        $attachmentNum++;
    }

    return $header . join( '', @rows ) . $footer;
}

#Format a single row in an attachment table by expanding a template.
#| =$web= | the web |
#| =$topic= | the topic |
#| =$info= | hash containing fields name, user (user (not wikiname) who uploaded this revision), date (date of _this revision_ of the attachment), command and version  (the required revision; required to be a full (major.minor) revision number) |
#| =$tmpl= | The template of a row |
#| =$attachmentNum= | The sequential number of this attachment (starting with 1) |
#| =$isLast= | True if this is the last attachment |
sub _formatRow {
    my ( $this, $topicObject, $info, $tmpl, $attachmentNum, $isLast ) = @_;

    my $row = $tmpl;

    $row =~
s/%A_(\w+)%/_expandAttrs( $this, $1, $topicObject, $info, $attachmentNum)/ge;
    $row =~
s/%R_(\w+)%/_expandRowAttrs( $this, $1, $topicObject, $info, $attachmentNum, $isLast)/ge;
    $row =~ s/$MARKER/%/go;

    return $row;
}

sub _expandAttrs {
    my ( $this, $attr, $topicObject, $info, $attachmentNum ) = @_;
    my $file = $info->{name} || '';
    my $users = $this->{session}->{users};

    require Foswiki::Time;

    if ( $attr eq 'REV' ) {
        return $info->{version};
    }
    elsif ( $attr eq 'ICON' ) {
        return '%ICON{"' . $file . '" default="else"}%';
    }
    elsif ( $attr eq 'EXT' ) {

        # $fileExtension is used to map the attachment to its MIME type
        # only grab the last extension in case of multiple extensions
        $file =~ m/\.([^.]*)$/;
        return $1;
    }
    elsif ( $attr eq 'URL' ) {
        return $this->{session}->getScriptUrl(
            0, 'viewfile', $topicObject->web, $topicObject->topic,
            rev => $info->{version} || undef,
            filename => $file
        );
    }
    elsif ( $attr eq 'FILESIZE' ) {
        return $info->{size};
    }
    elsif ( $attr eq 'SIZE' ) {

        # size in user friendly notation
        my $attrSize = $info->{size};
        $attrSize = 1 if ( !$attrSize || $attrSize < 1 );
        return _formatFileSize( $attrSize, 0, ' ' );
    }
    elsif ( $attr eq 'COMMENT' ) {
        my $comment = $info->{comment};
        if ($comment) {
            $comment =~ s/\|/&#124;/g;
        }
        else {
            $comment = '';
        }
        return $comment;
    }
    elsif ( $attr eq 'ATTRS' ) {
        if ( $info->{attr} ) {
            return $info->{attr};
        }
        else {
            return "&nbsp;";
        }
    }
    elsif ( $attr eq 'FILE' ) {
        return $file;
    }
    elsif ( $attr eq 'EFILE' ) {

        # Really aggressive URL encoding, required to protect wikiwords
        # See Bugs:Item3289, Bugs:Item3623
        $file =~ s/([^A-Za-z0-9])/'%'.sprintf('%02x',ord($1))/ge;
        return $file;
    }
    elsif ( $attr eq 'DATE' ) {
        return Foswiki::Time::formatTime( $info->{date} || 0 );
    }
    elsif ( $attr eq 'EPOCH' ) {
        return $info->{date} || 0;
    }
    elsif ( $attr eq 'USER' ) {
        return $users->webDotWikiName( $this->_cUID($info) );
    }
    elsif ( $attr eq 'USERNAME' ) {
        return $users->getWikiName( $this->_cUID($info) );
    }
    elsif ( $attr eq 'COUNT' ) {
        return $attachmentNum;
    }
    else {
        return $MARKER . 'A_' . $attr . $MARKER;
    }
}

sub _expandRowAttrs {
    my ( $this, $attr, $topicObject, $info, $attachmentNum, $isLast ) = @_;

    my $num = $attachmentNum - 1;

    if ( $attr =~ s/STARTROW_(\d+)/$num % $1 == 0/ge ) {
        return $attr;
    }
    elsif ( $attr =~ s/ENDROW_(\d+)/$isLast || $num % $1 == ($1 - 1)/ge ) {
        return $attr;
    }
}

sub _cUID {
    my ( $this, $info ) = @_;

    my $users = $this->{session}->{users};
    my $user = $info->{author} || $info->{user} || 'UnknownUser';
    my $cUID;
    if ($user) {
        $cUID = $users->getCanonicalUserID($user);
        if ( !$cUID ) {

            # Not a login name or a wiki name. Is it a valid cUID?
            my $ln = $users->getLoginName($user);
            $cUID = $user if defined $ln && $ln ne 'unknown';
        }
    }
    return $cUID;
}

# prints the filesize in user friendly format
sub _formatFileSize {

    my $fs  = $_[0];         # First variable is the size in bytes
    my $dp  = $_[1];         # Number of decimal places required
    my $sep = $_[2] || '';
    my @units = ( 'bytes', 'K', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB' );
    my $u     = 0;
    $dp = ( $dp > 0 ) ? 10**$dp : 1;
    while ( $fs >= 1024 ) {
        $fs /= 1024;
        $u++;
    }
    if ( $units[$u] ) {
        my $size = int( $fs * $dp ) / $dp;
        my $unit = $units[$u];
        if ( $u == 0 && $size == 1 ) {

            # single byte
            $unit = 'byte';
        }
        return "$size$sep$unit";
    }
    else {
        return int($fs);
    }
}

=begin TML

---++ ObjectMethod getAttachmentLink( $topicObject, $name ) -> $html

   * =$topicObject= - The topic
   * =$name= - Name of the attachment

Build a link to the attachment, suitable for insertion in the topic.

=cut

sub getAttachmentLink {
    my ( $this, $topicObject, $attName ) = @_;

    my $att         = $topicObject->get( 'FILEATTACHMENT', $attName );
    my $fileComment = $att->{comment};
    my $fileTime    = $att->{date} || 0;
    $fileComment = $attName unless ($fileComment);
    my ($fileExt) = $attName =~ m/(?:.*\.)*([^.]*)/;
    $fileExt ||= '';

    my $fileLink = '';
    my $imgSize  = '';
    my $prefs    = $this->{session}->{prefs};

    if ( $attName =~ m/\.(gif|jpg|jpeg|png)$/i ) {

        # inline image

        # The pixel size calculation is done for performance reasons
        # Some browsers wait with rendering a page until the size of
        # embedded images is known, e.g. after all images of a page are
        # downloaded. When you upload an image to Foswiki and checkmark
        # the link checkbox, Foswiki will generate the width and height
        # img parameters, speeding up the page rendering.
        my $stream = $topicObject->openAttachment( $attName, '<' );
        my ( $nx, $ny ) = _imgsize( $stream, $attName );
        $stream->close();
        my %attrs;

        if ( $nx > 0 && $ny > 0 ) {
            $attrs{width}  = $nx;
            $attrs{height} = $ny;
            $imgSize       = "width='$nx' height='$ny'";
        }

        $fileLink = $prefs->getPreference('ATTACHEDIMAGEFORMAT');
        unless ($fileLink) {
            $attrs{src} = "%ATTACHURLPATH%/$attName";
            $attrs{alt} = $attName;
            return "   * $fileComment: " . CGI::br() . CGI::img( \%attrs );
        }
    }
    else {

        # normal attached file
        $fileLink = $prefs->getPreference('ATTACHEDFILELINKFORMAT');
        unless ($fileLink) {
            return "   * [[%ATTACHURL%/$attName][$attName]]: $fileComment";
        }
    }

    # I18N: Site specified %ATTACHEDIMAGEFORMAT% or %ATTACHEDFILELINKFORMAT%,
    # ensure that filename is URL encoded - first $name must be URL.
    $fileLink =~ s/\$name/$attName/;        # deprecated
    $fileLink =~ s/\$name/$attName/;        # deprecated, see Item1814
    $fileLink =~ s/\$filename/$attName/g;
    $fileLink =~ s/\$fileurl/$attName/g;
    $fileLink =~ s/\$fileext/$fileExt/;

    # Expand \t and \n early (only in the format, not
    # in the comment) - TWikibug:Item4581
    $fileLink =~ s/\\t/\t/g;
    $fileLink =~ s/\\n/\n/g;
    $fileLink =~ s/\$comment/$fileComment/g;
    $fileLink =~ s/\$size/$imgSize/g;
    $fileLink =~ s/([^\n])$/$1\n/;

    require Foswiki::Time;
    $fileLink = Foswiki::Time::formatTime( $fileTime, $fileLink );
    $fileLink = Foswiki::expandStandardEscapes($fileLink);

    return $fileLink;
}

# code fragment to extract pixel size from images
# taken from http://www.tardis.ed.ac.uk/~ark/wwwis/
# subroutines: _imgsize, _gifsize, _OLDgifsize, _gif_blockskip,
#              _NEWgifsize, _jpegsize
#
sub _imgsize {
    my ( $file, $att ) = @_;
    my ( $x, $y ) = ( 0, 0 );

    if ( defined($file) ) {
        binmode($file);    # For Windows
        my $s;
        return ( 0, 0 ) unless ( read( $file, $s, 4 ) == 4 );
        seek( $file, 0, 0 );
        if ( $s eq 'GIF8' ) {

            #  GIF 47 49 46 38
            ( $x, $y ) = _gifsize($file);
        }
        else {
            my ( $a, $b, $c, $d ) = unpack( 'C4', $s );
            if (   $a == 0x89
                && $b == 0x50
                && $c == 0x4E
                && $d == 0x47 )
            {

                #  PNG 89 50 4e 47
                ( $x, $y ) = _pngsize($file);
            }
            elsif ($a == 0xFF
                && $b == 0xD8
                && $c == 0xFF
                && ( $d == 0xE0 || $d == 0xE1 ) )
            {

                #  JPG ff d8 ff e0/e1
                ( $x, $y ) = _jpegsize($file);
            }
        }
        close($file);
    }
    return ( $x, $y );
}

sub _gifsize {
    my ($GIF) = @_;
    if (0) {
        return &_NEWgifsize($GIF);
    }
    else {
        return &_OLDgifsize($GIF);
    }
}

sub _OLDgifsize {
    my ($GIF) = @_;
    my ( $type, $a, $b, $c, $d, $s ) = ( 0, 0, 0, 0, 0, 0 );

    if (   defined($GIF)
        && read( $GIF, $type, 6 )
        && $type =~ m/GIF8[7,9]a/
        && read( $GIF, $s, 4 ) == 4 )
    {
        ( $a, $b, $c, $d ) = unpack( 'C' x 4, $s );
        return ( $b << 8 | $a, $d << 8 | $c );
    }
    return ( 0, 0 );
}

# part of _NEWgifsize
sub _gif_blockskip {
    my ( $GIF, $skip, $type ) = @_;
    my ($s)     = 0;
    my ($dummy) = '';

    read( $GIF, $dummy, $skip );    # Skip header (if any)
    while (1) {
        if ( eof($GIF) ) {

            #warn "Invalid/Corrupted GIF (at EOF in GIF $type)\n";
            return '';
        }
        read( $GIF, $s, 1 );        # Block size
        last if ord($s) == 0;       # Block terminator
        read( $GIF, $dummy, ord($s) );    # Skip data
    }
}

# this code by "Daniel V. Klein" <dvk@lonewolf.com>
sub _NEWgifsize {
    my ($GIF) = @_;
    my ( $cmapsize, $a, $b, $c, $d, $e ) = 0;
    my ( $type, $s ) = ( 0, 0 );
    my ( $x,    $y ) = ( 0, 0 );
    my ($dummy) = '';

    return ( $x, $y ) if ( !defined $GIF );

    read( $GIF, $type, 6 );
    if ( $type !~ /GIF8[7,9]a/ || read( $GIF, $s, 7 ) != 7 ) {

        #warn "Invalid/Corrupted GIF (bad header)\n";
        return ( $x, $y );
    }
    ($e) = unpack( "x4 C", $s );
    if ( $e & 0x80 ) {
        $cmapsize = 3 * 2**( ( $e & 0x07 ) + 1 );
        if ( !read( $GIF, $dummy, $cmapsize ) ) {

            #warn "Invalid/Corrupted GIF (global color map too small?)\n";
            return ( $x, $y );
        }
    }
  FINDIMAGE:
    while (1) {
        if ( eof($GIF) ) {

            #warn "Invalid/Corrupted GIF (at EOF w/o Image Descriptors)\n";
            return ( $x, $y );
        }
        read( $GIF, $s, 1 );
        ($e) = unpack( 'C', $s );
        if ( $e == 0x2c ) {    # Image Descriptor (GIF87a, GIF89a 20.c.i)
            if ( read( $GIF, $s, 8 ) != 8 ) {

                #warn "Invalid/Corrupted GIF (missing image header?)\n";
                return ( $x, $y );
            }
            ( $a, $b, $c, $d ) = unpack( "x4 C4", $s );
            $x = $b << 8 | $a;
            $y = $d << 8 | $c;
            return ( $x, $y );
        }
        if ( $type eq 'GIF89a' ) {
            if ( $e == 0x21 ) {    # Extension Introducer (GIF89a 23.c.i)
                read( $GIF, $s, 1 );
                ($e) = unpack( 'C', $s );
                if ( $e == 0xF9 ) { # Graphic Control Extension (GIF89a 23.c.ii)
                    read( $GIF, $dummy, 6 );    # Skip it
                    next FINDIMAGE;    # Look again for Image Descriptor
                }
                elsif ( $e == 0xFE ) {    # Comment Extension (GIF89a 24.c.ii)
                    &_gif_blockskip( $GIF, 0, 'Comment' );
                    next FINDIMAGE;       # Look again for Image Descriptor
                }
                elsif ( $e == 0x01 ) {    # Plain Text Label (GIF89a 25.c.ii)
                    &_gif_blockskip( $GIF, 12, 'text data' );
                    next FINDIMAGE;       # Look again for Image Descriptor
                }
                elsif ( $e == 0xFF )
                {    # Application Extension Label (GIF89a 26.c.ii)
                    &_gif_blockskip( $GIF, 11, 'application data' );
                    next FINDIMAGE;    # Look again for Image Descriptor
                }
                else {

           #printf STDERR "Invalid/Corrupted GIF (Unknown extension %#x)\n", $e;
                    return ( $x, $y );
                }
            }
            else {

                #printf STDERR "Invalid/Corrupted GIF (Unknown code %#x)\n", $e;
                return ( $x, $y );
            }
        }
        else {

            #warn "Invalid/Corrupted GIF (missing GIF87a Image Descriptor)\n";
            return ( $x, $y );
        }
    }
}

# _jpegsize : gets the width and height (in pixels) of a jpeg file
# Andrew Tong, werdna@ugcs.caltech.edu           February 14, 1995
# modified slightly by alex@ed.ac.uk
sub _jpegsize {
    my ($JPEG) = @_;
    my ($done) = 0;
    my ( $c1, $c2, $ch, $s, $length, $dummy ) = ( 0, 0, 0, 0, 0, 0 );
    my ( $a, $b, $c, $d );

    if (   defined($JPEG)
        && read( $JPEG, $c1, 1 )
        && read( $JPEG, $c2, 1 )
        && ord($c1) == 0xFF
        && ord($c2) == 0xD8 )
    {
        while ( ord($ch) != 0xDA && !$done ) {

            # Find next marker (JPEG markers begin with 0xFF)
            # This can hang the program!!
            while ( ord($ch) != 0xFF ) {
                return ( 0, 0 ) unless read( $JPEG, $ch, 1 );
            }

            # JPEG markers can be padded with unlimited 0xFF's
            while ( ord($ch) == 0xFF ) {
                return ( 0, 0 ) unless read( $JPEG, $ch, 1 );
            }

            # Now, $ch contains the value of the marker.
            if ( ( ord($ch) >= 0xC0 ) && ( ord($ch) <= 0xC3 ) ) {
                return ( 0, 0 ) unless read( $JPEG, $dummy, 3 );
                return ( 0, 0 ) unless read( $JPEG, $s,     4 );
                ( $a, $b, $c, $d ) = unpack( 'C' x 4, $s );
                return ( $c << 8 | $d, $a << 8 | $b );
            }
            else {

                # We **MUST** skip variables, since FF's within variable
                # names are NOT valid JPEG markers
                return ( 0, 0 ) unless read( $JPEG, $s, 2 );
                ( $c1, $c2 ) = unpack( 'C' x 2, $s );
                $length = $c1 << 8 | $c2;
                last if ( !defined($length) || $length < 2 );
                read( $JPEG, $dummy, $length - 2 );
            }
        }
    }
    return ( 0, 0 );
}

#  _pngsize : gets the width & height (in pixels) of a png file
#  source: http://www.la-grange.net/2000/05/04-png.html
sub _pngsize {
    my ($PNG)  = @_;
    my ($head) = '';
    my ( $a, $b, $c, $d, $e, $f, $g, $h ) = 0;
    if (   defined($PNG)
        && read( $PNG, $head, 8 ) == 8
        && $head eq "\x89\x50\x4e\x47\x0d\x0a\x1a\x0a"
        && read( $PNG, $head, 4 ) == 4
        && read( $PNG, $head, 4 ) == 4
        && $head eq 'IHDR'
        && read( $PNG, $head, 8 ) == 8 )
    {
        ( $a, $b, $c, $d, $e, $f, $g, $h ) = unpack( 'C' x 8, $head );
        return (
            $a << 24 | $b << 16 | $c << 8 | $d,
            $e << 24 | $f << 16 | $g << 8 | $h
        );
    }
    return ( 0, 0 );
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2012 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2001-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved. TWiki Contributors
are listed in the AUTHORS file in the root of this distribution.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
