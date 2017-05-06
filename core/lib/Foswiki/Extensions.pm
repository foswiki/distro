# See bottom of file for license and copyright information

package Foswiki::Extensions;

=begin TML

---++!! Class Foswiki::Extensions

[[https://foswiki.org/Development/OONewPluginModel][Foswiki OONewPluginModel topic]]
could serve as a temporary explanasion of why this module extists and what
functionality it is expected to provide.

=cut

use File::Spec     ();
use IO::Dir        ();
use Devel::Symdump ();
use Scalar::Util qw(blessed);

use Assert;
use Try::Tiny;
use Data::Dumper;
use Foswiki::Exception;
use Foswiki::FeatureSet qw(featuresComply);

# Constants for topological sorting.
use constant NODE_TEMP_MARK => 0;
use constant NODE_PERM_MARK => 1;
use constant NODE_DISABLED  => -1;

use Foswiki::Class qw(app callbacks);
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
  ; # List of the extension modules in the order they were registered with registerExtModule().
our %registeredModules;   # Modules registered with registerExtModule().
our %extSubClasses;       # Subclasses registered by extensions.
our %extDeps;             # Module dependecies; defines the order of extensions.
our %extTags;             # Tags registered by extensions.
our %extCallbacks;        # Callbacks registered by extensions.
our %pluggables;          # Pluggable methods
our %plugMethods;         # Extension registered plug methods.

# --- END of static data declarations

has extensions => (
    is      => 'rw',
    lazy    => 1,
    builder => 'prepareExtensions',
);

has extSubDirs => (
    is      => 'rw',
    lazy    => 1,
    builder => 'prepareExtSubDirs',
);

=begin TML

---++ ObjectAttribute extPrefix => string

Extension modules name prefix. Used by =normalizeExtName()= method and for locating extension by their =.pm= files.

Default: Foswiki::Extension.

=cut

has extPrefix => (
    is      => 'ro',
    default => 'Foswiki::Extension',
);

=begin TML

---++ ObjectAttribute dependecies => hashref

Keys: extension module names
Values: list of extensions modules required by the key's module.

=cut

has dependencies => (
    is      => 'rw',
    lazy    => 1,
    builder => 'prepareDependencies',
);

=begin TML

---++ ObjectAttribute orderedList => arrayref

List of extensions presorted to confirm with their dependencies.

=cut

has orderedList => (
    is      => 'ro',
    lazy    => 1,
    clearer => 1,
    builder => 'prepareOrderedList',
);

=begin TML

---++ ObjectAttribute registeredClasses => hashref

Map of core classes into list of overriding subclasses.

=cut

has registeredClasses => (
    is      => 'ro',
    lazy    => 1,
    clearer => 1,
    builder => 'prepareRegisteredClasses',
);

has registeredMethods => (
    is      => 'rw',
    lazy    => 1,
    clearer => 1,
    builder => 'prepareRegisteredMethods',
);

has _errors => (
    is      => 'rw',
    lazy    => 1,
    default => sub { [] },
);

# Hashref of disabled extensions. Keys are extension names, values – reason
# descriptions.
has disabledExtensions => (
    is      => 'ro',
    lazy    => 1,
    clearer => 1,
    builder => 'prepareDisabledExtensions',
);

sub BUILD {
    my $this = shift;

    $this->loadExtensions;
}

sub normalizeExtName {
    my $this = shift;
    my ($extName) = @_;
    unless ( $extName =~ /::/ ) {

        # Attempt to load en extension by its short name.
        $extName = $this->extPrefix . "::" . $extName;
    }
    return $extName;
}

sub extEnabled {
    my $this = shift;
    my ($ext) = @_;

    my $extName = $this->normalizeExtName($ext);

    return defined $this->disabledExtensions->{$extName} ? undef : $extName;
}

sub extObject {
    my $this = shift;
    my ($ext) = @_;

    my $extName = $this->normalizeExtName($ext);

    return $this->extensions->{$extName};
}

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

        # When @FS_REQUIRED is present we don't check API_VERSION as demand of
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
        registerExtModule($extModule);
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
    Foswiki::Exception::FileOp->throw(
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
                # Note that loggins isn't possible yet. But we can rely upon
                # server logging perhaps.
                Foswiki::Exception::Ext::BadName->throw(
                    extension => $dirEntry );
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
            say STDERR "Extension $extModule problem: \n",
              Foswiki::Exception::errorStr( $this->_errors->[-1] );
        };
    }
}

