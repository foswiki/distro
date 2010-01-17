# See bottom of file for license and copyright information
package Foswiki;

=begin TML

---+ package Foswiki

Foswiki operates by creating a singleton object (known as the Session
object) that acts as a point of reference for all the different
modules in the system. This package is the class for this singleton,
and also contains the vast bulk of the basic constants and the per-
site configuration mechanisms.

Global variables are avoided wherever possible to avoid problems
with CGI accelerators such as mod_perl.

---++ Public Data members
   * =request=          Pointer to the Foswiki::Request
   * =response=         Pointer to the Foswiki::Respose
   * =context=          Hash of context ids
   * moved: =loginManager=     Foswiki::LoginManager singleton (moved to Foswiki::Users)
   * =plugins=          Foswiki::Plugins singleton
   * =prefs=            Foswiki::Prefs singleton
   * =remoteUser=       Login ID when using ApacheLogin. Maintained for
                        compatibility only, do not use.
   * =requestedWebName= Name of web found in URL path or =web= URL parameter
   * =scriptUrlPath=    URL path to the current script. May be dynamically
                        extracted from the URL path if {GetScriptUrlFromCgi}.
                        Only required to support {GetScriptUrlFromCgi} and
                        not consistently used. Avoid.
   * =security=         Foswiki::Access singleton
   * =SESSION_TAGS=     Hash of preference settings whose value is specific to
                        the current request.
   * =store=            Foswiki::Store singleton
   * =topicName=        Name of topic found in URL path or =topic= URL
                        parameter
   * =urlHost=          Host part of the URL (including the protocol)
                        determined during intialisation and defaulting to
                        {DefaultUrlHost}
   * =user=             Unique user ID of logged-in user
   * =users=            Foswiki::Users singleton
   * =webName=          Name of web found in URL path, or =web= URL parameter,
                        or {UsersWebName}

=cut

use strict;
use Assert;
use Error qw( :try );

use Fcntl;          # File control constants e.g. O_EXCL
use CGI         (); # Always required to get html generation tags;
use Digest::MD5 (); # For passthru and validation

use Foswiki::Response ();
use Foswiki::Request  ();
use Foswiki::Logger   ();
use Foswiki::Validation ();

require 5.005;    # For regex objects and internationalisation

# Site configuration constants
use vars qw( %cfg );

# Uncomment this and the __END__ to enable AutoLoader
#use AutoLoader 'AUTOLOAD';
# You then need to autosplit Foswiki.pm:
# cd lib
# perl -e 'use AutoSplit; autosplit("Foswiki.pm", "auto")'

# Other computed constants
our $foswikiLibDir;
our %regex;
our %functionTags;
our %contextFreeSyntax;
our $VERSION;
our $RELEASE;
our $TRUE  = 1;
our $FALSE = 0;
our $engine;
our $ifParser;

# Token character that must not occur in any normal text - converted
# to a flag character if it ever does occur (very unlikely)
# Foswiki uses $TranslationToken to mark points in the text. This is
# normally \0, which is not a useful character in any 8-bit character
# set we can find, nor in UTF-8. But if you *do* encounter problems
# with it, the workaround is to change $TranslationToken to something
# longer that is unlikely to occur in your text - for example
# muRfleFli5ble8leep (do *not* use punctuation characters or whitspace
# in the string!)
# See Codev.NationalCharTokenClash for more.
our $TranslationToken = "\0";

# Returns the full path of the directory containing Foswiki.pm
sub _getLibDir {
    return $foswikiLibDir if $foswikiLibDir;

    $foswikiLibDir = $INC{'Foswiki.pm'};

    # fix path relative to location of called script
    if ( $foswikiLibDir =~ /^\./ ) {
        print STDERR
"WARNING: Foswiki lib path $foswikiLibDir is relative; you should make it absolute, otherwise some scripts may not run from the command line.";
        my $bin;

        # SMELL : Should not assume environment variables; get data from request
        if (   $ENV{SCRIPT_FILENAME}
            && $ENV{SCRIPT_FILENAME} =~ m#^(.+)/.+?$# )
        {

            # CGI script name
            # implicit untaint OK, because of use of $SCRIPT_FILENAME
            $bin = $1;
        }
        elsif ( $0 =~ m#^(.*)/.*?$# ) {

            # program name
            # implicit untaint OK, because of use of $PROGRAM_NAME ($0)
            $bin = $1;
        }
        else {

            # last ditch; relative to current directory.
            require Cwd;
            $bin = Cwd::cwd();
        }
        $foswikiLibDir = "$bin/$foswikiLibDir/";

        # normalize "/../" and "/./"
        while ( $foswikiLibDir =~ s|([\\/])[^\\/]+[\\/]\.\.[\\/]|$1| ) {
        }
        $foswikiLibDir =~ s|([\\/])\.[\\/]|$1|g;
    }
    $foswikiLibDir =~ s|([\\/])[\\/]*|$1|g;    # reduce "//" to "/"
    $foswikiLibDir =~ s|[\\/]$||;              # cut trailing "/"

    return $foswikiLibDir;
}

BEGIN {
    require Monitor;
    require Foswiki::Sandbox;                  # system command sandbox
    require Foswiki::Configure::Load;          # read configuration files

    if (DEBUG) {

        # If ASSERTs are on, then warnings are errors. Paranoid,
        # but the only way to be sure we eliminate them all.
        # Look out also for $cfg{WarningsAreErrors}, below, which
        # is another way to install this handler without enabling
        # ASSERTs
        # ASSERTS are turned on by defining the environment variable
        # FOSWIKI_ASSERTS. If ASSERTs are off, this is assumed to be a
        # production environment, and no stack traces or paths are
        # output to the browser.
        $SIG{'__WARN__'} = sub { die @_ };
        $Error::Debug = 1;    # verbose stack traces, please
    }
    else {
        $Error::Debug = 0;    # no verbose stack traces
    }

    # DO NOT CHANGE THE FORMAT OF  $VERSION
    # Automatically expanded on checkin of this module 
    $VERSION = '$Date$ $Rev$ ';
    $RELEASE = 'Foswiki-1.0.9';
    $VERSION =~ s/^.*?\((.*)\).*: (\d+) .*?$/$RELEASE, $1, build $2/;

    # Default handlers for different %TAGS%
    %functionTags = (
        ADDTOHEAD         => \&ADDTOHEAD,
        ALLVARIABLES      => \&ALLVARIABLES,
        ATTACHURL         => \&ATTACHURL,
        ATTACHURLPATH     => \&ATTACHURLPATH,
        COREPOD           => \&COREPOD,
        DATE              => \&DATE,
        DISPLAYTIME       => \&DISPLAYTIME,
        ENCODE            => \&ENCODE,
        ENV               => \&ENV,
        FORMFIELD         => \&FORMFIELD,
        GMTIME            => \&GMTIME,
        GROUPS            => \&GROUPS,
        HTTP_HOST         => \&HTTP_HOST_deprecated,
        HTTP              => \&HTTP,
        HTTPS             => \&HTTPS,
        ICON              => \&ICON,
        ICONURL           => \&ICONURL,
        ICONURLPATH       => \&ICONURLPATH,
        IF                => \&IF,
        INCLUDE           => \&INCLUDE,
        INTURLENCODE      => \&INTURLENCODE_deprecated,
        LANGUAGES         => \&LANGUAGES,
        MAKETEXT          => \&MAKETEXT,
        META              => \&META,
        METASEARCH        => \&METASEARCH,
        NOP               => \&NOP,
        PLUGINVERSION     => \&PLUGINVERSION,
        PUBURL            => \&PUBURL,
        PUBURLPATH        => \&PUBURLPATH,
        QUERYPARAMS       => \&QUERYPARAMS,
        QUERYSTRING       => \&QUERYSTRING,
        RELATIVETOPICPATH => \&RELATIVETOPICPATH,
        REMOTE_ADDR       => \&REMOTE_ADDR_deprecated,
        REMOTE_PORT       => \&REMOTE_PORT_deprecated,
        REMOTE_USER       => \&REMOTE_USER_deprecated,
        RENDERHEAD        => \&RENDERHEAD,
        REVINFO           => \&REVINFO,
        REVTITLE          => \&REVTITLE,
        REVARG            => \&REVARG,
        SCRIPTNAME        => \&SCRIPTNAME,
        SCRIPTURL         => \&SCRIPTURL,
        SCRIPTURLPATH     => \&SCRIPTURLPATH,
        SEARCH            => \&SEARCH,
        SEP               => \&SEP,
        SERVERTIME        => \&SERVERTIME,
        SPACEDTOPIC       => \&SPACEDTOPIC_deprecated,
        SPACEOUT          => \&SPACEOUT,
        'TMPL:P'          => \&TMPLP,
        TOPICLIST         => \&TOPICLIST,
        URLENCODE         => \&ENCODE,
        URLPARAM          => \&URLPARAM,
        LANGUAGE          => \&LANGUAGE,
        USERINFO          => \&USERINFO,
        USERNAME          => \&USERNAME_deprecated,
        VAR               => \&VAR,
        WEBLIST           => \&WEBLIST,
        WIKINAME          => \&WIKINAME_deprecated,
        WIKIUSERNAME      => \&WIKIUSERNAME_deprecated,

        # Constant tag strings _not_ dependent on config. These get nicely
        # optimised by the compiler.
        ENDSECTION   => sub { '' },
        WIKIVERSION  => sub { $VERSION },
        STARTSECTION => sub { '' },
        STARTINCLUDE => sub { '' },
        STOPINCLUDE  => sub { '' },
    );
    $contextFreeSyntax{IF} = 1;

    unless ( ( $Foswiki::cfg{DetailedOS} = $^O ) ) {
        require Config;
        $Foswiki::cfg{DetailedOS} = $Config::Config{'osname'};
    }
    $Foswiki::cfg{OS} = 'UNIX';
    if ( $Foswiki::cfg{DetailedOS} =~ /darwin/i ) {    # MacOS X
        $Foswiki::cfg{OS} = 'UNIX';
    }
    elsif ( $Foswiki::cfg{DetailedOS} =~ /Win/i ) {
        $Foswiki::cfg{OS} = 'WINDOWS';
    }
    elsif ( $Foswiki::cfg{DetailedOS} =~ /vms/i ) {
        $Foswiki::cfg{OS} = 'VMS';
    }
    elsif ( $Foswiki::cfg{DetailedOS} =~ /bsdos/i ) {
        $Foswiki::cfg{OS} = 'UNIX';
    }
    elsif ( $Foswiki::cfg{DetailedOS} =~ /dos/i ) {
        $Foswiki::cfg{OS} = 'DOS';
    }
    elsif ( $Foswiki::cfg{DetailedOS} =~ /^MacOS$/i ) {    # MacOS 9 or earlier
        $Foswiki::cfg{OS} = 'MACINTOSH';
    }
    elsif ( $Foswiki::cfg{DetailedOS} =~ /os2/i ) {
        $Foswiki::cfg{OS} = 'OS2';
    }

    # readConfig is defined in Foswiki::Configure::Load to allow overriding it
    Foswiki::Configure::Load::readConfig();

    if ( $Foswiki::cfg{WarningsAreErrors} ) {

        # Note: Warnings are always errors if ASSERTs are enabled
        $SIG{'__WARN__'} = sub { die @_ };
    }

    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }

    # If not set, default to strikeone validation
    $Foswiki::cfg{Validation}{Method} ||= 'strikeone';
    $Foswiki::cfg{Validation}{ValidForTime} = $Foswiki::cfg{LeaseLength}
      unless defined $Foswiki::cfg{Validation}{ValidForTime};
    $Foswiki::cfg{Validation}{MaxKeys} = 1000
      unless defined $Foswiki::cfg{Validation}{MaxKeys};

    # Constant tags dependent on the config
    $functionTags{ALLOWLOGINNAME} =
      sub { $Foswiki::cfg{Register}{AllowLoginName} || 0 };
    $functionTags{AUTHREALM}      = sub { $Foswiki::cfg{AuthRealm} };
    $functionTags{DEFAULTURLHOST} = sub { $Foswiki::cfg{DefaultUrlHost} };
    $functionTags{HOMETOPIC}      = sub { $Foswiki::cfg{HomeTopicName} };
    $functionTags{LOCALSITEPREFS} = sub { $Foswiki::cfg{LocalSitePreferences} };
    $functionTags{NOFOLLOW} =
      sub { $Foswiki::cfg{NoFollow} ? 'rel=' . $Foswiki::cfg{NoFollow} : '' };
    $functionTags{NOTIFYTOPIC}     = sub { $Foswiki::cfg{NotifyTopicName} };
    $functionTags{SCRIPTSUFFIX}    = sub { $Foswiki::cfg{ScriptSuffix} };
    $functionTags{STATISTICSTOPIC} = sub { $Foswiki::cfg{Stats}{TopicName} };
    $functionTags{SYSTEMWEB}       = sub { $Foswiki::cfg{SystemWebName} };
    $functionTags{TRASHWEB}        = sub { $Foswiki::cfg{TrashWebName} };
    $functionTags{WIKIADMINLOGIN}  = sub { $Foswiki::cfg{AdminUserLogin} };
    $functionTags{USERSWEB}        = sub { $Foswiki::cfg{UsersWebName} };
    $functionTags{WEBPREFSTOPIC}   = sub { $Foswiki::cfg{WebPrefsTopicName} };
    $functionTags{WIKIPREFSTOPIC}  = sub { $Foswiki::cfg{SitePrefsTopicName} };
    $functionTags{WIKIUSERSTOPIC}  = sub { $Foswiki::cfg{UsersTopicName} };
    $functionTags{WIKIWEBMASTER}   = sub { $Foswiki::cfg{WebMasterEmail} };
    $functionTags{WIKIWEBMASTERNAME} = sub { $Foswiki::cfg{WebMasterName} };

    # locale setup
    #
    #
    # Note that 'use locale' must be done in BEGIN block for regexes and
    # sorting to work properly, although regexes can still work without
    # this in 'non-locale regexes' mode.

    if ( $Foswiki::cfg{UseLocale} ) {

        # Set environment variables for grep
        $ENV{LC_CTYPE} = $Foswiki::cfg{Site}{Locale};

        # Load POSIX for I18N support.
        require POSIX;
        import POSIX qw( locale_h LC_CTYPE LC_COLLATE );

       # SMELL: mod_perl compatibility note: If Foswiki is running under Apache,
       # won't this play with the Apache process's locale settings too?
       # What effects would this have?
        setlocale( &LC_CTYPE,   $Foswiki::cfg{Site}{Locale} );
        setlocale( &LC_COLLATE, $Foswiki::cfg{Site}{Locale} );
    }

    $functionTags{CHARSET} = sub {
        $Foswiki::cfg{Site}{CharSet}
          || 'iso-8859-1';
    };

    $functionTags{LANG} = sub {
        $Foswiki::cfg{Site}{Locale} =~ m/^([a-z]+_[a-z]+)/i ? $1 : 'en_US';
    };

    # Set up pre-compiled regexes for use in rendering.  All regexes with
    # unchanging variables in match should use the '/o' option.
    # In the regex hash, all precompiled REs have "Regex" at the
    # end of the name. Anything else is a string, either intended
    # for use as a character class, or as a sub-expression in
    # another compiled RE.

    # Build up character class components for use in regexes.
    # Depends on locale mode and Perl version, and finally on
    # whether locale-based regexes are turned off.
    if (   not $Foswiki::cfg{UseLocale}
        or $] < 5.006
        or not $Foswiki::cfg{Site}{LocaleRegexes} )
    {

        # No locales needed/working, or Perl 5.005, so just use
        # any additional national characters defined in LocalSite.cfg
        $regex{upperAlpha} = 'A-Z' . $Foswiki::cfg{UpperNational};
        $regex{lowerAlpha} = 'a-z' . $Foswiki::cfg{LowerNational};
        $regex{numeric}    = '\d';
        $regex{mixedAlpha} = $regex{upperAlpha} . $regex{lowerAlpha};
    }
    else {

        # Perl 5.006 or higher with working locales
        $regex{upperAlpha} = '[:upper:]';
        $regex{lowerAlpha} = '[:lower:]';
        $regex{numeric}    = '[:digit:]';
        $regex{mixedAlpha} = '[:alpha:]';
    }
    $regex{mixedAlphaNum} = $regex{mixedAlpha} . $regex{numeric};
    $regex{lowerAlphaNum} = $regex{lowerAlpha} . $regex{numeric};
    $regex{upperAlphaNum} = $regex{upperAlpha} . $regex{numeric};

    # Compile regexes for efficiency and ease of use
    # Note: qr// locks in regex modes (i.e. '-xism' here) - see Friedl
    # book at http://regex.info/.

    $regex{linkProtocolPattern} = $Foswiki::cfg{LinkProtocolPattern};

    # Header patterns based on '+++'. The '###' are reserved for numbered
    # headers
    # '---++ Header', '---## Header'
    $regex{headerPatternDa} = qr/^---+(\++|\#+)(.*)$/m;

    # '<h6>Header</h6>
    $regex{headerPatternHt} = qr/^<h([1-6])>(.+?)<\/h\1>/mi;

    # '---++!! Header' or '---++ Header %NOTOC% ^top'
    $regex{headerPatternNoTOC} = '(\!\!+|%NOTOC%)';

    # Foswiki concept regexes
    $regex{wikiWordRegex} =
qr/[$regex{upperAlpha}]+[$regex{lowerAlphaNum}]+[$regex{upperAlpha}]+[$regex{mixedAlphaNum}]*/o;
    $regex{webNameBaseRegex} =
      qr/[$regex{upperAlpha}]+[$regex{mixedAlphaNum}_]*/o;
    if ( $Foswiki::cfg{EnableHierarchicalWebs} ) {
        $regex{webNameRegex} =
          qr/$regex{webNameBaseRegex}(?:(?:[\.\/]$regex{webNameBaseRegex})+)*/o;
    }
    else {
        $regex{webNameRegex} = $regex{webNameBaseRegex};
    }
    $regex{defaultWebNameRegex} = qr/_[$regex{mixedAlphaNum}_]+/o;
    $regex{anchorRegex}         = qr/\#[$regex{mixedAlphaNum}_]+/o;
    $regex{abbrevRegex}         = qr/[$regex{upperAlpha}]{3,}s?\b/o;
    $regex{topicNameRegex} =
      qr/(?:(?:$regex{wikiWordRegex})|(?:$regex{abbrevRegex}))/o;

    # Simplistic email regex, e.g. for WebNotify processing - no i18n
    # characters allowed
    $regex{emailAddrRegex} =
      qr/([a-z0-9!+$%&'*+-\/=?^_`{|}~.]+\@[a-z0-9\.\-]+)/i;

# Filename regex to used to match invalid characters in attachments - allow
# alphanumeric characters, spaces, underscores, etc.
# TODO: Get this to work with I18N chars - currently used only with UseLocale off
    $regex{filenameInvalidCharRegex} = qr/[^$regex{mixedAlphaNum}\. _-]/o;

    # Multi-character alpha-based regexes
    $regex{mixedAlphaNumRegex} = qr/[$regex{mixedAlphaNum}]*/o;

    # %TAG% name
    $regex{tagNameRegex} =
      '[' . $regex{mixedAlpha} . '][' . $regex{mixedAlphaNum} . '_:]*';

    # Set statement in a topic
    $regex{bulletRegex} = '^(?:\t|   )+\*';
    $regex{setRegex}    = $regex{bulletRegex} . '\s+(Set|Local)\s+';
    $regex{setVarRegex} =
      $regex{setRegex} . '(' . $regex{tagNameRegex} . ')\s*=\s*(.*)$';

    # Character encoding regexes

    # 7-bit ASCII only
    $regex{validAsciiStringRegex} = qr/^[\x00-\x7F]+$/o;

    # Regex to match only a valid UTF-8 character, taking care to avoid
    # security holes due to overlong encodings by excluding the relevant
    # gaps in UTF-8 encoding space - see 'perldoc perlunicode', Unicode
    # Encodings section.  Tested against Markus Kuhn's UTF-8 test file
    # at http://www.cl.cam.ac.uk/~mgk25/ucs/examples/UTF-8-test.txt.
    $regex{validUtf8CharRegex} = qr{
                # Single byte - ASCII
                [\x00-\x7F]
                |

                # 2 bytes
                [\xC2-\xDF][\x80-\xBF]
                |

                # 3 bytes

                    # Avoid illegal codepoints - negative lookahead
                    (?!\xEF\xBF[\xBE\xBF])

                    # Match valid codepoints
                    (?:
                    ([\xE0][\xA0-\xBF])|
                    ([\xE1-\xEC\xEE-\xEF][\x80-\xBF])|
                    ([\xED][\x80-\x9F])
                    )
                    [\x80-\xBF]
                |

                # 4 bytes
                    (?:
                    ([\xF0][\x90-\xBF])|
                    ([\xF1-\xF3][\x80-\xBF])|
                    ([\xF4][\x80-\x8F])
                    )
                    [\x80-\xBF][\x80-\xBF]
                }xo;

    $regex{validUtf8StringRegex} = qr/^ (?: $regex{validUtf8CharRegex} )+ $/xo;

    # Check for unsafe search regex mode (affects filtering in) - default
    # to safe mode
    $Foswiki::cfg{ForceUnsafeRegexes} = 0
      unless defined $Foswiki::cfg{ForceUnsafeRegexes};

    # initialize lib directory early because of later 'cd's
    _getLibDir();

    # initialize the runtime engine
    if ( !defined $Foswiki::cfg{Engine} ) {

        # Caller did not define an engine; try and work it out (mainly for
        # the benefit of pre-1.0 CGI scripts)
        $Foswiki::cfg{Engine} = 'Foswiki::Engine::Legacy';
    }
    $engine = eval qq(use $Foswiki::cfg{Engine}; $Foswiki::cfg{Engine}->new);
    die $@ if $@;

    Monitor::MARK('Static configuration loaded');
}

=begin TML

---++ ObjectMethod UTF82SiteCharSet( $utf8 ) -> $ascii

Auto-detect UTF-8 vs. site charset in string, and convert UTF-8 into site
charset.

=cut

sub UTF82SiteCharSet {
    my ( $this, $text ) = @_;

    return $text unless ( defined $Foswiki::cfg{Site}{CharSet} );

    # Detect character encoding of the full topic name from URL
    return undef if ( $text =~ $regex{validAsciiStringRegex} );

    # SMELL: all this regex stuff should go away.
    # If not UTF-8 - assume in site character set, no conversion required
    if ( $^O eq 'darwin' ) {

        #this is a gross over-generalisation - as not all darwins are apple's
        # and not all darwins use apple's perl
        my $trial = $text;
        $trial =~ s/$regex{validUtf8CharRegex}//g;
        return unless ( length($trial) == 0 );
    }
    else {

        #SMELL: this seg faults on OSX leopard. (and possibly others)
        return undef unless ( $text =~ $regex{validUtf8StringRegex} );
    }

    # If site charset is already UTF-8, there is no need to convert anything:
    if ( $Foswiki::cfg{Site}{CharSet} =~ /^utf-?8$/i ) {

        # warn if using Perl older than 5.8
        if ( $] < 5.008 ) {
            $this->logger->log( 'warning',
                    'UTF-8 not remotely supported on Perl ' 
                  . $]
                  . ' - use Perl 5.8 or higher..' );
        }

        # We still don't have Codev.UnicodeSupport
        $this->logger->log( 'warning',
                'UTF-8 not yet supported as site charset -'
              . 'Foswiki is likely to have problems' );
        return $text;
    }

    # Convert into ISO-8859-1 if it is the site charset.  This conversion
    # is *not valid for ISO-8859-15*.
    if ( $Foswiki::cfg{Site}{CharSet} =~ /^iso-?8859-?1$/i ) {

        # ISO-8859-1 maps onto first 256 codepoints of Unicode
        # (conversion from 'perldoc perluniintro')
        $text =~ s/ ([\xC2\xC3]) ([\x80-\xBF]) /
          chr( ord($1) << 6 & 0xC0 | ord($2) & 0x3F )
            /egx;
    }
    else {

        # Convert from UTF-8 into some other site charset
        if ( $] >= 5.008 ) {
            require Encode;
            import Encode qw(:fallbacks);

            # Map $Foswiki::cfg{Site}{CharSet} into real encoding name
            my $charEncoding =
              Encode::resolve_alias( $Foswiki::cfg{Site}{CharSet} );
            if ( not $charEncoding ) {
                $this->logger->log( 'warning',
                        'Conversion to "'
                      . $Foswiki::cfg{Site}{CharSet}
                      . '" not supported, or name not recognised - check '
                      . '"perldoc Encode::Supported"' );
            }
            else {

                # Convert text using Encode:
                # - first, convert from UTF8 bytes into internal
                # (UTF-8) characters
                $text = Encode::decode( 'utf8', $text );

                # - then convert into site charset from internal UTF-8,
                # inserting \x{NNNN} for characters that can't be converted
                $text = Encode::encode( $charEncoding, $text, &FB_PERLQQ() );
            }
        }
        else {
            require Unicode::MapUTF8;    # Pre-5.8 Perl versions
            my $charEncoding = $Foswiki::cfg{Site}{CharSet};
            if ( not Unicode::MapUTF8::utf8_supported_charset($charEncoding) ) {
                $this->logger->log( 'warning',
                        'Conversion to "'
                      . $Foswiki::cfg{Site}{CharSet}
                      . '" not supported, or name not recognised - check '
                      . '"perldoc Unicode::MapUTF8"' );
            }
            else {

                # Convert text
                $text = Unicode::MapUTF8::from_utf8(
                    {
                        -string  => $text,
                        -charset => $charEncoding
                    }
                );

                # FIXME: Check for failed conversion?
            }
        }
    }
    return $text;
}

