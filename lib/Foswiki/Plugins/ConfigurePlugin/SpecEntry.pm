package Foswiki::Plugins::ConfigurePlugin::SpecEntry;

# A SpecEntry represents a single entry in a .spec file - either a
# section, an individual keyed value, or a special layout marker like
# *FINDEXTENSIONS*. It also behaves as a Value object for use with
# checkers.
use strict;
use warnings;
use Data::Structure::Util;

our $configItemRegex = qr/(?:\{(?:'[^']+'|"[^"]+"|[-:\w]+)\})+/o;

my %key_cache = ();

sub new {
    my $class = shift;
    my $this = bless( {@_}, $class );
    return $this;
}

sub createSpecEntry {
    my $this = shift;
    return new Foswiki::Plugins::ConfigurePlugin::SpecEntry(@_);
}

# Get a list of all known keys in the spec
sub getAllKeys {
    return keys %key_cache;
}

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

#print STDERR "$this->{type}:".($this->{keys}||$this->{title}||'?')." D".($this->{depth}||'?')." matches\n";
        return ($this);
    }

    my @result = ();

    # Search pending (used during loading)
    #if ( $this->{_pending} ) {
    #    foreach my $child ( @{ $this->{_pending} } ) {
    #        push(@result, $child->findSpecEntries(@_));
    #    }
    #}

    # Search children
    foreach my $child ( @{ $this->{children} } ) {
        push( @result, $child->findSpecEntries(@_) );
    }

    return @result;
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

    %key_cache = ();
    $this->{type} = 'ROOT';

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
            my @ns = $this->findSpecEntries(
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

            #my @vo = $this->findSpecEntries( keys => $item->{keys} );
            #next if scalar(@vo);
            next if $key_cache{ $item->{keys} };

            # SMELL: warning?
            $key_cache{ $item->{keys} } = $item;
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
          #my @open = $this->findSpecEntries( keys => $2 );
          #die "$2 doesn't match a single known spec" unless scalar(@open) == 1;
          #$open = $open[0];
                $open = $key_cache{$2};
                die "$2 doesn't match a known spec" unless $open;
            }
            else {
                my ( $type, $opts ) = ( $1, $2 );

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
                $open = $this->createSpecEntry(
                    type    => $type,
                    options => $opts,
                    @other
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
            if ( $open
                && ( $open->{type} eq 'SECTION' || $open->{type} eq 'ROOT' ) )
            {
                $this->_addPendingEntry($open);
                $open = undef;
            }

            # If there is already an object for
            # these keys, we don't need to add another. But if there
            # isn't, we do.
            if ( !$open ) {

                #my @o = $this->findSpecEntries( keys => $keys );
                #die "$keys matches multiple specs" if scalar(@o) > 1;
                #$open = $o[0] if scalar(@o);
                $open = $key_cache{$keys};

                # Create an untyped value if the keys are not already known
                $open = $this->createSpecEntry( type => 'UNKNOWN' )
                  unless $open;
                $key_cache{$keys} = $open;
            }
            $open->{optional} = 1 if $optional;
            $open->{defined} = [ $file, 0 + $. ];    # debugging
            $open->{keys} = $keys;
            my $val = eval "\$Foswiki::cfg$keys";    # unexpanded value
            if ( $open->{type} eq 'PERL' ) {

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
            if ( ref($val) eq 'Regexp' ) {
                $open->{value} = "$val";
            }
            else {
                $open->{value} = $val;
            }
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

our %level_counts;    # localised in sub check(), set in sub inc()

# Check the configuration settings given in the $data against the
# checkers for the corresponding type.
our $guess_val;

# A report always is generated for every key listed in $data. A report has fields:
# =keys= - the key path
# =level= - 'information', 'warnings' or 'errors'
# =message= - the message string (may be null)
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

        #my @spec = $this->findSpecEntries( keys => $keypath );
        #die "$keypath has no, or multiple, specs" unless scalar(@spec) == 1;
        #my $spec = $spec[0];
        my $spec = $key_cache{$keypath};
        unless ($spec) {
            my @spec = $this->findSpecEntries( keys => $keypath );
            $spec = $spec[0];
            die "ASSERT FAILURE $keypath" if $spec;
        }
        die "$keypath has no spec" unless $spec;
        my $path = join(
            '::', grep { defined $_ && !/^$/ }
              split( /[}{]/, $keypath )
        );
        my $checkerClass = 'Foswiki::Configure::Checkers::' . $path;
        my @checkers     = _findClasses($checkerClass);
        foreach my $chcl (@checkers) {

            # Load the checker
            eval "require $chcl";
            if ($@) {
                print STDERR $@;
                next;
            }

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
                  $checker->provideFeedback( $spec, $data->{$keypath} );
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
    my ( $this, $data, @path ) = @_;

    my @content;
    if ( scalar(@path) ) {
        my $keypath = '{' . join( '}{', @path ) . '}';

        #my @ss = $this->findSpecEntries( keys => $keypath );
        #die "Problem at $keypath" if scalar(@ss) > 1;
        #my $spec = $ss[0];
        my $spec = ( $key_cache{$keypath} );
        if ( $spec && defined $spec->{keys} ) {

            # This is a specced level; we will take the entire data
            # under this point as the new value.
            # Stomp Foswiki::cfg with our new value for checking
            # and return
            unless ($@) {
                my $nval = eval "\$Foswiki::cfg$keypath";
                die $@ if $@;
                my $string = _value2string( $keypath, $nval );
                push( @content, $string );
                return \@content;
            }
        }
        elsif ( $spec->{title} ) {
            push( @content, "# $spec->{title}" );
        }
    }
    if ( ref($data) eq 'HASH' ) {
        foreach my $sk ( sort keys %$data ) {
            my $c = $this->lscify( $data->{$sk}, ( @path, safeKey($sk) ) );
            push( @content, @$c );
        }
    }
    else {

        # Something else; unspecced and not a hash.
        my $keypath = '{' . join( '}{', @path ) . '}';
        my $val     = eval "\$Foswiki::cfg$keypath";
        my $var     = _value2string( $keypath, $val );
        push( @content, $var );
    }
    return \@content;
}

# Used to generate appropriate lines values for storing in LocalSite.cfg.
sub _value2string {
    my ( $kp, $val ) = @_;
    return Data::Dumper->Dump( [$val], ["\$Foswiki::cfg$kp"] );
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

sub getCheckerOptions {
    return shift->{checkerOpts};
}

sub feedback {
    return '';
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
