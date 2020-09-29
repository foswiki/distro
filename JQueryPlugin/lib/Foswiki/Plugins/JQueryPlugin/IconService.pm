# See bottom of file for license and copyright information
package Foswiki::Plugins::JQueryPlugin::IconService;
use strict;
use warnings;

use Foswiki::Func();
use Foswiki::ListIterator();
use Foswiki::Plugins::JQueryPlugin();
use Error qw(:try);

=begin TML

---+ package Foswiki::Plugins::JQueryPlugin::IconService

Singleton class that handles all sorts of icons, image as well as font icons

=cut

sub new {
    my $class = shift;

    my $this = bless( {@_}, $class );

    # load icon fonts
    my @prefixes  = ();
    my $iconFonts = $Foswiki::cfg{JQueryPlugin}{IconFonts}
      || {
        'fontawesome' => {
            'prefix'     => 'fa',
            'definition' => $Foswiki::cfg{PubDir} . '/'
              . $Foswiki::cfg{SystemWebName}
              . '/JQueryPlugin/plugins/fontawesome/fontawesome.json',
            'plugin' => 'fontawesome',
        }
      };

    foreach my $name ( keys %{$iconFonts} ) {
        my $rec = $iconFonts->{$name};
        $this->{_iconFonts}{$name} = $rec;
        $rec->{name} = $name;
        push @prefixes, $rec->{prefix};
    }
    $this->{_iconPrefixes} = join( "|", @prefixes );

    # icon search path
    unless ( defined $this->{_iconSearchPath} ) {
        my $iconSearchPath = $Foswiki::cfg{JQueryPlugin}{IconSearchPath}
          || 'FamFamFamSilkIcons, FamFamFamSilkCompanion1Icons, FamFamFamSilkCompanion2Icons, FamFamFamSilkGeoSilkIcons, FamFamFamFlagIcons, FamFamFamMiniIcons, FamFamFamMintIcons';
        @{ $this->{_iconSearchPath} } = split( /\s*,\s*/, $iconSearchPath );
    }

    $this->_readIcons();

    return $this;
}

=begin TML

---++ ObjectMethod unload

initialize the service so that it can be reused

=cut

sub unload {
    my $this = shift;

    undef $this->{_loadedFont};
}

=begin TML

---++ ObjectMethod finish

finalizer

=cut

sub finish {
    my $this = shift;

    undef $this->{_icons};
    undef $this->{_iconFonts};
    undef $this->{_iconPrefixes};
    undef $this->{_loadedFont};
    undef $this->{_iconSearchPath};
}

=begin TML

---++ ObjectMethod loadIconFont($name)

loads the given font into the current page.

=cut

sub loadIconFont {
    my ( $this, $fontName ) = @_;

    my $font = $this->getIconFont($fontName);

    if ( $font && !$this->{_loadedFont}{ $font->{name} } ) {
        $this->{_loadedFont}{ $font->{name} } = 1;

        if ( defined $font->{plugin} ) {
            Foswiki::Plugins::JQueryPlugin::createPlugin( $font->{plugin} );
        }
        elsif ( defined $font->{css} ) {
            Foswiki::Func::addToZone(
                "head",
                uc($fontName) . "::CSS",
                "<link rel='stylesheet' href='$font->{css}' media='all'>"
            );
        }
    }

    return $font;
}

sub loadFontOfIcon {
    my ( $this, $icon ) = @_;

    if ( ref($icon) ) {
        return $this->loadIconFont( $icon->{fontName} );
    }
    elsif ( $icon =~ /^($this->{_iconPrefixes})/ ) {
        return $this->loadIconFont($1);
    }
}

sub loadAllIconFonts {
    my $this = shift;

    foreach my $fontName ( keys %{ $this->{_iconFonts} } ) {
        $this->loadIconFont($fontName);
    }
}

=begin TML

---++ ObjectMethod getIconFont($name)

get an icon font definition. =$name= can either be the font name, such as "fontawesome",
or the prefix as used by the icon itself, e.g. =fa= for fontawesome icons. 

=cut

