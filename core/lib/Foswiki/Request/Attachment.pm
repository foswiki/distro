# See bottom of file for license and copyright information

=begin TML

---+!! package Foswiki::Request::Attachment

Subclass of =Foswiki::Request=. Encapsulates request data for requests that ask
for and attachment.

The following attributes are parsed from the path_info and/or query params (see
=Foswiki::Request= for base class attributes description)
   
   * =filename= the requested attachment filename

=cut

package Foswiki::Request::Attachment;

use Assert;
use IO::File         ();
use Foswiki::Sandbox ();

use Foswiki::Class;
extends qw(Foswiki::Request);

has filename => (
    is      => 'rw',
    lazy    => 1,
    default => sub {
        return $_[0]->_pathParsed->{filename};
    },
);

=begin TML

---++ ObjectMethod attachment() -> $filename

Gets the complete attachment name parsed from the query path, or the =topic=
and =filename= query params. This either returns a name, or undef.

   * It does not filter out any illegal characters.

This is read only.

=cut

sub attachment {
    my $this = shift;

    print STDERR "Request->topic() returns "
      . ( $this->topic || 'undef' ) . "\n"
      if $Foswiki::Request::TRACE;

    return $this->filename;
}

=begin TML

---++ ObjectAttribute invalidAttachment() -> "Invalid requested filename"

Returns the invalid attachment file name, when the parser is able to identify it as a filename.
Returns undef when the requested topic is valid.

   * It does not filter out or encode any illegal characters. Use caution when returning this string to the UI.

This is read only.

=cut

=begin TML

---++ private objectMethod _establishAddress() ->  n/a

Used internally by the web(), topic() and attachment() methods to trigger parsing of the url and/or topic= parameter
and set object variables with the results.  Attachment requests have to also accommodate redirect requests 
where a pub/Web/Topic/Attachment path is redirected to a bin/viewfile request.

=cut

around _establishAttributes => sub {
    my $orig = shift;
    my $this = shift;

    my $app = $this->app;
    my $env = $app->env;

    my $pathInfo;

    if (   defined( $env->{REDIRECT_STATUS} )
        && $env->{REDIRECT_STATUS} != 200
        && defined( $env->{REQUEST_URI} ) )
    {

        # this is a redirect - can be used to make 404,401 etc URL's
        # more foswiki tailored and is also used in TWikiCompatibility
        $pathInfo = $env->{REQUEST_URI};

        # ignore parameters, as apache would.
        $pathInfo =~ s/^(.*)(\?|#).*/$1/;

        # SMELL: not store agnostic, assume the construction of pub urls
        $pathInfo =~ s|$Foswiki::cfg{PubUrlPath}||;    #remove pubUrlPath
    }
    else {

        $pathInfo = Foswiki::urlDecode( $this->pathInfo );
    }

    # Extract web/topic/attachment from path.
    my $parse = parse($pathInfo);

    # If a topic urlparam is provided, it overrides the path.
    # Use the Request parser, since no filename is in the topic param.
    if ( $this->param('topic') ) {
        my $tparse = Foswiki::Request::parse( $this->param('topic') );
        foreach my $key ( keys %$tparse ) {
            next unless defined $tparse->{$key};
            $parse->{$key} = $tparse->{$key};
        }
    }

    $parse->{topic} = ucfirst( $parse->{topic} ) if defined $parse->{topic};

    #SMELL: validateAttachmentName still does a "filter-out" of invalid chars.
    $parse->{filename} = Foswiki::Sandbox::untaint(
        $this->param('filename') || $parse->{filename},
        \&Foswiki::Sandbox::validateAttachmentName
    );

    return $parse;
};

=begin TML

---++ staticMethod parse([query path]) -> { web => $web, topic => $topic, attachment => $attachment,  invalidWeb => optional, invalidTopic => optional }

Parses the rquests query_path and returns a hash of web and topic names.
If passed a query string, it will parse it and return the extracted
web / topic.

*This method cannot set the web and topic parsed from the query path.*

Slash (/) can separate webs, subwebs and topics.
Dot (.) can *only* separate a web path from a topic.
Trailing slash disambiguates a topic from a subweb when both exist with same name.

If any illegal characters are present, then web and/or topic are undefined.   The original bad
components are returned in the invalidWeb or invalidTopic entries.

webExists and topicExists may be called to disambiguate between subwebs and topics
however the returned web and topic names do not necessarily exist.

This routine returns two variables when encountering invalid input:
   * {invalidWeb}  contains original invalid web / pathinfo content when validation fails.
   * {invalidTopic} Same function but for topic name

Ths following paths are supported:
   * Main            Extracts webname, topic is undef
   * Main/Somename   Extracts webname. Somename might be a subweb if it exixsts, or a topic.
   * Main.Somename   Extracts webname and topic.
   * Main/Somename/  Forces Somename to be a web, if it also exists as a topic

=cut

sub parse {
    my $pathInfo = shift;

    my $resp = {};
    return $resp unless defined $pathInfo;

    my @path = split( /\/+/, $pathInfo );
    shift(@path) unless ( $path[0] );    # remove leading empty string

    # work out the web, topic and filename
    my @web;
    my $badweb;
    my $pel =
      Foswiki::Sandbox::untaint( $path[0],
        \&Foswiki::Sandbox::validateWebName );

    while ($pel
        && $Foswiki::app->store->webExists( join( '/', @web, $pel ) ) )
    {
        push( @web, $pel );
        shift(@path);
        $pel =
          Foswiki::Sandbox::untaint( $path[0],
            \&Foswiki::Sandbox::validateWebName );
        unless ( $pel eq $path[0] ) {
            $badweb = $path[0];
            last;
        }
    }

    # If the supplied web is invalid, don't proceed
    if ($badweb) {
        $resp->{invalidWeb} = $badweb;
        return $resp;
    }

    my $webpath = join( '/', @web );

    # If there is no web, then topic doesn't make sense either.
    my $topic;
    my $ttopic;

    if ($webpath) {

        # The next element on the path has to be the topic name
        $ttopic = shift(@path);
        $topic =
          Foswiki::Sandbox::untaint( $ttopic,
            \&Foswiki::Sandbox::validateTopicName );
    }

    # What's left in the path is the attachment name.
    my $filename = join( '/', @path );

    $resp = { web => $webpath, topic => $topic };
    $resp->{invalidTopic} = $ttopic unless defined $topic;
    $resp->{filename} = $filename;

    #print STDERR Data::Dumper::Dumper( \$resp );

    return $resp;

}

1;
__END__

Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2016 Foswiki Contributors. All Rights Reserved.
Foswiki Contributors are listed in the AUTHORS file in the root of this
distribution. NOTE: Please extend that file, not this notice.

This module is based/inspired on Catalyst framework, and also CGI,
CGI::Simple and HTTP::Headers modules. Refer to
http://search.cpan.org/~mramberg/Catalyst-Runtime-5.7010/lib/Catalyst.pm,
http://search.cpan.org/~lds/CGI.pm-3.29/CGI.pm,
http://search.cpan.org/author/ANDYA/CGI-Simple-1.103/lib/CGI/Simple.pm, and
http://search.cpan.org/~gaas/libwww-perl-5.808/lib/HTTP/Headers.pm
for full credits and license details.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
