#
# Copyright (C) 2004-2012 C-Dot Consultants - All rights reserved
# Copyright (C) 2008-2010 Foswiki Contributors
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#
package Foswiki::Contrib::Build;

use strict;

my %minifiers;    # functions used to minify

my @compressFilters = (
    { RE => qr/\.js$/,  filter => '_build_js' },
    { RE => qr/\.css$/, filter => '_build_css' },
    { RE => qr/\.gz$/,  filter => '_build_gz' },
);

=begin TML

---++++ target_compress
Compress Javascript and CSS files. This target is "best efforts" - the build
won't fail if a source or target isn't missing.

=cut

sub target_compress {
    my $this = shift;
    my %file_ok;
    foreach my $filter (@compressFilters) {
      FILE:
        foreach my $file ( @{ $this->{files} } ) {
            next FILE if $file_ok{$file};

            # Find files that match the build filter and try to update
            # them
            if ( $file->{name} =~ /$filter->{RE}/ ) {
                my $fn = $filter->{filter};
                $file_ok{$file} =
                  $this->$fn( $this->{basedir} . '/' . $file->{name} );
            }
        }
    }
}

# Uses JavaScript::Minifier to optimise javascripts
# Several different name mappings are supported:
#   * XXX.uncompressed.js -> XXX.js
#   * XXX_src.js -> XXX.js
#   * XXX.uncompressed.js -> XXX.compressed.js
#
# These are selected between depending on which exist on disk.
sub _build_js {
    my ( $this, $to ) = @_;

    # First try uglify
    if ( !$minifiers{js} ) {
        if ( $this->_haveuglifyjs() ) {
            $minifiers{js} = sub {
                return $this->_uglifyjs( @_, 'js' );
            };
        }
    }

    if ( !$minifiers{js} ) {
        my $yui = $this->_haveYUI();

        if ($yui) {
            $minifiers{js} = sub {
                return $this->_yuiMinify( @_, 'js', $yui );
            };
        }
    }

    # If no good, try the CPAN minifiers
    if ( !$minifiers{js} && eval { require JavaScript::Minifier::XS; 1 } ) {
        $minifiers{js} = sub {
            return $this->_cpanMinify( @_, \&JavaScript::Minifier::XS::minify );
        };
    }
    if ( !$minifiers{js} && eval { require JavaScript::Minifier; 1 } ) {
        $minifiers{js} = sub {
            return $this->_cpanMinify(
                @_,
                sub {
                    JavaScript::Minifier::minify( input => $_[0] );
                }
            );
        };
    }
    if ( !$minifiers{js} ) {
        warn "Cannot squish $to: no minifier found\n";
        return;
    }

    return $this->_build_compress( 'js', $to );
}

# Uses CSS::Minifier to optimise CSS files
#
# Several different name mappings are supported:
#    * XXX.uncompressed.css -> XXX.css
#    * XXX_src.css -> XXX.css
#    * XXX.uncompressed.css -> XXX.compressed.css

sub _build_css {
    my ( $this, $to ) = @_;

    # First try cssmin
    if ( !$minifiers{css} ) {
        if ( $this->_havecssmin() ) {
            $minifiers{css} = sub {
                return $this->_cssmin( @_, 'css' );
            };
        }
    }

    if ( !$minifiers{css} ) {
        my $yui = $this->_haveYUI();

        if ($yui) {
            $minifiers{css} = sub {
                return $this->_yuiMinify( @_, 'css', $yui );
            };
        }
    }
    if ( !$minifiers{css} && eval { require CSS::Minifier::XS; 1 } ) {
        $minifiers{css} = sub {
            return $this->_cpanMinify( @_, \&CSS::Minifier::XS::minify );
        };
    }
    if ( !$minifiers{css} && eval { require CSS::Minifier; 1 } ) {
        $minifiers{css} = sub {
            $this->_cpanMinify(
                @_,
                sub {
                    CSS::Minifier::minify( input => $_[0] );
                }
            );
        };
    }

    return $this->_build_compress( 'css', $to );
}

sub _needsBuilding {
    my ( $from, $to ) = @_;

    if ( -e $to ) {
        my @fstat = stat($from);
        my @tstat = stat($to);
        return 0 if ( $tstat[9] >= $fstat[9] );
    }
    return 1;
}

# Guess the name mapping for .js or .css
sub _deduceCompressibleSrc {
    my ( $this, $to, $ext ) = @_;
    my $from;

    if ( $to =~ /^(.*)\.compressed\.$ext$/ ) {
        if ( -e "$1.uncompressed.$ext" ) {
            $from = "$1.uncompressed.$ext";
        }
        elsif ( -e "$1_src\.$ext" ) {
            $from = "$1_src.$ext";
        }
        else {
            $from = "$1.$ext";
        }
    }
    elsif ( $to =~ /^(.*)\.$ext$/ ) {
        if ( -e "$1.uncompressed.$ext" ) {
            $from = "$1.uncompressed.$ext";
        }
        else {
            $from = "$1_src.$ext";
        }
    }
    return $from;
}

