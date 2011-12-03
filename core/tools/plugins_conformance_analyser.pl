#!/usr/bin/perl -w

# Copyright (C) 2004 C-Dot Consultants - All rights reserved
# Portions (C) 2004 Martin Cleaver

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

# Script that analyses plugins for "badness" i.e. the amount by which
# they violate the standards for working in a TWiki context. The script
# run from the root of an SVN checkout.
#
# The output is generated on STDOUT, so you should pipe to a file such
# as stats.html. Progress messages will be printed to STDERR, so you
# will still be informed of progress and be able to interact with the
# script.
#
# Usage: -debug will switch on a verbose debug trace.
# Anything else will be interpreted as a plugin name
# Report will be written to conformance_report
#
use strict;

use CGI qw( -any );

# Other constants
my $red   = "#FF9999";
my $green = "#99FF66";
my %handlers;

# Options
my $interactivePick = 1;
my $debug           = 0;

# Database of analysis results
# Top level hash fields and semantics are:
# howbad - {module|token}
# illmod - {module}{illegal token}{file} - illegal token context
# illtok - {illegal token}{module} - illegal token context
# funcsyms - {Foswiki::Func symbol} - symbols in Func
# suspect - {module}{file}{code fragment} - suspect code
# handlers - {token}{module} handler defined by module
my %data;

sub analyseConformance {
    my @modules = @_;
    unless ( scalar(@_) ) {
        opendir( DIR, "twikiplugins" )
          || die "no twikiplugins subdir under ", `pwd`;
        @modules = grep { -d "twikiplugins/$_" && !/^\./ } readdir DIR;
        closedir(DIR);
    }

    # Build list of functions in Func.pm
    my $text = `cat lib/Foswiki/Func.pm`;
    foreach my $line ( split( /\n/, $text ) ) {
        if ( $line =~ /^sub ({^_]\w+)/ ) {
            $data{funcsyms}{$1} = 1;
        }
    }

    unshift( @INC, "lib" );
    eval "use Foswiki::Plugin";
    unless ($@) {
        map { $handlers{$_} = $Foswiki::Plugin::deprecated{$_} ? 1 : 0 }
          @Foswiki::Plugin::registrableHandlers;
    }

    my $module;
    foreach $module ( sort @modules ) {
        print STDERR "Analysing $module\n";
        analyseCode( $module, \%data );
    }
    generateReport( \%data, @modules );
}

