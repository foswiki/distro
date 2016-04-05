# See bottom of file for license and copyright information

=begin TML

---+!! package Foswiki::Request::Attachment

Class to encapsulate request data for requests that ask for 
and attachment.

Fields:
   * =action= action requested (view, edit, save, ...)
   * =cookies= hashref whose keys are cookie names and values
               are CGI::Cookie objects
   * =headers= hashref whose keys are header name
   * =method= request method (GET, HEAD, POST)
   * =param= hashref of parameters, both query and body ones
   * =param_list= arrayref with parameter names in received order
   * =path_info= path_info of request (eg. /WebName/TopciName)
   * =remote_address= Client's IP address
   * =remote_user= Remote HTTP authenticated user
   * =secure= Boolean value about use of encryption
   * =server_port= Port that the webserver listens on
   * =uploads= hashref whose keys are parameter name of uploaded
               files
   * =uri= the request uri

The following fields are parsed from the path_info and/or query params
   * =web= the requested web.  Access using web method
   * =topic= the requested topic. Access using topic
   * =filename= the requested attachment filename

=cut

package Foswiki::Request::Attachment;
use strict;
use warnings;

use Foswiki::Request ();
our @ISA = ('Foswiki::Request');

use Assert;
use Error            ();
use IO::File         ();
use Foswiki::Sandbox ();

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

---++ ClassMethod new([$initializer])

Constructs a Foswiki::Request object.
   * =$initializer= - may be a filehandle or hashref.
      * If it's a filehandle, it'll be used to reload the Foswiki::Request
        object. See =save= method. Note: Restore only parameters
      * It can be a hashref whose keys are parameter names. Values may be 
        arrayref's to multivalued parameters. Same note as above.

=cut

sub new {
    my ( $proto, $initializer ) = @_;

    my $this;

    my $class = ref($proto) || $proto;

    $this = {
        action          => '',
        cookies         => {},
        headers         => {},
        method          => undef,
        param           => {},
        param_list      => [],
        path_info       => '',
        remote_address  => '',
        remote_user     => undef,
        secure          => 0,
        server_port     => undef,
        start_time      => [Time::HiRes::gettimeofday],
        uploads         => {},
        uri             => '',
        _pathParsed     => undef,
        web             => undef,
        invalidWeb      => undef,
        topic           => undef,
        invalidTopic    => undef,
        filename        => undef,
        invalidFilename => undef,
    };

    bless $this, $class;

    if ( ref($initializer) eq 'HASH' ) {
        while ( my ( $key, $value ) = each %$initializer ) {
            $this->multi_param(
                -name  => $key,
                -value => ref($value) eq 'ARRAY' ? [@$value] : [$value]
            );
        }
    }
    elsif ( ref($initializer) && UNIVERSAL::isa( $initializer, 'GLOB' ) ) {
        $this->load($initializer);
    }
    return $this;
}

=begin TML

---++ ObjectMethod web() -> $baseweb

Gets the complete Web path parsed from the query path, or the topic=
query param.  This either returns a valid parsed web path, or undef.

   * It does not filter out any illegal characters.
   * It does not set a default web.

This is read only.

=cut

sub web {
    my $this = shift;

    unless ( $this->{_pathParsed} ) {
        $this->_establishWebTopicAttachment();
    }

    print STDERR "Request->web() returns " . ( $this->{web} || 'undef' ) . "\n"
      if $Foswiki::Request::TRACE;
    return $this->{web};

}

=begin TML

---++ ObjectMethod topic() -> $basetopic

Gets the complete topic name parsed from the query path, or the topic=
queryparam.  This either returns a valid parsed topic name, or undef.

   * It does not filter out any illegal characters.
   * It does not set a default topic.

This is read only.

=cut

sub topic {
    my $this = shift;

    unless ( $this->{_pathParsed} ) {
        $this->_establishWebTopicAttachment();
    }

    print STDERR "Request->topic() returns "
      . ( $this->{topic} || 'undef' ) . "\n"
      if $Foswiki::Request::TRACE;
    return $this->{topic};

}

=begin TML

---++ ObjectMethod attachment() -> $filename

Gets the complete attachment name parsed from the query path, or the topic=
and filename= query params. This either returns a name, or undef.

   * It does not filter out any illegal characters.

This is read only.