=begin TML

---++ ObjectMethod writeCompletePage( $text, $pageType, $contentType )

Write a complete HTML page with basic header to the browser.
   * =$text= is the text of the page body (&lt;html&gt; to &lt;/html&gt; if it's HTML)
   * =$pageType= - May be "edit", which will cause headers to be generated that force
     caching for 24 hours, to prevent Codev.BackFromPreviewLosesText bug, which caused
     data loss with IE5 and IE6.
   * =$contentType= - page content type | text/html

This method removes noautolink and nop tags before outputting the page unless
$contentType is text/plain.

=cut

sub writeCompletePage {
    my ( $this, $text, $pageType, $contentType ) = @_;
    $contentType ||= 'text/html';

    if ( $contentType ne 'text/plain' ) {

        # Remove <nop> and <noautolink> tags
        $text =~ s/([\t ]?)[ \t]*<\/?(nop|noautolink)\/?>/$1/gis;
        $text .= "\n" unless $text =~ /\n$/s;

        my $cgis = $this->getCGISession();
        if ( $cgis && $contentType eq 'text/html'
               && $Foswiki::cfg{Validation}{Method} ne 'none') {
            # Don't expire the validation key through login, or when
            # endpoint is an error.
            Foswiki::Validation::expireValidationKeys($cgis)
                unless ($this->{request}->action() eq 'login'
                          or ( $ENV{REDIRECT_STATUS} || 0 ) >= 400);
            my $usingStrikeOne = 0;
            if ($Foswiki::cfg{Validation}{Method} eq 'strikeone'
                  # Add the onsubmit handler to the form
                  && $text =~ s/(<form[^>]*method=['"]POST['"][^>]*>)/
                    Foswiki::Validation::addOnSubmit($1)/gei) {
                # At least one form has been touched; add the validation
                # cookie
                $this->{users}->{loginManager}->addCookie(
                    Foswiki::Validation::getCookie(
                        $cgis, $this->{response}));
                # Add the JS module to the page. Note that this is *not*
                # incorporated into the foswikilib.js because that module
                # is conditionally loaded under the control of the
                # templates, and we have to be *sure* it gets loaded.
                $this->addToHEAD( 'FOSWIKI STRIKE ONE',
                                  <<STRIKEONE);
<script type="text/javascript" src="$Foswiki::cfg{PubUrlPath}/$Foswiki::cfg{SystemWebName}/JavascriptFiles/strikeone.js"></script>
STRIKEONE
                $usingStrikeOne = 1;
            }
            # Inject validation key in HTML forms
            my $context =
              $this->{request}->url( -full => 1, -path => 1, -query => 1 )
                . time();
            $text =~ s/(<form[^>]*method=['"]POST['"][^>]*>)/
              $1 . Foswiki::Validation::addValidationKey(
                  $cgis, $context, $usingStrikeOne )/gei;
        }
        my $htmlHeader = join( "\n",
            map { '<!--' . $_ . '-->' . $this->{_HTMLHEADERS}{$_} }
              keys %{ $this->{_HTMLHEADERS} } );
        $text =~ s!(</head>)!$htmlHeader$1!i if $htmlHeader;
        chomp($text);
    }

    $this->generateHTTPHeaders( undef, $pageType, $contentType );
    my $hdr = $this->{response}->printHeaders;

    # Call final handler
    $this->{plugins}->dispatch( 'completePageHandler', $text, $hdr );

    $this->{response}->print($text);
}

=begin TML

---++ ObjectMethod generateHTTPHeaders( $query, $pageType, $contentType ) -> $header

All parameters are optional.

   * =$query= CGI query object | Session CGI query (there is no good reason to set this)
   * =$pageType= - May be "edit", which will cause headers to be generated that force caching for 24 hours, to prevent Codev.BackFromPreviewLosesText bug, which caused data loss with IE5 and IE6.
   * =$contentType= - page content type | text/html

=cut

sub generateHTTPHeaders {
    my ( $this, $query, $pageType, $contentType ) = @_;

    $query = $this->{request} unless $query;

    # Handle Edit pages - future versions will extend to caching
    # of other types of page, with expiry time driven by page type.
    my ( $pluginHeaders, $coreHeaders );

    my $hopts = {};

    if ( $pageType && $pageType eq 'edit' ) {

        # Get time now in HTTP header format
        require Foswiki::Time;
        my $lastModifiedString =
          Foswiki::Time::formatTime( time, '$http', 'gmtime' );

        # Expiry time is set high to avoid any data loss.  Each instance of
        # Edit page has a unique URL with time-string suffix (fix for
        # RefreshEditPage), so this long expiry time simply means that the
        # browser Back button always works.  The next Edit on this page
        # will use another URL and therefore won't use any cached
        # version of this Edit page.
        my $expireHours   = 24;
        my $expireSeconds = $expireHours * 60 * 60;

        # and cache control headers, to ensure edit page
        # is cached until required expiry time.
        $hopts->{'last-modified'} = $lastModifiedString;
        $hopts->{expires}         = "+${expireHours}h";
        $hopts->{'cache-control'} = "max-age=$expireSeconds";
    }

    # DEPRECATED plugins header handler. Plugins should use
    # modifyHeaderHandler instead.
    $pluginHeaders = $this->{plugins}->dispatch( 'writeHeaderHandler', $query )
      || '';
    if ($pluginHeaders) {
        foreach ( split /\r?\n/, $pluginHeaders ) {

            # Implicit untaint OK; data from plugin handler
            if (m/^([\-a-z]+): (.*)$/i) {
                $hopts->{$1} = $2;
            }
        }
    }

    $contentType = 'text/html' unless $contentType;
    if ( defined( $Foswiki::cfg{Site}{CharSet} ) ) {
        $contentType .= '; charset=' . $Foswiki::cfg{Site}{CharSet};
    }

    # use our version of the content type
    $hopts->{'Content-Type'} = $contentType;

    # New (since 1.026)
    $this->{plugins}
      ->dispatch( 'modifyHeaderHandler', $hopts, $this->{request} );

    # add cookie(s)
    $this->{users}->{loginManager}->modifyHeader($hopts);

    # The headers method resets all headers to what we pass
    # what we want is simply ensure our headers are there
    $this->{response}->setDefaultHeaders($hopts);
}

# Tests if the $redirect is an external URL, returning false if
# AllowRedirectUrl is denied
sub _isRedirectSafe {
    my $redirect = shift;

    return 1 if ( $Foswiki::cfg{AllowRedirectUrl} );
    return 1 if $redirect =~ m#^/#;    # relative URL - OK

    #TODO: this should really use URI
    # Compare protocol, host name and port number
    if ( $redirect =~ m!^(.*?://[^/]*)! ) {

        # implicit untaints OK because result not used. uc retaints
        # if use locale anyway.
        my $target = uc($1);

        $Foswiki::cfg{DefaultUrlHost} =~ m!^(.*?://[^/]*)!;
        return 1 if ( $target eq uc($1) );

        if ( $Foswiki::cfg{PermittedRedirectHostUrls} ) {
            foreach my $red (
                split( /\s*,\s*/, $Foswiki::cfg{PermittedRedirectHostUrls} ) )
            {
                $red =~ m!^(.*?://[^/]*)!;
                return 1 if ( $target eq uc($1) );
            }
        }
    }
    return 0;
}

=begin TML

---++ ObjectMethod redirectto($url) -> $url
Gets a redirect url from CGI parameter 'redirectto', if present on the query.

If the redirectto CGI parameter specifies a valid redirection target it is
returned; otherwise the original URL passed in the parameter is returned.

Conditions for a valid redirection target are:
   * The target matches the linkProtocolPattern regex, and redirection
     to the url _isRedirectSafe
   * The target specified a topic, or a Web.Topic (redirect will be to
     'view')

=cut

sub redirectto {
    my ( $this, $url ) = @_;
    ASSERT($url);

    my $redirecturl = $this->{request}->param('redirectto');
    return $url unless $redirecturl;

    if ( $redirecturl =~ m#^$regex{linkProtocolPattern}://#o ) {

        # assuming URL
        if ( _isRedirectSafe($redirecturl) ) {
            return $redirecturl;
        }
        else {
            return $url;
        }
    }

    # assuming 'web.topic' or 'topic'
    my ( $w, $t ) =
      $this->normalizeWebTopicName( $this->{webName}, $redirecturl );

    # capture anchor
    my ( $topic, $anchor ) = split( '#', $t, 2 );
    $t = $topic if $topic;
    my @attrs = ();
    push( @attrs, '#' => $anchor ) if $anchor;

    return $this->getScriptUrl( 1, 'view', $w, $t, @attrs );
}

=begin TML

---++ StaticMethod splitAnchorFromUrl( $url ) -> ( $url, $anchor )

Takes a full url (including possible query string) and splits off the anchor.
The anchor includes the # sign. Returns an empty string if not found in the url.

=cut

sub splitAnchorFromUrl {
    my ($url) = @_;

    ($url, my $anchor) = $url =~ m/^(.*?)(#(.*?))*$/;
    return ( $url, $anchor );
}

=begin TML

---++ ObjectMethod redirect( $url, $passthrough )

   * $url - url or topic to redirect to
   * $passthrough - (optional) parameter to pass through current query
     parameters (see below)

Redirects the request to =$url=, *unless*
   1 It is overridden by a plugin declaring a =redirectCgiQueryHandler=.
   1 =$session->{request}= is =undef= or
Thus a redirect is only generated when in a CGI context.

Normally this method will ignore parameters to the current query. Sometimes,
for example when redirecting to a login page during authentication (and then
again from the login page to the original requested URL), you want to make
sure all parameters are passed on, and for this $passthrough should be set to
true. In this case it will pass all parameters that were passed to the
current query on to the redirect target. If the request_method for the
current query was GET, then all parameters will be passed by encoding them
in the URL (after ?). If the request_method was POST, then there is a risk the
URL would be too big for the receiver, so it caches the form data and passes
over a cache reference in the redirect GET.

NOTE: Passthrough is only meaningful if the redirect target is on the same
server.

=cut

sub redirect {
    my ( $this, $url, $passthru ) = @_;
    ASSERT( defined $url );

    my $query = $this->{request};

    # if we got here without a query, there's not much more we can do
    return unless $query;

	( $url, my $anchor ) = splitAnchorFromUrl($url);

    if ( $passthru && defined $query->method() ) {
        my $existing = '';
        if ( $url =~ s/\?(.*)$// ) {
            $existing = $1;    # implicit untaint OK; recombined later
        }

        if ( uc( $query->method() ) eq 'POST' ) {

            # Redirecting from a post to a get
            my $cache = $this->cacheQuery();
            if ($cache) {
                if ($url eq '/') {
                    $url = $this->getScriptUrl(1, 'view');
                }
                $url .= $cache;
            }
        }
        else {
            # Redirecting a get to a get; no need to use passthru
            if ( $query->query_string() ) {
                $url .= '?' . $query->query_string();
            }
            if ($existing) {
                if ( $url =~ /\?/ ) {
                    $url .= ';';
                }
                else {
                    $url .= '?';
                }
                $url .= $existing;
            }
        }
    }

    # prevent phishing by only allowing redirect to configured host
    # do this check as late as possible to catch _any_ last minute hacks
    # TODO: this should really use URI
    if ( !_isRedirectSafe($url) ) {

        # goto oops if URL is trying to take us somewhere dangerous
        $url = $this->getScriptUrl(
            1, 'oops',
            $this->{web}   || $Foswiki::cfg{UsersWebName},
            $this->{topic} || $Foswiki::cfg{HomeTopicName},
            template => 'oopsaccessdenied',
            def      => 'topic_access',
            param1   => 'redirect',
            param2   => 'unsafe redirect to ' 
              . $url
              . ': host does not match {DefaultUrlHost} , and is not in {PermittedRedirectHostUrls}"'
              . $Foswiki::cfg{DefaultUrlHost} . '"'
        );
    }

	$url .= $anchor if $anchor;

    return
      if ( $this->{plugins}
        ->dispatch( 'redirectCgiQueryHandler', $this->{response}, $url ) );

    # SMELL: this is a bad breaking of encapsulation: the loginManager
    # should just modify the url, then the redirect should only happen here.
    return !$this->{users}->{loginManager}->redirectCgiQuery( $query, $url );
}

=begin TML

---++ ObjectMethod cacheQuery() -> $queryString

Caches the current query in the params cache, and returns a rewritten
query string for the cache to be picked up again on the other side of a
redirect.

We can't encode post params into a redirect, because they may exceed the
size of the GET request. So we cache the params, and reload them when the
redirect target is reached.

=cut

sub cacheQuery {
    my $this  = shift;
    my $query = $this->{request};

    return '' unless ( scalar( $query->param() ) );

    # Don't double-cache
    return '' if ( $query->param('foswiki_redirect_cache') );

    $this->{digester}->add( $$, rand(time) );
    my $uid              = $this->{digester}->hexdigest();
    my $passthruFilename = "$Foswiki::cfg{WorkingDir}/tmp/passthru_$uid";

    # passthrough file is only written to once, so if it already exists,
    # suspect a security hack (O_EXCL)
    sysopen( F, "$passthruFilename", O_RDWR | O_EXCL | O_CREAT, 0600 )
      || die 'Unable to open '.$Foswiki::cfg{WorkingDir}
        .'/tmp for write; check the setting of {WorkingDir} in configure,'
          .' and check file permissions: '.$!;
    $query->save( \*F );
    close(F);

    if ($Foswiki::cfg{UsePathForRedirectCache}) {
        return '/foswiki_redirect_cache/' . $uid;
    } else {
        return '?foswiki_redirect_cache=' . $uid;
    }
}

=begin TML

---++ ObjectMethod getCGISession() -> $cgisession

Get the CGI::Session object associated with this session, if there is
one. May return undef.

=cut

sub getCGISession {
    my $this = shift;
    return $this->{users}->{loginManager}->{_cgisession};
}

=begin TML

---++ StaticMethod isValidWikiWord( $name ) -> $boolean

Check for a valid WikiWord or WikiName

=cut

sub isValidWikiWord {
    my $name = shift || '';
    return ( $name =~ m/^$regex{wikiWordRegex}$/o );
}

=begin TML

---++ StaticMethod isValidTopicName( $name [, $nonww] ) -> $boolean

Check for a valid topic =$name=. If =$nonww=, then accept non wiki-words
(though they must still be composed of only valid, unfiltered characters)

=cut

# Note: must work on tainted names.
sub isValidTopicName {
    my ( $name, $nonww ) = @_;

    return 0 unless defined $name && $name ne '';
    return 1 if ( $name =~ m/^$regex{topicNameRegex}$/o );
    return 0 unless $nonww;
    return 0 if $name =~ /$Foswiki::cfg{NameFilter}/;
    return 1;
}

=begin TML

---++ StaticMethod isValidWebName( $name, $system ) -> $boolean

STATIC Check for a valid web name. If $system is true, then
system web names are considered valid (names starting with _)
otherwise only user web names are valid

If $Foswiki::cfg{EnableHierarchicalWebs} is off, it will also return false
when a nested web name is passed to it.

=cut

# Note: must work on tainted names.
sub isValidWebName {
    my $name = shift || '';
    my $sys = shift;
    return 1 if ( $sys && $name =~ m/^$regex{defaultWebNameRegex}$/o );
    return ( $name =~ m/^$regex{webNameRegex}$/o );
}

=begin TML

---++ StaticMethod isValidEmailAddress( $name ) -> $boolean

STATIC Check for a valid email address name.

=cut

# Note: must work on tainted names.
sub isValidEmailAddress {
    my ($name) = @_;
    return $name =~ /^$regex{emailAddrRegex}$/;
}

=begin TML

---++ ObjectMethod getSkin () -> $string

Get the currently requested skin path

=cut

sub getSkin {
    my $this = shift;

    my $skinpath = $this->{prefs}->getPreferencesValue('SKIN') || '';

    if ( $this->{request} ) {
        my $resurface = $this->{request}->param('skin');
        $skinpath = $resurface if $resurface;
    }

    my $epidermis = $this->{prefs}->getPreferencesValue('COVER');
    $skinpath = $epidermis . ',' . $skinpath if $epidermis;

    if ( $this->{request} ) {
        $epidermis = $this->{request}->param('cover');
        $skinpath = $epidermis . ',' . $skinpath if $epidermis;
    }

    return $skinpath;
}

=begin TML

---++ ObjectMethod getScriptUrl( $absolute, $script, $web, $topic, ... ) -> $scriptURL

Returns the URL to a Foswiki script, providing the web and topic as
"path info" parameters.  The result looks something like this:
"http://host/foswiki/bin/$script/$web/$topic".
   * =...= - an arbitrary number of name,value parameter pairs that will be url-encoded and added to the url. The special parameter name '#' is reserved for specifying an anchor. e.g. <tt>getScriptUrl('x','y','view','#'=>'XXX',a=>1,b=>2)</tt> will give <tt>.../view/x/y?a=1&b=2#XXX</tt>

If $absolute is set, generates an absolute URL. $absolute is advisory only;
Foswiki can decide to generate absolute URLs (for example when run from the
command-line) even when relative URLs have been requested.

The default script url is taken from {ScriptUrlPath}, unless there is
an exception defined for the given script in {ScriptUrlPaths}. Both
{ScriptUrlPath} and {ScriptUrlPaths} may be absolute or relative URIs. If
they are absolute, then they will always generate absolute URLs. if they
are relative, then they will be converted to absolute when required (e.g.
when running from the command line, or when generating rss). If
$script is not given, absolute URLs will always be generated.

If either the web or the topic is defined, will generate a full url (including web and topic). Otherwise will generate only up to the script name. An undefined web will default to the main web name.

=cut

sub getScriptUrl {
    my ( $this, $absolute, $script, $web, $topic, @params ) = @_;

    $absolute ||=
      (      $this->inContext('command_line')
          || $this->inContext('rss')
          || $this->inContext('absolute_urls') );

    # SMELL: topics and webs that contain spaces?

    my $url;
    if ( defined $Foswiki::cfg{ScriptUrlPaths} && $script ) {
        $url = $Foswiki::cfg{ScriptUrlPaths}{$script};
    }
    unless ( defined($url) ) {
        $url = $Foswiki::cfg{ScriptUrlPath};
        if ($script) {
            $url .= '/' unless $url =~ /\/$/;
            $url .= $script;
            if (
                rindex( $url, $Foswiki::cfg{ScriptSuffix} ) !=
                ( length($url) - length( $Foswiki::cfg{ScriptSuffix} ) ) )
            {
                $url .= $Foswiki::cfg{ScriptSuffix} if $script;
            }
        }
    }

    if ( $absolute && $url !~ /^[a-z]+:/ ) {

        # See http://www.ietf.org/rfc/rfc2396.txt for the definition of
        # "absolute URI". Foswiki bastardises this definition by assuming
        # that all relative URLs lack the <authority> component as well.
        $url = $this->{urlHost} . $url;
    }

    if ( $web || $topic ) {
        ( $web, $topic ) = $this->normalizeWebTopicName( $web, $topic );

        $url .= urlEncode( '/' . $web . '/' . $topic );

        $url .= _make_params( 0, @params );
    }

    return $url;
}

sub _make_params {
    my ( $notfirst, @args ) = @_;
    my $url    = '';
    my $ps     = '';
    my $anchor = '';
    while ( my $p = shift @args ) {
        if ( $p eq '#' ) {
            $anchor .= '#' . urlEncode( shift(@args) );
        }
        else {
            $ps .= ';' . urlEncode($p) . '=' . urlEncode( shift(@args) || '' );
        }
    }
    if ($ps) {
        $ps =~ s/^;/?/ unless $notfirst;
        $url .= $ps;
    }
    $url .= $anchor;
    return $url;
}

=begin TML

---++ ObjectMethod getPubUrl($absolute, $web, $topic, $attachment) -> $url

Composes a pub url. If $absolute is set, returns an absolute URL.
If $absolute is set, generates an absolute URL. $absolute is advisory only;
Foswiki can decide to generate absolute URLs (for example when run from the
command-line) even when relative URLs have been requested.

$web, $topic and $attachment are optional. A partial URL path will be
generated if one or all is not given.

=cut

sub getPubUrl {
    my ( $this, $absolute, $web, $topic, $attachment ) = @_;

    $absolute ||=
      (      $this->inContext('command_line')
          || $this->inContext('rss')
          || $this->inContext('absolute_urls') );

    my $url = '';
    $url .= $Foswiki::cfg{PubUrlPath};
    if ( $absolute && $url !~ /^[a-z]+:/ ) {

        # See http://www.ietf.org/rfc/rfc2396.txt for the definition of
        # "absolute URI". Foswiki bastardises this definition by assuming
        # that all relative URLs lack the <authority> component as well.
        $url = $this->{urlHost} . $url;
    }
    if ( $web || $topic || $attachment ) {
        ( $web, $topic ) = $this->normalizeWebTopicName( $web, $topic );

        my $path = '/' . $web . '/' . $topic;
        if ($attachment) {
            $path .= '/' . $attachment;

            # Attachments are served directly by web server, need to handle
            # URL encoding specially
            $url .= urlEncodeAttachment($path);
        }
        else {
            $url .= urlEncode($path);
        }
    }

    return $url;
}

=begin TML

---++ ObjectMethod getIconUrl( $absolute, $iconName ) -> $iconURL

Map an icon name to a URL path.

=cut

sub getIconUrl {
    my ( $this, $absolute, $iconName ) = @_;

    my $iconTopic = $this->{prefs}->getPreferencesValue('ICONTOPIC');
    if ( defined($iconTopic) ) {
        $iconTopic =~ s/\s+$//;
        my ( $web, $topic ) =
          $this->normalizeWebTopicName( $this->{webName}, $iconTopic );
        $iconName =~ s/^.*\.(.*?)$/$1/;
        return $this->getPubUrl( $absolute, $web, $topic, $iconName . '.gif' );
    }
    else {
        return '';
    }
}

=begin TML

---++ ObjectMethod mapToIconFileName( $fileName, $default ) -> $fileName

Maps from a filename (or just the extension) to the name of the
file that contains the image for that file type.

=cut

sub mapToIconFileName {
    my ( $this, $fileName, $default ) = @_;

    my @bits = ( split( /\./, $fileName ) );
    my $fileExt = lc( $bits[$#bits] );

    unless ( $this->{_ICONMAP} ) {
        my $iconTopic = $this->{prefs}->getPreferencesValue('ICONTOPIC');
        if ( defined($iconTopic) ) {
            my ( $web, $topic ) =
              $this->normalizeWebTopicName( $this->{webName}, $iconTopic );
            local $/ = undef;
            try {
                my $icons =
                  $this->{store}->getAttachmentStream( undef, $web, $topic,
                    '_filetypes.txt' );
                %{ $this->{_ICONMAP} } = split( /\s+/, <$icons> );
                close($icons);
            }
            catch Error::Simple with {
                %{ $this->{_ICONMAP} } = ();
            };
        }
        else {
            return $default || $fileName;
        }
    }

    return $this->{_ICONMAP}->{$fileExt} || $default || 'else';
}

=begin TML

---++ ObjectMethod normalizeWebTopicName( $theWeb, $theTopic ) -> ( $theWeb, $theTopic )

Normalize a Web<nop>.<nop>TopicName

See =Foswiki::Func= for a full specification of the expansion (not duplicated
here)

*WARNING* if there is no web specification (in the web or topic parameters)
the web defaults to $Foswiki::cfg{UsersWebName}. If there is no topic
specification, or the topic is '0', the topic defaults to the web home topic
name.

*WARNING* if the input topic name is tainted, then the output web and
topic names will be tainted.

=cut

sub normalizeWebTopicName {
    my ( $this, $web, $topic ) = @_;

    ASSERT( defined $topic ) if DEBUG;

    if ( $topic =~ m|^(.*)[./](.*?)$| ) {
        $web   = $1;
        $topic = $2;

        if ( DEBUG && !UNTAINTED( $_[2] ) ) {

            # retaint data untainted by RE above
            $web   = TAINT($web);
            $topic = TAINT($topic);
        }
    }
    $web   ||= $cfg{UsersWebName};
    $topic ||= $cfg{HomeTopicName};

    # MAINWEB and TWIKIWEB expanded for compatibility reasons
    while (
        $web =~ s/%((MAIN|TWIKI|USERS|SYSTEM|DOC)WEB)%/
              $this->_expandTagOnTopicRendering( $1 ) || ''/e
      )
    {
    }

    # Normalize web name to use / and not . as a subweb separator
    $web =~ s#\.#/#g;

    return ( $web, $topic );
}

=begin TML

---++ ClassMethod new( $loginName, $query, \%initialContext )

Constructs a new Foswiki object. Parameters are taken from the query object.

   * =$loginName= is the login username (*not* the wikiname) of the user you
     want to be logged-in if none is available from a session or browser.
     Used mainly for side scripts and debugging.
   * =$query= the Foswiki::Request query (may be undef, in which case an empty query
     is used)
   * =\%initialContext= - reference to a hash containing context
     name=value pairs to be pre-installed in the context hash

=cut

sub new {
    my ( $class, $login, $query, $initialContext ) = @_;
    ASSERT( !$query || UNIVERSAL::isa( $query, 'Foswiki::Request' ) );
    Monitor::MARK("Static compilation complete");

    # Compatibility; not used except maybe in plugins
    $Foswiki::cfg{TempfileDir} = "$Foswiki::cfg{WorkingDir}/tmp"
      unless defined( $Foswiki::cfg{TempfileDir} );

    # Set command_line context if there is no query
    $initialContext ||= defined($query) ? {} : { command_line => 1 };

    $query ||= new Foswiki::Request();
    my $this = bless( { sandbox => 'Foswiki::Sandbox' }, $class );

    $this->{request}  = $query;
    $this->{cgiQuery} = $query;    # for backwards compatibility in contribs
    $this->{response} = new Foswiki::Response();
    $this->{digester} = new Digest::MD5();

    # Tell Foswiki::Response which charset we are using if not default
    if ( defined $Foswiki::cfg{Site}{CharSet}
        && $Foswiki::cfg{Site}{CharSet} !~ /^iso-?8859-?1$/io )
    {
        $this->{response}->charset( $Foswiki::cfg{Site}{CharSet} );
    }

    $this->{_HTMLHEADERS} = {};
    $this->{context}      = $initialContext;

    require Foswiki::Plugins;
    $this->{plugins} = new Foswiki::Plugins($this);
    require Foswiki::Store;
    $this->{store} = new Foswiki::Store($this);

    # use login as a default (set when running from cmd line)
    $this->{remoteUser} = $login;

    require Foswiki::Users;
    $this->{users}      = new Foswiki::Users($this);
    $this->{remoteUser} = $this->{users}->{remoteUser};

    # Make %ENV safer, preventing hijack of the search path. The
    # environment is set per-query, so this can't be done in a BEGIN.
    # TWikibug:Item4382: Default $ENV{PATH} must be untainted because
    # Foswiki runs with use strict and calling external programs that
    # writes on the disk will fail unless Perl seens it as set to safe value.
    if ( $Foswiki::cfg{SafeEnvPath} ) {
        $ENV{PATH} = $Foswiki::cfg{SafeEnvPath};
    }
    else {

        # SMELL: how can we validate the PATH?
        $ENV{PATH} = Foswiki::Sandbox::untaintUnchecked( $ENV{PATH} );
    }
    delete @ENV{qw( IFS CDPATH ENV BASH_ENV )};

    my $url = $query->url();
    if ( $url && $url =~ m{^([^:]*://[^/]*).*$} ) {
        $this->{urlHost} = $1;

        # If the urlHost in the url is localhost, this is a lot less
        # useful than the default url host. This is because new CGI("")
        # assigns this host by default - it's a default setting, used
        # when there is nothing better available.
        if ( $this->{urlHost} eq 'http://localhost' ) {
            $this->{urlHost} = $Foswiki::cfg{DefaultUrlHost};
        }
        elsif ( $Foswiki::cfg{RemovePortNumber} ) {
            $this->{urlHost} =~ s/\:[0-9]+$//;
        }
    }
    else {
        $this->{urlHost} = $Foswiki::cfg{DefaultUrlHost};
    }
    if (   $Foswiki::cfg{GetScriptUrlFromCgi}
        && $url
        && $url =~ m{^[^:]*://[^/]*(.*)/.*$}
        && $1 )
    {

        # SMELL: this is a really dangerous hack. It will fail
        # spectacularly with mod_perl.
        # SMELL: why not just use $query->script_name?
        # SMELL: unchecked implicit untaint?
        $this->{scriptUrlPath} = $1;
    }

    my $web   = '';
    my $topic = $query->param('topic');
    if ($topic) {
        if (   $topic =~ m#^$regex{linkProtocolPattern}://#o
            && $this->{request} )
        {

            # redirect to URI
            $this->{webName} = '';
            $this->redirect($topic);
            return $this;
        }
        elsif ( $topic =~ m#^(.*)[./](.*?)$# ) {

            # is '?topic=Webname.SomeTopic'
            # implicit untaint OK - validated later
            $web   = $1;
            $topic = $2;
            $web =~ s/\./\//g;

            # jump to WebHome if 'bin/script?topic=Webname.'
            $topic = $Foswiki::cfg{HomeTopicName} if ( $web && !$topic );
        }

        # otherwise assume 'bin/script/Webname?topic=SomeTopic'
    }
    else {
        $topic = '';
    }

    my $pathInfo = $query->path_info();
    $pathInfo =~ s|//+|/|g;    # multiple //'s are illogical

    # Get the web and topic names from PATH_INFO
    if ( $pathInfo =~ m#^/(.*)[./](.*?)$# ) {

        # is '/Webname/SomeTopic' or '/Webname'
        # implicit untaint OK - validated later
        $web   = $1 unless $web;
        $topic = $2 unless $topic;
        $web =~ s/\./\//g;
    }
    elsif ( $pathInfo =~ m#^/(.*?)$# ) {

        # is 'bin/script/Webname' or 'bin/script/'
        # implicit untaint OK - validated later
        $web = $1 unless $web;
    }

    my $topicNameTemp = $this->UTF82SiteCharSet($topic);
    if ($topicNameTemp) {
        $topic = $topicNameTemp;
    }

    # TWikibug:Item3270 - here's the appropriate place to enforce spec
    $topic = ucfirst($topic);

    # Validate and untaint topic name from path info
    $this->{topicName} = Foswiki::Sandbox::untaint(
        $topic,
        sub {
            return $Foswiki::cfg{HomeTopicName}
              unless isValidTopicName( $topic, 1 );
            return $topic;
        }
    );

    # Validate web name from path info
    $this->{requestedWebName} = Foswiki::Sandbox::untaint(
        $web,
        sub {
            return '' unless $web &&    # can be an empty string
                  isValidWebName( $web, 1 );
            return $web;
        }
    );
    $this->{webName} = $this->{requestedWebName}
      || $Foswiki::cfg{UsersWebName};

    # Convert UTF-8 web and topic name from URL into site charset if
    # necessary
    # SMELL: merge these two cases, browsers just don't mix two encodings
    # in one URL - can also simplify into 2 lines by making function
    # return unprocessed text if no conversion
    my $webNameTemp = $this->UTF82SiteCharSet( $this->{webName} );
    if ($webNameTemp) {
        $this->{webName} = $webNameTemp;
    }

    $this->{scriptUrlPath} = $Foswiki::cfg{ScriptUrlPath};

    require Foswiki::Prefs;
    my $prefs = new Foswiki::Prefs($this);
    $this->{prefs} = $prefs;

    # Form definition cache
    $this->{forms} = {};

    # Push global preferences from %SYSTEMWEB%.DefaultPreferences
    $prefs->pushGlobalPreferences();

    # SMELL: what happens if we move this into the Foswiki::User::new?
    $this->{user} = $this->{users}->initialiseUser( $this->{remoteUser} );

    # Static session variables that can be expanded in topics when they
    # are enclosed in % signs
    # SMELL: should collapse these into one. The duplication is pretty
    # pointless. Could get rid of the SESSION_TAGS hash, might be
    # the easiest thing to do, but then that would allow other
    # upper-case named fields in the object to be accessed as well...
    $this->{SESSION_TAGS}{BASEWEB}        = $this->{webName};
    $this->{SESSION_TAGS}{BASETOPIC}      = $this->{topicName};
    $this->{SESSION_TAGS}{INCLUDINGTOPIC} = $this->{topicName};
    $this->{SESSION_TAGS}{INCLUDINGWEB}   = $this->{webName};

    # Push plugin settings
    $this->{plugins}->settings();

    # Now the rest of the preferences
    $prefs->pushGlobalPreferencesSiteSpecific();

    # User preferences only available if we can get to a valid wikiname,
    # which depends on the user mapper.
    my $wn = $this->{users}->getWikiName( $this->{user} );
    if ($wn) {
        $prefs->pushPreferences( $Foswiki::cfg{UsersWebName},
            $wn, 'USER ' . $wn );
    }

    $prefs->pushWebPreferences( $this->{webName} );

    $prefs->pushPreferences( $this->{webName}, $this->{topicName}, 'TOPIC' );

    $prefs->pushPreferenceValues( 'SESSION',
        $this->{users}->{loginManager}->getSessionValues() );

    # Finish plugin initialization - register handlers
    $this->{plugins}->enable();

 # SMELL: Every place should localize it before use, so it's not necessary here.
    $Foswiki::Plugins::SESSION = $this;

    Monitor::MARK("Foswiki session created");

    return $this;
}

=begin TML

---++ ObjectMethod renderer()
Get a reference to the renderer object. Done lazily because not everyone
needs the renderer.

=cut

sub renderer {
    my ($this) = @_;

    unless ( $this->{renderer} ) {
        require Foswiki::Render;

        # requires preferences (such as LINKTOOLTIPINFO)
        $this->{renderer} = new Foswiki::Render($this);
    }
    return $this->{renderer};
}

=begin TML

---++ ObjectMethod attach()
Get a reference to the attach object. Done lazily because not everyone
needs the attach.

=cut

sub attach {
    my ($this) = @_;

    unless ( $this->{attach} ) {
        require Foswiki::Attach;
        $this->{attach} = new Foswiki::Attach($this);
    }
    return $this->{attach};
}

=begin TML

---++ ObjectMethod templates()
Get a reference to the templates object. Done lazily because not everyone
needs the templates.

=cut

sub templates {
    my ($this) = @_;

    unless ( $this->{templates} ) {
        require Foswiki::Templates;
        $this->{templates} = new Foswiki::Templates($this);
    }
    return $this->{templates};
}

=begin TML

---++ ObjectMethod i18n()
Get a reference to the i18n object. Done lazily because not everyone
needs the i18ner.

=cut

sub i18n {
    my ($this) = @_;

    unless ( $this->{i18n} ) {
        require Foswiki::I18N;

        # language information; must be loaded after
        # *all possible preferences sources* are available
        $this->{i18n} = new Foswiki::I18N($this);
    }
    return $this->{i18n};
}

=begin TML

---++ ObjectMethod logger()

=cut

sub logger {
    my $this = shift;

    unless ( $this->{logger} ) {
        eval "require $Foswiki::cfg{Log}{Implementation}";
        die $@ if $@;
        $this->{logger} = $Foswiki::cfg{Log}{Implementation}->new();
    }
    return $this->{logger};
}

=begin TML

---++ ObjectMethod search()
Get a reference to the search object. Done lazily because not everyone
needs the searcher.

=cut

sub search {
    my ($this) = @_;

    unless ( $this->{search} ) {
        require Foswiki::Search;
        $this->{search} = new Foswiki::Search($this);
    }
    return $this->{search};
}

=begin TML

---++ ObjectMethod security()
Get a reference to the security object. Done lazily because not everyone
needs the security.

=cut

sub security {
    my ($this) = @_;

    unless ( $this->{security} ) {
        require Foswiki::Access;
        $this->{security} = new Foswiki::Access($this);
    }
    return $this->{security};
}

=begin TML

---++ ObjectMethod net()
Get a reference to the net object. Done lazily because not everyone
needs the net.

=cut

sub net {
    my ($this) = @_;

    unless ( $this->{net} ) {
        require Foswiki::Net;
        $this->{net} = new Foswiki::Net($this);
    }
    return $this->{net};
}

=begin TML

---++ ObjectMethod DESTROY()

called by Perl when the Foswiki object goes out of scope
(maybe should be used kist to ASSERT that finish() was called..

=cut

#sub DESTROY {
#    my $this = shift;
#    $this->finish();
#}

=begin TML

---++ ObjectMethod finish()
Break circular references.

=cut

# Note to developers; please undef *all* fields in the object explicitly,
# whether they are references or not. That way this method is "golden
# documentation" of the live fields in the object.
sub finish {
    my $this = shift;

    $_->finish() foreach values %{ $this->{forms} };
    $this->{plugins}->finish()   if $this->{plugins};
    undef $this->{plugins};
    $this->{users}->finish()     if $this->{users};
    undef $this->{users};
    $this->{prefs}->finish()     if $this->{prefs};
    undef $this->{prefs};
    $this->{templates}->finish() if $this->{templates};
    undef $this->{templates};
    $this->{renderer}->finish()  if $this->{renderer};
    undef $this->{renderer};
    $this->{net}->finish()       if $this->{net};
    undef $this->{net};
    $this->{store}->finish()     if $this->{store};
    undef $this->{store};
    $this->{search}->finish()    if $this->{search};
    undef $this->{search};
    $this->{attach}->finish()    if $this->{attach};
    undef $this->{attach};
    $this->{security}->finish()  if $this->{security};
    undef $this->{security};
    $this->{i18n}->finish()      if $this->{i18n};
    undef $this->{i18n};
#TODO: the logger doesn't seem to have a finish...
#    $this->{logger}->finish()      if $this->{logger};
    undef $this->{logger};
    
    undef $this->{_HTMLHEADERS};
    undef $this->{request};
    undef $this->{digester};
    undef $this->{urlHost};
    undef $this->{web};
    undef $this->{topic};
    undef $this->{webName};
    undef $this->{topicName};
    undef $this->{_ICONMAP};
    undef $this->{context};
    undef $this->{remoteUser};
    undef $this->{requestedWebName};    # Web name before renaming
    undef $this->{scriptUrlPath};
    undef $this->{user};
    undef $this->{SESSION_TAGS};
    undef $this->{_INCLUDES};
    undef $this->{response};
    undef $this->{evaluating_if};
    undef $this->{_addedToHEAD};
}

=begin TML

---++ ObjectMethod logEvent( $action, $webTopic, $extra, $user )
   * =$action= - what happened, e.g. view, save, rename
   * =$webTopic= - what it happened to
   * =$extra= - extra info, such as minor flag
   * =$user= - login name of user - default current user,
     or failing that the user agent

Write the log for an event to the logfile

=cut

sub logEvent {
    my $this = shift;

    my $action   = shift || '';
    my $webTopic = shift || '';
    my $extra    = shift || '';
    my $user     = shift;

    $user ||= $this->{user};
    $user = ( $this->{users}->getLoginName($user) || 'unknown' )
      if ( $this->{users} );

    if ( $user eq $cfg{DefaultUserLogin} ) {
        my $cgiQuery = $this->{request};
        if ($cgiQuery) {
            my $agent = $cgiQuery->user_agent();
            if ($agent) {
                if ( $agent =~ m/([\w]+)/ ) {
                    $extra .= ' ' . $1;
                }
            }
        }
    }

    my $remoteAddr = $this->{request}->remoteAddress() || '';

    $this->logger->log( 'info', $user, $action, $webTopic, $extra,
        $remoteAddr );
}

# Add a web reference to a [[...][...]] link in an included topic
sub _fixIncludeLink {
    my ( $web, $link, $label ) = @_;

    # Detect absolute and relative URLs and web-qualified wikinames
    if ( $link =~
m#^($regex{webNameRegex}\.|$regex{defaultWebNameRegex}\.|$regex{linkProtocolPattern}:|/)#o
      )
    {
        if ($label) {
            return "[[$link][$label]]";
        }
        else {
            return "[[$link]]";
        }
    }
    elsif ( !$label ) {

        # Must be wikiword or spaced-out wikiword (or illegal link :-/)
        $label = $link;
    }

    # If link is only an anchor, leave it as is (Foswikitask:Item771)
    return "[[$link][$label]]" if $link =~ /^#/;
    return "[[$web.$link][$label]]";
}

# Replace web references in a topic. Called from forEachLine, applying to
# each non-verbatim and non-literal line.
sub _fixupIncludedTopic {
    my ( $text, $options ) = @_;

    my $fromWeb = $options->{web};

    unless ( $options->{in_noautolink} ) {

        # 'TopicName' to 'Web.TopicName'
        $text =~
          s#(?:^|(?<=[\s(]))($regex{wikiWordRegex})(?=\s|\)|$)#$fromWeb.$1#go;
    }

    # Handle explicit [[]] everywhere
    # '[[TopicName][...]]' to '[[Web.TopicName][...]]'
    $text =~ s/\[\[([^]]+)\](?:\[([^]]+)\])?\]/
      _fixIncludeLink( $fromWeb, $1, $2 )/geo;

    return $text;
}

=begin TML

---++ StaticMethod validatePattern( $pattern ) -> $pattern

Validate a pattern provided in a parameter to $pattern so that
dangerous chars (interpolation and execution) are disabled.

=cut

sub validatePattern {
    my $pattern = shift;

    # Escape unescaped $ and @ characters that might interpolate
    # an internal variable.
    # There is no need to defuse (??{ and (?{ as perl won't allow
    # it anyway, unless one uses re 'eval' which we won't do
    $pattern =~ s/(^|[^\\])([\$\@])/$1\\$2/g;
    return $pattern;
}

=begin TML

---++ StaticMethod applyPatternToIncludedText( $text, $pattern ) -> $text

Apply a pattern on included text to extract a subset

=cut

sub applyPatternToIncludedText {
    my ( $text, $pattern ) = @_;

    $pattern = Foswiki::Sandbox::untaint( $pattern, \&validatePattern );

    try {
        $text =~ s/$pattern/$1/is;
    }
    catch Error::Simple with {
        $text = '';
    };
    return $text;
}

#
# SMELL: this is _not_ a tag handler in the sense of other builtin tags,
# because it requires far more context information (the text of the topic)
# than any handler.
# SMELL: as a tag handler that also semi-renders the topic to extract the
# headings, this handler would be much better as a preRenderingHandler in
# a plugin (where head, script and verbatim sections are already protected)
#
#    * $text  : ref to the text of the current topic
#    * $topic : the topic we are in
#    * $web   : the web we are in
#    * $args  : 'Topic' [web='Web'] [depth='N']
# Return value: $tableOfContents
# Handles %<nop>TOC{...}% syntax.  Creates a table of contents
# using Foswiki bulleted
# list markup, linked to the section headings of a topic. A section heading is
# entered in one of the following forms:
#    * $headingPatternSp : \t++... spaces section heading
#    * $headingPatternDa : ---++... dashes section heading
#    * $headingPatternHt : &lt;h[1-6]> HTML section heading &lt;/h[1-6]>
sub _TOC {
    my ( $this, $text, $defaultTopic, $defaultWeb, $args ) = @_;

    require Foswiki::Attrs;

    my $params = new Foswiki::Attrs($args);

    # get the topic name attribute
    my $topic = $params->{_DEFAULT} || $defaultTopic;

    # get the web name attribute
    $defaultWeb =~ s#/#.#g;
    my $web = $params->{web} || $defaultWeb;

    my $isSameTopic = $web eq $defaultWeb && $topic eq $defaultTopic;

    $web =~ s#/#\.#g;
    my $webPath = $web;
    $webPath =~ s/\./\//g;

    # get the depth limit attribute
    my $maxDepth =
         $params->{depth}
      || $this->{prefs}->getPreferencesValue('TOC_MAX_DEPTH')
      || 6;
    my $minDepth = $this->{prefs}->getPreferencesValue('TOC_MIN_DEPTH') || 1;

    # get the title attribute
    my $title =
         $params->{title}
      || $this->{prefs}->getPreferencesValue('TOC_TITLE')
      || '';
    $title = CGI::span( { class => 'foswikiTocTitle' }, $title ) if ($title);

    if ( $web ne $defaultWeb || $topic ne $defaultTopic ) {
        unless (
            $this->security->checkAccessPermission(
                'VIEW', $this->{user}, undef, undef, $topic, $web
            )
          )
        {
            return $this->inlineAlert( 'alerts', 'access_denied', $web,
                $topic );
        }
        my $meta;
        ( $meta, $text ) =
          $this->{store}->readTopic( $this->{user}, $web, $topic );
    }

    my $insidePre      = 0;
    my $insideVerbatim = 0;
    my $highest        = 99;
    my $result         = '';
    my $verbatim       = {};
    $text = $this->renderer->takeOutBlocks( $text, 'verbatim', $verbatim );
    $text = $this->renderer->takeOutBlocks( $text, 'pre',      $verbatim );

    # Find URL parameters
    my $query   = $this->{request};
    my @qparams = ();
    foreach my $name ( $query->param ) {
        next if ( $name eq 'keywords' );
        next if ( $name eq 'topic' );
        next if ( $name eq 'text' );
        push @qparams, $name => $query->param($name);
    }

   # clear the set of unique anchornames in order to inhibit the 'relabeling' of
   # anchor names if the same topic is processed more than once, cf. explanation
   # in handleCommonTags()
    $this->renderer->_eraseAnchorNameMemory();

    # NB: While we're processing $text line by line here,
    # $this->renderer->getRendereredVersion() 'allocates' unique anchor names by
    # first replacing '#WikiWord', followed by regex{headerPatternHt} and
    # regex{headerPatternDa}. In order to stay in sync and not 'clutter'/slow
    # down the renderer code, we have to adhere to this order here as well
    my @regexps = (
        '^(\#)(' . $regex{wikiWordRegex} . ')',
        $regex{headerPatternHt}, $regex{headerPatternDa}
    );
    my @lines    = split( /\r?\n/, $text );
    my %anchors  = ();
    my %headings = ();
    my %levels   = ();
    for my $i ( 0 .. $#regexps ) {
        my $lineno = 0;

        # SMELL: use forEachLine
        foreach my $line (@lines) {
            $lineno++;
            if ( $line =~ m/$regexps[$i]/ ) {
                my ( $level, $heading ) = ( $1, $2 );
                my $anchor =
                  $this->renderer->makeUniqueAnchorName( $web, $topic,
                    $heading );

                if ( $i > 0 ) {

                 # SMELL: needed only because Render::_makeAnchorHeading uses it
                    my $compatAnchor =
                      $this->renderer->makeAnchorName( $anchor, 1 );
                    $compatAnchor =
                      $this->renderer->makeUniqueAnchorName( $web, $topic,
                        $anchor, 1 )
                      if ( $compatAnchor ne $anchor );

                    $heading =~ s/\s*$regex{headerPatternNoTOC}.+$//go;
                    next unless $heading;

                    $level = length $level if ( $i == 2 );
                    if ( ( $level >= $minDepth ) && ( $level <= $maxDepth ) ) {
                        $anchors{$lineno}  = $anchor;
                        $headings{$lineno} = $heading;
                        $levels{$lineno}   = $level;
                    }
                }
            }
        }
    }

    # SMELL: this handling of <pre> is archaic.
    foreach my $lineno ( sort { $a <=> $b } ( keys %headings ) ) {
        my ( $level, $line, $anchor ) =
          ( $levels{$lineno}, $headings{$lineno}, $anchors{$lineno} );
        $highest = $level if ( $level < $highest );
        my $tabs = "\t" x $level;

        # Remove *bold*, _italic_ and =fixed= formatting
        $line =~
s/(^|[\s\(])\*([^\s]+?|[^\s].*?[^\s])\*($|[\s\,\.\;\:\!\?\)])/$1$2$3/g;
        $line =~
s/(^|[\s\(])_+([^\s]+?|[^\s].*?[^\s])_+($|[\s\,\.\;\:\!\?\)])/$1$2$3/g;
        $line =~
s/(^|[\s\(])=+([^\s]+?|[^\s].*?[^\s])=+($|[\s\,\.\;\:\!\?\)])/$1$2$3/g;

        # Prevent WikiLinks
        $line =~ s/\[\[.*?\]\[(.*?)\]\]/$1/g;    # '[[...][...]]'
        $line =~ s/\[\[(.*?)\]\]/$1/ge;          # '[[...]]'
        $line =~
          s/([\s\(])($regex{webNameRegex})\.($regex{wikiWordRegex})/$1<nop>$3/go
          ;                                      # 'Web.TopicName'
        $line =~ s/([\s\(])($regex{wikiWordRegex})/$1<nop>$2/go;   # 'TopicName'
        $line =~ s/([\s\(])($regex{abbrevRegex})/$1<nop>$2/go;     # 'TLA'
        $line =~ s/([\s\-\*\(])([$regex{mixedAlphaNum}]+\:)/$1<nop>$2/go
          ;    # 'Site:page' Interwiki link
               # Prevent manual links
        $line =~ s/<[\/]?a\b[^>]*>//gi;

        # create linked bullet item, using a relative link to anchor
        my $target =
          $isSameTopic
          ? _make_params( 0, '#' => $anchor, @qparams )
          : $this->getScriptUrl(
            0, 'view', $web, $topic,
            '#' => $anchor,
            @qparams
          );
        $line = $tabs . '* ' . CGI::a( { href => $target }, $line );
        $result .= "\n" . $line;
    }

    if ($result) {
        if ( $highest > 1 ) {

            # left shift TOC
            $highest--;
            $result =~ s/^\t{$highest}//gm;
        }

        # add a anchor to be able to jump to the toc and add a outer div
        return CGI::a( { name => 'foswikiTOC' }, '' )
          . CGI::div( { class => 'foswikiToc' }, "$title$result\n" );

    }
    else {
        return '';
    }
}

=begin TML

---++ ObjectMethod inlineAlert($template, $def, ... ) -> $string

Format an error for inline inclusion in rendered output. The message string
is obtained from the template 'oops'.$template, and the DEF $def is
selected. The parameters (...) are used to populate %PARAM1%..%PARAMn%

=cut

sub inlineAlert {
    my $this     = shift;
    my $template = shift;
    my $def      = shift;

    my $text =
      $this->templates->readTemplate( 'oops' . $template, $this->getSkin() );
    if ($text) {
        my $blah = $this->templates->expandTemplate($def);
        $text =~ s/%INSTANTIATE%/$blah/;

        # web and topic can be anything; they are not used
        $text =
          $this->handleCommonTags( $text, $this->{webName},
            $this->{topicName} );
        my $n = 1;
        while ( defined( my $param = shift ) ) {
            $text =~ s/%PARAM$n%/$param/g;
            $n++;
        }

        # Suppress missing params
        $text =~ s/%PARAM\d+%//g;

        # Suppress missing params
        $text =~ s/%PARAM\d+%//g;
    }
    else {
        $text =
            CGI::h1('Foswiki Installation Error')
          . 'Template "'
          . $template
          . '" not found.'
          . CGI::p()
          . 'Check your configuration settings for {TemplateDir} and {TemplatePath}';
    }

    return $text;
}

=begin TML

---++ StaticMethod parseSections($text) -> ($string,$sectionlistref)

Generic parser for sections within a topic. Sections are delimited
by STARTSECTION and ENDSECTION, which may be nested, overlapped or
otherwise abused. The parser builds an array of sections, which is
ordered by the order of the STARTSECTION within the topic. It also
removes all the SECTION tags from the text, and returns the text
and the array of sections.

Each section is a =Foswiki::Attrs= object, which contains the attributes
{type, name, start, end}
where start and end are character offsets in the
string *after all section tags have been removed*. All sections
are required to be uniquely named; if a section is unnamed, it
will be given a generated name. Sections may overlap or nest.

See test/unit/Fn_SECTION.pm for detailed testcases that
round out the spec.

=cut

sub parseSections {

    #my( $text _ = @_;
    my %sections;
    my @list = ();

    my $seq    = 0;
    my $ntext  = '';
    my $offset = 0;
    foreach my $bit ( split( /(%(?:START|END)SECTION(?:{.*?})?%)/, $_[0] ) ) {
        if ( $bit =~ /^%STARTSECTION(?:{(.*)})?%$/ ) {
            require Foswiki::Attrs;

            # SMELL: unchecked implicit untaint?
            my $attrs = new Foswiki::Attrs($1);
            $attrs->{type} ||= 'section';
            $attrs->{name} =
                 $attrs->{_DEFAULT}
              || $attrs->{name}
              || '_SECTION' . $seq++;
            delete $attrs->{_DEFAULT};
            my $id = $attrs->{type} . ':' . $attrs->{name};
            if ( $sections{$id} ) {

                # error, this named section already defined, ignore
                next;
            }

            # close open unnamed sections of the same type
            foreach my $s (@list) {
                if (   $s->{end} < 0
                    && $s->{type} eq $attrs->{type}
                    && $s->{name} =~ /^_SECTION\d+$/ )
                {
                    $s->{end} = $offset;
                }
            }
            $attrs->{start} = $offset;
            $attrs->{end}   = -1;        # open section
            $sections{$id}  = $attrs;
            push( @list, $attrs );
        }
        elsif ( $bit =~ /^%ENDSECTION(?:{(.*)})?%$/ ) {
            require Foswiki::Attrs;

            # SMELL: unchecked implicit untaint?
            my $attrs = new Foswiki::Attrs($1);
            $attrs->{type} ||= 'section';
            $attrs->{name} = $attrs->{_DEFAULT} || $attrs->{name} || '';
            delete $attrs->{_DEFAULT};
            unless ( $attrs->{name} ) {

                # find the last open unnamed section of this type
                foreach my $s ( reverse @list ) {
                    if (   $s->{end} == -1
                        && $s->{type} eq $attrs->{type}
                        && $s->{name} =~ /^_SECTION\d+$/ )
                    {
                        $attrs->{name} = $s->{name};
                        last;
                    }
                }

                # ignore it if no matching START found
                next unless $attrs->{name};
            }
            my $id = $attrs->{type} . ':' . $attrs->{name};
            if ( !$sections{$id} || $sections{$id}->{end} >= 0 ) {

                # error, no such open section, ignore
                next;
            }
            $sections{$id}->{end} = $offset;
        }
        else {
            $ntext .= $bit;
            $offset = length($ntext);
        }
    }

    # close open sections
    foreach my $s (@list) {
        $s->{end} = $offset if $s->{end} < 0;
    }

    return ( $ntext, \@list );
}

=begin TML

---++ ObjectMethod expandVariablesOnTopicCreation ( $text, $user, $web, $topic ) -> $text

   * =$text= - text to expand
   * =$user= - This is the user expanded in e.g. %USERNAME. Optional, defaults to logged-in user.
Expand limited set of variables during topic creation. These are variables
expected in templates that must be statically expanded in new content.
   * =$web= - name of web
   * =$topic= - name of topic

# SMELL: no plugin handler

=cut

sub expandVariablesOnTopicCreation {
    my ( $this, $text, $user, $theWeb, $theTopic ) = @_;

    $user ||= $this->{user};

    # Chop out templateonly sections
    my ( $ntext, $sections ) = parseSections($text);
    if ( scalar(@$sections) ) {

 # Note that if named templateonly sections overlap, the behaviour is undefined.
        foreach my $s ( reverse @$sections ) {
            if ( $s->{type} eq 'templateonly' ) {
                $ntext =
                    substr( $ntext, 0, $s->{start} )
                  . substr( $ntext, $s->{end}, length($ntext) );
            }
            else {

                # put back non-templateonly sections
                my $start = $s->remove('start');
                my $end   = $s->remove('end');
                $ntext =
                    substr( $ntext, 0, $start )
                  . '%STARTSECTION{'
                  . $s->stringify() . '}%'
                  . substr( $ntext, $start, $end - $start )
                  . '%ENDSECTION{'
                  . $s->stringify() . '}%'
                  . substr( $ntext, $end, length($ntext) );
            }
        }
        $text = $ntext;
    }

    # Make sure func works, for registered tag handlers
    $Foswiki::Plugins::SESSION = $this;

    # Note: it may look dangerous to override the user this way, but
    # it's actually quite safe, because only a subset of tags are
    # expanded during topic creation. if the set of tags expanded is
    # extended, then the impact has to be considered.
    my $safe = $this->{user};
    $this->{user} = $user;
    $text = _processTags( $this, $text, \&_expandTagOnTopicCreation, 16 );

    # expand all variables for type="expandvariables" sections
    ( $ntext, $sections ) = parseSections($text);
    if ( scalar(@$sections) ) {
        $theWeb   ||= $this->{session}->{webName};
        $theTopic ||= $this->{session}->{topicName};
        foreach my $s ( reverse @$sections ) {
            if ( $s->{type} eq 'expandvariables' ) {
                my $etext =
                  substr( $ntext, $s->{start}, $s->{end} - $s->{start} );
                expandAllTags( $this, \$etext, $theTopic, $theWeb );
                $ntext =
                    substr( $ntext, 0, $s->{start} ) 
                  . $etext
                  . substr( $ntext, $s->{end}, length($ntext) );
            }
            else {

                # put back non-expandvariables sections
                my $start = $s->remove('start');
                my $end   = $s->remove('end');
                $ntext =
                    substr( $ntext, 0, $start )
                  . '%STARTSECTION{'
                  . $s->stringify() . '}%'
                  . substr( $ntext, $start, $end - $start )
                  . '%ENDSECTION{'
                  . $s->stringify() . '}%'
                  . substr( $ntext, $end, length($ntext) );
            }
        }
        $text = $ntext;
    }

    # kill markers used to prevent variable expansion
    $text =~ s/%NOP%//g;
    $this->{user} = $safe;
    return $text;
}

=begin TML

---++ StaticMethod entityEncode( $text, $extras ) -> $encodedText

Escape special characters to HTML numeric entities. This is *not* a generic
encoding, it is tuned specifically for use in Foswiki.

HTML4.0 spec:
"Certain characters in HTML are reserved for use as markup and must be
escaped to appear literally. The "&lt;" character may be represented with
an <em>entity</em>, <strong class=html>&amp;lt;</strong>. Similarly, "&gt;"
is escaped as <strong class=html>&amp;gt;</strong>, and "&amp;" is escaped
as <strong class=html>&amp;amp;</strong>. If an attribute value contains a
double quotation mark and is delimited by double quotation marks, then the
quote should be escaped as <strong class=html>&amp;quot;</strong>.</p>

Other entities exist for special characters that cannot easily be entered
with some keyboards..."

This method encodes HTML special and any non-printable ascii
characters (except for \n and \r) using numeric entities.

FURTHER this method also encodes characters that are special in Foswiki
meta-language.

$extras is an optional param that may be used to include *additional*
characters in the set of encoded characters. It should be a string
containing the additional chars.

=cut

sub entityEncode {
    my ( $text, $extra ) = @_;
    $extra ||= '';

    # encode all non-printable 7-bit chars (< \x1f),
    # except \n (\xa) and \r (\xd)
    # encode HTML special characters '>', '<', '&', ''' and '"'.
    # encode TML special characters '%', '|', '[', ']', '@', '_',
    # '*', and '='
    $text =~
      s/([[\x01-\x09\x0b\x0c\x0e-\x1f"%&'*<=>@[_\|$extra])/'&#'.ord($1).';'/ge;
    return $text;
}

=begin TML

---++ StaticMethod entityDecode ( $encodedText ) -> $text

Decodes all numeric entities (e.g. &amp;#123;). _Does not_ decode
named entities such as &amp;amp; (use HTML::Entities for that)

=cut

sub entityDecode {
    my $text = shift;

    $text =~ s/&#(\d+);/chr($1)/ge;
    return $text;
}

=begin TML

---++ StaticMethod urlEncodeAttachment ( $text )

For attachments, URL-encode specially to 'freeze' any characters >127 in the
site charset (e.g. ISO-8859-1 or KOI8-R), by doing URL encoding into native
charset ($siteCharset) - used when generating attachment URLs, to enable the
web server to serve attachments, including images, directly.

This encoding is required to handle the cases of:

    - browsers that generate UTF-8 URLs automatically from site charset URLs - now quite common
    - web servers that directly serve attachments, using the site charset for
      filenames, and cannot convert UTF-8 URLs into site charset filenames

The aim is to prevent the browser from converting a site charset URL in the web
page to a UTF-8 URL, which is the default.  Hence we 'freeze' the URL into the
site character set through URL encoding.

In two cases, no URL encoding is needed:  For EBCDIC mainframes, we assume that
site charset URLs will be translated (outbound and inbound) by the web server to/from an
EBCDIC character set. For sites running in UTF-8, there's no need for Foswiki to
do anything since all URLs and attachment filenames are already in UTF-8.

=cut

sub urlEncodeAttachment {
    my ($text) = @_;

    my $usingEBCDIC = ( 'A' eq chr(193) );    # Only true on EBCDIC mainframes

    if (
        (
            defined( $Foswiki::cfg{Site}{CharSet} )
            and $Foswiki::cfg{Site}{CharSet} =~ /^utf-?8$/i
        )
        or $usingEBCDIC
      )
    {

        # Just let browser do UTF-8 URL encoding
        return $text;
    }

    # Freeze into site charset through URL encoding
    return urlEncode($text);
}

=begin TML

---++ StaticMethod urlEncode( $string ) -> encoded string

Encode by converting characters that are illegal in URLs to
their %NN equivalents. This method is used for encoding
strings that must be embedded _verbatim_ in URLs; it cannot
be applied to URLs themselves, as it escapes reserved
characters such as = and ?.

RFC 1738, Dec. '94:
    <verbatim>
    ...Only alphanumerics [0-9a-zA-Z], the special
    characters $-_.+!*'(), and reserved characters used for their
    reserved purposes may be used unencoded within a URL.
    </verbatim>

Reserved characters are $&+,/:;=?@ - these are _also_ encoded by
this method.

This URL-encoding handles all character encodings including ISO-8859-*,
KOI8-R, EUC-* and UTF-8.

This may not handle EBCDIC properly, as it generates an EBCDIC URL-encoded
URL, but mainframe web servers seem to translate this outbound before it hits browser
- see CGI::Util::escape for another approach.

=cut

sub urlEncode {
    my $text = shift;

    $text =~ s/([^0-9a-zA-Z-_.:~!*'\/])/'%'.sprintf('%02x',ord($1))/ge;

    return $text;
}

=begin TML

---++ StaticMethod urlDecode( $string ) -> decoded string

Reverses the encoding done in urlEncode.

=cut

sub urlDecode {
    my $text = shift;

    $text =~ s/%([\da-f]{2})/chr(hex($1))/gei;

    return $text;
}

=begin TML

---++ StaticMethod isTrue( $value, $default ) -> $boolean

Returns 1 if =$value= is true, and 0 otherwise. "true" means set to
something with a Perl true value, with the special cases that "off",
"false" and "no" (case insensitive) are forced to false. Leading and
trailing spaces in =$value= are ignored.

If the value is undef, then =$default= is returned. If =$default= is
not specified it is taken as 0.

=cut

sub isTrue {
    my ( $value, $default ) = @_;

    $default ||= 0;

    return $default unless defined($value);

    $value =~ s/^\s*(.*?)\s*$/$1/gi;
    $value =~ s/off//gi;
    $value =~ s/no//gi;
    $value =~ s/false//gi;
    return ($value) ? 1 : 0;
}

=begin TML

---++ StaticMethod spaceOutWikiWord( $word, $sep ) -> $string

Spaces out a wiki word by inserting a string (default: one space) between each word component.
With parameter $sep any string may be used as separator between the word components; if $sep is undefined it defaults to a space.

=cut

sub spaceOutWikiWord {
    my ( $word, $sep ) = @_;

    # Both could have the value 0 so we cannot use simple = || ''
    $word = defined($word) ? $word : '';
    $sep  = defined($sep)  ? $sep  : ' ';
    $word =~
s/([$regex{lowerAlpha}])([$regex{upperAlpha}$regex{numeric}]+)/$1$sep$2/go;
    $word =~ s/([$regex{numeric}])([$regex{upperAlpha}])/$1$sep$2/go;
    return $word;
}

=begin TML

---++ ObjectMethod expandAllTags(\$text, $topic, $web, $meta)
Expands variables by replacing the variables with their
values. Some example variables: %<nop>TOPIC%, %<nop>SCRIPTURL%,
%<nop>WIKINAME%, etc.
$web and $incs are passed in for recursive include expansion. They can
safely be undef.
The rules for tag expansion are:
   1 Tags are expanded left to right, in the order they are encountered.
   1 Tags are recursively expanded as soon as they are encountered -
     the algorithm is inherently single-pass
   1 A tag is not "encountered" until the matching }% has been seen, by
     which time all tags in parameters will have been expanded
   1 Tag expansions that create new tags recursively are limited to a
     set number of hierarchical levels of expansion

=cut

sub expandAllTags {
    my $this = shift;
    my $text = shift;    # reference
    my ( $topic, $web, $meta ) = @_;
    $web =~ s#\.#/#go;

    # push current context
    my $memTopic = $this->{SESSION_TAGS}{TOPIC};
    my $memWeb   = $this->{SESSION_TAGS}{WEB};

    $this->{SESSION_TAGS}{TOPIC} = $topic;
    $this->{SESSION_TAGS}{WEB}   = $web;

    # Escape ' !%VARIABLE%'
    $$text =~ s/(?<=\s)!%($regex{tagNameRegex})/&#37;$1/g;

    # Make sure func works, for registered tag handlers
    $Foswiki::Plugins::SESSION = $this;

    # NOTE TO DEBUGGERS
    # The depth parameter in the following call controls the maximum number
    # of levels of expansion. If it is set to 1 then only tags in the
    # topic will be expanded; tags that they in turn generate will be
    # left unexpanded. If it is set to 2 then the expansion will stop after
    # the first recursive inclusion, and so on. This is incredible useful
    # when debugging. The default is set to 16
    # to match the original limit on search expansion, though this of
    # course applies to _all_ tags and not just search.
    $$text =
      _processTags( $this, $$text, \&_expandTagOnTopicRendering, 16, @_ );

    # restore previous context
    $this->{SESSION_TAGS}{TOPIC} = $memTopic;
    $this->{SESSION_TAGS}{WEB}   = $memWeb;
}

# Process Foswiki %TAGS{}% by parsing the input tokenised into
# % separated sections. The parser is a simple stack-based parse,
# sufficient to ensure nesting of tags is correct, but no more
# than that.
# $depth limits the number of recursive expansion steps that
# can be performed on expanded tags.
sub _processTags {
    my $this = shift;
    my $text = shift;
    my $tagf = shift;
    my $tell = 0;

    return '' if ( ( !defined($text) )
        || ( $text eq '' ) );

    #no tags to process
    return $text unless ( $text =~ /(%)/ );

    my $depth = shift;

    unless ($depth) {
        my $mess = "Max recursive depth reached: $text";
        $this->logger->log( 'warning', $mess );

        # prevent recursive expansion that just has been detected
        # from happening in the error message
        $text =~ s/%(.*?)%/$1/go;
        return $text;
    }

    my $verbatim = {};
    $text = $this->renderer->takeOutBlocks( $text, 'verbatim', $verbatim );

    # See Item1442
    #my $percent = ($TranslationToken x 3).'%'.($TranslationToken x 3);

    my @queue = split( /(%)/, $text );
    my @stack;
    my $stackTop = '';    # the top stack entry. Done this way instead of
         # referring to the top of the stack for efficiency. This var
         # should be considered to be $stack[$#stack]

    while ( scalar(@queue) ) {
        my $token = shift(@queue);

        #print STDERR ' ' x $tell,"PROCESSING $token \n";

        # each % sign either closes an existing stacked context, or
        # opens a new context.
        if ( $token eq '%' ) {

            #print STDERR ' ' x $tell,"CONSIDER $stackTop\n";
            # If this is a closing }%, try to rejoin the previous
            # tokens until we get to a valid tag construct. This is
            # a bit of a hack, but it's hard to think of a better
            # way to do this without a full parse that takes % signs
            # in tag parameters into account.
            if ( $stackTop =~ /}$/s ) {
                while ( scalar(@stack)
                    && $stackTop !~ /^%($regex{tagNameRegex}){.*}$/so )
                {
                    my $top = $stackTop;

                    #print STDERR ' ' x $tell,"COLLAPSE $top \n";
                    $stackTop = pop(@stack) . $top;
                }
            }

            # /s so you can have newlines in parameters
            if ( $stackTop =~ m/^%(($regex{tagNameRegex})(?:{(.*)})?)$/so ) {

                # SMELL: unchecked implicit untaint?
                my ( $expr, $tag, $args ) = ( $1, $2, $3 );

                #print STDERR ' ' x $tell,"POP $tag\n";
                my $e = &$tagf( $this, $tag, $args, @_ );

                if ( defined($e) ) {

                    #print STDERR ' ' x $tell--,"EXPANDED $tag -> $e\n";
                    $stackTop = pop(@stack);
                    unless ( $e =~ /(%)/ ) {

#SMELL: this is a profiler speedup found by Sven on the last day of 4.2.1
#TODO: I don't think this parser should be in this section - re-analysis desired.
#print STDERR "no tags to recurse\n";
                        $stackTop .= $e;
                        next;
                    }

                    # Recursively expand tags in the expansion of $tag
                    $stackTop .=
                      _processTags( $this, $e, $tagf, $depth - 1, @_ );
                }
                else {    # expansion failed
                      #print STDERR ' ' x $tell++,"EXPAND $tag FAILED\n";
                      # To handle %NOP
                      # correctly, we have to handle the %VAR% case differently
                      # to the %VAR{}% case when a variable expansion fails.
                      # This is so that recursively define variables e.g.
                      # %A%B%D% expand correctly, but at the same time we ensure
                      # that a mismatched }% can't accidentally close a context
                      # that was left open when a tag expansion failed.
                      # However Cairo didn't do this, so for compatibility
                      # we have to accept that %NOP can never be fixed. if it
                      # could, then we could uncomment the following:

                    #if( $stackTop =~ /}$/ ) {
                    #    # %VAR{...}% case
                    #    # We need to push the unexpanded expression back
                    #    # onto the stack, but we don't want it to match the
                    #    # tag expression again. So we protect the %'s
                    #    $stackTop = $percent.$expr.$percent;
                    #} else
                    {

                        # %VAR% case.
                        # In this case we *do* want to match the tag expression
                        # again, as an embedded %VAR% may have expanded to
                        # create a valid outer expression. This is directly
                        # at odds with the %VAR{...}% case.
                        push( @stack, $stackTop );
                        $stackTop = '%';    # open new context
                    }
                }
            }
            else {
                push( @stack, $stackTop );
                $stackTop = '%';            # push a new context
                                            #$tell++;
            }
        }
        else {
            $stackTop .= $token;
        }
    }

    # Run out of input. Gather up everything in the stack.
    while ( scalar(@stack) ) {
        my $expr = $stackTop;
        $stackTop = pop(@stack);
        $stackTop .= $expr;
    }

    #$stackTop =~ s/$percent/%/go;

    $this->renderer->putBackBlocks( \$stackTop, $verbatim, 'verbatim' );

    #print STDERR "FINAL $stackTop\n";

    return $stackTop;
}

# Handle expansion of a tag during topic rendering
# $tag is the tag name
# $args is the bit in the {} (if there are any)
# $topic and $web should be passed for dynamic tags (not needed for
# session or constant tags
sub _expandTagOnTopicRendering {
    my $this = shift;
    my $tag  = shift;
    my $args = shift;

    # my( $topic, $web, $meta ) = @_;
    require Foswiki::Attrs;

    my $e = $this->{prefs}->getPreferencesValue($tag);
    unless ( defined($e) ) {
        $e = $this->{SESSION_TAGS}{$tag};
        if ( !defined($e) && defined( $functionTags{$tag} ) ) {
            $e = &{ $functionTags{$tag} }(
                $this, new Foswiki::Attrs( $args, $contextFreeSyntax{$tag} ), @_
            );
        }
    }
    return $e;
}

# Handle expansion of a tag during new topic creation. When creating a
# new topic from a template we only expand a subset of the available legal
# tags, and we expand %NOP% differently.
sub _expandTagOnTopicCreation {
    my $this = shift;

    # my( $tag, $args, $topic, $web ) = @_;

    # Required for Cairo compatibility. Ignore %NOP{...}%
    # %NOP% is *not* ignored until all variable expansion is complete,
    # otherwise them inside-out rule would remove it too early e.g.
    # %GM%NOP%TIME -> %GMTIME -> 12:00. So we ignore it here and scrape it
    # out later. We *have* to remove %NOP{...}% because it can foul up
    # brace-matching.
    return '' if $_[0] eq 'NOP' && defined $_[1];

    # Only expand a subset of legal tags. Warning: $this->{user} may be
    # overridden during this call, when a new user topic is being created.
    # This is what we want to make sure new user templates are populated
    # correctly, but you need to think about this if you extend the set of
    # tags expanded here.
    return undef
      unless $_[0] =~
/^(URLPARAM|DATE|(SERVER|GM)TIME|(USER|WIKI)NAME|WIKIUSERNAME|USERINFO)$/;

    return _expandTagOnTopicRendering( $this, @_ );
}

=begin TML

---++ ObjectMethod enterContext( $id, $val )

Add the context id $id into the set of active contexts. The $val
can be anything you like, but should always evaluate to boolean
TRUE.

An example of the use of contexts is in the use of tag
expansion. The commonTagsHandler in plugins is called every
time tags need to be expanded, and the context of that expansion
is signalled by the expanding module using a context id. So the
forms module adds the context id "form" before invoking common
tags expansion.

Contexts are not just useful for tag expansion; they are also
relevant when rendering.

Contexts are intended for use mainly by plugins. Core modules can
use $session->inContext( $id ) to determine if a context is active.

=cut

sub enterContext {
    my ( $this, $id, $val ) = @_;
    $val ||= 1;
    $this->{context}->{$id} = $val;
}

=begin TML

---++ ObjectMethod leaveContext( $id )

Remove the context id $id from the set of active contexts.
(see =enterContext= for more information on contexts)

=cut

sub leaveContext {
    my ( $this, $id ) = @_;
    my $res = $this->{context}->{$id};
    delete $this->{context}->{$id};
    return $res;
}

=begin TML

---++ ObjectMethod inContext( $id )

Return the value for the given context id
(see =enterContext= for more information on contexts)

=cut

sub inContext {
    my ( $this, $id ) = @_;
    return $this->{context}->{$id};
}

=begin TML

---++ StaticMethod registerTagHandler( $tag, $fnref )

STATIC Add a tag handler to the function tag handlers.
   * =$tag= name of the tag e.g. MYTAG
   * =$fnref= Function to execute. Will be passed ($session, \%params, $web, $topic )

=cut

sub registerTagHandler {
    my ( $tag, $fnref, $syntax ) = @_;
    $functionTags{$tag} = \&$fnref;
    if ( $syntax && $syntax eq 'context-free' ) {
        $contextFreeSyntax{$tag} = 1;
    }
}

=begin TML

---++ ObjectMethod handleCommonTags( $text, $web, $topic, $meta ) -> $text

Processes %<nop>VARIABLE%, and %<nop>TOC% syntax; also includes
'commonTagsHandler' plugin hook.

Returns the text of the topic, after file inclusion, variable substitution,
table-of-contents generation, and any plugin changes from commonTagsHandler.

$meta may be undef when, for example, expanding templates, or one-off strings
at a time when meta isn't available.

=cut

sub handleCommonTags {
    my ( $this, $text, $theWeb, $theTopic, $meta ) = @_;

    ASSERT($theWeb)   if DEBUG;
    ASSERT($theTopic) if DEBUG;

    return $text unless $text;
    my $verbatim = {};

    # Plugin Hook (for cache Plugins only)
    $this->{plugins}
      ->dispatch( 'beforeCommonTagsHandler', $text, $theTopic, $theWeb, $meta );

    #use a "global var", so included topics can extract and putback
    #their verbatim blocks safetly.
    $text = $this->renderer->takeOutBlocks( $text, 'verbatim', $verbatim );

    my $memW = $this->{SESSION_TAGS}{INCLUDINGWEB};
    my $memT = $this->{SESSION_TAGS}{INCLUDINGTOPIC};
    $this->{SESSION_TAGS}{INCLUDINGWEB}   = $theWeb;
    $this->{SESSION_TAGS}{INCLUDINGTOPIC} = $theTopic;

    expandAllTags( $this, \$text, $theTopic, $theWeb, $meta );

    $text = $this->renderer->takeOutBlocks( $text, 'verbatim', $verbatim );

    # Plugin Hook
    $this->{plugins}
      ->dispatch( 'commonTagsHandler', $text, $theTopic, $theWeb, 0, $meta );

    # process tags again because plugin hook may have added more in
    expandAllTags( $this, \$text, $theTopic, $theWeb, $meta );

    $this->{SESSION_TAGS}{INCLUDINGWEB}   = $memW;
    $this->{SESSION_TAGS}{INCLUDINGTOPIC} = $memT;

    # 'Special plugin tag' TOC hack, must be done after all other expansions
    # are complete, and has to reprocess the entire topic.

   # We need to keep track of the 'TOC topics' here in order to ensure that each
   # of these topics is only processed once (this is due to the fact that the
   # renaming of ambiguous anchors has to work context-less and cannot recognize
   # whether a particular heading has been converted before)--alternatively, we
   # could just clear the 'anchorname memory' and keep reprocessing topics
   # (the latter solution is slower if th same TOC is included multiple times)
   # current solution: let _TOC() clear the hash which holds the anchornames
    $text =~ s/%TOC(?:{(.*?)})?%/$this->_TOC($text, $theTopic, $theWeb, $1)/ge;

    # Codev.FormattedSearchWithConditionalOutput: remove <nop> lines,
    # possibly introduced by SEARCHes with conditional CALC. This needs
    # to be done after CALC and before table rendering in order to join
    # table rows properly
    $text =~ s/^<nop>\r?\n//gm;

    $this->renderer->putBackBlocks( \$text, $verbatim, 'verbatim' );

    # Foswiki Plugin Hook (for cache Plugins only)
    $this->{plugins}
      ->dispatch( 'afterCommonTagsHandler', $text, $theTopic, $theWeb, $meta );

    return $text;
}

=begin TML

---++ ObjectMethod ADDTOHEAD( $args )

Add =$html= to the HEAD tag of the page currently being generated.

Note that macros may be used in the HEAD. They will be expanded
according to normal variable expansion rules.

---+++ =%<nop>ADDTOHEAD%=
You can write =%ADDTOHEAD{...}%= in a topic or template. This variable accepts the following parameters:
   * =_DEFAULT= optional, id of the head block. Used to generate a comment in the output HTML.
   * =text= optional, text to use for the head block. Mutually exclusive with =topic=.
   * =topic= optional, full Foswiki path name of a topic that contains the full text to use for the head block. Mutually exclusive with =text=. Example: =topic="%WEB%.MyTopic"=.
   * =requires= optional, comma-separated list of id's of other head blocks this one depends on.
=%<nop>ADDTOHEAD%= expands in-place to the empty string, unless there is an error in which case the variable expands to an error string.

Use =%<nop>RENDERHEAD%= to generate the sorted head tags.

=cut

sub ADDTOHEAD {
    my ( $this, $args, $topic, $web ) = @_;

    my $_DEFAULT = $args->{_DEFAULT};
    my $text     = $args->{text};
    $topic = $args->{topic};
    my $requires = $args->{requires};
    if ( defined $topic ) {
        ( $web, $topic ) = $this->normalizeWebTopicName( $web, $topic );

        # prevent deep recursion
        $web =~ s/\//\./g;
        unless ($this->{_addedToHEAD}{"$web.$topic"}) {
          my $dummy = undef;
          ( $dummy, $text ) =
            $this->{store}->readTopic( $this->{user}, $web, $topic );
          $this->{_addedToHEAD}{"$web.$topic"} = 1;
        }
    }
    $text = $_DEFAULT unless defined $text;
    $text = ''        unless defined $text;

    $this->addToHEAD( $_DEFAULT, $text, $requires );
    return '';
}

sub addToHEAD {
    my ( $this, $tag, $header, $requires ) = @_;

    # Expand macros in the header
    $header =
      $this->handleCommonTags( $header, $this->{webName}, $this->{topicName} );

    $this->{_SORTEDHEADS} ||= {};
    $tag ||= '';

    $requires ||= '';
    my $debug = '';

    # Resolve to references to build DAG
    my @requires;
    foreach my $req ( split( /,\s*/, $requires ) ) {
        unless ( $this->{_SORTEDHEADS}->{$req} ) {
            $this->{_SORTEDHEADS}->{$req} = {
                tag      => $req,
                requires => [],
                header   => '',
            };
        }
        push( @requires, $this->{_SORTEDHEADS}->{$req} );
    }
    my $record = $this->{_SORTEDHEADS}->{$tag};
    unless ($record) {
        $record = { tag => $tag };
        $this->{_SORTEDHEADS}->{$tag} = $record;
    }
    $record->{requires} = \@requires;
    $record->{header}   = $header;

    # Temporary, for compatibility until %RENDERHEAD% is embedded
    # in the skins
    $this->{_HTMLHEADERS}{GENERATED_HEADERS} = _genHeaders($this);
}

sub _visit {
    my ( $v, $visited, $list ) = @_;
    return if $visited->{$v};
    $visited->{$v} = 1;
    foreach my $r ( @{ $v->{requires} } ) {
        _visit( $r, $visited, $list );
    }
    push( @$list, $v );
}

sub _genHeaders {
    my ($this) = @_;
    return '' unless $this->{_SORTEDHEADS};

    # Loop through the vertices of the graph, in any order, initiating
    # a depth-first search for any vertex that has not already been
    # visited by a previous search. The desired topological sorting is
    # the reverse postorder of these searches. That is, we can construct
    # the ordering as a list of vertices, by adding each vertex to the
    # start of the list at the time when the depth-first search is
    # processing that vertex and has returned from processing all children
    # of that vertex. Since each edge and vertex is visited once, the
    # algorithm runs in linear time.
    my %visited;
    my @total;
    foreach my $v ( values %{ $this->{_SORTEDHEADS} } ) {
        _visit( $v, \%visited, \@total );
    }

    return join( "\n", map { "<!-- $_->{tag} --> $_->{header}" } @total );
}

=begin TML

---+++ %<nop}RENDERHEAD%
=%RENDERHEAD%= should be written where you want the sorted head tags to be generated. This will normally be in a template. The variable expands to a sorted list of the head blocks added up to the point the RENDERHEAD variable is expanded. Each expanded head block is preceded by an HTML comment that records the ID of the head block.

Head blocks are sorted to satisfy all their =requires= constraints.
The output order of blocks with no =requires= value is undefined. If cycles
exist in the dependency order, the cycles will be broken but the resulting
order of blocks in the cycle is undefined.

=cut

sub RENDERHEAD {
    my $this = shift;
    return _genHeaders($this);
}

=begin TML

---++ StaticMethod initialize( $pathInfo, $remoteUser, $topic, $url, $query ) -> ($topicName, $webName, $scriptUrlPath, $userName, $dataDir)

Return value: ( $topicName, $webName, $Foswiki::cfg{ScriptUrlPath}, $userName, $Foswiki::cfg{DataDir} )

Static method to construct a new singleton session instance.
It creates a new Foswiki and sets the Plugins $SESSION variable to
point to it, so that Foswiki::Func methods will work.

This method is *DEPRECATED* but is maintained for script compatibility.

Note that $theUrl, if specified, must be identical to $query->url()

=cut

sub initialize {
    my ( $pathInfo, $theRemoteUser, $topic, $theUrl, $query ) = @_;

    if ( !$query ) {
        $query = new Foswiki::Request( {} );
    }
    if ( $query->path_info() ne $pathInfo ) {
        $query->path_info( "/$0/" . $pathInfo );
    }
    if ($topic) {
        $query->param( -name => 'topic', -value => '' );
    }

    # can't do much if $theUrl is specified and it is inconsistent with
    # the query. We are trying to get to all parameters passed in the
    # query.
    if ( $theUrl && $theUrl ne $query->url() ) {
        die
'Sorry, this version of Foswiki does not support the url parameter to Foswiki::initialize being different to the url in the query';
    }
    my $session = new Foswiki( $theRemoteUser, $query );

    # Force the new session into the plugins context.
    $Foswiki::Plugins::SESSION = $session;

    return (
        $session->{topicName},     $session->{webName},
        $session->{scriptUrlPath}, $session->{userName},
        $Foswiki::cfg{DataDir}
    );
}

=begin TML

---++ StaticMethod readFile( $filename ) -> $text

Returns the entire contents of the given file, which can be specified in any
format acceptable to the Perl open() function. Fast, but inherently unsafe.

WARNING: Never, ever use this for accessing topics or attachments! Use the
Store API for that. This is for global control files only, and should be
used *only* if there is *absolutely no alternative*.

=cut

sub readFile {
    my $name = shift;
    open( IN_FILE, "<$name" ) || return '';
    local $/ = undef;
    my $data = <IN_FILE>;
    close(IN_FILE);
    $data = '' unless ( defined($data) );
    return $data;
}

=begin TML

---++ StaticMethod expandStandardEscapes($str) -> $unescapedStr

Expands standard escapes used in parameter values to block evaluation. The following escapes
are handled:

| *Escape:* | *Expands To:* |
| =$n= or =$n()= | New line. Use =$n()= if followed by alphanumeric character, e.g. write =Foo$n()Bar= instead of =Foo$nBar= |
| =$nop= or =$nop()= | Is a "no operation". |
| =$quot= | Double quote (="=) |
| =$percnt= | Percent sign (=%=) |
| =$dollar= | Dollar sign (=$=) |

=cut

sub expandStandardEscapes {
    my $text = shift;
    $text =~ s/\$n\(\)/\n/gos;    # expand '$n()' to new line
    $text =~ s/\$n([^$regex{mixedAlpha}]|$)/\n$1/gos;  # expand '$n' to new line
    $text =~ s/\$nop(\(\))?//gos;      # remove filler, useful for nested search
    $text =~ s/\$quot(\(\))?/\"/gos;   # expand double quote
    $text =~ s/\$percnt(\(\))?/\%/gos; # expand percent
    $text =~ s/\$dollar(\(\))?/\$/gos; # expand dollar
    $text =~ s/\$lt(\(\))?/\</gos;     # expand less than
    $text =~ s/\$gt(\(\))?/\>/gos;     # expand greater than
    $text =~ s/\$amp(\(\))?/\&/gos;    # expand ampersand
    return $text;
}

# generate an include warning
# SMELL: varying number of parameters idiotic to handle for customized $warn
sub _includeWarning {
    my $this    = shift;
    my $warn    = shift;
    my $message = shift;

    if ( $warn eq 'on' ) {
        return $this->inlineAlert( 'alerts', $message, @_ );
    }
    elsif ( isTrue($warn) ) {

        # different inlineAlerts need different argument counts
        my $argument = '';
        if ( $message eq 'topic_not_found' ) {
            my ( $web, $topic ) = @_;
            $argument = "$web.$topic";
        }
        else {
            $argument = shift;
        }
        $warn =~ s/\$topic/$argument/go if $argument;
        return $warn;
    }    # else fail silently
    return '';
}

#-------------------------------------------------------------------
# Tag Handlers
#-------------------------------------------------------------------

sub FORMFIELD {
    my ( $this, $params, $topic, $web ) = @_;
    my $cgiQuery = $this->{request};
    $params->{rev} = $cgiQuery->param('rev') if ($cgiQuery);
    return $this->renderer->renderFORMFIELD( $params, $topic, $web );
}

sub TMPLP {
    my ( $this, $params ) = @_;
    return $this->templates->tmplP($params);
}

sub VAR {
    my ( $this, $params, $topic, $inweb ) = @_;
    my $key = $params->{_DEFAULT};
    return '' unless $key;
    my $web = $params->{web} || $inweb;

    # handle %USERSWEB%-type cases
    ( $web, $topic ) = $this->normalizeWebTopicName( $web, $topic );

    # always return a value, even when the key isn't defined
    return $this->{prefs}->getWebPreferencesValue( $key, $web ) || '';
}

sub PLUGINVERSION {
    my ( $this, $params ) = @_;
    $this->{plugins}->getPluginVersion( $params->{_DEFAULT} );
}

sub IF {
    my ( $this, $params, $topic, $web, $meta ) = @_;

    unless ($ifParser) {
        require Foswiki::If::Parser;
        $ifParser = new Foswiki::If::Parser();
    }

    my $texpr = $params->{_DEFAULT};
    my $expr;
    my $result;

    # Recursion block.
    $this->{evaluating_if} ||= {};

    # Block after 5 levels.
    if (   $this->{evaluating_if}->{$texpr}
        && $this->{evaluating_if}->{$texpr} > 5 )
    {
        delete $this->{evaluating_if}->{$texpr};
        return '';
    }
    $this->{evaluating_if}->{$texpr}++;

    try {
        $expr = $ifParser->parse($texpr);
        unless ($meta) {
            require Foswiki::Meta;
            $meta = new Foswiki::Meta( $this, $web, $topic );
        }
        if ( $expr->evaluate( tom => $meta, data => $meta ) ) {
            $params->{then} = '' unless defined $params->{then};
            $result = expandStandardEscapes( $params->{then} );
        }
        else {
            $params->{else} = '' unless defined $params->{else};
            $result = expandStandardEscapes( $params->{else} );
        }
    }
    catch Foswiki::Infix::Error with {
        my $e = shift;
        $result =
          $this->inlineAlert( 'alerts', 'generic', 'IF{', $params->stringify(),
            '}:', $e->{-text} );
    }
    finally {
        delete $this->{evaluating_if}->{$texpr};
    };
    return $result;
}

# Processes a specific instance %<nop>INCLUDE{...}% syntax.
# Returns the text to be inserted in place of the INCLUDE command.
# $topic and $web should be for the immediate parent topic in the
# include hierarchy. Works for both URLs and absolute server paths.
sub INCLUDE {
    my ( $this, $params, $includingTopic, $includingWeb ) = @_;

    # remember args for the key before mangling the params
    my $args = $params->stringify();

    # Remove params, so they don't get expanded in the included page
    my %control;
    for my $p qw(_DEFAULT pattern rev section raw warn) {
        $control{$p} = $params->remove($p);
    }

    $control{warn} ||= $this->{prefs}->getPreferencesValue('INCLUDEWARNING');

    # make sure we have something to include. If we don't do this, then
    # normalizeWebTopicName will default to WebHome. TWikibug:Item2209.
    unless ( $control{_DEFAULT} ) {
        return _includeWarning( $this, $control{warn}, 'bad_include_path', '' );
    }

    # Filter out '..' from path to prevent includes of '../../file'
    if ( $Foswiki::cfg{DenyDotDotInclude} && $control{_DEFAULT} =~ /\.\./ ) {
        return _includeWarning( $this, $control{warn}, 'bad_include_path',
            $control{_DEFAULT} );
    }

    # no sense in considering an empty string as an unfindable section
    delete $control{section}
      if ( defined( $control{section} ) && $control{section} eq '' );
    $control{raw} ||= '';
    $control{inWeb}   = $includingWeb;
    $control{inTopic} = $includingTopic;
    if ( $control{_DEFAULT} =~ /^([a-z]+):/ ) {
        my $handler = $1;
        eval 'use Foswiki::IncludeHandlers::' . $handler;
        die $@ if ($@);
        unless ($@) {
            $handler = 'Foswiki::IncludeHandlers::' . $handler;
            return $handler->INCLUDE( $this, \%control, $params );
        }
    }

    # No protocol handler; must be a topic reference

    my $text = '';
    my $meta = '';
    my $includedWeb;
    my $includedTopic = $control{_DEFAULT};
    $includedTopic =~ s/\.txt$//;    # strip optional (undocumented) .txt

    ( $includedWeb, $includedTopic ) =
      $this->normalizeWebTopicName( $includingWeb, $includedTopic );

    # See Codev.FailedIncludeWarning for the history.
    unless ( $this->{store}->topicExists( $includedWeb, $includedTopic ) ) {
        return _includeWarning( $this, $control{warn}, 'topic_not_found',
            $includedWeb, $includedTopic );
    }

    # prevent recursive includes. Note that the inclusion of a topic into
    # itself is not blocked; however subsequent attempts to include the
    # topic will fail. There is a hard block of 99 on any recursive include.
    my $key = $includingWeb . '.' . $includingTopic;
    my $count = grep( $key, keys %{ $this->{_INCLUDES} } );
    $key .= $args;
    if ( $this->{_INCLUDES}->{$key} || $count > 99 ) {
        return _includeWarning( $this, $control{warn}, 'already_included',
            "$includedWeb.$includedTopic", '' );
    }

    my %saveTags  = %{ $this->{SESSION_TAGS} };
    my $prefsMark = $this->{prefs}->mark();

    $this->{_INCLUDES}->{$key}            = 1;
    $this->{SESSION_TAGS}{INCLUDINGWEB}   = $includingWeb;
    $this->{SESSION_TAGS}{INCLUDINGTOPIC} = $includingTopic;

    # copy params into session tags
    foreach my $k ( keys %$params ) {
        $this->{SESSION_TAGS}{$k} = $params->{$k};
    }

    ( $meta, $text ) =
      $this->{store}
      ->readTopic( undef, $includedWeb, $includedTopic, $control{rev} );

    # Simplify leading, and remove trailing, newlines. If we don't remove
    # trailing, it becomes impossible to %INCLUDE a topic into a table.
    $text =~ s/^[\r\n]+/\n/;
    $text =~ s/[\r\n]+$//;

    unless (
        $this->security->checkAccessPermission(
            'VIEW', $this->{user},  $text,
            $meta,  $includedTopic, $includedWeb
        )
      )
    {
        if ( isTrue( $control{warn} ) ) {
            return $this->inlineAlert( 'alerts', 'access_denied',
                "[[$includedWeb.$includedTopic]]" );
        }    # else fail silently
        return '';
    }

    # remove everything before and after the default include block unless
    # a section is explicitly defined
    if ( !$control{section} ) {
        $text =~ s/.*?%STARTINCLUDE%//s;
        $text =~ s/%STOPINCLUDE%.*//s;
    }

    # handle sections
    my ( $ntext, $sections ) = parseSections($text);

    my $interesting = ( defined $control{section} );
    if ( $interesting || scalar(@$sections) ) {

        # Rebuild the text from the interesting sections
        $text = '';
        foreach my $s (@$sections) {
            if (   $control{section}
                && $s->{type} eq 'section'
                && $s->{name} eq $control{section} )
            {
                $text .= substr( $ntext, $s->{start}, $s->{end} - $s->{start} );
                $interesting = 1;
                last;
            }
            elsif ( $s->{type} eq 'include' && !$control{section} ) {
                $text .= substr( $ntext, $s->{start}, $s->{end} - $s->{start} );
                $interesting = 1;
            }
        }
    }

    if ( $interesting and ( length($text) eq 0 ) ) {
        return _includeWarning( $this, $control{warn},
            'topic_section_not_found', $includedWeb, $includedTopic,
            $control{section} );
    }

    # If there were no interesting sections, restore the whole text
    $text = $ntext unless $interesting;

    $text = applyPatternToIncludedText( $text, $control{pattern} )
      if ( $control{pattern} );

    # Do not show TOC in included topic if TOC_HIDE_IF_INCLUDED
    # preference has been set
    if ( isTrue( $this->{prefs}->getPreferencesValue('TOC_HIDE_IF_INCLUDED') ) )
    {
        $text =~ s/%TOC(?:{(.*?)})?%//g;
    }

    expandAllTags( $this, \$text, $includedTopic, $includedWeb, $meta );

    # 4th parameter tells plugin that its called for an included file
    $this->{plugins}
      ->dispatch( 'commonTagsHandler', $text, $includedTopic, $includedWeb, 1,
        $meta );

   # We have to expand tags again, because a plugin may have inserted additional
   # tags.
    expandAllTags( $this, \$text, $includedTopic, $includedWeb, $meta );

    # If needed, fix all 'TopicNames' to 'Web.TopicNames' to get the
    # right context so that links continue to work properly
    if ( $includedWeb ne $includingWeb ) {
        my $removed = {};

        $text = $this->renderer->forEachLine(
            $text,
            \&_fixupIncludedTopic,
            {
                web        => $includedWeb,
                pre        => 1,
                noautolink => 1
            }
        );

        # handle tags again because of plugin hook
        expandAllTags( $this, \$text, $includedTopic, $includedWeb, $meta );
    }

    # restore the tags
    delete $this->{_INCLUDES}->{$key};
    %{ $this->{SESSION_TAGS} } = %saveTags;

    $this->{prefs}->restore($prefsMark);

    return $text;
}

sub HTTP {
    my ( $this, $params ) = @_;
    my $res;
    if ( $params->{_DEFAULT} ) {
        $res = $this->{request}->http( $params->{_DEFAULT} );
    }
    $res = '' unless defined($res);
    return $res;
}

sub HTTPS {
    my ( $this, $params ) = @_;
    my $res;
    if ( $params->{_DEFAULT} ) {
        $res = $this->{request}->https( $params->{_DEFAULT} );
    }
    $res = '' unless defined($res);
    return $res;
}

#deprecated functionality, now implemented using %ENV%
#move to compatibility plugin in Foswiki 2.0
sub HTTP_HOST_deprecated {
    return $_[0]->{request}->header('Host') || '';
}

#deprecated functionality, now implemented using %ENV%
#move to compatibility plugin in Foswiki 2.0
sub REMOTE_ADDR_deprecated {
    return $_[0]->{request}->remoteAddress() || '';
}

#deprecated functionality, now implemented using %ENV%
#move to compatibility plugin in Foswiki 2.0
sub REMOTE_PORT_deprecated {

    # CGI/1.1 (RFC 3875) doesn't specify REMOTE_PORT,
    # but some webservers implement it. However, since
    # it's not RFC compliant, Foswiki should not rely on
    # it. So we get more portability.
    return '';
}

#deprecated functionality, now implemented using %ENV%
#move to compatibility plugin in Foswiki
sub REMOTE_USER_deprecated {
    return $_[0]->{request}->remoteUser() || '';
}

# Only does simple search for topicmoved at present, can be expanded when required
# SMELL: this violates encapsulation of Store and Meta, by exporting
# the assumption that meta-data is stored embedded inside topic
# text.
sub METASEARCH {
    my ( $this, $params ) = @_;

    return $this->{store}->searchMetaData($params);
}

sub DATE {
    my $this = shift;
    return Foswiki::Time::formatTime(
        time(),
        $Foswiki::cfg{DefaultDateFormat},
        $Foswiki::cfg{DisplayTimeValues}
    );
}

sub GMTIME {
    my ( $this, $params ) = @_;
    return Foswiki::Time::formatTime( time(), $params->{_DEFAULT} || '',
        'gmtime' );
}

sub SERVERTIME {
    my ( $this, $params ) = @_;
    return Foswiki::Time::formatTime( time(), $params->{_DEFAULT} || '',
        'servertime' );
}

sub DISPLAYTIME {
    my ( $this, $params ) = @_;
    return Foswiki::Time::formatTime(
        time(),
        $params->{_DEFAULT} || '',
        $Foswiki::cfg{DisplayTimeValues}
    );
}

#| $web | web and  |
#| $topic | topic to display the name for |
#| $formatString | format string (like in search) |
sub REVINFO {
    my ( $this, $params, $theTopic, $theWeb ) = @_;
    my $format = $params->{_DEFAULT} || $params->{format};
    my $web    = $params->{web}      || $theWeb;
    my $topic  = $params->{topic}    || $theTopic;
    my $cgiQuery = $this->{request};
    my $cgiRev   = '';
    $cgiRev = $cgiQuery->param('rev') if ($cgiQuery);
    my $rev = $params->{rev} || $cgiRev || '';

    ( $web, $topic ) = $this->normalizeWebTopicName( $web, $topic );
    if ( $web ne $theWeb || $topic ne $theTopic ) {
        unless (
            $this->security->checkAccessPermission(
                'VIEW', $this->{user}, undef, undef, $topic, $web
            )
          )
        {
            return $this->inlineAlert( 'alerts', 'access_denied', $web,
                $topic );
        }
    }

    return $this->renderer->renderRevisionInfo( $web, $topic, undef, $rev,
        $format );
}

sub REVTITLE {
    my ( $this, $params, $theTopic, $theWeb ) = @_;
    my $request = $this->{request};
    my $out     = '';
    if ($request) {
        my $rev = $request->param('rev');
        $out = '(r' . $rev . ')' if ($rev);
    }
    return $out;
}

sub REVARG {
    my ( $this, $params, $theTopic, $theWeb ) = @_;
    my $request = $this->{request};
    my $out     = '';
    if ($request) {
        my $rev = $request->param('rev');
        $out = '&rev=' . $rev if ($rev);
    }
    return $out;
}

sub ENCODE {
    my ( $this, $params ) = @_;
    my $type = $params->{type} || 'url';

    # Value 0 can be valid input so we cannot use simple = || ''
    my $text = defined( $params->{_DEFAULT} ) ? $params->{_DEFAULT} : '';
    return _encode( $type, $text );
}

sub _encode {
    my ( $type, $text ) = @_;

    if ( $type =~ /^entit(y|ies)$/i ) {
        return entityEncode($text);
    }
    elsif ( $type =~ /^html$/i ) {
        return entityEncode( $text, "\n\r" );
    }
    elsif ( $type =~ /^quotes?$/i ) {

        # escape quotes with backslash (Bugs:Item3383 fix)
        $text =~ s/\"/\\"/go;
        return $text;
    }
    elsif ( $type =~ /^url$/i ) {
        $text =~ s/\r*\n\r*/<br \/>/;    # Legacy.
        return urlEncode($text);
    }
    elsif ( $type =~ /^(off|none)$/i ) {

        # no encoding
        return $text;
    }
    else {                               # safe or default
                                         # entity encode ' " < > and %
        $text =~ s/([<>%'"])/'&#'.ord($1).';'/ge;
        return $text;
    }
}

sub ENV {
    my ( $this, $params ) = @_;

    my $key = $params->{_DEFAULT};
    return ''
      unless $key
          && defined $Foswiki::cfg{AccessibleENV}
          && $key =~ /$Foswiki::cfg{AccessibleENV}/o;
    my $val;
    if ( $key =~ /^HTTPS?_(\w+)/ ) {
        $val = $this->{request}->header($1);
    }
    elsif ( $key eq 'REQUEST_METHOD' ) {
        $val = $this->{request}->method;
    }
    elsif ( $key eq 'REMOTE_USER' ) {
        $val = $this->{request}->remoteUser;
    }
    elsif ( $key eq 'REMOTE_ADDR' ) {
        $val = $this->{request}->remoteAddress;
    }
    else {

        # TSA SMELL: Foswiki::Request doesn't support
        # SERVER_\w+, REMOTE_HOST and REMOTE_IDENT.
        # Use %ENV as fallback, but for ones above
        # wil probably not behave as expected if
        # running with non-CGI engine.
        $val = $ENV{$key};
    }
    return defined $val ? $val : 'not set';
}

sub SEARCH {
    my ( $this, $params, $topic, $web ) = @_;

    # pass on all attrs, and add some more
    #$params->{_callback} = undef;
    $params->{inline}    = 1;
    $params->{baseweb}   = $web;
    $params->{basetopic} = $topic;
    $params->{search}    = $params->{_DEFAULT} if defined $params->{_DEFAULT};
    $params->{type} =
      $this->{prefs}->getPreferencesValue('SEARCHVARDEFAULTTYPE')
      unless ( $params->{type} );
    my $s;
    try {
        $s = $this->search->searchWeb(%$params);
    }
    catch Error::Simple with {
        my $message = (DEBUG) ? shift->stringify() : shift->{-text};

        # Block recursions kicked off by the text being repeated in the
        # error message
        $message =~ s/%([A-Z]*[{%])/%<nop>$1/g;
        $s = $this->inlineAlert( 'alerts', 'bad_search', $message );
    };
    return $s;
}

sub WEBLIST {
    my ( $this, $params ) = @_;
    my $format = $params->{_DEFAULT} || $params->{'format'} || '$name';
    $format ||= '$name';
    my $separator = $params->{separator} || "\n";
    $separator =~ s/\$n/\n/;
    my $web       = $params->{web}       || '';
    my $webs      = $params->{webs}      || 'public';
    my $selection = $params->{selection} || '';
    my $showWeb   = $params->{subwebs}   || '';
    $selection =~ s/\,/ /g;
    $selection = " $selection ";
    my $marker = $params->{marker} || 'selected="selected"';
    $web =~ s#\.#/#go;

    my @list = ();
    my @webslist = split( /,\s*/, $webs );
    foreach my $aweb (@webslist) {
        if ( $aweb eq 'public' ) {
            push( @list,
                $this->{store}->getListOfWebs( 'user,public,allowed', $showWeb )
            );
        }
        elsif ( $aweb eq 'webtemplate' ) {
            push( @list,
                $this->{store}->getListOfWebs( 'template,allowed', $showWeb ) );
        }
        else {
            push( @list, $aweb ) if ( $this->{store}->webExists($aweb) );
        }
    }

    my @items;
    my $indent = CGI::span( { class => 'foswikiWebIndent' }, '' );
    foreach my $item (@list) {
        my $line = $format;
        $line =~ s/\$web\b/$web/g;
        $line =~ s/\$name\b/$item/g;
        $line =~ s/\$qname/"$item"/g;
        my $indenteditem = $item;
        $indenteditem =~ s#/$##g;
        $indenteditem =~ s#\w+/#$indent#g;
        $line         =~ s/\$indentedname/$indenteditem/g;
        my $mark = ( $selection =~ / \Q$item\E / ) ? $marker : '';
        $line =~ s/\$marker/$mark/g;
        push( @items, $line );
    }
    return join( $separator, @items );
}

sub TOPICLIST {
    my ( $this, $params ) = @_;
    my $format = $params->{_DEFAULT} || $params->{'format'} || '$topic';
    my $separator = $params->{separator} || "\n";
    $separator =~ s/\$n/\n/;
    my $web       = $params->{web}       || $this->{webName};
    my $selection = $params->{selection} || '';
    $selection =~ s/\,/ /g;
    $selection = " $selection ";
    my $marker = $params->{marker} || 'selected="selected"';
    $web =~ s#\.#/#go;

    return ''
      if $web ne $this->{webName}
          && $this->{prefs}->getWebPreferencesValue( 'NOSEARCHALL', $web );

    my @items;
    foreach my $item ( $this->{store}->getTopicNames($web) ) {
        my $line = $format;
        $line =~ s/\$web\b/$web/g;
        $line =~ s/\$topic\b/$item/g;
        $line =~ s/\$name\b/$item/g;     # Undocumented, DO NOT REMOVE
        $line =~ s/\$qname/"$item"/g;    # Undocumented, DO NOT REMOVE
        my $mark = ( $selection =~ / \Q$item\E / ) ? $marker : '';
        $line =~ s/\$marker/$mark/g;
        $line = expandStandardEscapes($line);
        push( @items, $line );
    }
    return join( $separator, @items );
}

sub QUERYSTRING {
    my $this = shift;
    return $this->{request}->queryString();
}

sub QUERYPARAMS {
    my ( $this, $params ) = @_;
    return '' unless $this->{request};
    my $format =
      defined $params->{format}
      ? $params->{format}
      : '$name=$value';
    my $separator = defined $params->{separator} ? $params->{separator} : "\n";
    my $encoding = $params->{encoding} || 'safe';

    my @list;
    foreach my $name ( $this->{request}->param() ) {

        # Issues multi-valued parameters as separate hiddens
        my $value = $this->{request}->param($name);
        $value = '' unless defined $value;
        $name  = _encode( $encoding, $name );
        $value = _encode( $encoding, $value );

        my $entry = $format;
        $entry =~ s/\$name/$name/g;
        $entry =~ s/\$value/$value/;
        push( @list, $entry );
    }
    return join( $separator, @list );
}

sub URLPARAM {
    my ( $this, $params ) = @_;
    my $param     = $params->{_DEFAULT} || '';
    my $newLine   = $params->{newline};
    my $encode    = $params->{encode} || 'safe';
    my $multiple  = $params->{multiple};
    my $separator = $params->{separator};
    $separator = "\n" unless ( defined $separator );

    my $value;
    if ( $this->{request} ) {
        if ( Foswiki::isTrue($multiple) ) {
            my @valueArray = $this->{request}->param($param);
            if (@valueArray) {

                # join multiple values properly
                unless ( $multiple =~ m/^on$/i ) {
                    my $item = '';
                    @valueArray = map {
                        $item = $_;
                        $_    = $multiple;
                        $_ .= $item unless (s/\$item/$item/go);
                        $_
                    } @valueArray;
                }
                $value = join( $separator, @valueArray );
            }
        }
        else {
            $value = $this->{request}->param($param);
        }
    }
    if ( defined $value ) {
        $value =~ s/\r?\n/$newLine/go if ( defined $newLine );
        if ( $encode =~ /^entit(y|ies)$/i ) {
            $value = entityEncode($value);
        }
        elsif ( $encode =~ /^quotes?$/i ) {
            $value =~
              s/\"/\\"/go;    # escape quotes with backslash (Bugs:Item3383 fix)
        }
        elsif ( $encode =~ /^(off|none)$/i ) {

            # no encoding
        }
        elsif ( $encode =~ /^url$/i ) {
            $value =~ s/\r*\n\r*/<br \/>/;    # Legacy
            $value = urlEncode($value);
        }
        else {                                # safe or default
                                              # entity encode ' " < > and %
            $value =~ s/([<>%'"])/'&#'.ord($1).';'/ge;
        }
    }
    unless ( defined $value ) {
        $value = $params->{default};
        $value = '' unless defined $value;
    }

    # Block expansion of %URLPARAM in the value to prevent recursion
    $value =~ s/%URLPARAM{/%<nop>URLPARAM{/g;
    return $value;
}

# This routine was introduced to URL encode Mozilla UTF-8 POST URLs in the
# TWiki Feb2003 release - encoding is no longer needed since UTF-URLs are now
# directly supported, but it is provided for backward compatibility with
# skins that may still be using the deprecated %INTURLENCODE%.
sub INTURLENCODE_deprecated {
    my ( $this, $params ) = @_;

    # Just strip double quotes, no URL encoding - Mozilla UTF-8 URLs
    # directly supported now
    return $params->{_DEFAULT} || '';
}

# This routine is deprecated as of DakarRelease,
# and is maintained only for backward compatibility.
# Spacing of WikiWords is now done with %SPACEOUT%
# (and the private routine _SPACEOUT).
# Move to compatibility module in Foswiki 2.0
sub SPACEDTOPIC_deprecated {
    my ( $this, $params, $theTopic ) = @_;
    my $topic = spaceOutWikiWord($theTopic);
    $topic =~ s/ / */g;
    return urlEncode($topic);
}

sub SPACEOUT {
    my ( $this, $params ) = @_;
    my $spaceOutTopic = $params->{_DEFAULT};
    my $sep           = $params->{'separator'};
    $spaceOutTopic = spaceOutWikiWord( $spaceOutTopic, $sep );
    return $spaceOutTopic;
}

sub ICON {
    my ( $this, $params ) = @_;
    my $file = $params->{_DEFAULT} || '';

    # Try to map the file name to see if there is a matching filetype image
    # If no mapping could be found, use the file name that was passed
    my $iconFileName = $this->mapToIconFileName( $file, $file );
    return CGI::img(
        {
            src    => $this->getIconUrl( 0, $iconFileName ),
            width  => 16,
            height => 16,
            align  => 'top',
            alt    => $iconFileName,
            border => 0
        }
    );
}

sub ICONURL {
    my ( $this, $params ) = @_;
    my $file = ( $params->{_DEFAULT} || '' );

    return $this->getIconUrl( 1, $file );
}

sub ICONURLPATH {
    my ( $this, $params ) = @_;
    my $file = ( $params->{_DEFAULT} || '' );

    return $this->getIconUrl( 0, $file );
}

sub RELATIVETOPICPATH {
    my ( $this, $params, $theTopic, $web ) = @_;
    my $topic = $params->{_DEFAULT};

    return '' unless $topic;

    my $theRelativePath;

    # if there is no dot in $topic, no web has been specified
    if ( index( $topic, '.' ) == -1 ) {

        # add local web
        $theRelativePath = $web . '/' . $topic;
    }
    else {
        $theRelativePath = $topic;    #including dot
    }

    # replace dot by slash is not necessary; System.MyTopic is a valid url
    # add ../ if not already present to make a relative file reference
    if ( $theRelativePath !~ m!^../! ) {
        $theRelativePath = "../$theRelativePath";
    }
    return $theRelativePath;
}

sub ATTACHURLPATH {
    my ( $this, $params, $topic, $web ) = @_;
    return $this->getPubUrl( 0, $web, $topic );
}

sub ATTACHURL {
    my ( $this, $params, $topic, $web ) = @_;
    return $this->getPubUrl( 1, $web, $topic );
}

sub LANGUAGE {
    my $this = shift;
    return $this->i18n->language();
}

sub LANGUAGES {
    my ( $this, $params ) = @_;
    my $format    = $params->{format}    || "   * \$langname";
    my $separator = $params->{separator} || "\n";
    $separator =~ s/\\n/\n/g;
    my $selection = $params->{selection} || '';
    $selection =~ s/\,/ /g;
    $selection = " $selection ";
    my $marker = $params->{marker} || 'selected="selected"';

    # $languages is a hash reference:
    my $languages = $this->i18n->enabled_languages();

    my @tags = sort( keys( %{$languages} ) );

    my $result = '';
    my $i      = 0;
    foreach my $lang (@tags) {
        my $item = $format;
        my $name = ${$languages}{$lang};
        $item =~ s/\$langname/$name/g;
        $item =~ s/\$langtag/$lang/g;
        my $mark = ( $selection =~ / \Q$lang\E / ) ? $marker : '';
        $item =~ s/\$marker/$mark/g;
        $result .= $separator if $i;
        $result .= $item;
        $i++;
    }

    return $result;
}

sub MAKETEXT {
    my ( $this, $params ) = @_;

    my $str = $params->{_DEFAULT} || $params->{string} || "";
    return "" unless $str;

    # escape everything:
    $str =~ s/\[/~[/g;
    $str =~ s/\]/~]/g;

    # restore already escaped stuff:
    $str =~ s/~~\[/~[/g;
    $str =~ s/~~\]/~]/g;

    # unescape parameters and calculate highest parameter number:
    my $max = 0;
    $str =~ s/~\[(\_(\d+))~\]/ $max = $2 if ($2 > $max); "[$1]"/ge;
    $str =~
s/~\[(\*,\_(\d+),[^,]+(,([^,]+))?)~\]/ $max = $2 if ($2 > $max); "[$1]"/ge;

    # get the args to be interpolated.
    my $argsStr = $params->{args} || "";

    my @args = split( /\s*,\s*/, $argsStr );

    # fill omitted args with zeros
    while ( ( scalar @args ) < $max ) {
        push( @args, 0 );
    }

    # do the magic:
    my $result = $this->i18n->maketext( $str, @args );

    # replace accesskeys:
    $result =~
      s#(^|[^&])&([a-zA-Z])#$1<span class='foswikiAccessKey'>$2</span>#g;

    # replace escaped amperstands:
    $result =~ s/&&/\&/g;

    return $result;
}

sub SCRIPTNAME {
    return $_[0]->{request}->action;
}

sub SCRIPTURL {
    my ( $this, $params, $topic, $web ) = @_;
    my $script = $params->{_DEFAULT} || '';

    return $this->getScriptUrl( 1, $script );
}

sub SCRIPTURLPATH {
    my ( $this, $params, $topic, $web ) = @_;
    my $script = $params->{_DEFAULT} || '';

    return $this->getScriptUrl( 0, $script );
}

sub PUBURL {
    my $this = shift;
    return $this->getPubUrl(1);
}

sub PUBURLPATH {
    my $this = shift;
    return $this->getPubUrl(0);
}

sub ALLVARIABLES {
    return shift->{prefs}->stringify();
}

sub META {
    my ( $this, $params, $topic, $web ) = @_;

    my $meta = $this->inContext('can_render_meta');

    return '' unless $meta;

    my $option = $params->{_DEFAULT} || '';

    if ( $option eq 'form' ) {

        # META:FORM and META:FIELD
        return $meta->renderFormForDisplay( $this->templates );
    }
    elsif ( $option eq 'formfield' ) {

        # a formfield from within topic text
        return $meta->renderFormFieldForDisplay( $params->get('name'), '$value',
            $params );
    }
    elsif ( $option eq 'attachments' ) {

        # renders attachment tables
        return $this->attach->renderMetaData( $web, $topic, $meta, $params );
    }
    elsif ( $option eq 'moved' ) {
        return $this->renderer->renderMoved( $web, $topic, $meta, $params );
    }
    elsif ( $option eq 'parent' ) {

        # Only parent parameter has the format option and should do std escapes
        return expandStandardEscapes(
            $this->renderer->renderParent( $web, $topic, $meta, $params ) );
    }

    # return nothing if invalid parameter
    return '';
}

# Remove NOP tag in template topics but show content. Used in template
# _topics_ (not templates, per se, but topics used as templates for new
# topics)
sub NOP {
    my ( $this, $params, $topic, $web ) = @_;

    return '<nop>' unless $params->{_RAW};

    return $params->{_RAW};
}

# Shortcut to %TMPL:P{"sep"}%
sub SEP {
    my $this = shift;
    return $this->templates->expandTemplate('sep');
}

#deprecated functionality, now implemented using %USERINFO%
#move to compatibility plugin in Foswiki 2.0
sub WIKINAME_deprecated {
    my ( $this, $params ) = @_;

    $params->{format} = $this->{prefs}->getPreferencesValue('WIKINAME')
      || '$wikiname';

    return $this->USERINFO($params);
}

#deprecated functionality, now implemented using %USERINFO%
#move to compatibility plugin in Foswiki 2.0
sub USERNAME_deprecated {
    my ( $this, $params ) = @_;

    $params->{format} = $this->{prefs}->getPreferencesValue('USERNAME')
      || '$username';

    return $this->USERINFO($params);
}

#deprecated functionality, now implemented using %USERINFO%
#move to compatibility plugin in Foswiki 2.0
sub WIKIUSERNAME_deprecated {
    my ( $this, $params ) = @_;

    $params->{format} = $this->{prefs}->getPreferencesValue('WIKIUSERNAME')
      || '$wikiusername';

    return $this->USERINFO($params);
}

sub USERINFO {
    my ( $this, $params ) = @_;
    my $format = $params->{format} || '$username, $wikiusername, $emails';

    my $user = $this->{user};

    if ( $params->{_DEFAULT} ) {
        $user = $params->{_DEFAULT};
        return '' if !$user;

        # map wikiname to a login name
        $user = $this->{users}->getCanonicalUserID($user);
        return '' unless $user;
        return ''
          if ( $Foswiki::cfg{AntiSpam}{HideUserDetails}
            && !$this->{users}->isAdmin( $this->{user} )
            && $user ne $this->{user} );
    }

    return '' unless $user;

    my $info = $format;

    if ( $info =~ /\$username/ ) {
        my $username = $this->{users}->getLoginName($user);
        $username = 'unknown' unless defined $username;
        $info =~ s/\$username/$username/g;
    }
    if ( $info =~ /\$wikiname/ ) {
        my $wikiname = $this->{users}->getWikiName($user);
        $wikiname = 'UnknownUser' unless defined $wikiname;
        $info =~ s/\$wikiname/$wikiname/g;
    }
    if ( $info =~ /\$wikiusername/ ) {
        my $wikiusername = $this->{users}->webDotWikiName($user);
        $wikiusername = "$Foswiki::cfg{UsersWebName}.UnknownUser"
          unless defined $wikiusername;
        $info =~ s/\$wikiusername/$wikiusername/g;
    }
    if ( $info =~ /\$emails/ ) {
        my $emails = join( ', ', $this->{users}->getEmails($user) );
        $info =~ s/\$emails/$emails/g;
    }
    if ( $info =~ /\$groups/ ) {
        my @groupNames;
        my $it = $this->{users}->eachMembership($user);
        while ( $it->hasNext() ) {
            my $group = $it->next();
            push( @groupNames, $group );
        }
        my $groups = join( ', ', @groupNames );
        $info =~ s/\$groups/$groups/g;
    }
    if ( $info =~ /\$cUID/ ) {
        my $cUID = $user;
        $info =~ s/\$cUID/$cUID/g;
    }
    if ( $info =~ /\$admin/ ) {
        my $admin = $this->{users}->isAdmin($user) ? 'true' : 'false';
        $info =~ s/\$admin/$admin/g;
    }

    return $info;
}

sub GROUPS {
    my ( $this, $params ) = @_;

    my $groups = $this->{users}->eachGroup();
    my @table;
    while ( $groups->hasNext() ) {
        my $group = $groups->next();

        # Nop it to prevent wikiname expansion unless the topic exists.
        my $groupLink = "<nop>$group";
        $groupLink = '[[' . $Foswiki::cfg{UsersWebName} . ".$group][$group]]"
          if (
            $this->{store}->topicExists( $Foswiki::cfg{UsersWebName}, $group )
          );
        my $descr        = "| $groupLink |";
        my $it           = $this->{users}->eachGroupMember($group);
        my $limit_output = 32;
        while ( $it->hasNext() ) {
            my $user = $it->next();
            $descr .= ' [['
              . $this->{users}->webDotWikiName($user) . ']['
              . $this->{users}->getWikiName($user) . ']]';
            if ( $limit_output == 0 ) {
                $descr .= '<div>%MAKETEXT{"user list truncated"}%</div>';
                last;
            }
            $limit_output--;
        }
        push( @table, "$descr |" );
    }

    return '| *Group* | *Members* |' . "\n" . join( "\n", sort @table );
}

1;
__DATA__
# Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008 Foswiki Contributors. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# Based on parts of Ward Cunninghams original Wiki and JosWiki.
# Copyright (C) 1998 Markus Peter - SPiN GmbH (warpi@spin.de)
# Some changes by Dave Harris (drh@bhresearch.co.uk) incorporated
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
#
# As per the GPL, removal of this notice is prohibited.
