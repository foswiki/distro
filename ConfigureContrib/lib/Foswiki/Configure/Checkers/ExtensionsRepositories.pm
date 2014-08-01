# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::ExtensionsRepositories;

use strict;
use warnings;

require Foswiki::Configure::Checkers::URL;
our @ISA = (qw/Foswiki::Configure::Checkers::URL/);

=begin TML

---++ ObjectMethod check($valobj) -> $checkmsg

Checks the Extensions repository list.

Syntax:
  list := repospec[;repospec...]
  repospec := name=(listurl,puburl[,username,password])

See UI.pm::findRepositories.

=cut

sub check {
    my $this = shift;
    my ($valobj) = @_;

    my $keys = ref $valobj ? $valobj->{keys} : $valobj;

    my $value = $this->getItemCurrentValue($keys);

    return $this->NOTE("No repositories specified") unless ($value);

    my $e = '';
    my $n = $this->showExpandedValue($value);

    my $v = $value;
    Foswiki::Configure::Load::expandValue($v);
    $this->setItemValue( $v, $keys );

    my @list = Foswiki::Configure::UI::findRepositories();

    my $newval = '';

    my $table .= '<table class="foswikiSmall"><thead>
 <tr><td>Name<td>Data URL<td>Pub URL<td colspan="2">Authentication
<tbody>';

    my %h = ();
    my $r = 0;

    foreach my $repo (@list) {
        $r++;
        my $list = join( "\001,", $repo->{data}, $repo->{pub} );
        $this->setItemValue( $list, $keys );
        my $msg = $this->SUPER::check(
            $keys,
            {
                list     => ["\\001,"],
                parts    => [qw/scheme authority path query/],
                partsreq => [qw/scheme authority path/],
                authtype => ['hostip'],
                pass     => [1],
            },
        );
        if ($msg) {
            $e .=
              $this->ERROR( "in entry $r"
                  . ( $repo->{name} ? " ($repo->{name})" : '' )
                  . ":$msg" );
        }

        ( $repo->{data}, $repo->{pub} ) =
          split( /\001,/, $this->getItemCurrentValue($keys), 2 );

        $newval .= ';' if ($newval);

        my $txt = $repo->{name} || '';
        $h{ids}{$r} = $txt;
        $newval .= $txt . '=(';
        $table  .= "<tr><td>$txt";
        if ($txt) {
            $n .= $this->ERROR(
"Duplicated repository name: $txt at entry $r, also used for entry $h{names}{$txt}"
            ) if ( $h{names}{$txt} );
            $h{names}{$txt} = $r;
        }
        else {
            $e .= $this->ERROR("No name specified for repository entry $r");
        }

        $txt = $repo->{data} || '';
        $newval .= $txt;
        $table  .= "<td>$txt";
        if ($txt) {
            $n .= $this->WARN(
"Duplicated repository data URL: $txt at entry $r ($h{ids}{$r}), also used for entry $h{data}{$txt} ($h{ids}{$h{data}{$txt}})"
            ) if ( $h{data}{$txt} );
            $h{data}{$txt} = $r;
        }
        else {
            $e .= $this->ERROR(
                "No data URL specified for repository entry $r ($h{ids}{$r})");
        }

        $txt = $repo->{pub} || '';
        $newval .= ",$txt";
        $table  .= "<td>$txt";
        if ($txt) {
            $n .= $this->WARN(
"Duplicated repository pub URL: $txt at entry $r ($h{ids}{$r}), also used for entry $h{pub}{$txt} ($h{ids}{$h{pub}{$txt}})"
            ) if ( $h{pub}{$txt} );
            $h{pub}{$txt} = $r;
        }
        else {
            $e .= $this->ERROR(
                "No pub URL specified for repository entry $r ($h{ids}{$r})");
        }

        if ( defined $repo->{user} ) {
            $txt = $repo->{user} || '';
            $newval .= ",$txt";
            $table  .= "<td>$txt";

            $txt = $repo->{pass} || '';
            $newval .= ",$txt";
            $table  .= "<td>$txt";
        }
        else {
            $table .= '<td colspan="2"><center>None</center>';
        }

        $newval .= ')';
    }
    $table .= '</tbody></table>';

    delete $this->{UpdatedValue};

    if ( $e =~ /(?:Error|Warning):/ ) {
        $this->setItemValue( $value, $keys );
    }
    else {
        $n .= $this->NOTE(
            (
                @list > 1
                ? "Repositories <span class='foswikiSmallish'>(Each extension installs from the <b>last</b> repository listed that contains it.)</span>"
                : 'Repository'
            )
            . $table
        );
        if ( $newval eq $value ) {
            $this->setItemValue( $value, $keys );
        }
        else {
            $e .= $this->FB_VALUE( $this->setItemValue( $newval, $keys ) );
        }
    }

    return $n . $e;
}

1;

__END__

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2012 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.