sub _build_compress {
    my ( $this, $type, $to ) = @_;

    if ( !$minifiers{$type} ) {
        warn "Cannot squish $to: no minifier found for $type\n";
        return;
    }

    my $from = $this->_deduceCompressibleSrc( $to, $type );
    unless ( -e $from ) {

        # There may be a good reason there is no minification source;
        # for example, it might not be a derived object.
        #warn "Minification source for $to not found\n";
        return;
    }
    if ( -l $to ) {

        # BuildContrib will always override links created by pseudo-install
        unlink($to);
    }
    unless ( _needsBuilding( $from, $to ) ) {
        if ( $this->{-v} || $this->{-n} ) {
            warn "$to is up-to-date\n";
        }
        return;
    }

    if ( !$this->{-n} ) {
        &{ $minifiers{$type} }( $from, $to );
        warn "Generated $to from $from\n";
    }
    else {
        warn "Minify $from to $to\n";
    }
}

# Uses Compress::Zlib to gzip files
#
#   * xxx.yyy -> xxx.yyy.gz
#

sub _build_gz {
    my ( $this, $to ) = @_;

    unless ( eval { require Compress::Zlib } ) {
        warn "Cannot gzip: $@\n";
        return 0;
    }

    my $from = $to;
    $from =~ s/\.gz$// or return 0;
    return 0 unless -e $from && _needsBuilding( $from, $to );

    if ( -l $to ) {

        # BuildContrib will always override links created by pseudo-install
        unlink($to);
    }

    my $f;
    open( $f, '<', $from ) || die $!;
    local $/ = undef;
    my $text = <$f>;
    close($f);

    $text = Compress::Zlib::memGzip($text);

    unless ( $this->{-n} ) {
        my $f;
        open( $f, '>', $to ) || die "$to: $!";
        binmode $f;
        print $f $text;
        close($f);
        warn "Generated $to from $from\n";
    }
    return 1;
}

# helper functions for calling minifiers
sub _cpanMinify {
    my ( $this, $from, $to, $fn ) = @_;
    my $f;
    open( $f, '<', $from ) || die $!;
    local $/ = undef;
    my $text = <$f>;
    close($f);

    $text = &$fn($text);

    if ( open( $f, '<', $to ) ) {
        my $ot = <$f>;
        close($f);
        if ( $text eq $ot ) {

            #warn "$to is up to date w.r.t $from\n";
            return 1;    # no changes
        }
    }

    open( $f, '>', $to ) || die "$to: $!";
    print $f $text;
    close($f);
}

sub _yuiMinify {
    my ( $this, $from, $to, $type, $cmdtype ) = @_;
    my $lcall = $ENV{'LC_ALL'};
    my $cmd;

    if ( $cmdtype == 2 ) {
        $cmd =
"java -jar $this->{basedir}/tools/yuicompressor.jar --type $type $from";
    }
    else {
        $cmd = "yui-compressor --type $type $from";
    }
    unless ( $this->{-n} ) {
        $cmd .= " -o $to";
    }

    warn "$cmd\n";
    my $out = `$cmd`;
    $ENV{'LC_ALL'} = $lcall;
    return $out;
}

sub _cssmin {
    my ( $this, $from, $to ) = @_;
    my $lcall = $ENV{'LC_ALL'};
    my $cmd;

    $cmd = "cssmin $from";

    warn "$cmd\n";
    my $out = `$cmd`;

    unless ( $this->{-n} ) {
        if ( open( F, '>', $to ) ) {
            local $/ = undef;
            print F $out;
            close(F);
        }
        else {
            die "$to: $!";
        }
    }

    $ENV{'LC_ALL'} = $lcall;
    return $out;
}

sub _uglifyjs {
    my ( $this, $from, $to ) = @_;
    my $lcall = $ENV{'LC_ALL'};
    my $cmd;

    $cmd = "uglifyjs $from";

    unless ( $this->{-n} ) {
        $cmd .= " -o $to";
    }

    $cmd .= ' -b beautify=false,ascii-only=true';

    warn "$cmd\n";
    my $out = `$cmd`;
    $ENV{'LC_ALL'} = $lcall;
    return $out;
}

=begin TML

---++++ _haveYUI
return 1 if we have YUI as a command yui-compressor
return 2 if we have YUI as a jar file in tools

=cut

sub _haveYUI {
    my $this   = shift;
    my $info   = `yui-compressor -h 2>&1`;
    my $result = 0;

    if ( not $? ) {
        $result = 1;
    }
    elsif ( -e "$this->{basedir}/tools/yuicompressor.jar" ) {

        # Do we have java?
        $info = `java -version 2>&1` || '';
        if ( not $? ) {
            $result = 2;
        }
    }

    return $result;
}

=begin TML

---++++ _haveuglifyjs
return 1 if we have uglify as a command uglify 

=cut

sub _haveuglifyjs {
    my $this   = shift;
    my $info   = `echo ''|uglifyjs 2>&1`;
    my $result = 0;

    if ( not $? ) {
        $result = 1;
    }

    return $result;
}

=begin TML

---++++ _havecssmin
return 1 if we have cssmin as a command

=cut

sub _havecssmin {
    my $this   = shift;
    my $info   = `cssmin -h 2>&1`;
    my $result = 0;

    if ( not $? ) {
        $result = 1;
    }

    return $result;
}

1;
