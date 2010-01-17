# See bottom of file for license and copyright information

=begin TML

---+ package WysiwygPlugin

This plugin is responsible for translating TML to HTML before an edit starts
and translating the resultant HTML back into TML.

Note: In the case of a new topic, you might expect to see the "create topic"
screen in the editor when it goes back to Foswiki for the topic content. This
doesn't happen because the earliest possible handler is called on the topic
content and not the template. The template is effectively ignored and a blank
document is sent to the editor.

Attachment uploads can be handled by URL requests from the editor to the rest
handler in this plugin. This avoids the need to add any scripts to the bin dir.
You will have to use a form, though, as XmlHttpRequest does not support file
uploads.

=cut

package Foswiki::Plugins::WysiwygPlugin;

use CGI qw( :cgi -any );

use strict;

use Assert;
use Encode ();

use Foswiki::Func                              ();    # The plugins API
use Foswiki::Plugins                           ();    # For the API version
use Foswiki::Plugins::WysiwygPlugin::Constants ();

use vars qw( $html2tml $tml2html $recursionBlock $imgMap );
use vars qw( %FoswikiCompatibility @refs %xmltag %xmltagPlugin);

our $SHORTDESCRIPTION  = 'Translator framework for Wysiwyg editors';
our $NO_PREFS_IN_TOPIC = 1;
our $VERSION           = '$Rev$';

our $RELEASE = '17 Jan 2010';

our $SECRET_ID =
'WYSIWYG content - do not remove this comment, and never use this identical text in your topics';

sub WHY { 0 }

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # %OWEB%.%OTOPIC% is the topic where the initial content should be
    # grabbed from, as defined in templates/edit.skin.tmpl
    Foswiki::Func::registerTagHandler( 'OWEB',            \&_OWEBTAG );
    Foswiki::Func::registerTagHandler( 'OTOPIC',          \&_OTOPICTAG );
    Foswiki::Func::registerTagHandler( 'WYSIWYG_TEXT',    \&_WYSIWYG_TEXT );
    Foswiki::Func::registerTagHandler( 'JAVASCRIPT_TEXT', \&_JAVASCRIPT_TEXT );
    Foswiki::Func::registerTagHandler( 'WYSIWYG_SECRET_ID',
        sub { $SECRET_ID } );

    Foswiki::Func::registerRESTHandler( 'tml2html',    \&_restTML2HTML );
    Foswiki::Func::registerRESTHandler( 'html2tml',    \&_restHTML2TML );
    Foswiki::Func::registerRESTHandler( 'upload',      \&_restUpload );
    Foswiki::Func::registerRESTHandler( 'attachments', \&_restAttachments );

    # Plugin correctly initialized
    return 1;
}