sub loadExtensions {
    my $this = shift;

    foreach my $extDir ( @{ $this->extSubDirs } ) {
        $this->_loadFromSubDir($extDir);
    }
}

sub initialize {
    my $this = shift;

    # Register macro tag handlers for enabled extensions.
    foreach my $tag ( keys %extTags ) {
        if ( $this->extEnabled( $extTags{$tag}{extension} ) ) {
            my $handler = $extTags{$tag}{class} // $extTags{$tag}{extension};
            $this->app->macros->registerTagHandler( $tag, $handler );
        }
    }

    # Register callback handlers for enabled extensions.
    foreach my $cbName ( keys %extCallbacks ) {
        foreach my $cbData ( @{ $extCallbacks{$cbName} } ) {
            $this->registerCallback(
                $cbName,
                \&_cbDispatch,
                {
                    extension => $cbData->{extension},
                    app       => $this->app,
                    userCode  => $cbData->{code},
                }
            );
        }
    }
}

sub _cbDispatch {
    my $cbObj  = shift;    # The object which initiated the callback.
    my %params = @_;

    my $app    = $params{data}{app};
    my $extObj = $app->extensions->extObject( $params{data}{extension} );

    return $params{data}{userCode}->( $extObj, $cbObj, $params{params} );
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
        Foswiki::Exception::Fatal->throw(
            text => "Temp. mark for node $node is impossible here" )
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

sub prepareOrderedList {
    my $this = shift;

    my @orderedExtList =
      $this->_topoSort( [ map { $this->normalizeExtName($_) } @extModules ],
        $this->dependencies );
    return \@orderedExtList;
}

sub prepareExtensions {
    my $this = shift;

    my $app        = $this->app;
    my $extensions = {};

    foreach my $ext ( @{ $this->orderedList } ) {
        $extensions->{$ext} = $app->create($ext);
    }

    return $extensions;
}

sub prepareExtSubDirs {
    my $this = shift;

    my $extLibs = $this->app->env->{FOSWIKI_EXTLIBS};
    my @extPath;

    if ( defined $extLibs ) {
        push @extPath, split /:/, $extLibs;
    }
    else {
        my $fwPath = $this->app->env->{FOSWIKI_LIBS};

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

---++ ObjectMethod disableExtension( $extName, $reason )

Marks extension =$extName= as disable because of =$reason=.

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

---++ ObjectMethod mapClass($class) => $replacement

Maps a core class name into replacement class name.

=cut

sub mapClass {
    my $this = shift;
    my ($class) = @_;

    $class = ref($class) || $class;

    my $replClass = $this->registeredClasses->{$class};
    return $replClass || $class;
}

=begin TML

---++ ObjectMethod prepareDisabledExtensions => \%disabled

Returns extensions disabled for this installation or host. %disabled hash keys
are extension names, values are text reasons for disabling the extension.

*NOTE* Extension =Foswiki::Extension::Empty= is hard coded into the list of
disabled extensions because its purpose is to be a template for developing
functional extensions.

=cut

sub prepareDisabledExtensions {
    my $this        = shift;
    my $env         = $this->app->env;
    my $envVar      = 'FOSWIKI_DISABLED_EXTENSIONS';
    my $envDisabled = $env->{$envVar} // '';
    my %disabled;
    if ( my $reftype = ref($envDisabled) ) {
        Foswiki::Exception::Fatal->throw(
                text => "Environment variable $envVar is a ref to "
              . $reftype
              . " but ARRAY or scalar string expected" )
          unless $reftype eq 'ARRAY';
    }
    else {
        $envDisabled = [ split /,/, $envDisabled ];
    }

    # Never enable extension Empty. It's purpose is to serve as a template only.
    push @$envDisabled, 'Empty';

    %disabled =
      map {
        $this->normalizeExtName($_) =>
          "Disabled by $envVar environment variable."
      } @$envDisabled;

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

# Build mapping of core classes into overriding classes based on the ordered
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

sub prepareRegisteredMethods {
    my $this = shift;

    my %normPlugs;

    # Rebuild %plugMethods using normalized extension names.
    foreach my $ext ( keys %plugMethods ) {
        my $extMod = $this->normalizeExtName($ext);
        foreach my $target ( keys %{ $plugMethods{$ext} } ) {
            foreach my $method ( keys %{ $plugMethods{$ext}{$target} } ) {
                foreach
                  my $where ( keys %{ $plugMethods{$ext}{$target}{$method} } )
                {
                    Foswiki::Exception::Fatal->throw(
                            text => "Duplicate registration of "
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

    foreach my $ext ( @{ $this->orderedList } ) {
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
                        Foswiki::Exception::Fatal->throw(
                                text => "Cannot handle flow control exception "
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

        if ($wantArray) {
            return @{ $callParams->{rc} };
        }
        elsif ( defined $wantArray ) {
            return $callParams->{rc};
        }
        return;
    }

    # When no extension registered for this method call the original directly.
    return $origCode->( $params{object}, @{ $params{args} } );
}

# Universal methods supporting static, on class, and object calls.
sub extName {
    shift if ref( $_[0] ) && $_[0]->isa('Foswiki::Extensions');
    my ($extName) = @_;

    my $name = Foswiki::fetchGlobal( "\$" . $extName . "::NAME" );

    unless ($name) {
        ( $name = $extName ) =~ s/^Foswiki::Extension:://;
    }

    return $name // '';
}

=begin TML

---++ Static methods

=cut

sub registerSubClass {
    my ( $extModule, $class, $subClass ) = @_;

    push @{ $extSubClasses{$class} },
      {
        extension => $extModule,
        subClass  => $subClass
      };
}

sub registerExtModule {
    my ($extModule) = @_;

    push @extModules, $extModule;
    $registeredModules{$extModule} = 1;
}

sub registerExtTagHandler {
    my ( $extModule, $tagName, $tagClass ) = @_;

    $extTags{$tagName} = {
        extension => $extModule,
        ( defined $tagClass ? ( class => $tagClass ) : () ),
    };
}

sub registerExtCallback {
    my ( $extModule, $cbName, $cbCode ) = @_;

    push @{ $extCallbacks{$cbName} },
      {
        extension => $extModule,
        code      => $cbCode,
      };
}

sub registerDeps {
    my $extModule = shift;

    #say STDERR "Registering dependencies for module ", $extModule, ":",
    #  join( ",", @_ );

    push @{ $extDeps{$extModule} }, @_;
}

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

    Foswiki::Class::_inject_code(
        $target, $method,
        sub {
            my $obj = shift;

            # Avoid autovivification of the extensions object.
            if ( $obj->_has__appObj && $obj->__appObj->has_extensions ) {
                return $obj->__appObj->extensions->_callPluggable(
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

sub registerPlugMethod {
    my ( $extModule, $where, $pluggableMethod, $code ) = @_;

    ASSERT(
        $where =~ /^(?:before|after|around)$/,
        "Unknown plug method type $where"
    );

    $pluggableMethod =~ /^(.+)::([^:]+)$/;
    my ( $target, $method ) = ( $1, $2 );

    $plugMethods{$extModule}{$target}{$method}{$where} = $code;
}

sub isRegistered {
    my ($extModule) = @_;

    return $registeredModules{$extModule} // 0;
}

=begin TML

---++ SEE ALSO

=Foswiki::Extension::Empty=, =Foswiki::Class=.

=cut

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2016 Foswiki Contributors. Foswiki Contributors
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
