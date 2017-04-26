# Copyright (C) 2013-2017 Michael Daum http://michaeldaumconsulting.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

package Foswiki::Plugins::NatEditPlugin::RestAttachments;

use strict;
use warnings;

use Foswiki::Func ();
use Error qw( :try );
use JSON ();

sub handle {
    my ( $session, $plugin, $verb, $response ) = @_;

    my $web   = $session->{webName};
    my $topic = $session->{topicName};

    my ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );
    my @results = ();

    if (
        Foswiki::Func::checkAccessPermission(
            "VIEW", Foswiki::Func::getWikiName(),
            $text, $topic, $web, $meta
        )
      )
    {

        my @attachments = $meta->find("FILEATTACHMENT");

        my $request = $session->{request};
        my $term    = $request->param("term");

        my $context = Foswiki::Func::getContext();
        foreach
          my $attachment ( sort { $a->{name} cmp $b->{name} } @attachments )
        {
            next
              if defined($term)
              && $term ne ''
              && $attachment->{name} !~ /$term/i
              && $attachment->{comment} !~ /$term/i;

            my $record = {
                web   => $web,
                topic => $topic,
                url   => $Foswiki::cfg{PubUrlPath} . '/'
                  . $web . '/'
                  . $topic . '/'
                  . $attachment->{name},
            };

            my $extension = $attachment->{name};
            $extension =~ s/^.*\.//;
            $extension =~ s/^\s+//;
            $extension =~ s/\s+$//;

            # thumbnails
            if ( $context->{MimeIconPluginEnabled} ) {
                require Foswiki::Plugins::MimeIconPlugin;

                my $theme = $Foswiki::cfg{Plugins}{MimeIconPlugin}{Theme}
                  || 'oxygen';

                $record->{img} =
                  Foswiki::Plugins::MimeIconPlugin::getIcon( $extension,
                    $theme, 48 );
            }

            if (   $context->{ImagePluginEnabled}
                && $extension =~ /gif|jpe?g|png|svg|bmp/i )
            {
                $record->{img} = Foswiki::Func::getScriptUrlPath()
                  . "/rest/ImagePlugin/resize?topic=$web.$topic;file=$attachment->{name};size=48x48>&crop=northwest";
            }

            foreach my $key ( sort keys %{$attachment} ) {
                $record->{$key} = $attachment->{$key};
            }

            # provide properties for ui-autocomplete
            $record->{label} = $record->{name};

            push @results, $record;
        }
    }

    my $result = JSON::to_json( \@results, { pretty => 1 } );

    $response->header(
        -status => 200,
        -type   => 'text/plain',
    );
    $response->print($result);

    return "";
}

1;

