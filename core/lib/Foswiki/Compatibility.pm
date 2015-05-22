# See bottom of file for license and copyright information
package Foswiki::Compatibility;

use strict;
use warnings;
use Assert;

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

---+ package Foswiki::Compatibility

Support for compatibility with old versions. Packaged
separately because 99.999999% of the time this won't be needed.

=cut

sub _upgradeCategoryItem {
    my ( $catitems, $ctext ) = @_;
    my $catname     = '';
    my $scatname    = '';
    my $catmodifier = '';
    my $catvalue    = '';
    my @cmd         = split( /\|/, $catitems );
    my $src         = '';
    my $len         = @cmd;
    if ( $len < '2' ) {

        # FIXME
        return ( $catname, $catmodifier, $catvalue );
    }
    my $svalue = '';

    my $i;
    my $itemsPerLine;

    # check for CategoryName=CategoryValue parameter
    my $paramCmd = '';
    my $cvalue   = '';    # was$query->param( $cmd[1] );
    if ($cvalue) {
        $src = "<!---->$cvalue<!---->";
    }
    elsif ($ctext) {
        foreach ( split( /\r?\n/, $ctext ) ) {
            if (/$cmd[1]/) {
                $src = $_;
                last;
            }
        }
    }

    if ( $cmd[0] eq 'select' || $cmd[0] eq 'radio' ) {
        $catname  = $cmd[1];
        $scatname = $catname;

        #$scatname =~ s/[^a-zA-Z0-9]//g;
        my $size = $cmd[2];
        for ( $i = 3 ; $i < $len ; $i++ ) {
            my $value = $cmd[$i];
            $svalue = $value;
            if ( $src =~ m/$value/ ) {
                $catvalue = $svalue;
            }
        }

    }
    elsif ( $cmd[0] eq 'checkbox' ) {
        $catname  = $cmd[1];
        $scatname = $catname;

        #$scatname =~ s/[^a-zA-Z0-9]//g;
        if ( $cmd[2] eq 'true' || $cmd[2] eq '1' ) {
            $i           = $len - 4;
            $catmodifier = 1;
        }
        $itemsPerLine = $cmd[3];
        for ( $i = 4 ; $i < $len ; $i++ ) {
            my $value = $cmd[$i];
            $svalue = $value;

            # I18N: FIXME - need to look at this, but since it's upgrading
            # old forms that probably didn't use I18N, it's not a high
            # priority.
            if ( $src =~ m/$value[^a-zA-Z0-9\.]/ ) {
                $catvalue .= ", " if ($catvalue);
                $catvalue .= $svalue;
            }
        }

    }
    elsif ( $cmd[0] eq 'text' ) {
        $catname  = $cmd[1];
        $scatname = $catname;

        #$scatname =~ s/[^a-zA-Z0-9]//g;
        # SMELL: unchecked implicit untaint?
        $src =~ m/<!---->(.*)<!---->/;
        if ($1) {
            $src = $1;
        }
        else {
            $src = '';
        }
        $catvalue = $src;
    }

    return ( $catname, $catmodifier, $catvalue );
}

=begin TML

---++ StaticMethod upgradeCategoryTable( $session, $web, $topic, $meta, $text ) -> $text

Upgrade old style category table

May throw Foswiki::OopsException

=cut

sub upgradeCategoryTable {
    my ( $session, $web, $topic, $meta, $text ) = @_;

    my $icat =
      $session->templates->readTemplate( 'twikicatitems', no_oops => 1 );

    if ($icat) {
        my @items = ();

        # extract category section and build category form elements
        my ( $before, $ctext, $after ) = split( /<!--TWikiCat-->/, $text );

        # cut TWikiCat part
        $text = $before || '';
        $text .= $after if ($after);
        $ctext = '' if ( !$ctext );

        my $ttext = '';
        foreach ( split( /\r?\n/, $icat ) ) {
            my ( $catname, $catmod, $catvalue ) =
              _upgradeCategoryItem( $_, $ctext );
            if ($catname) {
                push @items, ( [ $catname, $catmod, $catvalue ] );
            }
        }
        my $prefs     = $session->{prefs};
        my $webObject = Foswiki::Meta->new( $session, $web );
        my $listForms = $webObject->getPreference('WEBFORMS');
        $listForms =~ s/^\s*//g;
        $listForms =~ s/\s*$//g;
        my @formTemplates = split( /\s*,\s*/, $listForms );
        my $defaultFormTemplate = '';
        $defaultFormTemplate = $formTemplates[0] if (@formTemplates);

        if ( !$defaultFormTemplate ) {
            $session->logger->log( 'warning',
                    "Form: can't get form definition to convert category table "
                  . " for topic $web.$topic" );
            foreach my $oldCat (@items) {
                my $name  = $oldCat->[0];
                my $value = $oldCat->[2];
                $meta->put( 'FORM', { name => '' } );
                $meta->putKeyed(
                    'FIELD',
                    {
                        name  => $name,
                        title => $name,
                        value => $value
                    }
                );
            }
            return;
        }

        require Foswiki::Form;
        my $def = new Foswiki::Form( $session, $web, $defaultFormTemplate );
        $meta->put( 'FORM', { name => $defaultFormTemplate } );

        foreach my $fieldDef ( @{ $def->getFields() } ) {
            my $value = '';
            foreach my $oldCatP (@items) {
                my @oldCat = @$oldCatP;
                my $name = $oldCat[0] || '';
                $name =~ s/[^A-Za-z0-9_\.]//g;
                if ( $name eq $fieldDef->{name} ) {
                    $value = $oldCat[2];
                    last;
                }
            }
            $meta->putKeyed(
                'FIELD',
                {
                    name  => $fieldDef->{name},
                    title => $fieldDef->{title},
                    value => $value,
                }
            );
        }

    }
    else {

        # We used to log a warning but it only made noise and trouble
        # People will not need to be warned any longer. Item1440
    }
    return $text;
}

