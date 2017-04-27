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

The typespec consists of a type id and some options.

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
use Foswiki::Configure::Reporter  ();

our $TRUE  = 1;    # Required for checking default value syntax
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

sub _debugItem {
    my $item = shift;
    return ( $item->{typename} || 'Section' ) . ' '
      . ( $item->{keys} || $item->{headline} || '???' );
}

=begin TML

---++ StaticMethod readSpec($root, $reporter)

Load the configuration declarations. The core set is defined in
Foswiki.spec, which must be found on the @INC path and is always loaded
first. Then find all settings for extensions in their .spec files.

This *only* reads type specifications, it *does not* read values. For that,
use Foswiki::Configure::Load::readConfig.

   * =$root= - Foswiki::Configure::Root of the model

=cut

sub readSpec {
    my ( $root, $reporter ) = @_;

    my $file = Foswiki::Configure::FileUtil::findFileOnPath('Foswiki.spec');
    if ($file) {
        parse( $file, $root, $reporter );
    }

    my %read;
    foreach my $dir (@INC) {
        foreach my $subdir (
            'Foswiki/Plugins', 'Foswiki/Contrib',
            'TWiki/Plugins',   'TWiki/Contrib'
          )
        {

            _findSpecsFrom( "$dir/$subdir", $root, \%read, $reporter );
        }
    }

    foreach my $file ( sort keys %read ) {
        parse( $read{$file}, $root, $reporter );
    }

}

