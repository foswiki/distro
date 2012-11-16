# -*- mode: CPerl; -*-

# See bottom of file for license and copyright information

package Foswiki::Configure::Pluggables::AUDIT;

# Audit definitions
#
# Audits are composite checks, involving multiple items and possibly
# large output.

use strict;
use warnings;

use Foswiki::Configure(qw/:DEFAULT :config :keys :util/);

use Foswiki::Configure::Pluggable;
our @ISA = (qw/Foswiki::Configure::Pluggable/);

use Foswiki::Configure::AUDIT;

# Audit categories.  Keep to a reasonable number; use multiple buttons
# rather than more headings; order by impact/cost.

# *** DO NOT add to this table.  It will be replaced with a config file shortly.
# *** This is prototype scaffolding code.

my @functions = (
    'Basic checks' => {    # E.G. re-run checks (not feedback)
        auditType => 'action',
        desc      => << "DESC",
Click the <b>Cursory checks</b> action button to re-run the checks
performed when you entered <tt>configure</tt>.  These are quick, but important checks.<br />
Click the <b>Extended checks</b> action button to run these and selected extended checks.
DESC
        items => [
            {
                type => 'NULL',
                opts =>
'NOLABEL FEEDBACK="Cursory checks" FEEDBACK="Extended checks"',
                keys        => '{ConfigParams}',
                auditGroups => [qw/PARS PARS:2 EPARS:2/],
            },
        ],
    },
    'Web server Environment' => {
        auditType => 'action',
        desc      => << "DESC",
Click the action button to analyze and display the webserver environment.
DESC

        items => [
            {
                type        => 'NULL',
                opts        => 'NOLABEL FEEDBACK="~p[/test/pathinfo]Analyze"',
                keys        => '{CGISetup}',
                auditGroups => 'CGI',
            },
            {
                type => "PATHINFO",
                opts =>
'LABEL="<span class=\\"configureItemLabel\\"><b>PathInfo</b> test results</span>"',
                keys => '{ConfigureGUI}{PATHINFO}',
                desc =>
qq{Extended path information (PATH_INFO) is used to provide arguments to CGI scripts such as configure. 
<p>Verifying that your webserver correctly delivers PATH_INFO is particularly important if you are using mod_perl, Apache or IIS, or are using a web hosting provider, as these environments are frequently misconfigured or running out-of-date software.
<p>When you click <strong>Analyze Environment</strong>, configure tests PATH_INFO by making a special request to itself with known PATH_INFO. Configure verifies that it receives the correct information from the webserver.
<p>Any error that is detected by this test will be reported above.},
            },
        ],
    },
    'Disks & Storage' => {    # Someday Store too
        auditType => 'action',
        desc      => << "DESC",
Click the action button to analyze paths and permissions<br />Note that you can perform these checks for individual items under the General path settings tab.
DESC
        items => [
            {
                type        => 'NULL',
                opts        => 'NOLABEL FEEDBACK="Analyze"',
                keys        => '{DisksAndStorage}',
                auditGroups => [qw/DIRS/],
            },
        ],
    },
    'Analysis results' => {
        auditType     => 'results',
        auditWindowId => '{ConfigureGUI}{AUDIT}{RESULTS}status',
        items         => [
            {
                type => 'AUDIT',
                opts => 'NOLABEL',
                keys => '{ConfigureGUI}{AUDIT}{RESULTS}',
            },
        ],
    },
);

sub new {
    my ($class) = @_;

    my @items;

    while ( @functions >= 2 ) {
        my ( $head, $contents ) = splice( @functions, 0, 2 );

        my $sect =
          Foswiki::Configure::AUDIT->new( $head, '' );    # Headline, options
        foreach my $key ( grep $_ ne 'items', keys %$contents ) {
            $sect->set( $key, $contents->{$key} );
        }
        push @items, $sect;

        foreach my $item ( @{ $contents->{items} } ) {
            my $value =
              Foswiki::Configure::Value->new( ( $item->{type} || 'UNKNOWN' ) );
            foreach my $key ( grep $_ ne 'type', keys %$item ) {
                $value->set( $key, $item->{$key} );
            }
            $sect->addChild($value);
        }
    }
    die "Bad function table\n" if (@functions);

    return [@items];
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