sub generateReport {
    my ( $dataRef, @modules ) = @_;

    %data = %{$dataRef};

    # print results
    print "---+ Report on the current status of packages in the Plugins web\n";
    print RED( "This report was script-generated on " . `date` . "<p>" );
    print
      "The goal of the analysis is to determine conformance to standards.\n";

    my $funcUsageReport = "";
    foreach my $key (
        sort { $data{funcsyms}{$a} <=> $data{funcsyms}{$b} }
        keys %{ $data{funcsyms} }
      )
    {
        $funcUsageReport .= TR( TD($key), TD( $data{funcsyms}{$key} - 1 ) );
    }

    if ( $funcUsageReport ne "" ) {
        print "---++ Usage of functions in Func\n";
        print TABLE( THR( "Function", "Calls" ), $funcUsageReport );
    }

    my $handlerReport = "";
    foreach my $h ( sort keys %handlers ) {
        if ( $data{handlers}{$h} ) {
            my $hn = $handlers{$h} ? RED($h) : $h;
            $handlerReport .=
              TR( TD($hn) . TD( join( ", ", @{ $data{handlers}{$h} } ) ) );
        }
    }

    if ( $handlerReport ne "" ) {
        print "\n---++ Handlers defined by modules\n";
        print "Handlers in red are deprecated\n";
        print TABLE( THR( "Handler", "Modules" ), $handlerReport );
    }

    my $illegalCallsReport = "";
    my @badtoks            = keys %{ $data{illtok} };
    @badtoks = sort { $data{howbad}{$b} <=> $data{howbad}{$a} } @badtoks;
    foreach my $token (@badtoks) {
        my @badmods = sort keys %{ $data{illtok}{$token} };
        $illegalCallsReport .= TR(
            TD("<nop>$token"),
            TD( $data{howbad}{$token} ),
            TD( join( " ", @badmods ) )
        );
    }

    if ( $illegalCallsReport ne "" ) {
        print
"\n---++ Calls to TWiki symbols not published through Foswiki::Func\n";
        print TABLE( THR( "Symbol", "Calls", "Callers" ), $illegalCallsReport );
    }

    # Table of each module, each token it calls, and what files call them
    my $badModsReport = "";
    my @badmods       = sort keys %{ $data{illmod} };
    foreach my $module (@badmods) {
        my @badtoks = keys %{ $data{illmod}{$module} };
        @badtoks = sort { $data{howbad}{$b} <=> $data{howbad}{$a} } @badtoks;
        my $tokc = scalar(@badtoks);
        foreach my $token (@badtoks) {
            my @files = sort keys %{ $data{illmod}{$module}{$token} };
            my $desc  = "";
            foreach my $file (@files) {
                $desc .=
                    "<nop>$file ("
                  . $data{illmod}{$module}{$token}{$file}
                  . ")<br />";
            }
            $badModsReport .=
              TR( TDS( $tokc, $module ), TD("<nop>$token"), TD($desc) );
            $tokc = 0;
        }
    }

    if ( $badModsReport ne "" ) {
        print "\n---++ Analysis of possibly illegal references\n";
        print TABLE( THR( "Module", "Symbol", "File (calls)" ),
            $badModsReport );
    }

    # Table of each module and each file with questionable code
    my $questionableCodeReport = "";
    foreach my $module ( sort keys %{ $data{suspect} } ) {
        my $filc = scalar( keys %{ $data{suspect}{$module} } );
        foreach my $file ( keys %{ $data{suspect}{$module} } ) {
            if ( defined( $data{suspect}{$module}{$file} ) ) {
                $questionableCodeReport .= TR(
                    TDS( $filc, $module ),
                    TD("$file"),
                    TD(
                            "\n<pre>\n"
                          . $data{suspect}{$module}{$file}
                          . "</pre>\n"
                    )
                );
                $filc = 0;
            }
        }
    }

    if ( $questionableCodeReport ne "" ) {
        print "\n---++ Other questionable code in modules\n";
        print "\nQuestionable code is code that may read or write topics ";
        print "or webs directly, or may pose a security threat.\n\n";
        print TABLE( THR( "Module", "File", "Code Fragment" ),
            $questionableCodeReport );
    }

    my $conformanceReport = "";
    my @sm = sort { $data{howbad}{$a} <=> $data{howbad}{$b} } @modules;
    my $n  = $data{howbad}{ @sm[ scalar(@sm) - 1 ] };
    my $i  = 0;
    foreach my $module (@sm) {
        my $howbad = $data{howbad}{$module} || 0;
        $conformanceReport .= TR_SHADE( $howbad, $n, TD($module), TD($howbad) );
    }

    if ( $conformanceReport ne "" ) {
        print "\n---++ Estimated module conformance\n";
        print "Conformance is degree to which module conforms with published ";
        print "interfaces. Low number *good*, high number *bad*\n";
        print TABLE( THR( "Module", "Conformance rating" ),
            $conformanceReport );
    }

    my $directivesReport = "";
    foreach my $find ( sort keys( %{ $data{directives} } ) ) {
        $directivesReport .=
          TR( TD($find),
            TD( join( ", ", sort( keys %{ $data{directives}{$find} } ) ) ) );
    }

    if ( $directivesReport ne "" ) {
        print "\n---++ Directives apparently expanded by modules\n";
        print TABLE( THR( "Directive", "Module(s)" ), $directivesReport );
    }
}

