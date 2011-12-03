# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Configure::FoswikiCfg

This is both a parser for configuration declaration files, such as
FoswikiCfg.spec, and a serialisation visitor for writing out changes
to LocalSite.cfg

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
type id from the Foswiki::Configure::Types hierachy - for example, type
BOOLEAN is defined by Foswiki::Configure::Types::BOOLEAN. Each type is a
subclass of Foswiki::Configure::Type - see that class for more details of
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

An *extension* is a placeholder for a pluggable UI module (a class in
Foswiki::Configure::Checkers::UIs)

=cut

package Foswiki::Configure::FoswikiCfg;

use strict;
use warnings;
use Data::Dumper ();

use Foswiki::Configure::Visitor ();
our @ISA = ('Foswiki::Configure::Visitor');

use Foswiki::Configure::Util      ();
use Foswiki::Configure::Section   ();
use Foswiki::Configure::Value     ();
use Foswiki::Configure::Pluggable ();
use Foswiki::Configure::Item      ();

my %dupItem;

=begin TML

---++ ClassMethod new()

Used in saving, when we need a callback. Otherwise the methods here are
all static.

=cut

sub new {
    my $class = shift;

    return bless( {}, $class );
}

=begin TML

---++ StaticMethod load($root, $haveLSC)

Load the configuration declarations. The core set is defined in
Foswiki.spec, which must be found on the @INC path and is always loaded
first. Then find all settings for extensions in their .spec files.

This *only* reads type specifications, it *does not* read values.

SEE ALSO Foswiki::Configure::Load::readDefaults

   * $root Foswiki::Configure::Root of the model
   * $haveLSC if we have a LocalSite.cfg

If we don't have a LocalSite.cfg, only Foswiki.spec will be loaded
(Config.spec files from extensions will be skipped) and only the
first section of Config.spec will be loaded. This means that checkers
will only be built and run for that first section.

=cut

sub load {
    my ( $root, $haveLSC ) = @_;

    my $file = Foswiki::Configure::Util::findFileOnPath('Foswiki.spec');
    if ($file) {
        _parse( $file, $root, $haveLSC );
    }
    if ($haveLSC) {

        # Blot out specs from the template EmptyPlugin
        my %read = ( EmptyPlugin => 1 );
        foreach my $dir (@INC) {
            _loadSpecsFrom( "$dir/Foswiki/Plugins", $root, \%read );
            _loadSpecsFrom( "$dir/Foswiki/Contrib", $root, \%read );
            _loadSpecsFrom( "$dir/TWiki/Plugins",   $root, \%read );
            _loadSpecsFrom( "$dir/TWiki/Contrib",   $root, \%read );
        }
    }
}

sub _loadSpecsFrom {
    my ( $dir, $root, $read ) = @_;

    return unless opendir( D, $dir );
    foreach my $extension ( grep { !/^\./ } readdir D ) {
        next if $read->{$extension};
        $extension =~ /(.*)/;
        $extension = $1;    # untaint
        my $file = "$dir/$extension/Config.spec";
        next unless -e $file;
        _parse( $file, $root, 1 );
        $read->{$extension} = $file;
    }
    closedir(D);
}

