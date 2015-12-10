# See bottom of file for license and copyright information
package Foswiki::Plugins::WysiwygPlugin::Handlers;

# This package contains the handler functions used to implement the
# WysiwygPlugin. They are implemented here so we can 'lazy-load' this
# module only when it is actually required.
use strict;
use warnings;
use Assert;
use Error (':try');

use CGI qw( :cgi );

use Foswiki::Func                              ();    # The plugins API
use Foswiki::Plugins                           ();    # For the API version
use Foswiki::Plugins::WysiwygPlugin::Constants ();

our $html2tml;
our $imgMap;
our @refs;
our %xmltagPlugin;

our $SECRET_ID =
'WYSIWYG content - do not remove this comment, and never use this identical text in your topics';

sub toSiteCharSet {
    my $string = shift;

    return $string unless defined $string;

    return $string if $Foswiki::UNICODE;

    return $string
      if ( $Foswiki::cfg{Site}{CharSet} =~ /^utf-?8/i );

    # If the site charset is not utf-8, need to convert it
    # Leave this code using Encode:: - not used on UNICODE core.
    require Encode;
    return Encode::encode(
        $Foswiki::cfg{Site}{CharSet},
        Encode::decode_utf8($string),
        Encode::FB_PERLQQ
    );
}

sub _SECRET_ID {
    $SECRET_ID;
}

sub _OWEBTAG {
    my ( $session, $params, $topic, $web ) = @_;

    my $query = Foswiki::Func::getCgiQuery();

    return $web unless $query;

    my $tt = $query->param('templatetopic');
    if ( defined($tt) ) {
        my @split =
          split( /\./, toSiteCharSet($tt) );

        if ( $#split == 0 ) {
            return $web;
        }
        else {
            return $split[0];
        }
    }

    return $web;
}

