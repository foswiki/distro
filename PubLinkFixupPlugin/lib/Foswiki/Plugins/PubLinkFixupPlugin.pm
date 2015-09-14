# See bottom of file for default license and copyright information

=begin TML

---+ package Foswiki::Plugins::PubLinkFixupPlugin

This plugin performs pub link fixup of the generated HTML page.  If Foswiki is configured with a 
non-utf-8 ={Store}{Encoding}=, then links to /pub files will be generated with the incorrect encoding.

Even on non-utf-8 sites, Foswiki operates fully with UNICODE and utf-8 encoding in the core and on 
the web interface.  /pub attachment links will be generated assuming the filesnames are utf-8 encoded.
This plugin provides a completePageHandler that finds utf-8 encoded links to /pub attachments and
re-encodes them to the {Store}{Encoding}.

This is __not__ a complete fix to the issue.  It is still strongly recommended that sites convert
their Store to utf-8 to avoid these types of encoding issues.

=cut

# change the package name!!!
package Foswiki::Plugins::PubLinkFixupPlugin;

# Always use strict to enforce variable scoping
use strict;
use warnings;

use Foswiki          ();
use Foswiki::Func    ();    # The plugins API
use Foswiki::Plugins ();    # For the API version
use Foswiki::Store   ();

our $VERSION = '1.00';
our $RELEASE = '14 Sep 2015';

# One line description of the module
our $SHORTDESCRIPTION =
  'For non-utf-8 sites, fix up Pub links to use correct encoding.';

our $NO_PREFS_IN_TOPIC = 1;

=begin TML

---++ initPlugin($topic, $web, $user) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin topic is in
     (usually the same as =$Foswiki::cfg{SystemWebName}=)

=cut

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.3 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }

    # If site is running utf-8 store, then this plugin is not needed.
    # Just undefine the completePageHandler.
    unless ( $Foswiki::cfg{Store}{Encoding}
        && $Foswiki::cfg{Store}{Encoding} ne 'utf-8' )
    {
        undef *completePageHandler;
        Foswiki::Func::writeDebug(
            'PubLinkFixupPlugin disabled - utf-8 store detected')
          if ( $Foswiki::cfg{Plugins}{PubLinkFixupPlugin}{Debug} );
    }

    # Plugin correctly initialized
    return 1;
}

=begin TML

---++ completePageHandler($html, $httpHeaders)

This handler is called on the ingredients of every page that is
output by the standard CGI scripts. It is designed primarily for use by
cache and security plugins.
   * =$html= - the body of the page (normally &lt;html>..$lt;/html>)
   * =$httpHeaders= - the HTTP headers. Note that the headers do not contain
     a =Content-length=. That will be computed and added immediately before
     the page is actually written. This is a string, which must end in \n\n.

*Since:* Foswiki::Plugins::VERSION 2.0

=cut

sub completePageHandler {

    # my( $html, $httpHeaders ) = @_;

    if (   $Foswiki::cfg{Store}{Encoding}
        && $Foswiki::cfg{Store}{Encoding} ne 'utf-8' )
    {
        $_[0] =~
s#(<(?:a|link) .*?href=(["'])(?:$Foswiki::cfg{DefaultUrlHost})?($Foswiki::cfg{PubUrlPath}/?.*?)\2.*?/?>)#_reEncodePubLink($1, $3)#ge;
        $_[0] =~
s#(<(?:audio|iframe|img|script|source|track|video) .*?src=(["'])(?:$Foswiki::cfg{DefaultUrlHost})?($Foswiki::cfg{PubUrlPath}/?.*?)\2.*?/?>)#_reEncodePubLink($1, $3)#ge;
        $_[0] =~
s#(<object .*?data=(["'])(?:$Foswiki::cfg{DefaultUrlHost})?($Foswiki::cfg{PubUrlPath}/?.*?)\2.*?/?>)#_reEncodePubLink($1, $3)#ge;
    }
}

=begin TML
---++ private _reEncodePubLink( $wholeLink, $url )

This routine is called for each pub link found in the complete page.
It takes the href/src location from the link, re-encodes it into the
{Store}{Encoding} and then replaces it back into the whole link.

=cut

sub _reEncodePubLink {
    my ( $wholeLink, $url ) = @_;

    my $origLink = $wholeLink;    # For debug printing

    # Extract just the path component, truncating any querystring
    my $qPos = index( $url, '?' );
    if ( $qPos >= 0 ) {
        $url = substr( $url, 0, $qPos );
    }

    # Decode the path back to utf-8
    my $decoded = Foswiki::urlDecode($url);

    # something didn't work right,  undo the decode and keep going
    if ( index( $decoded, chr(0xFFFD) ) > 0 ) {
        Foswiki::Func::writeDebug("Warning: Decode failed for ($decoded)")
          if ( $Foswiki::cfg{Plugins}{PubLinkFixupPlugin}{Debug} );
        $decoded = $url;
    }

    # if ascii, just return unmodified
    return $wholeLink if $decoded !~ m/[^[:ascii:]]+/;

    # Extract out the file system path for further checking
    ( my $storePath ) = $decoded =~ m/^$Foswiki::cfg{PubUrlPath}(\/.*)$/;
    return $wholeLink unless $storePath;    #Nothing to check?

    # If file exists with utf-8 encoding, do nothing
    my $tmpPath = "$Foswiki::cfg{PubDir}$storePath";
    return $wholeLink
      if ( -e Encode::encode( 'utf-8', $tmpPath, Encode::FB_WARN ) );

    # re-encode the decoded URL into the {Store}{Encoding}
    my $text = Foswiki::Store::encode($decoded);

    ($storePath) = $text =~ m/^$Foswiki::cfg{PubUrlPath}(\/.*)$/;
    return $wholeLink unless $storePath;    #Nothing to check?

    # if the file doesn't exist, then either oddball encoding, or
    # maybe a real broken link.  Just return unchanged.
    return $wholeLink unless ( -e $Foswiki::cfg{PubDir} . $storePath );

    # Entity-encode non-ASCII high character and other restricted characters.
    $text =~ s{([^0-9a-zA-Z-_.:~!*#/])}{sprintf('%%%02x',ord($1))}ge;

    # Replace the urlpath in the link.
    $wholeLink =~ s/\Q$url\E/$text/;

    if (   $origLink ne $wholeLink
        && $Foswiki::cfg{Plugins}{PubLinkFixupPlugin}{Debug} )
    {
        Foswiki::Func::writeDebug( <<DETAILS );
PubLinkFixupPlugin - 
REWRITING: $origLink
       TO: $wholeLink
DETAILS

        return $wholeLink;

    }
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2013 Foswiki Contributors. Foswiki Contributors
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