#Get file attachment attributes for old html
#format.
sub _getOldAttachAttr {
    my ( $session, $atext ) = @_;
    my $fileName    = '';
    my $filePath    = '';
    my $fileSize    = '';
    my $fileDate    = '';
    my $fileUser    = '';
    my $fileComment = '';
    my $before      = '';
    my $item        = '';
    my $after       = '';
    my $users       = $session->{users};

    ( $before, $fileName, $after ) = split( /<(?:\/)*TwkFileName>/, $atext );
    if ( !$fileName ) { $fileName = ''; }
    if ($fileName) {
        ( $before, $filePath, $after ) =
          split( /<(?:\/)*TwkFilePath>/, $atext );
        if ( !$filePath ) { $filePath = ''; }

        # SMELL: unchecked implicit untaint
        $filePath =~ s/<TwkData value="(.*)">//g;
        if   ($1) { $filePath = $1; }
        else      { $filePath = ''; }
        $filePath =~ s/\%NOP\%//gi; # delete placeholder that prevents WikiLinks
        ( $before, $fileSize, $after ) =
          split( /<(?:\/)*TwkFileSize>/, $atext );
        if ( !$fileSize ) { $fileSize = '0'; }
        ( $before, $fileDate, $after ) =
          split( /<(?:\/)*TwkFileDate>/, $atext );

        if ( !$fileDate ) {
            $fileDate = '';
        }
        else {
            $fileDate =~ s/&nbsp;/ /g;
            require Foswiki::Time;
            $fileDate = Foswiki::Time::parseTime($fileDate);
        }
        ( $before, $fileUser, $after ) =
          split( /<(?:\/)*TwkFileUser>/, $atext );
        if ( !$fileUser ) {
            $fileUser = '';
        }
        else {
            $fileUser = $users->getLoginName($fileUser) if $fileUser;
        }
        $fileUser ||= '';
        $fileUser =~ s/ //g;
        ( $before, $fileComment, $after ) =
          split( /<(?:\/)*TwkFileComment>/, $atext );
        if ( !$fileComment ) { $fileComment = ''; }
    }

    return ( $fileName, $filePath, $fileSize, $fileDate, $fileUser,
        $fileComment );
}

=begin TML

---++ migrateToFileAttachmentMacro ( $session, $meta, $text  ) -> $text

Migrate old HTML format

=cut

sub migrateToFileAttachmentMacro {
    my ( $session, $meta, $text ) = @_;
    ASSERT( $meta->isa('Foswiki::Meta') ) if DEBUG;

    my ( $before, $atext, $after ) = split( /<!--TWikiAttachment-->/, $text );
    $text = $before || '';
    $text .= $after if ($after);
    $atext = '' if ( !$atext );

    if ( $atext =~ m/<TwkNextItem>/ ) {
        my $line = '';
        foreach $line ( split( /<TwkNextItem>/, $atext ) ) {
            my (
                $fileName, $filePath, $fileSize,
                $fileDate, $fileUser, $fileComment
            ) = _getOldAttachAttr( $session, $line );

            if ($fileName) {
                $meta->putKeyed(
                    'FILEATTACHMENT',
                    {
                        name    => $fileName,
                        version => '',
                        path    => $filePath,
                        size    => $fileSize,
                        date    => $fileDate,
                        user    => $fileUser,
                        comment => $fileComment,
                        attr    => ''
                    }
                );
            }
        }
    }
    else {

        # Format of macro that came before META:ATTACHMENT
        my $line = '';
        require Foswiki::Attrs;
        foreach $line ( split( /\r?\n/, $atext ) ) {
            if ( $line =~ m/%FILEATTACHMENT\{\s"([^"]*)"([^}]*)\}%/ ) {
                my $name   = $1;
                my $values = new Foswiki::Attrs($2);
                $values->{name} = $name;
                $meta->putKeyed( 'FILEATTACHMENT', $values );
            }
        }
    }

    return $text;
}

