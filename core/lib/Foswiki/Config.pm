# See bottom of file for license and copyright information

package Foswiki::Config;

=begin TML

---+!! Class Foswiki::Config

Class representing configuration data.

---++ General concepts

The first and primary function of this class is to serve as a placeholder for
the configuration hash stored in [[?%QUERYSTRING%#ObjectAttributeData][=data=]] attribute.
Additionally this class implements:

   1. Bootstrapping of a fresh install
   1. Specs handling
   1. Some API
   
There're two modes a =Foswiki::Class= object may be in: _data_ and _specs_. The
difference between them is in whether =data= attribute contains a normal plain
hash (_data_ mode) or a tied one (_specs_ mode). Whichever one is active at any
given moment of time it doesn't affect application functionality – see
[[https://perldoc.perl.org/perltie.html][perltie]].

---+++ Specs mode

A =Foswiki::Config= class is switched into _specs_ mode with a call to
[[?%QUERYSTRING%#ObjectMethodSpecsMode][=specsMode()=]] method. The switch could
be performed dynamically at any time (as well as switching back to _data_) and
preserves all configuration data.

This mode is mainly needed by the =configure= script as it provides all required
information about configuration keys and their attributes. Additionally it can
be used for debugging purposes as values stored into the configuration hash
could be transparently verified for their validity.

The following classes are working together to implement _specs_ mode:

| *Class* | *Functionality* |
| =Foswiki::Config::DataHash= | =data= attribute hash is tied to it;\
  considered as top-level container class |
| =Foswiki::Config::Node= | Represents information about a key stored in\
  the configuration hash |
| =Foswiki::Config::Section= | A configuration section |

---+++ Globals

This class installs the global hash =%Foswiki::cfg= to provide compatibility
with legacy code. The hash is an alias to the
[[?%QUERYSTRING%?#ObjectAttributeData][=data=]] attribute. It's assumed that
normally there is only one instance of =Foswiki::Config= class and it's the one
stored in =Foswiki::App= =cfg= attribute. For that reason =%Foswiki::cfg= is
assumed to be the configuration hash of currently active application. This
assumption could be workarounded using
[[?%QUERYSTRING%#ObjectMethodAssignGlob][=assignGLOB()=]] and
[[?%QUERYSTRING%#ObjectMethodUnassignGlob][=unAssignGLOB()=]] methods.


---++ Terminology

*LSC* is an abbreviation used throughout this documention in place of "local
site configuration".

A configuration *key* is a sequence of characters starting with a word character
(=\w= in [[https://perldoc.perl.org/perlre.html][Perl regexps]]) and followed by
any character except ='.'= (a dot), or ='='= (an equal sign), or ='{'=, or ='}'=
(curly braces).

*Spec* is a file containing information about attributes of LSC keys. The
attributes include but not limited to key default value, description,
config section it belongs to, etc.

*Key path* is a sequence of configuration *keys* in either dot or curly braces 
notation. For example, a dot notation:

<verbatim>
JQueryPlugin.Plugins.Animate.Enabled
</verbatim>

Curly braces notation:

<verbatim>
{JQueryPlugin}{Plugins}{Animate}{Enabled}
</verbatim>

*Full key path* is a *key path* which includes all *keys* to identify a
distinctive configuration entry. The examples above are both representing a full
path. Sometimes a *partial key path* might be used to shorten a notation. Like,
for example, when it's known that we're speaking about =JQueryPlugin.Plugins=
part of the configuration then it would be ok to use just =Animate.Enabled=.

Current application object would often be referred here as =$app=. Most of the
time this is a shortcut for =$this->app= or legacy code supporting
=$Foswiki::app= variable. Whenever a reference to an instance of this class is
needed =$app->cfg= notation would be used.

---++ LSC File Format

The new LSC file has a line-based format. A line in the file could be a:

   * comment starting with =#=
   * empty line (whitespaces are allowed)
   * record line
   * data line of a here-document
   
A record line is a line starting with a full key path in dot-notation, followed
by an equal sign, and then by a valid Perl data or nothing. 'Valid data' means
that what is placed on the right side of the equal sign must produce a valid
output after being passed as a parameter to
=[[https://perldoc.perl.org/functions/eval.html][eval]]= function. For example:

<verbatim>
MailerContrib.RespectUserPrefs='LANGUAGE'
MaxLSCBackups=10
</verbatim>

The data could be a multi-line represented by a here-document. As any other kind
of data it must represent a valid Perl data would it be a simple multi-line string
or a complex structure:

<verbatim>
Log.Action=<<CF_DIWS
{
  'attach' => 1,
  'changes' => 1,
  'compare' => 1,
  'edit' => 1,
  'rdiff' => 1,
  'register' => 1,
  'rename' => 1,
  'rest' => 1,
  'save' => 1,
  'search' => 1,
  'upload' => 1,
  'view' => 1,
  'viewfile' => 1
}
CF_DIWS
</verbatim>

If nothing follows the equal sign then the key's value is undefined:

<verbatim>
Store.Encoding=
</verbatim>

---++ Macro expansion

Macros in a configuration hash must be expanded using =expandStr()= method.

A macro is a specially formatted string embedded into a configuration key
value. The macro string starts with ='$'= (dollar sign) and followed by
full key path enclosed in curly braces. See the =parseKeys()= method and
how it handles embraced keys.

Here is few examples of valid macro strings:

<verbatim>
${JQueryPlugin.Plugins.JEditable.Module}
${JQueryPlugin}{Plugins}{JEditable}{Module}
${JQueryPlugin.Plugins.JEditable}{Module}
</verbatim>

Macros are exanded recursivly. I.e. if we expand an embedded macro string then
key's value it represents will be expanded too prior to inserting it into the
original data.

Consider a sample chunk of LSC file:

<verbatim>
CoreDir='/usr/local/www/foswiki'
DataDir='${CoreDir}/data'
WorkingDir='${CoreDir}/working'
Cache.RootDir='${WorkingDir}/cache'
</verbatim>

It will result in the following configuration data hash:

<verbatim>
{
    CoreDir       => '/usr/local/www/foswiki',
    DataDir       => '/usr/local/www/foswiki/data',
    WorkingDir    => '/usr/local/www/foswiki/working',
    Cache.RootDir => '/usr/local/www/foswiki/working/cache',
}
</verbatim>

How undefined key values are handled is defined by =undef= and =undefFail=
parameters of the =expandStr()= method.

Any non-word character can be inserted using a special macro =${&lt;chr&gt;}= where
=&lt;chr&gt;= is the symbol we need to insert:

| =${$}= | _$_ |
| =${{}= | _{_ |
| =${}}= | _}_ |
| =${\}= | _\_ |
| =${$}{Key.Path}= | _${Key.Path}_ |

Note that a word char inside the curly braces is considered a valid key name.
Thus,a string _'${k}'_ will either expand into key =k= value; or if there is no
such key then the result of the expansion will depend on =undef= and =undefFail=
parameters of the =expandStr()= method.

---++ ATTRIBUTES

=cut

use Assert;
use Encode ();
use File::Basename;
use File::Spec;
use POSIX qw(locale_h);
use Unicode::Normalize;
use Cwd qw( abs_path );
use Try::Tiny;
use Foswiki qw(urlEncode urlDecode make_params);

use Foswiki::Configure::FileUtil;
use Foswiki::Exception::Config;

package Foswiki::Exception::_expandStr::UndefVal {
    use Foswiki::Class;
    extends qw<Foswiki::Exception>;
    with qw<Foswiki::Exception::Harmless>;
}

use Foswiki::Class -app;
extends qw(Foswiki::Object);
with qw(Foswiki::Util::Localize);

# Enable to trace auto-configuration (Bootstrap)
use constant TRAUTO => 1;

# This should be the one place in Foswiki that knows the syntax of valid
# configuration item keys. Only simple scalar hash keys are supported.
#
our $ITEMREGEX =
  qr/(?:\{(?:'(?:\\.|[^'])+'|"(?:\\.|[^"])+"|[A-Za-z0-9_\.]+)\})+/;

our $KeyNameREGEX = '\w[^\.=\{\}]*';
our $KeyPathREGEX =
  "(?<key>(?:\{$KeyNameREGEX\})+)|(?<key>$KeyNameREGEX(?:\.$KeyNameREGEX)*)";
our $KeyMacroREGEX =
"\\\$(?:\{(?<key>$KeyNameREGEX(?:\.$KeyNameREGEX)*)\}|(?<key>(?:\{$KeyNameREGEX\})+))";

# Generic booleans, used in some older LSC's
our $TRUE  = 1;
our $FALSE = 0;

# Configuration items that have been deprecated and must be mapped to
# new configuration items. The value is mapped unchanged.
my %remap = (
    '{StoreImpl}'           => '{Store}{Implementation}',
    '{AutoAttachPubFiles}'  => '{RCS}{AutoAttachPubFiles}',
    '{QueryAlgorithm}'      => '{Store}{QueryAlgorithm}',
    '{SearchAlgorithm}'     => '{Store}{SearchAlgorithm}',
    '{Site}{CharSet}'       => '{Store}{Encoding}',
    '{RCS}{FgrepCmd}'       => '{Store}{FgrepCmd}',
    '{RCS}{EgrepCmd}'       => '{Store}{EgrepCmd}',
    '{RCS}{overrideUmask}'  => '{Store}{overrideUmask}',
    '{RCS}{dirPermission}'  => '{Store}{dirPermission}',
    '{RCS}{filePermission}' => '{Store}{filePermission}',
    '{RCS}{WorkAreaDir}'    => '{Store}{WorkAreaDir}'
);

$Foswiki::regex{optionNameRegex} = qr/^-(?<option>[[:alpha:]_][[:alnum:]_]*)$/;

# Hash of parser_format => Parser::Module format. If parser module doesn't load
# the corresponding key would then exists but be undefined.
# This info is ok to share across different application instances as a module
# would be loaded only once per address space.
my %parserModules;

=begin TML

#ObjectAttributeData
---+++ ObjectAttribute data

Contains configuration hash. =%Foswiki::cfg= is an alias to this attribute.

=cut

has data => (
    is      => 'rw',
    lazy    => 1,
    clearer => 1,
    isa     => Foswiki::Object::isaHASH( 'data', noUndef => 1, ),
    builder => 'prepareData',
    trigger => sub {
        my $this = shift;
        $this->assignGLOB;
    },
);

=begin TML

---+++ ObjectAttribute files

What files we read the config from in the order of reading.

=cut

has files => (
    is      => 'rw',
    lazy    => 1,
    default => sub { [] },
);

=begin TML

---+++ ObjectAttribute lscFile

Default filename for local site configuration. Can be set from the following
sources (in the order from hight priority to lower):

   * corresponding constructor parameter
   * environment (or PSGI env) variable FOSWIKI_CONFIG
   * default constant 'LocalSite.cfg'
=cut

has lscFile => (
    is      => 'rwp',
    lazy    => 1,
    builder => 'prepareLscFile',
);

=begin TML

---+++ ObjectAttribute lscHeader

Default header to be put at the beginning of LSC file.
=cut

has lscHeader => (
    is      => 'ro',
    lazy    => 1,
    builder => 'prepareLscHeader',
);

=begin TML

---+++ ObjectAttribute failedConfig

Keeps the name of the failed config or spec file.

=cut

has failedConfig => ( is => 'rw', );

=begin TML

---+++ ObjectAttribute bootstrapMessage

If there is something to inform user about bootstrapping stage – the message
will be here.

=cut

has bootstrapMessage => ( is => 'rw', );

=begin TML

---+++ ObjectAttribute noExpand -> Bool

Default for =readConfig()= method =$noExpand= parameter when called by
constructor. Not used otherwise.

See [[?%QUERYSTRING%#ObjectMethodNew][constructor new()]].

=cut

has noExpand => ( is => 'rw', default => 0, );

=begin TML

---+++ ObjectAttribute noSpec -> Bool

Default for =readConfig()= method =$noSpec= parameter when called by
constructor. Not used otherwise.

See [[?%QUERYSTRING%#ObjectMethodNew][constructor new()]].

=cut

has noSpec => ( is => 'rw', default => 0, );

=begin TML

---+++ ObjectAttribute configSpec -> Bool

Default for =readConfig()= method =$configSpec= parameter when called by
constructor. Not used otherwise.

See [[?%QUERYSTRING%#ObjectMethodNew][constructor new()]].

=cut

has configSpec => ( is => 'rw', default => 0, );

=begin TML

---+++ ObjectAttribute noLocal -> Bool

Default for =readConfig()= method =$noLocal= parameter when called by
constructor. Not used otherwise.

See [[?%QUERYSTRING%#ObjectMethodNew][constructor new()]].

=cut

has noLocal => ( is => 'rw', default => 0, );

=begin TML

---+++ ObjectAttribute rootSection => $rootSectionObject

The root section object. Holds a list of first-level sections in the order,
defined by specs.

=cut

has rootSection => (
    is      => 'rw',
    lazy    => 1,
    clearer => 1,
    isa     => Foswiki::Object::isaCLASS(
        'rootSection', 'Foswiki::Config::Section', noUndef => 1,
    ),
    builder => 'prepareRootSection',
);

=begin TML

---+++ ObjectAttribute specFiles

A object of =Foswiki::Config::Spec::Files= class. List of specs found.

=cut

has specFiles => (
    is      => 'rw',
    lazy    => 1,
    clearer => 1,
    isa     => Foswiki::Object::isaCLASS(
        'specFiles',
        'Foswiki::Config::Spec::Files',
        noUndef => 1,
    ),
    builder => 'prepareSpecFiles',
);

=begin TML

---+++ ObjectAttribute dataHashClass

Class name used to create tied data hash.

=cut

has dataHashClass => (
    is      => 'ro',
    lazy    => 1,
    clearer => 1,
    builder => 'prepareDataHashClass',
);

=begin TML

---+++ ObjectAttribute _specParsers

Cache of spec parser objects.

=cut

has _specParsers => (
    is      => 'ro',
    lazy    => 1,
    clearer => 1,
    builder => '_prepareSpecParsers',
);

# Hash of optionName => arity
has _keyOptArity => (
    is      => 'ro',
    lazy    => 1,
    clearer => 1,
    builder => '_prepareKeyOptArity',
);

# Hash of optionName => arity
has _secOptArity => (
    is      => 'ro',
    lazy    => 1,
    clearer => 1,
    builder => '_prepareSecOptArity',
);

# LSC file object of Foswiki::File class. A temporary storage for read/write
# methods, doesn't utilize prepare method because it is always externally
# initialized.
has _lscFileObj => (
    is      => 'rw',
    clearer => 1,
);

# List of key/value pairs. Used by both LSC read and write methods.
has _lscRecords => (
    is      => 'rw',
    clearer => 1,
    lazy    => 1,
    builder => '_prepareLscRecords',
);

# Current position in _lscRecords list.
has _lscRecPos => ( is => 'rw', );

# Configuration shortcut attributes.

=begin TML

---++ METHODS

=cut

=begin TML

#ObjectMethodNew
---+++ ClassMethod new([noExpand => 0/1][, noSpec => 0/1][, configSpec => 0/1][, noLoad => 0/1])
   
   * =noExpand= - suppress expansion of $Foswiki vars embedded in
     values.
   * =noSpec= - can be set when the caller knows that Foswiki.spec
     has already been read.
   * =configSpec= - if set, will also read Config.spec files located
     using the standard methods (iff !$nospec). Slow.
   * =noLocal= - if set, Load will not re-read an existing LocalSite.cfg.
     this is needed when testing the bootstrap.  If it rereads an existing
     config, it overlays all the bootstrapped settings.
=cut

sub BUILD {
    my $this = shift;
    my ($params) = @_;

    $this->_workOutOS;
    $this->_populatePresets;
    $this->_guessDefaults;

    #$this->data->{isVALID} =
    #  $this->readConfig( $this->noExpand, $this->noSpec, $this->configSpec,
    #    $this->noLocal, );

    try {
        $this->read(
            noExpand   => $this->noExpand,
            noDefaults => $this->noSpec,
            onlyMain   => !$this->configSpec,
            noLocal    => $this->noLocal,
        );
    }
    catch {
        my $e = Foswiki::Exception::Fatal->transmute( $_, 0 );
        warn $e->stringify;
        $this->data->{isVALID} = 0;
    };

    $this->_setupGlobals;

    return;
}

sub DEMOLISH {
    my $this = shift;
    $this->unAssignGLOB;
}

sub _workOutOS {
    my $this = shift;
    unless ( $this->data->{DetailedOS} ) {
        $this->data->{DetailedOS} = $^O;
    }
    return if $this->data->{OS};
    if ( $this->data->{DetailedOS} =~ m/darwin/i ) {    # Mac OS X
        $this->data->{OS} = 'UNIX';
    }
    elsif ( $this->data->{DetailedOS} =~ m/Win/i ) {
        $this->data->{OS} = 'WINDOWS';
    }
    elsif ( $this->data->{DetailedOS} =~ m/vms/i ) {
        $this->data->{OS} = 'VMS';
    }
    elsif ( $this->data->{DetailedOS} =~ m/bsdos/i ) {
        $this->data->{OS} = 'UNIX';
    }
    elsif ( $this->data->{DetailedOS} =~ m/solaris/i ) {
        $this->data->{OS} = 'UNIX';
    }
    elsif ( $this->data->{DetailedOS} =~ m/dos/i ) {
        $this->data->{OS} = 'DOS';
    }
    elsif ( $this->data->{DetailedOS} =~ m/^MacOS$/i ) {

        # MacOS 9 or earlier
        $this->data->{OS} = 'MACINTOSH';
    }
    elsif ( $this->data->{DetailedOS} =~ m/os2/i ) {
        $this->data->{OS} = 'OS2';
    }
    else {

        # Erm.....
        $this->data->{OS} = 'UNIX';
    }
}

=begin TML

---+++ ObjectMethod localize( %init ) => $holder

This method preserves current =data= attribute on =_dataStack= and sets =data=
to the values provided in =%init=.

See also: =Foswiki::Util::Localize=

=cut

sub setLocalizableAttributes { return qw(data files); }

around localize => sub {
    my $orig = shift;
    my $this = shift;
    my %init = @_;

    return $orig->( $this, data => \%init, );
};

around doLocalize => sub {
    my $orig = shift;
    my $this = shift;

    $orig->( $this, @_ );

    $this->assignGLOB;
};

=begin TML

---+++ ObjectMethod _createSpecParser( $format ) -> $parser

Creates a new parser object for =$format=. 

=cut

sub _createSpecParser {
    my $this   = shift;
    my $format = shift;

    my $fmtClass = "Foswiki::Config::Spec::Format::" . $format;

    $parserModules{$format} = $fmtClass;

    return $this->create( $fmtClass, cfg => $this, @_ );
}

=begin TML

---+++ ObjectMethod getSpecParser( $format ) -> $parser

Returns a parser object for specified spec =$format=. Undef is returned is such
format is now known or parser module load failed.

Format modules are defined undef =Foswiki::Config::Spec::Format::= namespace and
available in corresponding directory.

=cut

sub getSpecParser {
    my $this   = shift;
    my $format = shift;

    my $parsers = $this->_specParsers;

    return if exists $parsers->{$format} && !$parsers->{$format};

    my $parser;

    try {
        $parser = $this->_createSpecParser($format);
    }
    catch {
        my $e = Foswiki::Exception::Fatal->transmute( $_, 0 );

        # SMELL Error messages must be somehow buffered. An API must be
        # considered on Foswiki::App.
        say STDERR "Cannot load parser for spec format '" . $format . "': "
          . $e;

        $parserModules{$format} = undef;
    };

    $parsers->{$format} = $parser;

    return undef unless $parser;
    return $parser;
}

=begin TML

---+++ ObjectMethod fetchDefaults( %params )

Fetch keys default values from specs cache. Refresh cache if necessary.

---++++!! Parameters

| *Param* | *Description* | *Default* |
| =data= | Hashref to store defaults into | =$app->cfg->data= |
| =onlyMain= | Bool, fetch only the main spec file defaults (normally – =Foswiki.spec=) | _false_ |

See =Foswiki::Config::Spec::CacheFile=, =Foswiki::Config::Spec::File=.

=cut

sub fetchDefaults {
    my $this   = shift;
    my %params = @_;

    state $called = 0;

    if ($called) {

        # This must never happen. But if it is – no whistle and bells of very
        # informative exceptions are needed. Just die, as simple as this.
        die "Circular dependecy in call to fetchDefaults!";
    }

    $called = 1;

    my $specFiles = $this->specFiles;
    my @setParams = defined $params{data} ? ( data => $params{data} ) : ();
    my @flist =
      $params{onlyMain} ? ( $specFiles->mainSpec ) : @{ $specFiles->list };

    foreach my $specFile (@flist) {

        #say STDERR "Checking cache of ", $specFile->path;
        $specFile->refreshCache;

        foreach my $pair ( @{ $specFile->cacheFile->entries } ) {
            $this->set( @$pair, @setParams );
        }
    }

    $called = 0;
}

=begin TML

---+++ ObjectMethod readConfig( $noExpand, $noSpec, $configSpec, $noLocal )

%RED% *Must not be used any more* %ENDCOLOR%

In normal Foswiki operations as a web server this method is called by the
=BEGIN= block of =Foswiki.pm=.  However, when benchmarking/debugging it can be
replaced by custom code which sets the configuration hash.  To prevent us from
overriding the custom code again, we use an "unconfigurable" key
=$cfg->data->{ConfigurationFinished}= as an indicator.

Note that this method is called by Foswiki and configure, and normally reads
=Foswiki.spec= to get defaults. Other spec files (those for extensions) are
*not* read unless the $config_spec flag is set.

The assumption is that =configure= will be run when an extension is installed,
and that will add the config values to LocalSite.cfg, so no defaults are
needed. Foswiki.spec is still read because so much of the core code doesn't
provide defaults, and it would be silly to have them in two places anyway.

=cut

sub readConfig {
    my $this = shift;
    my ( $noExpand, $noSpec, $configSpec, $noLocal ) = @_;

    # To prevent us from overriding the custom code in test mode
    return 1 if $this->data->{ConfigurationFinished};

    # Assume LocalSite.cfg is valid - will be set false if errors detected.
    my $validLSC = 1;

    # Read Foswiki.spec and LocalSite.cfg
    # (Suppress Foswiki.spec if already read)

    # Old configs might not bootstrap the OS settings, so set if needed.
    $this->_workOutOS unless ( $this->data->{OS} && $this->data->{DetailedOS} );

    # BEGIN of new specs code
    # SMELL It's here for testing only.
    #$this->specsMode;

    # END of new specs code

    unless ($noSpec) {
        push @{ $this->files }, 'Foswiki.spec';
    }
    if ( !$noSpec && $configSpec ) {

        foreach my $dir (@INC) {
            foreach my $subdir ( 'Foswiki/Plugins', 'Foswiki/Contrib' ) {
                my $d;
                next unless opendir( $d, "$dir/$subdir" );
                my %read;
                foreach
                  my $extension ( grep { !/^\./ && !/^Empty/ } readdir $d )
                {
                    next if $read{$extension};
                    $extension =~ m/(.*)/;    # untaint
                    my $file = "$dir/$subdir/$1/Config.spec";
                    next unless -e $file;
                    push( @{ $this->files }, $file );
                    $read{$extension} = 1;
                }
                closedir($d);
            }
        }
    }
    my $lscFile = $this->lscFile;
    unless ($noLocal) {
        push @{ $this->files }, $lscFile;
    }

    for my $file ( @{ $this->files } ) {
        my $return = do $file;

        unless ( defined $return && $return eq '1' ) {

            my $errorMessage;
            if ($@) {
                $errorMessage = "Failed to parse $file: $@";
                warn "couldn't parse $file: $@" if $@;
            }
            next if ( !DEBUG && ( $file =~ m/Config\.spec$/ ) );
            if ( not defined $return ) {
                unless ( $! == 2 && $file eq $lscFile ) {

                    # LocalSite.cfg doesn't exist, which is OK
                    warn "couldn't do $file: $!";
                    $errorMessage = "Could not do $file: $!";
                }
                $this->failedConfig($file);
                $validLSC = 0;
            }

            # Pointless (says CDot), Config.spec does not need 1; at the end
            #elsif ( not $return eq '1' ) {
            #   print STDERR
            #   "Running file $file returned  unexpected results: $return \n";
            #}
            if ($errorMessage) {

                # SMELL die has to be replaced with an exception.
                die <<GOLLYGOSH;
Content-type: text/plain

$errorMessage
Please inform the site admin.
GOLLYGOSH
                exit 1;
            }
        }
    }

    # Patch deprecated config settings
    # TODO: remove this in version 2.0
    if ( exists $this->data->{StoreImpl} ) {
        $this->data->{Store}{Implementation} =
          'Foswiki::Store::' . $this->data->{StoreImpl};
        delete $this->data->{StoreImpl};
    }
    foreach my $el ( keys %remap ) {

        # Only remap if the old key extsts, and the new key does NOT exist
        if ( ( eval("exists \$this->data->{$el}") ) ) {
            eval( <<CODE );
\$this->data->{$remap{$el}}=\$this->data->{$el} unless ( exists \$this->data->{$remap{$el}} );
delete \$this->data->{$el};
CODE
            print STDERR "REMAP failed $@" if ($@);
        }
    }

    # Expand references to $this->data vars embedded in the values of
    # other $this->data vars.
    $this->expandValue( $this->data ) unless $noExpand;

    $this->data->{ConfigurationFinished} = 1;

    if ( $^O eq 'MSWin32' ) {

        #force paths to use '/'
        $this->data->{PubDir}      =~ s|\\|/|g;
        $this->data->{DataDir}     =~ s|\\|/|g;
        $this->data->{ToolsDir}    =~ s|\\|/|g;
        $this->data->{ScriptDir}   =~ s|\\|/|g;
        $this->data->{TemplateDir} =~ s|\\|/|g;
        $this->data->{LocalesDir}  =~ s|\\|/|g;
        $this->data->{WorkingDir}  =~ s|\\|/|g;
    }

    # Add explicit {Site}{CharSet} for older extensions. Default to utf-8.
    # Explanation is in http://foswiki.org/Tasks/Item13435
    $this->data->{Site}{CharSet} = 'utf-8';

    # Explicit return true if we've completed the load
    return $validLSC;
}

sub _expandAll {
    my $this   = shift;
    my %params = @_[ 1 .. $#_ ];

    if ( ref( $_[0] ) ) {
        if ( ref( $_[0] ) eq 'HASH' ) {
            foreach my $key ( keys %{ $_[0] } ) {
                $this->_expandAll( $_[0]->{$key}, %params, );
            }
        }
        elsif ( ref( $_[0] ) eq 'ARRAY' ) {
            foreach my $val ( @{ $_[0] } ) {
                $this->_expandAll( $val, %params, );
            }
        }

        # Ignore any other ref types.
    }
    elsif ( defined $_[0] && $_[0] =~ /$KeyMacroREGEX/ ) {
        $_[0] = $this->expandStr( %params, str => $_[0], );
    }
}

=begin TML

---+++ ObjectMethod expandAll( %params )

Expands macros in all keys of a configuration data hash.

---++++!! Parameters

| *Param* | *Description* | *Default* |
| =undef= | What to replace an undefined key value with | _"undef"_ |
| =undefFail= | Bool, wether to fail if an undefined key value encountered | _false_ |
| =data= | Configuration data hash | =$app->cfg->data= |

=%params= is transparently sent over to =expandStr()= method except for =str=
key.

=cut

sub expandAll {
    my $this   = shift;
    my %params = @_;

    $params{undef}     = 'undef' unless exists $params{undef};
    $params{undefFail} = 0       unless exists $params{undefFail};

    my $data = defined $params{data} ? $params{data} : $this->data;

    $this->Throw( 'Foswiki::Exception::Fatal',
        "data key must be a hashref in call to expandAll() method",
    ) unless ref($data) eq 'HASH';

    $this->_expandAll( $data, %params );
}

=begin TML

---+++ ObjectMethod read( %params ) -> $data

This method replaces the legacy =readConfig()=. Depending on what is defined
by the parameters it:

   * Fetches default values from spec files
   * Reads the local site configuration file
   * Expands macros in configuration keys
   * Sets isVALID key to _true_ if LSC has been read successfully. It would remain _false_ whether LSC read failed or =noLocal= param is _true_.
   * Normalizes =!PubDir, !DataDir, !ToolsDir, !ScriptDir, !TemplateDir, !LocalesDir,= and =WorkingDir= to correspond the OS used.
   * Sets =ConfigurationFinished= configuration key to true
   
The method returns filled in configuration data hash.

---++++!! Parameters

| *Param* | *Description* | *Default* |
| =data= | Configuration data hash to fill | =$app->cfg->data= |
| =noDefaults= | Don't fetch spec default values | _false_ |
| =onlyMain= | Only fetch defaults of the main spec file | _false_ |
| =noLocal= | Don't read local site configuration file | _false_ |
| =noExpand= | Don't expand macros in the configuration hash | _false_ |
| =lscFile= | Name of the local configuration file | see =readLSCStart()= method |
| =_stage= | The initialization stage as defined by =Foswiki::App= =stage= context. | =$app->context->{appStage}= |

%X% *NOTE:* The =_stage= param is not used by the core but could be taken into
account by an extension overriding a pluggable method. It is also passed over to
the =expandAll()= method.

=cut

sub read {
    my $this   = shift;
    my %params = @_;

    my $data;
    my ( @dataParam, @lscFileParam );

    if ( $params{data} ) {
        $data = $params{data};
        push @dataParam, data => $data;
    }
    else {
        $data = $this->data;
    }

    return if $data->{ConfigurationFinished};

    my $stage = $params{_stage} // $this->app->context->{appStage};

    # Similar to the old readConfig() noSpec set to true.
    my $noDefaults = exists $params{noDefaults} ? $params{noDefaults} : 0;

    # Similar to the old readConfig() when both noSpec and configSpec are false.
    # Reads only defaults from the main spec file (Foswiki.spec for the moment).
    # Taken into account only when noDefaults is false.
    my $onlyMain = exists $params{onlyMain} ? $params{onlyMain} : 0;

    # Don't read LSC
    my $noLocal = exists $params{noLocal} ? $params{noLocal} : 0;

    # Don't expand macros in the final data hash.
    my $noExpand = exists $params{noExpand} ? $params{noExpand} : 0;

    unless ($noDefaults) {
        $this->fetchDefaults(
            onlyMain => $onlyMain,
            data     => $data,
            _stage   => $stage,
        );
    }

    $data->{isVALID} = 0;

    unless ($noLocal) {
        push @lscFileParam, lscFile => $params{lscFile}
          if defined $params{lscFile};
        $data->{isVALID} =
          $this->readLSC( @dataParam, @lscFileParam, _stage => $stage, );
    }

    unless ($noExpand) {
        $this->expandAll( @dataParam, _stage => $stage, );
    }

    # Make all path conformant to the OS we running under.
    foreach my $dirKey (
        qw(PubDir DataDir ToolsDir ScriptDir TemplateDir LocalesDir WorkingDir))
    {
        next unless defined $data->{$dirKey};
        my ( $v, $d, $f ) = File::Spec->splitpath( $data->{$dirKey} );
        my @d = File::Spec->splitdir($d);
        $data->{$dirKey} =
          File::Spec->canonpath(
            File::Spec->catpath( $v, File::Spec->catdir(@d), $f ) );
    }

    # Add explicit {Site}{CharSet} for older extensions. Default to utf-8.
    # Explanation is in http://foswiki.org/Tasks/Item13435
    $data->{Site}{CharSet} = 'utf-8' unless defined $data->{Site}{CharSet};

    $data->{ConfigurationFinished} = 1;

    return $data;
}

=begin TML

---+++ ObjectMethod readLSCStart( %params ) -> $success

This method prepares reading from LSC file. Only to be called by =readLSC()=
method.

As a matter of fact this method reads the entire LSC file in %WIKITOOLNAME%
format into memory and prepares data for =readLSCRecord()= method.

Returns _false_ if failed.

---++++!! Parameters

| *Param* | *Description* | *Default* |
| =lscFile= | Full pathname of LSC file | =$this->lscFile= with _.new_ suffix appended in %WIKITOOLNAME% library directory |

%X% *NOTE:* The _.new_ suffix is a temporary solution to avoid conflicts with
legacy code. Will be removed in release.

=cut

sub readLSCStart {
    my $this   = shift;
    my %params = @_;

    $this->_clear_lscRecords;
    $this->_clear_lscFileObj;

    my $lscFile = $params{lscFile}
      // File::Spec->catfile( Foswiki::guessLibDir, $this->lscFile . ".new" );

    unless ( -r $lscFile ) {
        warn "$lscFile is not readable";
        return 0;
    }
    unless ( -f $lscFile ) {
        warn "$lscFile is not a plain file";
        return 0;
    }

    my $cfFile = $this->create(
        'Foswiki::File',
        path => $lscFile,

        # Prevent occasional overwriting of the LSC would a bug sneak into the
        # code.
        autoWrite => 0,
    );

    my $lnum = 0;
    my ( $hereDoc, $hereKey, $hereVal, @lscRecords );
    foreach my $line ( split /\n/, $cfFile->content ) {
        my ( $keyPath, $keyVal );
        $lnum++;
        chomp $line;
        next if !$hereDoc && $line =~ /^\s*(?:#|\z)/;
        my $doEval = 0;
        if ($hereDoc) {
            if ( $line =~ /^$hereDoc\s*$/ ) {
                $keyVal  = $hereVal;
                $keyPath = $hereKey;
                $doEval  = 1;
                undef $hereDoc;
                undef $hereKey;
                undef $hereVal;
            }
            else {
                $hereVal .= "\n$line";
            }
        }
        elsif ( $line =~ /^\s*(?<keyPath>$KeyPathREGEX)\s*=\s*(?<keyVal>.+)?$/ )
        {
            ( $keyPath, $keyVal ) = @+{qw(keyPath keyVal)};
            if ( defined($keyVal) && length($keyVal) ) {
                if ( $keyVal =~ s/^\<\<// ) {
                    $hereDoc = $keyVal;
                    $hereKey = $keyPath;

                    # Reset to avoid preliminary setting of the key.
                    undef $keyPath;

                    if ( length($hereDoc) == 0 ) {
                        warn
"Bad here-document at $lscFile($lnum): must have signature";
                        return 0;
                    }
                }
                else {
                    $doEval = 1;
                }
            }
            else {
                $keyVal = undef;
            }
        }
        else {
            say STDERR "^\\s*(?<keyPath>$KeyPathREGEX)\\s*=\\s*(?<keyVal>.+)\$";
            warn
"Failed to read $lscFile($lnum): unrecorgnized format of line '$line'";
            return 0;
        }

        if ($keyPath) {
            if ($doEval) {
                my $interp = eval $keyVal;
                if ($@) {
                    warn "Syntax error in $lscFile($lnum), value '$keyVal': $@";
                    return 0;
                }
                $keyVal = $interp;
            }
            push @lscRecords, [ $keyPath, $keyVal ];
        }
    }

    if ($hereDoc) {
        warn "Unclosed here-doc labeled $hereDoc in $lscFile";
        return 0;
    }

    $this->_lscRecords( \@lscRecords );
    $this->_lscRecPos(0);

    return 1;
}

=begin TML

---+++ ObjectMethod readLSCRecord( %params ) -> ($success, $keyPath, $keyVal )

Fetches next record from LSC file. Only to be called by =readLSC()= method.

Returns a list of =($success, $keyPath, $keyVal)=. If =$success= is _false_ then
record reading failed. If =$success= is _true_ but =$keyPath= is _undef_ then it
was an attempt to read past last record.

=cut

sub readLSCRecord {
    my $this   = shift;
    my %params = @_;

    my $curPos = $this->_lscRecPos;

    $this->_lscRecPos( $curPos + 1 );

    return ( 1, undef, undef ) if $curPos >= scalar( @{ $this->_lscRecords } );

    return ( 1, @{ $this->_lscRecords->[$curPos] } );
}

=begin TML

---+++ ObjectMethod readLSCFinalize( %params ) -> $success

Finalizes read cycle. Only to be called by =readLSC()= method.

Returns _true_ if everything is ok.

=cut

sub readLSCFinalize {
    my $this = shift;

    $this->_clear_lscFileObj;
    $this->_clear_lscRecords;
    $this->_lscRecPos(0);

    return 1;
}

=begin TML

#ObjectMethodReadLSC
---+++ ObjectMethod readLSC( %params ) -> $success

Reads local site configuration.

Returns true if everything is ok.

---++++!! Parameters

| *Param* | *Description* | *Default* |
| =data= | Configuration data hash reference to read LSC into. | $app->cfg->data |

Read the Implementation Notes section on how parameters are handled.

---++++!! Implementation Notes

This method does a very simple thing:

   1. Calls =readLSCStart()= method to initiate the reading
   1. Fetches config records consisting of key path and value one by one with =readLSCRecord()= and stores it in the hash defined by =data= param using =set()= method.
   1. Calls =readLSCFinalize()=.

Although the only parameter used by this method is =data= a user is allowed to
supply more parameters if necessary. They all will be passed over to the
=readLSCStart()= method as is with no modification except for =data= which might
be altered for a purpose and is always appended to the end of parameters so that
it would override any user supplied value for it. For the =readLSCRecord()= and
=readLSCFinalize()= method =data= is the only parameter passed.

Such approach to handling paramers makes sense if one remembers that all four =readLSC*=
methods are pluggables. So, any extra parameter not handled by the core could be
useful for a extension.
   
=cut

sub readLSC {
    my $this   = shift;
    my %params = @_;

 # Avoid dying of warnings here – at least until bufferized error reporting is
 # in place. Otherwise we wouldn't even be able to test bootstrap.
    local $SIG{__WARN__};

    my $cfgData = $params{data} // $this->data;

    return 0 unless $this->readLSCStart( @_, data => $cfgData, );

    my ( $rc, $keyPath, $keyVal );
    do {
        ( $rc, $keyPath, $keyVal ) = $this->readLSCRecord( data => $cfgData );
        if ( $rc && defined $keyPath ) {
            $this->set( $keyPath, $keyVal, data => $cfgData );
        }
    } while ( $rc && defined $keyPath );

    # Avoid possible optimization, call and get finalize return value
    # explicitly.
    my $finalRc = $this->readLSCFinalize( data => $cfgData );

    return ( $rc && $finalRc );
}

=begin TML

---+++ ObjectMethod _genLSCHereDoc( $val ) -> $hereDocStr

Generates a valid heredoc string which would incapsulate =$val=.

=cut

sub _genLSCHereDoc {
    my $this = shift;
    my $val  = shift;

    my $endMark;
    my @a = ( 'A' .. 'Z' );

    # End-mark must not be contained in the value string. So, repeat generation
    # until we get a unique one.
    do {
        $endMark = 'CF_';
        for ( 1 .. 4 ) {
            $endMark .= $a[ int( rand( scalar(@a) ) ) ];
        }
    } while ( $val =~ /$endMark/ );

    return "<<$endMark\n$val\n$endMark";
}

=begin TML

---+++ ObjectMethod writeLSCStart( %params )

Initiates LSC writing.

---++++!! Parameters

| *Param* | *Description* | *Default* |
| =lscFile= | LSC file name | _LocalSite.cfg.new_ in Foswiki lib directory | 

=cut

sub writeLSCStart {
    my $this   = shift;
    my %params = @_;

    my $lscFile = $params{lscFile}
      // File::Spec->catfile( Foswiki::guessLibDir, $this->lscFile . ".new" );

    $this->_lscFileObj(
        $this->create(
            'Foswiki::File',
            path       => $lscFile,
            autoWrite  => 1,
            autoCreate => 1,
            content    => '',
        )
    );
}

=begin TML

---+++ ObjectMethod writeLSCRecord( %params )

This method is for low-level writing of a single key/value pair into LSC.

---++++!! Parameters

| *Param* | *Description* | *Default* |
| =key= | Full configuration key path | |
| =value= | Key value | |
| =comment= | Comment text to be written before configuration record. Must be a clear text with no '#' prepended. | |

=cut

sub writeLSCRecord {
    my $this   = shift;
    my %params = @_;

    # Support for extensions. If an extension doesn't want a record to be stored
    # in a standard location it could simply delete 'key' item from the params.
    return unless defined $params{key};

    my $comment =
      defined $params{comment}
      ? join( "\n", map { "# $_" } split /\n/, $params{comment} )
      : undef;
    push @{ $this->_lscRecords },
      {
        key     => $params{key},
        value   => $params{value},
        comment => $comment,
      };
}

=begin TML

---+++ ObjectMethod writeLSCFinalize( %params )

Called when all LSC records are stored.

---++++!! Parameters

No parameters are used.

=cut

sub writeLSCFinalize {
    my $this   = shift;
    my %params = @_;

    my $_lscFileObj = $this->_lscFileObj;

    $_lscFileObj->autoWrite(0);

    $_lscFileObj->content( $_lscFileObj->content . "\n" );

    foreach my $rec ( @{ $this->_lscRecords } ) {
        my $key     = $rec->{key};
        my $val     = $rec->{value} // '';
        my $comment = $rec->{comment};

        if ( $val =~ /\n/ ) {

            # Special notion for multiline values.
            $val = $this->_genLSCHereDoc($val);
        }

        $_lscFileObj->content( $_lscFileObj->content
              . ( $comment ? "$comment\n" : '' )
              . "$key=$val\n" );
    }

    $_lscFileObj->autoWrite(1);
    $this->_clear_lscFileObj;
    $this->_clear_lscRecords;
}

=begin TML

---+++ ObjectMethod writeLSC( %params )

Writes configuration data into LSC file.

---++++!! Parameters

See also parameters of =writeLSCStart()= method.

| *Param* | *Description* | *Default* |
| =data= | Configuration data hash to be written into LSC file. | =$app->cfg->data= |

---++++!! Implementation notes

This method does the following:

   1. Converts the =data= hash into specs mode unless it's a hash tied to =$app->cfg->dataHashClass= already.
   1. Calls =writeLSCStart()=.
   1. Gets all leaf nodes from the data hash and writes them one-by-one with =writeLSCRecord()= method.
   1. Calls =writeLSCFinalize()=.

Because of the convertion into specs mode (see
=[[?%QUERYSTRING%#ObjectMethodSpecsMode][specsMode()]]= method) the data hash
may eventually contain more keys then there was initially. If this is
undesirable behavior then the =data= hash must be already in specs mode when
passed into the method.

Before writing a key into LSC file it is checked against all known keys defined
in specs. If the key is not found then it is prepended with a warning comment.

All user defined parameters are handled similar to the
=[[?%QUERYSTRING%#ObjectMethodReadLSC][readLSC()]]= method.

=cut

sub writeLSC {
    my $this   = shift;
    my %params = @_;

    my $cfgData = $params{data} // $this->data;

    my $root = tied %$cfgData;

    $cfgData = $this->specsMode( setAttr => 0, data => $cfgData, )
      unless $root && $root->isa( $this->dataHashClass );

    $root = tied %$cfgData;

    $this->writeLSCStart( @_, data => $cfgData );

    my @cfgKeys = sort map { $_->fullName } $root->getLeafNodes;

    my %specKeys;

    foreach my $sf ( @{ $this->specFiles->list } ) {
        $specKeys{ $_->[0] } = 1 foreach @{ $sf->cacheFile->entries };
    }

    local $Data::Dumper::Terse    = 1;
    local $Data::Dumper::Deepcopy = 1;

    my $comment = $this->lscHeader . "\n";
    foreach my $cfKey (@cfgKeys) {
        unless ( $specKeys{$cfKey} ) {
            $comment .= "Key $cfKey is not defined in a spec file";

            #say STDERR "Key $cfKey is not defined in specs";
        }

        my @keys      = $this->parseKeys($cfKey);
        my $leafKey   = pop @keys;
        my $keyObject = $root->getKeyObject(@keys);
        my $val;

        if ( defined $keyObject ) {
            $val = $keyObject->nodes->{$leafKey}->getValue;
        }

        if ( defined $val ) {
            $val = Data::Dumper->Dump( [$val] );
            chomp $val;
        }

        $this->writeLSCRecord(
            key     => $cfKey,
            value   => $val,
            comment => $comment,
            data    => $cfgData,
        );

        undef $comment;
    }

    $this->writeLSCFinalize( data => $cfgData, );
    return;
}

=begin TML

---+++ ObjectMethod expandValue($datum [, $mode])

Expands references to Foswiki configuration items which occur in the
values configuration items contained within the datum, which may be a
hash or array reference, or a scalar value. The replacement is done in-place.

$mode - How to handle undefined values:
   * false:  'undef' (string) is returned when an undefined value is
     encountered.
   * 1 : return undef if any undefined value is encountered.
   * 2 : return  '' for any undefined value (including embedded)
   * 3 : die if an undefined value is encountered.

=cut

sub expandValue {
    my $this = shift;
    my $undef;
    $this->_expandValue( $_[0], ( $_[1] || 0 ), $undef );

    $_[0] = undef if ($undef);
}

# $_[0] - value being expanded
# $_[1] - $mode
# $_[2] - $undef (return)
sub _expandValue {
    my $this = shift;
    if ( ref( $_[0] ) eq 'HASH' ) {
        $this->expandValue( $_, $_[1] ) foreach ( values %{ $_[0] } );
    }
    elsif ( ref( $_[0] ) eq 'ARRAY' ) {
        $this->expandValue( $_, $_[1] ) foreach ( @{ $_[0] } );

        # Can't do this, because Windows uses an object (Regexp) for regular
        # expressions.
        #    } elsif (ref($_[0])) {
        #        die("Can't handle a ".ref($_[0]));
    }
    else {
        1 while ( defined( $_[0] )
            && $_[0] =~
            s/(\$Foswiki::cfg$ITEMREGEX)/_handleExpand($this, $1, @_[1,2])/ges
        );
    }
}

# Used to expand the $Foswiki::cfg variable in the expand* routines.
# $_[0] - $item
# $_[1] - $mode
# $_[2] - $undef
sub _handleExpand {
    my $this = shift;
    my $val  = eval( $_[0] );
    $this->Throw( 'Foswiki::Exception::Fatal', "Error expanding $_[0]: $@" )
      if ($@);

    return $val                                      if ( defined $val );
    return 'undef'                                   if ( !$_[1] );
    return ''                                        if ( $_[1] == 2 );
    die "Undefined value in expanded string $_[0]\n" if ( $_[1] == 3 );
    $_[2] = 1;
    return '';
}

sub _doExpandStr {
    my $this   = shift;
    my $str    = shift;
    my %params = @_;

    local $params{__expLevel} = $params{__expLevel} + 1;

    # Reset pos
    $str =~ /^/gs;

    my $expStr = "";

    my @dataParam = $params{data} ? ( data => $params{data} ) : ();

    # Construct like ${<chr>} is being expanded into just <chr>. This is how
    # escaping is implemented. Note that this works for non-word chars only. Any
    # ${<word-chr>.*} is commonly considered a macro.
    while ($str =~ /(?<txt>.*?)\$\{(?<chr>\W)\}/gsc
        || $str =~ /(?<txt>.*?)$KeyMacroREGEX/gsc )
    {
        $expStr .= $+{txt};
        if ( defined $+{chr} ) {

            # Expand \ escaping
            $expStr .= $+{chr};
        }
        else {
            my $key = $+{key};
            my $keyVal = $this->get( $key, @dataParam );
            if ( defined $keyVal ) {
                $expStr .= $this->_expandStr( $keyVal, %params );
            }
            else {
                if ( $params{undefFail} ) {
                    $this->Throw( 'Foswiki::Exception::Fatal',
                            "Failed to expand string '"
                          . $str
                          . "': key "
                          . $key
                          . " value is undefined" );
                }
                $this->Throw( 'Foswiki::Exception::_expandStr::UndefVal', $key )
                  unless defined $params{undef};
                $expStr .= $params{undef};
            }
        }
    }

    $str =~ /\G(?<txt>.*)$/;
    $expStr .= $+{txt};

    return $expStr;
}

sub _expandStr {
    my $this   = shift;
    my $str    = shift;
    my %params = @_;
    my $expStr;

    $params{__expLevel} //= 0;

    try {
        $expStr = $this->_doExpandStr( $str, %params );
    }
    catch {
        my $e = Foswiki::Exception::Fatal->transmute( $_, 0 );
        if (  !$params{__expLevel}
            && $e->isa('Foswiki::Exception::_expandStr::UndefVal') )
        {
            $expStr = undef;
        }
        else {
            $e->rethrow;
        }
    };
    return $expStr;
}

=begin TML

---+++ ObjectMethod expandStr( %params ) -> expanded data

Expands a string possibly containing config value macro ${Key}

Returns an array of expanded strings if called in a list context. In a scalar
context either returns a scalar for a single expanded string; or an array ref if
multiple strings were expanded.

---++++!! Parameters

| *Param* | *Description* | *Default* |
| =data= | Configuration data hash. | =$app->cfg->data= |
| =str= | Data to be expanded. Could be a scalar or an array ref. | |
| =key= | Full path of a configuration key to expand or an array ref of keys. | |
| =undef= | What an undefined value must be replaced with. | _undef_ |
| =undefFail= | Throw a fatal exception if undefined value has been encountered | _false_ |

---++++!! Implementation details

When a configuration key with undefined value encountered during the expansion
process then method behaviour depends on =undefFail= and =undef= parameters.
With =undefFail= set to _true_ a fatal exception will be generated. Otherwise,
if =undef= is not specified or has undefined value then the whole expansion will
result in an undefined value. But if =undef= containts a value it will be used
as if it's the value of the undefined configuration key.

For example, for the following config:

<verbatim>
UndefKey=
AKey='Here we include ${UndefKey}...'
</verbatim>

With =undefFail= being _false_ and =undef= set to '*undef*' the resulting value will be:

<verbatim>
Here we include *undef*...
</verbatim>

=cut

sub expandStr {
    my $this   = shift;
    my %params = @_;

    my ( @strs, @estrs );

    # $isList is true if a list is requested; i.e. any of str or key are passed
    # in with an array ref.
    my $isList;

    if ( $params{str} ) {
        if ( my $rt = ref( $params{str} ) ) {
            $this->Throw( 'Foswiki::Exception::Fatal',
                "expandStr method's str parameter cannot be " . $rt . " ref" )
              unless $rt eq 'ARRAY';
            push @strs, @{ $params{str} };
            $isList = 1;
        }
        else {
            push @strs, $params{str};
        }
        delete $params{str};
    }

    if ( $params{key} ) {
        if ( my $rt = ref( $params{key} ) ) {
            $this->Throw( 'Foswiki::Exception::Fatal',
                "expandStr method's key parameter cannot be " . $rt . " ref" )
              unless $rt eq 'ARRAY';
            push @strs, $this->get($_) foreach @{ $params{key} };
            $isList = 1;
        }
        else {
            push @strs, $this->get( $params{key} );
        }
        delete $params{key};
    }

    push @estrs, $this->_expandStr( $_, %params ) foreach @strs;

    return (
        wantarray ? @estrs : ( @estrs > 1 || $isList ? [@estrs] : $estrs[0] ) );
}

=begin TML
---+++ ObjectMethod bootstrapSystemSettings()

This method tries to determine mandatory configuration defaults to operate
when no LocalSite.cfg is found.

=cut

sub bootstrapSystemSettings {
    my $this = shift;

    # Strip off any occasional configuration data which might be a result of
    # previously failed readConfig.
    $this->clear_data;

    # Restore system-default state.
    $this->_workOutOS;
    $this->_populatePresets;
    $this->_guessDefaults;

    my $env    = $this->app->env;
    my $engine = $this->app->engine;

    print STDERR "AUTOCONFIG: Bootstrap Phase 1: " . Data::Dumper::Dumper($env)
      if (TRAUTO);

    # Try to create $Foswiki::cfg in a minimal configuration,
    # using paths and URLs relative to this request. If URL
    # rewriting is happening in the web server this is likely
    # to go down in flames, but it gives us the best chance of
    # recovering. We need to guess values for all the vars that

    # would trigger "undefined" errors
    my $bin;
    my $script = '';
    if ( defined $ENV{FOSWIKI_SCRIPTS} ) {
        $bin = $ENV{FOSWIKI_SCRIPTS};
    }
    else {
        eval('require FindBin');
        $this->Throw( 'Foswiki::Exception::Fatal',
            "Could not load FindBin to support configuration recovery: $@" )
          if $@;
        FindBin::again();    # in case we are under mod_perl or similar
        $FindBin::Bin =~ m/^(.*)$/;
        $bin = $1;
        $FindBin::Script =~ m/^(.*)$/;
        $script = $1;
    }

    # Can't use Foswiki::decode_utf8 - this is too early in initialization
    # SMELL TODO The above must not be true anymore. Yet, why not use
    # Encode::decode_utf8?
    print STDERR "AUTOCONFIG: Found Bin dir: "
      . $bin
      . ", Script name: $script using FindBin\n"
      if (TRAUTO);

    $this->data->{ScriptSuffix} = ( fileparse( $script, qr/\.[^.]*/ ) )[2];
    $this->data->{ScriptSuffix} = ''
      if ( $engine->isa('Foswiki::Engine::FastCGI')
        || $engine->isa('Foswiki::Engine::PSGI') );
    print STDERR "AUTOCONFIG: Found SCRIPT SUFFIX "
      . $this->data->{ScriptSuffix} . "\n"
      if ( TRAUTO && $this->data->{ScriptSuffix} );

    my %rel_to_root = (
        DataDir    => { dir => 'data',   required => 0 },
        LocalesDir => { dir => 'locale', required => 0 },
        PubDir     => { dir => 'pub',    required => 0 },
        ToolsDir   => { dir => 'tools',  required => 0 },
        WorkingDir => {
            dir           => 'working',
            required      => 1,
            validate_file => 'README'
        },
        TemplateDir => {
            dir           => 'templates',
            required      => 1,
            validate_file => 'foswiki.tmpl'
        },
        ScriptDir => {
            dir           => 'bin',
            required      => 1,
            validate_file => 'setlib.cfg'
        }
    );

    # Note that we don't resolve x/../y to y, as this might
    # confuse soft links
    my $root = Foswiki::guessHomeDir;
    $root =~ s{\\}{/}g;
    my $fatal = '';
    my $warn  = '';
    while ( my ( $key, $def ) = each %rel_to_root ) {
        $this->data->{$key} = File::Spec->rel2abs( $def->{dir}, $root );
        $this->data->{$key} = abs_path( $this->data->{$key} );
        ( $this->data->{$key} ) = $this->data->{$key} =~ m/^(.*)$/;    # untaint

        # Need to decode utf8 back to perl characters.  The file path operations
        # all worked with bytes, but Foswiki needs characters.
        $this->data->{$key} = NFC( Encode::decode_utf8( $this->data->{$key} ) );

        print STDERR "AUTOCONFIG: $key = "
          . Encode::encode_utf8( $this->data->{$key} ) . "\n"
          if (TRAUTO);

        if ( -d $this->data->{$key} ) {
            if ( $def->{validate_file}
                && !-e $this->data->{$key} . "/$def->{validate_file}" )
            {
                $fatal .=
                    "\n{$key} (guessed "
                  . $this->data->{$key} . ") "
                  . $this->data->{$key}
                  . "/$def->{validate_file} not found";
            }
        }
        elsif ( $def->{required} ) {
            $fatal .= "\n{$key} (guessed " . $this->data->{$key} . ")";
        }
        else {
            $warn .=
              "\n      * Note: {$key} could not be guessed. Set it manually!";
        }
    }

    # Bootstrap the Site Locale and CharSet
    $this->_bootstrapSiteSettings();

    # Bootstrap the store related settings.
    $this->_bootstrapStoreSettings();

    if ($fatal) {
        my $lscFile = $this->lscFile;
        $this->Throw( 'Foswiki::Exception::Fatal', <<EPITAPH );
Unable to bootstrap configuration. $lscFile could not be loaded,
and Foswiki was unable to guess the locations of the following critical
directories: $fatal
EPITAPH
    }

# Re-read Foswiki.spec *and Config.spec*. We need the Config.spec's
# to get a true picture of our defaults (notably those from
# JQueryPlugin. Without the Config.spec, no plugins get registered)
# Don't load LocalSite.cfg if it exists (should normally not exist when bootstrapping)
    $this->readConfig( 0, 0, 1, 1 );
    print STDERR "AUTOCONFIG: Detected OS "
      . $this->data->{OS}
      . ":  DetailedOS: "
      . $this->data->{DetailedOS} . " \n"
      if (TRAUTO);

    $this->_setupGlobals;

    $this->data->{isVALID} = 1;
    $this->setBootstrap;

    # Note: message is not I18N'd because there is no point; there
    # is no localisation in a default cfg derived from Foswiki.spec
    my $system_message = <<BOOTS;
*WARNING !LocalSite.cfg could not be found* (This is normal for a new installation) %BR%
This Foswiki is running using a bootstrap configuration worked
out by detecting the layout of the installation.
BOOTS

    if ($warn) {
        chomp $system_message;
        $system_message .= $warn . "\n";
    }
    $this->bootstrapMessage( $system_message // '' );
}

=begin TML

---+++ ObjectMethod bootstrapWebSettings($script)

Called by bootstrapConfig.  This handles the web environment specific settings only:

   * ={DefaultUrlHost}=
   * ={ScriptUrlPath}=
   * ={ScriptUrlPaths}{view}=
   * ={PubUrlPath}=

=cut

sub bootstrapWebSettings {
    my $this   = shift;
    my $script = shift;

    my $app     = $this->app;
    my $env     = $app->env;
    my $engine  = $app->engine;
    my $cfgData = $this->data;

    print STDERR "AUTOCONFIG: Bootstrap Phase 2: "
      . Data::Dumper::Dumper( \%ENV )
      if (TRAUTO);

    # Cannot bootstrap the web side from CLI environments
    if ( !$engine->HTTPCompliant ) {
        $cfgData->{DefaultUrlHost} = 'http://localhost';
        $cfgData->{ScriptUrlPath}  = '/bin';
        $cfgData->{PubUrlPath}     = '/pub';
        print STDERR
          "AUTOCONFIG: Bootstrap Phase 2 bypassed! n/a in the CLI Environment\n"
          if (TRAUTO);
        return 'Phase 2 boostrap bypassed - n/a in CLI environment\n';
    }

    $cfgData->{Engine} //= ref($engine);

    my $protocol = $engine->secure ? 'https' : 'http';

    # Figure out the DefaultUrlHost
    if ( $env->{HTTP_HOST} ) {
        $cfgData->{DefaultUrlHost} = "$protocol://" . $env->{HTTP_HOST};
        print STDERR "AUTOCONFIG: Set DefaultUrlHost "
          . $cfgData->{DefaultUrlHost}
          . " from HTTP_HOST "
          . $env->{HTTP_HOST} . " \n"
          if (TRAUTO);
    }
    elsif ( $env->{SERVER_NAME} ) {
        $cfgData->{DefaultUrlHost} = "$protocol://" . $env->{SERVER_NAME};
        print STDERR "AUTOCONFIG: Set DefaultUrlHost "
          . $cfgData->{DefaultUrlHost}
          . " from SERVER_NAME "
          . $env->{SERVER_NAME} . " \n"
          if (TRAUTO);
    }
    elsif ( $env->{SCRIPT_URI} ) {
        ( $cfgData->{DefaultUrlHost} ) =
          $env->{SCRIPT_URI} =~ m#^(https?://[^/]+)/#;
        print STDERR "AUTOCONFIG: Set DefaultUrlHost "
          . $cfgData->{DefaultUrlHost}
          . " from SCRIPT_URI "
          . $env->{SCRIPT_URI} . " \n"
          if (TRAUTO);
    }
    else {

        # OK, so this is barfilicious. Think of something better.
        $cfgData->{DefaultUrlHost} = "$protocol://localhost";
        say STDERR "AUTOCONFIG: barfilicious: Set DefaultUrlHost "
          . $cfgData->{DefaultUrlHost}
          if (TRAUTO);
    }

# Examine the CGI path.   The 'view' script it typically removed from the
# URL when using "Short URLs.  If this BEGIN block is being run by
# 'view',  then $this->data->{ScriptUrlPaths}{view} will be correctly
# bootstrapped.   If run for any other script, it will be set to a
# reasonable though probably incorrect default.
#
# In order to recover the correct view path when the script is 'configure',
# the ConfigurePlugin stashes the path to the view script into a session variable.
# and then recovers it.  When the jsonrpc script is called to save the configuration
# it then has the VIEWPATH parameter available.  If "view" was never called during
# configuration, then it will not be set correctly.
    my $path_info = $engine->path_info
      || '';    #SMELL Sometimes PATH_INFO appears to be undefined.
    my $request_uri = $engine->request_uri;
    say STDERR "AUTOCONFIG: REQUEST_URI is " . ( $request_uri || '(undef)' )
      if (TRAUTO);
    say STDERR "AUTOCONFIG: SCRIPT_URI  is "
      . ( $env->{SCRIPT_URI} || '(undef)' )
      if (TRAUTO);
    say STDERR "AUTOCONFIG: PATH_INFO   is $path_info" if (TRAUTO);
    say STDERR "AUTOCONFIG: ENGINE      is " . $cfgData->{Engine}
      if (TRAUTO);

# This code tries to break the url up into <prefix><script><path> ... The script may or may not
# be present.  Short URLs will omit the script from view operations, and *may* omit the
# <prefix> for all operations.   Examples of URLs and shortening.
#
#  Full:    /foswiki/bin/view/Main/WebHome   /foswiki/bin/edit/Main/WebHome
#  Full:    /bin/view/Main/WebHome           /bin/edit/Main/WebHome            omitting prefix
#  Short:   /foswiki/Main/WebHome            /foswiki/bin/edit/Main/WebHome    omitting bin/view
#  Short:   /Main/WebHome                    /bin/edit/Main/WebHome            omitting prefix and bin/view
#  Shorter: /Main/WebHome                    /edit/Main/WebHome                omitting prefix and bin in all cases.
#
# Note that some of this can't be done as part of the view script.  The only way to know if "bin" is omitted in
# all cases is when a script other than view runs,   like jsonrpc.

    my $pfx;

    my $suffix =
      ( defined $env->{SCRIPT_URL}
          && length( $env->{SCRIPT_URL} ) < length($path_info) )
      ? $env->{SCRIPT_URL}
      : $path_info;

    # Try to Determine the prefix of the script part of the URI.
    if ( $env->{SCRIPT_URI} && $env->{SCRIPT_URL} ) {
        if ( index( $env->{SCRIPT_URI}, $cfgData->{DefaultUrlHost} ) eq 0 ) {
            $pfx =
              substr( $env->{SCRIPT_URI},
                length( $cfgData->{DefaultUrlHost} ) );
            $pfx =~ s#$suffix$##;
            print STDERR
"AUTOCONFIG: Calculated prefix $pfx from SCRIPT_URI and SCRIPT_URL\n"
              if (TRAUTO);
        }
    }

    unless ( defined $pfx ) {
        if ( my $idx = index( $request_uri, $path_info ) ) {
            $pfx = substr( $request_uri, 0, $idx + 1 );
        }
        $pfx = '' unless ( defined $pfx );
        print STDERR "AUTOCONFIG: URI Prefix is $pfx\n" if (TRAUTO);
    }

    # Work out the URL path for Short and standard URLs
    if ( $request_uri =~ m{^(.*?)/$script(\b|$)} ) {
        my $spfx = $1;
        print STDERR
          "AUTOCONFIG: SCRIPT $script fully contained in REQUEST_URI "
          . $request_uri
          . ", Not short URLs\n"
          if (TRAUTO);

        # Conventional URLs   with path and script
        $cfgData->{ScriptUrlPath} = $spfx;
        $cfgData->{ScriptUrlPaths}{view} =
          $spfx . '/view' . $cfgData->{ScriptSuffix};

        # This might not work, depending on the websrver config,
        # but it's the best we can do
        $cfgData->{PubUrlPath} = ( length($spfx) ? "$spfx/.." : "" ) . "/pub";
    }
    else {
        print STDERR "AUTOCONFIG: Building Short URL paths using prefix $pfx \n"
          if (TRAUTO);
        $cfgData->{ScriptUrlPath}        = $pfx . '/bin';
        $cfgData->{ScriptUrlPaths}{view} = $pfx;
        $cfgData->{PubUrlPath}           = $pfx . '/pub';
    }

    if (TRAUTO) {
        say STDERR "AUTOCONFIG: Using ScriptUrlPath ",
          $cfgData->{ScriptUrlPath};
        say STDERR "AUTOCONFIG: Using {ScriptUrlPaths}{view} "
          . (
            ( defined $cfgData->{ScriptUrlPaths}{view} )
            ? $cfgData->{ScriptUrlPaths}{view}
            : 'undef'
          );
        say STDERR "AUTOCONFIG: Using PubUrlPath: ", $cfgData->{PubUrlPath};
    }

    # Note: message is not I18N'd because there is no point; there
    # is no localisation in a default cfg derived from Foswiki.spec
    my $vp = '';
    $vp = '?VIEWPATH=' . $cfgData->{ScriptUrlPaths}{view}
      if ( defined $cfgData->{ScriptUrlPaths}{view} );
    my $system_message = <<BOOTS;
*WARNING !LocalSite.cfg could not be found* (This is normal for a new installation) %BR%
This Foswiki is running using a bootstrap configuration worked
out by detecting the layout of the installation.
To complete the bootstrap process you should either:
   * Restore the missing !LocalSite.cfg from a backup, *or*
   * Complete the new Foswiki installation:
      * visit [[%SCRIPTURL{configure}%$vp][configure]] and save a new configuration.
      * Register a user and add it to the %USERSWEB%.AdminGroup
%BR% *You have been logged in as a temporary administrator.*
Any requests made to this Foswiki will be treated as requests made by an administrator with full rights
Your temporary administrator rights will "stick" until you've logged out from this session.
BOOTS

    #'
    return ( $system_message || '' );
}

=begin TML

---+++ ObjectMethod _bootstrapSiteSettings()

Called by bootstrapConfig.  This handles the {Site} settings.

=cut

sub _bootstrapSiteSettings {
    my $this = shift;

#   Guess a locale first.   This isn't necessarily used, but helps guess a CharSet, which is always used.

    require locale;
    $this->data->{Site}{Locale} = setlocale(LC_CTYPE);

    print STDERR "AUTOCONFIG: Set initial {Site}{Locale} to  "
      . $this->data->{Site}{Locale} . "\n";
}

=begin TML

---+++ ObjectMethod _bootstrapStoreSettings()

Called by bootstrapConfig.  This handles the store specific settings.   This in turn
tests each Store Contib to determine if it's capable of bootstrapping.

=cut

sub _bootstrapStoreSettings {
    my $this = shift;

    # Ask each installed store to bootstrap itself.

    my @stores = Foswiki::Configure::FileUtil::findPackages(
        'Foswiki::Contrib::*StoreContrib');

    foreach my $store (@stores) {
        Foswiki::load_package($store);
        my $ok;
        eval('$ok = $store->can(\'bootstrapStore\')');
        if ($@) {
            print STDERR $@;
        }
        else {
            $store->bootstrapStore() if ($ok);
        }
    }

    # Handle the common store settings managed by Core.  Important ones
    # guessed/checked here include:
    #  - $Foswiki::cfg{Store}{SearchAlgorithm}

    # Set PurePerl search on Windows, or FastCGI systems.
    if (
        (
               $this->data->{Engine}
            && $this->data->{Engine} =~ m/(FastCGI|Apache)/
        )
        || $^O eq 'MSWin32'
      )
    {
        $this->data->{Store}{SearchAlgorithm} =
          'Foswiki::Store::SearchAlgorithms::PurePerl';
        print STDERR
"AUTOCONFIG: Detected FastCGI, mod_perl or MS Windows. {Store}{SearchAlgorithm} set to PurePerl\n"
          if (TRAUTO);
    }
    else {

        # SMELL: The fork to `grep goes into a loop in the unit tests
        # Not sure why, for now just default to pure perl bootstrapping
        # in the unit tests.
        if ( !$this->app->inUnitTestMode ) {

            # Untaint PATH so we can check for grep on the path
            my $x = $ENV{PATH} || '';
            $x =~ m/^(.*)$/;
            $ENV{PATH} = $1;
            `grep -V 2>&1`;
            if ($!) {
                print STDERR
"AUTOCONFIG: Unable to find a valid 'grep' on the path. Forcing PurePerl search\n"
                  if (TRAUTO);
                $this->data->{Store}{SearchAlgorithm} =
                  'Foswiki::Store::SearchAlgorithms::PurePerl';
            }
            else {
                $this->data->{Store}{SearchAlgorithm} =
                  'Foswiki::Store::SearchAlgorithms::Forking';
                print STDERR
                  "AUTOCONFIG: {Store}{SearchAlgorithm} set to Forking\n"
                  if (TRAUTO);
            }
            $ENV{PATH} = $x;    # re-taint
        }
        else {
            $this->data->{Store}{SearchAlgorithm} =
              'Foswiki::Store::SearchAlgorithms::PurePerl';
        }
    }

    # Detect the NFC / NDF normalization of the file system, and set
    # NFCNormalizeFilenames if needed.
    # SMELL: Really this should be done per web, both in data and pub.
    my $nfcok =
      Foswiki::Configure::FileUtil::canNfcFilenames( $Foswiki::cfg{DataDir} );
    if ( defined $nfcok && $nfcok == 1 ) {
        print STDERR "AUTOCONFIG: Data Storage allows NFC filenames\n"
          if (TRAUTO);
        $this->data->{NFCNormalizeFilenames} = 0;
    }
    elsif ( defined($nfcok) && $nfcok == 0 ) {
        print STDERR "AUTOCONFIG: Data Storage enforces NFD filenames\n"
          if (TRAUTO);
        $this->data->{NFCNormalizeFilenames} = 1
          ; #the configure's interface still shows unchecked - so, don't understand.. ;(
    }
    else {
        print STDERR "AUTOCONFIG: WARNING: Unable to detect Normalization.\n";
        $this->data->{NFCNormalizeFilenames} = 1;    #enable too - safer as none
    }
}

=begin TML

---+++ ObjectMethod setBootstrap()

This routine is called to initialize the bootstrap process.   It sets the list of
configuration parameters that will need to be set and "protected" during bootstrap.

If any keys will be set during bootstrap / initial creation of LocalSite.cfg, they
should be added here so that they are preserved when the %Foswiki::cfg hash is
wiped and re-initialized from the Foswiki spec.

=cut

sub setBootstrap {
    my $this = shift;

    # Bootstrap works out the correct values of these keys
    my @BOOTSTRAP =
      qw( {DataDir} {DefaultUrlHost} {DetailedOS} {OS} {PubUrlPath} {ToolsDir} {WorkingDir}
      {PubDir} {TemplateDir} {ScriptDir} {ScriptUrlPath} {ScriptUrlPaths}{view}
      {ScriptSuffix} {LocalesDir} {Store}{Implementation} {NFCNormalizeFilenames}
      {Store}{SearchAlgorithm} {Site}{Locale} );

    $this->data->{isBOOTSTRAPPING} = 1;
    ASSERT( $this->data->{isBOOTSTRAPPING} );
    $this->data->{AisBOOTSTRAPPING} = 1;
    push( @{ $this->data->{BOOTSTRAP} }, @BOOTSTRAP );
}

=begin TML

---+++ ObjectMethod _isBadCfgKey( $keyName ) -> $errorStr

Checks if =$keyName= is invalid. Return error message describing the problem or
undef if the key is valid.

=cut

sub _isBadCfgKey {
    my $this = shift;
    my ($keyName) = @_;

    return "Key name cannot be undef" unless defined($keyName);

    return
        "Key name must be a scalar value, not "
      . ref($keyName)
      . " reference"
      if ref($keyName);

    return "Invalid config key name"
      unless $keyName =~ /^[^\.\{\}]+$/;

    return undef;
}

=begin TML

---+++ ObjectMethod _validateBindings( $keyName )

Checks if =$keyName is valid and throws
=Foswiki::Exception::Config::InvalidKeyName= exception if it's not.

=cut

sub _validateCfgKey {
    my $this = shift;
    my ($keyName) = @_;

    my $errText = $this->_isBadCfgKey($keyName);

    if ($errText) {
        $this->Throw( 'Foswiki::Exception::Config::InvalidKeyName',
            $errText, keyName => $keyName, );
    }
}

=begin TML

---+++ ObjectMethod parseKey( @keyPath ) -> @parsedPath

This method takes any combination of scalar strings and array refs from
=@keyPath= and converts it into a plain list of keys forming a key path.

A scalar string could be a combination of either a dot or culry braces notation,
but not both. For example, valid strings are:

<verbatim>
AKey
Key.SubKey
{Key}{SubKey}
</verbatim>

but not ={Key.SubKey}=.

An array ref is considered to be a key path on its own and is been parsed
same way as the original =@keyPath=. In other words, the following structure:

<verbatim>
[
    'A.B',
    [
        '{C}{D}',
        [
            'E', F',
        ]
    ]
]
</verbatim>

will be parsed into:

<verbatim>
qw(A B C D E F)
</verbatim>

If a reference to anything but an array is encountered during the parsing
then =Foswiki::Exception::Config::InvalidKeyName= exception will be thrown.

=cut

sub parseKeys {
    my $this = shift;
    my @path = @_;
    my @keys;

    return () if @_ < 1;

    if ( @path == 1 ) {
        return () unless defined $path[0];
        if ( ref( $path[0] ) ) {
            $this->Throw(
                'Foswiki::Exception::Config::InvalidKeyName',
                "Reference passed is not an arrayref but " . ref( $path[0] ),
                keyName => $path[0],
            ) unless ref( $path[0] ) eq 'ARRAY';
            @keys = $this->parseKeys( @{ $path[0] } );
        }
        elsif ( $path[0] =~ /^(?:\{[^\{\}]+\})+$/ ) {
            @keys = $path[0] =~ /\{([^\{\}]+)\}/g;
        }
        else {
            @keys = split /\./, $path[0];
        }
    }

    if ( !@keys && @path > 1 ) {
        @keys = map { $this->parseKeys($_) } @path;
    }

    return @keys;
}

=begin TML

---+++ ObjectMethod arg2keys( @keyPath ) -> @parsedPath

Wrapper around parseKeys. It throws =Foswiki::Exception::Fatal= if parse
returned non-zero number of keys in the path. Otherwise keys in the path are
validated and =Foswiki::Exception::Config::InvalidKeyName= is thrown if
validation fails..

=cut

sub arg2keys {
    my $this = shift;

    my @keys = $this->parseKeys(@_);

    $this->Throw( 'Foswiki::Exception::Fatal',
        "No valid config keys found in the method arguments" )
      unless @keys > 0;

    $this->_validateCfgKey($_) foreach @keys;

    return @keys;
}

=begin TML

---+++ ObjectMethod normalizeKeyPath($keyPath, %params) -> $normalizedPathString

Takes a =$keyPath= in any form and returns its normalized stringified form.
Ususally it means a dotted notation but if =$params{asHash}= is _true_ then
curly braces notation is used. 

The =$keyPath= may consist of data of any format allowed to
define keys:

    1. A scalar with path string.
    1. An array refs containing:
       1. Strings containing path strings.
       1. Array refs defining paths on their own (yes, recursion).
    
For example, the following:

<verbatim>
['A.B', 'C', ['{D}{E}', ['F', 'G'], 'H', []], 'I']
</verbatim>

is actually what one is expecting to be: a path _A.B.C.D.E.F.G.H.I_ in
dot-normilized form.

=arg2keys()= method is used to have the job done.

=cut

sub normalizeKeyPath {
    my $this    = shift;
    my $keyPath = shift;
    my %params  = @_;

    my @keys = $this->arg2keys($keyPath);

    my ( $prefix, $joint, $suffix ) =
      $params{asHash} ? qw({ }{ }) : ( '', '.', '' );
    return $prefix . join( $joint, @keys ) . $suffix;
}

=begin TML

---+++ ObjectMethod getSubHash($keyPath, %params) -> (\%subHash, $keyName)

Returns subhash of config data where key defined by =$keyPath= is stored. The
key's short name (the last element of key path) is returned as second element.

For example, for the following data hash:

<verbatim>
my $data = {
    This => {
        Is => {
            A => {
                Key => "With value"
            }
        }
    }
}
</verbatim>

if =$keyPath= is _'This.Is.A'_ then sub hash will be the content of
=$data->{This}{Is}= and =$keyName= will be _'A'_. 

---++++!! Parameters

| *Name* | *Description* | *Default* |
| =data= | Data hash ref | =$app->cfg->data= |
| =autoVivify= | Automatically create non-existing subhashes. | _FALSE_ |

---++++!! Implementation details

The method returns an empty list if the key path doesn't refer to a valid
subhash. For example, for the following data structure:

<verbatim>
my $data = {
    Key1 => {
        Key2 => 'Value',
    }
}
</verbatim>

_Key1.Key2_ would be a valid path but _Key1.Key2.Key3_ is incorrect. With
=autoVivify= set to _true_ the latter keypath would still be incorrect because
=Key2= already contains a value and we're not supposed to alter it. But key path
_Key1.NewKey.Key3_ will create a new subhash for NewKey and return it to the
caller. The subhash will be empty meaning that there is no _Key3_ key in it. In
other words:

<verbatim>
exists($data->{Key1}{NewKey}) -> true
ref($data->{Key1}{NewKey}) -> HASH
exists($data->{Key1}{NewKey}{Key3}) -> false
</verbatim>

See =arg2keys()=.

=cut

sub getSubHash {
    my $this   = shift;
    my $key    = shift;
    my %params = @_;

    my @keys = $this->arg2keys($key);

    my $subHash = $params{data} || $this->data;

    while ( @keys > 1 ) {
        my $key = shift @keys;
        unless ( exists( $subHash->{$key} ) || !$params{autoVivify} ) {
            $subHash->{$key} = {};
        }
        $subHash = $subHash->{$key};
        return () unless ref($subHash) eq 'HASH';
    }

    return ( $subHash, $keys[0] );
}

=begin TML

---+++ ObjectMethod get($keyPath, %params) -> $value

Returns value assigned to configuration key defined by =$keyPath=.
The key path could be either a scalar string or an array ref.

See =arg2keys()= method about parsing the =$keyPath=; and =getSubHash()= method
about supported parameters.

Example calls referring same key:

<verbatim>
$app->cfg->get([qw(Root Branch Leaf)]);
$app->cfg->get("Root.Branch.Leaf");
$app->cfg->get("{Root}{Branch}{Leaf}");
</verbatim>

=cut

sub get {
    my $this = shift;

    my ( $subHash, $leafName ) = $this->getSubHash(@_);

    return undef unless defined $subHash;

    return $subHash->{$leafName};
}

=begin TML

---+++ ObjectMethod set($keyPath => $value, %params)

Sets a key defined by =$keyPath= to =$value=.

---++++!! Parameters

| *Name* | *Description* | *Default* |
| =data= | Configuration data hash = | =$app->cfg->data= |

---++++!! Implementation details

Method autovivifies keys in =$keyPath= by setting =getSubHash()= method
=autoVivify= parameter to _true_.

Example calls:

<verbatim>
$app->cfg->set([qw(Root Branch Leaf)], $value);
$app->cfg->set("Root.Branch.Leaf", $value);
$app->cfg->set("{Root}{Branch}{Leaf}", $value);
</verbatim>

See =getSubbHash()= and =arg2keys()=.

=cut

sub set {
    my $this = shift;
    my ( $cfgPath, $value, %params ) = @_;

    my $data = $params{data} // $this->data;

    my ( $subHash, $leafName ) =
      $this->getSubHash( $cfgPath, autoVivify => 1, data => $data, );

    $subHash->{$leafName} = $value;
}

=begin TML

---+++ ObjectMethod getAttachmentURL( $web, $topic, $attachment, %options ) -> $url

Get a URL that points at an attachment. The URL may be absolute, or
relative to the the page being rendered (if that makes sense for the
store implementation).
   * =$web= - name of the web for the URL
   * =$topic= - name of the topic
   * =$attachment= - name of the attachment, defaults to no attachment
   * %options - parameters to be attached to the URL

Supported %options are:
   * =topic_version= - version of topic to retrieve attachment from
   * =attachment_version= - version of attachment to retrieve
   * =absolute= - if the returned URL must be absolute, rather than relative

If =$web= is not given, =$topic= and =$attachment= are ignored/
If =$topic= is not given, =$attachment= is ignored.

If =topic_version= is not given, the most recent revision of the topic
should be linked. Similarly if attachment_version= is not given, the most recent
revision of the attachment will be assumed. If =topic_version= is specified
but =attachment_version= is not (or the specified =attachment_version= is not
present), then the most recent version of the attachment in that topic version
will be linked. Stores may not support =topic_version= and =attachment_version=.

The default implementation is suitable for use with stores that put
attachments in a web-visible directory, pointed at by
$Foswiki::cfg{PubUrlPath}. As such it may also be used as a
fallback for distributed topics (such as those in System) when content is not
held in the store itself (e.g. if the store doesn't recognise the web it
can call SUPER::getAttachmentURL)

As required by RFC3986, the returned URL may only contain the
allowed characters -A-Za-z0-9_.~!*\'();:@&=+$,/?%#[]

=cut

sub getAttachmentURL {
    my ( $this, $web, $topic, $attachment, %options ) = @_;

    ASSERT( !ref($web), "Old format of getAttachmentURL call" );

    my $url = $this->data->{PubUrlPath} || '';

    if ($topic) {
        ( $web, $topic ) = Foswiki::Func::normalizeWebTopicName( $web, $topic );
    }

    if ($web) {
        $url .= '/' . Foswiki::urlEncode($web);
        if ($topic) {
            if ( defined $options{topic_version} ) {

                # TODO: check that the given topic version exists
            }
            $url .= '/' . Foswiki::urlEncode($topic);
            if ($attachment) {
                if ( defined $options{attachment_version} ) {

                    # TODO: check that this attachment version actually
                    # exists on the requested topic version
                }

                # TODO: check that the attachment actually exists on the
                # topic at this revision
                $url .= '/' . Foswiki::urlEncode($attachment);
            }
        }
    }

    if ( $options{absolute} && $url !~ /^[a-z]+:/ ) {

        # See http://www.ietf.org/rfc/rfc2396.txt for the definition of
        # "absolute URI". Foswiki bastardises this definition by assuming
        # that all relative URLs lack the <authority> component as well.
        $url = $this->urlHost . $url;
    }

    return $url;
}

=begin TML

---+++ ObjectMethod getPubURL($web, $topic, $attachment, %options) -> $url

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
      (      $this->app->inContext('command_line')
          || $this->app->inContext('absolute_urls') );

    return $this->getAttachmentURL( $web, $topic, $attachment, %options );
}

=begin TML

---+++ ObjectMethod getScriptUrl( $absolute, $script, $web, $topic, ... ) -> $scriptURL

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

    my $app = $this->app;

    $absolute ||=
      ( $app->inContext('command_line') || $app->inContext('absolute_urls') );

    # SMELL: topics and webs that contain spaces?

    my $url;
    if ( defined $this->data->{ScriptUrlPaths} && $script ) {
        $url = $this->data->{ScriptUrlPaths}{$script};
    }
    unless ( defined($url) ) {
        $url = $this->data->{ScriptUrlPath};
        if ($script) {
            $url .= '/' unless $url =~ m/\/$/;
            $url .= $script;
            if (
                rindex( $url, $this->data->{ScriptSuffix} ) !=
                ( length($url) - length( $this->data->{ScriptSuffix} ) ) )
            {
                $url .= $this->data->{ScriptSuffix} if $script;
            }
        }
    }

    if ( $absolute && $url !~ /^[a-z]+:/ ) {

        # See http://www.ietf.org/rfc/rfc2396.txt for the definition of
        # "absolute URI". Foswiki bastardises this definition by assuming
        # that all relative URLs lack the <authority> component as well.
        $url = $this->urlHost . $url;
    }

    if ($topic) {
        ( $web, $topic ) = $app->request->normalizeWebTopicName( $web, $topic );

        $url .= urlEncode( '/' . $web . '/' . $topic );

    }
    elsif ($web) {
        $url .= urlEncode( '/' . $web );
    }
    $url .= make_params(@params);

    return $url;
}

=begin TML

---+++ ObjectMethod patch(%cfgChunk) or patch(\%cfgChunk)

Patches the config object data with keys in =%cfgChunk=. Keys already existing
in the config data are overriden with those from the chunk.

=cut

sub patch {
    my $this = shift;
    my %cfgChunk;
    if ( @_ == 1 ) {
        %cfgChunk = %{ $_[0] };
    }
    else {
        %cfgChunk = @_;
    }
    my $data = $this->data;
    $data->{$_} = $cfgChunk{$_} foreach keys %cfgChunk;
}

=begin TML

---+++ ObjectMethod urlHost -> $urlHost

=cut

sub urlHost {
    my $this = shift;

    #{urlHost}  is needed by loadSession..
    my $url = $this->app->request->url;
    my $cfg = $this->app->cfg;
    my $urlHost;
    if (   $url
        && !$cfg->data->{ForceDefaultUrlHost}
        && $url =~ m{^([^:]*://[^/]*).*$} )
    {
        $urlHost = $1;

        if ( $cfg->data->{RemovePortNumber} ) {
            $urlHost =~ s/\:[0-9]+$//;
        }

        # If the urlHost in the url is localhost, this is a lot less
        # useful than the default url host. This is because new CGI("")
        # assigns this host by default - it's a default setting, used
        # when there is nothing better available.
        if ( $urlHost =~ m/^(https?:\/\/)localhost$/i ) {
            my $protocol = $1;

#only replace localhost _if_ the protocol matches the one specified in the DefaultUrlHost
            if ( $cfg->data->{DefaultUrlHost} =~ m/^$protocol/i ) {
                $urlHost = $cfg->data->{DefaultUrlHost};
            }
        }
    }
    else {
        $urlHost = $cfg->data->{DefaultUrlHost};
    }
    ASSERT($urlHost) if DEBUG;
    return $urlHost;
}

# Preset values that are hard-coded and not coming from external sources.
sub _populatePresets {
    my $this = shift;

    my $cfgData = $this->data;

    $cfgData->{SwitchBoard} //= {};

    # package - perl package that contains the method for this request
    # function - name of the function in package
    # context - hash of context vars to define
    # allow - hash of HTTP methods to allow (all others are denied)
    # deny - hash of HTTP methods that are denied (all others are allowed)
    # 'deny' is not tested if 'allow' is defined

    # The switchboard can contain entries either as hashes or as arrays.
    # The array format specifies [0] package, [1] function, [2] context
    # and should be used when declaring scripts from plugins that must work
    # with Foswiki 1.0.0 and 1.0.4.

    $cfgData->{SwitchBoard}{attach} = {
        package  => 'Foswiki::UI::Attach',
        request  => 'Foswiki::Request::Attachment',
        function => 'attach',
        context  => { attach => 1 },
    };
    $cfgData->{SwitchBoard}{changes} = {
        package  => 'Foswiki::UI::Changes',
        request  => 'Foswiki::Request',
        function => 'changes',
        context  => { changes => 1 },
    };
    $cfgData->{SwitchBoard}{configure} = {
        package => 'Foswiki::UI::Configure',
        request => 'Foswiki::Request',
        method  => 'configure',
    };
    $cfgData->{SwitchBoard}{edit} = {
        request  => 'Foswiki::Request',
        package  => 'Foswiki::UI::Edit',
        function => 'edit',
        context  => { edit => 1 },
    };
    $cfgData->{SwitchBoard}{jsonrpc} = {
        package => 'Foswiki::Contrib::JsonRpcContrib',
        request => 'Foswiki::Request::JSON',
        method  => 'dispatch',
        context => { jsonrpc => 1 },
    };
    $cfgData->{SwitchBoard}{login} = {
        package  => undef,
        function => 'logon',
        request  => 'Foswiki::Request',
        context  => { ( login => 1, logon => 1 ) },
    };
    $cfgData->{SwitchBoard}{logon} = {
        package  => undef,
        function => 'logon',
        request  => 'Foswiki::Request',
        context  => { ( login => 1, logon => 1 ) },
    };
    $cfgData->{SwitchBoard}{manage} = {
        package  => 'Foswiki::UI::Manage',
        request  => 'Foswiki::Request',
        function => 'manage',
        context  => { manage => 1 },
        allow    => { POST => 1 },
    };
    $cfgData->{SwitchBoard}{oops} = {
        package  => 'Foswiki::UI::Oops',
        function => 'oops_cgi',
        request  => 'Foswiki::Request',
        context  => { oops => 1 },
    };
    $cfgData->{SwitchBoard}{preview} = {
        package  => 'Foswiki::UI::Preview',
        request  => 'Foswiki::Request',
        function => 'preview',
        context  => { preview => 1 },
    };
    $cfgData->{SwitchBoard}{previewauth} = $cfgData->{SwitchBoard}{preview};
    $cfgData->{SwitchBoard}{rdiff}       = {
        package  => 'Foswiki::UI::RDiff',
        request  => 'Foswiki::Request',
        function => 'diff',
        context  => { diff => 1 },
    };
    $cfgData->{SwitchBoard}{rdiffauth} = $cfgData->{SwitchBoard}{rdiff};
    $cfgData->{SwitchBoard}{register}  = {
        package => 'Foswiki::UI::Register',
        request => 'Foswiki::Request',
        method  => 'register_cgi',
        context => { register => 1 },

        # method verify must allow GET; protect in Foswiki::UI::Register
        #allow => { POST => 1 },
    };
    $cfgData->{SwitchBoard}{rename} = {
        package  => 'Foswiki::UI::Rename',
        request  => 'Foswiki::Request',
        function => 'rename',
        context  => { rename => 1 },

        # Rename is 2 stage; protect in Foswiki::UI::Rename
        #allow => { POST => 1 },
    };
    $cfgData->{SwitchBoard}{resetpasswd} = {
        package  => 'Foswiki::UI::Passwords',
        request  => 'Foswiki::Request',
        function => 'resetPassword',
        context  => { resetpasswd => 1 },
        allow    => { POST => 1 },
    };
    $cfgData->{SwitchBoard}{rest} = {
        package  => 'Foswiki::UI::Rest',
        request  => 'Foswiki::Request::Rest',
        function => 'rest',
        context  => { rest => 1 },
    };
    $cfgData->{SwitchBoard}{restauth} = $cfgData->{SwitchBoard}{rest};
    $cfgData->{SwitchBoard}{save}     = {
        package  => 'Foswiki::UI::Save',
        request  => 'Foswiki::Request',
        function => 'save',
        context  => { save => 1 },
        allow    => { POST => 1 },
    };
    $cfgData->{SwitchBoard}{search} = {
        package  => 'Foswiki::UI::Search',
        request  => 'Foswiki::Request',
        function => 'search',
        context  => { search => 1 },
    };
    $cfgData->{SwitchBoard}{statistics} = {
        package  => 'Foswiki::UI::Statistics',
        request  => 'Foswiki::Request',
        function => 'statistics',
        context  => { statistics => 1 },
    };
    $cfgData->{SwitchBoard}{upload} = {
        package  => 'Foswiki::UI::Upload',
        request  => 'Foswiki::Request',
        function => 'upload',
        context  => { upload => 1 },
        allow    => { POST => 1 },
    };
    $cfgData->{SwitchBoard}{viewfile} = {
        package => 'Foswiki::UI::Viewfile',
        request => 'Foswiki::Request::Attachment',
        method  => 'viewfile',
        context => { viewfile => 1 },
    };
    $cfgData->{SwitchBoard}{viewfileauth} = $cfgData->{SwitchBoard}{viewfile};
    $cfgData->{SwitchBoard}{view}         = {
        package  => 'Foswiki::UI::View',
        function => 'view',
        context  => { view => 1 },
        request  => 'Foswiki::Request',
    };
    $cfgData->{SwitchBoard}{viewauth} = $cfgData->{SwitchBoard}{view};

    # List of supported engines. Used by =Foswiki::Engine::start()= method.
    $cfgData->{EngineList} = [
        'PSGI',
        'CGI',

        #'Apache',
        #'FastCGI',
        'CLI'
        , # CLI engine probe() method always return true because this is the last resort engine.
    ];
}

# Try to guess values which are not set.
sub _guessDefaults {
    my $this = shift;

    # Guess temporary files location if not preset.
    unless ( $this->data->{TempfileDir} ) {

        # Give it a sane default.
        if ( $this->data->{OS} eq 'WINDOWS' ) {

            # Windows default tmpdir is the C: root  use something sane.
            # Configure does a better job,  it should be run.
            $this->data->{TempfileDir} = $this->data->{WorkingDir};
        }
        else {
            $this->data->{TempfileDir} = File::Spec->tmpdir();
        }
    }

    # If not set, default to strikeone validation
    $this->data->{Validation}{Method} ||= 'strikeone';
    $this->data->{Validation}{ValidForTime} = $this->data->{LeaseLength}
      unless defined $this->data->{Validation}{ValidForTime};
    $this->data->{Validation}{MaxKeys} = 1000
      unless defined $this->data->{Validation}{MaxKeys};
}

# Setup global variables/structures dependant on configuration.
sub _setupGlobals {
    my $this = shift;

    # Set up pre-compiled regexes for use in rendering.
    # In the regex hash, all precompiled REs have "Regex" at the
    # end of the name. Anything else is a string, either intended
    # for use as a character class, or as a sub-expression in
    # another compiled RE.

    # Character class components for use in regexes.
    # (Pre-UTF-8 compatibility; not used in core)
    $Foswiki::regex{upperAlpha}    = '[:upper:]';
    $Foswiki::regex{lowerAlpha}    = '[:lower:]';
    $Foswiki::regex{numeric}       = '[:digit:]';
    $Foswiki::regex{mixedAlpha}    = '[:alpha:]';
    $Foswiki::regex{mixedAlphaNum} = '[:alnum:]';
    $Foswiki::regex{lowerAlphaNum} = '[:lower:][:digit:]';
    $Foswiki::regex{upperAlphaNum} = '[:upper:][:digit:]';

    # Compile regexes for efficiency and ease of use
    # Note: qr// locks in regex modes (i.e. '-xism' here) - see Friedl
    # book at http://regex.info/.

    $Foswiki::regex{linkProtocolPattern} = $this->data->{LinkProtocolPattern}
      || '(file|ftp|gopher|https|http|irc|mailto|news|nntp|telnet)';

    # Header patterns based on '+++'. The '###' are reserved for numbered
    # headers
    # '---++ Header', '---## Header'
    $Foswiki::regex{headerPatternDa} = qr/^---+(\++|\#+)(.*)$/m;

    # '<h6>Header</h6>
    $Foswiki::regex{headerPatternHt} = qr/^<h([1-6])>(.+?)<\/h\1>/mi;

    # '---++!! Header' or '---++ Header %NOTOC% ^top'
    $Foswiki::regex{headerPatternNoTOC} = '(\!\!+|%NOTOC%)';

    # Foswiki concept regexes
    $Foswiki::regex{wikiWordRegex} = qr(
            [[:upper:]]+
            [[:lower:][:digit:]]+
            [[:upper:]]+
            [[:alnum:]]*
       )xo;
    $Foswiki::regex{webNameBaseRegex} = qr/[[:upper:]]+[[:alnum:]_]*/;
    if ( $this->data->{EnableHierarchicalWebs} ) {
        $Foswiki::regex{webNameRegex} = qr(
                $Foswiki::regex{webNameBaseRegex}
                (?:(?:[\.\/]$Foswiki::regex{webNameBaseRegex})+)*
           )xo;
    }
    else {
        $Foswiki::regex{webNameRegex} = $Foswiki::regex{webNameBaseRegex};
    }
    $Foswiki::regex{defaultWebNameRegex} = qr/_[[:alnum:]_]+/;
    $Foswiki::regex{anchorRegex}         = qr/\#[[:alnum:]:._]+/;
    my $abbrevLength = $this->data->{AcronymLength} || 3;
    $Foswiki::regex{abbrevRegex} = qr/[[:upper:]]{$abbrevLength,}s?\b/;

    $Foswiki::regex{topicNameRegex} =
qr/(?:(?:$Foswiki::regex{wikiWordRegex})|(?:$Foswiki::regex{abbrevRegex}))/;

    # Email regex, e.g. for WebNotify processing and email matching
    # during rendering.

    my $emailAtom = qr([A-Z0-9\Q!#\$%&'*+-/=?^_`{|}~\E])i;    # Per RFC 5322 ]

    # Valid TLD's at http://data.iana.org/TLD/tlds-alpha-by-domain.txt
    # Version 2012022300, Last Updated Thu Feb 23 15:07:02 2012 UTC
    my $validTLD = $this->data->{Email}{ValidTLD};

    unless ( eval { qr/$validTLD/ } ) {
        $validTLD =
qr(AERO|ARPA|ASIA|BIZ|CAT|COM|COOP|EDU|GOV|INFO|INT|JOBS|MIL|MOBI|MUSEUM|NAME|NET|ORG|PRO|TEL|TRAVEL|XXX)i;

# Too early to log, should do something here other than die (which prevents fixing)
# warn is trapped and turned into a die...
#warn( "{Email}{ValidTLD} does not compile, using default" );
    }

    $Foswiki::regex{emailAddrRegex} = qr(
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
    # $Foswiki::regex{filenameInvalidCharRegex} = qr/[^[:alnum:]\. _-]/;
    #
    # It was only used in Foswiki::Sandbox::sanitizeAttachmentName(), which now
    # uses $Foswiki::cfg{NameFilter} instead.
    # See RobustnessTests::test_sanitizeAttachmentName
    #
    # Actually, this is used in GenPDFPrincePlugin; let's copy NameFilter
    $Foswiki::regex{filenameInvalidCharRegex} =
      qr/$Foswiki::cfg{AttachmentNameFilter}/;

    $Foswiki::regex{webTopicInvalidCharRegex} = qr/$Foswiki::cfg{NameFilter}/;

    # Multi-character alpha-based regexes
    $Foswiki::regex{mixedAlphaNumRegex} = qr/[[:alnum:]]*/;

    # %TAG% name
    $Foswiki::regex{tagNameRegex} = '[A-Za-z][A-Za-z0-9_:]*';

    # Set statement in a topic
    $Foswiki::regex{bulletRegex} = '^(?:\t|   )+\*';
    $Foswiki::regex{setRegex} =
      $Foswiki::regex{bulletRegex} . '\s+(Set|Local)\s+';
    $Foswiki::regex{setVarRegex} =
        $Foswiki::regex{setRegex} . '('
      . $Foswiki::regex{tagNameRegex}
      . ')\s*=\s*(.*)$';

    # Character encoding regexes

    # Regex to match only a valid UTF-8 character, taking care to avoid
    # security holes due to overlong encodings by excluding the relevant
    # gaps in UTF-8 encoding space - see 'perldoc perlunicode', Unicode
    # Encodings section.  Tested against Markus Kuhn's UTF-8 test file
    # at http://www.cl.cam.ac.uk/~mgk25/ucs/examples/UTF-8-test.txt.
    $Foswiki::regex{validUtf8CharRegex} = qr{
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

    $Foswiki::regex{validUtf8StringRegex} =
      qr/^(?:$Foswiki::regex{validUtf8CharRegex})+$/;

    # Check for unsafe search regex mode (affects filtering in) - default
    # to safe mode
    $this->data->{ForceUnsafeRegexes} = 0
      unless defined $this->data->{ForceUnsafeRegexes};
}

=begin TML

#ObjectMethodAssignGlob
---+++ ObjectMethod assignGLOB

Sets the global =%Foswiki::cfg= hash to be an alias to the config's object
=data= attribute.

=cut

sub assignGLOB {
    my $this = shift;
    my ($data) = @_;

    $data //= $this->data;

    # Alias ::cfg for compatibility. Though $app->cfg should be preferred
    # way of accessing config.
    *Foswiki::cfg = $data;
}

=begin TML

#ObjectMethodUnassignGlob
---+++ ObjectMethod unAssignGLOB

Does the opposite to the =assignGLOB()= method: assigns global =%Foswiki::cfg=
to an empty hash.

=cut

sub unAssignGLOB {
    my $this = shift;

    my $glob = Foswiki::getNS('Foswiki');

    if ( *{ $glob->{cfg} }{HASH} eq $this->data ) {
        my %empty;
        *Foswiki::cfg = \%empty;
    }
}

# Check if $Foswiki::cfg is an alias to this object's data attribute. Useful for
# debugging only.
sub _validateBindings {
    my $this    = shift;
    my $testKey = '__TEST_VALUE__';
    $this->data->{$testKey} = 'Test is OK';
    ASSERT(
        $Foswiki::cfg{$testKey} eq $this->data->{$testKey},
"%Foswiki::cfg is not mapped to the active Foswiki::Config object data attribute"
    );
    $testKey = '__TEST_ANOTHER__';
    $Foswiki::cfg{$testKey} = "Now it different";
    ASSERT(
        $Foswiki::cfg{$testKey} eq $this->data->{$testKey},
        "Foswiki::Config data attribute is not mapped to the %Foswiki::cfg hash"
    );
}

=begin TML

---+++ ObjectMethod makeSpecsHash( %params ) -> $tiedHash

Creates a new hash tied to =$app->cfg->dataHashClass=. Normally this would be
=Foswiki::Config::DataHash=. If parameter key =data= is specified and is a hash
reference then it's content is assigned to the newly created tied hash making it
a full copy of the original data.

=cut

sub makeSpecsHash {
    my $this   = shift;
    my %params = @_;

    $this->Throw( 'Foswiki::Exception::Fatal', "'data' must be a hash ref" )
      if $params{data} && ref( $params{data} ) ne 'HASH';

    my %newData;
    my $tieObj = tie %newData, $this->dataHashClass,
      app    => $this->app,
      cfg    => $this,
      _trace => 0,
      ;

    # SMELL Test and throw an exception if tie failed.

    %newData = %{ $params{data} } if $params{data};

    return \%newData;
}

=begin TML

#ObjectMethodSpecsMode
---+++ ObjectMethod specsMode( %params ) -> \%cfgData

Converts =data= attribute from plain data hash into specs mode by tieing it
to =Foswiki::Config::DataHash=. The original data is preserved.

Returns a reference to the newly created tied hash. 

---++++!! Parameters

| *Key* | *Description* | *Default* |
| =data= | Reference to config data to be copied into the tied hash | =$app->cfg->data= |
| =setAttr= | True if =$app->cfg->data= has to be set to the new tied hash | _true_ unless =data= key is defined |

---++++!! Implementation details

The method does nothing if =setAttr= attribute is true and =$app->cfg->data= is
a tied hash already.

%X% *NOTE:* Current implementation is incomplete as before restoring the original
data specs must be re-read from the disk. Otherwise this operation may result in
inconsistent data not complying with specs requirements.

See =makeSpecsHash()=.

=cut

sub specsMode {
    my $this   = shift;
    my %params = @_;

    my $cfgData = $params{data} // $this->data;

    # A flag to indicate wether to set object data attribute to the newly
    # created tied hash. If corresponding method parameter setAttr is not set
    # then setAttr would be false if data parameter is there.
    my $setAttr = $params{setAttr} // !defined( $params{data} );

    return if $setAttr && tied %{ $this->data };

    my $newData = $this->makeSpecsHash;

    foreach my $specFile ( @{ $this->specFiles->list } ) {
        $specFile->data($newData);
        $specFile->localData(0);
        $specFile->parse;
    }

    my $ndo = tied %$newData;

    #my %spLeafs = map { $_->fullName => 1 } $ndo->getLeafNodes;
    #say STDERR "Got leafs: ", scalar( keys %spLeafs );

    # Do key assignment one-by-one to avoid clearing the $newData hash if we
    # attempt to perform %{$newData} assignment.
    $newData->{$_} = $cfgData->{$_} foreach keys %$cfgData;

    #my %dLeafs = map { $_->fullName => 1 } $ndo->getLeafNodes;
    #say STDERR "Leafs after data assign: ", scalar( keys %dLeafs );
    #foreach my $l ( keys %dLeafs ) {
    #    say STDERR "New leaf node: ", $l unless $spLeafs{$l};
    #}
    #foreach my $l ( keys %spLeafs ) {
    #    say STDERR "Lost leaf node: ", $l unless $dLeafs{$l};
    #}

    $this->data($newData) if $setAttr;

    return $newData;
}

=begin TML

---+++ ObjectMethod dataMode

Does the opposite to =specsMode()= method – assigns plain hash to the =data=
attribute. The data is preserved.

=cut

sub dataMode {
    my $this = shift;

    return unless tied %{ $this->data };

    # SMELL Use of private Foswiki::Object method _cloneData. Should there be
    # public one?
    my $newData = $this->_cloneData( $this->data, 'data' );

    $this->data($newData);
}

=begin TML

---+++ ObjectMethod getKeyObject(@path) -> $keyObject

Returns a container object of =Foswiki::Config::DataHash= class. =@path= is a
full path to the key (see =normalizeKeyPath= method).

See also =getKeyObject()= method of =Foswiki::Config::DataHash=.

=cut

sub getKeyObject {
    my $this = shift;
    my @keys = $this->parseKeys(@_);

    my $dataObj;
    return undef unless $dataObj = tied %{ $this->data };

    return $dataObj->getKeyObject(@keys);
}

=begin TML

---+++ ObjectMethod getKeyNode(@path) -> $nodeObject

Returns =Foswiki::Config::Node= object defined by =@path= (see
=normalizeKeyPath= method).

=cut

sub getKeyNode {
    my $this = shift;
    my @keys = $this->arg2keys(@_);

    return undef unless @keys;

    my $nodeKey = pop @keys;

    my $keyObj = $this->getKeyObject(@keys);

    return undef unless defined $keyObj;

    return $keyObj->nodes->{$nodeKey};
}

=begin TML

---+++ ObjectMethod spec( %params )

Translates specs structure into a valid configuration data hash tied to
=$app->cfg->dataHashClass=.

---++++!! Parameters

| *Key* | *Description* | *Default* |
| =source= | Where specs data comes from. Could be a string or a =Foswiki::File= object. | <nop> *Required* |
| =specs= | Array ref of specs. | <nop> *Required* |
| =section= | An instance of =Foswiki::Config::Section= class. | <nop> *Required* |
| =dataObj= | An instance of =Foswiki::Config::DataHash= class. The one behind the =data= attribute is used if this key is not defined. | =tied( %{ $app->cfg->data } )= |
| =localData= | Used only if =dataObj= parameter is specified. If _true_ then =dataObj= is considered local, i.e. not coming from the =$app->cfg->data= and not planned to be used for it. | _true_ if =dataObj= is not the same one behind =$app->cfg->data= hash |

---++++!! Implementation details

If =dataObj= key is defined then =spec()= method doesn't turn =specsMode= on.

The =localData= parameter is relevant only when =dataObj= is defined. It changes
the way keys with =-enhancing= option set are handled. When =localData= is
_false_ and no previously defined key with the same name is found then an
exception is thrown. When =localData= is _true_ then this situation is not
considered a error. The option is useful when it is needed to work with chunks
of specs rather then with the full set read from all sources.

Specs data format is currently described in
[[https://foswiki.org/Development/OOConfigSpecsFormat][OOConfigSpecsFormat&nbsp;proposal]].

See [[System.SpecFileFormat]],
=[[?%QUERYSTRING%#ObjectMethodSpecsMode][specsMode()]]=

=cut

sub spec {
    my $this   = shift;
    my %params = @_;

    $this->Throw( 'Foswiki::Exception::Fatal',
        "Spec source parameter is required and cannot be empty" )
      unless defined( $params{source} )
      && ( ref( $params{source} ) || length( $params{source} ) );

    $this->Throw( 'Foswiki::Exception::Fatal',
        "Spec source parameter is a ref but not a Foswiki::File instance",
    ) if ref( $params{source} ) && !$params{source}->isa('Foswiki::File');

    my ( $data, $section, $localData );

    if ( $params{dataObj} ) {
        $this->Throw( 'Foswiki::Exception::Fatal',
            "The dataObj key must be a Foswiki::Config::DataHash instance",
          )
          unless UNIVERSAL::isa( $params{dataObj},
            'Foswiki::Config::DataHash' );

        $this->Throw( 'Foswiki::Exception::Fatal',
            "The section key must be defined when data key is used",
        ) unless defined $params{section};

        $this->Throw( 'Foswiki::Exception::Fatal',
            "The section key must be a Foswiki::Config::Section instance",
          )
          unless UNIVERSAL::isa( $params{section}, 'Foswiki::Config::Section' );

        $data    = $params{dataObj};
        $section = $params{section};

        # If no localData parameter is given then try to guess it by comparing
        # passed in =dataObj= parameter with config =data= attribute.
        #
        # NOTE: This won't work if called from within specsMode() method because
        # it works on a freshly created data hash before making storing it into
        # the attribute.
        my $globData = tied %{ $this->data };
        $localData = $params{localData}
          // ( !defined($globData) || $globData != $data );
    }
    else {
        $this->specsMode;

        $data      = tied( %{ $this->data } );
        $localData = 0;
        $section   = $this->rootSection;
    }

    my $specs = $this->create(
        'Foswiki::Config::SpecDef',
        specDef   => $params{specs},
        source    => $params{source},
        section   => $section,
        dataObj   => $data,
        localData => $localData,
    );
    try {
        $this->_specSectionBody( specs => $specs, );
    }
    catch {
        my $e = Foswiki::Exception::Fatal->transmute( $_, 0 );

        if ( $e->isa('Foswiki::Exception::Config::NoNextDef') ) {
            $this->Throw(
                'Foswiki::Exception::Config::BadSpecData',
                "Incomlete spec data",
            );
        }

        $e->rethrow;
    };
}

=begin TML

---+++ ObjectMethod prepareData

Initializer of =data= attribute.

=cut

sub prepareData {
    my $this = shift;
    my $data = {};
    $this->assignGLOB($data);
    return $data;
}

=begin TML

---+++ ObjectMethod prepareDataHashClass

Initializer of =dataHashClass= attribute.

Returns _'Foswiki::Config::DataHash'_ by default. But if extensions subsystem is
initialized and there is at least one extension claiming to override the class
then it is mapped through =Foswiki::ExtManager= =mapClass()= method.

The class is preloaded with =Foswiki::load_class()=.

=cut

sub prepareDataHashClass {
    my $this = shift;

    my $hashClass = 'Foswiki::Config::DataHash';

    # Map the class only if app's extensions attribute is initialized. Otherwise
    # avoid autovivification. This code would make sense when very early config
    # loading would be implemented.
    $hashClass = $this->app->extMgr->mapClass($hashClass)
      if $this->app->has_extMgr;

    Foswiki::load_class($hashClass);

    return $hashClass;
}

=begin TML

---+++ ObjectMethod prepareRootSection

Initializer of =rootSection= attribute.

=cut

sub prepareRootSection {
    my $this = shift;

    return $this->create( 'Foswiki::Config::Section', name => 'Root' );
}

=begin TML

---+++ ObjectMethod prepareSpecFiles

Initializer of =specFiles= attribute.

=cut

sub prepareSpecFiles {
    my $this = shift;

    return $this->create( 'Foswiki::Config::Spec::Files', cfg => $this, );
}

=begin TML

---+++ ObjectMethod prepareLscFile

Initializer of =lscFile= attribute. Uses =FOSWIKI_CONFIG= environment variable
to let user-defined config be used. Otherwise _'LocalSite.cfg'_ is returned.

=cut

sub prepareLscFile {
    return $ENV{FOSWIKI_CONFIG} || 'LocalSite.cfg';
}

=begin TML

---+++ ObjectMethod prepareLscHeader

Initializer of =lscHeader= attribute.

=cut

sub prepareLscHeader {
    return <<'EOH';
#!fwconfig
# Local site settings for Foswiki. This file is managed by the 'configure'
# CGI script, though you can also make (careful!) manual changes with a
# text editor.  See the Foswiki.spec file in this directory for documentation
# Extensions are documented in the Config.spec file in the Plugins/<extension>
# or Contrib/<extension> directories  (Do not remove the following blank line.)
EOH
}

=begin TML

---+++ ObjectMethod _prepareSpecParsers

Initializer of =_specParsers= attribute.

=cut

sub _prepareSpecParsers {

    # Keep track of previously failed modules.
    return {
        map { $_ => undef }
        grep { !defined $parserModules{$_} } keys %parserModules
    };
}

=begin TML

---+++ ObjectMethod _prepareKeyOptArity

Initializer of =_keyOptArity= attribute.

=cut

sub _prepareKeyOptArity {
    my $this = shift;

    my %arity;

    my $nodeClass = $this->dataHashClass->NODE_CLASS;
    my @types     = $nodeClass->getAllTypes;

    foreach my $type (@types) {
        my $typeClass = $nodeClass->type2class($type);
        %arity = ( %arity, $typeClass->optArities );
    }

    return \%arity;
}

=begin TML

---+++ ObjectMethod _prepareSecOptArity

Initializer of =_secOptArity= attribute.

=cut

sub _prepareSecOptArity {
    my $this = shift;

    return { Foswiki::Config::Section->optArities };
}

=begin TML

---+++ ObjectMethod _prepareLscRecords

Initializer of =_lscRecords= attribute.

=cut

sub _prepareLscRecords {
    return [];
}

=begin TML

---+++ ObjectMethod _specSectionBody

Parser of body part of section definition element of specs.

=cut

sub _specSectionBody {
    my $this   = shift;
    my %params = @_;

    my $specs   = $params{specs};
    my $section = $specs->section;

    # Defines number of arguments for an option. 0 is for boolean ones, 1 is for
    # others. More than 1 argument is only possible for special cases like
    # 'section' which are handled manually. Actually, 'section' is the only such
    # option so far.
    # It also defines valid section options.
    my $secOptionArity = $this->_secOptArity;

    while ( $specs->hasNext ) {
        my $elem = $specs->fetch;

        if ( $elem =~ $Foswiki::regex{optionNameRegex} ) {
            my ( $option, @values ) =
              $this->_fetchOptVal( $+{option}, $specs, $secOptionArity, "" );

            if ( $secOptionArity->{$option} > 1 ) {
                if ( $option eq 'section' ) {
                    $this->_specSection(
                        specs   => $specs,
                        secName => $values[0],
                        secData => $values[1],
                    );
                }
                else {
                    $this->Throw(
                        'Foswiki::Exception::Config::BadSpecData',
"Don't know how to handle section's multi-param option $option",
                        section => $section,
                    );
                }
            }
            else {
                # Bool zero-arity options get values too.
                if ( $option eq 'expandable' ) {

                    # Insert dynamically-generated specs.
                    my $specData;
                    my $expandable = $values[0];
                    if ( my $refType = ref($expandable) ) {
                        if ( $refType eq 'CODE' ) {
                            $specData =
                              [ $expandable->( $this, section => $section, ) ];
                        }
                        else {
                            $this->Throw(
                                'Foswiki::Exception::Config::BadSpecData',
                                "Unallowed reference type "
                                  . $refType
                                  . " for -expandable",
                                section => $section,
                            );
                        }
                    }
                    else {
                        my $expMod = $expandable;

                        $expMod = __PACKAGE__ . "::Expandable::$expMod"
                          unless $expMod =~ /::/;

                        try {
                            Foswiki::load_package($expMod);

                            my $composeSub = $expMod->can('compose');

                            $this->Throw(
                                'Foswiki::Exception::Config::BadSpecData',
                                "Module "
                                  . $expMod
                                  . " doesn't have 'compose' method",
                                section => $section,
                            ) unless $composeSub;

                            if ( $expMod->can('new') ) {
                                my $expObj =
                                  $this->create( $expMod, cfg => $this, );
                                $specData = [ $expObj->compose ];
                            }
                            else {
                                $specData = [
                                    $composeSub->(
                                        $this, section => $section,
                                    )
                                ];
                            }
                        }
                        catch {
                            my $e =
                              Foswiki::Exception::Fatal->transmute( $_, 0 );
                            $e->_set_text( "Processing of -expandable '"
                                  . $expandable
                                  . "' failed: "
                                  . $e->text );
                            $e->rethrow;
                        };
                    }

                    $specs->inject( specDef => $specData );
                }
                else {
                    $section->setOpt( $option, $values[0] );
                }
            }

        }
        else {
            # Processing a key definition.
            $this->_specCfgKey( $elem, specs => $specs, );
        }
    }
}

=begin TML

---+++ ObjectMethod _specSection

Parser of section element of specs.

=cut

sub _specSection {
    my $this   = shift;
    my %params = @_;

    my $specs   = $params{specs};
    my $section = $specs->section;

    my ( @secProfile, @subSecElems );
    my $secName = $params{secName};

    $this->Throw(
        'Foswiki::Exception::Config::BadSpecData',
        "Section name must be a plain string, not "
          . ref($secName)
          . " reference",
        section => $section,
    ) if ref($secName);

    my $secData       = $params{secData};
    my $badValTypeTxt = $specs->badSubSpecElem($secData);
    $this->Throw(
        'Foswiki::Exception::Config::BadSpecData',
        "Cannot create section '$secName' from $badValTypeTxt",
    ) if $badValTypeTxt;

    my $secLevel = $section->level + 1;

    my $subSection = $this->rootSection->find( $secName, $secLevel );

    unless ($subSection) {
        $subSection = $section->subSection($secName);
    }

    # Set subsection modprefix to that of parent's section.
    $subSection->setOpt( modprefix => $section->getOpt('modprefix') );

    my $secSpecs = $specs->subSpecs( section => $subSection, );

    $this->_specSectionBody( specs => $secSpecs, );
}

=begin TML

---+++ ObjectMethod _isCompleteKeyDef( $specs, $section, $keyName )

Throws =Foswiki::Exception::Config::BadSpecData= exception if no next item
in =$specs=.

=cut

sub _isCompleteKeyDef {
    my $this = shift;
    my ( $specs, $section, $keyName ) = @_;

    $this->Throw(
        'Foswiki::Exception::Config::BadSpecData',
        "Incomplete key '$keyName': missing definition",
        section => $section,
    ) unless $specs->hasNext;
}

=begin TML

---+++ ObjectMethod _fetchOptVal( $option, $spec, $arity, $errorSuffix ) -> ( $option, @values )

Fetches option value or values from =$spec=. Option name is passed in =$option=
parameter. =$arity= is a mapping of option names into their arities.
=$errorSuffix= is appedned to the standard exception message to provide more
information about the nature of a problem.

The method supports boolean options in negated form (=-nooption= vs. =-option=).
For a boolean option single value is returned.

For other options retuned as many values fetched from =$spec= as defined by
its arity.

Returns a list of option name (with optional =no= prefix removed from booleans)
followed by one or few values.

=Foswiki::Exception::Config::BadSpecData= exception is thrown upon errors.

=cut

sub _fetchOptVal {
    my $this = shift;
    my ( $option, $spec, $arity, $errorSuffix ) = @_;

    my @values;

    my $isTrue = 1;
    if ( !defined $arity->{$option} && $option =~ /^no(?<option>.+)$/ ) {
        if ( defined $arity->{ $+{option} } ) {
            $option = $+{option};
            $isTrue = 0;
        }
    }

    my $argCount = $arity->{$option};

    $this->Throw(
        'Foswiki::Exception::Config::BadSpecData',
        "Don't know how to handle key option '"
          . $option . "' "
          . $errorSuffix,
        section => $spec->section,
        srcFile => $spec->source,
    ) unless defined $argCount;

    $this->Throw(
        'Foswiki::Exception::Config::BadSpecData',
        "Incomplete option '" . $option . "' " . $errorSuffix,
        section => $spec->section,
    ) unless $spec->hasNext($argCount);

    if ( $argCount > 0 ) {
        push @values, $spec->fetch($argCount);
    }
    else {
        # Boolean value, arity == 0
        push @values, $isTrue;
    }

    return ( $option, @values );
}

=begin TML

---+++ ObjectMethod _parseSpecKeyType( $keyType ) -> ( $type [, $size] )

Method parsed type string possibly with size attribute following type name.
For example: _'STRING'_ or _'STRING(40)'_.

Returns a list of one or two elements with the first one being the base type
name followed by size.

=cut

sub _parseSpecKeyType {
    my $this = shift;
    my ($keyType) = @_;

    if ( $keyType && $keyType =~ /^(?<type>.+)\((?<size>\d+(?:x\d+)?)\)$/ ) {
        return ( $+{type}, $+{size} );
    }

    return ($keyType);
}

=begin TML

---+++ ObjectMethod _specCfgKey( $key, %params )

Parses a key element data in specs.

---++++!! Parameters

| *Key* | *Description* | *Default* |
| =specs= | Array ref of specs. | <nop> *Required* |

=cut

sub _specCfgKey {
    my $this = shift;
    my ( $key, %params ) = @_;

    my $specs   = $params{specs};
    my $section = $specs->section;
    my $data    = $specs->dataObj || tied %{ $this->data };

    my $arity = $this->_keyOptArity;

    my @keyPath = $this->arg2keys( $specs->keyPath, $key );
    my $keyFullName = $this->normalizeKeyPath( \@keyPath );

    # Cut off short key name of the full path.
    my $keyName = pop @keyPath;

    $this->_isCompleteKeyDef( $specs, $section, $keyFullName );

    my $value = $specs->fetch;

    my ( @keyProfile, @keyOptions, @subKeySpecs, @keySources );

    # $isLeafKey is undef until we decide if the key we're working with is leaf
    # – i.e. defines a key storing value, not other keys.
    # The node is non-leaf if it holds a hash ref. For a newly created node
    # its value is undefined.
    my ( $isLeafKey, $isEnhancing, $keyType, $prevKeyType, $keySize, $keyText );
    my $noSourceFromSpec = 0;

    unless ( ref($value) ) {
        my @ktype = $this->_parseSpecKeyType($value);
        $keyType = $ktype[0];
        $keySize = $ktype[1] if @ktype > 1;
        $isLeafKey = 1;    # Type could be assigned to a leaf node only.
        $this->_isCompleteKeyDef( $specs, $section, $keyFullName );
        $value = $specs->fetch;
    }

    my $badValTypeTxt = $specs->badSubSpecElem($value);
    $this->Throw(
        'Foswiki::Exception::Config::BadSpecData',
        "Cannot create spec key '$keyFullName' from $badValTypeTxt",
        section => $section,
        srcFile => $specs->source,
    ) if $badValTypeTxt;

    my $keySpecs  = $specs->subSpecs;
    my $keyObject = $data->getKeyObject( $this->parseKeys(@keyPath) );
    my $keyNode   = $keyObject->nodes->{$keyName};

    if ( defined $keyNode ) {
        $isLeafKey //= $keyNode->isVague ? undef : $keyNode->isLeaf;

        # Type could only be valid for a leaf node.
        $prevKeyType = $keyNode->getOpt('type') if $isLeafKey;
    }

    while ( $keySpecs->hasNext ) {
        my $elem = $keySpecs->fetch;

        $this->Throw(
            'Foswiki::Exception::Config::BadSpecData',
"Undefined value encountered where an element is expected for key '$keyFullName'",
            section => $section,
        ) unless defined $elem;

        $this->Throw(
            'Foswiki::Exception::Config::BadSpecData',
            "Unexpected reference to "
              . ref($elem)
              . " where scalar is expected for key '$keyFullName'",
            section => $section,
        ) if ref($elem);

        if ( $elem =~ $Foswiki::regex{optionNameRegex} ) {
            my ( $option, @values ) =
              $this->_fetchOptVal( $+{option}, $keySpecs, $arity,
                "of key $keyFullName" );

            if ( $option eq 'source' ) {
                $noSourceFromSpec = 1;
            }

            if ( $option eq 'type' ) {
                my @ktype = $this->_parseSpecKeyType( $values[0] );
                unless ( defined $keyType ) {
                    $keyType = $ktype[0];
                    push @keyOptions, size => $ktype[1] if @ktype > 1;
                    push @keyOptions, $option, $keyType;
                }
                elsif ( $keyType ne $ktype[0] ) {
                    $this->Throw(
                        'Foswiki::Exception::Config::BadSpecData',
                        "Conflicting types in key definition: '"
                          . $keyType
                          . "' vs. '"
                          . $ktype[0] . "'",
                        section => $section,
                        key     => $keyFullName,
                        srcFile => $specs->source,
                    );
                }
            }
            elsif ( $arity->{$option} < 2 ) {

                # For a boolean option there will be value too. _fetchOptVal()
                # would take care of it.
                if ( $option eq 'enhance' ) {
                    $isEnhancing = 1;
                }
                elsif ( $option eq 'text' ) {

                    # If this spec is enhancing then special care of text is
                    # needed.
                    $keyText = ( $keyText // "" ) . $values[0];
                }
                else {
                    push @keyOptions, ( $option, $values[0] );
                }
            }
            else {
                # SMELL TODO Muliple options arguments are yet to be implemented
                # and the way it'll be done is yet to be thought out. So far, as
                # a proposal, a node class must support a method which would
                # convert ($option, @values) list into a data structure suitable
                # to be passed over to its constructor. Most likely variants
                # would be returning pairs ( $option => \@values ) or ( $option
                # => { @values } ).
                $this->Throw(
                    'Foswiki::Exception::Config::BadSpecData',
                    "Multiple arities are not handled yet; though option '"
                      . $option
                      . "' is declared as a "
                      . $arity->{$option}
                      . "-argument one",
                    section => $section,
                );
            }
        }
        else {
            $this->Throw(
                'Foswiki::Exception::Config::BadSpecData',
                "Subkey '"
                  . $elem
                  . "' cannot be declared in a leaf key definition",
                section => $section,
                key     => $keyFullName,
            ) if $isLeafKey;

            $isLeafKey = 0;

            my @subKeyElems = ( $elem, $keySpecs->fetch );

            unless ( ref( $subKeyElems[1] ) ) {
                push @subKeyElems, $keySpecs->fetch;
            }

            push @subKeySpecs,
              $specs->subSpecs(
                specDef => \@subKeyElems,
                keyPath => [ @keyPath, $keyName ],
              );
        }
    }

    if ($isEnhancing) {
        $this->Throw(
            'Foswiki::Exception::Config::BadSpecData',
            "Cannot enhance key, no original found",
            section => $section,
            key     => $keyFullName,
            srcFile => $specs->source,
        ) unless defined $keyNode || $specs->localData;
    }

    if ( defined $keyNode ) {
        if ( $keyNode->isLeaf && defined $keyType ) {
            $this->Throw(
                'Foswiki::Exception::Config::BadSpecData',
                "Key type '"
                  . $keyType
                  . "' is different from the previously declared '"
                  . $prevKeyType . "'",
                section => $section,
                key     => $keyFullName,
                srcFile => $specs->source,
              )
              if ( $prevKeyType ne $keyType )
              && !( $isEnhancing && $keyType eq 'VOID' );
        }
    }
    else {
        if ( defined $keyType ) {
            push @keyOptions, type => $keyType;
            push @keyOptions, size => $keySize if defined $keySize;
        }
    }

    push @keyProfile, leafState => $isLeafKey if defined $isLeafKey;
    $keyNode //= $keyObject->makeNode(
        key         => $keyName,
        nodeType    => $keyType,
        nodeProfile => [ @keyProfile, section => $keySpecs->section, ],
    );
    $keyNode->setOpt(@keyOptions);
    if ( defined $keyText ) {
        if ($isEnhancing) {
            $keyNode->addText($keyText);
        }
        else {
            $keyNode->setOpt( text => $keyText );
        }
    }
    $keyNode->addSource( $keySpecs->source ) unless $noSourceFromSpec;

    if ( $keyNode->isBranch ) {
        foreach my $subKeySpec (@subKeySpecs) {
            $this->_specCfgKey( $subKeySpec->fetch, specs => $subKeySpec );
        }
    }
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2016-2017 Foswiki Contributors. Foswiki Contributors
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
