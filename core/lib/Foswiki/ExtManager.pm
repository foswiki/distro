# See bottom of file for license and copyright information

package Foswiki::ExtManager;

=begin TML

---+!! Class Foswiki::ExtManager

   : [[https://foswiki.org/Development/OONewPluginModel][Foswiki OONewPluginModel topic]]
   could serve as a temporary explanation of why this module extists and what
   functionality it is expected to provide.
   
This class is here to provide extension management for %WIKITOOLNAME%. And by
'management' we mean every aspect of manipulation with extension loading,
version checking, extension objects, their names, chains of calls, etc.

---++ Common advises

   * It must always be remembered that your extension isn't the only one working
   in the system! Think of consequences of the actions it takes and don't forget
   sharing the playground!

---++ Initialization Stages And Logic

An extension manager instance is not meant to be used by anything but an
application object. It was designed to closely interact with an application
and its life cycle.

Basically, extension manager is passing through two startup stages: construction
and initialization.

---+++ Construction Stage

At the construction stage (which is called so because it's initiated by class
constructor) the manager only loads extensions by scanning directories listed in
=%PERLDOC{"Foswiki::ExtManager" attr="extSubDirs" text="extSubDirs"}%= attribute
and loading all _.pm_ files it finds there. The order of files (and thus the
order of extensions) in not relevant here and depends on how =CPAN:IO::Dir=
=read()= method works.

Upon loading an extension module registers (or declares – particular term
depends on a point of view) it's components or attributes like methods or
callback handlers, subclasses, order in the execution chain (before or after
another extension), etc. All this could either be done by direct reference to
extension manager's =register*()= family of static methods; or, preferably, by
using subroutines exported by =%PERLDOC{Foswiki::Class}%= module when
=extension= modifier is used as a =Foswiki::Class= parameter (see
=%PERLDOC{Foswiki::Extension::Empty}%= for code examples).

*Important!* It has to be understood that after this stage is completed
extensions are only registered with the core code. The information obtained is
later used to correctly order and initialize extensions and setup some
extension manager's internals. More than that, because Perl can only load a
module once (which is pretty understandable) over it's run cycle an extension
has only a single chance of registering itself. This fact becomes especially
significant in PSGI or any other similar environment with shared codebase where
all ever created instances of applications (and their respective extension
managers, of course) share the very same collection of loaded and registered
extension modules. And it's still possible that a newly installed extension
could be loaded after its counterparts by a different application instance and
it would still work as expected.

#InitializationStage
---+++ Initialization Stage

This is when extensions are actually created. This stage is somewhat different
from the construction stage in a way that it has to be initiated by some
external force. Most commonly this force is the application code which knows the
exact moment when it needs the extensions.

While initialization code itself is only responsible for registering callbacks
and tag handlers, it may initiate a number of other preparatory actions like
building the ordered list of extensions and creating their corresponding
instances. Those actions are performed by lazy attribute builders. Their order
is not guaranteed and depends on core code implementation.

Upon finishing this stage the extension manager sets global application context
*extensionsInitialized*. Only when this context is active it is guaranteed that
the extensions infrastructure is completely prepared and ready to serve. Until
then any code trying to use it finds itself in a grey zone with no warranties
but with a number of ways to shoot itself into foot...

#ExtOrdering
---+++ Extensions Ordering

Most of the time the order of extensions plays no role in their functionality.
But 'most' doesn't mean 'always' and it is possible for an extension, say, named
_Ext1_ to declare that it needs to be called after another one named _Ext2_.
This is done by exported subroutines =extAfter= and =extBefore= which accept
lists of extension names. Note that =extBefore= is nothing special but just
another way to write =extAfter=. I.e.:

<verbatim>
package Foswiki::Extension::Ext1;
extBefore qw<Ext2>;
</verbatim>

is equivalent to:

<verbatim>
package Foswiki::Extension::Ext2;
extAfter qw<Ext1>;
</verbatim>

But as long as _Ext1_ can't neither politely ask nor сompel _Ext2_ to declare
this order for him without using a hack, =extBefore= remains the only legal way
to accomplish the task. Still it's better to remember that internally extension
manager know nothing about _'before'_ but only operates with _'after'_.

Information about extension ordering is being collected during the construction
stage and is used upon preparing the =orderedList= attribute. To rearrange the
list of extensions topological sorting algorithm is used. If a circular
dependency is encountered in a chain of extension dependencies, the whole chain
is disabled. (See the note below)

*%X% NOTE:* Currently =extAfter= and =extBefore= are been considered 'dependencies'.
It means that if for a reason _Ext2_ is disabled then _Ext1_, which is depending
on it, will be disabled too. This behavior is temporary and is a subjuect to
change making these two subs used for merely declaring the order and nothing
else. Another sub is to be introduced to declare requirements – something with a
name =extRequire= or alike. The change would also change the described above
circular dependency resolving approach. In particular, it is expected that for
non-dependency order declarations detection of circularity will not disable
involved extensions but will only generate a warning and leave them in the order
they were at the detection moment. But the particular solution is still to be
considered and discussed.

#ApiCompatibility
---+++ API Compatibility

Upon building a list of disabled extensions the manager tests their API
compatibility. The following conditions are to be met to declare an extension
compatible:

   1 It is a subclass of =Foswiki::Extension=
   1 Its module defines either =$API_VERSION= or =@FS_REQUIRED=
   1 Features required by the module (as defined in =@FS_REQUIRED=) are provided
   either by the core or by specified namespaces (see
   =%PERLDOC{Foswiki::FeatureSet}%=)
   1 If no =@FS_REQUIRED= is found then the requested API version in
   =$API_VERSION= is tested to fall into inclusive range from
   =$Foswiki::ExtManager::MIN_VERSION= to =$Foswiki::ExtManager::VERSION=.
   
%X% *NOTE:* The =$Foswiki::ExtManager::VERSION= mentioned above is not Foswiki
version. It declares current API version which may fall behind
$Foswiki::VERSION if API did not change over few Foswiki releases. For example,
Foswiki v3.1 might easily have API versioned as v3.0.5. It is recommended to
set API version to match the release where it was changed.
   
The =@FS_REQUIRED= is a simple list of strings where each string is either a
feature name or two strings together define a namespace in a form of
=-namespace= option:

<verbatim>
package Foswiki::Extension::SampleExtension;

our @FS_REQUIRED = qw<MOO UNICODE -namespace Ext::OtherExtension FEAT1 FEAT2>;
</verbatim>

In the example above the extension requests the core to support MOO and UNICODE
features; and the extension _OtherExtension_ to support FEAT1 and FEAT2. If any
of the above is not true then compatibility check fails and the
_SampleExtension_ will be disabled. A possible cause to fail could be, for
instance, an older version of _OtherExtension_ installed in the system which
doesn't support =FEAT2= yet. Or the core has moved on and switched to a
different OO framework making the =MOO= feature gone.

Use of feature sets is highly recommended versus use of =$API_VERSION= because
of its flexibility. In some cases an abandoned extension could be very important
for a particular %WIKITOOLNAME% installation. It could still be compatible with
some newer core version even though it's declared API version falls short
matching =$Foswiki::ExtManager::MIN_VERSION=. This is a very possible situation
as some rarely used core feature could be considered useless or harmfull and
removed causing a bump to the =$MIN_VERSION= value. But the old extension never
used the feature and thus it's still compatible with the new core! Usually this
could be fixed by corresponding increase to the extension's =$API_VERSION=. But
then again, how could we know if it's not using another core functionality which
is not there anymore? And remember that depending on the importance and
particular functionality of that old extension its failure might result in
severe data corruption.

This is why feature sets provide better solution to the problem. And even more,
as this framework supports a feature deprecation cycle, further core development
may provide %WIKITOOLNAME% users with warnings on those extensions which are
relying upon soon to be removed functionality.

=cut

# TODO The following section contains coding guidelines which are to be made
# part of common development guidelines.

=begin TML

#SubClassing
---+++ Subclassing

An extension could subclass practically any core class and redefine its
functionality. To make this possible any %WIKITOOLNAME% code, including
extensions themselves, must comply to the following rules:

   * Any class must be a direct or indirect descendant of
     =%PERLDOC{Foswiki::Object}%=.
   * New class instances (objects) must be created using
     =%PERLDOC{"Foswiki::App" method="create"}%= method which is directly
     available as a ObjectMethod for classes consuming
     =Foswiki::Role::AppObject= role.
     
The second rule is redundant for extensions because they're inheriting from
=Foswiki::Extension= which already consumes the role.

Most of the core classes, with =%PERLDOC{Foswiki::App}%= in the first place, are
following these rules making it possible to subclass practically any core class.

It is important remember the advise about multiple active extensions. With
respect to subclassing the advise could be extended with an additional sentense:
remember about the order! When few extensions are requesting to subclass the
same class the inheritance order is determined from the =orderedList= attribute.

What happens next is a little bit of a magic because there is a thing to be
always kept in mind: the code could be ran under a code-sharing environment like
mod_perl or PSGI. Same code may serve different sites with different sets of
active extensions. Imagine three extensions declaring three subclasses of the
same class: =SubC1=, =SubC2=, and =SubC3=, to say. For simplicity let's imagine
that they're ordered by their respective numbers. Imagine too that the setup is
serving one site where all three extensions are active, and another site where
the active ones are the first and the third. What it means is that whatever
tricks we might invent to actually declare =SubC1= inheriting from the core
class, and =SubC2= inheriting from =SubC1=, but we simply won't have a way to
determine what =SubC3= must inherit from because for one site it's =SubC2= while
for another it's =SubC1=!

The solution for the problem is in use of roles. The extension manager takes
declared subclasses of active extensions, orders them and apply them as roles to
a new subclass of the core class. This implies that extension subclasses must
all be built using =[[CPAN:Moo::Role][Moo::Role]]=.

More implementation details are in the code of =prepareRegisteredClasses()=
method.

#PluggableMethods
---+++ Pluggable Methods

Alongside with subclassing there is a less radical method of redefining core
behavior. It is called 'pluggable methods' and it depends on the good will of a
core class which can declare itself an _extensible_ (see
=%PERLDOC{Foswiki::Class}%=). With this modifier it acquires the power of
declaring some of its methods as _pluggables_. A pluggable method is extensions'
plaything. But more details on this subject can be found in
=Foswiki::Extension::Empty= documentation.

=cut

use File::Spec     ();
use IO::Dir        ();
use Devel::Symdump ();
use Scalar::Util qw(blessed weaken reftype);

use Foswiki qw<inject_code fetchGlobal>;
use Assert;
use Try::Tiny;
use Data::Dumper;
use Foswiki::Exception;
use Foswiki::FeatureSet qw(featuresComply);

# Constants for topological sorting.
use constant NODE_TEMP_MARK => 0;
use constant NODE_PERM_MARK => 1;
use constant NODE_DISABLED  => -1;

use Foswiki::Class -app, -callbacks, -sugar;
extends qw(Foswiki::Object);

# This is the version to be matched agains extension's API version declaration.
# Extension is considered valid only if it's API version is no higher than
# $VERSION.
use version 0.77; our $VERSION = version->declare("2.99.0");

# The minimal API version this module supports. If an extension declares API
# version lower than this it gets rejected.
our $MIN_VERSION = version->declare("2.99.0");

# --- Static data registered upon extension's module load and to be parsed when
# extensions are built.
# NOTE All data stored in globals is raw and must be revalidated before used.
our @extModules
  ; # List of the extension modules in the order they were registered with _registerExtModule().
our %registeredModules;   # Modules registered with _registerExtModule().
our %extSubClasses;       # Subclasses registered by extensions.
our %extDeps;             # Module dependecies; defines the order of extensions.
our %extTags;             # Tags registered by extensions.
our %extCallbacks;        # Callbacks registered by extensions.
our %pluggables;          # Pluggable methods
our %plugMethods;         # Extension registered plug methods.
our %extDisabled
  ;    # Disabled extensions defined by keys. Values are reasons for disabling.

# Declare sugars for extensions
newSugar -extension => {
    plugBefore      => \&_handler_plugBefore,
    plugAfter       => \&_handler_plugAfter,
    plugAround      => \&_handler_plugAround,
    callbackHandler => \&_handler_callbackHandler,
    extClass        => \&_handler_extClass,
    extAfter        => \&_handler_extAfter,
    extBefore       => \&_handler_extBefore,
    tagHandler      => \&_handler_tagHandler,
};

# --- END of static data declarations

=begin TML

---++ Attributes

=cut

=begin TML

---+++ ObjectAttribute extensions => hashref

Mapping of extension names into extension objects.

Lazy, builder creates the objects.

=cut

has extensions => (
    is      => 'rw',
    lazy    => 1,
    builder => 'prepareExtensions',
);

=begin TML

---+++ ObjectAttribute extSubDirs => arrayref

List of *library* paths where to look for extensions. Those are not ultimate as
full names of directories where extensions are actually being located are formed
using =extPrefix= attribute. For example, with it's default
_"Foswiki::Extension"_ value a library path _/usr/local/www/foswiki/lib_ would
be used to make the full form _/usr/local/www/foswiki/lib/Foswiki/Extension_ –
and this is where the manager is expecting to find extensions.

Lazy, builder uses the following sources to set the attribute (next one is used
if none of the previous is set):

   1 =FOSWIKI_EXTLIBS= environment variable. Multiple paths are supported,
   separated by colon.
   1 =FOSWIKI_LIBS= environment variable.
   1 Full path to _Foswiki.pm_ from =%INC= hash is used to guess the correct
   library path.

=cut

has extSubDirs => (
    is      => 'rw',
    lazy    => 1,
    builder => 'prepareExtSubDirs',
);

=begin TML

---+++ ObjectAttribute extPrefix => string

Extension modules name prefix. Used by =normalizeExtName()= method and for
locating extension by their =.pm= files.

*Default:* _Foswiki::Extension_

*Example:* if an extension is referred by its short name _Ext1_ then internaly
it will be normalized and the full form _Foswiki::Extension::Ext1_ will be used.

*%X% NOTE:* Changing this attribute will most likely break loading of standard
extensions. Though it could be useful for testing/debugging.

=cut

has extPrefix => (
    is      => 'ro',
    default => 'Foswiki::Extension',
);

=begin TML

---+++ ObjectAttribute dependecies => hashref

For an extension name defines other extensions this one depends upon. All
names are in normalized form.

=cut

has dependencies => (
    is      => 'rw',
    lazy    => 1,
    builder => 'prepareDependencies',
);

=begin TML

---+++ ObjectAttribute orderedList => arrayref

Ordered list of extensions. The order depends on =dependencies= attribute.
See [[?%QUERYSTRING%#ExtOrdering][Extensions Ordering]].

=cut

has orderedList => (
    is      => 'ro',
    lazy    => 1,
    clearer => 1,
    builder => 'prepareOrderedList',
);

=begin TML

---+++ ObjectAttribute registeredClasses => hashref

Map of core classes into lists of overriding subclasses.

See =extClass= in =Foswiki::Class= and extensions documentation
(=Foswiki::Extension::Empty=).

=cut

has registeredClasses => (
    is      => 'ro',
    lazy    => 1,
    clearer => 1,
    builder => 'prepareRegisteredClasses',
);

=begin TML

---+++ ObjectAttribute registeredMethods => hashref

Multilevel map of target=>method=>where keys into lists of coderefs.

   $ target: a target core module, where the pluggable method defined
   $ method: the method name
   $ where: before/around/after

The coderefs in lists are from =plug[Before|Around|After]= extension
declarations and ordered after the =orderedList= attribute.
   
=cut

has registeredMethods => (
    is      => 'rw',
    lazy    => 1,
    clearer => 1,
    builder => 'prepareRegisteredMethods',
);

# Hashref of disabled extensions. Keys are extension names, values – reason
# descriptions.
has disabledExtensions => (
    is      => 'ro',
    lazy    => 1,
    clearer => 1,
    builder => 'prepareDisabledExtensions',
);

=begin TML

---+++ ObjectAttribute _errors => arrayref

List of =Foswiki::Exception::Ext::Load= instances containing information about
loading modules errors.

=cut

has _errors => (
    is      => 'rw',
    lazy    => 1,
    default => sub { [] },
);

=begin TML

---++ Methods

=cut

sub BUILD {
    my $this = shift;

    # Never enable extension Empty. It's purpose is to be an example.
    $extDisabled{ $this->normalizeExtName('Empty') } = "sample code";

    $this->loadExtensions;
}

=begin TML

---+++ ObjectMethod normalizeExtName( $extName ) => $normalName

Takes an extension name in =$extName= and makes it a full extension name by
prepending it with =extPrefix= if the name is in short form. A name considered
to be short if it doesn't contain any double-colon (::).

=cut

sub normalizeExtName {
    my $this = shift;
    my ($extName) = @_;
    unless ( $extName =~ /::/ ) {

        # Attempt to load en extension by its short name.
        $extName = $this->extPrefix . "::" . $extName;
    }
    return $extName;
}

=begin TML

---+++ ObjectMethod extEnabled( $extName ) => $enabled

If extension =$extName= is enabled then returns its normalized name. Otherwise
_undef_ is returned.

=cut

sub extEnabled {
    my $this = shift;
    my ($ext) = @_;

    my $extName = $this->normalizeExtName($ext);

    return defined $this->disabledExtensions->{$extName} ? undef : $extName;
}

=begin TML

---+++ ObjectMethod extObject( $extName ) => $extObject

Returns reference to extension's =$extName= object. Short names are allowed.

=cut

sub extObject {
    my $this = shift;
    my ($ext) = @_;

    my $extName = $this->normalizeExtName($ext);

    return $this->extensions->{$extName};
}

=begin TML

---+++ ObjectMethod isBadVersion( $extName ) => $errorMessage

Takes a extension name =$extName= and returns a error message if the extension
doesn't pass version compatibility check. Returns _undef_ if extension is
compatible with the core. See the
[[?%QUERYSTRING%#ApiCompatibility][API Compatibility]] section.

=cut

sub isBadVersion {
    my $this = shift;
    my ($extName) = @_;

    return "Extension module $extName not a subclass of Foswiki::Extension"
      unless $extName->isa('Foswiki::Extension');

    my @apiScalar = grep { /::API_VERSION$/ } Devel::Symdump->scalars($extName);
    my @featArray = grep { /::FS_REQUIRED$/ } Devel::Symdump->arrays($extName);
    my $checkAPI  = 1;

    unless ( @apiScalar || @featArray ) {
        return
          "Neither \$API_VERSION nor \@FS_REQUIRED are defined in $extName";
    }

    if (@featArray) {

        # When @FS_REQUIRED is present we don't check API_VERSION as demand for
        # features is more specific and more precise.
        my @fs_required = Foswiki::fetchGlobal( '@' . $featArray[0] );

        if (@fs_required) {

            # As we have a list of required features API check can be skipped.
            $checkAPI = 0;

            my (
                @nameSpaceParam, @fList, @nonComplyList,
                $errMsg,         $failOnEmptyList
            );
            my $comply = 1;

            # Closure with all its access to internals is better solution than a
            # separate sub.
            my $checkFList = sub {
                if (@fList) {
                    $comply = featuresComply(
                        -features => \@fList,
                        -inactive => \@nonComplyList,
                        @nameSpaceParam
                    );
                    unless ($comply) {
                        $errMsg =
                            "Inactive or missing features: "
                          . join( ", ", @nonComplyList )
                          . (
                            @nameSpaceParam
                            ? " from namespace $nameSpaceParam[1]"
                            : ""
                          );
                    }
                    @fList = ();
                }
                elsif ($failOnEmptyList) {
                    $comply = 0;
                    $errMsg =
                      "Incomplete \@FS_REQUIRED: empty list of features";
                    if (@nameSpaceParam) {
                        $errMsg .= " for -namespace $nameSpaceParam[1]";
                    }
                }

                return $comply;
            };

            while ( $comply && @fs_required ) {
                my $item = shift @fs_required;
                if ( $item =~ /^-namespace$/ ) {
                    ( $comply = $checkFList->() ) or next;
                    unless (@fs_required) {
                        $errMsg =
"Incomplete \@FS_REQUIRED: no name defined for the last -namespace";
                        $comply = 0;
                        next;
                    }
                    @nameSpaceParam = ( -namespace => shift @fs_required );
                    $failOnEmptyList = 1;
                }
                else {
                    push @fList, $item;
                }
            }

            # Check features of the last -namespace unless already failed.
            $comply &&= $checkFList->();

            return $errMsg unless $comply;
        }
    }

    if ( $checkAPI && @apiScalar ) {
        my $api_ver = Foswiki::fetchGlobal( '$' . $apiScalar[0] );

        return "Failed to fetch \$API_VERSION"
          unless defined $api_ver;

        return
            "Declared API version "
          . $api_ver
          . " is lower than supported "
          . $MIN_VERSION
          if $api_ver < $MIN_VERSION;

        return
            "Declared API version "
          . $api_ver
          . " is higher than supported "
          . $VERSION
          if $api_ver > $VERSION;
    }

    return '';
}

sub _loadExtModule {
    my $this = shift;
    my ($extModule) = @_;

    return if isRegistered($extModule);

    try {
        Foswiki::load_class($extModule);
        _registerExtModule($extModule);
    }
    catch {
        Foswiki::Exception::Ext::Load->rethrow(
            $_,
            extension => $extModule,
            reason    => Foswiki::Exception::errorStr($_),
        );
    };
}

sub _loadFromSubDir {
    my $this = shift;
    my ($subDir) = @_;

    my $extDirPath =
      File::Spec->catdir( $subDir, split( /::/, $this->extPrefix ) );
    my $extDir = IO::Dir->new($extDirPath);
    $this->Throw(
        'Foswiki::Exception::FileOp', undef,
        file => $extDirPath,
        op   => "opendir",
    ) unless defined $extDir;

    while ( my $dirEntry = $extDir->read ) {
        next if -d $dirEntry || $dirEntry !~ /\.pm$/;

        # SMELL $dirEntry is tainted but this we must take care of later.
        my $extModule;
        try {
            if ( $dirEntry =~
                /^(\w+)\.pm$/a )    # We match against ASCII symbols only.
            {
                $extModule = $this->normalizeExtName($1);
                $this->_loadExtModule($extModule);
            }
            else {
                # SMELL Bad extension file name, shall we do something about it?
                # Note that logging isn't possible yet. But we can rely upon
                # server logging perhaps.
                $this->Throw( 'Foswiki::Exception::Ext::BadName',
                    undef, extension => $dirEntry );
            }
        }
        catch {
            # We don't really fail upon extension load because this isn't fatal
            # in neither way. What bad could unloaded extension cause?
            push @{ $this->_errors },
              Foswiki::Exception::Ext::Load->transmute(
                $_, 1,
                extension => $extModule,
                reason    => Foswiki::Exception::errorStr($_),
              );

            #say STDERR "Extension $extModule problem: \n",
            #  Foswiki::Exception::errorStr( $this->_errors->[-1] );
        };
    }
}

=begin TML

---+++ ObjectMethod loadExtensions()

Loads extension modules unless they're already loaded.

For extension manager's internal use mostly.

=cut

sub loadExtensions {
    my $this = shift;

    foreach my $extDir ( @{ $this->extSubDirs } ) {
        $this->_loadFromSubDir($extDir);
    }
}

=begin TML

---+++ ObjectMethod initialize()

Initializes extensions subsystem. See
[[?%QUERYSTRING%#InitializationStage][Initialization Stage]].

=cut

sub initialize {
    my $this = shift;

    # Register callback handlers for enabled extensions.
    foreach my $cbName ( keys %extCallbacks ) {
        foreach my $cbInfo ( @{ $extCallbacks{$cbName} } ) {
            my $cbData = {
                extension => $cbInfo->{extension},
                userCode  => $cbInfo->{code},
                app       => $this->app,
            };

            # Avoid circular dependencies on the app object.
            weaken( $cbData->{app} );
            $this->registerCallback( $cbName, \&_cbDispatch, $cbData );
        }
    }

    # Register macro tag handlers for enabled extensions.
    foreach my $tag ( keys %{ $extTags{tags} } ) {
        my $tagData = $extTags{tags}{$tag};
        if ( $this->extEnabled( $tagData->{extension} ) ) {

            # Store back mapping for later clean up.
            push @{ $extTags{exts}{ $tagData->{extension} }{tags} }, $tag;
            my $handler = $tagData->{class} // $tagData->{extension};
            $this->app->macros->registerTagHandler( $tag, $handler );
        }
    }

    $this->app->enterContext('extensionsInitialized');
}

=begin TML

---+++ ObjectMethod deregisterExtension( $extName )

This method doesn't remove an extension from the system but it cleans up
references to the extension's object. For the moment it only deregisters
extension's tags in macros framework.

=cut

sub deregisterExtension {
    my $this = shift;
    my ($ext) = @_;

    my $extTags = $extTags{exts}{$ext}{tags};

    if ($extTags) {
        my $macros = $this->app->macros;
        foreach my $tag (@$extTags) {
            $macros->deregisterTag($tag);
        }
    }
}

=begin TML

---+++ ObjectMethod disableExtension( $extName, $reason )

Marks extension =$extName= as disable because of =$reason=.

*%X% NOTE:* Disabling an extension makes reason only before =extensions=
attribute is filled in with extensions objects. Any later call to this method
makes no sense even though the call won't fail. This is intentional as in the
future disabling an extension might also deregister it.

=cut

sub disableExtension {
    my $this = shift;
    my ( $extName, $reason ) = @_;

    ASSERT(
        defined $extName,
        "Undefined extension name in call to "
          . ref($this)
          . "::disableExtension method"
    );
    ASSERT(
        defined $reason,
        "Undefined reason in call to "
          . ref($this)
          . "::disableExtension method"
    );

    #$this->app->logger->warn("Disabling $extName because of: $reason");

    $this->disabledExtensions->{ $this->normalizeExtName($extName) } = $reason;
}

=begin TML

---+++ ObjectMethod mapClass( $class ) => $subClass

Maps a core class name into sub class constructed from extensions' class
declarations (=extClass=).

=cut

sub mapClass {
    my $this = shift;
    my ($class) = @_;

    $class = ref($class) || $class;

    my $replClass = $this->registeredClasses->{$class};
    return $replClass || $class;
}

sub _cbDispatch {
    my $cbObj  = shift;    # The object which initiated the callback.
    my %params = @_;

    my $app       = $params{data}{app};
    my $extension = $params{data}{extension};

    if ( $app->extMgr->extEnabled($extension) ) {
        my $extObj = $app->extMgr->extObject($extension);
        return $params{data}{userCode}->( $extObj, $cbObj, $params{params} )
          if $extObj;
    }
}

sub _extVisit {
    my $this   = shift;
    my %params = @_;

    my $marked    = $params{marked};
    my $depHash   = $params{depHash};
    my $extName   = $params{extName};
    my $visitPath = $params{_visitPath} // [];

    my @list;

    if (
        defined $marked->{$extName}
        && (   $marked->{$extName} == NODE_TEMP_MARK
            || $marked->{$extName} == NODE_DISABLED )
      )
    {
        state $nType = {
            &NODE_TEMP_MARK => "Circular dependecy found for",
            &NODE_DISABLED  => "Disabled extension",
        };

        my $disableMsg =
            $nType->{ $marked->{$extName} } . " "
          . $extName
          . " in dependecy chain: "
          . join( " -> ", @$visitPath, $extName );

        # Disable all problematic extensions.
        foreach my $disabledExt (@$visitPath) {
            $marked->{$disabledExt} = NODE_DISABLED;
            $this->disableExtension( $disabledExt, $disableMsg );
        }

        # Don't override the original disable message!
        if ( $marked->{$extName} == NODE_TEMP_MARK ) {
            $this->disableExtension( $extName, $disableMsg );
            $marked->{$extName} = NODE_DISABLED;
        }

        return ();
    }

    unless ( $marked->{$extName} ) {
        $marked->{$extName} = NODE_TEMP_MARK;
        my @subList;
        foreach my $depExt ( @{ $depHash->{$extName} } ) {
            @subList = $this->_extVisit(
                marked     => $marked,
                depHash    => $depHash,
                extName    => $depExt,
                _visitPath => [ @$visitPath, $extName ],
                _level     => ( $params{_level} // 0 ) + 1,
            );
            push @list, @subList;
        }
        unless ( $marked->{$extName} == NODE_DISABLED ) {
            $marked->{$extName} = NODE_PERM_MARK;
            push @list, $extName;
        }
    }

    return @list;
}

sub _topoSort {
    my $this = shift;
    my ( $order, $depHash ) = @_;

    # Marked nodes:
    # undef – not visited yet.
    # defined – NODE_* constants.
    my %marked;

    my @list;
    foreach my $node (@$order) {

        # Support manually disabled extensions.
        $marked{$node} = NODE_DISABLED unless $this->extEnabled($node);

        # At this stage there must be no temporary marks.
        $this->Throw( 'Foswiki::Exception::Fatal',
            "Temp. mark for node $node is impossible here" )
          if defined $marked{$node} && $marked{$node} == NODE_TEMP_MARK;
        next if $marked{$node};
        push @list,
          $this->_extVisit(
            marked  => \%marked,
            depHash => $depHash,
            extName => $node
          );
    }
    return @list;
}

=begin TML

---+++ ObjectMethod prepareOrderedList()

Initializer for =orderedList= attribute.

=cut

sub prepareOrderedList {
    my $this = shift;

    my @orderedExtList =
      $this->_topoSort( [ map { $this->normalizeExtName($_) } @extModules ],
        $this->dependencies );
    return \@orderedExtList;
}

=begin TML

---+++ ObjectMethod prepareExtensions()

Initializer for =extensions= attribute.

=cut

sub prepareExtensions {
    my $this = shift;

    my $app        = $this->app;
    my $extensions = {};

    foreach my $ext ( @{ $this->orderedList } ) {
        $extensions->{$ext} = $app->create($ext);
    }

    return $extensions;
}

=begin TML

---+++ ObjectMethod prepareExtSubDirs()

Initializer for =extSubDirs= attribute.

=cut

sub prepareExtSubDirs {
    my $this = shift;

    my $extLibs = $ENV{FOSWIKI_EXTLIBS};
    my @extPath;

    if ( defined $extLibs ) {
        push @extPath, split /:/, $extLibs;
    }
    else {
        my $fwPath = $ENV{FOSWIKI_LIBS};

        # If the env is not set guess by Foswiki.pm module.
        $fwPath //= ( File::Spec->splitpath( $INC{'Foswiki.pm'} ) )[1];

        push @extPath, $fwPath;
    }

    # Add extra extension subdirs to @INC but make sure not to duplicate with
    # existins entries.
    my %incDirs = map { File::Spec->rel2abs($_) => 1 } @INC;
    foreach my $pth (@extPath) {
        push @INC, $pth unless $incDirs{ File::Spec->rel2abs($pth) };
    }

    return \@extPath;
}

=begin TML

---+++ ObjectMethod prepareDisabledExtensions => \%disabled

Returns extensions disabled for this installation or host. %disabled hash keys
are extension names, values are text reasons for disabling the extension.

*%X% NOTE:* Extension =Foswiki::Extension::Empty= is hard coded into the list of
disabled extensions because its purpose is to be a template for developing
functional extensions.

=cut

sub _disabled2List {
    my $this = shift;
    my ( $disabled, $msg ) = @_;

    my @list;
    if ( my $reftype = reftype($disabled) ) {
        $this->Throw( 'Foswiki::Exception::Fatal',
                $msg
              . " is a ref to "
              . $reftype
              . " but ARRAY or scalar string expected" )
          unless $reftype eq 'ARRAY';
        @list = @$disabled;
    }
    else {
        @list = split /,/, $disabled;
    }
    return map { [ $_, $msg ] } @list;
}

sub prepareDisabledExtensions {
    my $this    = shift;
    my $envVar  = 'FOSWIKI_DISABLED_EXTENSIONS';
    my $confKey = "DisabledExtensions";

    # @disabled would contain a list of pairs of extension name and a message to
    # be appended to "Disable reason: " prefix.
    my @disabled = $this->_disabled2List( $ENV{$envVar} // '',
        "listed in environment variable $envVar" );
    my %disabled;

    push @disabled,
      $this->_disabled2List(
        $this->app->cfg->get($confKey) // '',
        "listed in configuration key $confKey"
      );

    push @disabled, map { [ $_, $extDisabled{$_} ] } keys %extDisabled;

    #say STDERR $_->[0], ": ", $_->[1] foreach @disabled;

    %disabled =
      map {
        $this->normalizeExtName( $_->[0] ) => "Disable reason: "
          . lcfirst( $_->[1] ) . "."
      } @disabled;

    foreach my $ext (@extModules) {
        my $extMod = $this->normalizeExtName($ext);
        my $reason;

        unless ( $disabled{$extMod} ) {

            # Disable API-incompatible modules
            $reason = $this->isBadVersion($extMod);

            if ($reason) {
                $disabled{$extMod} = $reason;
            }
        }
    }

    return \%disabled;
}

=begin TML

---+++ ObjectMethod prepareDependencies()

Initializer for =dependencies= attribute.

=cut

sub prepareDependencies {
    my $this = shift;

    my %nDeps;    # Normalized dependecy hash.
    foreach my $ext ( keys %extDeps ) {
        my $extName = $this->normalizeExtName($ext);

        my @deps = map { $this->normalizeExtName($_) } @{ $extDeps{$ext} };
        push @{ $nDeps{$extName} }, @deps;
    }

    return \%nDeps;
}

=begin TML

---+++ ObjectMethod prepareRegisteredClasses()

Initializer for =registeredClasses= attribute.

See [[?%QUERYSTRING%?#SubClassing][Subclassing]].

=cut

# Build mapping of core classes into sub-classes based on the ordered
# extension list.
sub prepareRegisteredClasses {
    my $this = shift;
    my %classMap;

    my %ext2class;
    foreach my $coreClass ( keys %extSubClasses ) {
        foreach my $registration ( @{ $extSubClasses{$coreClass} } ) {
            my $extName = $this->extEnabled( $registration->{extension} );

            next unless $extName;

            if ( defined $ext2class{$extName}{$coreClass} ) {

                # That's not something we'd tolerate.
                $this->disableExtension( $extName,
"$extName attepted double-registration for core class $coreClass"
                );
                next;
            }

            $ext2class{$extName}{$coreClass} = $registration->{subClass};
        }
    }

    # Build inheritance order. Use reverse to conform with the way overriden
    # methods are getting called.
    my %inheritance;
    foreach my $extName ( reverse @{ $this->orderedList } ) {
        foreach my $coreClass ( keys %{ $ext2class{$extName} } ) {
            push @{ $inheritance{$coreClass} },
              $ext2class{$extName}{$coreClass};
        }
    }

    # Build actual replacement classes.
    foreach my $coreClass ( keys %inheritance ) {
        $classMap{$coreClass} =
          Moo::Role->create_class_with_roles( $coreClass,
            @{ $inheritance{$coreClass} } );
    }

    return \%classMap;
}

=begin TML

---+++ ObjectMethod prepareRegisteredMethods()

Initializer for =registeredMethods= attribute.

=cut

sub prepareRegisteredMethods {
    my $this = shift;

    my %normPlugs;

    # Rebuild %plugMethods using normalized extension names.
    # $where is after/before/around
    foreach my $ext ( keys %plugMethods ) {
        my $extMod = $this->normalizeExtName($ext);
        foreach my $target ( keys %{ $plugMethods{$ext} } ) {
            foreach my $method ( keys %{ $plugMethods{$ext}{$target} } ) {
                foreach
                  my $where ( keys %{ $plugMethods{$ext}{$target}{$method} } )
                {
                    $this->Throw( 'Foswiki::Exception::Fatal',
                            "Duplicate registration of "
                          . $where
                          . " method "
                          . $target . "::"
                          . $method . " in "
                          . $extMod )
                      if defined $normPlugs{$extMod}{$target}{$method}{$where};
                    $normPlugs{$extMod}{$target}{$method}{$where} =
                      $plugMethods{$ext}{$target}{$method}{$where};
                }
            }
        }
    }

    my %methodMap;

  SCANEXT:
    foreach my $ext ( @{ $this->orderedList } ) {
        next unless $this->extEnabled($ext);
        foreach my $target ( keys %{ $normPlugs{$ext} } ) {
            foreach my $method ( keys %{ $normPlugs{$ext}{$target} } ) {
                foreach
                  my $where ( keys %{ $normPlugs{$ext}{$target}{$method} } )
                {
                    #say STDERR "Recording registered ", $where,
                    #  " plug method ", $method, " on ", $target,
                    #  " for extension ", $ext;
                    push @{ $methodMap{$target}{$method}{$where} },
                      {
                        extension => $ext,
                        code      => $normPlugs{$ext}{$target}{$method}{$where},
                      };
                }
            }
        }
    }

    return \%methodMap;
}

sub _execMethodList {
    my $this = shift;
    my ( $mList, $callParams ) = @_;

    # Remember the original argument list pointer to avoid plugin modification.
    # SMELL Shouldn't it be a list of protected keys?
    my $origArgs = $callParams->{args};
    my $app      = $this->app;

    # SMELL Use of the logger may cause issues if logger declares a pluggable
    # method or methods.
    my $logger = $app->logger if $app->has_logger;
    my $extensions = $this->extensions;

    my $restart;
    do {
        $restart = 0;
        my $lastIteration = 0;
        my ( $mIdx, $mEntry );
        values @$mList;  # Explicitly reset previous iterations over this array.
        while ( !$lastIteration && ( ( $mIdx, $mEntry ) = each @$mList ) ) {
            try {
                $mEntry->{code}
                  ->( $extensions->{ $mEntry->{extension} }, $callParams );
                if ( $callParams->{args} != $origArgs ) {

                    # Warnings will be suppressed at early stages of application
                    # life until the configuration object is built and ready.
                    $logger->warn(
                        "Extension ",
                        $mEntry->{extension},
" attempted to replace argument list in parameters hash."
                    ) if $logger;
                    $callParams->{args} = $origArgs;
                }
            }
            catch {
                my $e = Foswiki::Exception::Fatal->transmute( $_, 0 );

                if ( $e->isa('Foswiki::Exception::Ext::Flow') ) {
                    if ( $e->isa('Foswiki::Exception::Ext::Last') ) {
                        $callParams->{rc} = $e->rc if $e->has_rc;
                        $callParams->{execAborted} =
                          { extension => $mEntry->{extension}, };
                        $lastIteration = 1;
                    }
                    elsif ( $e->isa('Foswiki::Exception::Ext::Restart') ) {
                        $callParams->{execRestarted} =
                          { extension => $mEntry->{extension}, };
                        $lastIteration = $restart = 1;
                    }
                    else {
                        $this->Throw( 'Foswiki::Exception::Fatal',
                                "Cannot handle flow control exception "
                              . ref($e)
                              . " thrown by "
                              . $mEntry->{extension} );
                    }
                }
                else {
                    $callParams->{execFailed} = {
                        extension => $mEntry->{extension},
                        exception => $e,
                    };
                    $e->rethrow;
                }
            };

            # NOTE If any code would be needed at this point it must remember
            # about $lastIteration.
        }
    } while ($restart);
}

sub _callPluggable {
    my $this = shift;
    my ( $target, $method, %params ) = @_;

    my $origCode = $pluggables{$target}{$method};

    ASSERT( defined $origCode,
        "Pluggable method $method for $target is not defined" );

    my $wantArray = wantarray;

    my $callParams = {
        wantarray => $wantArray,
        class     => $target,
        method    => $method,
        args      => $params{args},
        object    => $params{object},
    };

    my $registeredMethods = $this->registeredMethods;

    if ( defined $registeredMethods->{$target}{$method} ) {
        my $m = $registeredMethods->{$target}{$method};
        foreach my $stage (qw(before around after)) {
            $callParams->{stage} = $stage;
            $this->_execMethodList( $m->{$stage}, $callParams );

            if ( $stage eq 'before' ) {

                # Remove errorneous rc set by an extension on `before' stage.
                delete $callParams->{rc} if exists $callParams->{rc};
            }
            elsif ( $stage eq 'around' ) {
                unless ( exists $callParams->{rc} ) {
                    if ($wantArray) {
                        $callParams->{rc} =
                          [ $origCode->( $params{object}, @{ $params{args} } )
                          ];
                    }
                    elsif ( defined $wantArray ) {
                        $callParams->{rc} =
                          $origCode->( $params{object}, @{ $params{args} } );
                    }
                    else {
                       # As no return value is expected we don't set the rc key.
                        $origCode->( $params{object}, @{ $params{args} } );
                    }
                }
            }
        }

        if ( $wantArray && ref( $callParams->{rc} ) ) {
            my $refType = reftype( $callParams->{rc} );
            if ( $refType eq 'ARRAY' ) {
                return @{ $callParams->{rc} };
            }
            elsif ( $refType eq 'HASH' ) {
                return %{ $callParams->{rc} };
            }
            return $callParams->{rc};
        }
        elsif ( defined $wantArray ) {
            return $callParams->{rc};
        }
        return;
    }

    # When no extension registered for this method call the original directly.
    return $origCode->( $params{object}, @{ $params{args} } );
}

=begin TML

---++ Static Methods

=cut

=begin TML

---+++ StaticMethod isRegistered( $extModule ) => $registered

Returns _true_ if =$extModule= is already registered with the core.

=cut

sub isRegistered {
    my ($extModule) = @_;

    return $registeredModules{$extModule} // 0;
}

=begin TML

---+++ StaticMethod extName( $extFullName )

Returns extension's name. The name is either the part of extension's module
name without prefix or a value from =$NAME= global if it's defined in the
module.

The method though declared as static could also me called on both
=Foswiki::ExtManager= class or its subclasses; and on extension manager object.
In the latter case =extPrefix= attribute is used to strip it off of the
beginning of extension's name string.

=cut

# Universal methods supporting static, on class, and object calls.
sub extName {
    my $this = shift if UNIVERSAL::isa( $_[0], 'Foswiki::ExtManager' );
    my ($extName) = @_;

    my $name = Foswiki::fetchGlobal( "\$" . $extName . "::NAME" );

    my $extPrefix = 'Foswiki::Extension';

    if ( ref($this) ) {
        $extPrefix = $this->extPrefix;
    }

    unless ($name) {
        ( $name = $extName ) =~ s/^$exrPrefix:://;
    }

    return $name // '';
}

=begin TML

---++ Registration methods

Registration methods though publicly available but are not recommended for
end-user code and mostly intended to support corresponding shortcuts in
=Foswiki::Class=.

=cut

=begin TML

---+++ StaticMethod registerSubClass( $extModule, $class, $subClass )

Registers a sub-class =$subClass= for =$class= by extension =$extModule=.

For example, a hypothetical extension =Foswiki::Extension::CloudConfig= wants
to override =Foswiki::Config= functionality. For this purpose it provides a
sub-class =Foswiki::Extension::CloudConfig::Config=. To make the core use
this class the method has to be called like this:

<verbatim>
registerSubClass(
        'Foswiki::Extenstion::CloudConfig',
        'Foswiki::Config',
        'Foswiki::Extension::CloudConfig::Config'
);
</verbatim>

Shortcut: =extClass=

See [[?%QUERYSTRING%#SubClassing][Subclassing]].

=cut

sub registerSubClass {
    my ( $extModule, $class, $subClass ) = @_;

    push @{ $extSubClasses{$class} },
      {
        extension => $extModule,
        subClass  => $subClass
      };
}

=begin TML

---+++ StaticMethod _registerExtModule( $module )

Creates a record about a recently loaded extension module.

For internal use.

=cut

sub _registerExtModule {
    my ($extModule) = @_;

    push @extModules, $extModule;
    $registeredModules{$extModule} = 1;
}

=begin TML

---+++ StaticMethod registerExtTagHandler( $extModule, $tagName [, $tagClass] )

Registers a tag named =$tagName= for extension =$extModule=. If =$tagClass= is
passed in then it's interpreted as a macro class (the one which consumes
=Foswiki::Macro= role; see =registerTagHandler()= method in =Foswiki::Macros=).

If =$tagClass= is not used then the extension must have a method named after
=$tagName=.

Shortcut: =tagHandler=

=cut

sub registerExtTagHandler {
    my ( $extModule, $tagName, $tagClass ) = @_;

    # SMELL Shall we check for duplicate registrations here? Perhaps we shall.
    $extTags{tags}{$tagName} = {
        extension => $extModule,
        ( defined $tagClass ? ( class => $tagClass ) : () ),
    };
}

=begin TML

---+++ StaticMethod registerExtCallback( $extModule, $cbName, $cbCode )

Registers extension's code =$cbCode= as a handler for callback =$cbName=.

Shortcut: =callbackHandler=

=cut

sub registerExtCallback {
    my ( $extModule, $cbName, $cbCode ) = @_;

    push @{ $extCallbacks{$cbName} },
      {
        extension => $extModule,
        code      => $cbCode,
      };
}

=begin TML

---+++ StaticMethod registerDeps( $extModule, @deps )

With this method we register what extensions must go before =$extModule=.

Shortcuts: =extAfter=, =extBefore=

=cut

# TODO Rename deps (dependencies) into something order-related as extBefore
# and extAfter shall only declare wishful order. For real dependecies more
# strict extRequire must be introduced.
sub registerDeps {
    my $extModule = shift;

    push @{ $extDeps{$extModule} }, @_;
}

=begin TML

---+++ StaticMethod registerPluggable( $class, $method, $code )

Registers =$code= as pluggable method =$method= for =$class=.

Shortcut: =pluggable=

See [[?%QUERYSTRING%#PluggableMethods][Pluggable Methods]].

=cut

sub registerPluggable {
    my ( $target, $method, $code ) = @_;

    ASSERT( ref($code) eq 'CODE' ) if DEBUG;

    Foswiki::Exception::Fatal->throw(
            text => "Attempt to register duplicate pluggable method "
          . $method
          . " for class "
          . $target )
      if defined $pluggables{$target}{$method};

    #say STDERR "Registering pluggable method $method for $target";

    $pluggables{$target}{$method} = $code;

    inject_code(
        $target, $method,
        sub {
            my $obj = shift;

            # Avoid auto-vivification of the extensions object.
            if ( $obj->has_app && $obj->app->has_extMgr ) {
                return $obj->app->extMgr->_callPluggable(
                    $target,
                    $method,
                    args   => \@_,
                    object => $obj,
                );
            }

            return $code->( $obj, @_ );
        }
    );
}

=begin TML

---+++ StaticMethod registerPlugMethod( $extModule, $where, $pluggableMethod, $code )

Registers a handler defined by coderef in =$code= for a pluggable method
=$pluggableMethod=. =$where= defines the execution stage: _before_, _after_,
or _around_.

Shortcuts: =plugBefore=, =plugAfter=, =plugAround=

=cut

sub registerPlugMethod {
    my ( $extModule, $where, $pluggableMethod, $code ) = @_;

    ASSERT(
        $where =~ /^(?:before|after|around)$/,
        "Unknown plug method type $where"
    );

    # No point of processing other plugs if the extension is already disabled.
    return if $extDisabled{$extModule};

    $pluggableMethod =~ /^(.+)::([^:]+)$/;
    my ( $target, $method ) = ( $1, $2 );

    if ( $method =~ /^_/ ) {

        # TODO Generate a warning for private methods.
    }

    my $modLoaded = 0;
    my $disableReason;
    try {
        Foswiki::load_class($target);
        $modLoaded = 1;
    }
    catch {
        my $e = Foswiki::Exception::Fatal->transmute( $_, 0 );
        if ( $e->isa("Foswiki::Exception::ModLoad") ) {
            $disableReason =
              "cannot register a plug for $pluggableMethod: " . $e->stringify;
        }
        else {
            $e->rethrow;
        }
    };

    if ($modLoaded) {
        if ( $target->isa("Foswiki::Object") ) {
            unless ( defined $pluggables{$target}{$method} ) {
                my $methodCode;

                try {
                    $methodCode = fetchGlobal("&${pluggableMethod}");
                }
                catch {
                    my $e = Foswiki::Exception::Fatal->transmute( $_, 0 );
                    $disableReason =
                        "Register a plug for "
                      . $pluggableMethod
                      . " failed: "
                      . $e->stringify;
                };

                unless ($disableReason) {

                    # Convert non-pluggable method into pluggable.
                    registerPluggable( $target, $method, $methodCode );
                }
            }
            $plugMethods{$extModule}{$target}{$method}{$where} = $code
              unless $disableReason;
        }
        else {
            $disableReason =
              "attempt to register plug for a non-Foswiki::Object class";
        }
    }

    $extDisabled{$extModule} = $disableReason if $disableReason;
}

=begin TML

---++ RELATED

%PERLDOC{Foswiki::Extension::Empty}% : a source of information on practical
details of extension development

%PERLDOC{Foswiki::Class}%

=cut

# --- Sugar handlers
sub _handler_plugBefore ($&) {
    my $target = caller;
    my ( $plug, $code ) = @_;
    registerPlugMethod( $target, 'before', $plug, $code );
}

sub _handler_plugAround ($&) {
    my $target = caller;
    my ( $plug, $code ) = @_;
    registerPlugMethod( $target, 'around', $plug, $code );
}

sub _handler_plugAfter ($&) {
    my $target = caller;
    my ( $plug, $code ) = @_;
    registerPlugMethod( $target, 'after', $plug, $code );
}

sub _handler_extClass ($$) {
    my ( $class, $subClass ) = @_;
    my $target = caller;

    registerSubClass( $target, $class, $subClass );
}

sub _handler_extAfter (@) {
    my $target = caller;

    registerDeps( $target, @_ );
}

sub _handler_extBefore (@) {
    my $target = caller;

    registerDeps( $_, $target ) foreach @_;
}

sub _handler_tagHandler ($;$) {
    my $target = caller;

    # Handler could be a class name doing Foswiki::Macro role or a sub to be
    # installed as target's hadnling method.
    my ( $tagName, $tagHandler ) = @_;

    if ( ref($tagHandler) eq 'CODE' ) {

        # If second argument is a code ref then we install method with the same
        # name as macro name.
        Foswiki::inject_code( $target, $tagName, $tagHandler );
        registerExtTagHandler( $target, $tagName );
    }
    else {
        registerExtTagHandler( $target, $tagName, $tagHandler );
    }
}

sub _handler_callbackHandler ($&) {
    my $target = caller;

    registerExtCallback( $target, @_ );
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