sub getIconFont {
    my ( $this, $fontName ) = @_;

    my $font = $this->{_iconFonts}{$fontName};

    unless ( defined $font ) {

        # not found, then try prefixes
        foreach my $name ( keys %{ $this->{_iconFonts} } ) {
            my $rec = $this->{_iconFonts}{$name};
            if ( $rec->{prefix} eq $name ) {
                $font     = $rec;
                $fontName = $name;
                last;
            }
        }
    }

    # make sure the name is in there
    $font->{name} = $fontName;

    return $font;
}

# the iconName could actually be a list of classes, only the first one is the actual icon name, e.g. fa-face fa-fw.
sub renderIcon {
    my ( $this, $params ) = @_;

    my $iconName;

    unless ( ref($params) ) {
        $iconName = $params;
        $params   = {};
    }
    else {
        $iconName = $params->{_DEFAULT} || '';
    }

    my $iconAlt   = $params->{alt}   || $iconName;
    my $iconTitle = $params->{title} || '';
    my $iconFormat  = $params->{format};
    my $iconStyle   = $params->{style};
    my $iconAnimate = $params->{animate};
    my $iconWidth   = $params->{width} || 16;
    my $iconHeight  = $params->{height} || '';
    my $iconPath;

    my $iconClass = $params->{class};
    my @iconClass = split( /\s+/, $iconName );
    $iconName = shift @iconClass;
    push @iconClass, $iconClass if $iconClass;

    # is this a known icon fonts
    my $icon = $this->getIcon($iconName);
    return '' unless $icon;

    if ( defined $icon->{fontName} ) {
        $iconFormat = '<i class=\'$iconClass\' $iconStyle $iconTitle></i>';
        $iconPath   = '';
        push @iconClass, "foswikiIcon", "jqIcon", $icon->{prefix}, $icon->{id};

        $this->loadIconFont( $icon->{fontName} );
    }
    else {
        my $iconHeightFormat = $iconHeight ? 'height=\'$iconHeight\'' : '';
        $iconFormat =
'<img src=\'$iconPath\' class=\'$iconClass $iconName\' $iconStyle $iconAlt$iconTitle width=\'$iconWidth\' $iconHeightFormat />'
          unless $iconFormat;
        $iconPath = $icon->{url};
        push @iconClass, "foswikiIcon", "jqIcon";
    }

    if ( defined $iconAnimate ) {
        push @iconClass, "faa-$iconAnimate", "animated";
    }

    $iconClass = join( " ", @iconClass );

    my $img = $iconFormat;
    $img =~ s/\$iconName/$iconName/g;
    $img =~ s/\$iconPath/$iconPath/g;
    $img =~ s/\$iconClass/$iconClass/g;
    $img =~ s/\$iconStyle/style='$iconStyle'/g if $iconStyle;
    $img =~ s/\$iconAlt/alt='$iconAlt' /g if $iconAlt;
    $img =~ s/\$iconTitle/title='$iconTitle' /g if $iconTitle;
    $img =~ s/\$(iconAlt|iconTitle|iconStyle)//g;
    $img =~ s/\$iconWidth/$iconWidth/g;
    $img =~ s/\$iconHeight/$iconHeight/g;

    return $img;
}

=begin TML

---++ ObjectMethod getIconUrlPath ( $iconName ) -> $pubUrlPath

Returns the path to the named icon searching along a given icon search path.
This path can be in =$Foswiki::cfg{JQueryPlugin}{IconSearchPath}= or will fall
back to =FamFamFamSilkIcons=, =FamFamFamSilkCompanion1Icons=,
=FamFamFamFlagIcons=, =FamFamFamMiniIcons=, =FamFamFamMintIcons= As you see
installing Foswiki:Extensions/FamFamFamContrib would be nice to have.

   = =$iconName=: name of icon; you will have to know the icon name by heart as listed in your
     favorite icon set, meaning there's no mapping between something like "semantic" and "physical" icons
   = =$pubUrlPath=: the path to the icon as it is attached somewhere in your wiki or the empty
     string if the icon was not found

=cut

sub getIconUrlPath {
    my ( $this, $iconName ) = @_;

    return '' unless $iconName;

    $iconName =~ s/^.*\.(.*?)$/$1/;    # strip file extension

    my $icon = $this->getIcon($iconName);
    return $icon->{url} if defined $icon && defined $icon->{url};
    return;
}

=begin TML

---++ ObjectMethod getIcon($id) -> \%icon;

get the icon descriptor for the given id

=cut

