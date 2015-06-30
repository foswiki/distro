# See bottom of file for copyright
package Foswiki::Plugins::EditRowPlugin::Save;

use strict;
use warnings;
use Assert;
use Error ':try';

use Foswiki       ();
use Foswiki::Func ();

use constant TRACE => 0;

# REST handler for table row edit save with redirect on completion.
# The noredirect URL parameter can be passed to prevent
# the redirection. If it is set, the request will respond with a 500
# status code with a human readable message. This allows the handler
# to be used by Javascript table editors.
# URL params:
#    * erp_action - save command e.g "saveTableCmd"
#    * erp_topic
#    * erp_table
#    * erp_row
#    * erp_version - encoded unique version identifier; if it doesn't
#      match the latest rev of the topic, the save will be aborted.
#    * erp_stop_edit - if true, stop editing after save complete
sub process {
    my ( $session, $plugin, $verb, $response ) = @_;
    my $query = Foswiki::Func::getCgiQuery();

    unless ($query) {
        print CGI::header( -status => 500 );
        return undef;
    }

    my $ajax = $query->param('noredirect');

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

    # Find the action
    my $action;
    my $minor     = 0;    # If true, this is a quiet save
    my $no_return = 0;    # if true, we want to finish editing after the action
    my $no_save   = 0;    # if true, we are cancelling
    my $clicked = join( '', $query->multi_param('erp_action') ) || '';
    if ( $clicked =~ /^#?(quiet)?(save(Table|Row|Cell)Cmd)$/ ) {
        $action    = $2;
        $minor     = $1 ? 1 : 0;
        $no_return = 1;
    }
    elsif ( $clicked =~ /^#?((up|down|add|move|delete)RowCmd)$/ ) {
        $action = $1;
    }
    else {
        $action    = 'cancelCmd';
        $no_save   = 1;
        $no_return = 1;
    }

    Foswiki::Func::writeDebug(
        "ERP: SAVE $action, $active_topic for $active_user")
      if TRACE;

    if (
        $action ne 'cancelCmd'
        && !Foswiki::Func::checkAccessPermission(
            'CHANGE', $active_user, $text, $topic, $web, $meta
        )
      )
    {
        $url = Foswiki::Func::getScriptUrl(
            $web, $topic, 'oops',
            template => 'oopsaccessdenied',
            def      => 'topic_access',
            param1   => 'CHANGE',
            param2   => 'access not allowed to topic'
        );
        $result = $mess = "ACCESS DENIED";
    }
    elsif (
           $action ne 'cancelCmd'
        && ( !$active_user || !$curr_user || $active_user ne $curr_user )
        && (   $active_version && $curr_rev && $curr_rev ne $active_version
            || $active_date && $curr_date && $curr_date ne $active_date )
      )
    {
        $mess =
"Cannot save because it would overwrite changes made by $curr_user (revision $curr_rev).\nRefresh the view and try again.";
        $url = Foswiki::Func::getScriptUrl(
            $web, $topic, 'oops',
            template => 'oopsaccessdenied',
            def      => 'topic_access',
            param1   => 'CHANGE',
            param2   => $mess
        );
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

        #die join(' ',map { "'$_'=>'$urps->{$_}'"} keys %$urps);
        require Foswiki::Plugins::EditRowPlugin::TableParser;
        ASSERT( !$@, $@ ) if DEBUG;
        my $parser = Foswiki::Plugins::EditRowPlugin::TableParser->new();
        my $content = $parser->parse( $text, $meta, $urps );

        my $nlines = '';
        my $table  = undef;
        my $macro  = $Foswiki::cfg{Plugins}{EditRowPlugin}{Macro}
          || 'EDITTABLE';

        # Turn off editing if the erp_stop_edit flag is set in the request
        $no_return = 1 if $query->param('erp_stop_edit');

        if (TRACE) {
            require Data::Dumper;
            Foswiki::Func::writeDebug(
                Data::Dumper->Dump( [$urps], [$action] ) );
        }

      LINE:

        # Not really each line, actually each line-or-table-object
        foreach my $line (@$content) {
            if (
                UNIVERSAL::isa(
                    $line, 'Foswiki::Plugins::EditRowPlugin::Table'
                )
              )
            {
                $table = $line;
                if (   $active_topic eq $urps->{erp_topic}
                    && $urps->{erp_table} eq $table->getID() )
                {
                    Foswiki::Func::writeDebug("Performing $action") if TRACE;
                    eval { $result = $table->$action($urps); };
                    if ($@) {
                        throw Error::Simple $@ unless $ajax;
                        $mess    = $@;
                        $no_save = 1;
                        last LINE;
                    }
                }
                $line = $table->stringify();
                $table->finish();
                $nlines .= $line;
            }
            else {
                $nlines .= "$line\n";
            }
        }
        unless ($no_save) {
            Foswiki::Func::saveTopic( $web, $topic, $meta, $nlines,
                { minor => $minor } );
        }

        # $url will be set if there's been an error
        # Use a row anchor within range of the row being edited as
        # the goto target
        my $anchor = 'erp_' . $urps->{erp_table};
        if ( $urps->{erp_row} > 3 ) {
            my $before = $urps->{erp_row} - 3;
            $anchor .= "_${before}";
        }
        my @p = ( '#' => $anchor );
        unless ($no_return) {
            push( @p, erp_topic => $urps->{erp_topic} );
            push( @p, erp_table => $urps->{erp_table} );
            push( @p, erp_row   => $urps->{erp_row} );
        }
        $url = Foswiki::Func::getScriptUrl( $web, $topic, 'view', @p );
    }

    if ($ajax) {

        # $mess will be set if there's been an error
        my $status = $mess ? 500 : 200;
        $response->header(
            -status  => $status,
            -type    => 'text/html',
            -charset => 'UTF-8'
        );
        if ( defined $result ) {
            if ($result) {

                # renderText("0") clears the output, so don't do it.
                $result =
                  Foswiki::Func::expandCommonVariables( $result, $topic, $web );
                $result = Foswiki::Func::renderText( $result, $web, $topic );
                $result =~ s/<nop>//gs;
                $result =~ s/\s+/ /gs;
            }
        }
        else {
            $result = $mess || '';
        }

        # The leading text RESPONSE is required so that a single 0 value can
        # be returned - see Item10794
        $response->print("RESPONSE$result");

        # Add new validation key to HTTP header
        if ( $Foswiki::cfg{Validation}{Method} eq 'strikeone' ) {
            require Foswiki::Validation;
            my $context =
              $query->url( -full => 1, -path => 1, -query => 1 ) . time();
            my $cgis = $session->getCGISession();
            my $nonce;
            if ( Foswiki::Validation->can('generateValidationKey') ) {
                $nonce =
                  Foswiki::Validation::generateValidationKey( $cgis,
                    $context, 1 );
            }
            else {
                # Pre 2.0 compatibility
                my $html =
                  Foswiki::Validation::addValidationKey( $cgis, $context, 1 );
                $nonce = $1 if ( $html =~ /value=['"]\?(.*?)['"]/ );
            }
            $response->pushHeader( 'X-Foswiki-Validation' => $nonce )
              if defined $nonce;
        }
    }
    else {
        Foswiki::Func::redirectCgiQuery( undef, $url );
    }
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