sub _findSpecsFrom {
    my ( $dir, $root, $read, $reporter ) = @_;

    return unless opendir( D, $dir );

    # note we ignore specs from any extension where the name starts
    # with "Empty" e.g. EmptyPlugin, EmptyContrib
    my @specfiles;
    foreach my $extension ( sort grep { !/^\./ && !/^Empty/ } readdir D ) {

        next if $read->{$extension};

        $extension =~ m/(.*)/;
        $extension = $1;    # untaint
        my $file = "$dir/$extension/Config.spec";
        next unless -e $file;
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
              $root->getSectionObject( $item->{Headline}, $item->{Depth} );
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

=begin TML

---++ StaticMethod parse($file, $root, $reporter [, $cant_enhance])

Parse the config declaration $file and add it to a $root node for the
configuration it describes. If $cant_enhance, don't report ENHANCE
failures (which may be due to a missing root spec; which is OK when
installing a package)

=cut

sub parse {
    my ( $file, $root, $reporter, $cant_enhance ) = @_;
    my $fh;

    unless ( open( $fh, '<', $file ) ) {
        $reporter->ERROR("$file open failed: $!");
        return '';
    }

    local $/ = "\n";
    my $open = undef;    # current setting or section
    my $isEnhancing = 0; # Is the current $open an existing item being enhanced?
    my @settings;
    my $sectionNum = 0;

    $reporter->NOTE("Loading specs from $file") if TRACE;

    while ( my $l = <$fh> ) {
        chomp $l;

        my $context = "$file: $.";

        # Continuation lines

        while ( $l =~ s/\\$// ) {
            my $cont = <$fh>;
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

        last if ( $l =~ m/^(1;|__[A-Z]+__)/ );
        next if ( $l =~ m/^\s*$/ || $l =~ m/^\s*#!/ );

        if ( $l =~ m/^#\s*\*\*\s*([A-Z]+)\s*(.*?)\s*\*\*\s*$/ ) {

            # **STRING 30 EXPERT**
            if ( $open && !$isEnhancing ) {
                $reporter->NOTE(
                    "\tClosed " . _debugItem($open) . ' at ' . __LINE__ )
                  if TRACE;
                push( @settings, $open );
                $open = undef;
            }
            if ( $1 eq 'ENHANCE' ) {

                # Enhance an existing value
                $open = $root->getValueObject($2);
                unless ( $open || $cant_enhance ) {
                    $reporter->ERROR("$context: No such value $2");
                }
                $isEnhancing = $open ? 1 : 0;
                $reporter->NOTE("\tEnhancing $open->{keys}")
                  if TRACE && $open;
            }
            else {
                my $type = $1;
                my $opts = $2;
                eval {
                    $open = Foswiki::Configure::Value->new(
                        $type,
                        opts       => $opts,
                        defined_at => [ $file, $. ]
                    );
                    $reporter->NOTE("\tOpened $open->{typename}") if TRACE;
                };

                if ($@) {
                    $reporter->ERROR("$context: $@");
                    $open = undef;
                }
                $isEnhancing = 0;
            }
        }

        elsif (
            $l =~ m/^(#)?\s*\$(?:(?:Fosw|TW)iki::)?cfg([^=\s]*)\s*=\s*(.*?)$/ )
        {

            # $Foswiki::cfg{Rice}{Brown} =

            my $optional = $1;
            my $keys     = $2;
            my $value    = $3;

            if ( $keys eq '{WebMasterName}' ) {
                ASSERT($open) if DEBUG;
            }
            unless ( $keys =~ m/^$Foswiki::Configure::Load::ITEMREGEX$/ ) {
                $reporter->ERROR("$context: Invalid item specifier $keys");
                $open = undef;
                next;
            }

            # Restore initial \n for continued lines
            $value .= "\n" unless $value =~ m/\s*;\s*$/;

            # Read the value verbatim, retaining internal \s
            while ( $value !~ s/\s*;\s*$//s ) {
                my $cont = <$fh>;
                last unless defined $cont;
                $value .= $cont;
            }

            # check it's a valid perl expression, ignoring uninitialised
            # variable warnings inside strings.
            $value =~ m/^\s*(.*?)[\s;]*$/s;    # trim and untaint
            $value = $1;
            no warnings;
            eval($value);
            use warnings;
            $reporter->ERROR( "$context: Cannot eval value '$value': "
                  . Foswiki::Configure::Reporter::stripStacktrace($@) )
              if $@;

            if ( $open && $open->isa('SectionMarker') ) {
                unless ($isEnhancing) {
                    $reporter->NOTE(
                        "\tClosed " . _debugItem($open) . ' at ' . __LINE__ )
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
            $open->{defined_at} = [ $file, $. ];

            # Record the value *string*, internal formatting et al.
            # This is the best way to retain perl formatting while
            # being sensitive to changes.
            $open->{default} = $1;

            # Configure treats all regular expressions as simple quoted string,
            # Convert from qr/ /  notation to a simple quoted string
            if (   $open->{typename} eq 'REGEX'
                && $open->{default} =~ m/^qr(.)(.*)\1$/ )
            {

                # Convert a qr// into a quoted string

                # Strip off useless furniture (?^: ... )
                while ( $open->{default} =~ s/^\(\?\^:(.*)\)$/$1/ ) {
                }

                # Convert quoting for a single-quoted string. All we
                # need to do is protect single quote
                $open->{default} =~ s/'/\\'/g;
                $open->{default} = "'" . $open->{default} . "'";
            }
            elsif ( $open->{typename} eq 'REGEX' ) {
                $open->{default} =~
                  s/\\'/'/g;    # unescape any escaped ' for quoted string.
            }

            $open->{keys} = $keys;
            unless ($isEnhancing) {
                $reporter->NOTE(
                    "\tClosed " . _debugItem($open) . ' at ' . __LINE__ )
                  if TRACE;
                push( @settings, $open );
            }
            $open        = undef;
            $isEnhancing = 0;
        }

        elsif ( $l =~ m/^#\s*\*([A-Z]+)\*/ ) {

            # *FINDEXTENSIONS* pluggable
            my $name   = $1;
            my $subset = \@settings;

            if ($isEnhancing) {
                $reporter->ERROR(
                    "$context: Cannot ENHANCE a non-section with a Pluggable")
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
                    $reporter->ERROR("$context: Incomplete $otype declaration");
                }
                elsif ( !$isEnhancing ) {
                    push( @settings, $open );
                    $reporter->NOTE(
                        "\tClosed " . _debugItem($open) . ' at ' . __LINE__ )
                      if TRACE;
                }
                $open = undef;
            }

            eval {
                Foswiki::Configure::Pluggable::load( $name, $subset, $file,
                    $. );
            };
            if ($@) {
                $reporter->WARN("Can't load pluggable $name: $@");
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

        elsif ( $l =~ m/^#\s*---\+(\+*) *(.*?)$/ ) {

            # ---++ Section
            $sectionNum++;
            if ( $open && !$isEnhancing ) {

               # We have an open item.  If it's a value, we don't want to create
               # it since that will confuse the UI.  Report such errors.
                if ( $open->isa('Foswiki::Configure::Value') ) {
                    my $otype = $open->{typename};
                    $reporter->ERROR("$context: Incomplete $otype declaration");
                }
                elsif ( !$isEnhancing ) {
                    push( @settings, $open );
                    $reporter->NOTE(
                        "\tClosed " . _debugItem($open) . ' at ' . __LINE__ )
                      if TRACE;
                }
            }
            $open = new SectionMarker( length($1), $2 );
            $isEnhancing = 0;
        }

        elsif ( $l =~ m/^#\s?(.*)$/ ) {

            # Bog standard comment
            $open->append( 'desc', $1 ) if $open;
        }
    }
    close($fh);
    if ( $open && !$isEnhancing ) {
        if ( $open->isa('Foswiki::Configure::Value') ) {
            my $otype = $open->{typename};
            $reporter->ERROR("$file:$.: Incomplete $otype declaration");
        }
        else {
            push( @settings, $open ) unless $isEnhancing;
            $reporter->NOTE(
                "\tClosed " . _debugItem($open) . ' at ' . __LINE__ )
              if TRACE;
        }
    }
    _extractSections( \@settings, $root );

    # Promote the EXPERT setting up to those containers where
    # all children have it
    $root->promoteSetting('EXPERT');
}

=begin TML

---++ StaticMethod protectKeys($keystring) -> $keystring

Process a key string {Like}{This} and make sure that each key is
safe for use in an eval.

=cut

sub protectKeys {
    my $k = shift;
    $k =~ s/^\{(.*)\}$/$1/;
    return '{'
      . join(
        '}{', map { protectKey($_) }
          split( /\}\{/, $k )
      ) . '}';
}

=begin TML

---++ StaticMethod protectKey($keystring) -> $keystring

Process a key string (a hash index) and make sure that it is
safe for use as a perl hash index.

=cut

sub protectKey {
    my $k = shift;
    return $k if $k =~ m/^[a-z_][a-z0-9_]*$/i;

    # Remove existing quotes, if there
    $k =~ s/^(["'])(.*)\1$/$2/i;

    # Use ' to suppress interpolation (just in case)
    $k =~ s/'/\\'/g;    # escape '
    $k = "'$k'";
    if (DEBUG) {
        eval($k);
        ASSERT( !$@, $k );
    }
    return $k;
}

=begin TML

---++ StaticMethod addSpecDefaultsToCfg($spec, \%cfg, \%added)

   * =$spec= - ref to a Foswiki::Configure::Item
   * =\%cfg= ref to a cfg hash e.g. Foswiki::cfg
   * =\%added= (optional) ref to a hash to receive keys that were added

For each key in the $spec missing from the %cfg passed, add the
default (unexpanded) from the spec to the %cfg, if it exists.

=cut

sub addSpecDefaultsToCfg {
    my ( $spec, $cfg, $added ) = @_;

    if ( $spec->{children} ) {
        foreach my $child ( @{ $spec->{children} } ) {
            addSpecDefaultsToCfg( $child, $cfg );
        }
    }
    else {
        if ( exists( $spec->{default} )
            && eval("!exists(\$cfg->$spec->{keys})") )
        {
            # {default} stores a value string. Convert it to the
            # value suitable for storing in cfg
            print STDERR "Defaulting $spec->{keys}\n" if TRACE;
            my $value = eval( $spec->{default} );
            eval("\$cfg->$spec->{keys}=$spec->{default}");
            $added->{ $spec->{keys} } = $spec->{default} if $added;
        }
    }
}

=begin TML

---++ StaticMethod addCfgValuesToSpec(\%cfg, $spec)

   * =\%cfg= ref to a cfg hash e.g. Foswiki::cfg
   * =$spec= - ref to a Foswiki::Configure::Item

For each key in the spec add the current value from the %cfg
as current_value. If the key is
not set in the %cfg, then set it to the default.
Note that the %cfg should contain *unexpanded* values.

=cut

sub addCfgValuesToSpec {
    my ( $cfg, $spec ) = @_;
    if ( $spec->{children} ) {
        foreach my $child ( @{ $spec->{children} } ) {
            addCfgValuesToSpec( $cfg, $child );
        }
    }
    else {
        if ( eval("exists(\$cfg->$spec->{keys})") ) {

            # Encode the value as something that can be handled by
            # UIs
            my $value = eval("\$cfg->$spec->{keys}");
            ASSERT( !$@ ) if DEBUG;
            $spec->{current_value} = $spec->encodeValue($value);
        }

        # Don't do this; it's not the case that the default value
        # will end up in LocalSite.cfg
        #elsif (exists($spec->{default})) {
        #    eval("\$spec->{current_value}=eval(\$spec->{default})");
        #}
    }
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
