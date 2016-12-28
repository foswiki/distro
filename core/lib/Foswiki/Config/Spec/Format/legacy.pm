# See bottom of file for license and copyright information

# This module would reimplement Configure's LoadSpec module parsing code to keep
# it as compatible with the original code as possible.

package Foswiki::Config::Spec::Format::legacy::SpecItem;

use Foswiki::Class;
extends qw(Foswiki::Object);

has data => (
    is      => 'ro',
    lazy    => 1,
    clearer => 1,
    builder => 'prepapreData',
);

has name => (
    is      => 'rw',
    builder => 'prepareName',
);

has dataIdx => (
    is        => 'ro',
    lazy      => 1,
    clearer   => 1,
    predicate => 1,
    builder   => 'prepareDataIdx',
);

sub prepareData {
    my $this = shift;
    return [];
}

sub prepareName {
    return undef;
}

sub addOpts {
    my $this = shift;

    Foswiki::Exception::Fatal->throw(
        text => "Odd number of elements in options array" )
      unless @_ % 2 == 0;

    push @{ $this->data }, @_;
    $this->clear_dataIdx;
}

# Returns an option value from the data attribute.
sub opt {
    my $this    = shift;
    my $optName = shift;
    my $idx     = $this->dataIdx->{$optName};
    return undef unless defined $idx;
    return $this->data->[$idx];
}

# Adds text to the text option.
sub appendText {
    my $this = shift;

    my $idx = $this->dataIdx->{text};
    my $text = join( '', @_ );

    if ( defined $idx ) {
        $this->data->[ $idx + 1 ] .= "\n" . $text;
    }
    else {
        $this->addOpts( text => $text );
    }
}

