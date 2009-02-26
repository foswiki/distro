# See bottom of file for license and copyright information
package Foswiki::Compatibility;

use Assert;

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
            if ( $src =~ /$value/ ) {
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
            if ( $src =~ /$value[^a-zA-Z0-9\.]/ ) {
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
        $src =~ /<!---->(.*)<!---->/;
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

    my $icat = $session->templates->readTemplate('twikicatitems');

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
        my $prefs = $session->{prefs};
        my $listForms = $prefs->getWebPreferencesValue( 'WEBFORMS', $web );
        $listForms =~ s/^\s*//go;
        $listForms =~ s/\s*$//go;
        my @formTemplates = split( /\s*,\s*/, $listForms );
        my $defaultFormTemplate = '';
        $defaultFormTemplate = $formTemplates[0] if (@formTemplates);

        if ( !$defaultFormTemplate ) {
            $session->logger->log(
                'warning',
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
                $name =~ s/[^A-Za-z0-9_\.]//go;
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
        $session->logger->log('warning',
            "Form: get find category template twikicatitems for Web $web");
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
        $filePath =~ s/<TwkData value="(.*)">//go;
        if   ($1) { $filePath = $1; }
        else      { $filePath = ''; }
        $filePath =~
          s/\%NOP\%//goi;    # delete placeholder that prevents WikiLinks
        ( $before, $fileSize, $after ) =
          split( /<(?:\/)*TwkFileSize>/, $atext );
        if ( !$fileSize ) { $fileSize = '0'; }
        ( $before, $fileDate, $after ) =
          split( /<(?:\/)*TwkFileDate>/, $atext );

        if ( !$fileDate ) {
            $fileDate = '';
        }
        else {
            $fileDate =~ s/&nbsp;/ /go;
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
        $fileUser =~ s/ //go;
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

    if ( $atext =~ /<TwkNextItem>/ ) {
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
            if ( $line =~ /%FILEATTACHMENT{\s"([^"]*)"([^}]*)}%/ ) {
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
        if ( $date =~ /-/ ) {
            $date =~ s/&nbsp;/ /go;
            $date = Foswiki::Time::parseTime($date);
        }
        $att->{date} = $date;
        $att->{user} = $users->webDotWikiName( $att->{user} );
    }
}

1;
__DATA__
# Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008-2009 Foswiki Contributors. All Rights Reserved.
# Foswiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 1999-2007 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
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
#
