
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
   * =response=         Pointer to the Foswiki::Response
   * =context=          Hash of context ids
   * =plugins=          Foswiki::Plugins singleton
   * =prefs=            Foswiki::Prefs singleton
   * =remoteUser=       Login ID when using ApacheLogin. Maintained for
                        compatibility only, do not use.
   * =requestedWebName= Name of web found in URL path or =web= URL parameter
   * =scriptUrlPath=    URL path to the current script. May be dynamically
                        extracted from the URL path if {GetScriptUrlFromCgi}.
                        Only required to support {GetScriptUrlFromCgi} and
                        not consistently used. Avoid.
   * =access=         Foswiki::Access singleton
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
use warnings;
use Assert;
use Cwd qw( abs_path );
use Error qw( :try );
use File::Spec               ();
use Monitor                  ();
use CGI                      ();  # Always required to get html generation tags;
use Digest::MD5              ();  # For passthru and validation
use Foswiki::Configure::Load ();

use 5.006;                        # First version to accept v-numbers.

# Item13331 - use CGI::ENCODE_ENTITIES introduced in CGI>=4.14 to restrict encoding
# in CGI's html rendering code to only these; note that CGI's default values
# still breaks some unicode byte strings
$CGI::ENCODE_ENTITIES = q{&<>"'};

#SMELL:  Perl 5.10.0 on Mac OSX Snow Leopard warns "v-string in use/require non-portable"
require 5.008_008;    # see http://foswiki.org/Development/RequirePerl588

# Site configuration constants
our %cfg;

# Other computed constants
our $foswikiLibDir;
our %regex;
our %macros;
our %contextFreeSyntax;
our $VERSION;
our $RELEASE;
our $UNICODE = 1;  # flag that extensions can use to test if the core is unicode
our $TRUE    = 1;
our $FALSE   = 0;
our $engine;
our $TranslationToken = "\0";    # Do not deprecate - used in many plugins
our $system_message;             # Important broadcast message from the system
my $bootstrap_message = '';      # Bootstrap message.

# Note: the following marker is used in text to mark RENDERZONE
# macros that have been hoisted from the source text of a page. It is
# carefully chosen so that it is (1) not normally present in written
# text (2) does not combine with other characters to form valid
# wide-byte characters and (3) does not conflict with other markers used
# by Foswiki/Render.pm
our $RENDERZONE_MARKER = "\3";

# Used by takeOut/putBack blocks
our $BLOCKID = 0;
our $OC      = "<!--\0";
our $CC      = "\0-->";

# This variable is set if Foswiki is running in unit test mode.
# It is provided so that modules can detect unit test mode to avoid
# corrupting data spaces.
our $inUnitTestMode = 0;

sub SINGLE_SINGLETONS       { 0 }
sub SINGLE_SINGLETONS_TRACE { 0 }

# Returns the full path of the directory containing Foswiki.pm
sub _getLibDir {
    return $foswikiLibDir if $foswikiLibDir;

    $foswikiLibDir = $INC{'Foswiki.pm'};

    # fix path relative to location of called script
    if ( $foswikiLibDir =~ m/^\./ ) {
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

# Character encoding/decoding stubs. Done so we can ovveride
# if necessary (e.g. on OSX we may want to monkey-patch in a
# NFC/NFD module)
#
# Note, NFC normalization is being done only for network and directory
# read operations,  but NOT for topic data. Adding normalization here
# caused performance issues because some versions of Unicode::Normalize
# have removed the XS versions.  We really only need to normalize directory
# names not file contents.

=begin TML

---++ StaticMethod decode_utf8($octets) -> $unicode

Decode a binary string of octets known to be encoded using UTF-8 into
perl characters (unicode).

=cut

*decode_utf8 = \&Encode::decode_utf8;

=begin TML

---++ StaticMethod encode_utf8($unicode) -> $octets

Encode a perl character string into a binary string of octets
encoded using UTF-8.

=cut

*encode_utf8 = \&Encode::encode_utf8;

BEGIN {

    # First thing we do; make sure we print unicode errors
    binmode( STDERR, ":utf8" );

    #Monitor::MARK("Start of BEGIN block in Foswiki.pm");
    if (DEBUG) {
        if ( not $Assert::soft ) {

            # If ASSERTs are on (and not soft), then warnings are errors.
            # Paranoid, but the only way to be sure we eliminate them all.
            # ASSERTS are turned on by defining the environment variable
            # FOSWIKI_ASSERTS. If ASSERTs are off, this is assumed to be a
            # production environment, and no stack traces or paths are
            # output to the browser.
            $SIG{'__WARN__'} = sub { die @_ };
            $Error::Debug = 1;    # verbose stack traces, please
        }
        else {

            # ASSERTs are soft, so warnings are not errors
            # but ASSERTs are enabled. This is useful for tracking down
            # problems that only manifest on production servers.
            $Error::Debug = 0;    # no verbose stack traces
        }
    }
    else {
        $Error::Debug = 0;        # no verbose stack traces
    }

    # DO NOT CHANGE THE FORMAT OF $VERSION.
    # Use $RELEASE for a descriptive version.
    use version 0.77; $VERSION = version->declare('v2.1.4');
    $RELEASE = 'Foswiki-2.1.4';

    # Default handlers for different %TAGS%
    # Where an entry is set as 'undef', the tag will be demand-loaded
    # from Foswiki::Macros, if it is used. This tactic is used to reduce
    # the load time of this module, especially when it is used from
    # REST handlers.
    %macros = (
        ADDTOHEAD => undef,

        # deprecated, use ADDTOZONE instead
        ADDTOZONE     => undef,
        ALLVARIABLES  => sub { $_[0]->{prefs}->stringify() },
        ATTACHURL     => undef,
        ATTACHURLPATH => undef,
        DATE          => sub {
            Foswiki::Time::formatTime(
                time(),
                $Foswiki::cfg{DefaultDateFormat},
                $Foswiki::cfg{DisplayTimeValues}
            );
        },
        DISPLAYTIME => sub {
            Foswiki::Time::formatTime(
                time(),
                $_[1]->{_DEFAULT} || '',
                $Foswiki::cfg{DisplayTimeValues}
            );
        },
        ENCODE            => undef,
        ENV               => undef,
        EXPAND            => undef,
        FORMAT            => undef,
        FORMFIELD         => undef,
        FOSWIKI_BROADCAST => sub { $Foswiki::system_message || '' },
        GMTIME            => sub {
            Foswiki::Time::formatTime( time(), $_[1]->{_DEFAULT} || '',
                'gmtime' );
        },
        GROUPINFO => undef,
        GROUPS    => undef,
        HTTP_HOST =>

          #deprecated functionality, now implemented using %ENV%
          sub { $_[0]->{request}->header('Host') || '' },
        HTTP                 => undef,
        HTTPS                => undef,
        ICON                 => undef,
        ICONURL              => undef,
        ICONURLPATH          => undef,
        IF                   => undef,
        INCLUDE              => undef,
        INTURLENCODE         => undef,
        LANGUAGE             => sub { $_[0]->i18n->language(); },
        LANGUAGES            => undef,
        MAKETEXT             => undef,
        META                 => undef,                              # deprecated
        METASEARCH           => undef,                              # deprecated
        NONCE                => undef,
        PENDINGREGISTRATIONS => undef,
        PERLDEPENDENCYREPORT => undef,
        NOP =>

          # Remove NOP tag in template topics but show content.
          # Used in template _topics_ (not templates, per se, but
          # topics used as templates for new topics)
          sub { $_[1]->{_RAW} ? $_[1]->{_RAW} : '<nop>' },
        PLUGINVERSION => sub {
            $_[0]->{plugins}->getPluginVersion( $_[1]->{_DEFAULT} );
        },
        PUBURL      => undef,
        PUBURLPATH  => undef,
        QUERY       => undef,
        QUERYPARAMS => undef,
        QUERYSTRING => sub {
            my $s = $_[0]->{request}->queryString();

            # Aggressively encode QUERYSTRING (even more than the
            # default) because it might be leveraged for XSS
            $s =~ s/(['\/])/'%'.sprintf('%02x', ord($1))/ge;
            return $s;
        },
        RELATIVETOPICPATH => undef,
        REMOTE_ADDR =>

          # DEPRECATED, now implemented using %ENV%
          #move to compatibility plugin in Foswiki 2.0
          sub { $_[0]->{request}->remoteAddress() || ''; },
        REMOTE_PORT =>

          # DEPRECATED
          # CGI/1.1 (RFC 3875) doesn't specify REMOTE_PORT,
          # but some webservers implement it. However, since
          # it's not RFC compliant, Foswiki should not rely on
          # it. So we get more portability.
          sub { '' },
        REMOTE_USER =>

          # DEPRECATED
          sub { $_[0]->{request}->remoteUser() || '' },
        RENDERZONE    => undef,
        REVINFO       => undef,
        REVTITLE      => undef,
        REVARG        => undef,
        SCRIPTNAME    => sub { $_[0]->{request}->action() },
        SCRIPTURL     => undef,
        SCRIPTURLPATH => undef,
        SEARCH        => undef,
        SEP =>

          # Shortcut to %TMPL:P{"sep"}%
          sub { $_[0]->templates->expandTemplate('sep') },
        SERVERTIME => sub {
            Foswiki::Time::formatTime( time(), $_[1]->{_DEFAULT} || '',
                'servertime' );
        },
        SERVERINFORMATION   => undef,
        SET                 => undef,
        SHOWPREFERENCE      => undef,
        SPACEDTOPIC         => undef,
        SPACEOUT            => undef,
        'TMPL:P'            => sub { $_[0]->templates->tmplP( $_[1] ) },
        TOPICLIST           => undef,
        URLENCODE           => undef,
        URLPARAM            => undef,
        USERINFO            => undef,
        USERNAME            => undef,
        VAR                 => undef,
        WEBLIST             => undef,
        WIKINAME            => undef,
        WIKIUSERNAME        => undef,
        DISPLAYDEPENDENCIES => undef,

        # Constant tag strings _not_ dependent on config. These get nicely
        # optimised by the compiler.
        STOPSECTION  => sub { '' },
        ENDSECTION   => sub { '' },
        WIKIVERSION  => sub { $VERSION },
        WIKIRELEASE  => sub { $RELEASE },
        STARTSECTION => sub { '' },
        STARTINCLUDE => sub { '' },
        STOPINCLUDE  => sub { '' },
        ENDINCLUDE   => sub { '' },
    );
    $contextFreeSyntax{IF} = 1;

    # Load LocalSite.cfg
    if ( Foswiki::Configure::Load::readConfig( 0, 0, 0 ) ) {
        $Foswiki::cfg{isVALID} = 1;
    }
    else {
        require Foswiki::Configure::Bootstrap;
        $bootstrap_message = Foswiki::Configure::Bootstrap::bootstrapConfig();
        eval 'require Foswiki::Plugins::ConfigurePlugin';
        die
"LocalSite.cfg load failed, and ConfigurePlugin could not be loaded: $@"
          if $@;
    }

    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }

    # Set environment var FOSWIKI_NOTAINT to disable taint checks even
    # if Taint::Runtime is installed
    elsif ( DEBUG && !$ENV{FOSWIKI_NOTAINT} ) {
        eval { require Taint::Runtime; };
        if ($@) {
            print STDERR
"DEVELOPER WARNING: taint mode could not be enabled. Is Taint::Runtime installed?\n";
        }
        else {
            # Enable taint checking
            Taint::Runtime::_taint_start();
        }
    }

    # If not set, default to strikeone validation
    $Foswiki::cfg{Validation}{Method} ||= 'strikeone';
    $Foswiki::cfg{Validation}{ValidForTime} = $Foswiki::cfg{LeaseLength}
      unless defined $Foswiki::cfg{Validation}{ValidForTime};
    $Foswiki::cfg{Validation}{MaxKeys} = 1000
      unless defined $Foswiki::cfg{Validation}{MaxKeys};

    # Constant tags dependent on the config
    $macros{ALLOWLOGINNAME} =
      sub { $Foswiki::cfg{Register}{AllowLoginName} || 0 };
    $macros{AUTHREALM}      = sub { $Foswiki::cfg{AuthRealm} };
    $macros{DEFAULTURLHOST} = sub { $Foswiki::cfg{DefaultUrlHost} };
    $macros{HOMETOPIC}      = sub { $Foswiki::cfg{HomeTopicName} };
    $macros{LOCALSITEPREFS} = sub { $Foswiki::cfg{LocalSitePreferences} };
    $macros{NOFOLLOW} =
      sub { $Foswiki::cfg{NoFollow} ? 'rel=' . $Foswiki::cfg{NoFollow} : '' };
    $macros{NOTIFYTOPIC}       = sub { $Foswiki::cfg{NotifyTopicName} };
    $macros{SCRIPTSUFFIX}      = sub { $Foswiki::cfg{ScriptSuffix} };
    $macros{STATISTICSTOPIC}   = sub { $Foswiki::cfg{Stats}{TopicName} };
    $macros{SYSTEMWEB}         = sub { $Foswiki::cfg{SystemWebName} };
    $macros{TRASHWEB}          = sub { $Foswiki::cfg{TrashWebName} };
    $macros{SANDBOXWEB}        = sub { $Foswiki::cfg{SandboxWebName} };
    $macros{WIKIADMINLOGIN}    = sub { $Foswiki::cfg{AdminUserLogin} };
    $macros{USERSWEB}          = sub { $Foswiki::cfg{UsersWebName} };
    $macros{WEBPREFSTOPIC}     = sub { $Foswiki::cfg{WebPrefsTopicName} };
    $macros{WIKIPREFSTOPIC}    = sub { $Foswiki::cfg{SitePrefsTopicName} };
    $macros{WIKIUSERSTOPIC}    = sub { $Foswiki::cfg{UsersTopicName} };
    $macros{WIKIWEBMASTER}     = sub { $Foswiki::cfg{WebMasterEmail} };
    $macros{WIKIWEBMASTERNAME} = sub { $Foswiki::cfg{WebMasterName} };
    $macros{WIKIAGENTEMAIL}    = sub {
        $Foswiki::cfg{Email}{WikiAgentEmail} || $Foswiki::cfg{WebMasterEmail};
    };
    $macros{WIKIAGENTNAME} = sub {
        $Foswiki::cfg{Email}{WikiAgentName} || $Foswiki::cfg{WebMasterName};
    };

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

    $macros{CHARSET} = sub {
        'utf-8';
    };

    $macros{LANG} = sub {
        my $lang = 'en';    # the default
        if (   $Foswiki::cfg{UseLocale}
            && $Foswiki::cfg{Site}{Locale} =~ m/^([a-z]+)(?:_([a-z]+))?/i )
        {

# Locale identifiers use _ as the separator in the language, but a minus sign is required
# for HTML (see http://www.ietf.org/rfc/rfc1766.txt)
            $lang = $1 . ( $2 ? "-$2" : '' );
        }
        return $lang;
    };

    # Set up pre-compiled regexes for use in rendering.
    # In the regex hash, all precompiled REs have "Regex" at the
    # end of the name. Anything else is a string, either intended
    # for use as a character class, or as a sub-expression in
    # another compiled RE.

    # Character class components for use in regexes.
    # (Pre-UTF-8 compatibility; not used in core)
    $regex{upperAlpha}    = '[:upper:]';
    $regex{lowerAlpha}    = '[:lower:]';
    $regex{numeric}       = '[:digit:]';
    $regex{mixedAlpha}    = '[:alpha:]';
    $regex{mixedAlphaNum} = '[:alnum:]';
    $regex{lowerAlphaNum} = '[:lower:][:digit:]';
    $regex{upperAlphaNum} = '[:upper:][:digit:]';

    # Compile regexes for efficiency and ease of use
    # Note: qr// locks in regex modes (i.e. '-xism' here) - see Friedl
    # book at http://regex.info/.

    $regex{linkProtocolPattern} = $Foswiki::cfg{LinkProtocolPattern}
      || '(file|ftp|gopher|https|http|irc|mailto|news|nntp|telnet)';

    # Header patterns based on '+++'. The '###' are reserved for numbered
    # headers
    # '---++ Header', '---## Header'
    $regex{headerPatternDa} = qr/^---+(\++|\#+)(.*)$/m;

    # '<h6>Header</h6>
    $regex{headerPatternHt} = qr/^<h([1-6])>(.+?)<\/h\1>/mi;

    # '---++!! Header' or '---++ Header %NOTOC% ^top'
    $regex{headerPatternNoTOC} = '(\!\!+|%NOTOC%)';

    # Foswiki concept regexes
    $regex{wikiWordRegex} = qr(
            [[:upper:]]+
            [[:lower:][:digit:]]+
            [[:upper:]]+
            [[:alnum:]]*
       )xo;
    $regex{webNameBaseRegex} = qr/[[:upper:]]+[[:alnum:]_]*/;
    if ( $Foswiki::cfg{EnableHierarchicalWebs} ) {
        $regex{webNameRegex} = qr(
                $regex{webNameBaseRegex}
                (?:(?:[\.\/]$regex{webNameBaseRegex})+)*
           )xo;
    }
    else {
        $regex{webNameRegex} = $regex{webNameBaseRegex};
    }
    $regex{defaultWebNameRegex} = qr/_[[:alnum:]_]+/;
    $regex{anchorRegex}         = qr/\#[[:alnum:]:._]+/;
    my $abbrevLength = $Foswiki::cfg{AcronymLength} || 3;
    $regex{abbrevRegex} = qr/[[:upper:]]{$abbrevLength,}s?\b/;

    $regex{topicNameRegex} =
      qr/(?:(?:$regex{wikiWordRegex})|(?:$regex{abbrevRegex}))/;

    # Email regex, e.g. for WebNotify processing and email matching
    # during rendering.

    my $emailAtom = qr([A-Z0-9\Q!#\$%&'*+-/=?^_`{|}~\E])i;    # Per RFC 5322 ]

    # Valid TLD's at http://data.iana.org/TLD/tlds-alpha-by-domain.txt
    # Version 2012022300, Last Updated Thu Feb 23 15:07:02 2012 UTC
    my $validTLD = $Foswiki::cfg{Email}{ValidTLD};

    unless ( eval { qr/$validTLD/ } ) {
        $validTLD =
qr(AERO|ARPA|ASIA|BIZ|CAT|COM|COOP|EDU|GOV|INFO|INT|JOBS|MIL|MOBI|MUSEUM|NAME|NET|ORG|PRO|TEL|TRAVEL|XXX)i;

# Too early to log, should do something here other than die (which prevents fixing)
# warn is trapped and turned into a die...
#warn( "{Email}{ValidTLD} does not compile, using default" );
    }

    $regex{emailAddrRegex} = qr(
       (?:                            # LEFT Side of Email address
         (?:$emailAtom+                  # Valid characters left side of email address
           (?:\.$emailAtom+)*            # And 0 or more dotted atoms
         )
       |
         (?:"[\x21\x23-\x5B\x5D-\x7E\s]+?")   # or a quoted string per RFC 5322
       )
       @
       (?:                          # RIGHT side of Email address
         (?:                           # FQDN
           [a-z0-9-]+                     # hostname part
           (?:\.[a-z0-9-]+)*              # 0 or more alphanumeric domains following a dot.
           \.(?:                          # TLD
              (?:[a-z]{2,2})                 # 2 character TLD
              |
              $validTLD                      # TLD's longer than 2 characters
           )
         )
         |
           (?:\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])      # dotted triplets IP Address
         )
       )oxi;

    # Item11185: This is how things were before we began Operation Unicode:
    #
    # $regex{filenameInvalidCharRegex} = qr/[^[:alnum:]\. _-]/;
    #
    # It was only used in Foswiki::Sandbox::sanitizeAttachmentName(), which now
    # uses $Foswiki::cfg{NameFilter} instead.
    # See RobustnessTests::test_sanitizeAttachmentName
    #
    # Actually, this is used in GenPDFPrincePlugin; let's copy NameFilter
    $regex{webTopicInvalidCharRegex} = qr/$Foswiki::cfg{NameFilter}/;
    $regex{filenameInvalidCharRegex} = qr/$Foswiki::cfg{AttachmentNameFilter}/;

    # Multi-character alpha-based regexes
    $regex{mixedAlphaNumRegex} = qr/[[:alnum:]]*/;

    # %TAG% name
    $regex{tagNameRegex} = '[A-Za-z][A-Za-z0-9_:]*';

    # Set statement in a topic
    $regex{bulletRegex} = '^(?:\t|   )+\*';
    $regex{setRegex}    = $regex{bulletRegex} . '\s+(Set|Local)\s+';
    $regex{setVarRegex} =
      $regex{setRegex} . '(' . $regex{tagNameRegex} . ')\s*=\s*(.*)$';

    # Character encoding regexes

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

    $regex{validUtf8StringRegex} = qr/^(?:$regex{validUtf8CharRegex})+$/;

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

    #Monitor::MARK('End of BEGIN block in Foswiki.pm');
}

# Components that all requests need
use Foswiki::Response ();
use Foswiki::Request  ();
use Foswiki::Logger   ();
use Foswiki::Meta     ();
use Foswiki::Sandbox  ();
use Foswiki::Time     ();
use Foswiki::Prefs    ();
use Foswiki::Plugins  ();
use Foswiki::Users    ();

=begin TML

---++ ObjectMethod writeCompletePage( $text, $pageType, $contentType )

Write a complete HTML page with basic header to the browser.
   * =$text= is the text of the page script (&lt;html&gt; to &lt;/html&gt; if it's HTML)
   * =$pageType= - May be "edit", which will cause headers to be generated that force
     caching for 24 hours, to prevent Codev.BackFromPreviewLosesText bug, which caused
     data loss with IE5 and IE6.
   * =$contentType= - page content type | text/html

This method removes noautolink and nop tags before outputting the page unless
$contentType is text/plain.

=cut

sub writeCompletePage {
    my ( $this, $text, $pageType, $contentType ) = @_;

    # true if the body is to be output without encoding to utf8
    # first. This is the case if the body has been gzipped and/or
    # rendered from the cache
    my $binary_body = 0;

    $contentType ||= 'text/html';

    my $cgis = $this->{users}->getCGISession();
    if (   $cgis
        && $contentType =~ m!^text/html!
        && $Foswiki::cfg{Validation}{Method} ne 'none' )
    {

        # Don't expire the validation key through login, or when
        # endpoint is an error.
        Foswiki::Validation::expireValidationKeys($cgis)
          unless ( $this->{request}->action() eq 'login'
            or ( $ENV{REDIRECT_STATUS} || 0 ) >= 400 );

        my $usingStrikeOne = $Foswiki::cfg{Validation}{Method} eq 'strikeone';
        if ($usingStrikeOne) {

            # add the validation cookie
            my $valCookie = Foswiki::Validation::getCookie($cgis);
            $valCookie->secure( $this->{request}->secure );
            $this->{response}
              ->cookies( [ $this->{response}->cookies, $valCookie ] );

            # Add the strikeone JS module to the page.
            my $src = (DEBUG) ? '.uncompressed' : '';
            $this->zones()->addToZone(
                'script',
                'JavascriptFiles/strikeone',
                '<script type="text/javascript" src="'
                  . $this->getPubURL(
                    $Foswiki::cfg{SystemWebName}, 'JavascriptFiles',
                    "strikeone$src.js"
                  )
                  . '"></script>',
                'JQUERYPLUGIN'
            );

            # Add the onsubmit handler to the form
            $text =~ s/(<form[^>]*method=['"]POST['"][^>]*>)/
                Foswiki::Validation::addOnSubmit($1)/gei;
        }

        my $context =
          $this->{request}->url( -full => 1, -path => 1, -query => 1 ) . time();

        # Inject validation key in HTML forms
        $text =~ s/(<form[^>]*method=['"]POST['"][^>]*>)/
          $1 . Foswiki::Validation::addValidationKey(
              $cgis, $context, $usingStrikeOne )/gei;

        #add validation key to HTTP header so we can update it for ajax use
        $this->{response}->pushHeader(
            'X-Foswiki-Validation',
            Foswiki::Validation::generateValidationKey(
                $cgis, $context, $usingStrikeOne
            )
        ) if ($cgis);
    }

    if ( $this->{zones} ) {

        $text = $this->zones()->_renderZones($text);
    }

    # Validate format of content-type (defined in rfc2616)
    my $tch = qr/[^\[\]()<>@,;:\\"\/?={}\s]/;
    if ( $contentType =~ m/($tch+\/$tch+(\s*;\s*$tch+=($tch+|"[^"]*"))*)$/i ) {
        $contentType = $1;
    }
    else {
        # SMELL: can't compute; faking content-type for backwards compatibility;
        # any other information might become bogus later anyway
        $contentType = "text/plain;contenttype=invalid";
    }
    my $hdr = "Content-type: " . $1 . "\r\n";

    # Call final handler
    $this->{plugins}->dispatch( 'completePageHandler', $text, $hdr );

    # cache final page, but only view and rest
    my $cachedPage;
    if ( $contentType ne 'text/plain' ) {

        # Remove <nop> and <noautolink> tags
        $text =~ s/([\t ]?)[ \t]*<\/?(nop|noautolink)\/?>/$1/gis;
        if ( $Foswiki::cfg{Cache}{Enabled}
            && ( $this->inContext('view') || $this->inContext('rest') ) )
        {
            $cachedPage = $this->{cache}->cachePage( $contentType, $text );
            $this->{cache}->renderDirtyAreas( \$text )
              if $cachedPage && $cachedPage->{isdirty};
        }

        # remove <dirtyarea> tags
        $text =~ s/<\/?dirtyarea[^>]*>//g;

        # Check that the templates specified clean HTML
        if (DEBUG) {

            # When tracing is enabled in Foswiki::Templates, then there will
            # always be a <!--bodyend--> after </html>. So we need to disable
            # this check.
            require Foswiki::Templates;
            if (   !Foswiki::Templates->TRACE
                && $contentType =~ m#text/html#
                && $text =~ m#</html>(.*?\S.*)$#s )
            {
                ASSERT( 0, <<BOGUS );
Junk after </html>: $1. Templates may be bogus
- Check for excess blank lines at ends of .tmpl files
-  or newlines after %TMPL:INCLUDE
- You can enable TRACE in Foswiki::Templates to help debug
BOGUS
            }
        }
    }

    $this->{response}->pushHeader( 'X-Foswiki-Monitor-renderTime',
        $this->{request}->getTime() );

    my $hopts = { 'Content-Type' => $contentType };

    $this->setCacheControl( $pageType, $hopts );

    if ($cachedPage) {
        $text = '' unless $this->setETags( $cachedPage, $hopts );
    }

    if ( $Foswiki::cfg{HttpCompress} && length($text) ) {

        # Generate a zipped page, if the client accepts them

        if ( my $encoding = _gzipAccepted() ) {
            $hopts->{'Content-Encoding'} = $encoding;
            $hopts->{'Vary'}             = 'Accept-Encoding';

            # check if we take the version from the cache. NOTE: we don't
            # set X-Foswiki-Pagecache because this is *not* coming from
            # the cache (well it is, but it was only just put there)
            if ( $cachedPage && !$cachedPage->{isdirty} ) {
                $text = $cachedPage->{data};
            }
            else {
                # Not available from the cache, or it has dirty areas
                require Compress::Zlib;
                $text = Compress::Zlib::memGzip( encode_utf8($text) );
            }
            $binary_body = 1;
        }
    }    # Otherwise fall through and generate plain text

    # Generate (and print) HTTP headers.
    $this->generateHTTPHeaders($hopts);

    if ($binary_body) {
        $this->{response}->body($text);
    }
    else {
        $this->{response}->print($text);
    }
}

# PRIVATE
sub _gzipAccepted {
    my $encoding;
    if ( ( $ENV{'HTTP_ACCEPT_ENCODING'} || '' ) =~
        /(?:^|\b)((?:x-)?gzip)(?:$|\b)/ )
    {
        $encoding = $1;
    }
    elsif ( $ENV{'HTTP2'} ) {

        # SMELL: $ENV{'HTTP2'} is a non-standard way to detect http2 protocol
        $encoding = 'gzip';
    }
    return $encoding;
}

=begin TML

---++ ObjectMethod satisfiedByCache( $action, $web, $topic ) -> $boolean

Try and satisfy the current request for the given web.topic from the cache, given
the current action (view, edit, rest etc).

If the action is satisfied, the cache content is written to the output and
true is returned. Otherwise ntohing is written, and false is returned.

Designed for calling from Foswiki::UI::*

=cut

sub satisfiedByCache {
    my ( $this, $action, $web, $topic ) = @_;

    my $cache = $this->{cache};
    return 0 unless $cache;

    my $cachedPage = $cache->getPage( $web, $topic ) if $cache;
    return 0 unless $cachedPage;

    Foswiki::Func::writeDebug("found $web.$topic for $action in cache")
      if Foswiki::PageCache::TRACE();
    if ( int( $this->{response}->status() || 200 ) >= 500 ) {
        Foswiki::Func::writeDebug(
            "Cache retrieval skipped due to non-200 status code "
              . $this->{response}->status() )
          if DEBUG;
        return 0;
    }
    Monitor::MARK("found page in cache");

    my $hdrs = { 'Content-Type' => $cachedPage->{contenttype} };

    # render uncacheable areas
    my $text = $cachedPage->{data};

    if ( $cachedPage->{isdirty} ) {
        $cache->renderDirtyAreas( \$text );

        # dirty pages are cached in unicode
        $text = encode_utf8($text);
    }
    elsif ( $Foswiki::cfg{HttpCompress} ) {

        # Does the client accept gzip?
        if ( my $encoding = _gzipAccepted() ) {

            # Cache has compressed data, just whack it out
            $hdrs->{'Content-Encoding'} = $encoding;
            $hdrs->{'Vary'}             = 'Accept-Encoding';

        }
        else {
        # e.g. CLI request satisfied from the cache, or old browser that doesn't
        # support gzip. Non-isdirty pages are cached already utf8-encoded, so
        # all we have to do is unzip.
            require Compress::Zlib;
            $text = Compress::Zlib::memGunzip( $cachedPage->{data} );
        }
    }    # else { Non-isdirty pages are stored already utf8-encoded }

    # set status
    my $response = $this->{response};
    if ( $cachedPage->{status} == 302 ) {
        $response->redirect( $cachedPage->{location} );
    }
    else {

     # See Item9941
     # Don't allow a 200 status to overwrite a status (possibly an error status)
     # coming from elsewhere in the code. Note that 401's are not cached (they
     # fail Foswiki::PageCache::isCacheable) but all other statuses are.
     # SMELL: Cdot doesn't think any other status can get this far.
        $response->status( $cachedPage->{status} )
          unless int( $cachedPage->{status} ) == 200;
    }

    # set remaining headers
    # Mark the response so we know it was satisfied from the cache
    $hdrs->{'X-Foswiki-PageCache'} = 1;
    $text = undef unless $this->setETags( $cachedPage, $hdrs );
    $this->generateHTTPHeaders($hdrs);

    # send it out
    $response->body($text) if defined $text;

    Monitor::MARK('Wrote HTML');
    $this->logger->log(
        {
            level    => 'info',
            action   => $action,
            webTopic => $web . '.' . $topic,
            extra    => '(cached)',
        }
    );

    return 1;
}

=begin TML

---++ ObjectMethod setCacheControl( $pageType, \%hopts )

Set the cache control headers in a response

   * =$pageType= - page type - 'view', ;edit' etc
   * =\%hopts - ref to partially filled in hash of headers

=cut

sub setCacheControl {
    my ( $this, $pageType, $hopts ) = @_;

    if ( $pageType && $pageType eq 'edit' ) {

        # Edit pages - future versions will extend to
        # of other types of page, with expiry time driven by page type.

        # Get time now in HTTP header format
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
        $hopts->{'Cache-Control'} = "max-age=$expireSeconds";
    }
    else {

        # we need to force the browser into a check on every
        # request; let the server decide on an 304 as below
        my $cacheControl = 'max-age=0';

        # allow the admin to disable us from setting the max-age, as then
        # it can't be set by apache
        $cacheControl = $Foswiki::cfg{BrowserCacheControl}->{ $this->{webName} }
          if ( $Foswiki::cfg{BrowserCacheControl}
            && defined(
                $Foswiki::cfg{BrowserCacheControl}->{ $this->{webName} } ) );

        # don't remove the 'if'; we need the header to not be there at
        # all for the browser to use the cached version
        $hopts->{'Cache-Control'} = $cacheControl if ( $cacheControl ne '' );
    }
}

=begin TML

---++ ObjectMethod setETags( $cachedPage, \%hopts ) -> $boolean

Set etags (and modify status) depending on what the cached page specifies.
Return 1 if the page has been modified since it was last retrieved, 0 otherwise.

   * =$cachedPage= - page cache to use
   * =\%hopts - ref to partially filled in hash of headers

=cut

sub setETags {
    my ( $this, $cachedPage, $hopts ) = @_;

    # check etag and last modification time
    my $etag         = $cachedPage->{etag};
    my $lastModified = $cachedPage->{lastmodified};

    $hopts->{'ETag'}          = $etag         if $etag;
    $hopts->{'Last-Modified'} = $lastModified if $lastModified;

    # only send a 304 if both criteria are true
    return 1
      unless (
           $etag
        && $lastModified

        && $ENV{'HTTP_IF_NONE_MATCH'}
        && $etag eq $ENV{'HTTP_IF_NONE_MATCH'}

        && $ENV{'HTTP_IF_MODIFIED_SINCE'}
        && $lastModified eq $ENV{'HTTP_IF_MODIFIED_SINCE'}
      );

    # finally decide on a 304 reply
    $hopts->{'Status'} = '304 Not Modified';

    #print STDERR "NOT modified\n";
    return 0;
}

=begin TML

---++ ObjectMethod generateHTTPHeaders( \%hopts )

All parameters are optional.
   * =\%hopts - optional ref to partially filled in hash of headers (will be written to)

=cut

sub generateHTTPHeaders {
    my ( $this, $hopts ) = @_;

    $hopts ||= {};

    # DEPRECATED plugins header handler. Plugins should use
    # modifyHeaderHandler instead.
    my $pluginHeaders =
      $this->{plugins}->dispatch( 'writeHeaderHandler', $this->{request} )
      || '';
    if ($pluginHeaders) {
        foreach ( split /\r?\n/, $pluginHeaders ) {

            # Implicit untaint OK; data from plugin handler
            if (m/^([\-a-z]+): (.*)$/i) {
                $hopts->{$1} = $2;
            }
        }
    }

    my $contentType = $hopts->{'Content-Type'};
    $contentType = 'text/html' unless $contentType;
    $contentType .= '; charset=utf-8'
      if $contentType =~ m!^text/!
      && $contentType !~ /\bcharset\b/;

    # use our version of the content type
    $hopts->{'Content-Type'} = $contentType;

    # These headers don't appear to be used, and can leak stuff.
    $hopts->{'X-FoswikiAction'} = $this->{request}->action if DEBUG;
    $hopts->{'X-FoswikiURI'}    = $this->{request}->uri    if DEBUG;

    # Turn off XSS protection in DEBUG so it doesn't mask problems
    $hopts->{'X-XSS-Protection'} = 0 if DEBUG;

    $this->{plugins}
      ->dispatch( 'modifyHeaderHandler', $hopts, $this->{request} );

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
    if ( $redirect =~ m!^(.*?://[^/?#]*)! ) {

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

If the CGI parameter 'redirectto' is present on the query, then will validate
that it is a legal redirection target (url or topic name). If 'redirectto'
is not present on the query, performs the same steps on $url.

Returns undef if the target is not valid, and the target URL otherwise.

=cut

sub redirectto {
    my ( $this, $url ) = @_;

    my $redirecturl = $this->{request}->param('redirectto');
    $redirecturl = $url unless $redirecturl;

    return unless $redirecturl;

    if ( $redirecturl =~ m#^$regex{linkProtocolPattern}://# ) {

        # assuming URL
        return $redirecturl if _isRedirectSafe($redirecturl);
        return;
    }

    my @attrs = ();

    # capture anchor
    if ( $redirecturl =~ s/#(.*)// ) {
        push( @attrs, '#' => $1 );
    }

    # capture params
    if ( $redirecturl =~ s/\?(.*)// ) {
        push( @attrs, map { split( '=', $_, 2 ) } split( /[;&]/, $1 ) );
    }

    # assuming 'web.topic' or 'topic'
    my ( $w, $t ) =
      $this->normalizeWebTopicName( $this->{webName}, $redirecturl );

    return $this->getScriptUrl( 0, 'view', $w, $t, @attrs );
}

=begin TML

---++ StaticMethod splitAnchorFromUrl( $url ) -> ( $url, $anchor )

Takes a full url (including possible query string) and splits off the anchor.
The anchor includes the # sign. Returns an empty string if not found in the url.

=cut

sub splitAnchorFromUrl {
    my ($url) = @_;

    ( $url, my $anchor ) = $url =~ m/^(.*?)(#(.*?))*$/;
    return ( $url, $anchor );
}

=begin TML

---++ ObjectMethod redirect( $url, $passthrough, $status )

   * $url - url or topic to redirect to
   * $passthrough - (optional) parameter to pass through current query
     parameters (see below)
   * $status - HTTP status code (30x) to redirect with. Defaults to 302.

Redirects the request to =$url=, *unless*
   1 It is overridden by a plugin declaring a =redirectCgiQueryHandler=
     (a dangerous, deprecated handler!)
   1 =$session->{request}= is =undef=
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
    my ( $this, $url, $passthru, $status ) = @_;
    ASSERT( defined $url ) if DEBUG;

    return unless $this->{request};

    ( $url, my $anchor ) = splitAnchorFromUrl($url);

    if ( $passthru && defined $this->{request}->method() ) {
        my $existing = '';
        if ( $url =~ s/\?(.*)$// ) {
            $existing = $1;    # implicit untaint OK; recombined later
        }
        if ( uc( $this->{request}->method() ) eq 'POST' ) {

            # Redirecting from a post to a get
            my $cache = $this->cacheQuery();
            if ($cache) {
                if ( $url eq '/' ) {
                    $url = $this->getScriptUrl( 1, 'view' );
                }
                $url .= $cache;
            }
        }
        else {

            # Redirecting a get to a get; no need to use passthru
            if ( $this->{request}->query_string() ) {
                $url .= '?' . $this->{request}->query_string();
            }
            if ($existing) {
                if ( $url =~ m/\?/ ) {
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
            $this->{webName}   || $Foswiki::cfg{UsersWebName},
            $this->{topicName} || $Foswiki::cfg{HomeTopicName},
            template => 'oopsredirectdenied',
            def      => 'redirect_denied',
            param1   => "$url",
            param2   => "$Foswiki::cfg{DefaultUrlHost}",
        );
    }

    $url .= $anchor if $anchor;

    # Dangerous, deprecated handler! Might work, probably won't.
    return
      if ( $this->{plugins}
        ->dispatch( 'redirectCgiQueryHandler', $this->{response}, $url ) );

    $url = $this->getLoginManager()->rewriteRedirectUrl($url);

    # Foswiki::Response::redirect doesn't automatically pass on the cookies
    # for us, so we have to do it explicitly; otherwise the session cookie
    # won't get passed on.
    $this->{response}->redirect(
        -url     => $url,
        -cookies => $this->{response}->cookies(),
        -status  => $status,
    );
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

    return '' unless ( $query->param() );

    # Don't double-cache
    return '' if ( $query->param('foswiki_redirect_cache') );

    require Foswiki::Request::Cache;
    my $uid = Foswiki::Request::Cache->new()->save($query);
    if ( $Foswiki::cfg{UsePathForRedirectCache} ) {
        return '/foswiki_redirect_cache/' . $uid;
    }
    else {
        return '?foswiki_redirect_cache=' . $uid;
    }
}

=begin TML

---++ ObjectMethod getCGISession() -> $cgisession

Get the CGI::Session object associated with this session, if there is
one. May return undef.

=cut

sub getCGISession {
    $_[0]->{users}->getCGISession();
}

=begin TML

---++ ObjectMethod getLoginManager() -> $loginManager

Get the Foswiki::LoginManager object associated with this session, if there is
one. May return undef.

=cut

sub getLoginManager {
    $_[0]->{users}->getLoginManager();
}

=begin TML

---++ StaticMethod isValidWikiWord( $name ) -> $boolean

Check for a valid WikiWord or WikiName

=cut

sub isValidWikiWord {
    my $name = shift || '';
    return ( $name =~ m/^$regex{wikiWordRegex}$/ );
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

    # Make sure any name is supported by the Store encoding
    if (   $Foswiki::cfg{Store}{Encoding}
        && $Foswiki::cfg{Store}{Encoding} ne 'utf-8'
        && $name =~ m/[^[:ascii:]]+/ )
    {
        my $badName = 0;
        try {
            Foswiki::Store::encode( $name, 1 );
        }
        catch Error with {
            $badName = 1;
        };
        return 0 if $badName;
    }

    return 1 if ( $name =~ m/^$regex{topicNameRegex}$/ );
    return 0 unless $nonww;
    return 0 if $name =~ m/$cfg{NameFilter}/;
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
    return 1 if ( $sys && $name =~ m/^$regex{defaultWebNameRegex}$/ );
    return ( $name =~ m/^$regex{webNameRegex}$/ );
}

=begin TML

---++ StaticMethod isValidEmailAddress( $name ) -> $boolean

STATIC Check for a valid email address name.

=cut

# Note: must work on tainted names.
sub isValidEmailAddress {
    my $name = shift || '';
    return $name =~ m/^$regex{emailAddrRegex}$/;
}

=begin TML

---++ ObjectMethod getSkin () -> $string

Get the currently requested skin path

=cut

sub getSkin {
    my $this = shift;

    my @skinpath;
    my $skins;

    if ( $this->{request} ) {
        $skins = $this->{request}->param('cover');
        if ( defined $skins
            && $skins =~ m/([[:alnum:].,\s]+)/ )
        {

            # Implicit untaint ok - validated
            $skins = $1;
            push( @skinpath, split( /,\s]+/, $skins ) );
        }
    }

    $skins = $this->{prefs}->getPreference('COVER');
    if ( defined $skins
        && $skins =~ m/([[:alnum:].,\s]+)/ )
    {

        # Implicit untaint ok - validated
        $skins = $1;
        push( @skinpath, split( /[,\s]+/, $skins ) );
    }

    $skins = $this->{request} ? $this->{request}->param('skin') : undef;
    $skins = $this->{prefs}->getPreference('SKIN') unless $skins;

    if ( defined $skins && $skins =~ m/([[:alnum:].,\s]+)/ ) {

        # Implicit untaint ok - validated
        $skins = $1;
        push( @skinpath, split( /[,\s]+/, $skins ) );
    }

    return join( ',', @skinpath );
}

=begin TML

---++ ObjectMethod getScriptUrl( $absolute, $script, $web, $topic, ... ) -> $scriptURL

Returns the URL to a Foswiki script, providing the web and topic as
"path info" parameters.  The result looks something like this:
"http://host/foswiki/bin/$script/$web/$topic".
   * =...= - an arbitrary number of name,value parameter pairs that will
be url-encoded and added to the url. The special parameter name '#' is
reserved for specifying an anchor. e.g.
=getScriptUrl('x','y','view','#'=>'XXX',a=>1,b=>2)= will give
=.../view/x/y?a=1&b=2#XXX=

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

As required by RFC3986, the returned URL will only contain the
allowed characters -A-Za-z0-9_.~!*\'();:@&=+$,/?%#[]

=cut

sub getScriptUrl {
    my ( $this, $absolute, $script, $web, $topic, @params ) = @_;

    $absolute ||=
      ( $this->inContext('command_line') || $this->inContext('absolute_urls') );

    # SMELL: topics and webs that contain spaces?

    my $url;
    if ( defined $Foswiki::cfg{ScriptUrlPaths} && $script ) {
        $url = $Foswiki::cfg{ScriptUrlPaths}{$script};
    }
    unless ( defined($url) ) {
        $url = $Foswiki::cfg{ScriptUrlPath};
        if ($script) {
            $url .= '/' unless $url =~ m/\/$/;
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

    if ($topic) {
        ( $web, $topic ) = $this->normalizeWebTopicName( $web, $topic );

        $url .= urlEncode( '/' . $web . '/' . $topic );

    }
    elsif ($web) {
        $url .= urlEncode( '/' . $web );
    }
    $url .= make_params(@params);

    return $url;
}

=begin TML

---++ StaticMethod make_params(...)
Generate a URL parameters string from parameters given. A parameter
named '#' will generate a fragment identifier.

=cut

sub make_params {
    my $url = '';
    my @ps;
    my $anchor = '';
    while ( my $p = shift @_ ) {
        if ( $p eq '#' ) {
            $anchor = '#' . urlEncode( shift(@_) );
        }
        else {
            my $v = shift(@_);
            $v = '' unless defined $v;
            push( @ps, urlEncode($p) . '=' . urlEncode($v) );
        }
    }
    if ( scalar(@ps) ) {
        @ps = sort(@ps) if (DEBUG);
        $url .= '?' . join( ';', @ps );
    }
    return $url . $anchor;
}

=begin TML

---++ ObjectMethod getPubURL($web, $topic, $attachment, %options) -> $url

Composes a pub url.
   * =$web= - name of the web for the URL, defaults to $session->{webName}
   * =$topic= - name of the topic, defaults to $session->{topicName}
   * =$attachment= - name of the attachment, defaults to no attachment
Supported %options are:
   * =topic_version= - version of topic to retrieve attachment from
   * =attachment_version= - version of attachment to retrieve
   * =absolute= - requests an absolute URL (rather than a relative path)

If =$web= is not given, =$topic= and =$attachment= are ignored.
If =$topic= is not given, =$attachment= is ignored.

If =topic_version= is not given, the most recent revision of the topic
will be linked. Similarly if attachment_version= is not given, the most recent
revision of the attachment will be assumed. If =topic_version= is specified
but =attachment_version= is not (or the specified =attachment_version= is not
present), then the most recent version of the attachment in that topic version
will be linked.

If Foswiki is running in an absolute URL context (e.g. the skin requires
absolute URLs, such as print or rss, or Foswiki is running from the
command-line) then =absolute= will automatically be set.

Note: for compatibility with older plugins, which use %PUBURL*% with
a constructed URL path, do not use =*= unless =web=, =topic=, and
=attachment= are all specified.

As required by RFC3986, the returned URL will only contain the
allowed characters -A-Za-z0-9_.~!*\'();:@&=+$,/?%#[]

=cut

sub getPubURL {
    my ( $this, $web, $topic, $attachment, %options ) = @_;

    $options{absolute} ||=
      ( $this->inContext('command_line') || $this->inContext('absolute_urls') );

    return $this->{store}
      ->getAttachmentURL( $this, $web, $topic, $attachment, %options );
}

=begin TML

---++ ObjectMethod deepWebList($filter, $web) -> @list

Deep list subwebs of the named web. $filter is a Foswiki::WebFilter
object that is used to filter the list. The listing of subwebs is
dependent on $Foswiki::cfg{EnableHierarchicalWebs} being true.

Webs are returned as absolute web pathnames.

=cut

sub deepWebList {
    my ( $this, $filter, $rootWeb ) = @_;
    my @list;
    my $webObject = new Foswiki::Meta( $this, $rootWeb );
    my $it = $webObject->eachWeb( $Foswiki::cfg{EnableHierarchicalWebs} );
    return $it->all() unless $filter;
    while ( $it->hasNext() ) {
        my $w = $rootWeb || '';
        $w .= '/' if $w;
        $w .= $it->next();
        if ( $filter->ok( $this, $w ) ) {
            push( @list, $w );
        }
    }
    return @list;
}

=begin TML

---++ ObjectMethod normalizeWebTopicName( $web, $topic ) -> ( $web, $topic )

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

   #SMELL: Item12567: Writing the separator as a character class for some reason
   # taints all the results including the data ouside the character class..
    if ( defined $topic && $topic =~ m{^(.*)(?:\.|/)(.*?)$} ) {
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
              $this->_expandMacroOnTopicRendering( $1 ) || ''/e
      )
    {
    }

    # Normalize web name to use / and not . as a subweb separator
    $web =~ s#\.#/#g;

    return ( $web, $topic );
}

=begin TML

---++ StaticMethod load_package( $full_package_name )

Will cleanly load the package or fail. This is better than 'eval "require $package"'.

It is not perfect for Perl < 5.10. For Perl 5.8, if somewhere else 'eval "require $package"' 
was used *earlier* for a module that fails to load, then not only is the failure not detected
then. Neither will it be detected here.

The recommendation is to replace all dynamic require calls in Foswiki to be replaced with this call.

This functionality used to be done via module Class::Load, but that had painful dependencies.

See http://blog.fox.geek.nz/2010/11/searching-design-spec-for-ultimate.html for the gory details.

=cut

sub load_package {
    my $fullname = shift;

    # Is it already loaded? If so, it might be an internal class an missing
    # from @INC, so skip it. See perldoc UNIVERSAL for what this does.
    return if eval { $fullname->isa($fullname) };

    $fullname =~ s{::}{/}g;
    $fullname .= '.pm';
    require $fullname;
}

=begin TML

---++ Private _parsePath( $this, $webtopic, $defaultweb, $topicOverride )

Parses the Web/Topic path parameters to safely establish a valid web and topic,
or assign safe defaults.

   * $webtopic - A "web/topic" path.  It might have originated from the query path_info,
   or from the topic= URL parameter. (only when the topic param contained a web component)
   * $defaultweb - The default web to use if the web part of webtopic is missing or invalid.
   This can be from the default UsersWebName,  or from the url parameter defaultweb.
   * $topicOverride - A topic name to use instead of any topic provided in the pathinfo.

Note if $webtopic ends with a trailing slash, it provides a hint that the last component should be
considered web.  This allows disambiguation between a topic and subweb with the same name.
Trailing slash forces it to be recognized as a webname, otherwise the topic is shown.
Note. If the web doesn't exist, the force will be ignored.  It's not possible to create a missing web
by referencing it in a URL.

This routine sets two variables when encountering invalid input:
   * $this->{invalidWeb}  contains original invalid web / pathinfo content when validation fails.
   * $this->{invalidTopic} Same function but for topic name
When invalid / illegal characters are encountered, the session {webName} and {topicName} will be
defaulted to safe defaults.  Scripts using those fields should also test if the corresponding
invalid* versions are defined, and should throw an oops exception rathern than allowing execution
to proceed with defaulted values.

The topic name will always have the first character converted to upper case, to prevent creation of
or access to invalid topics.

=cut

sub _parsePath {
    my $this          = shift;
    my $webtopic      = shift;
    my $defaultweb    = shift;
    my $topicOverride = shift;

    #print STDERR "_parsePath called WT ($webtopic) DEF ($defaultweb)\n";

    my $trailingSlash = ( $webtopic =~ s/\/$// );

    #print STDERR "TRAILING = $trailingSlash\n";

    # Remove any leading slashes or dots.
    $webtopic =~ s/^[\/.]+//;

    my @parts = split /[\/.]+/, $webtopic;
    my $cur = 0;
    my @webs;         # Collect valid webs from path
    my @badpath;      # Collect all webs, including illegal
    my $temptopic;    # Candidate topicname extracted from path, defaults.

    foreach (@parts) {

        # Lax check on name to eliminate evil characters.
        my $p = Foswiki::Sandbox::untaint( $_,
            \&Foswiki::Sandbox::validateTopicName );
        unless ($p) {
            push @badpath, $_;
            next;
        }

        if ( \$_ == \$parts[-1] ) {    # This is the last part of path

            if ( $this->topicExists( join( '/', @webs ) || $defaultweb, $p )
                && !$trailingSlash )
            {

                #print STDERR "Exists and no trailing slash\n";

                # It exists in Store as a topic and there is no trailing slash
                $temptopic = $p || '';
            }
            elsif ( $this->webExists( join( '/', @webs, $p ) ) ) {

                #print STDERR "Web Exists " . join( '/', @webs, $p ) . "\n";

                # It exists in Store as a web
                push @badpath, $p;
                push @webs,    $p;
            }
            elsif ($trailingSlash) {

                #print STDERR "Web forced ...\n";
                if ( !$this->webExists( join( '/', @webs, $p ) )
                    && $this->topicExists( join( '/', @webs ) || $defaultweb,
                        $p ) )
                {

                    #print STDERR "Forced, but no such web, and topic exists";
                    $temptopic = $p;
                }
                else {

                    #print STDERR "Append it to the webs\n";
                    $p = Foswiki::Sandbox::untaint( $p,
                        \&Foswiki::Sandbox::validateWebName );

                    unless ($p) {
                        push @badpath, $_;
                        next;
                    }
                    else {
                        push @badpath, $p;
                        push @webs,    $p;
                    }
                }
            }
            else {
                #print STDERR "Just a topic. " . scalar @webs . "\n";
                $temptopic = $p;
            }
        }
        else {
            $p = Foswiki::Sandbox::untaint( $p,
                \&Foswiki::Sandbox::validateWebName );
            unless ($p) {
                push @badpath, $_;
                next;
            }
            else {
                push @badpath, $p;
                push @webs,    $p;
            }
        }
    }

    my $web    = join( '/', @webs );
    my $badweb = join( '/', @badpath );

    # Set the requestedWebName before applying defaults - used by statistics
    # generation.   Note:  This is validated using Topic name rules to permit
    # names beginning with lower case.
    $this->{requestedWebName} =
      Foswiki::Sandbox::untaint( $badweb,
        \&Foswiki::Sandbox::validateTopicName );

    #print STDERR "Set requestedWebName to $this->{requestedWebName} \n"
    #  if $this->{requestedWebName};

    if ( length($web) != length($badweb) ) {

        #print STDERR "RESULTS:\nPATH: $web\nBAD:  $badweb\n";
        $this->{invalidWeb} = $badweb;
    }

    unless ($web) {
        $web = Foswiki::Sandbox::untaint( $defaultweb,
            \&Foswiki::Sandbox::validateWebName );
        unless ($web) {
            $this->{invalidWeb} = $defaultweb;
            $web = $Foswiki::cfg{UsersWebName};
        }
    }

    # Override topicname if urlparam $topic is provided.
    $temptopic = $topicOverride if ($topicOverride);

    # Provide a default topic if none specified
    $temptopic = $Foswiki::cfg{HomeTopicName} unless defined($temptopic);

    # Item3270 - here's the appropriate place to enforce spec
    # http://develop.twiki.org/~twiki4/cgi-bin/view/Bugs/Item3270
    my $topic =
      Foswiki::Sandbox::untaint( ucfirst($temptopic),
        \&Foswiki::Sandbox::validateTopicName );

    unless ($topic) {
        $this->{invalidTopic} = $temptopic;
        $topic = $Foswiki::cfg{HomeTopicName};

        #print STDERR "RESULTS:\nTOPIC  $topic\nBAD:  $temptopic\n";
        $this->{invalidTopic} = $temptopic;
    }

    #print STDERR "PARSE returns web $web topic $topic\n";

    return ( $web, $topic );
}

=begin TML

---++ ClassMethod new( $defaultUser, $query, \%initialContext )

Constructs a new Foswiki session object. A unique session object exists for
every transaction with Foswiki, for example every browser request, or every
script run. Session objects do not persist between mod_perl runs.

   * =$defaultUser= is the username (*not* the wikiname) of the default
     user you want to be logged-in, if none is available from a session
     or browser. Used mainly for unit tests and debugging, it is typically
     undef, in which case the default user is taken from
     $Foswiki::cfg{DefaultUserName}.
   * =$query= the Foswiki::Request query (may be undef, in which case an
     empty query is used)
   * =\%initialContext= - reference to a hash containing context
     name=value pairs to be pre-installed in the context hash. May be undef.

=cut

sub new {
    my ( $class, $defaultUser, $query, $initialContext ) = @_;

    Monitor::MARK("Static init over; make Foswiki object");
    ASSERT( !$query || UNIVERSAL::isa( $query, 'Foswiki::Request' ) )
      if DEBUG;

   # Override user to be admin if no configuration exists.
   # Do this really early, so that later changes in isBOOTSTRAPPING can't change
   # Foswiki's behavior.
    $defaultUser = 'admin' if ( $Foswiki::cfg{isBOOTSTRAPPING} );

    unless ( $Foswiki::cfg{TempfileDir} ) {

        # Give it a sane default.
        if ( $^O eq 'MSWin32' ) {

            # Windows default tmpdir is the C: root  use something sane.
            # Configure does a better job,  it should be run.
            $Foswiki::cfg{TempfileDir} = $Foswiki::cfg{WorkingDir};
        }
        else {
            $Foswiki::cfg{TempfileDir} = File::Spec->tmpdir();
        }
    }

    # Cover all the possibilities
    $ENV{TMPDIR} = $Foswiki::cfg{TempfileDir};
    $ENV{TEMP}   = $Foswiki::cfg{TempfileDir};
    $ENV{TMP}    = $Foswiki::cfg{TempfileDir};

    # Make sure CGI is also using the appropriate tempfile location
    $CGI::TMPDIRECTORY = $Foswiki::cfg{TempfileDir};

    # Make %ENV safer, preventing hijack of the search path. The
    # environment is set per-query, so this can't be done in a BEGIN.
    # This MUST be done before any external programs are run via Sandbox.
    # or it will fail with taint errors.  See Item13237
    if ( defined $Foswiki::cfg{SafeEnvPath} ) {
        $ENV{PATH} = $Foswiki::cfg{SafeEnvPath};
    }
    else {
        # Default $ENV{PATH} must be untainted because
        # Foswiki may be run with the -T flag.
        # SMELL: how can we validate the PATH?
        $ENV{PATH} = Foswiki::Sandbox::untaintUnchecked( $ENV{PATH} );
    }
    delete @ENV{qw( IFS CDPATH ENV BASH_ENV )};

    if (   $Foswiki::cfg{WarningFileName}
        && $Foswiki::cfg{Log}{Implementation} eq 'Foswiki::Logger::PlainFile' )
    {

        # Admin has already expressed a preference for where they want their
        # logfiles to go, and has obviously not re-run configure yet.
        $Foswiki::cfg{Log}{Implementation} = 'Foswiki::Logger::Compatibility';

#print STDERR "WARNING: Foswiki is using the compatibility logger. Please re-run configure and check your logfiles settings\n";
    }

    # Make sure LogFielname is defined for use in old plugins,
    # but don't overwrite the setting from configure, if there is one.
    # This is especially important when the admin has *chosen*
    # to use the compatibility logger. (Some old TWiki heritage
    # plugins write directly to the configured LogFileName
    if ( not $Foswiki::cfg{LogFileName} ) {
        if ( $Foswiki::cfg{Log}{Implementation} eq
            'Foswiki::Logger::Compatibility' )
        {
            my $stamp =
              Foswiki::Time::formatTime( time(), '$year$mo', 'servertime' );
            my $defaultLogDir = "$Foswiki::cfg{DataDir}";
            $Foswiki::cfg{LogFileName} = $defaultLogDir . "/log$stamp.txt";

#print STDERR "Overrode LogFileName to $Foswiki::cfg{LogFileName} for CompatibilityLogger\n"
        }
        else {
            $Foswiki::cfg{LogFileName} = "$Foswiki::cfg{Log}{Dir}/events.log";

#print STDERR "Overrode LogFileName to $Foswiki::cfg{LogFileName} for PlainFileLogger\n"
        }
    }

    # Set command_line context if there is no query
    $initialContext ||= defined($query) ? {} : { command_line => 1 };

    # This foswiki supports:
    $initialContext->{SUPPORTS_PARA_INDENT}   = 1;    #  paragraph indent
    $initialContext->{SUPPORTS_PREF_SET_URLS} = 1;    # ?Set+, ?Local+ etc URLs
    if ( $Foswiki::cfg{Password} ) {
        $initialContext->{admin_available} = 1;       # True if sudo supported.
    }

    $query ||= new Foswiki::Request();

    # Phase 2 of Bootstrap.  Web settings require that the Foswiki request
    # has been parsed.
    if ( $Foswiki::cfg{isBOOTSTRAPPING} ) {
        my $phase2_message =
          Foswiki::Configure::Bootstrap::bootstrapWebSettings(
            $query->action() );
        unless ($system_message) {    # Don't do this more than once.
            $system_message =
              ( $Foswiki::cfg{Engine} && $Foswiki::cfg{Engine} !~ /CLI/i )
              ? ( '<div class="foswikiHelp"> '
                  . $bootstrap_message
                  . $phase2_message
                  . '</div>' )
              : $bootstrap_message . $phase2_message;
        }
    }

    my $this = bless( { sandbox => 'Foswiki::Sandbox' }, $class );

    if (SINGLE_SINGLETONS_TRACE) {
        require Data::Dumper;
        print STDERR "new $this: "
          . Data::Dumper->Dump( [ [caller], [ caller(1) ] ] );
    }

    $this->{request}  = $query;
    $this->{cgiQuery} = $query;    # for backwards compatibility in contribs
    $this->{response} = new Foswiki::Response();

    # This is required in case we get an exception during
    # initialisation, so that we have a session to handle it with.
    ASSERT( !$Foswiki::Plugins::SESSION ) if SINGLE_SINGLETONS;
    $Foswiki::Plugins::SESSION = $this;
    ASSERT( $Foswiki::Plugins::SESSION->isa('Foswiki') ) if DEBUG;

    $this->{context} = $initialContext;

    # Construct the plugins objects and load the code for the plugins,
    # calling any preload handlers.
    $this->{plugins} = new Foswiki::Plugins($this);

    if ( $Foswiki::cfg{Cache}{Enabled} && $Foswiki::cfg{Cache}{Implementation} )
    {
        eval "require $Foswiki::cfg{Cache}{Implementation}";
        if ($@) {    # The require failed - Be graceful in failure
            ASSERT( !$@, $@ ) if DEBUG;
            $Foswiki::cfg{Cache}{Enabled} = 0;
        }
        else {
            $this->{cache} = $Foswiki::cfg{Cache}{Implementation}->new();
        }
    }

    my $prefs = new Foswiki::Prefs($this);
    $this->{prefs} = $prefs;

    # construct the store object
    my $base = $Foswiki::cfg{Store}{Implementation}
      || 'Foswiki::Store::PlainFile';

    load_package($base);

    foreach my $class ( @{ $Foswiki::cfg{Store}{ImplementationClasses} } ) {

        # this allows us to add an arbitary set of mixins for things
        # like recordChanges

        # Rejig the store impl's ISA to use each Class  in order.'
        load_package($class);
        no strict 'refs';
        push( @{ $class . '::ISA' }, $base );
        use strict 'refs';
        $base = $class;
    }

    $this->{store} = $base->new();
    ASSERT( $this->{store}, "no $base object created" ) if DEBUG;

    #Monitor::MARK("Created store");

    $this->{digester} = new Digest::MD5();
    $this->{users}    = new Foswiki::Users($this);

    #Monitor::MARK("Created users object");

    #{urlHost}  is needed by loadSession..
    my $url = $query->url();
    if (   $url
        && !$Foswiki::cfg{ForceDefaultUrlHost}
        && $url =~ m{^([^:]*://[^/]*).*$} )
    {
        $this->{urlHost} = $1;

        if ( $Foswiki::cfg{RemovePortNumber} ) {
            $this->{urlHost} =~ s/\:[0-9]+$//;
        }

        # If the urlHost in the url is localhost, this is a lot less
        # useful than the default url host. This is because new CGI("")
        # assigns this host by default - it's a default setting, used
        # when there is nothing better available.
        if ( $this->{urlHost} =~ m/^(https?:\/\/)localhost$/i ) {
            my $protocol = $1;

#only replace localhost _if_ the protocol matches the one specified in the DefaultUrlHost
            if ( $Foswiki::cfg{DefaultUrlHost} =~ m/^$protocol/i ) {
                $this->{urlHost} = $Foswiki::cfg{DefaultUrlHost};
            }
        }
    }
    else {
        $this->{urlHost} = $Foswiki::cfg{DefaultUrlHost};
    }
    ASSERT( $this->{urlHost} ) if DEBUG;

    $this->{scriptUrlPath} = $Foswiki::cfg{ScriptUrlPath};
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

    # The web/topic can be provided by either the query path_info,
    # or by URL Parameters:
    # topic:       Specifies web.topic or topic.
    #              Overrides the path given in the URL
    # defaultweb:  Overrides the default web, for use when topic=
    #              does not provide a web.
    # path_info    Defaults to the Users web Home topic

    # Note that the jsonrpc script does none of these. A default
    # web/topic is part of the posted json request.

    # Set the default for web
    # Development.AddWebParamToAllCgiScripts: enables
    # bin/script?topic=WebPreferences;defaultweb=Sandbox
    my $defaultweb = $query->param('defaultweb') || $Foswiki::cfg{UsersWebName};

    # rest doesn't use web/topic path, but pick up a default.
    my $webtopic = '';

   # SMELL: It is completely bogus that we do this for the jsonrpc script.
   # But we must, because jsonrpc depends upon the bogus path_info to trigger
   # a bug in core which results in an unassigned default BASEWEB and BASETOPIC.
   # If jsonrpc gets a default web/topic, it will pick up settings for the
   # wrong topic and fail.
    unless ( $query->action() eq 'rest' ) {
        $webtopic = urlDecode( $query->path_info() || '' );
    }

    my $topicOverride = '';
    my $topic         = $query->param('topic');
    if ( defined $topic ) {
        if ( $topic =~ m/[\/.]+/ ) {
            $webtopic = $topic;

           #print STDERR "candidate webtopic set to $webtopic by query param\n";
        }
        else {
            $topicOverride = $topic;

            #print STDERR
            #  "candidate topic set to $topicOverride by query param\n";
        }
    }

    ( my $web, $topic ) =
      $this->_parsePath( $webtopic, $defaultweb, $topicOverride );

    $this->{topicName} = $topic;
    $this->{webName}   = $web;

    if (   !$Foswiki::cfg{Sessions}{EnableGuestSessions}
        && defined $Foswiki::cfg{Sessions}{TopicsRequireGuestSessions}
        && $this->{topicName} =~
        m/$Foswiki::cfg{Sessions}{TopicsRequireGuestSessions}/ )
    {
        #print STDERR "FORCE Session - . $topic / " . $query->action() . "\n";
        $this->{context}{sessionRequired} = 1;
    }

  #else {    print STDERR "NO Session -  $topic / " . $query->action() . "\n"; }

    # Load (or create) the CGI session
    $this->{remoteUser} = $this->{users}->loadSession($defaultUser);

    # Form definition cache
    $this->{forms} = {};

    # Push global preferences from %SYSTEMWEB%.DefaultPreferences
    $prefs->loadDefaultPreferences();

    #Monitor::MARK("Loaded default prefs");

    # SMELL: what happens if we move this into the Foswiki::Users::new?
    # Note:  The initializeUserHandler() can override settings like
    #        topicName and webName. For example, HomePagePlugin.
    $this->{user} = $this->{users}->initialiseUser( $this->{remoteUser} );

    #Monitor::MARK("Initialised user");

    # Static session variables that can be expanded in topics when they
    # are enclosed in % signs
    # SMELL: should collapse these into one. The duplication is pretty
    # pointless.
    $prefs->setInternalPreferences(
        BASEWEB        => $this->{webName},
        BASETOPIC      => $this->{topicName},
        INCLUDINGTOPIC => $this->{topicName},
        INCLUDINGWEB   => $this->{webName}
    );

    # Push plugin settings
    $this->{plugins}->settings();

    # Now the rest of the preferences
    $prefs->loadSitePreferences();

    # User preferences only available if we can get to a valid wikiname,
    # which depends on the user mapper.
    my $wn = $this->{users}->getWikiName( $this->{user} );
    if ($wn) {
        $prefs->setUserPreferences($wn);
    }

    $prefs->pushTopicContext( $this->{webName}, $this->{topicName} );

    #Monitor::MARK("Preferences all set up");

    # Set both isadmin and authenticated contexts.   If the current user
    # is admin, then they either authenticated, or we are in bootstrap.
    if ( $this->{users}->isAdmin( $this->{user} ) ) {
        $this->{context}{authenticated} = 1;
        $this->{context}{isadmin}       = 1;
    }

    # Finish plugin initialization - register handlers
    $this->{plugins}->enable();

    Monitor::MARK("Foswiki object created");

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
        $this->{renderer} = new Foswiki::Render($this);
    }

    return $this->{renderer};
}

=begin TML

---++ ObjectMethod renderer()
Get a reference to the zone renderer object. Done lazily because not everyone
needs the zones.

=cut

sub zones {
    my ($this) = @_;
    unless ( $this->{zones} ) {
        require Foswiki::Render::Zones;
        $this->{zones} = new Foswiki::Render::Zones($this);
    }
    return $this->{zones};
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

---++ ObjectMethod reset_i18n()
Kill the i18n object, if there is one, to force language re-initialisation.
Essential for changing language dynamically.

=cut

sub reset_i18n {
    my $this = shift;

    return unless $this->{i18n};
    $this->{i18n}->finish();
    undef $this->{i18n};
}

=begin TML

---++ ObjectMethod logger()

=cut

sub logger {
    my $this = shift;

    unless ( $this->{logger} ) {
        if ( $Foswiki::cfg{Log}{Implementation} eq 'none' ) {
            $this->{logger} = Foswiki::Logger->new();
        }
        else {
            eval "require $Foswiki::cfg{Log}{Implementation}";
            if ($@) {
                print STDERR "Logger load failed: $@";
                $this->{logger} = Foswiki::Logger->new();
            }
            else {
                $this->{logger} = $Foswiki::cfg{Log}{Implementation}->new();
            }
        }
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

---++ ObjectMethod access()
Get a reference to the ACL object. 

=cut

sub access {
    my ($this) = @_;

    unless ( $this->{access} ) {
        require Foswiki::Access;
        $this->{access} = Foswiki::Access->new($this);
    }
    ASSERT( $this->{access} ) if DEBUG;
    return $this->{access};
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

    # Print any macros that are never loaded
    #print STDERR "NEVER USED\n";
    #for my $i (keys %macros) {
    #    print STDERR "\t$i\n" unless defined $macros{$i};
    #}
    $_->finish() foreach values %{ $this->{forms} };
    undef $this->{forms};
    foreach my $key (
        qw(plugins users prefs templates renderer zones net
        store search attach access i18n cache logger)
      )
    {
        next
          unless ref( $this->{$key} );
        $this->{$key}->finish();
        undef $this->{$key};
    }

    undef $this->{request};
    undef $this->{cgiQuery};

    undef $this->{digester};
    undef $this->{urlHost};
    undef $this->{web};
    undef $this->{topic};
    undef $this->{webName};
    undef $this->{topicName};
    undef $this->{invalidWeb};
    undef $this->{invalidTopic};
    undef $this->{_ICONSPACE};
    undef $this->{_EXT2ICON};
    undef $this->{_KNOWNICON};
    undef $this->{_ICONSTEMPLATE};
    undef $this->{context};
    undef $this->{remoteUser};
    undef $this->{requestedWebName};    # Web name before renaming
    undef $this->{scriptUrlPath};
    undef $this->{user};
    undef $this->{_INCLUDES};
    undef $this->{response};
    undef $this->{evaluating_if};
    undef $this->{_addedToHEAD};
    undef $this->{sandbox};
    undef $this->{evaluatingEval};
    undef $this->{_ffCache};

    undef $this->{DebugVerificationCode};    # from Foswiki::UI::Register
    if (SINGLE_SINGLETONS_TRACE) {
        require Data::Dumper;
        print STDERR "finish $this: "
          . Data::Dumper->Dump( [ [caller], [ caller(1) ] ] );
    }
    if (SINGLE_SINGLETONS) {
        ASSERT( defined $Foswiki::Plugins::SESSION );
        ASSERT( $Foswiki::Plugins::SESSION == $this );
        ASSERT( $Foswiki::Plugins::SESSION->isa('Foswiki') );
    }
    undef $Foswiki::Plugins::SESSION;

    if (DEBUG) {
        my $remaining = join ',', grep { defined $this->{$_} } keys %$this;
        ASSERT( 0,
                "Fields with defined values in "
              . ref($this)
              . "->finish(): "
              . $remaining )
          if $remaining;
    }
}

=begin TML

---++ DEPRECATED  ObjectMethod logEvent( $action, $webTopic, $extra, $user )
   * =$action= - what happened, e.g. view, save, rename
   * =$webTopic= - what it happened to
   * =$extra= - extra info, such as minor flag
   * =$user= - login name of user - default current user,
     or failing that the user agent

Write the log for an event to the logfile

The method is deprecated,  Call logger->log directly.

=cut

sub logEvent {
    my $this = shift;

    my $action   = shift || '';
    my $webTopic = shift || '';
    my $extra    = shift || '';
    my $user     = shift;

    $this->logger->log(
        {
            level    => 'info',
            action   => $action || '',
            webTopic => $webTopic || '',
            extra    => $extra || '',
            user     => $user,
        }
    );
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

---++ ObjectMethod inlineAlert($template, $def, ... ) -> $string

Format an error for inline inclusion in rendered output. The message string
is obtained from the template 'oops'.$template, and the DEF $def is
selected. The parameters (...) are used to populate %PARAM1%..%PARAMn%

=cut

sub inlineAlert {
    my $this     = shift;
    my $template = shift;
    my $def      = shift;

    # web and topic can be anything; they are not used
    my $topicObject =
      Foswiki::Meta->new( $this, $this->{webName}, $this->{topicName} );
    my $text = $this->templates->readTemplate( 'oops' . $template );
    if ($text) {
        my $blah = $this->templates->expandTemplate($def);
        $text =~ s/%INSTANTIATE%/$blah/;

        $text = $topicObject->expandMacros($text);
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

        # Error in the template system.
        $text = $topicObject->renderTML(<<MESSAGE);
---+ Foswiki Installation Error
Template 'oops$template' not found or returned no text, expanding $def.

Check your configuration settings for {TemplateDir} and {TemplatePath}
or check for syntax errors in templates,  or a missing TMPL:END.
MESSAGE
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

    my $text = shift;

    return ( '', [] ) unless defined $text;

    my %sections;
    my @list = ();

    my $seq    = 0;
    my $ntext  = '';
    my $offset = 0;
    foreach
      my $bit ( split( /(%(?:START|STOP|END)SECTION(?:{.*?})?%)/, $text ) )
    {
        if ( $bit =~ m/^%STARTSECTION(?:{(.*)})?%$/ ) {
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
                    && $s->{name} =~ m/^_SECTION\d+$/ )
                {
                    $s->{end} = $offset;
                }
            }
            $attrs->{start} = $offset;
            $attrs->{end}   = -1;        # open section
            $sections{$id}  = $attrs;
            push( @list, $attrs );
        }
        elsif ( $bit =~ m/^%(?:END|STOP)SECTION(?:{(.*)})?%$/ ) {
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
                        && $s->{name} =~ m/^_SECTION\d+$/ )
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

---++ ObjectMethod expandMacrosOnTopicCreation ( $topicObject )

   * =$topicObject= - the topic

Expand only that subset of Foswiki variables that are
expanded during topic creation, in the body text and
PREFERENCE meta only. The expansion is in-place inside
the topic object.

# SMELL: no plugin handler

=cut

sub expandMacrosOnTopicCreation {
    my ( $this, $topicObject ) = @_;

    # Make sure func works, for registered tag handlers
    if (SINGLE_SINGLETONS) {
        ASSERT( defined $Foswiki::Plugins::SESSION );
        ASSERT( $Foswiki::Plugins::SESSION == $this );
    }
    local $Foswiki::Plugins::SESSION = $this;
    ASSERT( $Foswiki::Plugins::SESSION->isa('Foswiki') ) if DEBUG;

    my $text = $topicObject->text();
    if ($text) {

        # Chop out templateonly sections
        my ( $ntext, $sections ) = parseSections($text);
        if ( scalar(@$sections) ) {

            # Note that if named templateonly sections overlap,
            # the behaviour is undefined.

            # First excise all templateonly sections by replacing
            # with nulls of the same length. This keeps the string
            # length the same so offsets remain current.
            foreach my $s ( reverse @$sections ) {
                next unless ( $s->{type} eq 'templateonly' );
                my $r = "\0" x ( $s->{end} - $s->{start} );
                substr( $ntext, $s->{start}, $s->{end} - $s->{start}, $r );
            }

            # Now restore the macros for other sections.
            foreach my $s ( reverse @$sections ) {
                next if ( $s->{type} eq 'templateonly' );

                my $start = $s->remove('start');
                my $end   = $s->remove('end');
                $ntext =
                    substr( $ntext, 0, $start )
                  . '%STARTSECTION{'
                  . $s->{_RAW} . '}%'
                  . substr( $ntext, $start, $end - $start )
                  . '%ENDSECTION{'
                  . $s->{_RAW} . '}%'
                  . substr( $ntext, $end, length($ntext) );
            }

            # Chop the nulls
            $ntext =~ s/\0*//g;
            $text = $ntext;
        }

        $text = _processMacros( $this, $text, \&_expandMacroOnTopicCreation,
            $topicObject, 16 );

        # expand all variables for type="expandvariables" sections
        ( $ntext, $sections ) = parseSections($text);
        if ( scalar(@$sections) ) {
            foreach my $s ( reverse @$sections ) {
                if ( $s->{type} eq 'expandvariables' ) {
                    my $etext =
                      substr( $ntext, $s->{start}, $s->{end} - $s->{start} );
                    $this->innerExpandMacros( \$etext, $topicObject );
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
                      . $s->{_RAW} . '}%'
                      . substr( $ntext, $start, $end - $start )
                      . '%ENDSECTION{'
                      . $s->{_RAW} . '}%'
                      . substr( $ntext, $end, length($ntext) );
                }
            }
            $text = $ntext;
        }

        # kill markers used to prevent variable expansion
        $text =~ s/%NOP%//g;
        $topicObject->text($text);
    }

    # Expand preferences
    my @prefs = $topicObject->find('PREFERENCE');
    foreach my $p (@prefs) {
        $p->{value} =
          _processMacros( $this, $p->{value}, \&_expandMacroOnTopicCreation,
            $topicObject, 16 );

        # kill markers used to prevent variable expansion
        $p->{value} =~ s/%NOP%//g;
    }
}

=begin TML

---++ StaticMethod entityEncode( $text [, $extras] ) -> $encodedText

Escape special characters to HTML numeric entities. This is *not* a generic
encoding, it is tuned specifically for use in Foswiki.

HTML4.0 spec:
"Certain characters in HTML are reserved for use as markup and must be
escaped to appear literally. The "&lt;" character may be represented with
an <em>entity</em>, <strong class=html>&amp;lt;</strong>. Similarly, "&gt;"
is escaped as <strong class=html>&amp;gt;</strong>, and "&amp;" is escaped
as <strong class=html>&amp;amp;</strong>. If an attribute value contains a
double quotation mark and is delimited by double quotation marks, then the
quote should be escaped as <strong class=html>&amp;quot;</strong>.

Other entities exist for special characters that cannot easily be entered
with some keyboards..."

This method encodes:
   * all non-printable 7-bit chars (< \x1f), except \n (\xa) and \r (\xd)
   * HTML special characters '>', '<', '&', ''' (single quote) and '"' (double quote).
   * TML special characters '%', '|', '[', ']', '@', '_', '*', '$' and "="

$extras is an optional param that may be used to include *additional*
characters in the set of encoded characters. It should be a string
containing the additional chars.

This internal function is available for use by expanding the =%ENCODE= macro,
or the =%URLPARAM= macro, specifying =type="entities"= or =type="entity"=.

=cut

sub entityEncode {
    my ( $text, $extra ) = @_;
    $extra = '' unless defined $extra;

    # Safe on utf8 binary strings, as none of the characters has bit 7 set
    $text =~
s/([[\x01-\x09\x0b\x0c\x0e-\x1f"%&\$'*<=>@\]_\|$extra])/'&#'.ord($1).';'/ge;
    return $text;
}

#s/([[\x01-\x09\x0b\x0c\x0e-\x1f"%&\$'*<=>@[_\|$extra])/'&#'.ord($1).';'/ge;

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

---++ StaticMethod urlEncode( $perlstring ) -> $bytestring

Encode by converting characters that are reserved in URLs to
their %NN equivalents. This method is used for encoding
strings that must be embedded _verbatim_ in URLs; it cannot
be applied to URLs themselves, as it escapes reserved
characters such as =, &, %, ;, # and ?.

RFC 1738, Dec. '94:
    <verbatim>
    ...Only alphanumerics [0-9a-zA-Z], the special
    characters $-_.+!*'(), and reserved characters used for their
    reserved purposes may be used unencoded within a URL.
    </verbatim>

However this function is tuned for use with Foswiki. As such, it
encodes *all* characters except 0-9a-zA-Z-_.:~!*/

This internal function is available for use by expanding the =%ENCODE= macro,
specifying =type="url"=.  It is also the default encoding used by the =%URLPARAM= macro. 

=cut

sub urlEncode {
    my $text = shift;

    $text = encode_utf8($text);
    $text =~ s{([^0-9a-zA-Z-_.:~!*/])}{sprintf('%%%02x',ord($1))}ge;

    return $text;
}

=begin TML

---++ StaticMethod urlDecode( $bytestring ) -> $perlstring

Reverses the encoding done in urlEncode.

=cut

sub urlDecode {
    my $text = shift;

    $text =~ s/%([\da-fA-F]{2})/chr(hex($1))/ge;
    $text = decode_utf8($text);

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

    $value =~ s/^\s*(.*?)\s*$/$1/g;
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
    my $mark = "\001";
    $word =~ s/([[:upper:]])([[:digit:]])/$1$mark$2/g;
    $word =~ s/([[:digit:]])([[:upper:]])/$1$mark$2/g;
    $word =~ s/([[:lower:]])([[:upper:][:digit:]]+)/$1$mark$2/g;
    $word =~ s/([[:upper:]])([[:upper:]])(?=[[:lower:]])/$1$mark$2/g;
    $word =~ s/$mark/$sep/g;
    return $word;
}

=begin TML

---++ ObjectMethod innerExpandMacros(\$text, $topicObject)
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

sub innerExpandMacros {
    my ( $this, $text, $topicObject ) = @_;

    # push current context
    my $memTopic = $this->{prefs}->getPreference('TOPIC');
    my $memWeb   = $this->{prefs}->getPreference('WEB');

    # Historically this couldn't be called on web objects.
    my $webContext   = $topicObject->web   || $this->{webName};
    my $topicContext = $topicObject->topic || $this->{topicName};

    $this->{prefs}->setInternalPreferences(
        TOPIC => $topicContext,
        WEB   => $webContext
    );

    # Escape ' !%VARIABLE%'
    $$text =~ s/(?<=[\s\(\.])!%($regex{tagNameRegex})/&#37;$1/g;

    # Make sure func works, for registered tag handlers
    if (SINGLE_SINGLETONS) {
        ASSERT( defined $Foswiki::Plugins::SESSION );
        ASSERT( $Foswiki::Plugins::SESSION == $this );
    }
    local $Foswiki::Plugins::SESSION = $this;
    ASSERT( $Foswiki::Plugins::SESSION->isa('Foswiki') ) if DEBUG;

    # NOTE TO DEBUGGERS
    # The depth parameter in the following call controls the maximum number
    # of levels of expansion. If it is set to 1 then only macros in the
    # topic will be expanded; macros that they in turn generate will be
    # left unexpanded. If it is set to 2 then the expansion will stop after
    # the first recursive inclusion, and so on. This is incredible useful
    # when debugging. The default, 16, was selected empirically.
    $$text = _processMacros( $this, $$text, \&_expandMacroOnTopicRendering,
        $topicObject, 16 );

    # restore previous context
    $this->{prefs}->setInternalPreferences(
        TOPIC => $memTopic,
        WEB   => $memWeb
    );
}

=begin TML

---++ StaticMethod takeOutBlocks( \$text, $tag, \%map ) -> $text
   * =$text= - Text to process
   * =$tag= - XML-style tag.
   * =\%map= - Reference to a hash to contain the removed blocks

Return value: $text with blocks removed

Searches through $text and extracts blocks delimited by an XML-style tag,
storing the extracted block, and replacing with a token string which is
not affected by TML rendering.  The text after these substitutions is
returned.

=cut

sub takeOutBlocks {
    my ( $intext, $tag, $map ) = @_;

    # Case insensitive regexes are very slow,  Change to character class match
    # link is transformed to [lL][iI][nN][kK]
    my $re = join( '', map { '[' . lc($_) . uc($_) . ']' } split( '', $tag ) );

    return $intext unless ( $intext =~ m/<$re\b/ );

    my $out   = '';
    my $depth = 0;
    my $scoop;
    my $tagParams;

    foreach my $token ( split( /(<\/?$re[^>]*>)/, $intext ) ) {
        if ( $token =~ m/<$re\b([^>]*)?>/ ) {
            $depth++;
            if ( $depth eq 1 ) {
                $tagParams = $1;
                next;
            }
        }
        elsif ( $token =~ m/<\/$re>/ ) {
            if ( $depth > 0 ) {
                $depth--;
                if ( $depth eq 0 ) {
                    my $placeholder = "$tag$BLOCKID";
                    $BLOCKID++;
                    $map->{$placeholder}{text}   = $scoop;
                    $map->{$placeholder}{params} = $tagParams;
                    $out .= "$OC$placeholder$CC";
                    $scoop = '';
                    next;
                }
            }
        }
        if ( $depth > 0 ) {
            $scoop .= $token;
        }
        else {
            $out .= $token;
        }
    }

    # unmatched tags
    if ( defined($scoop) && ( $scoop ne '' ) ) {
        my $placeholder = "$tag$BLOCKID";
        $BLOCKID++;
        $map->{$placeholder}{text}   = $scoop;
        $map->{$placeholder}{params} = $tagParams;
        $out .= "$OC$placeholder$CC";
    }

    return $out;
}

=begin TML

---++ StaticMethod putBackBlocks( \$text, \%map, $tag, $newtag, $callBack ) -> $text

Return value: $text with blocks added back
   * =\$text= - reference to text to process
   * =\%map= - map placeholders to blocks removed by takeOutBlocks
   * =$tag= - Tag name processed by takeOutBlocks
   * =$newtag= - Tag name to use in output, in place of $tag.
     If undefined, uses $tag.
   * =$callback= - Reference to function to call on each block
     being inserted (optional)

Reverses the actions of takeOutBlocks.

Each replaced block is processed by the callback (if there is one) before
re-insertion.

Parameters to the outermost cut block are replaced into the open tag,
even if that tag is changed. This allows things like =&lt;verbatim class=''>=
to be changed to =&lt;pre class=''>=

If you set $newtag to '', replaces the taken-out block with the contents
of the block, not including the open/close. This is used for &lt;literal>,
for example.

=cut

sub putBackBlocks {
    my ( $text, $map, $tag, $newtag, $callback ) = @_;

    $newtag = $tag if ( !defined($newtag) );

    my $otext = $$text;
    my $pos   = 0;
    my $ntext = '';

    while ( ( $pos = index( $otext, ${OC} . $tag, $pos ) ) >= 0 ) {

        # Grab the text ahead of the marker
        $ntext .= substr( $otext, 0, $pos );

        # Length of the marker prefix
        my $pfxlen = length( ${OC} . $tag );

        # Ending marker position
        my $epos = index( $otext, ${CC}, $pos );

        # Tag instance
        my $placeholder =
          $tag . substr( $otext, $pos + $pfxlen, $epos - $pos - $pfxlen );

  # Not all calls to putBack use a common map, so skip over any missing entries.
        unless ( exists $map->{$placeholder} ) {
            $ntext .= substr( $otext, $pos, $epos - $pos + 4 );
            $otext = substr( $otext, $epos + 4 );
            $pos = 0;
            next;
        }

        # Any params saved with the tag
        my $params = $map->{$placeholder}{params} || '';

        # Get replacement value
        my $val = $map->{$placeholder}{text};
        $val = &$callback($val) if ( defined($callback) );

        # Append the new data and remove leading text + marker from original
        if ( defined($val) ) {
            $ntext .=
              ( $newtag eq '' ) ? $val : "<$newtag$params>$val</$newtag>";
        }
        $otext = substr( $otext, $epos + 4 );

        # Reset position for next pass
        $pos = 0;

        delete( $map->{$placeholder} );
    }

    $ntext .= $otext;    # Append any remaining text.
    $$text = $ntext;     # Replace the entire text

}

# Process Foswiki %TAGS{}% by parsing the input tokenised into
# % separated sections. The parser is a simple stack-based parse,
# sufficient to ensure nesting of tags is correct, but no more
# than that.
# $depth limits the number of recursive expansion steps that
# can be performed on expanded tags.
sub _processMacros {
    my ( $this, $text, $tagf, $topicObject, $depth ) = @_;
    my $tell = 0;

    return '' if ( ( !defined($text) )
        || ( $text eq '' ) );

    #no tags to process
    return $text unless ( $text =~ m/%/ );

    unless ($depth) {
        my $mess = "Max recursive depth reached: $text";
        $this->logger->log( 'warning', $mess );

        # prevent recursive expansion that just has been detected
        # from happening in the error message
        $text =~ s/%(.*?)%/$1/g;
        return $text;
    }

    my $verbatim = {};
    $text = takeOutBlocks( $text, 'verbatim', $verbatim );

    my $dirtyAreas = {};
    $text = takeOutBlocks( $text, 'dirtyarea', $dirtyAreas )
      if $topicObject->isCacheable();

    my @queue = split( /(%)/, $text );
    my @stack;
    my $stackTop = '';    # the top stack entry. Done this way instead of
         # referring to the top of the stack for efficiency. This var
         # should be considered to be $stack[$#stack]

    while ( scalar(@queue) ) {

        #print STDERR "QUEUE:".join("\n      ", map { "'$_'" } @queue)."\n";
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
            if ( $stackTop =~ m/}$/s ) {
                while ( scalar(@stack)
                    && $stackTop !~ /^%$regex{tagNameRegex}\{.*}$/s )
                {
                    my $top = $stackTop;

                    #print STDERR ' ' x $tell,"COLLAPSE $top \n";
                    $stackTop = pop(@stack) . $top;
                }
            }

            # /s so you can have newlines in parameters
            if ( $stackTop =~ m/^%(($regex{tagNameRegex})(?:{(.*)})?)$/s ) {

                # SMELL: unchecked implicit untaint?
                my ( $expr, $tag, $args ) = ( $1, $2, $3 );

                #Foswiki::Func::writeDebug("POP $tag") if $tracing;
                #Monitor::MARK("Before $tag");
                my $e = &$tagf( $this, $tag, $args, $topicObject );

                #Monitor::MARK("After $tag");

                if ( defined($e) ) {

                  #Foswiki::Func::writeDebug("EXPANDED $tag -> $e") if $tracing;
                    $stackTop = pop(@stack);

                    # Don't bother recursively expanding unless there are
                    # unexpanded tags in the result.
                    unless ( $e =~ m/%$regex{tagNameRegex}(?:{.*})?%/s ) {
                        $stackTop .= $e;
                        next;
                    }

                    # Recursively expand tags in the expansion of $tag
                    $stackTop .=
                      $this->_processMacros( $e, $tagf, $topicObject,
                        $depth - 1 );
                }
                else {

                   #Foswiki::Func::writeDebug("EXPAND $tag FAILED") if $tracing;
                   # To handle %NOP
                   # correctly, we have to handle the %VAR% case differently
                   # to the %VAR{}% case when a variable expansion fails.
                   # This is so that recursively define variables e.g.
                   # %A%B%D% expand correctly, but at the same time we ensure
                   # that a mismatched }% can't accidentally close a context
                   # that was left open when a tag expansion failed.
                   # However TWiki didn't do this, so for compatibility
                   # we have to accept that %NOP can never be fixed. if it
                   # could, then we could uncomment the following:

                    #if( $stackTop =~ m/}$/ ) {
                    #    # %VAR{...}% case
                    #    # We need to push the unexpanded expression back
                    #    # onto the stack, but we don't want it to match the
                    #    # tag expression again. So we protect the %'s
                    #    $stackTop = "&#37;$expr&#37;";
                    #} else
                    #{

                    # %VAR% case.
                    # In this case we *do* want to match the tag expression
                    # again, as an embedded %VAR% may have expanded to
                    # create a valid outer expression. This is directly
                    # at odds with the %VAR{...}% case.
                    push( @stack, $stackTop );
                    $stackTop = '%';    # open new context
                                        #}
                }
            }
            else {
                push( @stack, $stackTop );
                $stackTop = '%';        # push a new context
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

    putBackBlocks( \$stackTop, $dirtyAreas, 'dirtyarea' )
      if $topicObject->isCacheable();

    putBackBlocks( \$stackTop, $verbatim, 'verbatim' );

    #print STDERR "FINAL $stackTop\n";

    return $stackTop;
}

# Handle expansion of a tag during topic rendering
# $tag is the tag name
# $args is the bit in the {} (if there are any)
# $topicObject should be passed for dynamic tags (not needed for
# session or constant tags
sub _expandMacroOnTopicRendering {
    my ( $this, $tag, $args, $topicObject ) = @_;

    require Foswiki::Attrs;

    my $e = $this->{prefs}->getPreference($tag);
    if ( defined $e ) {
        if ( $args && $args =~ m/\S/ ) {
            my $attrs = new Foswiki::Attrs( $args, 0 );

            $e = $this->_processMacros(
                $e,
                sub {
                    # Expand %DEFAULT and any parameter tags
                    my ( $this, $tag, $args, $topicObject ) = @_;
                    my $tattrs = new Foswiki::Attrs($args);

                    if ( $tag eq 'DEFAULT' ) {

                        # Define the %DEFAULT macro to return the value
                        # passed (if any) or the default= parameter (if
                        # present) otherwise.
                        return $attrs->{_DEFAULT} if defined $attrs->{_DEFAULT};
                        return $tattrs->{default} if defined $tattrs->{default};

                        # No default and no value - kill it.
                        return '';
                    }
                    my $val = $attrs->{$tag};
                    $val = $tattrs->{default} unless defined $val;
                    return expandStandardEscapes($val) if defined $val;
                    return undef;
                },
                $topicObject,
                1
            );
        }
    }
    elsif ( exists( $macros{$tag} ) ) {
        unless ( defined( $macros{$tag} ) ) {

            # Demand-load the macro module
            die $tag unless $tag =~ m/([A-Z_:]+)/i;
            $tag = $1;
            eval "require Foswiki::Macros::$tag";
            die $@ if $@;
            $macros{$tag} = eval "\\&$tag";
            die $@ if $@;
        }

        my $attrs = new Foswiki::Attrs( $args, $contextFreeSyntax{$tag} );
        $e = &{ $macros{$tag} }( $this, $attrs, $topicObject );
    }
    elsif ( $args && $args =~ m/\S/ ) {

        # Arbitrary %SOMESTRING{default="xxx"}% will expand to xxx
        # in the absence of any definition.
        my $attrs = new Foswiki::Attrs($args);
        if ( defined $attrs->{default} ) {
            $e = expandStandardEscapes( $attrs->{default} );
        }
    }
    return $e;
}

# Handle expansion of a tag during new topic creation. When creating a
# new topic from a template we only expand a subset of the available legal
# tags, and we expand %NOP% differently.
sub _expandMacroOnTopicCreation {
    my $this = shift;

    # my( $tag, $args, $topicObject ) = @_;

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
    return
      unless $_[0] =~
m/^(URLPARAM|DATE|(SERVER|GM)TIME|(USER|WIKI)NAME|WIKIUSERNAME|USERINFO)$/;

    return $this->_expandMacroOnTopicRendering(@_);
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

---++ StaticMethod registerTagHandler( $tag, $fnref, $syntax )

STATIC Add a tag handler to the function tag handlers.
   * =$tag= name of the tag e.g. MYTAG
   * =$fnref= Function to execute. Will be passed ($session, \%params, $web, $topic )
   * =$syntax= somewhat legacy - 'classic' or 'context-free' (context-free may be removed in future)


$syntax parameter:
Way back in prehistory, back when the dinosaur still roamed the earth, 
Crawford tried to extend the tag syntax of macros such that they could be processed 
by a context-free parser (hence the "context-free") 
and bring them into line with HTML. 
This work was banjaxed by one particular tyrranosaur, 
who felt that the existing syntax was perfect. 
However by that time Crawford had used it in a couple of places - most notable in the action tracker. 

The syntax isn't vastly different from what's there; the differences are: 
   1 Use either type of quote for parameters 
   2 Optional quotes on parameter values e.g. recurse=on 
   3 Standardised use of \ for escapes 
   4 Boolean (valueless) options (i.e. recurse instead of recurse="on" 


=cut

sub registerTagHandler {
    my ( $tag, $fnref, $syntax ) = @_;
    $macros{$tag} = $fnref;
    if ( $syntax && $syntax eq 'context-free' ) {
        $contextFreeSyntax{$tag} = 1;
    }
}

=begin TML

---++ ObjectMethod expandMacros( $text, $topicObject ) -> $text

Processes %<nop>VARIABLE%, and %<nop>TOC% syntax; also includes
'commonTagsHandler' plugin hook.

Returns the text of the topic, after file inclusion, variable substitution,
table-of-contents generation, and any plugin changes from commonTagsHandler.

$topicObject may be undef when, for example, expanding templates, or one-off strings
at a time when meta isn't available.

DO NOT CALL THIS DIRECTLY; use $topicObject->expandMacros instead.

=cut

sub expandMacros {
    my ( $this, $text, $topicObject ) = @_;

    return '' unless defined $text;

    # Plugin Hook
    $this->{plugins}
      ->dispatch( 'beforeCommonTagsHandler', $text, $topicObject->topic,
        $topicObject->web, $topicObject );

    #use a "global var", so included topics can extract and putback
    #their verbatim blocks safetly.
    my $verbatim = {};
    $text = takeOutBlocks( $text, 'verbatim', $verbatim );

    # take out dirty areas
    my $dirtyAreas = {};
    $text = takeOutBlocks( $text, 'dirtyarea', $dirtyAreas )
      if $topicObject->isCacheable();

    # Require defaults for plugin handlers :-(
    my $webContext   = $topicObject->web   || $this->{webName};
    my $topicContext = $topicObject->topic || $this->{topicName};

    my $memW = $this->{prefs}->getPreference('INCLUDINGWEB');
    my $memT = $this->{prefs}->getPreference('INCLUDINGTOPIC');
    $this->{prefs}->setInternalPreferences(
        INCLUDINGWEB   => $webContext,
        INCLUDINGTOPIC => $topicContext
    );

    $this->innerExpandMacros( \$text, $topicObject );

    $text = takeOutBlocks( $text, 'verbatim', $verbatim );

    # Plugin Hook
    $this->{plugins}
      ->dispatch( 'commonTagsHandler', $text, $topicContext, $webContext, 0,
        $topicObject );

    # process tags again because plugin hook may have added more in
    $this->innerExpandMacros( \$text, $topicObject );

    $this->{prefs}->setInternalPreferences(
        INCLUDINGWEB   => $memW,
        INCLUDINGTOPIC => $memT
    );

    # 'Special plugin tag' TOC hack, must be done after all other expansions
    # are complete, and has to reprocess the entire topic.

    if ( $text =~ m/%TOC(?:\{.*\})?%/ ) {
        require Foswiki::Macros::TOC;
        my $tocInstance = 1;
        $text =~
s/%TOC(?:\{(.*?)\})?%/$this->TOC($text, $topicObject, $1, $tocInstance++)/ge;
    }

    # Codev.FormattedSearchWithConditionalOutput: remove <nop> lines,
    # possibly introduced by SEARCHes with conditional CALC. This needs
    # to be done after CALC and before table rendering in order to join
    # table rows properly
    $text =~ s/^<nop>\r?\n//gm;

    # restore dirty areas
    putBackBlocks( \$text, $dirtyAreas, 'dirtyarea' )
      if $topicObject->isCacheable();

    putBackBlocks( \$text, $verbatim, 'verbatim' );

    # Foswiki Plugin Hook (for cache Plugins only)
    $this->{plugins}
      ->dispatch( 'afterCommonTagsHandler', $text, $topicContext, $webContext,
        $topicObject );

    return $text;
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
    ASSERT(0) if DEBUG;
    my $IN_FILE;
    open( $IN_FILE, "<$name" ) || return '';
    local $/ = undef;
    my $data = <$IN_FILE>;
    close($IN_FILE);
    $data = '' unless ( defined($data) );
    return $data;
}

=begin TML

---++ StaticMethod expandStandardEscapes($str) -> $unescapedStr

Expands standard escapes used in parameter values to block evaluation. See
System.FormatTokens for a full list of supported tokens.

=cut

sub expandStandardEscapes {
    my $text = shift;

    # expand '$n()' and $n! to new line
    $text =~ s/\$n\(\)/\n/gs;
    $text =~ s/\$n(?=[^[:alpha:]]|$)/\n/gs;

    # filler, useful for nested search
    $text =~ s/\$nop(\(\))?//gs;

    # $quot -> "
    $text =~ s/\$quot(\(\))?/\"/gs;

    # $comma -> ,
    $text =~ s/\$comma(\(\))?/,/gs;

    # $percent -> %
    $text =~ s/\$perce?nt(\(\))?/\%/gs;

    # $lt -> <
    $text =~ s/\$lt(\(\))?/\</gs;

    # $gt -> >
    $text =~ s/\$gt(\(\))?/\>/gs;

    # $amp -> &
    $text =~ s/\$amp(\(\))?/\&/gs;

    # $dollar -> $, done last to avoid creating the above tokens
    $text =~ s/\$dollar(\(\))?/\$/gs;

    return $text;
}

=begin TML

---++ ObjectMethod webExists( $web ) -> $boolean

Test if web exists
   * =$web= - Web name, required, e.g. ='Sandbox'=

A web _has_ to have a preferences topic to be a web.

=cut

sub webExists {
    my ( $this, $web ) = @_;

    ASSERT( UNTAINTED($web), 'web is tainted' ) if DEBUG;
    return $this->{store}->webExists($web);
}

=begin TML

---++ ObjectMethod topicExists( $web, $topic ) -> $boolean

Test if topic exists
   * =$web= - Web name, optional, e.g. ='Main'=
   * =$topic= - Topic name, required, e.g. ='TokyoOffice'=, or ="Main.TokyoOffice"=

=cut

sub topicExists {
    my ( $this, $web, $topic ) = @_;
    ASSERT( UNTAINTED($web),   'web is tainted' )   if DEBUG;
    ASSERT( UNTAINTED($topic), 'topic is tainted' ) if DEBUG;
    return $this->{store}->topicExists( $web, $topic );
}

=begin TML

---+++ ObjectMethod getWorkArea( $key ) -> $directorypath

Gets a private directory uniquely identified by $key. The directory is
intended as a work area for plugins etc. The directory will exist.

=cut

sub getWorkArea {
    my ( $this, $key ) = @_;
    return $this->{store}->getWorkArea($key);
}

=begin TML

---++ ObjectMethod getApproxRevTime (  $web, $topic  ) -> $epochSecs

Get an approximate rev time for the latest rev of the topic. This method
is used to optimise searching. Needs to be as fast as possible.

SMELL: is there a reason this is in Foswiki.pm, and not in Search?

=cut

sub getApproxRevTime {
    my ( $this, $web, $topic ) = @_;

    my $metacache = $this->search->metacache;
    if ( $metacache->hasCached( $web, $topic ) ) {

        #don't kill me - this should become a property on Meta
        return $metacache->get( $web, $topic )->{modified};
    }

    return $this->{store}->getApproxRevTime( $web, $topic );
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2017 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved. TWiki Contributors
are listed in the AUTHORS file in the root of this distribution.
Based on parts of Ward Cunninghams original Wiki and JosWiki.
Copyright (C) 1998 Markus Peter - SPiN GmbH (warpi@spin.de)
Some changes by Dave Harris (drh@bhresearch.co.uk) incorporated

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