sub prepareDataIdx {
    my $this = shift;

    # Map list of options into a hash.
    my $data = $this->data;
    return { map { my $idx = $_ * 2; $data->[$idx] => $idx }
          0 .. ( $#{ $this->data } / 2 ) };
}

# Return a list suitable to be pushed onto the specs list.
sub asSpec {
    my $this = shift;

    return ( $this->name, $this->data );
}

package Foswiki::Config::Spec::Format::legacy::Section;

use Foswiki::Class;
extends qw(Foswiki::Config::Spec::Format::legacy::SpecItem);

has level => (
    is       => 'rw',
    required => 1,
);

around asSpec => sub {
    my $orig = shift;
    my $this = shift;

    return ( -section => $orig->( $this, @_ ) );
};

# Exception names look scary but this is to keep their uniqueness guaranteed.

# Flow is the base for all parser flow control exceptions.
package Foswiki::Exception::Config::Spec::Format::legacy::Flow;

use Foswiki::Class;
extends qw(Foswiki::Exception::Harmless);

# UpSection is to signal when to cancel processing and return control to the
# upper level stack frame.
package Foswiki::Exception::Config::Spec::Format::legacy::UpSection;

use Foswiki::Class;
extends qw(Foswiki::Exception::Config::Spec::Format::legacy::Flow);

# Repeat is to restart current line loop.
package Foswiki::Exception::Config::Spec::Format::legacy::Repeat;

use Foswiki::Class;
extends qw(Foswiki::Exception::Config::Spec::Format::legacy::Flow);

# Last commands to exit loop.
package Foswiki::Exception::Config::Spec::Format::legacy::Last;

use Foswiki::Class;
extends qw(Foswiki::Exception::Config::Spec::Format::legacy::Flow);

package Foswiki::Config::Spec::Format::legacy;

use Try::Tiny;

use Foswiki::Class qw(app);
extends qw(Foswiki::Object);
with qw(Foswiki::Config::Spec::Parser Foswiki::Config::CfgObject);

has specSrc => (
    is      => 'rw',
    trigger => 1,
    coerce  => sub {
        if ( ref( $_[0] ) eq 'ARRAY' ) {
            return $_[0];
        }
        else {
            return [ split /^/m, $_[0] ];
        }
    },
    trigger => 1,
);
has specLines => (
    is      => 'ro',
    clearer => 1,
    lazy    => 1,
    builder => 'prepareSpecLines',
);
has nextLine => (
    is      => 'rw',
    lazy    => 1,
    clearer => 1,
    builder => 'prepareNextLine',
);
has recordedLine => (
    is        => 'rw',
    clearer   => 1,
    predicate => 1,
);

# Specs file object supplied to the parse() method.
has _specFile => (
    is       => 'rw',
    weak_ref => 1,
);

# Spec defaults hash.
has _specDef => (
    is      => 'rw',
    builder => '_prepareSpecDef',
);

sub readLine {
    my $this     = shift;
    my $nextLine = $this->nextLine;
    return undef if $nextLine >= $this->specLines;
    my $line = $this->specSrc->[$nextLine];
    $this->nextLine( $nextLine + 1 );
    return $line;
}

# Records current line
sub recordLine {
    my $this = shift;

    $this->recordedLine( $this->nextLine );
    return $this->readLine;
}

# Restore last recorded line pos. Used when need to rescan already parsed portion.
sub restoreLine {
    my $this = shift;
    Foswiki::Exception::Fatal->throw( text =>
          "Cannot restore line position: no previously recorded line number!" )
      unless $this->has_recordedLine;
    $this->nextLine( $this->recordedLine );
    $this->clear_recordedLine;
}

sub _makeItem {
    my $this = shift;

    # Class could be empty for SpecItem or short form like Section.
    my $class = shift;

    $class =
      'Foswiki::Config::Spec::Format::legacy::' . ( $class || 'SpecItem' );

    my %profile = @_;

    $profile{data} //= [];

    unshift @{ $profile{data} },
      file => $this->_specFile->path,

      # Make it human-readable base-1. For aux items created before any
      # processing started line -1 would mean exactly this.
      line => ( $this->recordedLine // -2 ) + 1,
      ;

    my $item = $this->create( $class, %profile, );

    return $item;
}

sub _addItem2Specs {
    my $this   = shift;
    my $status = shift;

    my $specItem  = $status->{specItem};
    my $isSection = $this->_isSectionItem($status);

    push @{ $status->{specs} }, $specItem->asSpec if $specItem;

    $this->_closeItem($status);

    if ($isSection) {

        # We've just pushed a new section to the specs and hit a declaration
        # which belongs to this section.
        $this->restoreLine;
        $this->_sectionParse( section => $specItem, );
        Foswiki::Exception::Config::Spec::Format::legacy::Repeat->throw;
    }

    if ( $status->{nextSection} ) {

        my $curLevel  = $status->{section}->level;
        my $nextLevel = $status->{nextSection}->level;

        if ( $nextLevel <= $curLevel ) {

            # This is same or upper level section we've reached. Must be
            # processed by higher-level stack frame.
            $this->restoreLine;
            Foswiki::Exception::Config::Spec::Format::legacy::UpSection->throw;
        }

        # There must be no skipped section levels. I.e. it must not be
        # possible to have '---+++' defined right next to '---+'. It
        # would break UI if I get it correctly.
        if ( ( $nextLevel - 1 ) > $curLevel ) {
            Foswiki::Exception::Config::BadSpecSrc->throw(
                file => $this->_specFile,
                line => $this->nextLine,
                text => "Missing section level "
                  . ( $nextLevel - 1 )
                  . " before level "
                  . $nextLevel
                  . " section `"
                  . $status->{nextSection}->name
                  . "' declaration.",
            );
        }
    }
}

sub _closeItem {
    my $this   = shift;
    my $status = shift;

    undef $status->{specItem};
    undef $status->{isEnhancing};
}

sub _checkItemComplete {
    my $this   = shift;
    my $status = shift;

    if ( $status->{specItem} && !$status->{isEnhancing} ) {
        unless ( $status->{nextSection} ) {

            # SMELL or TBD Must be replaced with a non-destructive messaging. A
            # broken spec must not break the app. Though we might consider
            # ignoring the spec as well.
            Foswiki::Exception::Config::BadSpecSrc->throw(
                file => $this->_specFile,
                line => $this->nextLine,
                text => "Incomplete definition",
            );
        }
    }
    $this->_addItem2Specs($status);
}

sub _isSectionItem {
    my $this   = shift;
    my $status = shift;

    return $status->{specItem}
      && $status->{specItem}
      ->isa('Foswiki::Config::Spec::Format::legacy::Section');
}

sub _sectionParse {
    my $this   = shift;
    my %params = @_;

    my $cfg = $this->cfg;

    my $status = {
        section => $params{section}
          || $this->_makeItem( 'Section', level => 0, name => 'Root', ),
        specs => $params{specs} || $params{section}->data,
        isEnhancing => undef,
        specItem    => undef,
        itemText    => undef,
    };

    my ($specItem);

    my $specDef = $this->_specDef;

    my $exception;

    while ( defined( my $l = $this->recordLine ) ) {

        try {
            chomp $l;

            undef $exception;

            while ( $l =~ s/\\$// ) {
                my $cont = $this->readLine;
                last unless defined $cont;
                chomp $cont;
                $cont =~ s/^#// if ( $l =~ m/^#/ );
                $cont =~ s/^\s+/ /;
                if ( $cont =~ m/^#/ ) {
                    $l .= '\\';
                }
                else {
                    $l .= $cont;
                }
            }

            Foswiki::Exception::Config::Spec::Format::legacy::Last->throw
              if ( $l =~ m/^(1;|__[A-Z]+__)/ );
            Foswiki::Exception::Config::Spec::Format::legacy::Repeat->throw
              if ( $l =~ m/^\s*$/ || $l =~ m/^\s*#!/ );

            if ( $l =~
                m/^#\s*\*\*\s*(?<type>[A-Z]+)\s+(?<options>.*?)\s*\*\*\s*$/ )
            {
                my ( $type, $opts ) = @+{qw(type options)};

                if ( $status->{specItem} && !$status->{isEnhancing} ) {
                    $this->_addItem2Specs($status);
                }

                if ( $type eq 'ENHANCE' ) {

                    # LoadSpec determines if we're really enhancing an already
                    # defined spec by trying to load it. The new paradigm
                    # doesn't allow us to go this way because specs could be
                    # loaded from a single file without accessing others where
                    # the spec could have been defined. It is up to the Config
                    # core to determine if we really deal with enhancing.
                    $status->{specItem} = $this->_makeItem(
                        'SpecItem',
                        name => $opts,
                        data => [ type => $type ],
                    );
                    $status->{isEnhancing} = 1;
                }
                else {
                    $status->{specItem} =
                      $this->_makeItem( 'SpecItem', data => [ type => $type ] );
                }

                $status->{specItem}->addOpts( options => $opts );
            }
            elsif ( $l =~
m/^(?<optional>#)?\s*\$(?:(?:Fosw|TW)iki::)?cfg(?<keyPath>[^=\s]*)\s*=\s*(.*?)$/
              )
            {
                my ( $keyPath, $optional ) = @+{qw(keyPath optional)};

                unless ( $keyPath =~ /$Foswiki::Config::ITEMREGEX/ ) {

                    # XXX TODO report error here when bufferized messaging is in
                    # place.
                    $this->_closeItem($status);
                    Foswiki::Exception::Config::Spec::Format::legacy::Repeat
                      ->throw;
                }

                # Push section on specs list if we're in section declaration
                # now.
                if ( $this->_isSectionItem($status) ) {
                    $this->_addItem2Specs($status);
                }
                elsif ( !$status->{specItem} ) {
                    $status->{specItem} = $this->_makeItem('SpecItem');
                }

                # XXX LoadSpec checks for entries added by pluggables. Seems
                # like if the keyPath has been added previously then no other
                # processing is done on it. This kind of check is not possible
                # here because pluggables are to be executed by Foswiki::Config.
                # Perhaps they must set a kind of 'immutable' flag on
                # auto-generated items.

                my $specItem = $status->{specItem};

                my ( $subHash, $key ) =
                  $cfg->getSubHash( $keyPath, data => $specDef );

                my $defaultVal = $subHash->{$key};

                my $itemType = $specItem->opt('type');

                if ( $itemType && $itemType eq 'REGEX' ) {
                    if ( $defaultVal =~ m/^qr(.)(.*)\1$/
                        || ref($defaultVal) eq 'Regexp' )
                    {
                        # Convert a qr// into a quoted string
                        $defaultVal = $1;

                        # Strip off useless furniture (?^: ... )
                        while ( $defaultVal =~ s/^\(\?\^:(.*)\)$/$1/ ) {
                        }

                        # Convert quoting for a single-quoted string. All we
                        # need to do is protect single quote
                        $defaultVal =~ s/'/\\'/g;
                        $defaultVal = "'" . $defaultVal . "'";
                    }
                    else {
                        $defaultVal =~
                          s/\\'/'/g; # unescape any escaped ' for quoted string.
                    }
                }

                $specItem->addOpts(
                    default => $defaultVal,
                    ( $optional ? ( optional => 1 ) : () )
                );
                $specItem->name( $cfg->normalizeKeyPath($keyPath) );

                if ( $status->{isEnhancing} ) {
                    $this->_closeItem($status);
                }
                else {
                    $this->_addItem2Specs($status);
                }
                $status->{isEnhancing} = 0;
            }
            elsif ( $l =~ m/^#\s*\*([A-Z]+)\*/ ) {

                my $name = $1;

# SMELL LoadSpec does a lot of work on checking on enhancing and
# section/value checks. Not sure if it could be reproduced here. Not even sure if it makes any sense.

                $this->_checkItemComplete($status);

                push @{ $status->{specs} }, -pluggable => $name;
            }
            elsif ( $l =~ m/^#\s*---(?<subLevel>\++)\s*(?<section>.*?)$/ ) {
                my ( $subLevel, $section ) = @+{qw(subLevel section)};
                $subLevel = length($subLevel);

                $status->{nextSection} = $this->_makeItem(
                    'Section',
                    name  => $section,
                    level => $subLevel,
                );

                $this->_checkItemComplete($status);

                $status->{specItem} = $status->{nextSection};
                delete $status->{nextSection};

            }
            elsif ( $l =~ m/^#\s?(.*)$/ ) {

                # Bog standard comment
                $status->{specItem}->appendText($1);
            }

        }
        catch {
            my $e = Foswiki::Exception::Fatal->transmute( $_, 0 );

            if (
                $e->isa(
                    'Foswiki::Exception::Config::Spec::Format::legacy::Flow')
              )
            {
                $exception = $e;
            }
            else {
                $e->rethrow;
            }
        };

        if ($exception) {

            # Last and UpSection exception for now do the same. But this may
            # change in the future if post-loop processing will emerge.
            last
              if $exception->isa(
                'Foswiki::Exception::Config::Spec::Format::legacy::Last')
              || $exception->isa(
                'Foswiki::Exception::Config::Spec::Format::legacy::UpSection');
            next
              if $exception->isa(
                'Foswiki::Exception::Config::Spec::Format::legacy::Repeat');
        }
    }
}

sub parse {
    my $this     = shift;
    my $specFile = shift;

    $this->_specFile($specFile);
    $this->specSrc( $specFile->content );

    # Untaint the code.
    $specFile->content =~ /^(.*)$/s;
    my $specCode = $1;

    my (@specs);

   # It seems as it was initially thought to make some items optional. Though
   # it's never made its way into the final implementation (look for $optional
   # use in LoadSpec.pm – it's never been used) but commented out defaults are
   # not ignored. For this purpose we simply remove single comment char in
   # front of $Foswiki::cfg declarations. To make them real comments one must
   # double the sharp symbol.
    $specCode =~ s/^#?\s*\$(?:(?:Fosw|TW)iki::)cfg/\$this->_specDef->/mg;

    eval $specCode;
    die $@ if $@;

    $this->_sectionParse( specs => \@specs );

    return @specs;
}

sub prepareSpecLines {
    return scalar( @{ $_[0]->specSrc } );
}

sub prepareNextLine {
    return 0;
}

sub _prepareSpecDef {
    return {};
}

sub _trigger_specSrc {
    my $this = shift;
    $this->clear_specLines;
    $this->clear_nextLine;
    $this->clear_recordedLine;
}
1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2016 Foswiki Contributors. Foswiki Contributors
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