sub _OTOPICTAG {
    my ( $session, $params, $topic, $web ) = @_;

    my $query = Foswiki::Func::getCgiQuery();

    return $topic unless $query;

    my $tt = $query->param('templatetopic');
    if ( defined($tt) ) {
        my @split =
          split( /\./, toSiteCharSet($tt) );

        return $split[$#split];
    }

    return $topic;
}

# This handler is used to determine whether the topic is editable by
# a WYSIWYG editor or not. The only thing it does is to redirect to a
# normal edit url if the skin is set to WYSIWYGPLUGIN_WYSIWYGSKIN and
# nasty content is found.
sub beforeEditHandler {

    #my( $text, $topic, $web, $meta ) = @_;

    my $skin = Foswiki::Func::getPreferencesValue('WYSIWYGPLUGIN_WYSIWYGSKIN');

    if ( $skin && Foswiki::Func::getSkin() =~ /\b$skin\b/o ) {
        if ( notWysiwygEditable( $_[0] ) ) {

            # redirect
            my $query = Foswiki::Func::getCgiQuery();
            foreach my $p (qw( skin cover )) {
                my $arg = toSiteCharSet( $query->param($p) );
                if ( $arg && $arg =~ s/\b$skin\b// ) {
                    if ( $arg =~ /^[\s,]*$/ ) {
                        $query->delete($p);
                    }
                    else {
                        $query->param( -name => $p, -value => $arg );
                    }
                }
            }
            my $url = $query->url( -full => 1, -path => 1, -query => 1 );
            Foswiki::Func::redirectCgiQuery( $query, $url );

            # Bring this session to an untimely end
            exit 0;
        }
    }
}

# This handler is only invoked *after* merging is complete
sub beforeSaveHandler {

    #my( $text, $topic, $web ) = @_;
    my $query = Foswiki::Func::getCgiQuery();
    return unless $query;

    return unless defined( $query->param('wysiwyg_edit') );

    $_[0] = TranslateHTML2TML( $_[0], $_[1], $_[2] );
}

# This handler is invoked before a merge. Merges are done before the
# afterEditHandler is called, so we need to translate here.
sub beforeMergeHandler {

    #my( $text, $currRev, $currText, $origRev, $origText, $web, $topic ) = @_;
    afterEditHandler( $_[0], $_[6], $_[5] );
}

# This handler is invoked *after* a merge, and only from the edit
# script (so it's useless for a REST save)
sub afterEditHandler {
    my ( $text, $topic, $web ) = @_;
    my $query = Foswiki::Func::getCgiQuery();
    return unless $query;

    return
      unless defined( $query->param('wysiwyg_edit') )
      || $text =~ s/<!--$SECRET_ID-->//go;

    # Switch off wysiwyg_edit so it doesn't try to transform again in
    # the beforeSaveHandler
    $query->delete('wysiwyg_edit');

    $text = TranslateHTML2TML( $text, $_[1], $_[2] );

    $_[0] = $text;
}

# Invoked to convert HTML to TML
# $text is a foswiki string, i.e. octets encoded in utf8, and so is the result.
sub TranslateHTML2TML {
    my ( $text, %opts ) = @_;

    unless ($html2tml) {
        require Foswiki::Plugins::WysiwygPlugin::HTML2TML;

        $html2tml = new Foswiki::Plugins::WysiwygPlugin::HTML2TML();
    }

    # SMELL: really, really bad smell; bloody core should NOT pass text
    # with embedded meta to plugins! It is VERY BAD DESIGN!!!
    my $top = '';
    if ( $text =~ s/^(%META:[A-Z]+{.*?}%\r?\n)//s ) {
        $top = $1;
    }
    my $bottom = '';
    $text =~ s/^(%META:[A-Z]+{.*?}%\r?\n)/$bottom = "$1$bottom";''/gem;

    # Apply defaults
    $opts{convertImage} ||= \&_convertImage;
    $opts{rewriteURL}   ||= \&postConvertURL;

    # used by above callbacks
    $opts{web}   ||= $Foswiki::Plugins::SESSION->{webName};
    $opts{topic} ||= $Foswiki::Plugins::SESSION->{topicName};

    $opts{very_clean} = 1;    # aggressively polish TML
    $opts{stickybits} =
      Foswiki::Func::getPreferencesValue('WYSIWYGPLUGIN_STICKYBITS');
    $opts{ignoreattrs} =
      Foswiki::Func::getPreferencesValue('WYSIWYGPLUGIN_IGNOREATTRS');

    $text = $html2tml->convert( $text, \%opts );

    return $top . $text . $bottom;
}

# Handler used to process text in a =view= URL to generate text/html
# containing the HTML of the topic to be edited.
#
# Invoked when the selected skin is in use to convert the text to HTML
# We can't use the beforeEditHandler, because the editor loads up and then
# uses a URL to fetch the text to be edited. This handler is designed to
# provide the text for that request. It's a real struggle, because the
# commonTagsHandler is called so many times that getting the right
# call is hard, and then preventing a repeat call is harder!
sub beforeCommonTagsHandler {

    #my ( $text, $topic, $web, $meta )
    my $query = Foswiki::Func::getCgiQuery();

    # stop it from processing the template without expanded
    # %TEXT% (grr; we need a better way to tell where we
    # are in the processing pipeline)
    return if ( $_[0] =~ /^<!-- WysiwygPlugin Template/ );

    # Have to re-read the topic because verbatim blocks have already been
    # lifted out, and we need them.
    my $topic = $_[1];
    my $web   = $_[2];
    my ( $meta, $text );
    my $altText = $query->param('templatetopic');
    if ($altText) {
        $altText = toSiteCharSet($altText);
        if ( Foswiki::Func::topicExists( $web, $altText ) ) {
            ( $web, $topic ) =
              Foswiki::Func::normalizeWebTopicName( $web, $altText );
        }
    }

    $_[0] = _WYSIWYG_TEXT( $Foswiki::Plugins::SESSION, {}, $topic, $web );
}

# Handler used by editors that require pre-prepared HTML embedded in the
# edit template.
sub _WYSIWYG_TEXT {
    my ( $session, $params, $topic, $web ) = @_;

    # Have to re-read the topic because content has already been munged
    # by other plugins, or by the extraction of verbatim blocks.
    my ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );

    $text = TranslateTML2HTML( $text, web => $web, topic => $topic );

    # Lift out the text to protect it from further Foswiki rendering. It will be
    # put back in the postRenderingHandler.
    return _liftOut($text);
}

