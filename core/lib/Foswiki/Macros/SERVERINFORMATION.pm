# See bottom of file for license and copyright information
package Foswiki;

# Detailed core and plugin dependency report - see
# System.VarSERVERINFORMATION and System.FoswikiServerInformation

use strict;
use warnings;

use File::Spec;
use Foswiki::Func;
use Config;
use Foswiki::Configure::Auth;

sub SERVERINFORMATION {
    my ( $this, $params ) = @_;
    my $authorized;
    my $session = $Foswiki::Plugins::SESSION;

    Foswiki::Configure::Auth::checkAccess($session);

    my $report;
    if ( ( !defined $params->{_DEFAULT} )
        || $params->{_DEFAULT} eq 'environment' )
    {
        $report .= _report_environment();
    }

    if ( ( !defined $params->{_DEFAULT} )
        || $params->{_DEFAULT} eq 'execution' )
    {
        $report .= _report_execution();
    }

    if ( ( !defined $params->{_DEFAULT} )
        || $params->{_DEFAULT} eq 'modules' )
    {
        $report .= _report_modules();
    }

    return $report;
}

sub _report_environment {

    my $report = <<DONE;
<noautolink>
%TABLE{sort="off"}%
| *Key* | *Value* |
DONE

    my @cgivars = (

        # CGI 'Standard'
        qw/AUTH_TYPE CONTENT_LENGTH CONTENT_TYPE GATEWAY_INTERFACE/,
        qw/PATH_INFO PATH_TRANSLATED QUERY_STRING REMOTE_ADDR/,
        qw/REMOTE_HOST REMOTE_IDENT REMOTE_USER REQUEST_METHOD/,
        qw/SCRIPT_NAME SERVER_NAME SERVER_PORT SERVER_PROTOCOL/,
        qw/SERVER_SOFTWARE/,

        # Apache/common extensions
        qw/DOCUMENT_ROOT REQUEST_URI SCRIPT_FILENAME/,
        qw/SCRIPT_URI SCRIPT_URL SERVER_ADDR SERVER_ADMIN SERVER_SIGNATURE/,
        qw/UNIQUE_ID /,

        # Foswiki Extensions
        grep( /^(?:FOSWIKI)_/, keys %ENV ),

        # Perl Environment
        grep( /^(?:PERL)/, keys %ENV ),

        # System temporary dirs
        qw/TEMP TMP TMPDIR/,

        # HTTP headers & SSL data
        grep( /^(?:HTTP|SSL)_/, keys %ENV ),

        # Custom X_ headers (used in proxies, etc.)
        grep( /^X_/, keys %ENV ),

        # Other
        qw/PATH MOD_PERL MOD_PERL_API_VERSION/,
    );

    # Yes this duplicates the keys,  but it lets the code
    # report "undef" for variables which might be important.
    push @cgivars, keys %ENV;

    my $lastkey = '';
    foreach my $key ( sort @cgivars ) {

        # Don't report duplicates
        next if $key eq $lastkey;
        $lastkey = $key;

        my $value   = $ENV{$key};
        my $decoded = '';
        if ( $key eq 'HTTP_COOKIE' && $value ) {

            # url decode for readability
            #$value =~ s/%7C/ | /g;
            $value =~ s/%3D/=/g;
        }
        $value =~ s/\n/\\n/g if defined $value;
        $value = Foswiki::entityEncode($value) if defined $value;
        $report .=
          "| $key | " . ( ( defined $value ) ? $value : '_undef_' ) . " |\n";
    }

    $report .= '</noautolink>';

    return $report;
}

sub _report_execution {

    my $report = <<DONE;
<noautolink>
%TABLE{sort="off"}%
| *Area* | *Details* |
DONE

    $report .= '| @INC Library Path | ' . join( '%BR%', @INC ) . " |\n";

    # report the umask
    my $pUmask = sprintf( '%03o', umask() );
    my $override =
      ( $Foswiki::cfg{Store}{overrideUmask} )
      ? ' (Overridden by LocalSite.cfg)'
      : '';
    $report .= "| UMASK | $pUmask $override |\n";

    my $uid = getlogin() || getpwuid($>);
    my $user = 'userid: ' . ( $uid ? "*$uid*" : 'unknown' );
    $report .= "| User | $user  _Your scripts are executing as this user_ |\n";

    my @gids;
    eval {
        @gids = map { lc getgrgid($_) } split( ' ', $( );
    };
    if ($@) {
        @gids =
          ( lc( qx(sh -c '( id -un ; id -gn) 2>/dev/null' 2>nul ) || 'n/a' ) );
    }

    $report .= '| Groups | ' . join( ',', @gids ) . " |\n";

    #OS
    my $n =
        ucfirst( lc( $Config::Config{osname} ) ) . ' '
      . $Config::Config{osvers} . ' ('
      . $Config::Config{archname} . ')';
    $report .= "| Operating system | $n |\n";

    # Perl version and type
    if ( $] =~ m/^(\d+)\.(\d{3})(\d{3})$/ ) {
        $n = sprintf( "%d.%d.%d", $1, $2, $3 );
    }
    else {
        $n = $];
    }
    $n      .= " ($Config::Config{osname})";
    $report .= "| Perl version | $n |\n";
    $report .=
        "| File System | Case "
      . ( ( File::Spec->case_tolerant() ) ? 'Insensitive' : 'Sensitive' )
      . " |\n";
    $report .= "| Engine | =$Foswiki::cfg{Engine}=  |\n";
    $report .= '</noautolink>';

    return $report;
}

sub _report_modules {

    my $report = <<DONE;
<noautolink>
%TABLE{sort="off"}%
| *Module* | *Version* | *Location* |
DONE

    foreach my $mod ( sort keys %INC ) {
        next if $mod =~ /(?:Config|Foswiki).spec$/;
        my $pmod = $mod;
        $pmod =~ s/\.p[lm]$//;
        $pmod =~ s#[\//]#::#g;
        my $ver;
        eval { $ver = $pmod->VERSION() };
        $ver ||= '';
        my $incmod = $INC{$mod} || '(?)';
        $report .= "| $pmod | $ver | =$incmod= |\n";
    }
    return $report;
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2014-2015 Foswiki Contributors. Foswiki Contributors
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
