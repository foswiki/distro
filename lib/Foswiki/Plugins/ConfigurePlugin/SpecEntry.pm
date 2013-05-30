# See bottom of file for license and copyright information
package Foswiki::Plugins::ConfigurePlugin::SpecEntry;

# A SpecEntry represents a single entry in a .spec file - either a
# section, an individual keyed value, or a special layout marker like
# *FINDEXTENSIONS*. It also behaves as a Value object for use with
# checkers.
use strict;
use warnings;
use Data::Structure::Util;

our $configItemRegex = qr/(?:\{(?:'[^']+'|"[^"]+"|[-:\w]+)\})+/o;

sub new {
    my $class = shift;

    return bless( {@_}, $class );
}

sub createSpecEntry {
    my $this = shift;
    return new Foswiki::Plugins::ConfigurePlugin::SpecEntry(@_);
}

sub findSpecEntry {
    my $this     = shift;
    my %search   = @_;
    my $mismatch = 0;
    my $match    = 1;
    while ( my ( $k, $e ) = each %search ) {
        $match = 0 unless ( defined $this->{$k} && $this->{$k} eq $e );
    }

    # there was no search, or the search matched all terms
    return $this if $match;

    # Search pending
    if ( 0 && $this->{_pending} ) {
        foreach my $child ( @{ $this->{_pending} } ) {
            my $cvo = $child->findSpecEntry(@_);
            return $cvo if $cvo;
        }
    }

    # Search children
    foreach my $child ( @{ $this->{children} } ) {
        my $cvo = $child->findSpecEntry(@_);
        return $cvo if $cvo;
    }
    return undef;
}

sub _appendDescription {
    my ( $this, $desc ) = @_;
    if ( $this->{description} ) {
        $this->{description} .= " $desc";
    }
    else {
        $this->{description} = $desc;
    }
}

# Add a new entry to the queue for adding to the tree.
# Must only call on the root.
sub _addPendingEntry {
    my ( $this, $n ) = @_;
    die "Cannot add undef" unless defined $n;
    foreach my $v ( @{ $this->{_pending} } ) {

        # Don't push the same entry twice
        return if ( $v eq $n );
    }
    push( @{ $this->{_pending} }, $n );
}

# Add a child to this node.
sub addChild {
    my ( $this, $child ) = @_;
    foreach my $kid ( @{ $this->{children} } ) {
        Carp::confess if $child eq $kid;
    }
    $child->{parent} = $this;

    push( @{ $this->{children} }, $child );

}

# So the JSON module can serialise blessed objects
sub TO_JSON {
    my $d = { %{ $_[0] } };
    delete $d->{parent};
    return $d;
}

sub findFileOnPath {
    my $file = shift;

    $file =~ s(::)(/)g;

    foreach my $dir (@INC) {
        if ( -e "$dir/$file" ) {
            return "$dir/$file";
        }
    }
    return;
}

# Load all spec files into a tree structure
sub loadSpecFiles {
    my $this = new Foswiki::Plugins::ConfigurePlugin::SpecEntry;

    my $file = findFileOnPath('Foswiki.spec');
    if ($file) {
        $this->_parse($file);
    }

    my %read;
    foreach my $dir (@INC) {
        $this->_loadSpecsFrom( "$dir/Foswiki/Plugins", \%read );
        $this->_loadSpecsFrom( "$dir/Foswiki/Contrib", \%read );
    }

    return $this;
}

# Load all Config.spec files from the given type directory
sub _loadSpecsFrom {
    my ( $this, $dir, $read ) = @_;

    return unless opendir( D, $dir );
    foreach my $extension ( grep { $_ !~ /^\./ } readdir D ) {
        next if $extension =~ /^Empty/;    # Skip Empty*
        next if $read->{$extension};
        $extension =~ /(.*)/;
        $extension = $1;                   # untaint
        my $file = "$dir/$extension/Config.spec";
        next unless -e $file;
        $this->_parse($file);
        $read->{$extension} = $file;
    }
    closedir(D);
}

# Merge the pending entries into the tree, creating the section
# hierarchy as we go.
sub _mergePendingEntries {
    my $this = shift;

    my $section = $this;
    my $depth   = 0;

    foreach my $item ( @{ $this->{_pending} } ) {
        if ( $item->{type} && $item->{type} eq 'SECTION' ) {
            my $ns = $this->findSpecEntry(
                title => $item->{title},
                depth => $item->{depth}
            );
            if ($ns) {

                # the section is already there
                $depth   = $item->{depth};
                $section = $ns;
            }
            else {
                while ( $depth > $item->{depth} - 1 ) {
                    $section = $section->{parent} if $section->{parent};
                    $depth--;
                }
                while ( $depth < $item->{depth} - 1 ) {
                    my $ns = createSpecEntry(
                        $this,
                        type  => 'SECTION',
                        title => '',
                        depth => $depth
                    );
                    $section->addChild($ns);
                    $section = $ns;
                    $depth++;
                }
                $section->addChild($item);
                $section = $item;
                $depth++;
            }
            next;
        }

        # Skip it if we already have a settings object for these
        # keys (first loaded always takes precedence, irrespective
        # of which section it is in)
        if ( defined $item->{keys} ) {
            my $vo = $this->findSpecEntry( keys => $item->{keys} );

            # SMELL: warning?
            next if $vo;
        }

        $section->addChild($item);
    }
    delete $this->{_pending};
}

# The parse is a two-pass process. First we load all configuration items
# in a flat array, with SectionMarker objects marking where section
# headings were found. Then we process that array to find the section
# markers and create the hierarchy.
sub _parse {
    my ( $this, $file ) = @_;

    open( F, '<', $file ) || return '';
    local $/ = "\n";
    my $open       = undef;    # current setting or section
    my $sectionNum = 0;

    while ( my $l = <F> ) {
        $l =~ s/\r//g;

        # Continuation lines

        while ( $l =~ /\\$/ && !eof F ) {
            my $cont = <F>;
            $cont =~ s/\r//g;
            $cont =~ s/^#// if ( $l =~ /^#/ );
            $cont =~ s/^\s*//;
            chomp $l;
            unless ( $cont =~ /^#/ ) {
                chop $l;
                $l .= $cont;
            }
        }
        if ( $l =~ /\\$/ ) {
            die "Reached end-of-file at $file:$., continuation expected";
        }

        last if ( $l =~ /^1;|^__\w+__/ );
        next if ( $l =~ /^\s*$/ || $l =~ /^\s*#!/ );

        if ( $l =~ /^#\s*\*\*\s*([A-Z]+)\s*(.*?)\s*\*\*\s*$/ ) {

            # **STRING 30 EXPERT**
            $this->_addPendingEntry($open) if $open;
            if ( $1 eq 'ENHANCE' ) {

                # Enhance the description of an existing value
                $open = $this->findSpecEntry( keys => $2 );
            }
            else {
                $open = $this->createSpecEntry(
                    type    => $1,
                    options => _expandOptions( $1, $2 )
                );
            }
        }

        elsif ( $l =~ /^(#)?\s*\$(?:Foswiki::)?cfg([^=\s]*)\s*=(.*)$/ ) {

            # $Foswiki::cfg{Rice}{Brown} =
            my $optional = $1;
            my $keys     = safeKeys($2);
            unless ( $keys =~ /^$configItemRegex$/ ) {
                die "Invalid item specifier $keys at $file:$.";
            }

            # my $tentativeVal = $3; # Possibly line 1 of many
            if ( $open && $open->{type} eq 'SECTION' ) {
                $this->_addPendingEntry($open);
                $open = undef;
            }

            # If there is already an object for
            # these keys, we don't need to add another. But if there
            # isn't, we do.
            if ( !$open ) {
                $open = $this->findSpecEntry( keys => $keys );

                # Create an untyped value if the keys are not already known
                $open = $this->createSpecEntry( type => 'UNKNOWN' )
                  unless $open;
            }
            $open->{optional} = 1 if $optional;
            $open->{defined} = [ $file, 0 + $. ];
            $open->{keys} = $keys;
            $this->_addPendingEntry($open);
            $open = undef;
        }

        elsif ( $l =~ /^#\s*\*([A-Z]+)\*/ ) {

            # *FINDEXTENSIONS* etc
            my $name = $1;
            if ($open) {
                $this->_addPendingEntry($open);
            }
            $open = $this->createSpecEntry(
                type  => 'PLUGGABLE',
                title => $name
            );
        }

        elsif ( $l =~ /^#\s*---\+(\+*) *(.*?)$/ ) {

            # ---++ Section
            my ( $d, $t ) = ( $1, $2 );
            my $opts;
            $sectionNum++;
            $this->_addPendingEntry($open) if $open;
            if ( $t =~ s/^(.*?)\s*--\s*(.*?)\s*$/$1/ ) {
                $opts = $2;
            }
            $open = $this->createSpecEntry(
                type  => 'SECTION',
                title => $t,
                depth => length($d) + 1
            );
            $open->{options} = $opts if defined $opts;
        }

        elsif ( $l =~ /^#\s?(.*)$/ ) {

            # Bog standard comment
            $open->_appendDescription($1) if $open;
        }
    }
    close(F);
    $this->_addPendingEntry($open) if $open;
    $this->_mergePendingEntries();
}

sub _expandOptions {
    my ( $type, $options ) = @_;
    if ( $type eq 'SELECTCLASS' ) {
        return [ _findClasses($options) ];
    }
    return $options;
}

# $pattern is a wildcard expression that matches classes e.g.
# Foswiki::Plugins::*Plugin
# * is the only wildcard supported
# Finds all classes that match in @INC
sub _findClasses {
    my ($pattern) = @_;

    $pattern =~ s/\*/.*/g;
    my @path = split( /::/, $pattern );

    my $places = \@INC;

    while ( scalar(@path) > 1 && @$places ) {
        my $pathel = shift(@path);
        eval "\$pathel = qr/^($pathel)\$/";    # () to untaint
        my @newplaces;

        foreach my $place (@$places) {
            if ( opendir( DIR, $place ) ) {

                #next if ($place =~ /^\..*/);
                foreach my $subplace ( readdir DIR ) {
                    next unless $subplace =~ $pathel;

                    #next if ($subplace =~ /^\..*/);
                    push( @newplaces, $place . '/' . $1 );
                }
                closedir DIR;
            }
        }
        $places = \@newplaces;
    }

    my @list;
    my $leaf = shift(@path);
    eval "\$leaf = qr/$leaf\.pm\$/";
    my %known;
    foreach my $place (@$places) {
        if ( opendir( DIR, $place ) ) {
            foreach my $file ( readdir DIR ) {
                next unless $file =~ $leaf;
                next if ( $file =~ /^\..*/ );
                next unless ( $file =~ /^(.*)\.pm$/ );
                my $module = "$place/$1";
                $module =~ s./.::.g;
                if ( $module =~ /($pattern)$/ ) {
                    push( @list, $1 ) unless $known{$1};
                    $known{$1} = 1;
                }
            }
            closedir DIR;
        }
    }

    return @list;
}

# Canonicalise a key string
sub safeKeys {
    my $k = shift;
    $k =~ s/^{(.*)}$/$1/;
    return '{'
      . join( '}{',
        map { $_ =~ s/^(['"])(.*)\1$/$2/; safeKey($_) }
          split( /}{/, $k ) )
      . '}';
}

# Make a single key safe for use in a canonical key string
sub safeKey {
    my $k = shift;
    return $k if ( $k =~ /^[a-z_][a-z0-9_]*$/i );
    $k =~ s/'/\\'/g;
    return "'$k'";
}

our $next_level;    # localised in sub check(), set in sub inc()

# Set new values for the entries in the data structure passed.
# note: the spec is used to determine *where* to set values.
sub set {
    my ( $this, $data, @path ) = @_;
    my @report;
    local $next_level;

    if ( scalar(@path) ) {
        my $keypath = '{' . join( '}{', @path ) . '}';
        my $spec = $this->findSpecEntry( keys => $keypath );
        if ( $spec && defined $spec->{keys} ) {    # not a SECTION!
                # This is a specced level; we will take the entire data
                # under this point as the new value.
                # Stomp Foswiki::cfg with our new value for checking
                # and return
            eval "\$Foswiki::cfg$keypath=\$data";
            die $@ if $@;
            return;    # don't recurse any deeper
        }
    }
    if ( ref($data) eq 'HASH' ) {
        while ( my ( $sk, $se ) = each %$data ) {
            $this->set( $se, ( @path, safeKey($sk) ) );
        }
    }
}

# Check the configuration settings given in the $data against the
# checkers for the corresponding type.
our $guess_val;

sub check {
    my ( $this, $data, @path ) = @_;
    my @report;
    local $next_level;

    if ( scalar(@path) ) {
        my $keypath = '{' . join( '}{', @path ) . '}';
        my $spec = $this->findSpecEntry( keys => $keypath );
        if ($spec) {
            my $checkerClass =
              'Foswiki::Configure::Checkers::' . join( '::', @path );
            my @checkers = _findClasses($checkerClass);
            foreach my $chcl (@checkers) {

                # Load the checker
                eval "require $chcl";
                die $@ if $@;

                # Monkey-patch the checker so we know if the value
                # was guessed
                local $guess_val = undef;
                my $guess = sub {
                    $guess_val = eval "\$Foswiki::cfg$keypath";
                };
                eval "*{${chcl}::guessed}=\$guess";

                # Invoke the checker
                my $checker = $chcl->new($spec);
                my $message = $checker->check($spec);
                if ( $message || defined $guess_val ) {
                    my $whine = {
                        level => $next_level,
                        keys  => $keypath
                    };
                    $whine->{message} = $message   if $message;
                    $whine->{guess}   = $guess_val if defined $guess_val;
                    push( @report, $whine );
                }
            }
        }
    }
    if ( ref($data) eq 'HASH' ) {
        while ( my ( $sk, $se ) = each %$data ) {
            push( @report, $this->check( $se, ( @path, safeKey($sk) ) ) );
        }
    }

    return @report;
}

# Load current LSC *without* expanding embedded $Foswiki::cfg references
sub _loadRawLSC {
    my $fh;
    open(
        $fh, '<',
        Foswiki::Plugins::ConfigurePlugin::SpecEntry::findFileOnPath(
            'LocalSite.cfg')
    ) || die $@;
    local $/ = undef;
    my $c = <$fh>;
    close $fh;
    $c =~ s/^\$Foswiki::cfg/\$Foswikicfg/gm;
    my %Foswikicfg;
    eval $c;
    die $@ if $@;
    return \%Foswikicfg;
}

# Traverse LSC generating LSC format output
sub lscify {
    my ( $this, $data,, @path ) = @_;

    my @content;
    my %requires;
    if ( scalar(@path) ) {
        my $keypath = '{' . join( '}{', @path ) . '}';
        my $spec = $this->findSpecEntry( keys => $keypath );
        if ($spec) {
            if ( defined $spec->{keys} ) {

                # This is a specced level; we will take the entire data
                # under this point as the new value.
                # Stomp Foswiki::cfg with our new value for checking
                # and return
                my $type = "Foswiki::Configure::Types::$spec->{type}";
                eval "require $type";
                unless ($@) {
                    my $nval = eval "\$Foswiki::cfg$keypath";
                    die $@ if $@;
                    my ( $string, $require ) =
                      $type->new->value2string( $keypath, $nval );
                    push( @content, $string );
                    $requires{$require} = 1 if $require;
                    return ( \@content, \%requires );
                }
            }
            else {
                push( @content, "# $spec->{title}" );
            }
        }
    }
    if ( ref($data) eq 'HASH' ) {
        foreach my $sk ( sort keys %$data ) {
            my ( $c, $r ) =
              $this->lscify( $data->{$sk}, ( @path, safeKey($sk) ) );
            push( @content, @$c );
            map { $requires{$_} = 1 } keys %$r;
        }
    }
    else {

        # Something else; unspecced and not a hash.
        require Foswiki::Configure::Type;
        my $keypath = '{' . join( '}{', @path ) . '}';
        my $val = eval "\$Foswiki::cfg$keypath";
        my ( $var, $require ) =
          Foswiki::Configure::Type->new->value2string( $keypath, $val );
        $requires{$require} = 1 if $require;
        push( @content, $var );
    }
    return ( \@content, \%requires );
}

######### CRUFT TO SUPPORT CHECKERS ###############
# Done this clumsy way to avoid changing the checker code.
sub inc {
    my ( $this, $level ) = @_;
    $next_level = $level;
}

sub getKeys {
    return shift->{keys};
}

sub getCheckerOptions {
    return shift->{checkerOpts};
}

sub feedback {
    return '';
}

1;
1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2013 Foswiki Contributors. Foswiki Contributors
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