sub getIcon {
    my ( $this, $id ) = @_;

    return unless defined $id;
    return $this->{_icons}{$id};
}

=begin TML

---++ ObjectMethod getIcons() -> @list;

get all icons as a sorted list

=cut

sub getIcons {
    my $this = shift;

    return map { $_->[0] }
      sort     { $a->[1] cmp $b->[1] }
      map { [ $_, lc( $_->{text} ) ] } values %{ $this->{_icons} };
}

=begin TML

---++ ObjectMethod getIconIterator() -> Foswiki::ListIterator

get a list iterator for all icons

=cut

sub getIconIterator {
    my $this = shift;

    my @icons = $this->getIcons();
    return Foswiki::ListIterator->new( \@icons );
}

=begin TML

---++ ObjectMethod _readIcons()

read all icon definitions

=cut

sub _readIcons {
    my $this = shift;

    return if defined $this->{_icons};

    $this->_readIconFonts();
    $this->_readIconPath();

    $this->{_icons} = { map { $_->{id} => $_ } @{ $this->{_icons} } };
}

sub _readIconFonts {
    my $this = shift;

    foreach my $fontName ( keys %{ $this->{_iconFonts} } ) {

        my $font = $this->{_iconFonts}{$fontName};
        next unless -e $font->{definition};

        my $text = Foswiki::Func::readFile( $font->{definition} );
        my $json;
        try {
            $json = JSON::decode_json($text);
        }
        catch Error::Simple with {
            print STDERR "ERROR: cannot parse definition of $fontName: "
              . shift . "\n";
        };
        next unless $json;

        foreach my $entry ( @{ $json->{icons} } ) {
            $entry->{text}     = $entry->{name} || $entry->{id};
            $entry->{prefix}   = $font->{prefix};
            $entry->{id}       = $font->{prefix} . '-' . $entry->{id};
            $entry->{fontName} = $fontName;
            delete $entry->{url};
            push @{ $entry->{categories} }, $fontName;
            push @{ $entry->{categories} }, "fonticon";
            push @{ $this->{_icons} },      $entry;

            if ( $entry->{aliases} ) {
                foreach my $alias ( @{ $entry->{aliases} } ) {
                    my %clone = %$entry;
                    $clone{text}     = $alias;
                    $clone{id}       = $font->{prefix} . '-' . $alias;
                    $clone{_isAlias} = 1;
                    push @{ $this->{_icons} }, \%clone;
                }
            }
        }
    }
}

sub _readIconPath {
    my $this = shift;

    my %seen       = ();
    my $pubUrlPath = Foswiki::Func::getPubUrlPath();
    foreach my $item ( @{ $this->{_iconSearchPath} } ) {

        my ( $web, $topic ) =
          Foswiki::Func::normalizeWebTopicName( $Foswiki::cfg{SystemWebName},
            $item );

        my $iconDir  = $Foswiki::cfg{PubDir} . '/' . $web . '/' . $topic;
        my $iconPath = $pubUrlPath . '/' . $web . '/' . $topic;

        if ( -d "$iconDir/icons" ) {
            $iconDir  .= "/icons";
            $iconPath .= "/icons";
        }

        opendir( my $dh, $iconDir ) || next;
        foreach my $icon ( grep { /\.(png|gif|jpe?g|svgz?)$/i } readdir($dh) ) {
            next
              if $icon =~
/^(SilkCompanion1Thumb|index_abc|geosilk|silk\-companion\-II|igp_.*)\.png$/
              ;    # filter some more
            next if $icon =~ /^igp_/;
            my $id = $icon;
            $id =~ s/\.(png|gif|jpe?g|svgz?)$//i;

            # check whether the icon already exists and rename it if so
            if ( $seen{$id} ) {
                my $i = 1;
                $i++ while $seen{"$id-$i"};
                $id .= "-$i";

                #print STDERR "renaming $icon in $topic to $id\n";
            }
            $seen{$id} = 1;

            my $category = $topic;
            $category =~ s/(Plugin|Contrib)$//;

            my $desc = {
                id         => $id,
                text       => $id,
                url        => $iconPath . '/' . $icon,
                categories => [ $category, "imageicon" ],
            };

            push @{ $this->{_icons} }, $desc;
        }

        closedir $dh;
    }
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2010-2020 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.