# Find occurences of TWiki functions not from Foswiki::Func in the module.
# Also analyse module for questionable code use.
sub analyseCode {
    my ( $module, $data ) = @_;
    if ( -d "twikiplugins/$module" ) {
        my $text = `cd twikiplugins/$module && find . -name '*.pm' -print`;
        if ($?) {
            warn "Prob finding $?\n";
            undef $data->{howbad}{$module};
            return;
        }
        $data->{howbad}{$module} = 0;
        my @files = split( /\n/, $text );
        foreach my $file ( grep( !/\/(test|fixtures)\//, @files ) ) {
            $file =~ s/^\.\///o;
            my $r = "twikiplugins/$module/$file";
            my @finds = split( /\n/, `grep "Foswiki::" $r` );
            my $find;
            foreach $find (@finds) {
                next if $find =~ /COMPATIBILITY/;
                $find =~ s/#.*$//;
                $find =~ s/^\s+//;
                next if $find =~ /^(use|require)/;
                next if $find =~ /^package TWiki/;
                while ( $find =~ s/\b(TWiki(::(\w+))+)[^\w:]//o ) {
                    my $token = $1;
                    if (   $token !~ /Foswiki::Func/o
                        && $token !~
                        /Foswiki::(Plugins|Contrib|Attrs|Time|Sandbox|Meta|Net)/
                        && $token !~ /Foswiki::(regex|cfg)/ )
                    {

                        # Index twice, by module and by token
                        $data->{illmod}{$module}{$token}{$file}++;
                        $data->{illtok}{$token}{$module}++;
                        $token =~ m/(\w+)$/o;
                        if ( $data->{funcsyms}{$1} ) {
                            $data->{howbad}{$module} += 5;
                            $data->{howbad}{$token}  += 5;
                        }
                        else {
                            $data->{howbad}{$module}++;
                            $data->{howbad}{$token}++;
                        }
                    }
                    elsif ( $token =~ /Foswiki::Func::(\w+)\b/o ) {
                        $token = $1;
                        if ( defined( $data->{funcsyms}{$token} ) ) {
                            $data->{funcsyms}{$token}++;
                        }
                    }
                }
            }

            # search for handler definitions
            foreach my $h ( keys %handlers ) {
                `egrep -s -e "sub[ \t]*$h" $r`;
                if ( !$? ) {
                    push( @{ $data->{handlers}{$h} }, $module );
                }
            }

            # search for probable directives %DIRECTIVE
            @finds = split( /\n/, `egrep '^.*s/%[^\/]*%' $r` );
            foreach $find (@finds) {
                if ( $find !~ /^\s*\#/o ) {
                    if ( $find =~ s/^.*s\/%(\w+)%.*$/$1/o ) {
                        $data->{directives}{$find}{$module} = 1;
                    }
                }
            }

            # search for suspect code
            my $cmd = "egrep 'opendir[ \t]*\\(*[ \t]*[A-Z][A-Z]*,' $r";
            my $grr .= `$cmd`;
            $cmd = "egrep -e '=[ \t]*<[A-Z]*>' $r";
            $grr .= `$cmd`;
            $cmd = "egrep 'open[ \t]*\\(*[ \t]*[A-Z][A-Z]*,' $r";
            $grr .= `$cmd`;
            $cmd = "egrep '`' $r";
            $grr .= `$cmd`;
            $grr =~ s/^\s*\#.*$//mgo;
            $grr =~ s/</&lt;/o;
            $grr =~ s/>/&gt;/o;
            $grr =~ s/^\s*//go;
            $grr =~ s/\n\n/\n/gos;

            if ( $grr !~ /^\s*$/os ) {
                $data->{suspect}{$module}{$file} = $grr;
                my @badlines = split( /\n/, $grr );
                $data->{howbad}{$module} += scalar(@badlines) * 3;
            }
        }
    }
    else {
        warn "Failed to find twikiplugins/$module\n";
        undef $data->{howbad}{$module};
    }
}

# Generate HTML for red text
sub RED {
    my $s = join( " ", @_ );
    return CGI::font( { color => "#DD0000" }, $s );
}

# Generate HTML for green text
sub GREEN {
    my $s = join( " ", @_ );
    return CGI::font( { color => "#00DD00" }, $s );
}

# Generate a table data
sub TD {
    return CGI::td( {}, join( "", @_ ) );
}

# Generate a table data with background
sub TD_SHADE {
    my $c = shift;
    my $s = join( "", @_ );
    return CGI::td( { bgcolor => $c }, $s );
}

# Generate a row-spanning table data. The TD is generated
# only if the row count is non-zero
sub TDS {
    my $c = shift;
    my $s = join( "", @_ );
    return "" unless ($c);
    return CGI::td( { rowspan => $c }, $s );
}

# Generate a table header cell
sub TH {
    return CGI::th( {}, join( "", @_ ) );
}

# Generate a table row
sub TR {
    my $s = join( "", @_ );
    return CGI::Tr( { valign => "top" }, $s );
}

sub THR {
    return CGI::Tr( {}, join( "", map { CGI::th($_) } @_ ) );
}

# Generate a coloured table cell.
sub TR_SHADE {
    my $i   = shift;
    my $n   = shift || 1;
    my $s   = join( "", @_ );
    my $q   = 255 * ( $n - $i ) / $n;
    my $col = uc( sprintf( "%02x", $q ) );
    return CGI::Tr( { valign => "top", bgcolor => "#FF${col}FF" }, $s );
}

# Generate a table
sub TABLE {
    my $s = join( "", @_ );
    return CGI::table( { width => "100%", border => 1 }, $s );
}

# Analyse options
my @mods;
foreach my $parm (@ARGV) {
    if ( $parm =~ /^-d/o ) {
        $debug = 1;
    }
    else {
        push( @mods, $parm );
    }
}

analyseConformance(@mods);

1;
