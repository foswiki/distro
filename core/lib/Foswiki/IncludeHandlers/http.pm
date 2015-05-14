# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::IncludeHandlers::http

This package is designed to be lazy-loaded when Foswiki sees
an INCLUDE macro with the http: protocol. It implements a single
method INCLUDE. Also handles https:

=cut

package Foswiki::IncludeHandlers::http;

use strict;
use warnings;

use Foswiki ();

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

# Fetch content from a URL for inclusion by an INCLUDE
our $template_url;

sub INCLUDE {
    my ( $ignore, $session, $control, $options ) = @_;

    my $text = '';
    my $url  = $control->{_DEFAULT};

    # For speed, read file directly if URL matches an attachment
    # on this server.
    # SMELL: This is a DIRTY HACK that depends on the structure of
    # attachment URLs. Since the store is responsible for the generation of
    # attachment URLs, it is the only place this can really be done.
    unless ($template_url) {
        $template_url = quotemeta(
            $session->getPubURL( 'WEB', 'TOPIC', 'ATTACHMENT', absolute => 1 )
        );
        $template_url =~ s/WEB/($Foswiki::regex{webNameRegex})/;
        $template_url =~ s{TOPIC}{([^/.]+)};
        $template_url =~ s{ATTACHMENT}{([^/]+)};
    }

    if ( $url =~ m{^$template_url$} ) {
        my $incWeb   = $1;
        my $incTopic = $2;
        my $incAtt   = $3;

        # FIXME: Check for MIME type, not file suffix
        if ( $incAtt =~ m/\.(txt|html?)$/i ) {
            my $topicObject =
              Foswiki::Meta->new( $session, $incWeb, $incTopic );
            unless ( $topicObject->hasAttachment($incAtt) ) {
                return $session->_includeWarning( $control->{warn},
                    'bad_attachment', $url );
            }
            if (   $incWeb ne $control->{inWeb}
                || $incTopic ne $control->{inTopic} )
            {

                # CODE_SMELL: Does not account for not yet authenticated user
                unless ( $topicObject->haveAccess('VIEW') ) {
                    return $session->_includeWarning( $control->{warn},
                        'access_denied', "$incWeb.$incTopic" );
                }
            }
            my $fh = $topicObject->openAttachment( $incAtt, '<' );
            local $/;
            $text = <$fh>;
            $fh->close();
            unless ( $control->{raw} ) {

                # SMELL: assumes the construction of pub URLs
                my $tu = $session->getPubURL();
                $tu =~ m!^((?:[a-z]+:)?/*[^/]*)(/[^#?]*)!;
                $text = _cleanupIncludedHTML( $text, $1, $2, $options );
            }
            $text =
              Foswiki::applyPatternToIncludedText( $text, $control->{pattern} )
              if ( $control->{pattern} );
            $text = "<literal>\n" . $text . "\n</literal>"
              if ( $options->{literal} );
            return $text;
        }

        # fall through; try to include file over http based on MIME setting
    }

    return $session->_includeWarning( $control->{warn}, 'urls_not_allowed' )
      unless $Foswiki::cfg{INCLUDE}{AllowURLs};

    # SMELL: should use the URI module from CPAN to parse the URL
    # SMELL: but additional CPAN adds to code bloat
    unless ( $url =~ m!^https?:! ) {
        $text =
          $session->_includeWarning( $control->{warn}, 'bad_protocol', $url );
        return $text;
    }

    my $response = $session->net->getExternalResource($url);
    if ( !$response->is_error() ) {
        my $contentType = $response->header('content-type');
        $text = $response->content();
        if ( $contentType =~ m/^text\/html/ ) {
            if ( !$control->{raw} ) {
                $url =~ m!^([a-z]+:/*[^/]*)(/[^#?]*)!;
                $text = _cleanupIncludedHTML( $text, $1, $2, $options );
            }
        }
        elsif ( $contentType =~ m/^text\/(plain|css)/ ) {

            # do nothing
        }
        else {
            $text =
              $session->_includeWarning( $control->{warn}, 'bad_content',
                $contentType );
        }
        $text =
          Foswiki::applyPatternToIncludedText( $text, $control->{pattern} )
          if ( $control->{pattern} );
        $text = "<literal>\n" . $text . "\n</literal>"
          if ( $options->{literal} );
    }
    else {
        $text =
          $session->_includeWarning( $control->{warn}, 'geturl_failed',
            $url . ' ' . $response->message() );
    }

    return $text;
}

# Clean-up HTML text so that it can be shown embedded in a topic
sub _cleanupIncludedHTML {
    my ( $text, $host, $path, $options ) = @_;

    # FIXME: Make aware of <base> tag

    $text =~ s/^.*?<\/head>//is
      unless ( $options->{disableremoveheaders} );    # remove all HEAD
    $text =~ s/<script.*?<\/script>//gis
      unless ( $options->{disableremovescript} );     # remove all SCRIPTs
    $text =~ s/^.*?<body[^>]*>//is
      unless ( $options->{disableremovebody} );       # remove all to <BODY>
    $text =~ s/(?:\n)<\/body>.*//is
      unless ( $options->{disableremovebody} );       # remove </BODY>
    $text =~ s/(?:\n)<\/html>.*//is
      unless ( $options->{disableremoveheaders} );    # remove </HTML>
    $text =~ s/(<[^>]*>)/_removeNewlines($1)/ges
      unless ( $options->{disablecompresstags} )
      ;    # replace newlines in html tags with space
    $text =~ s/(\s(?:href|src|action)=(["']))(.*?)\2/$1 .
      _rewriteURLInInclude( $host, $path, $3 ).$2/geis

      unless ( $options->{disablerewriteurls} );

    return $text;
}

sub _removeNewlines {
    my ($theTag) = @_;
    $theTag =~ s/[\r\n]+/ /gs;
    return $theTag;
}

# Convert relative URLs to absolute URIs
sub _rewriteURLInInclude {
    my ( $theHost, $theAbsPath, $url ) = @_;

    # leave out an eventual final non-directory component from the absolute path
    $theAbsPath =~ s/(.*?)[^\/]*$/$1/;

    if ( $url =~ m/^\// ) {

        # fix absolute URL
        $url = $theHost . $url;
    }
    elsif ( $url =~ m/^\./ ) {

        # fix relative URL
        $url = $theHost . $theAbsPath . '/' . $url;
    }
    elsif ( $url =~ m/^$Foswiki::regex{linkProtocolPattern}:/ ) {

        # full qualified URL, do nothing
    }
    elsif ( $url =~ m/^#/ ) {

        # anchor. This needs to be left relative to the including topic
        # so do nothing
    }
    elsif ($url) {

        # FIXME: is this test enough to detect relative URLs?
        $url = $theHost . $theAbsPath . '/' . $url;
    }

    return $url;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
