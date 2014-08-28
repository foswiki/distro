# See bottom of file for license and copyright information
package Foswiki::Configure::LoadSpec;

=begin TML

---+ package Foswiki::Configure::LoadSpec

This is a parser for configuration declaration files, such as
Foswiki.spec, and the Config.spec files in extensions.

The supported syntax in declaration files is as follows:
<verbatim>
cfg ::= ( setting | section | extension )* ;
setting ::= BOL typespec EOL comment* BOL def ;
typespec ::= "**" typeid options "**" ;
def ::= "$" ["Foswiki::"] "cfg" keys "=" value ";" ;
keys ::= ( "{" id "}" )+ ;
value is any perl value not including ";"
comment ::= BOL "#" string EOL ;
section ::= BOL "#--+" string ( "--" options )? EOL comment* ;
extension ::= BOL " *" id "*"
EOL ::= end of line
BOL ::= beginning of line
typeid ::= id ;
id ::= a \w+ word (legal Perl bareword)
</verbatim>

A *section* is simply a divider used to create blocks. It can
  have varying depth depending on the number of + signs and may have
  options after -- e.g. #---+ Section -- TABS EXPERT

A *setting* is the sugar required for the setting of a single
  configuration value.

An *extension* is a pluggable UI extension that supports some extra UI
  functionality, such as the menu of languages or the menu of plugins.

Each *setting* has a *typespec* and a *def*.

The typespec consists of a type id and some options. Types are loaded by
type id from the Foswiki::Configure::TypeUIs hierachy - for example, type
BOOLEAN is defined by Foswiki::Configure::TypeUIs::BOOLEAN. Each type is a
subclass of Foswiki::Configure::TypeUI - see that class for more details of
what is supported.

A *def* is a specification of a field in the $Foswiki::cfg hash,
together with a perl value for that hash. Each field can have an
associated *Checker* which is loaded from the Foswiki::Configure::Checkers
hierarchy. Checkers are responsible for specific checks on the value of
that variable. For example, the checker for $Foswiki::cfg{Banana}{Republic}
will be expected to be found in
Foswiki::Configure::Checkers::Banana::Republic.
Checkers are subclasses of Foswiki::Configure::Checker. See that class for
more details.

An *extension* is a placeholder for a Foswiki::Configure::Pluggable.

=cut

use strict;
use warnings;

use Assert;

use Foswiki::Configure::Section   ();
use Foswiki::Configure::Value     ();
use Foswiki::Configure::Item      ();
use Foswiki::Configure::Load      ();
use Foswiki::Configure::FileUtil  ();
use Foswiki::Configure::Pluggable ();

our @errors;      # Log of errors
our @warnings;    # and warnings

our $TRUE  = 1;   # Required for checking default value syntax
our $FALSE = 0;

use constant TRACE => 0;

=begin TML

---++ Global $RAW_VALS
Set true to suppress parsing of attribute values (FEEDBACK and
CHECK strings) and simply store them as strings. This is
useful for performance, when these items are not required.
Default behaviour is to parse the strings.

=cut

our $RAW_VALS = 0;

=begin TML

---++ Global $FIRST_SECTION_ONLY
Set true to skip reading all except the first section.
This is useful if we have no LocalSite.cfg yet.
Default behaviour is to read all sections.

=cut

our $FIRST_SECTION_ONLY = 0;

sub _debugItem {
    my $item = shift;
    return ( $item->{typename} || 'Section' ) . ' '
      . ( $item->{keys} || $item->{headline} || '???' );
}

=begin TML

---++ StaticMethod readSpec($root, %options)

Load the configuration declarations. The core set is defined in
Foswiki.spec, which must be found on the @INC path and is always loaded
first. Then find all settings for extensions in their .spec files.

This *only* reads type specifications, it *does not* read values. For that,
use Foswiki::Configure::Load::readConfig (or
Foswiki::Configure::Load::readDefaults if you are after *default* values)

   * =$root= - Foswiki::Configure::Root of the model

=cut