=cut

sub attachment {
    my $this = shift;

    unless ( $this->{_pathParsed} ) {
        $this->_establishWebTopicAttachment();
    }

    print STDERR "Request->topic() returns "
      . ( $this->{topic} || 'undef' ) . "\n"
      if $Foswiki::Request::TRACE;

    return $this->{filename};

}

=begin TML

---++ ObjectMethod invalidWeb() -> "Invalid path component

Returns the bad part of the path, or the entire bad path, depending upon
the parsing process.  Returns undef when the requested web is valid.

   * It does not filter out or encode any illegal characters. Use caution when returning this string to the UI.

This is read only.

=cut

sub invalidWeb {
    my $this = shift;
    unless ( $this->{_pathParsed} ) {
        $this->_establishWebTopicAttachment();
    }

    return $this->{invalidWeb};
}

=begin TML

---++ ObjectMethod invalidTopic() -> "Invalid requested topic"

Returns the invalid topic name, when the parser is able to identify it as a topic.
Returns undef when the requested topic is valid.

   * It does not filter out or encode any illegal characters. Use caution when returning this string to the UI.

This is read only.

=cut

sub invalidTopic {
    my $this = shift;
    unless ( $this->{_pathParsed} ) {
        $this->_establishWebTopicAttachment();
    }

    return $this->{invalidTopic};
}

=begin TML

---++ private objectMethod _establishWebTopicAttachment() ->  n/a

Used internally by the web(), topic() and attachment() methods to trigger parsing of the url and/or topic= parameter
and set object variables with the results.  Attachment requests have to also accommodate redirect requests 
where a pub/Web/Topic/Attachment path is redirected to a bin/viewfile request.

=cut

sub _establishWebTopicAttachment {
    my $this = shift;

    my $pathInfo;

    if (   defined( $ENV{REDIRECT_STATUS} )
        && $ENV{REDIRECT_STATUS} != 200
        && defined( $ENV{REQUEST_URI} ) )
    {

        # this is a redirect - can be used to make 404,401 etc URL's
        # more foswiki tailored and is also used in TWikiCompatibility
        $pathInfo = $ENV{REQUEST_URI};

        # ignore parameters, as apache would.
        $pathInfo =~ s/^(.*)(\?|#).*/$1/;

        # SMELL: not store agnostic, assume the construction of pub urls
        $pathInfo =~ s|$Foswiki::cfg{PubUrlPath}||;    #remove pubUrlPath
    }
    else {

        $pathInfo = Foswiki::urlDecode( $this->path_info() );
    }

    # Extract web/topic/attachment from path.
    my $parse = Foswiki::Request::Attachment::parse($pathInfo);

    # If a topic urlparam is provided, it overrides the path.
    # Use the Request parser, since no filename is in the topic param.
    if ( $this->param('topic') ) {
        my $tparse = Foswiki::Request::parse( $this->param('topic') );
        $this->{web}          = $tparse->{web};
        $this->{topic}        = ucfirst( $tparse->{topic} );
        $this->{invalidWeb}   = $tparse->{invalidWeb};
        $this->{invalidTopic} = $tparse->{invalidTopic};
    }

    # If still no web, and we used the topic param, then try to get a web
    # from the path.
    if ( $this->param('topic') && !$this->{web} ) {
        $this->{web}        = $parse->{web};
        $this->{invalidWeb} = $parse->{invalidWeb};

    }

    # Note that Web can still be undefined.  Caller then determines if the
    # defaultweb query param, or the HomeWeb config parameter should be used.

    $this->{web} = $parse->{web} unless defined $this->{web};
    $this->{topic} = ucfirst( $parse->{topic} ) unless defined $this->{topic};
    $this->{invalidWeb} = $parse->{invalidWeb} unless defined $this->{web};
    $this->{invalidTopic} = $parse->{invalidTopic}
      unless defined $this->{topic};
    $this->{_pathParsed} = 1;

    #SMELL: validateAttachmentName still does a "filter-out" of invalid chars.
    $this->{filename} = Foswiki::Sandbox::untaint(
        $this->param('filename') || $parse->{filename},
        \&Foswiki::Sandbox::validateAttachmentName
    );

}

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
        && $Foswiki::Plugins::SESSION->webExists( join( '/', @web, $pel ) ) )
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