# Handler used to present the editable text in a javascript constant string
sub _JAVASCRIPT_TEXT {
    my ( $session, $params, $topic, $web ) = @_;

    my $html = _dropBack( _WYSIWYG_TEXT(@_) );

    $html =~ s/([\\'])/\\$1/sg;
    $html =~ s/\r/\\r/sg;
    $html =~ s/\n/\\n/sg;
    $html =~ s/script/scri'+'pt/g;

    return _liftOut("'$html'");
}

sub postRenderingHandler {

    # Replace protected content.
    $_[0] = _dropBack( $_[0] );
}

sub modifyHeaderHandler {
    my ( $headers, $query ) = @_;

    if ( $query->param('wysiwyg_edit') ) {
        $headers->{Expires} = 0;
        $headers->{'Cache-control'} = 'max-age=0, must-revalidate';
    }
}

# The subset of vars for which bidirection transformation is supported
# in URLs only
use vars qw( @VARS );

# The set of macros that get "special treatment" in URLs,  They have to end up
# sorted based on their expanded length.  To convert from URL to MACRO it has to
# be based upon longest match.  So _populateVars replaces this with the appropriately
# sorted array.
@VARS = (
    '%ATTACHURL%',
    '%ATTACHURLPATH%',
    '%PUBURL%',
    '%PUBURLPATH%',
    '%SCRIPTURLPATH{"view"}%',
    '%SCRIPTURLPATH{"viewfile"}%',
    '%SCRIPTURLPATH%',
    '%SCRIPTURL{"view"}%',
    '%SCRIPTURL{"viewfile"}%',
    '%SCRIPTURL%',
    '%SCRIPTSUFFIX%',    # bit dodgy, this one
);

# Initialises the mapping from var to URL and back
sub _populateVars {
    my $opts = shift;

    return if ( $opts->{exp} );

    local $Foswiki::Plugins::WysiwygPlugin::recursionBlock =
      1;                 # block calls to beforeCommonTagshandler

    my @exp = split(
        /\0/,
        Foswiki::Func::expandCommonVariables(
            join( "\0", @VARS ),
            $opts->{topic}, $opts->{web}
        )
    );

    # Item13178: The mapping between URL and vars needs to be longest match
    # so the list must be sorted by length of the value.  Also, null entries
    # should be omitted from the mapping, as they cannot be reversed.
    my %varh;
    my @exph = @exp;
    foreach my $k (@VARS) {
        my $val = shift @exph;
        $varh{$k} = $val if ( defined $val );
    }

    my @nvars;
    my @nexp;

    # Do the sort by length.
    foreach
      my $k ( sort { length( $varh{$b} ) <=> length( $varh{$a} ) } keys %varh )
    {
        next unless $varh{$k};    # Omit empty variables, can't be reversed.
        push @nvars, $k;
        push @nexp,  $varh{$k};
    }

    @VARS = @nvars;    # Replace the vars list with the length sorted list.

    # and build the list of values in order of @nvars.
    for my $i ( 0 .. $#VARS ) {
        my $nvar = $VARS[$i];
        $opts->{match}[$i] = "\Q$nvar\E";
        $nexp[$i] ||= '';    # Avoid undefined issues.
    }
    $opts->{exp} = \@nexp;

}

# callback passed to the TML2HTML convertor on each
# variable in a URL used in a square bracketed link
sub expandVarsInURL {
    my ( $url, $opts ) = @_;

    return '' unless $url;

    _populateVars($opts);
    for my $i ( 0 .. $#VARS ) {
        $url =~ s/$opts->{match}[$i]/$opts->{exp}->[$i]/g;
    }
    return $url;
}

# callback passed to the HTML2TML convertor
# See also foswiki_tiny.js in TinyMCEPlugin,  which performs similar functions.
sub postConvertURL {
    my ( $url, $opts ) = @_;

    #my $orig = $url; #debug

    local $Foswiki::Plugins::WysiwygPlugin::recursionBlock =
      1;    # block calls to beforeCommonTagshandler

    my $anchor = '';
    if ( $url =~ s/(#.*)$// ) {
        $anchor = $1;
    }
    my $parameters = '';
    if ( $url =~ s/(\?.*)$// ) {
        $parameters = $1;
    }

    _populateVars($opts);

    for my $i ( 0 .. $#VARS ) {
        next unless $opts->{exp}->[$i];

        # URLs passed here will be URL-encoded, so
        # we have to url-encode the test expression.
        my $test = quotemeta( Foswiki::urlEncode( $opts->{exp}->[$i] ) );
        $url =~ s/^$test/$VARS[$i]/g;
    }

    if ( $url =~ m#^%SCRIPTURL(?:PATH)?(?:{"view"}%|%/+view[^/]*)/+([/\w.]+)$#
        && !$parameters )
    {
        my $orig = $1;
        my ( $web, $topic ) =
          Foswiki::Func::normalizeWebTopicName( $opts->{web}, $orig );

        if ( $web && $web ne $opts->{web} ) {

            return $web . '.' . $topic . $anchor;
        }

        return $topic . $anchor;
    }

    return $url . $parameters . $anchor;
}

# Callback used to convert an IMG reference into a Foswiki variable,
# given the src= URL
sub _convertImage {
    my ( $src, $opts ) = @_;

    return unless $src;

    # block calls to beforeCommonTagshandler
    local $Foswiki::Plugins::WysiwygPlugin::recursionBlock = 1;

    # SMELL: this is not documented anywhere; is it still useful?
    unless ($imgMap) {
        $imgMap = {};
        my $imgs = Foswiki::Func::getPreferencesValue('WYSIWYGPLUGIN_ICONS');
        if ($imgs) {
            while ( $imgs =~ s/src="(.*?)" alt="(.*?)"// ) {
                my ( $src, $alt ) = ( $1, $2 );
                $src =
                  Foswiki::Func::expandCommonVariables( $src, $opts->{topic},
                    $opts->{web} );
                $alt .= '%' if $alt =~ /^%/;
                $imgMap->{$src} = $alt;
            }
        }
    }

    return $imgMap->{$src};
}

# Replace content with a marker to prevent it being munged by Foswiki
sub _liftOut {
    my ($text) = @_;
    my $n = scalar(@refs);
    push( @refs, $text );
    return "\05$n\05";
}

# Substitute marker
sub _dropBack {
    my ($text) = @_;

    # Restore everything that was lifted out
    while ( $text =~ s/\05([0-9]+)\05/$refs[$1]/gi ) {
    }
    return $text;
}

=begin TML

---++ StaticMethod addXMLTag($tag, \&fn)

Instruct WysiwygPlugin to "lift out" the named tag 
and pass it to &fn for processing.
&fn may modify the text of the tag.
&fn should return 0 if the tag is to be re-embedded immediately,
or 1 if it is to be re-embedded after all processing is complete.
The text passed (by reference) to &fn includes the 
=<tag> ... </tag>= brackets.

The simplest use of this function is something like this:
=Foswiki::Plugins::WysiwygPlugin::addXMLTag( 'mytag', sub { 1 } );=

A plugin may call this function more than once 
e.g. to change the processing function for a tag.
However, only the *original plugin* may change the processing
for a tag.

Plugins should call this function from their =initPlugin=
handlers so that WysiwygPlugin will protect the XML-like tags
for all conversions, including REST conversions.
Plugins that are intended to be used with older versions of Foswiki
(e.g. 1.0.6) should check that this function is defined before calling it,
so that they degrade gracefully if an older version of WysiwygPlugin
(e.g. that shipped with 1.0.6) is installed.

=cut

sub addXMLTag {
    my ( $tag, $fn ) = @_;

    my $plugin = caller;
    $plugin =~ s/^Foswiki::Plugins:://;

    return if not defined $tag;

    if (
        (
                not exists $Foswiki::Plugins::WysiwygPlugin::xmltag{$tag}
            and not exists $xmltagPlugin{$tag}
        )
        or ( $xmltagPlugin{$tag} eq $plugin )
      )
    {

        # This is either a plugin adding a new tag
        # or a plugin adding a tag it had previously added before.
        # A plugin is allowed to add a tag that it had added before
        # and the new function replaces the old.
        #
        $fn = sub { 1 }
          unless $fn;    # Default function

        $Foswiki::Plugins::WysiwygPlugin::xmltag{$tag} = $fn;
        $xmltagPlugin{$tag}                            = $plugin;
    }
    else {

        # DON'T replace the existing processing for this tag
        printf STDERR "WysiwygPlugin::addXMLTag: "
          . "$plugin cannot add XML tag $tag, "
          . "that tag was already registered by $xmltagPlugin{$tag}\n";
    }
}

# Invoked to convert TML to HTML
# $text is a foswiki string, i.e. octets encoded in utf8, and so is the result.
sub TranslateTML2HTML {
    my ( $text, %opts ) = @_;

    unless ($Foswiki::Plugins::WysiwygPlugin::tml2html) {
        require Foswiki::Plugins::WysiwygPlugin::TML2HTML;
        $Foswiki::Plugins::WysiwygPlugin::tml2html =
          new Foswiki::Plugins::WysiwygPlugin::TML2HTML();
    }

    # Apply defaults
    $opts{web}             ||= $Foswiki::Plugins::SESSION->{webName};
    $opts{topic}           ||= $Foswiki::Plugins::SESSION->{topicName};
    $opts{expandVarsInURL} ||= \&expandVarsInURL;
    $opts{xmltag}          ||= \%Foswiki::Plugins::WysiwygPlugin::xmltag;
    my $keepblocks =
      Foswiki::Func::getPreferencesValue('WYSIWYGPLUGIN_PROTECT_TAG_BLOCKS');
    if ( defined $keepblocks && $keepblocks ne 'NONE' ) {
        $opts{keepblocks} = [];
        foreach my $tag ( split /[,\s]+/, $keepblocks ) {
            push( @{ $opts{keepblocks} }, $tag );
        }
    }
    my $keeptags =
      Foswiki::Func::getPreferencesValue('WYSIWYGPLUGIN_PROTECT_EXISTING_TAGS');
    if ( defined $keeptags && $keeptags ne 'NONE' ) {
        $opts{keeptags} = [];
        foreach ( split( /[,\s]+/, $keeptags ) ) {
            push( @{ $opts{keeptags} }, $_ );
        }
    }
    $opts{forcenoautolink} =
      Foswiki::isTrue( Foswiki::Func::getPreferencesValue('NOAUTOLINK') );
    $opts{isKnownColour} = \&_isKnownColour;

    # SMELL: WTF is this? - CDot
    $opts{supportsparaindent} =
      Foswiki::Func::getContext()->{SUPPORTS_PARA_INDENT};
    my $disabled =
      Foswiki::Plugins::WysiwygPlugin::wysiwygEditingDisabledForThisContent(
        $_[0] );
    $opts{protectall} = $disabled ? 1 : 0;

    my $html =
      $Foswiki::Plugins::WysiwygPlugin::tml2html->convert( $_[0], \%opts );

    if ( $opts{protectall} ) {
        $html = CGI::div(
            { class => 'WYSIWYG_WARNING foswikiBroadcastMessage' },
            Foswiki::Func::renderText(
                Foswiki::Func::expandCommonVariables( <<"WARNING" ) ) )
*%MAKETEXT{"Conversion to HTML for WYSIWYG editing is disabled because of the topic content."}%*

%MAKETEXT{"This is why the conversion is disabled:"}% $disabled

%MAKETEXT{"(This message will be removed automatically)"}%
WARNING
          . CGI::div( { class => 'WYSIWYG_PROTECTED' }, $html );
    }

    return $html;
}

# Look in the Foswiki preferences to see if the named colour is
# a preference mapped to an HTML colour
sub _isKnownColour {
    my $name = shift;

    my $epr = Foswiki::Func::getPreferencesValue($name);

    # Match <font color="x" and style="color:x"
    if (
        defined $epr
        && (   $epr =~ /color=["'](#?\w+)['"]/
            || $epr =~ /color\s*:\s*(#?\w+)/
            || $epr =~ /class=["']foswiki(${name})FG['"]/i )
      )
    {
        return $1;
    }
    return undef;
}

# Text that is taken from a web page and added to the parameters of an XHR
# by JavaScript is UTF-8 encoded. This is because UTF-8 is the default encoding
# for XML, which XHR was designed to transport. For usefulness in Javascript
# the response to an XHR should also be UTF-8 encoded.
# This function generates such a response.
sub returnRESTResult {
    my ( $response, $status, $text ) = @_;

    # Foswiki 1.0 introduces the Foswiki::Response object, which handles all
    # responses.
    if ( UNIVERSAL::isa( $response, 'Foswiki::Response' ) ) {
        $response->header(
            -status  => $status,
            -type    => 'text/plain',
            -charset => 'UTF-8'
        );
        $response->print($text);
    }
    else {    # Pre-Foswiki-1.0.
              # Turn off AUTOFLUSH
              # See http://perl.apache.org/docs/2.0/user/coding/coding.html
        local $| = 0;
        my $query = Foswiki::Func::getCgiQuery();
        if ( defined($query) ) {
            my $len;
            { use bytes; $len = length($text); };
            print $query->header(
                -status         => $status,
                -type           => 'text/plain',
                -charset        => 'UTF-8',
                -Content_length => $len
            );
            print $text;
        }
    }
    print STDERR $text if ( $status >= 400 );
}

# Rest handler for use from Javascript. The 'text' parameter is used to
# pass the text for conversion. The text must be URI-encoded (this is
# to support use of this handler from XMLHttpRequest, which gets it
# wrong). Example:
#
# var req = new XMLHttpRequest();
# req.open("POST", url, true);
# req.setRequestHeader("Content-type", "application/x-www-form-urlencoded");
# var params = "text=" + encodeURIComponent(escape(text));
# request.req.setRequestHeader("Content-length", params.length);
# request.req.setRequestHeader("Connection", "close");
# request.req.onreadystatechange = ...;
# req.send(params);
#
sub REST_TML2HTML {
    my ( $session, $plugin, $verb, $response ) = @_;

    my $tml = Foswiki::Func::getCgiQuery()->param('text');
    $tml = toSiteCharSet($tml);

    return '' unless $tml;

    # if the secret ID is present, don't convert again. We are probably
    # going 'back' to this page (doesn't work on IE :-( )
    if ( $tml =~ /<!--$SECRET_ID-->/ ) {
        return $tml;
    }

    my $html = TranslateTML2HTML( toSiteCharSet($tml) );

    # Add the secret id to trigger reconversion. Doesn't work if the
    # editor eats HTML comments, so the editor may need to put it back
    # in during final cleanup.
    $html = '<!--' . $SECRET_ID . '-->' . $html;

    returnRESTResult( $response, 200, $html );

    return;    # to prevent further processing
}

# Rest handler for use from Javascript
sub REST_HTML2TML {
    my ( $session, $plugin, $verb, $response ) = @_;

    my $html = Foswiki::Func::getCgiQuery()->param('text');

    return '' unless $html;

    $html = toSiteCharSet($html);

    $html =~ s/<!--$SECRET_ID-->//go;
    unless ($html2tml) {
        require Foswiki::Plugins::WysiwygPlugin::HTML2TML;

        $html2tml = new Foswiki::Plugins::WysiwygPlugin::HTML2TML();
    }

    my $tml = $html2tml->convert(
        $html,
        {
            very_clean => 1,
            stickybits =>
              Foswiki::Func::getPreferencesValue('WYSIWYGPLUGIN_STICKYBITS'),
            ignoreattrs =>
              Foswiki::Func::getPreferencesValue('WYSIWYGPLUGIN_IGNOREATTRS'),
            convertImage => \&_convertImage,
            rewriteURL   => \&postConvertURL,
            web          => $session->{webName},      # used by callbacks
            topic        => $session->{topicName},    # used by callbacks
        }
    );

    returnRESTResult( $response, 200, $tml );

    return;    # to prevent further processing
}

sub _unquote {
    my $text = shift;
    $text =~ s/\\/\\\\/g;
    $text =~ s/\n/\\n/g;
    $text =~ s/\r/\\r/g;
    $text =~ s/\t/\\t/g;
    $text =~ s/"/\\"/g;
    $text =~ s/'/\\'/g;
    return $text;
}

# Get, and return, a list of attachments using JSON
sub REST_attachments {
    my ( $session, $plugin, $verb, $response ) = @_;
    my ( $web, $topic ) = ( $session->{webName}, $session->{topicName} );
    my ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );

    unless (
        Foswiki::Func::checkAccessPermission(
            'VIEW', Foswiki::Func::getWikiName(),
            $text, $topic, $web, $meta
        )
      )
    {
        returnRESTResult( $response, 401, "Access denied" );
        return;    # to prevent further processing
    }

    # Create a JSON list of attachment data, sorted by name
    my @atts;
    foreach my $att ( sort { $a->{name} cmp $b->{name} }
        $meta->find('FILEATTACHMENT') )
    {
        push(
            @atts,
            '{' . join(
                ',',
                map {
                        '"'
                      . _unquote($_) . '":"'
                      . _unquote( $att->{$_} ) . '"'
                } keys %$att
              )
              . '}'
        );

    }
    return '[' . join( ',', @atts ) . ']';
}

1;
__END__
Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2015 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this file:

Copyright (C) 2005 ILOG http://www.ilog.fr
and TWiki Contributors. All Rights Reserved. TWiki Contributors
are listed in the AUTHORS file in the root of your Foswiki (or TWiki)
distribution.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of the TWiki distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