###########################################################################
## INPUT
###########################################################################
{

    # Inner class that represents section headings temporarily during the
    # parse. They are expanded to section blocks at the end.
    package SectionMarker;
    @SectionMarker::ISA = ('Foswiki::Configure::Item');

    sub new {
        my ( $class, $depth, $head ) = @_;
        my $this = bless( {}, $class );
        $this->{depth} = $depth + 1;
        $this->{head}  = $head;
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
            if ( $item->{head} =~ s/^(.*?)\s*--\s*(.*?)\s*$/$1/ ) {
                $opts = $2;
            }
            my $ns =
              $root->getSectionObject( $item->{head}, $item->{depth} + 1 );
            if ($ns) {
                $depth = $item->{depth};
            }
            else {
                while ( $depth > $item->{depth} - 1 ) {
                    $section = $section->{parent};
                    $depth--;
                }
                while ( $depth < $item->{depth} - 1 ) {
                    my $ns = new Foswiki::Configure::Section('');
                    $section->addChild($ns);
                    $section = $ns;
                    $depth++;
                }
                $ns = new Foswiki::Configure::Section( $item->{head}, $opts );
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
            my $vo = $root->getValueObject( $item->getKeys() );
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
    my ( $file, $root, $haveLSC ) = @_;

    open( F, '<', $file ) || return '';
    local $/ = "\n";
    my $open = undef;    # current setting or section
    my @settings;
    my $sectionNum = 0;

    foreach my $l (<F>) {
        $l =~ s/\r//g;
        last if ( $l =~ /^1;|^__\w+__/ );
        if ( $l =~ /^#\s*\*\*\s*([A-Z]+)\s*(.*?)\s*\*\*\s*$/ ) {

            # **STRING 30 EXPERT**
            _pusht( \@settings, $open ) if $open;
            $open = new Foswiki::Configure::Value( $1, opts => $2 );
        }

        elsif ( $l =~ /^#?\s*\$(?:(?:Fosw|TW)iki::)?cfg([^=\s]*)\s*=(.*)$/ ) {

            # $Foswiki::cfg{Rice}{Brown} =
            my $keys         = $1;
            my $tentativeVal = $2;
            if ( $open && $open->isa('SectionMarker') ) {
                _pusht( \@settings, $open );
                $open = undef;
            }

            # If there is already a UI object for
            # these keys, we don't need to add another. But if there
            # isn't, we do.
            if ( !$open ) {
                next if $root->getValueObject($keys);

                # A pluggable may have already added an entry for these keys
                next if ( _getValueObject( $keys, \@settings ) );

                # This is an untyped value.
                $open = new Foswiki::Configure::Value('UNKNOWN');
            }
            $open->set( keys => $keys );
            _pusht( \@settings, $open );
            $open = undef;
        }

        elsif ( $l =~ /^#\s*\*([A-Z]+)\*/ ) {

            # *FINDEXTENSIONS*
            my $pluggable = $1;
            my $p         = Foswiki::Configure::Pluggable::load($pluggable);
            if ($p) {
                _pusht( \@settings, $open ) if $open;
                $open = $p;
            }
            elsif ($open) {

                # Not recognised
                $l =~ s/^#\s?//;
                $open->addToDesc($l);
            }
        }

        elsif ( $l =~ /^#\s*---\+(\+*) *(.*?)$/ ) {

            # ---++ Section
            # Only load the first section if we don't have LocalSite.cfg
            last if ( $sectionNum && !$haveLSC );
            $sectionNum++;
            _pusht( \@settings, $open ) if $open;
            $open = new SectionMarker( length($1), $2 );
        }

        elsif ( $l =~ /^#\s?(.*)$/ ) {

            # Bog standard comment
            $open->addToDesc($1) if $open;
        }
    }
    close(F);
    _pusht( \@settings, $open ) if $open;
    _extractSections( \@settings, $root );
}

sub _pusht {
    my ( $a, $n ) = @_;
    foreach my $v (@$a) {
        Carp::confess "$n" if $v eq $n;
    }
    push( @$a, $n );
}

###########################################################################
## OUTPUT
###########################################################################

=begin TML

---++ StaticMethod save($root, $valuer, $logger, $insane)
   * $root is a Foswiki::Configure::Root
   * $valuer is a Foswiki::Configure::Valuer
   * $logger an object that implements a logChange($keys,$value) method,
     called to record the changes.
   * $insane set to true if existing LocalSite.cfg should be overwritten

Generate .cfg file format output

=cut

sub save {
    my ( $root, $valuer, $logger, $insane ) = @_;

    # Object used to act as a visitor to hold the output
    my $this = new Foswiki::Configure::FoswikiCfg();
    $this->{logger}  = $logger;
    $this->{valuer}  = $valuer;
    $this->{root}    = $root;
    $this->{content} = '';

    my $lsc = Foswiki::Configure::Util::findFileOnPath('LocalSite.cfg');
    unless ($lsc) {

        # If not found on the path, park it beside Foswiki.spec
        $lsc = Foswiki::Configure::Util::findFileOnPath('Foswiki.spec') || '';
        $lsc =~ s/Foswiki\.spec/LocalSite.cfg/;
    }

    if ( !$insane && -f $lsc ) {
        open( F, '<', $lsc );
        local $/ = undef;
        $this->{content} = <F>;
        close(F);
    }
    else {
        $this->{content} = <<'HERE';
# Local site settings for Foswiki. This file is managed by the 'configure'
# CGI script, though you can also make (careful!) manual changes with a
# text editor.  See the Foswiki.spec file in this directory for documentation
# Extensions are documented in the Config.spec file in the Plugins/<extension>
# or Contrib/<extension> directories
HERE
    }

    # Clean out deprecated settings, so they don't occlude the
    # replacements
    foreach my $key ( keys %Foswiki::Configure::Load::remap ) {
        $this->{content} =~ s/\$Foswiki::cfg$key\s*=.*?;\s*//sg;
    }

    my $out = $this->_save();
    open( F, '>', $lsc )
      || die "Could not open $lsc for write: $!";
    print F $this->{content};
    close(F);

    return '';
}

sub _save {
    my $this = shift;

    $this->{content} =~ s/\s*1;\s*$/\n/sg;
    $this->{root}->visit($this);
    $this->{content} .= "1;\n";
}

# Visitor method called by node traversal during save. Incrementally modify
# values, unless a value is reverting to the default in which case remove it.
sub startVisit {
    my ( $this, $visitee ) = @_;

    if ( $visitee->isa('Foswiki::Configure::Value') ) {
        my $keys   = $visitee->getKeys();
        my $warble = $this->{valuer}->currentValue($visitee);
        return 1 unless defined $warble;

        if ( $this->{logger} ) {
            my $logValue = $visitee->asString( $this->{valuer} );
            $this->{logger}->logChange( $visitee->getKeys(), $logValue );
        }

        # For some reason Data::Dumper ignores the second parameter sometimes
        # when -T is enabled, so have to do a substitution
        my $txt = Data::Dumper->Dump( [$warble] );
        $txt =~ s/VAR1/Foswiki::cfg$keys/;

 # Substitute any existing value, or append if not there
 #unless ( $this->{content} =~ s/^\s*?\$(Foswiki::)?cfg$keys\s*=.*?;\n/$txt/ms )
 #
 # SMELL:  The _updateEntry call is needed to fix up configs broken by Item9699.
        unless ( $this->{content} =~
s/^\s*?\$(?:Foswiki::)?cfg($keys)\s*=.*?;\n/&_updateEntry($1,$txt)/msge
          )
        {
            $this->{content} .= $txt;
        }
    }
    return 1;
}

sub _updateEntry {
    my $keys     = shift;
    my $newentry = shift;
    return '' if $dupItem{"$keys"};
    $dupItem{"$keys"} = 1;
    return $newentry;
}

sub endVisit {
    my ( $this, $visitee ) = @_;

    return 1;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
