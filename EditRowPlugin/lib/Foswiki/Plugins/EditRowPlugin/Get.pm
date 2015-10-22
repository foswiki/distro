# See bottom of file for copyright
package Foswiki::Plugins::EditRowPlugin::Get;

use strict;
use warnings;
use Assert;
use Error ':try';

use Foswiki       ();
use Foswiki::Func ();

use constant TRACE => 0;

# REST handler for table row edit get. Gets the raw content of a
# single table cell. URL params:
#    * erp_topic
#    * erp_table
#    * erp_row
#    * erp_col
sub process {
    my ( $session, $plugin, $verb, $response ) = @_;
    my $query = Foswiki::Func::getCgiQuery();

    unless ($query) {
        print CGI::header( -status => 500 );
        return undef;
    }

    my $active_topic = $query->param('erp_topic');
    $active_topic =~ /(.*)/;
    my ( $web, $topic ) = Foswiki::Func::normalizeWebTopicName( undef, $1 );

    my $ri = $query->param('erp_version');
    my ( $active_version, $active_date );
    if ( $ri && $ri =~ /(\d+)_(\d+)$/ ) {
        ( $active_version, $active_date ) = ( $1, $2 );
    }
    my $active_user = Foswiki::Func::getWikiName();

    my ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );
    my ( $url, $mess, $result );

    my ( $curr_date, $curr_user, $curr_rev );
    if ($active_version) {
        ( $curr_date, $curr_user, $curr_rev ) =
          Foswiki::Func::getRevisionInfo( $web, $topic );
    }

    if (
        !Foswiki::Func::checkAccessPermission(
            'VIEW', $active_user, $text, $topic, $web, $meta
        )
      )
    {
        $url = Foswiki::Func::getScriptUrl(
            $web, $topic, 'oops',
            template => 'oopsaccessdenied',
            def      => 'topic_access',
            param1   => 'VIEW',
            param2   => 'access not allowed to topic'
        );
        $result = $mess = "ACCESS DENIED";
    }
    else {
        $text =~ s/\\\n//gs;
        my @ps   = $query->multi_param();
        my $urps = {};
        foreach my $p (@ps) {
            my @vals = $query->multi_param($p);

            # We interpreted multi-value parameters as comma-separated
            # lists. This is what checkboxes, select+multi etc. use.
            $urps->{$p} = join( ',', grep { defined $_ } @vals );
        }
        require Foswiki::Plugins::EditRowPlugin::TableParser;
        ASSERT( !$@, $@ ) if DEBUG;
        my $parser = Foswiki::Plugins::EditRowPlugin::TableParser->new();
        my $content = $parser->parse( $text, $meta, $urps );

        if (TRACE) {
            require Data::Dumper;
            Foswiki::Func::writeDebug( Data::Dumper->Dump( [$urps], ['GET'] ) );
        }
      LINE:
        foreach my $table (@$content) {
            if (
                UNIVERSAL::isa( $table,
                    'Foswiki::Plugins::EditRowPlugin::Table' )
                && $table->getID() eq $urps->{erp_table}
              )
            {
                $result = $table->getCell($urps);
                $table->finish();
                last LINE;
            }
        }
    }

    # $mess will be set if there's been an error
    my $status = $mess ? 500 : 200;
    $response->header(
        -status  => $status,
        -type    => 'application/json',
        -charset => 'utf-8',

        # HTTP/1.0
        -Pragma => 'no-cache',

        # HTTP/1.1
        -Cache_Control =>
          'no-store,no-cache,must-revalidate,post-check=0,pre-check=0'
    );
    if ( !defined $result ) {
        $result = $mess || '';
    }
    $response->print( JSON->new->allow_nonref->encode($result) );

    return undef;
}

1;
__END__
Author: Crawford Currie http://c-dot.co.uk

Copyright (c) 2008-2011 Foswiki Contributors
Copyright (c) 2007 WindRiver Inc. and TWiki Contributors.
All Rights Reserved. Foswiki Contributors are listed in the
AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

Do not remove this copyright notice.

This plugin supports editing of a table row-by-row.

It uses a fairly generic table object, and employs a REST handler
for saving.