=begin TML

---++ upgradeFrom1v0beta ( $session, $meta  ) -> $text

=cut

sub upgradeFrom1v0beta {
    my ( $session, $meta ) = @_;
    my $users = $session->{users};
    require Foswiki::Time;

    my @attach = $meta->find('FILEATTACHMENT');
    foreach my $att (@attach) {
        my $date = $att->{date} || 0;
        if ( $date =~ m/-/ ) {
            $date =~ s/&nbsp;/ /g;
            $date = Foswiki::Time::parseTime($date);
        }
        $att->{date} = $date;
        $att->{user} = $users->webDotWikiName( $att->{user} );
    }
}

# Read meta-data encoded using the discredited symmetrical encoding
# method from pre 1.1
sub readSymmetricallyEncodedMETA {
    my ( $meta, $type, $args ) = @_;

    my $keys = {};

    $args =~ s/\s*([^=]+)="([^"]*)"/
      _symmetricalDataDecode( $1, $2, $keys )/ge;

    if ( defined( $keys->{name} ) ) {

        # don't attempt to save it keyed unless it has a name
        $meta->putKeyed( $type, $keys );
    }
    else {
        $meta->put( $type, $keys );
    }
    return 1;
}

sub _symmetricalDataDecode {
    my ( $key, $value, $res ) = @_;

    # Old decoding retained for backward compatibility.
    # This encoding is badly broken, because the encoded
    # symbols are symmetrical, and use an encoded symbol (%).
    $value =~ s/%_N_%/\n/g;
    $value =~ s/%_Q_%/\"/g;
    $value =~ s/%_P_%/%/g;

    $res->{$key} = $value;

    return '';
}

# IF cfg{RequireCompatibleAnchors}

# Return a list of alternative anchor names generated using old generations
# of anchor name generator
sub makeCompatibleAnchors {
    my ($text) = @_;
    my @anchors;

    # Use the old algorithm to generate the old style, non-unique, anchor
    # target.
    my $badAnchor = _makeBadAnchorName( $text, 0 );
    push( @anchors, $badAnchor ),

      # There's an even older algorithm we have to allow for
      my $worseAnchor = _makeBadAnchorName( $text, 1 );
    if ( $worseAnchor ne $badAnchor ) {
        push( @anchors, $worseAnchor ),;
    }

    return @anchors;
}

# Make an anchor name using the seriously flawed (tm)Wiki anchor generation
# algorithm(s). This code is taken verbatim from Foswiki 1.0.4.
sub _makeBadAnchorName {
    my ( $anchorName, $compatibilityMode ) = @_;
    if (  !$compatibilityMode
        && $anchorName =~ m/^$Foswiki::regex{anchorRegex}$/ )
    {

        # accept, already valid -- just remove leading #
        return substr( $anchorName, 1 );
    }

    # strip out potential links so they don't get rendered.
    # remove double bracket link
    $anchorName =~ s/\[(?:\[.*?\])?\[(.*?)\]\s*\]/$1/g;

    # add an _ before bare WikiWords
    $anchorName =~ s/($Foswiki::regex{wikiWordRegex})/_$1/g;

    if ($compatibilityMode) {

        # remove leading/trailing underscores first, allowing them to be
        # reintroduced
        $anchorName =~ s/^[\s#_]*//;
        $anchorName =~ s/[\s_]*$//;
    }
    $anchorName =~ s/<\/?[a-zA-Z][^>]*>//gi;    # remove HTML tags
    $anchorName =~ s/&#?[a-zA-Z0-9]+;//g;       # remove HTML entities
    $anchorName =~ s/&//g;                      # remove &
         # filter TOC excludes if not at beginning
    $anchorName =~ s/^(.+?)\s*$Foswiki::regex{headerPatternNoTOC}.*/$1/;

    # filter '!!', '%NOTOC%'
    $anchorName =~ s/$Foswiki::regex{headerPatternNoTOC}//;

    # No matter what character set we use, the HTML standard does not allow
    # anything else than English alphanum characters in anchors
    # So we convert anything non A-Za-z0-9_ to underscores
    # and limit the number consecutive of underscores to 1
    # This means that pure non-English anchors will become A, A_AN1, A_AN2, ...
    # We accept anchors starting with 0-9. It is non RFC but it works and it
    # is very important for compatibility
    $anchorName =~ s/[^A-Za-z0-9]+/_/g;
    $anchorName =~ s/__+/_/g;             # remove excessive '_' chars

    if ( !$compatibilityMode ) {
        $anchorName =~ s/^[\s#_]+//;      # no leading space nor '#', '_'
    }

    $anchorName =~ s/^$/A/;               # prevent empty anchor

    # limit to 32 chars
    $anchorName =~ s/^(.{32})(.*)$/$1/;
    if ( !$compatibilityMode ) {
        $anchorName =~ s/[\s_]+$//;       # no trailing space, nor '_'
    }
    return $anchorName;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 1999-2007 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