sub readSpec {
    my ($root) = @_;

    my $file = Foswiki::Configure::FileUtil::findFileOnPath('Foswiki.spec');
    if ($file) {
        _parse( $file, $root );
    }
    unless ($FIRST_SECTION_ONLY) {

        my %read;
        foreach my $dir (@INC) {
            foreach my $subdir (
                'Foswiki/Plugins', 'Foswiki/Contrib',
                'TWiki/Plugins',   'TWiki/Contrib'
              )
            {

                _loadSpecsFrom( "$dir/$subdir", $root, \%read );
            }
        }
    }
}

=begin TML

---++ StaticMethod error($file, $line, @errs)
Report an error.

=cut

sub error {
    my ( $file, $line, $err ) = @_;
    $file ||= '';
    $line = $. unless defined $line;
    $err ||= 'Unspecified error';
    print STDERR "ERROR: $file:$line $err\n" if TRACE;
    Carp::confess "ERROR: $file:$line $err\n";
    push( @errors, [ $file, $line, $err ] );
}

=begin TML

---++ StaticMethod warning($file, $line, @errs)
Report an error.

=cut

sub warning {
    my ( $file, $line, $err ) = @_;
    return error(@_) unless $err;
    $file ||= '';
    $line = $. unless defined $line;
    push( @warnings, [ $file, $line, $err ] );
}

sub _loadSpecsFrom {
    my ( $dir, $root, $read ) = @_;

    return unless opendir( D, $dir );

    # note we ignore specs from any extension where the name starts
    # with "Empty" e.g. EmptyPlugin, EmptyContrib
    foreach my $extension ( grep { !/^\./ && !/^Empty/ } readdir D ) {

        next if $read->{$extension};

        $extension =~ /(.*)/;
        $extension = $1;    # untaint
        my $file = "$dir/$extension/Config.spec";
        next unless -e $file;
        _parse( $file, $root );
        $read->{$extension} = $file;
    }
    closedir(D);
}

{

    # Inner class that represents section headings temporarily during the
    # parse. They are expanded to section blocks at the end.
    package SectionMarker;
    @SectionMarker::ISA = ('Foswiki::Configure::Item');

    sub new {
        my ( $class, $depth, $head ) = @_;
        my $this = bless( {}, $class );
        $this->{Depth}    = $depth + 1;
        $this->{Headline} = $head;
        return $this;
    }

    sub getValueObject { return; }
}

# Process the config array and add section objects
sub _extractSections {
    my ( $settings, $root ) = @_;

    my $section = $root;
    my $depth   = 0;

    foreach my $item (@$settings) {
        if ( $item->isa('SectionMarker') ) {
            my $opts = '';
            if ( $item->{Headline} =~ s/^(.*?)\s*--\s*(.*?)\s*$/$1/ ) {
                $opts = $2;
            }
            my $ns =
              $root->getSectionObject( $item->{Headline}, $item->{Depth} + 1 );
            if ($ns) {
                $depth = $item->{Depth};
            }
            else {
                while ( $depth > $item->{Depth} - 1 ) {
                    $section = $section->{_parent};
                    $depth--;
                }
                while ( $depth < $item->{Depth} - 1 ) {
                    my $ns = new Foswiki::Configure::Section();
                    $section->addChild($ns);
                    $section = $ns;
                    $depth++;
                }
                $ns = new Foswiki::Configure::Section(
                    headline => $item->{Headline},
                    opts     => $opts
                );
                $ns->{desc} = $item->{desc};
                $section->addChild($ns);
                $depth++;
            }
            $section = $ns;
        }
        elsif ( $item->isa('Foswiki::Configure::Value') ) {

            # Skip it if we already have a settings object for these
            # keys (first loaded always takes precedence, irrespective
            # of which section it is in)
            my $vo = $root->getValueObject( $item->{keys} );
            next if ($vo);
            $section->addChild($item);
        }
        else {
            $section->addChild($item);
        }
    }
}

