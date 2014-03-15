package Foswiki::Plugins::ConfigurePlugin::SpecEntry;

# A SpecEntry represents a single entry in a .spec file - either a
# section, an individual keyed value, or a special layout marker like
# *FINDEXTENSIONS*. It also behaves as a Value object for use with
# checkers.
use strict;
use warnings;
use Data::Structure::Util;
use Assert;

our $configItemRegex = qr/(?:\{(?:'[^']+'|"[^"]+"|[-:\w]+)\})+/o;

sub new {
    my $class = shift;
    my $this = bless( {@_}, $class );
    return $this;
}

# Create a new configuration entry.
sub createSpecEntry {
    my $this = shift;
    return new Foswiki::Plugins::ConfigurePlugin::SpecEntry(@_);
}

# Get a list of all known keys in the spec
sub getAllKeys {
    my $this = shift;
    return keys %{ $this->_keyCache };
}

# Get the path down to a configuration item. The path is a list of section
# titles.
sub getSectionPath {
    my $this = shift;
    my $path;

    if ( $this->{parent} ) {
        $path = $this->{parent}->getSectionPath();
        push( @$path, $this->{parent}->{title} ) if $this->{parent}->{title};
    }
    else {
        $path = [];
    }
    return $path;
}

# For each key missing from the cfg passed, add the spec_value (unexpanded)
sub addMissingCfg {
    my ( $this, $cfg ) = @_;
    if ( $this->{type} =~ /^(SECTION|ROOT)$/ ) {
        foreach my $child ( @{ $this->{children} } ) {
            $child->addMissingCfg($cfg);
        }
    }
    elsif ( defined $this->{keys} ) {
        unless ( eval("exists \$cfg->$this->{keys}") ) {
            eval("\$cfg->$this->{keys} = \$this->{spec_value}");
        }
    }
}

# True if the given configuration item matches the given search
sub _matches {
    my ( $this, %search ) = @_;
    my $match = 1;

    while ( my ( $k, $e ) = each %search ) {
        if ( $k eq 'parent' ) {
            unless ( $this->{parent}
                && $this->{parent}->_matches(%$e) )
            {
                $match = 0;
                last;
            }
        }
        elsif ( !defined $this->{$k} || $this->{$k} ne $e ) {
            $match = 0;
            last;
        }
    }
    return $match;
}

# An empty search matches the first thing found
# If there are search terms, then the entire subtree is searched,
# but the shallowest matching node is returned
# All search terms must be matched
# Within this module we use the key_cache for simple key searches,
# for performance.
sub findSpecEntries {
    my $this   = shift;
    my %search = @_;

    my $match = $this->_matches(%search);

    # Return without searching the subtree if this node matches
    if ($match) {
        return ($this);
    }

    # Search children
    my @result = ();
    foreach my $child ( @{ $this->{children} } ) {
        push( @result, $child->findSpecEntries(@_) );
    }

    return @result;
}

# Add a child to this node, to create hierarchy.
sub addChild {
    my ( $this, $child ) = @_;
    foreach my $kid ( @{ $this->{children} } ) {
        Carp::confess if $child eq $kid;
    }
    $child->{parent} = $this;

    push( @{ $this->{children} }, $child );

}

# So the JSON module can serialise blessed objects. Causes terminal damage
# to the object by breaking parent pointers.
sub TO_JSON {
    my $d = { %{ $_[0] } };
    delete $d->{parent};
    return $d;
}

# Locate a file on the @INC path
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

# Load all spec files from core and extensions
sub loadSpecFiles {

    my @files;

    my $main_spec = findFileOnPath('Foswiki.spec');
    if ($main_spec) {
        push( @files, $main_spec );
    }

    my %read;
    foreach my $dir (@INC) {
        push( @files, _findSpecsIn( "$dir/Foswiki/Plugins", \%read ) );
        push( @files, _findSpecsIn( "$dir/Foswiki/Contrib", \%read ) );
    }

    my $cache = "$main_spec.cache";
    my $this;
    if ( -e $cache ) {
        my $up_to_date = 1;
        my $cache_time = ( stat($cache) )[9];
        foreach my $file (@files) {
            unless ( ( stat($file) )[9] < $cache_time ) {
                $up_to_date = 0;
                last;
            }
        }
        if ($up_to_date) {

            #print STDERR "Loading from cache $cache\n";
            $this = Storable::retrieve($cache);
        }
    }

    unless ($this) {

        #print STDERR "Loading from files\n";
        $this               = new Foswiki::Plugins::ConfigurePlugin::SpecEntry;
        $this->{type}       = 'ROOT';
        $this->{_key_cache} = {};

        foreach my $file (@files) {
            _parse( $this, $file );
        }

        Storable::store( $this, $cache );
    }

    _loadCurrentValues($this);

    return $this;
}

# Load all Config.spec files from the given type directory
sub _findSpecsIn {
    my ( $dir, $read ) = @_;

    return () unless opendir( D, $dir );

    my @specs;
    foreach my $extension ( grep { $_ !~ /^\./ } readdir D ) {
        next if $extension =~ /^Empty/;    # Skip Empty*
        next if $read->{$extension};
        $extension =~ /(.*)/;
        $extension = $1;                   # untaint
        my $file = "$dir/$extension/Config.spec";
        next unless -e $file;
        push( @specs, $file );
        $read->{$extension} = $file;
    }
    closedir(D);
    return @specs;
}

# Add a new entry to the queue for adding to the tree.
# Must only call on the root.
sub _addPendingEntry {
    my ( $root, $n ) = @_;
    ASSERT( defined $n, "Cannot add undef" ) if DEBUG;
    ASSERT( $root->{type} eq 'ROOT' ) if DEBUG;
    foreach my $v ( @{ $root->{_pending} } ) {

        # Don't push the same entry twice
        return if ( $v eq $n );
    }
    push( @{ $root->{_pending} }, $n );
}

sub _value2serialisable {
    my ( $type, $val ) = @_;

    if ( $type eq 'PERL' ) {

        # Collapse PERL to a string
        require Data::Dumper;
        my $d = Data::Dumper->new( [$val], ['x'] );
        $d->Sortkeys(1);
        $val = $d->Dump;
        $val =~ s/^\$x = (.*);\s*$/$1/s;
        $val =~ s/^     //gm;
    }

    # Convert regexp to string, because JsonRpcContrib falls
    # over when trying to serialise regexps
    my $result;
    if ( ref($val) eq 'Regexp' ) {
        $result = "$val";
    }
    else {
        $result = $val;
    }
    return $result;
}

# The parse is a two-pass process. First we load all configuration items
# in a flat array of pending entries, with SectionMarker objects marking
# where section headings were found. Then we process that array to find
# the section markers and create the hierarchy.
sub _parse {
    my ( $root, $file ) = @_;

    ASSERT( $root->{type} eq 'ROOT' ) if DEBUG;

    open( F, '<', $file ) || return '';
    local $/ = "\n";
    my $open       = undef;    # current setting or section
    my $value_open = 0;        # true if reading a multi-line value
    my $open_value;            # string for the value we are gathering

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

        if ( $open && $open->{keys} && $value_open ) {
            $open_value .= $l;
            my $v = eval($open_value);
            if ( !$@ && $open_value =~ /;\s*(#.*)?$/ ) {

                # Start of the line terminates the value
                $open->{spec_value} = _value2serialisable( $open->{type}, $v );
                $value_open = 0;
            }
        }

        last if ( $l =~ /^1;|^__\w+__/ );
        next if ( $l =~ /^\s*$/ || $l =~ /^\s*#!/ );

        if ( $l =~ /^#\s*\*\*\s*([A-Z]+)\s*(.*?)\s*\*\*\s*$/ ) {
            my ( $type, $opts ) = ( $1, $2 );

            # **STRING 30 EXPERT**
            $root->_addPendingEntry($open) if $open;
            if ( $type eq 'ENHANCE' ) {
                $open = $root->{_key_cache}->{$opts};
                die "$2 doesn't match a known spec" unless $open;
            }
            else {

                # SMELL: hate this, but it's hard-coded into the
                # SELECT class type so have to duplicate it here.
                my @other = ();
                if ( $type =~ /^SELECT/ ) {
                    my $size = 1;
                    my $mult = '';
                    my @choices;
                    if ( $opts =~ s/\s*!mult(?::(\d+))?\b// ) {
                        $size = ( $1 && $1 > 2 ) ? $1 : 5;
                        $mult = 'multiple ';
                    }
                    if ( $type eq 'SELECTCLASS' ) {
                        foreach my $opt ( split( /,\s*/, $opts ) ) {
                            if ( $opt eq 'none' ) {
                                unshift( @choices, 'none' );
                            }
                            else {
                                push( @choices, _findClasses($opt) );
                            }
                        }
                    }
                    else {
                        @choices = split( /,\s*/, $opts );
                    }
                    push( @other, ( choices => [@choices] ) );
                    $opts = "$mult$size";
                }
                $open = $root->createSpecEntry(
                    type    => $type,
                    options => $opts,
                    @other
                );
            }
        }

        elsif ( $l =~ /^(#)?\s*\$(?:Foswiki::)?cfg([^=\s]*)\s*=\s*(.*)$/ ) {

            # $Foswiki::cfg{Rice}{Brown} =
            my $optional = $1;
            my $keys     = Foswiki::Plugins::ConfigurePlugin::safeKeys($2);
            my $spec_val = $3;
            unless ( $keys =~ /^$configItemRegex$/ ) {
                die "Invalid item specifier $keys at $file:$.";
            }

            if ( $open
                && ( $open->{type} eq 'SECTION' || $open->{type} eq 'ROOT' ) )
            {
                $root->_addPendingEntry($open);
                $open = undef;
            }

            # If there is already an object for
            # these keys, we don't need to add another. But if there
            # isn't, we do.
            if ( !$open ) {
                $open = $root->{_key_cache}->{$keys};

                # Create an untyped value if the keys are not already known
                $open = $root->createSpecEntry( type => 'UNKNOWN' )
                  unless $open;
                $root->{_key_cache}->{$keys} = $open;
            }
            $open->{keys}     = $keys;
            $open->{optional} = 1 if $optional;
            $open->{defined}  = [ $file, 0 + $. ];    # debugging
            if ( defined $spec_val ) {
                my $v = eval($spec_val);
                if ( !$@ && $spec_val =~ /;\s*(#.*)?$/ ) {
                    $open->{spec_value} =
                      _value2serialisable( $open->{type}, $v );
                }
                else {
                    $value_open = 1;
                    $open_value = $spec_val;
                }
            }

            $root->_addPendingEntry($open);
            $open = undef;
        }

        elsif ( $l =~ /^#\s*\*([A-Z]+)\*/ ) {

            # *FINDEXTENSIONS*, *PLUGINS* etc are known as "PluggableSections"
            if ($open) {
                $root->_addPendingEntry($open);
            }
            my $name = $1;
            if ($open) {
                $root->_addPendingEntry($open);
            }
            my @entries = _loadPluggableSection( $name, $root );
            foreach my $e (@entries) {
                $root->_addPendingEntry($e);
            }
            $open = undef;
        }

        elsif ( $l =~ /^#\s*---\+(\+*) *(.*?)$/ ) {

            # ---++ Section
            my ( $d, $t ) = ( $1, $2 );
            my $opts;
            $sectionNum++;
            $root->_addPendingEntry($open) if $open;
            if ( $t =~ s/^(.*?)\s*--\s*(.*?)\s*$/$1/ ) {
                $opts = $2;
            }
            $open = $root->createSpecEntry(
                type  => 'SECTION',
                title => $t,
                depth => length($d) + 1
            );
            $open->{options} = $opts if defined $opts;
        }

        elsif ( $l =~ /^#\s?(.*)$/ && $open ) {

            # Bog standard comment
            if ( $open->{description} ) {
                $open->{description} .= " $1";
            }
            else {
                $open->{description} = $1;
            }
        }
    }
    close(F);
    $root->_addPendingEntry($open) if $open;

    # Convert the flat pending entries into a tree
    $root->_mergePendingEntries();
}

# Merge the pending entries into the tree, creating the section
# hierarchy as we go.
sub _mergePendingEntries {
    my $root = shift;

    ASSERT( $root->{type} eq 'ROOT' ) if DEBUG;

    my $section = $root;
    my $depth   = 0;

    foreach my $item ( @{ $root->{_pending} } ) {
        if ( $item->{type} && $item->{type} eq 'SECTION' ) {
            my @ns = $root->findSpecEntries(
                title => $item->{title},
                depth => $item->{depth}
            );
            if ( scalar(@ns) ) {

                die "Multiple $item->{title} sections at depth $item->{depth}"
                  if scalar(@ns) > 1;

                # the section is already there
                $depth   = $item->{depth};
                $section = $ns[0];
            }
            else {
                while ( $depth > $item->{depth} - 1 ) {
                    $section = $section->{parent} if $section->{parent};
                    $depth--;
                }
                while ( $depth < $item->{depth} - 1 ) {
                    my $ns = $root->createSpecEntry(
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

            #my @vo = $root->findSpecEntries( keys => $item->{keys} );
            #next if scalar(@vo);
            next if $root->{_key_cache}->{ $item->{keys} };

            # SMELL: warning?
            $root->{_key_cache}->{ $item->{keys} } = $item;
        }

        $section->addChild($item);
    }
    delete $root->{_pending};
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

# Load up all the keys entries with the current values from Foswiki::cfg
sub _loadCurrentValues {
    my $root = shift;

    while ( my ( $keys, $spec ) = each %{ $root->{_key_cache} } ) {

        # Pull in the current value from $Foswiki::cfg
        my $val = eval "\$Foswiki::cfg$keys";    # unexpanded value
        $spec->{current_value} = _value2serialisable( $spec->{type}, $val );
    }
}

our %level_counts;    # localised in sub check(), set in sub inc()

# Check the configuration settings given in the $data against the
# checkers for the corresponding type.
our $guess_val;

# A report always is generated for every key listed in $data. A report
# has fields:
#    =keys= - the key path
#    =level= - 'information', 'warnings' or 'errors'
#    =message= - the message string (may be null)
# Non-information reports may also have =sections=. This is an array of section
# titles leading from the root down to the key. It is used to locate the report
# in the user interface.
# Guessed fields may also have a =guess=.
sub check {
    my ( $this, $data ) = @_;
    my @report;

    my %prio = ( information => 1, warnings => 2, errors => 3 );

    foreach my $keypath ( keys %$data ) {
        my $reported = 0;

        my $spec = $this->_keyCache->{$keypath};
        unless ($spec) {
            my @spec = $this->findSpecEntries( keys => $keypath );
            $spec = $spec[0];
            die "ASSERT FAILURE $keypath" if $spec;
        }
        die "$keypath has no spec" unless $spec;
        my $path = join(
            '::',

            # Simple rewriting rules to perlify checker paths
            map {
                s/^['"](.*)['"]$/$1/;
                s/::/_/g;
                s/([^\w])/sprintf('%x', ord($1))/ge;
                $_
              }
              grep { defined $_ && !/^$/ }
              split( /[}{]/, $keypath )
        );
        my $chcl = 'Foswiki::Configure::Checkers::' . $path;

        # Don't reload the checker if it's already known
        unless ( eval "defined &${chcl}::check" ) {

            # Load the checker
            eval "require $chcl";
            if ($@) {

                # The assert will fail if the checker didn't compile
                ASSERT( $@ =~ /^Can't locate/, "$chcl:" . $@ ) if DEBUG;
                $chcl = undef;
            }
        }
        if ($chcl) {

            # Monkey-patch the checker so we know if the value
            # was guessed
            local $guess_val = undef;
            my $guess = sub {
                $guess_val = eval "\$Foswiki::cfg$keypath";
            };
            eval "*{${chcl}::guessed}=\$guess";

            # Invoke the checker
            my $checker = $chcl->new($spec);
            local %level_counts = ();
            my $message = $checker->check($spec);
            if ( $message || defined $guess_val ) {
                my $worst = 'information';
                foreach my $level ( keys %prio ) {
                    if (   $level_counts{$level}
                        && $prio{$level} > $prio{$worst} )
                    {
                        $worst = $level;
                    }
                }

                # Upgrade to a warning if the field value was guessed
                $worst = 'warnings'
                  if $worst eq 'information' && defined $guess_val;
                my $whine = {
                    level   => $worst,
                    keys    => $keypath,
                    message => $message ? $message : ''
                };
                $whine->{sections} = $spec->getSectionPath()
                  if ( $worst ne 'information' );
                $whine->{guess} = $guess_val if defined $guess_val;
                push( @report, $whine );
                $reported = 1;
            }

            # Certain keys can be used to pass a value to some
            # audit checkers e.g. CGI::Setup
            if ( $checker->can('provideFeedback') ) {
                $message =
                  $checker->provideFeedback( $spec, 1, $data->{$keypath} );
                if ($message) {
                    my $whine = {
                        level   => 'information',
                        keys    => $keypath,
                        message => $message
                    };
                    push( @report, $whine );
                    $reported = 1;
                }
            }
        }
        unless ($reported) {
            my $whine = {
                level   => 'information',
                keys    => $keypath,
                message => ''
            };
            push( @report, $whine );
        }
    }
    return @report;
}

######### CRUFT TO SUPPORT CHECKERS ###############
# Done this clumsy way to avoid changing the checker code.
sub inc {
    my ( $this, $level ) = @_;
    $level_counts{$level}++;
}

sub getKeys {
    return shift->{keys};
}

sub _keyCache {
    my $this = shift;
    return $this->{parent}->_keyCache if ( $this->{parent} );
    ASSERT( $this->{_key_cache} ) if DEBUG;
    return $this->{_key_cache};
}

sub getCheckerOptions {
    return shift->{checkerOpts};
}

sub feedback {
    return '';
}

sub _loadPluggableSection {
    my ( $name, $section ) = @_;
    my $modelName = 'Foswiki::Plugins::ConfigurePlugin::' . $name;
    eval "require $modelName";
    Carp::confess $@ if $@;

    my $load = $modelName . '::load';
    no strict 'refs';
    my @entries = &$load($section);
    use strict 'refs';
    return @entries;
}

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