sub _OWEBTAG {
    my ( $session, $params, $topic, $web ) = @_;

    my $query = Foswiki::Func::getCgiQuery();

    return $web unless $query;

    if ( defined( $query->param('templatetopic') ) ) {
        my @split = split( /\./, $query->param('templatetopic') );

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

    if ( defined( $query->param('templatetopic') ) ) {
        my @split = split( /\./, $query->param('templatetopic') );

        return $split[$#split];
    }

    return $topic;
}

$FoswikiCompatibility{startRenderingHandler} = 2.1;
sub startRenderingHandler {
    $_[0] =~ s#</?sticky>##g;
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
            foreach my $p qw( skin cover ) {
                my $arg = $query->param($p);
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

    if (   $Foswiki::cfg{Site}{CharSet}
        && $Foswiki::cfg{Site}{CharSet} =~ /^utf-?8$/i )
    {

        # If the site charset is utf-8, then form POSTs (such as the one
        # that got us here) are utf-8 encoded. we have to decode to prevent
        # the HTML parser from going tits up when it sees utf-8 in the data.
        $text = Encode::decode_utf8($text);
    }

    return
      unless defined( $query->param('wysiwyg_edit') )
          || $text =~ s/<!--$SECRET_ID-->//go;

    # Switch off wysiwyg_edit so it doesn't try to transform again in
    # the beforeSaveHandler
    $query->delete('wysiwyg_edit');

    $text = TranslateHTML2TML( $text, $_[1], $_[2] );

    $_[0] = $text;
}

# Invoked to convert HTML to TML (best efforts)
sub TranslateHTML2TML {
    my ( $text, $topic, $web ) = @_;

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

    my $opts = {
        web          => $web,
        topic        => $topic,
        convertImage => \&_convertImage,
        rewriteURL   => \&postConvertURL,
        very_clean   => 1,                  # aggressively polish saved HTML
    };

    $text = $html2tml->convert( $text, $opts );

    $text =~ s/\s+$/\n/s;

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
    return if $recursionBlock;
    return unless Foswiki::Func::getContext()->{body_text};

    my $query = Foswiki::Func::getCgiQuery();

    return unless $query;

    return unless defined( $query->param('wysiwyg_edit') );

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
    if ( $altText && Foswiki::Func::topicExists( $web, $altText ) ) {
        ( $web, $topic ) =
          Foswiki::Func::normalizeWebTopicName( $web, $altText );
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

    $text = TranslateTML2HTML( $text, $web, $topic );

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
    return if ( $recursionBlock || !$tml2html );

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

# callback passed to the TML2HTML convertor
sub getViewUrl {
    my ( $web, $topic ) = @_;

    # the Cairo documentation says getViewUrl defaults the web. It doesn't.
    unless ( defined $Foswiki::Plugins::SESSION ) {
        $web ||= $Foswiki::webName;
    }

    return Foswiki::Func::getViewUrl( $web, $topic );
}

# The subset of vars for which bidirection transformation is supported
# in URLs only
use vars qw( @VARS );

# The set of macros that get "special treatment" in URLs
@VARS = (
    '%ATTACHURL%',
    '%ATTACHURLPATH%',
    '%PUBURL%',
    '%PUBURLPATH%',
    '%SCRIPTURLPATH{"view"}%',
    '%SCRIPTURLPATH%',
    '%SCRIPTURL{"view"}%',
    '%SCRIPTURL%',
    '%SCRIPTSUFFIX%',    # bit dodgy, this one
);

# Initialises the mapping from var to URL and back
sub _populateVars {
    my $opts = shift;

    return if ( $opts->{exp} );

    local $recursionBlock = 1;    # block calls to beforeCommonTagshandler

    my @exp = split(
        /\0/,
        Foswiki::Func::expandCommonVariables(
            join( "\0", @VARS ),
            $opts->{topic}, $opts->{web}
        )
    );

    for my $i ( 0 .. $#VARS ) {
        my $nvar = $VARS[$i];
        $opts->{match}[$i] = $nvar;
        $exp[$i] ||= '';
    }
    $opts->{exp} = \@exp;
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
sub postConvertURL {
    my ( $url, $opts ) = @_;

    #my $orig = $url; #debug

    local $recursionBlock = 1;    # block calls to beforeCommonTagshandler

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
        $url =~ s/^$opts->{exp}->[$i]/$VARS[$i]/;
    }

    if ( $url =~ m#^%SCRIPTURL(?:PATH)?(?:{"view"}%|%/+view[^/]*)/+([/\w.]+)$#
        && !$parameters )
    {
        my $orig = $1;
        my ( $web, $topic ) =
          Foswiki::Func::normalizeWebTopicName( $opts->{web}, $orig );

        if ( $web && $web ne $opts->{web} ) {

            #print STDERR "$orig -> $web+$topic$anchor\n";    #debug
            return $web . '.' . $topic . $anchor;
        }

        #print STDERR "$orig -> $topic$anchor\n"; #debug
        return $topic . $anchor;
    }

    #print STDERR "$orig -> $url$anchor$parameters\n"; #debug
    return $url . $anchor . $parameters;
}

# Callback used to convert an image reference into a Foswiki variable.
sub _convertImage {
    my ( $src, $opts ) = @_;

    return unless $src;

    local $recursionBlock = 1;    # block calls to beforeCommonTagshandler

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

---++ StaticMethod notWysiwygEditable($text) -> $boolean
Determine if the given =$text= is WYSIWYG editable, based on the topic content
and the value of the Foswiki preferences WYSIWYG_EXCLUDE and
WYSIWYG_EDITABLE_CALLS. Returns a descriptive string if the text is not
editable, 0 otherwise.

=cut

sub notWysiwygEditable {

    #my ($text, $exclusions) = @_;

    my $exclusions = $_[1];
    unless ( defined($exclusions) ) {
        $exclusions = Foswiki::Func::getPreferencesValue('WYSIWYG_EXCLUDE')
          || '';
    }

    # Check for explicit exclusions before generic, non-configurable 
    # purely content-related reasons for exclusion
    if ($exclusions) {
        my $calls_ok = Foswiki::Func::getPreferencesValue('WYSIWYG_EDITABLE_CALLS')
          || '---';
        $calls_ok =~ s/\s//g;

        my $ok = 1;
        if (   $exclusions =~ /calls/
            && $_[0] =~ /%((?!($calls_ok){)[A-Z_]+{.*?})%/s )
        {
            print STDERR "WYSIWYG_DEBUG: has calls $1 (not in $calls_ok)\n"
              if (WHY);
            return "Text contains calls";
        }
        if ( $exclusions =~ /(macros|variables)/ && $_[0] =~ /%([A-Z_]+)%/s ) {
            print STDERR "$exclusions WYSIWYG_DEBUG: has macros $1\n"
              if (WHY);
            return "Text contains macros";
        }
        if (   $exclusions =~ /html/
            && $_[0] =~ /<\/?((?!literal|verbatim|noautolink|nop|br)\w+)/ )
        {
            print STDERR "WYSIWYG_DEBUG: has html: $1\n"
              if (WHY);
            return "Text contains HTML";
        }
        if ( $exclusions =~ /comments/ && $_[0] =~ /<[!]--/ ) {
            print STDERR "WYSIWYG_DEBUG: has comments\n"
              if (WHY);
            return "Text contains comments";
        }
        if ( $exclusions =~ /pre/ && $_[0] =~ /<pre\w/ ) {
            print STDERR "WYSIWYG_DEBUG: has pre\n"
              if (WHY);
            return "Text contains PRE";
        }
    }

    # Copy the content. 
    # Then crunch verbatim blocks, because verbatim blocks may contain *anything*.
    my $text = $_[0];

    # Look for combinations of sticky and other markup that cause problems together
    for my $tag ('literal', keys %xmltag) {
        while ($text =~ /<$tag\b[^>]*>(.*?)<\/$tag>/gsi) {
            my $inner = $1;
            if ($inner =~ /<sticky\b[^>]*>/i) {
                print STDERR "WYSIWYG_DEBUG: <sticky> inside <$tag>\n"
                  if (WHY);
                return "<sticky> inside <$tag>";
            }
        }
    }

    my $wasAVerbatimTag = "\000verbatim\001";
    while ($text =~ s/<verbatim\b[^>]*>(.*?)<\/verbatim>/$wasAVerbatimTag/i) {
        #my $content = $1;
        # If there is any content that breaks conversion if it is inside a verbatim block, 
        # check for it here:
    }

    # Look for combinations of verbatim and other markup that cause problems together
    for my $tag ('literal', keys %xmltag) {
        while ($text =~ /<$tag\b[^>]*>(.*?)<\/$tag>/gsi) {
            my $inner = $1;
            if ($inner =~ /$wasAVerbatimTag/i) {
                print STDERR "WYSIWYG_DEBUG: <verbatim> inside <$tag>\n"
                  if (WHY);
                return "<verbatim> inside <$tag>";
            }
        }
    }

    # Look for combinations of literal and other markup that cause problems together
    for my $tag (keys %xmltag) {
        while ($text =~ /<$tag\b[^>]*>(.*?)<\/$tag>/gsi) {
            my $inner = $1;
            if ($inner =~ /<literal\b[^>]*>/i) {
                print STDERR "WYSIWYG_DEBUG: <literal> inside <$tag>\n"
                  if (WHY);
                return "<literal> inside <$tag>";
            }
        }
    }

    # Check that the topic text can be converted to HTML
    eval {
        TranslateTML2HTML( $_[0], 'Fakewebname', 'FakeTopicName', dieOnError => 1 );
    };
    if ($@) {
        print STDERR "WYSIWYG_DEBUG: TML2HTML conversion threw an exception: $@\n"
          if (WHY);
        return "TML2HTML conversion fails";
    }

    return 0;
}

=pod

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

    if (   ( not exists $xmltag{$tag} and not exists $xmltagPlugin{$tag} )
        or ( $xmltagPlugin{$tag} eq $plugin ) )
    {

        # This is either a plugin adding a new tag
        # or a plugin adding a tag it had previously added before.
        # A plugin is allowed to add a tag that it had added before
        # and the new function replaces the old.
        #
        $fn = sub { 1 }
          unless $fn;    # Default function

        $xmltag{$tag}       = $fn;
        $xmltagPlugin{$tag} = $plugin;
    }
    else {

        # DON'T replace the existing processing for this tag
        printf STDERR "WysiwygPlugin::addXMLTag: "
          . "$plugin cannot add XML tag $tag, "
          . "that tag was already registered by $xmltagPlugin{$tag}\n";
    }
}

sub TranslateTML2HTML {
    my ( $text, $web, $topic, @extraConvertOptions ) = @_;

    # Translate the topic text to pure HTML.
    unless ($tml2html) {
        require Foswiki::Plugins::WysiwygPlugin::TML2HTML;
        $tml2html = new Foswiki::Plugins::WysiwygPlugin::TML2HTML();
    }
    return $tml2html->convert(
        $_[0],
        {
            web             => $web,
            topic           => $topic,
            getViewUrl      => \&getViewUrl,
            expandVarsInURL => \&expandVarsInURL,
            xmltag          => \%xmltag,
            @extraConvertOptions,
        }
    );
}

# PACKAGE PRIVATE
# Determine if sticky attributes prevent a tag being converted to
# TML when this attribute is present.
my @protectedByAttr;

sub protectedByAttr {
    my ( $tag, $attr ) = @_;

    unless ( scalar(@protectedByAttr) ) {

        # See the WysiwygPluginSettings for information on stickybits
        my $protection =
          Foswiki::Func::getPreferencesValue('WYSIWYGPLUGIN_STICKYBITS')
          || <<'DEFAULT';
.*=id,lang,title,dir,on.*;
a=accesskey,coords,shape,target;
bdo=dir;
br=clear;
col=char,charoff,span,valign,width;
colgroup=align,char,charoff,span,valign,width;
dir=compact;
div=align,style;
dl=compact;
font=size,face;
h\d=align;
hr=align,noshade,size,width;
legend=accesskey,align;
li=value;
ol=compact,start,type;
p=align;
param=name,type,value,valuetype;
pre=width;
q=cite;
table=align,bgcolor,frame,rules,summary,width;
tbody=align,char,charoff,valign;
td=abbr,align,axis,bgcolor,char,charoff,headers,height,nowrap,rowspan,scope,valign,width;
tfoot=align,char,charoff,valign;
th=abbr,align,axis,bgcolor,char,charoff,height,nowrap,rowspan,scope,valign,width,headers;
thead=align,char,charoff,valign;
tr=bgcolor,char,charoff,valign;
ul=compact,type;
DEFAULT
        foreach my $def ( split( /;\s*/s, $protection ) ) {
            my ( $re, $ats ) = split( /\s*=\s*/s, $def, 2 );
            push(
                @protectedByAttr,
                {
                    tag   => qr/$re/i,
                    attrs => join( '|', split( /\s*,\s*/, $ats ) )
                }
            );
        }
    }
    foreach my $row (@protectedByAttr) {
        if ( $tag =~ /^$row->{tag}$/i ) {
            if ( $attr =~ /^($row->{attrs})$/i ) {
                #print STDERR "Protecting  $tag with $attr matches $row->{attrs} \n";    #debug
                return 1;
            }
        }
    }
    return 0;
}

# Text that is taken from a web page and added to the parameters of an XHR
# by JavaScript is UTF-8 encoded. This is because UTF-8 is the default encoding
# for XML, which XHR was designed to transport.

# This function is used to decode such parameters to the currently selected
# Foswiki site character set.

# Note that this transform is not as simple as an Encode::from_to, as
# a number of unicode code points must be remapped for certain encodings.
sub RESTParameter2SiteCharSet {
    my ($text) = @_;

    $text = Encode::decode_utf8( $text, Encode::FB_PERLQQ );

    WC::mapUnicode2HighBit($text);

    if ( $Foswiki::cfg{Site}{CharSet} ) {
        $text = Encode::encode( $Foswiki::cfg{Site}{CharSet},
            $text, Encode::FB_PERLQQ );
    }

    return $text;
}

# Text that is taken from a web page and added to the parameters of an XHR
# by JavaScript is UTF-8 encoded. This is because UTF-8 is the default encoding
# for XML, which XHR was designed to transport. For usefulness in Javascript
# the response to an XHR should also be UTF-8 encoded.
# This function generates such a response.
sub returnRESTResult {
    my ( $response, $status, $text ) = @_;

    if ( $Foswiki::cfg{Site}{CharSet} ) {
        $text = Encode::decode( $Foswiki::cfg{Site}{CharSet},
            $text, Encode::FB_PERLQQ );
    }

    WC::mapHighBit2Unicode($text);

    $text = Encode::encode_utf8($text);

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
sub _restTML2HTML {
    my ( $session, $plugin, $verb, $response ) = @_;
    my $tml = Foswiki::Func::getCgiQuery()->param('text');

    $tml = RESTParameter2SiteCharSet($tml);

    # if the secret ID is present, don't convert again. We are probably
    # going 'back' to this page (doesn't work on IE :-( )
    if ( $tml =~ /<!--$SECRET_ID-->/ ) {
        return $tml;
    }

    my $html =
      TranslateTML2HTML( $tml, $session->{webName}, $session->{topicName} );

    # Add the secret id to trigger reconversion. Doesn't work if the
    # editor eats HTML comments, so the editor may need to put it back
    # in during final cleanup.
    $html = '<!--' . $SECRET_ID . '-->' . $html;

    returnRESTResult( $response, 200, $html );

    return;    # to prevent further processing
}

# Rest handler for use from Javascript
sub _restHTML2TML {
    my ( $session, $plugin, $verb, $response ) = @_;
    unless ($html2tml) {
        require Foswiki::Plugins::WysiwygPlugin::HTML2TML;

        $html2tml = new Foswiki::Plugins::WysiwygPlugin::HTML2TML();
    }
    my $html = Foswiki::Func::getCgiQuery()->param('text');

    $html = RESTParameter2SiteCharSet($html);

    $html =~ s/<!--$SECRET_ID-->//go;
    my $tml = $html2tml->convert(
        $html,
        {
            web             => $session->{webName},
            topic           => $session->{topicName},
            getViewUrl      => \&getViewUrl,
            expandVarsInURL => \&expandVarsInURL,
            very_clean      => 1,
        }
    );

    returnRESTResult( $response, 200, $tml );
    return;    # to prevent further processing
}

# SMELL: foswiki supports proper REST usage of the upload script,
# so debatable if this is required any more
sub _restUpload {
    my ( $session, $plugin, $verb, $response ) = @_;
    my $query = Foswiki::Func::getCgiQuery();

    # Item1458 ignore uploads not using POST
    if ( $query && $query->method() && uc( $query->method() ) ne 'POST' ) {
        returnRESTResult( $response, 405, "Method not Allowed" );
        return;
    }
    my ( $web, $topic ) =
      Foswiki::Func::normalizeWebTopicName( undef, $query->param('topic') );
    $web =
      Foswiki::Sandbox::untaint( $web, \&Foswiki::Sandbox::validateWebName );
    $topic = Foswiki::Sandbox::untaint( $topic,
        \&Foswiki::Sandbox::validateTopicName );
    unless ( defined $web && defined $topic ) {
        returnRESTResult( $response, 401, "Access denied" );
        return;    # to prevent further processing
    }
    my $hideFile    = $query->param('hidefile')    || '';
    my $fileComment = $query->param('filecomment') || '';
    my $createLink  = $query->param('createlink')  || '';
    my $doPropsOnly = $query->param('changeproperties');
    my $filePath    = $query->param('filepath')    || '';
    my $fileName    = $query->param('filename')    || '';
    if ( $filePath && !$fileName ) {
        $filePath =~ m|([^/\\]*$)|;
        $fileName = $1;
    }
    $fileComment =~ s/\s+/ /go;
    $fileComment =~ s/^\s*//o;
    $fileComment =~ s/\s*$//o;
    $fileName    =~ s/\s*$//o;
    $filePath    =~ s/\s*$//o;

    unless (
        Foswiki::Func::checkAccessPermission(
            'CHANGE', Foswiki::Func::getWikiName(),
            undef, $topic, $web
        )
      )
    {
        returnRESTResult( $response, 401, "Access denied" );
        return;    # to prevent further processing
    }

    my ( $fileSize, $fileDate, $tmpFileName );

    my $stream = $query->upload('filepath') unless $doPropsOnly;
    my $origName = $fileName;

    unless ($doPropsOnly) {

        # SMELL: call to unpublished function
        ( $fileName, $origName ) =
          Foswiki::Sandbox::sanitizeAttachmentName($fileName);

        # check if upload has non zero size
        if ($stream) {
            my @stats = stat $stream;
            $fileSize = $stats[7];
            $fileDate = $stats[9];
        }

        unless ( $fileSize && $fileName ) {
            returnRESTResult( $response, 500, "Zero-sized file upload" );
            return;    # to prevent further processing
        }

        my $maxSize =
          Foswiki::Func::getPreferencesValue('ATTACHFILESIZELIMIT') || 0;
        $maxSize =~ s/\s+$//;
        $maxSize = 0 unless ( $maxSize =~ /([0-9]+)/o );

        if ( $maxSize && $fileSize > $maxSize * 1024 ) {
            returnRESTResult( $response, 500, "OVERSIZED UPLOAD" );
            return;    # to prevent further processing
        }
    }

    # SMELL: use of undocumented CGI::tmpFileName
    my $tfp   = $query->tmpFileName( $query->param('filepath') );
    my $error = Foswiki::Func::saveAttachment(
        $web, $topic,
        $fileName,
        {
            dontlog     => !$Foswiki::cfg{Log}{upload},
            comment     => $fileComment,
            hide        => $hideFile,
            createlink  => $createLink,
            stream      => $stream,
            filepath    => $filePath,
            filesize    => $fileSize,
            filedate    => $fileDate,
            tmpFilename => $tfp,
        }
    );

    close($stream) if $stream;

    if ($error) {
        returnRESTResult( $response, 500, $error );
        return;    # to prevent further processing
    }

    # Otherwise allow the rest dispatcher to write a 200
    return "$origName attached to $web.$topic"
      . ( $origName ne $fileName ? " as $fileName" : '' );
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
sub _restAttachments {
    my ( $session, $plugin, $verb, $response ) = @_;
    my ( $web, $topic ) =
      Foswiki::Func::normalizeWebTopicName( undef,
        Foswiki::Func::getCgiQuery()->param('topic') );
    $web =
      Foswiki::Sandbox::untaint( $web, \&Foswiki::Sandbox::validateWebName );
    $topic = Foswiki::Sandbox::untaint( $topic,
        \&Foswiki::Sandbox::validateTopicName );
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
__DATA__
# Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008 Foswiki Contributors. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this file:
#
# Copyright (C) 2005 ILOG http://www.ilog.fr
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of your Foswiki (or TWiki)
# distribution.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of the TWiki distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.