# See if we have already build a value object for these keys
sub _getValueObject {
    my ( $keys, $settings ) = @_;
    foreach my $item (@$settings) {
        my $i = $item->getValueObject($keys);
        return $i if $i;
    }
    return;
}

# Parse the config declaration file and return a root node for the
# configuration it describes

sub _parse {
    my ( $file, $root ) = @_;

    open( F, '<', $file ) || return '';
    local $/ = "\n";
    my $open = undef;    # current setting or section
    my $isEnhancing = 0; # Is the current $open an existing item being enhanced?
    my @settings;
    my $sectionNum = 0;
    my @context = ( $file, 0 );

    print STDERR "Loading specs from $file\n" if TRACE;

    while ( my $l = <F> ) {
        chomp $l;

        $context[1] = $.;

        # Continuation lines

        while ( $l =~ s/\\$// ) {
            my $cont = <F>;
            last unless defined $cont;
            chomp $cont;
            $cont =~ s/^#// if ( $l =~ /^#/ );
            $cont =~ s/^\s+/ /;
            if ( $cont =~ /^#/ ) {
                $l .= '\\';
            }
            else {
                $l .= $cont;
            }
        }

        last if ( $l =~ /^(1;|__[A-Z]+__)/ );
        next if ( $l =~ /^\s*$/ || $l =~ /^\s*#!/ );

        if ( $l =~ /^#\s*\*\*\s*([A-Z]+)\s*(.*?)\s*\*\*\s*$/ ) {

            # **STRING 30 EXPERT**
            if ( $open && !$isEnhancing ) {
                print STDERR "\tClosed "
                  . _debugItem($open) . ' at '
                  . __LINE__ . "\n"
                  if TRACE;
                push( @settings, $open );
                $open = undef;
            }
            if ( $1 eq 'ENHANCE' ) {

                # Enhance an existing value
                $open = $root->getValueObject($2);
                error( @context, "No such value $2" )
                  unless $open;
                $isEnhancing = $open ? 1 : 0;
                print STDERR "\tEnhancing $open->{keys}\n" if TRACE && $open;
            }
            else {
                my $type = $1;
                my $opts = $2;

                eval {
                    $open = Foswiki::Configure::Value->new(
                        $1,
                        opts       => $2,
                        defined_at => [@context]
                    );
                    print STDERR "\tOpened $open->{typename}\n" if TRACE;
                };

                if ($@) {
                    error( @context, $@ );
                    $open = undef;
                }
                $isEnhancing = 0;
            }
        }

        elsif (
            $l =~ /^(#)?\s*\$(?:(?:Fosw|TW)iki::)?cfg([^=\s]*)\s*=\s*(.*?)$/ )
        {

            # $Foswiki::cfg{Rice}{Brown} =

            my $optional = $1;
            my $keys     = $2;
            my $value    = $3;

            if ( $keys eq '{WebMasterName}' ) {
                ASSERT($open) if DEBUG;
            }
            unless ( $keys =~ /^$Foswiki::Configure::Load::ITEMREGEX$/ ) {
                error( @context, 'Invalid item specifier $keys' );
                $open = undef;
                next;
            }

            while ( $value !~ s/\s*;\s*$// ) {
                my $cont = <F>;
                last unless defined $cont;
                chomp $cont;
                $cont =~ s/^\s+/ /;
                unless ( $cont =~ /^#/ ) {
                    $value .= $cont;
                }
            }

            # check it's a valid perl expression, ignoring uninitialised
            # variable warnings inside strings.
            no warnings;
            $value =~ /^(.*)$/;
            eval $1;
            die "Cannot eval value '$value': $@" if $@;
            $value = $1;
            use warnings;

            if ( $open && $open->isa('SectionMarker') ) {
                unless ($isEnhancing) {
                    print STDERR "\tClosed "
                      . _debugItem($open) . ' at '
                      . __LINE__ . "\n"
                      if TRACE;
                    push( @settings, $open );
                    $open = undef;
                }
            }

            if ( !$open ) {
                next if $root->getValueObject($keys);

                # A pluggable may have already added an entry for these keys
                next if ( _getValueObject( $keys, \@settings ) );

                # This is an untyped value.
                $open        = Foswiki::Configure::Value->new('UNKNOWN');
                $isEnhancing = 0;
            }
            $open->{defined_at} = [@context];

            # Record the value *string*, internal formatting et al.
            ASSERT( UNTAINTED($value), $value ) if DEBUG;
            if ( $value =~ /^qr\/(.*)\/$/ ) {

                # regexp; convert to string
                $value = eval $value;
                $value = "$value";
                $value =~ s/'/\\'/g;
                $value = "'$value'";
            }
            $open->{default} = $value;

            $open->{keys} = $keys;
            unless ($isEnhancing) {
                print STDERR "\tClosed "
                  . _debugItem($open) . ' at '
                  . __LINE__ . "\n"
                  if TRACE;
                push( @settings, $open );
            }
            $open        = undef;
            $isEnhancing = 0;
        }

        elsif ( $l =~ /^#\s*\*([A-Z]+)\*/ ) {

            # *FINDEXTENSIONS* pluggable
            my $name   = $1;
            my $subset = \@settings;

            if ($isEnhancing) {
                die "Cannot ENHANCE a non-section with a Pluggable"
                  if ( $open
                    && !$open->isa('Foswiki::Configure::Section') );
                $subset      = \@{ $open->{children} };
                $isEnhancing = $open;
            }
            elsif ($open) {
                if (   !$open->isa('Foswiki::Configure::Section')
                    && !$open->isa('SectionMarker') )
                {
                    my $otype = $open->{typename} || $open;
                    error( @context, "Incomplete $otype declaration" );
                }
                elsif ( !$isEnhancing ) {
                    push( @settings, $open );
                    print STDERR "\tClosed "
                      . _debugItem($open) . ' at '
                      . __LINE__ . "\n"
                      if TRACE;
                }
                $open = undef;
            }

            eval {
                Foswiki::Configure::Pluggable::load( $name, $subset, @context );
            };
            if ($@) {
                warning( @context, "Can't load pluggable $name: $@" );
            }
            elsif ($isEnhancing) {

                # Have to shoehorn in parent links
                foreach my $kid (@$subset) {
                    $kid->{_parent} = $isEnhancing
                      unless $kid->{_parent};
                }
            }

            $isEnhancing = 0;
        }

        elsif ( $l =~ /^#\s*---\+(\+*) *(.*?)$/ ) {

            # ---++ Section
            # Only load the first section if we don't have a LocalSite.cfg
            # yet
            last if ( $sectionNum && $FIRST_SECTION_ONLY );
            $sectionNum++;
            if ( $open && !$isEnhancing ) {

               # We have an open item.  If it's a value, we don't want to create
               # it since that will confuse the UI.  Report such errors.
                if ( $open->isa('Foswiki::Configure::Value') ) {
                    my $otype = $open->{typename};
                    error( @context, "Incomplete $otype declaration" );
                }
                elsif ( !$isEnhancing ) {
                    push( @settings, $open );
                    print STDERR "\tClosed "
                      . _debugItem($open) . ' at '
                      . __LINE__ . "\n"
                      if TRACE;
                }
            }
            $open = new SectionMarker( length($1), $2 );
            $isEnhancing = 0;
        }

        elsif ( $l =~ /^#\s?(.*)$/ ) {

            # Bog standard comment
            $open->append( 'desc', $1 ) if $open;
        }
    }
    close(F);
    if ( $open && !$isEnhancing ) {
        if ( $open->isa('Foswiki::Configure::Value') ) {
            my $otype = $open->{typename};
            error( $file, $., "Incomplete $otype declaration" );
        }
        else {
            push( @settings, $open ) unless $isEnhancing;
            print STDERR "\tClosed "
              . _debugItem($open) . ' at '
              . __LINE__ . "\n"
              if TRACE;
        }
    }
    _extractSections( \@settings, $root );
}

1;
__END__

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2014 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
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
