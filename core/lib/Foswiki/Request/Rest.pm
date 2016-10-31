# See bottom of file for license and copyright information

=begin TML

---+!! package Foswiki::Request::Rest

Class to encapsulate request data for REST requests.

The following fields are parsed from the path_info and/or query params
   * =
   * =web= the requested web.  Access using web method
   * =topic= the requested topic. Access using topic
   * =filename= the requested attachment filename

=cut

package Foswiki::Request::Rest;
use v5.14;

use Assert;
use IO::File         ();
use Foswiki::Sandbox ();
use Try::Tiny;
use Foswiki::Exception;

use Foswiki::Class;
extends qw(Foswiki::Request);

has subject => (
    is      => 'rw',
    lazy    => 1,
    default => sub { $_[0]->_pathParsed->{subject} },
);
has verb => (
    is      => 'rw',
    lazy    => 1,
    default => sub { $_[0]->_pathParsed->{verb} },
);
has invalidSubject => (
    is      => 'rw',
    lazy    => 1,
    default => sub { $_[0]->_pathParsed->{invalidSubject} },
);
has invalidVerb => (
    is      => 'rw',
    lazy    => 1,
    default => sub { $_[0]->_pathParsed->{invalidVerb} },
);

=begin TML

---++ private objectMethod _establishAttributes() ->  n/a

Used internally by the web(), topic() and attachment() methods to trigger parsing of the url and/or topic= parameter
and set object variables with the results.  Attachment requests have to also accommodate redirect requests 
where a pub/Web/Topic/Attachment path is redirected to a bin/viewfile request.

=cut

around _establishAttributes => sub {
    my $orig = shift;
    my $this = shift;

    # For REST requests, the topic urlparam is the only way to get
    # the web/topic.
    my $parse;
    if ( $this->param('topic') ) {

        # SMELL XXX We must use the SUPER method to parse topic as it may fetch
        # web from PATH_INFO which is incorrect for REST. Parsing has to be done
        # right here.
        $parse = $orig->( $this, $this->param('topic') );
        print STDERR Data::Dumper::Dumper( \$parse )
          if $Foswiki::Request::TRACE;
    }

    my $pathInfo = Foswiki::urlDecode( $this->pathInfo );

    # Foswiki rest invocations are defined as having a subject (pluginName)
    # and verb (restHandler in that plugin). Make sure the path_info is
    # well-structured.  Subject/verb or Subject.verb.  URL Encode anything that
    # doesn't pass validation.
    unless ( $pathInfo =~ m#/(.*?)[./]([^/]*)# ) {
        $parse->{invalidSubject} = Foswiki::urlEncode($pathInfo);
        return $parse;
    }

    my $subject = $1;
    my $verb    = $2;

    $parse->{subject} = Foswiki::Sandbox::untaint( $subject,
        \&Foswiki::Sandbox::validateTopicName );
    unless ( $parse->{subject} ) {
        $parse->{invalidSubject} = Foswiki::urlEncode($subject);
    }

    $parse->{verb} =
      Foswiki::Sandbox::untaint( $verb, \&Foswiki::Sandbox::validateTopicName );
    unless ( $parse->{verb} ) {
        $parse->{invalidVerb} = Foswiki::urlEncode($verb);
    }

    return $parse;
};

=begin TML

---++ ObjectAttribute subject ->$restSubject 

Gets the REST subject parsed from the query path.
This either returns a valid parsed topic name, or undef.

   * It does not filter out any illegal characters.
   * There is no default Subject.

This is read only.

=cut

=begin TML

---++ ObjectAttribute invalidSubject -> "Invalid path component"

Returns the bad part of the path, or the entire bad path, depending upon
the parsing process.  Returns undef when the requested web is valid.

   * It does not filter out or encode any illegal characters. Use caution when returning this string to the UI.

This is read only.

=cut

=begin TML

---++ ObjectAttribute verb ->$restVerb 

Gets the REST verb parsed from the query path.
This either returns a valid parsed topic name, or undef.

   * It does not filter out any illegal characters.
   * There is no default Subject.

This is read only.

=cut

=begin TML

---++ ObjectAttribute invalidVerb -> "Invalid path component"

Returns the bad part of the path, or the entire bad path, depending upon
the parsing process.  Returns undef when the requested web is valid.

   * It does not filter out or encode any illegal characters. Use caution when returning this string to the UI.

This is read only.

=cut

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
