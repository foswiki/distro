# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Configure::UI

This is both the factory for UIs and the base class of all UI objects.
A UI is the V part of the MVC model used in configure.

Each structural entity in a configure screen has a UI type, either
stored directly in the entity or indirectly in the type associated
with a value. The UI type is used to guide a visitor which is run
over the structure to generate the UI.

=cut

package Foswiki::Configure::UI;

use strict;
use warnings;
use File::Spec ();
use Cwd qw( abs_path );
use FindBin ();
use Digest::MD5 qw(md5_hex);
use File::Spec qw(splitpath catpath splitdir catdir);
use Foswiki::Configure::Load ();

our $totwarnings;
our $toterrors;
our $firsttime;

# These values are used in templates to control what is displayed
our $MESSAGE_TYPE = {
    NONE                      => ( 1 << 0 ),    # 1
    OK                        => ( 1 << 1 ),    # 2
    PASSWORD_CHANGED          => ( 1 << 2 ),    # 4
    PASSWORD_NOT_SET          => ( 1 << 3 ),    # 8
    PASSWORD_INCORRECT        => ( 1 << 4 ),    # 16
    PASSWORD_CONFIRM_NO_MATCH => ( 1 << 5 ),    # 32
    PASSWORD_EMPTY            => ( 1 << 6 ),    # 64

    SAVE_CHANGES => ( 1 << 10 ),

};
my $DEFAULT_TEMPLATE_PARSER = 'SimpleFreeMarker';
my $templateParser;

sub untaint {
    $_[0] =~ m/^(.*)$/;
    return $1;
}

=begin TML

---++ ClassMethod new($item)
Construct a new UI, attaching it to the given $item in the model.

=cut

sub new {
    my ( $class, $item ) = @_;

    Carp::confess unless $item;

    my $this = bless( { item => $item }, $class );

    $FindBin::Bin =~ /(.*)/;
    $this->{bin} = $1;

    # See EXTEND.pm for why we shouldn't use {bin} to find root.
    # In early initialization, we don't yet have LSC, so we will look there.
    # Probably the only way to have everything work is to insist on symlinks
    # from a root directory.

    my $dataDir = $Foswiki::cfg{DataDir};
    my $binDir  = $this->{bin};
    my @roots;
    foreach my $root ( $dataDir, $binDir ) {
        next unless ($root);
        my @root = File::Spec->splitdir($root);
        pop(@root);

        # SMELL: Force a trailing separator - Linux and Windows are inconsistent

        $root = File::Spec->catfile( @root, 'x' );
        chop $root;
        push @roots, $root;
    }

    # Record inconsistency for checker, debugging and further thought.
    # FindBin, seems to abs_path Bin, so let that through (reluctantly)

    if (   @roots >= 2
        && $roots[0] ne $roots[1] )
    {
        my $dd = abs_path( $roots[0] ) || 'undef';
        my $bd = abs_path( $roots[1] ) || 'undef';
        if ( $dd ne $bd ) {
            $this->{rootWarning} =
              "{DataDir} => $roots[0] ($dd) vs. {ScriptDir} => $roots[1] ($bd)";
        }
    }

    $this->{root} = $roots[0];

    $this->{filecount} =
      0;    # Used by recursive checkTreePerms to count files and limit

    return $this;
}

=begin TML

---++ StaticMethod reset($isFirstTime)

Called from the main =configure= script, this method resets the total
error and warning counts. This method is provided primarily for testing
support.

=cut

sub reset {
    my $ift = shift;
    $totwarnings = $toterrors = 0;
    $firsttime = $ift;
}

=begin TML

---++ ObjectMethod findRepositories()
Build descriptive hashes for the repositories listed in
$Foswiki::cfg{ExtensionsRepositories}

=cut

sub findRepositories {
    my $this = shift;
    unless ( defined( $this->{repositories} ) ) {
        my $replist = '';
        $replist .= $Foswiki::cfg{ExtensionsRepositories}
          if defined $Foswiki::cfg{ExtensionsRepositories};
        $replist = ";$replist;";
        while (
            $replist =~ s/[;\s]+(.*?)=\((.*?),(.*?)(?:,(.*?),(.*?))?\)\s*;/;/ )
        {
            push(
                @{ $this->{repositories} },
                { name => $1, data => $2, pub => $3, user => $4, pass => $5 }
            );
        }
    }
}

=begin TML

---++ ObjectMethod getRepository($name) -> \%repository
Gets the hash that describes a named repository

=cut

sub getRepository {
    my ( $this, $reponame ) = @_;
    foreach my $place ( @{ $this->{repositories} } ) {
        return $place if $place->{name} eq $reponame;
    }
    return;
}

=begin TML

---++ StaticMethod loadUI($id, $item) -> $ui

Loads the Foswiki::Configure::UIs subclass for the
given $id.  For example, given the id 'BEANS', it
will try and load Foswiki::Configure::UIs::BEANS

$item is passed on to the constructor for the UI.

=cut

sub loadUI {
    my ( $id, $item ) = @_;
    my $class = 'Foswiki::Configure::UIs::' . $id;

    eval "require $class";
    die $@ if $@;

    return $class->new($item);
}

=begin TML

---++ StaticMethod loadChecker($id, $item) -> $checker

Loads the Foswiki::Configure::Checker subclass for the
given $id. For example, given the id '{Beans}{Mung}', it
will try and load Foswiki::Configure::Checkers::Beans::Mung

Also called by 'clever' code with 'CheckerName'.

If the id doesn't have a subclass defined, the item's type class may
define a generic checker for that type.  If so, it is instantiated
for this item.

Finally, we will see if $item's type, or one it inherits from
has a generic checker.  If so, that's instantiated.

Returns the checker that's created or undef if no such checker is found.

Will die if the checker exists but fails to compile.

$item is passed on to the checker's constructor.

=cut

sub loadChecker {
    my ( $keys, $item ) = @_;
    my $id = $keys;

    # Convert {key}{s} to key::s, removing illegal characters
    # [-_\w] are legal. - => _.
    $id =~ s/\{([^}]*)\}/my $lbl = $1;
                          $lbl =~ tr,-_a-zA-Z0-9\x00-\xff,__a-zA-Z0-9,d;
                          $lbl . '::'/ge
      and substr( $id, -2 ) = '';
    my $checkClass = 'Foswiki::Configure::Checkers::' . $id;
    eval "use $checkClass ()";

    # Can't locate errors are OK, compile failures are not.
    if ($@) {
        die $@ unless ( $@ =~ /Can't locate / );

        # See if type wants to generate a generic checker
        return unless ( $item->can('getType') );

        my $type = $item->getType();
        return unless ($type);
        if ( $type->can('makeChecker') ) {
            return $type->makeChecker( $item, $keys );
        }

        # Finally, see if a generic checker exists for this type
        $checkClass = _findTypeChecker( ref($type) );
        return unless ($checkClass);
    }

    return $checkClass->new($item);
}

# Private routine _findTypeChecker
#
# Locates a default/generic checker for a Type
# Maps Foswiki::Configure::Types::<type> =>
#      Foswiki::Configure::Checkers::<type>
# If a direct mapping is not found, walks the Type's @ISA to
# determine if a default checker can be inherited.
#
# Caches search results (including failure) so that the search
# is only done once/Type.
#
# Returns the name of checker class; that class has been required.

my %typeCheckerClass;

sub _findTypeChecker {
    my $tclass = shift;

    return $typeCheckerClass{$tclass}
      if ( exists $typeCheckerClass{$tclass} );

    my $cclass = _loadTypeChecker($tclass);
    return $cclass if ($cclass);

    # Look for a generic checker in this type's ISA in
    # case we can inherit one.
    my @isa = eval "\@${tclass}::ISA";
    return undef unless (@isa);

    foreach my $iclass (@isa) {
        $cclass = _loadTypeChecker($iclass);
        return $cclass if ($cclass);
    }

    # Nothing in this class's immediate ISA
    # See if any ancestor inherits a checker.
    foreach my $iclass (@isa) {
        my @aisa = eval "\@${iclass}::ISA";
        next unless (@aisa);

        foreach my $aclass (@aisa) {
            my $cclass = _findTypeChecker($aclass);
            return $cclass if ($cclass);
        }
    }

    $typeCheckerClass{$tclass} = undef;
    return undef;
}

# Attempt to load a checker based on a Type's class
# Return checker class name with checker loaded if successful
# Return undef if checker not found
# die if found but compile errors
#
# Update cache if we have a definite result.

sub _loadTypeChecker {
    my $tclass = shift;

    my $cclass = $tclass;
    unless ( $cclass =~
        s/^Foswiki::Configure::Types::/Foswiki::Configure::Checkers::/ )
    {

        # Stop if not in Types (Usually stops at Type; Checker.pm
        # is not a useful generic checker.

        $typeCheckerClass{$tclass} = undef;
        return undef;
    }

    eval "use $cclass ()";
    unless ($@) {
        $typeCheckerClass{$tclass} = $cclass;
        return $cclass;
    }
    die $@ unless ( $@ =~ /Can't locate / );

    return undef;
}

=begin TML

---++ ObjectMethod getUrl() -> $response

Returns a response object as described in Foswiki::Net

=cut

sub getUrl {
    my ( $this, $url ) = @_;

    unless ( defined $Foswiki::VERSION ) {
        ( my $fwi, $Foswiki::VERSION ) = Foswiki::Configure::UI::extractModuleVersion( 'Foswiki', 1 );
        die "No Foswiki.pm\n" unless ($fwi);
    }
    require Foswiki::Net;
    my $tn       = new Foswiki::Net();
    my $response = $tn->getExternalResource($url);
    $tn->finish();
    return $response;
}

=begin TML

---++ ObjectMethod setting(...) -> $html
Generate the HTML for a key-value row in a table.

=cut

sub setting {
    my $this = shift;
    my $key  = shift;

    my $data = join( ' ', @_ ) || ' ';

    return CGI::Tr( {}, CGI::th( {}, $key ) . CGI::td( {}, $data ) );
}

=begin TML

---++ ObjectMethod makeID($id) -> $encodedID

Encode a string to make a simplified unique ID useable
as an HTML id or anchor

=cut

sub makeID {
    my ( $this, $str ) = @_;

    $str =~ s/\s(\w)/uc($1)/ge;
    $str =~ s/\W//g;
    return $str;
}

=begin TML

---++ ObjectMethod NOTE(...)

Generate HTML for an informational note.

=cut

sub NOTE {
    my $this = shift;
    return CGI::div( { class => 'configureInfo' },
        CGI::span( {}, join( "\n", @_ ) ) );
}

=begin TML

---++ ObjectMethod NOTE_OK(...)

Generate HTML for a note, but with the class configureOK

=cut

sub NOTE_OK {
    my $this = shift;
    return CGI::div( { class => 'configureOk' },
        CGI::span( {}, join( "\n", @_ ) ) );
}

=begin TML

---++ ObjectMethod WARN(...)

Generate HTML for a warning, and flag it in the model.

=cut

sub WARN {
    my $this = shift;
    $this->{item}->inc('warnings');
    $totwarnings++;
    return CGI::div( { class => 'foswikiAlert configureWarn' },
        CGI::span( {}, CGI::strong( {}, 'Warning: ' ) . join( "\n", @_ ) ) );
}

=begin TML

---++ ObjectMethod ERROR(...)

Generate HTML for an error, and flag it in the model.

=cut

sub ERROR {
    my $this = shift;
    $this->{item}->inc('errors');
    $toterrors++;
    return CGI::div( { class => 'foswikiAlert configureError' },
        CGI::span( {}, CGI::strong( {}, 'Error: ' ) . join( "\n", @_ ) ) );
}

=begin TML

---++ ObjectMethod FB_FOR(...)

Generate feedback for a named key (other than $this).
Only usable in =provideFeedback= methods.
 Usage: return $this->NOTE("My feedback")
               .$this->FB_FOR('{anotherkey}',
                              $this->WARN("That feedback" ));
All FB_FOR clauses must follow any messages for $this.
Feedback completly replaces the message area under an item,
so multiple updates of a target will retain only the last encountered.

=cut

sub FB_FOR {
    my $this = shift;
    my $keys = shift;

    my $target = eval "exists \$Foswiki::cfg$keys";
    die "Invalid FB_FOR target $keys\n" if ( $@ || !$target );

    return "\001$keys\002" . join( "\n", @_ );
}

=begin TML

---++ ObjectMethod FB_GUI(...)

Like FB_FOR, but intended for items in the {ConfigureGUI} namespace.
Does not require that the %Foswiki::cfg key exists, and does not count
as an unsaved change.

=cut

sub FB_GUI {
    my $this = shift;
    my $id   = shift;

    return "\001$id\002" . join( "\n", @_ );
}

=begin TML

---++ ObjectMethod FB_VALUE(...)

Like FB_FOR, but delivers a new value to the specified item.

For select-multiple items, the OPTION corresponding to each value is selected;
the first value becomes the selectedIndex.  Requires that select values are unique.

For select, radio and checkboxes, only the first value is used.

For text fields (text, textarea,hidden, password), multiple values are concatenated to
form the replacement value.

=cut

sub FB_VALUE {
    my $this = shift;
    my $keys = shift;

    my $target = eval "exists \$Foswiki::cfg$keys";
    die "Invalid FB_VALUE target $keys\n" if ($@);

    return "\001$keys\003" . join( "\004", @_ );
}

=begin TML

---++ ObjectMethod FB_GUIVAL(...)

Like FB_VALUE, but for GUI items.  Key needn't exist.

=cut

sub FB_GUIVAL {
    my $this = shift;
    my $keys = shift;

    return "\001$keys\003" . join( "\004", @_ );
}

=begin TML

---++ ObjectMethod FB_MODAL(...)

Returns HTML for a modal window, such as a form.

$options = comma-separated list of options - executed in order.
         default = r
         r = replace window contents (stepping on previous feedback; multiple checker
                           coordination is up to the checkers)
         a = append to window contents
         p = prepend to window contents
         o = open (activate) window
         s = substitute \004...) in data with contents of dom with id ...

The remaining arguments should form html at the <div> level or below.
N.B. Any other FB_ data targeting items in this html must follow the
FB_MODAL data.  This is no {ModalOptions} item (or if there is, this
does not interfere.  It simply satisfies the protocol requirement that
all messages start with something that look like a key.

=cut

sub FB_MODAL {
    my $this = shift;
    my $options = shift || 'r';

    return "\001{ModalOptions}$options\005" . join( "", @_ );
}

=begin TML

---++ ObjectMethod FB_ACTION(...)

Encodes actions to be performed by javascript.

$target = #id or name
$actions =
         t = scroll to top
         b = scroll to bottom

=cut

sub FB_ACTION {
    my $this    = shift;
    my $target  = shift;
    my $actions = shift;

    return "\001{$target}$actions\006" . join( '', @_ );
}

=begin TML

---++ ObjectMethod hidden($value) -> $html
Used in place of CGI::hidden, which is broken in some CGI versions.
HTML encodes the value

=cut

sub hidden {
    my ( $name, $value, $disabled ) = @_;
    $disabled = $disabled ? ' disabled="disabled"' : '';
    $name ||= '';
    $name =~ s/([[\x01-\x09\x0b\x0c\x0e-\x1f"%&'*<=>@[_\|])/
      '&#'.ord($1).';'/ge;
    $value ||= '';
    $value =~ s/([[\x01-\x09\x0b\x0c\x0e-\x1f"%&'*<=>@[_\|])/
      '&#'.ord($1).';'/ge;
    return "<input type='hidden' name='$name' value='$value'$disabled />";
}

=begin TML

---++ ObjectMethod urlEncode($data) -> $encodedData
URL encode a value.

=cut

sub urlEncode {
    my ( $this, $value ) = @_;
    $value =~ s/([^0-9a-zA-Z-_.:~!*\/])/'%'.sprintf('%02x',ord($1))/ge;
    return $value;
}

=begin TML

---++ StaticMethod authorised ($query) -> ($isAuthorized, $messageType)

Invoked to confirm authorisation, and handle password changes. The password
is changed in $Foswiki::cfg, a change which is then detected and written when
the configuration file is actually saved.

=cut

sub authorised {
    my $query = shift;

    my $pass     = $query->param('cfgAccess');
    my $newPass  = $query->param('newCfgP');
    my $confPass = $query->param('confCfgP');

    my ( $user, $addr ) = ( $query->remote_user(), $query->remote_addr() );
    my $defWorkDir = $query->param('{WorkingDir}');

    # Password defined, but no password supplied - reprompt
    if ( $Foswiki::cfg{Password} && !$pass ) {
        return ( 0, $MESSAGE_TYPE->{NONE} );
    }

    # If a password has been defined, check that it is valid
    if (
        $Foswiki::cfg{Password}
        && ( $pass
            && _encode_MD5( $pass, $Foswiki::cfg{Password} ) ne
            $Foswiki::cfg{Password} )
      )
    {
        _logPasswordFailure( $user, $addr );
        return ( 0, $MESSAGE_TYPE->{PASSWORD_INCORRECT} );
    }

    # Change the password if so requested
    if ( $query->param('changePassword') ) {
        return _setPassword( $defWorkDir, $newPass, $confPass, $user, $addr );
    }

    if ( !defined($pass) && $query->param('checkCfpP') ) {

        # first time, but using reload a password has been passed at least once

        if ( $newPass ne $confPass ) {
            return ( 0, $MESSAGE_TYPE->{PASSWORD_CONFIRM_NO_MATCH} );
        }
        if ( !$newPass || !$confPass ) {
            return ( 0, $MESSAGE_TYPE->{PASSWORD_NOT_SET} );
        }
        return _setPassword( $defWorkDir, $newPass, $confPass, $user, $addr );
    }

    # The first time we get here is after the "next" button is hit. A password
    # won't have been defined yet; so the authorisation must fail to force
    # a prompt.
    if ( !defined($pass) ) {
        return ( 0, $MESSAGE_TYPE->{NONE} );
    }

    # If we get this far, a password has been given. Check it.
    if ( !$Foswiki::cfg{Password} && !$confPass ) {

        return ( 0, $MESSAGE_TYPE->{PASSWORD_NOT_SET} );
    }

    # Password is correct, or no password defined

    return ( 1, $MESSAGE_TYPE->{OK} );
}

sub _setPassword {

    my ( $ok, $detail ) = setPassword(@_);

    return ( $ok, $MESSAGE_TYPE->{$detail} );
}

# Only called when authenticated; no reason to check old

sub setPassword {
    my ( $defWorkDir, $newPass, $confPass, $user, $addr ) = @_;

    $confPass ||= '';
    if ( !$newPass ) {
        return ( 0, 'PASSWORD_EMPTY' );
    }
    if ( $newPass ne $confPass ) {
        return wantarray ? ( 0, 'PASSWORD_CONFIRM_NO_MATCH' ) : 0;
    }
    $Foswiki::cfg{Password} = _encode_MD5($newPass);

    _encode_Digest( $newPass, $defWorkDir );
    return wantarray ? ( 1, 'PASSWORD_CHANGED' ) : 1;
}

# These should all become class methods so that they can be
# over-ridden - e.g. to replace with different encryption of
# storage.  Watch this space.

sub passwordState {
    unless ( $Foswiki::cfg{Password} ) {
        return 'PASSWORD_NOT_SET';
    }
    return 'OK';
}

sub removePassword {
    delete $Foswiki::cfg{Password};

    return '';
}

sub checkPassword {
    my ($password) = @_;

    unless ( $Foswiki::cfg{Password} ) {
        return 'PASSWORD_NOT_SET';
    }
    unless ($password) {
        return 'PASSWORD_EMPTY';
    }
    if ( $Foswiki::cfg{Password} eq
        _encode_MD5( $password, $Foswiki::cfg{Password} ) )
    {
        return 'OK';
    }

    _logPasswordFailure();
    return 'PASSWORD_INCORRECT';
}

sub collectMessages {
    my $this = shift;
    my ($item) = @_;

    my $errors   = $item->{errors}   || 0;
    my $warnings = $item->{warnings} || 0;

    return ( $errors, $warnings );
}

sub logPasswordFailure {
    my $query = shift;
    my $user  = $query->remote_user();
    my $addr  = $query->remote_addr();

    return _logPasswordFailure( $user, $addr );

}

sub _logPasswordFailure {
    my ( $user, $addr ) = @_;

    $user ||= $ENV{REMOTE_USER} || '';
    $addr ||= $ENV{REMOTE_ADDR} || '';

    my $logdir = $Foswiki::cfg{Log}{Dir};
    Foswiki::Configure::Load::expandValue($logdir);
    ($logdir) = $logdir =~ /^(.*)$/;
    unless ( -d $logdir ) {
        mkdir $logdir;
    }
    if ( open( my $lf, '>>', "$logdir/configure.log" ) ) {

        my $logmsg = '| '
          . gmtime() . ' | '
          . $user . ' | '
          . $addr . ' | '
          . '{Password} | '
          . "AUTHENTICATION FAILURE |\n";

        print $lf $logmsg;
        close($lf);
    }
}

sub _encode_Apache {
    my $pass   = shift;    # Password to be encoded
    my $stored = shift;    # Stored pw to recover salt.

    if ( defined $stored && length($stored) == 13 ) { # Old style crypt password
        return crypt( $pass, $stored );
    }

    my $salt;
    if ( defined $stored ) {
        $salt = substr( $stored, 0, 10 );
    }
    else {
        $salt = '$';
        my @saltchars = ( '.', '/', 0 .. 9, 'A' .. 'Z', 'a' .. 'z' );
        my $login = $Foswiki::cfg{AdminUserLogin} || 'admin';
        foreach my $i ( 0 .. 7 ) {

            $salt .= $saltchars[
              (
                  int( rand( $#saltchars + 1 ) ) +
                    $i +
                    ord( substr( $login, $i % length($login), 1 ) ) )
              % ( $#saltchars + 1 )
            ];
        }
        $salt .= '$';
    }
    return $salt . Digest::MD5::md5_hex( $salt . $pass );
}

sub _encode_MD5 {
    my $pass   = shift;    # Password to be encoded
    my $stored = shift;    # Stored pw to recover salt.
    my $APR    = 1;

    eval 'require Crypt::PasswdMD5';
    if ($@) {

        # For some reason perl module is not available
        $APR = 0;
        print STDERR
"Crypt::PasswdMD5 is missing.  Please install for improved configure security.\n";
    }

    # Checking password

    if ( defined $stored ) {
        my $salt;

        if ( length($stored) == 13 ) {    # Old style crypt password
            return crypt( $pass, $stored );
        }

        elsif ( length($stored) == 42 ) {
            $salt = substr( $stored, 0, 10 );
            return $salt . Digest::MD5::md5_hex( $salt . $pass );
        }
        elsif ( $APR && defined $stored && substr( $stored, 0, 5 ) eq '$apr1' )
        {
            $salt = substr( $stored, 0, 14 );
            return Crypt::PasswdMD5::apache_md5_crypt( $pass, $salt );
        }
        else {
            die "corrupted password" if defined $stored;
        }
    }

    # Encoding a new password

    if ($APR) {
        my $salt = '$apr1$';
        my @saltchars = ( '.', '/', 0 .. 9, 'A' .. 'Z', 'a' .. 'z' );
        foreach my $i ( 0 .. 7 ) {

            # generate a salt not only from rand() but also mixing
            # in the users login name: unecessary
            $salt .= $saltchars[
              (
                  int( rand( $#saltchars + 1 ) ) +
                    $i +
                    ord( substr( 'admin', $i % length('admin'), 1 ) ) )
              % ( $#saltchars + 1 )
            ];
        }
        return Crypt::PasswdMD5::apache_md5_crypt( $pass,
            substr( $salt, 0, 14 ) );
    }
    else {
        my $salt      = '$';
        my @saltchars = ( '.', '/', 0 .. 9, 'A' .. 'Z', 'a' .. 'z' );
        my $login     = $Foswiki::cfg{AdminUserLogin} || 'admin';
        foreach my $i ( 0 .. 7 ) {

            $salt .= $saltchars[
              (
                  int( rand( $#saltchars + 1 ) ) +
                    $i +
                    ord( substr( 'admin', $i % length('admin'), 1 ) ) )
              % ( $#saltchars + 1 )
            ];
        }
        $salt .= '$';
        return $salt . Digest::MD5::md5_hex( $salt . $pass );
    }
}

sub _encode_Digest {
    my $pass           = shift;    # Password to encode
    my $defaultWorkDir = shift;

    my $realm = 'Foswiki System Configuration';

    my $oldMask = umask(077);      # Access only by owner
    my $fh;

    # On very first run, pull this from url param, as config has not been saved.
    my $WorkingDir =
      ( defined $Foswiki::cfg{WorkingDir} )
      ? $Foswiki::cfg{WorkingDir}
      : $defaultWorkDir;
    ($WorkingDir) = $WorkingDir =~ m/(.*)/;    # Untaint, Hope admin knows best
    $WorkingDir =~ s#[/\\]+$##;                # Remove any trailing slash

    my ( $vol, $workdirs, $file ) = File::Spec->splitpath( $WorkingDir, 1 );
    my @wDirs = File::Spec->splitdir($workdirs);
    push( @wDirs, 'configure' );
    $workdirs = File::Spec->catdir(@wDirs);

    my $digestDir = File::Spec->catdir( $vol, $workdirs );
    unless ( -d $digestDir ) {
        my $saveumask = umask();
        umask( oct(000) );
        unless ( mkdir( untaint($digestDir), oct(755) ) ) {
            umask($saveumask);
            print STDERR "ERROR...  Configure unable to create $digestDir\n";
            print STDERR "ERROR...  Abandoned saving .htdigest-configure\n";
            return;
        }
        umask($saveumask);
    }

    my $fqDigest =
      File::Spec->catpath( $vol, $workdirs, '.htdigest-configure' );

    my $data = '';
    my $htExists;

    # Read in existing file if any
    if ( -e $fqDigest ) {
        $htExists = 1;
        if ( open( $fh, '<', $fqDigest ) ) {
            local $/ = undef;
            $data = <$fh>;
            close($fh);
        }
    }

    # Recover existing realm if any
    if ( $data =~ m/^admin:([^:]+):.*$/m ) {
        $realm = $1;

        #print STDERR "Reset realm to $realm\n";
    }

    my $toEncode = "admin:$realm:$pass";
    my $encoded  = Digest::MD5::md5_hex($toEncode);

    if ( $data =~ m/^admin:$realm/m ) {
        $data =~ s/^admin:$realm:.*+$/admin:$realm:$encoded/m;

        #print STDERR "replaced file with $data\n";
    }
    else {
        $data .= "admin:$realm:$encoded\n";

        #print STDERR "Appending file with $data\n";
    }

    open( $fh, '>', $fqDigest )
      || die "$fqDigest open failed: $!";
    print $fh $data;

    # Unless file previously existed,  make sure apache can read it.
    # But if the admin has changed permissions, don't override it!
    chmod 0640, $fqDigest unless $htExists;

    close($fh);
    umask($oldMask);    # Restore original umask
    return;
}

# Return a string of settingBlocks giving the status of various
# required modules.
# Either takes an array of hashes, or parameters in a hash.
# Each module hash needs:
#   name - e.g. Car::Wreck
#   usage - description of what it's for
#   dispostion - 'required', 'recommended'
#   minimumVersion - lowest acceptable $Module::VERSION
#
# if the module is installed, the hash will be updated to add
#   installedVersion - the version installed (or 'Unknown version')
sub checkPerlModules {
    my ( $this, $useTR, $mods ) = @_;

    my $e = '';
    foreach my $mod (@$mods) {
        $mod->{minimumVersion} ||= 0;
        $mod->{disposition}    ||= '';
        my $n = '';

        my ( $installed, $mod_version ) = extractModuleVersion( $mod->{name} );

        if ($installed) {
            $mod_version ||= 0;
            $mod_version =~ s/(\d+(\.\d*)?).*/$1/;    # keep 99.99 style only

            $mod->{installedVersion} = $mod_version || 'Unknown version';
            if ( $mod_version < $mod->{minimumVersion} ) {
                $n = $mod->{installedVersion};
                $n .=
                    ' installed. Version '
                  . $mod->{minimumVersion} . ' '
                  . $mod->{disposition};
                $n .= ' ' . $mod->{usage} if $mod->{usage};
            }
        }
        else {
            $n = 'Not installed. ' . $mod->{usage};
        }
        if ($n) {
            if ( $mod->{disposition} eq 'required' ) {
                $n = $this->ERROR($n);
            }
            elsif ( $mod->{disposition} eq 'recommended' ) {
                $n = $this->WARN($n);
            }
            else {
                $n = $this->NOTE($n);
            }
        }
        else {
            $mod_version ||= 'Unknown version';
            $n = $mod_version . ' installed.';
            $n .= ' ' . $mod->{usage} if $mod->{usage};
            $n = $this->NOTE($n);
        }
        if ($useTR) {
            my $modname = $mod->{name};
            if ( $useTR == 2 )
            {    # This link should be stable, or we could check Interwikis.txt
                $modname =
qq{$modname<br /><a href="http://search.cpan.org/perldoc?$modname" class="configureDependenciesLink" target="_blank">CPAN</a>};
            }
            $e .= $this->setting( $modname, $n );
        }
        else {
            $e .=
"<div class='configureSetting'><code>$mod->{name}:</code> $n</div>";
        }
    }
    return $e;
}

sub checkPerlModule {
    my ( $this, $module, $usage, $version ) = @_;
    my $error = $this->checkPerlModules(
        0,
        [
            {
                name           => $module,
                minimumVersion => $version,
                usage          => $usage
            }
        ]
    );
    return $error;
}

=begin TML

---++ StaticMethod extractModuleVersion ($moduleName, $magic) -> ($moduleFound, $moduleVersion, $modulePath)

Locates a module in @INC and parses it to determine its version.  If the second parameter is
true, it magically handles Foswiki.pm's version construction.

Returns:
  $moduleFound - True if the module was found (and could be opended for read)
  $moduleVersion - The module version that was extracted, or undef if none was found.
  $modulePath - The full path to the module.

Require was used previously, but it doesn't scale and can have side-effects such a
loading many unused dependencies, even LocalSite.cfg if it's a Foswiki module.

Since $VERSION is usually declared early in a module, we can also avoid reading
most of (most) files.

This parser was inspired by Module::Extract::VERSION, though this is simplified and
has special magic for the Foswiki build.

=cut

sub extractModuleVersion {
    my $module    = shift;
    my $FoswikiPM = shift;

    my $file = $module;
    $file =~ s,::,/,g;
    $file .= '.pm';
    my ( $mod_version, $mod_release );
    $mod_release = '';

    foreach my $dir (@INC) {
        open( my $mf, '<', "$dir/$file" ) or next;
        local $/ = "\n";
        local $_;
        my $pod;
        while (<$mf>) {
            chomp;
            if (/^=cut/) {
                $pod = 0;
                next;
            }
            if (/^=/) {
                $pod = 1;
                next;
            }
            next if ($pod);
            s/\s*#.*$//;
            if ($FoswikiPM) {
                if (/^\s*(?:our\s+)?\$(?:\w*::)*VERSION\s*=~\s*(.*?);/) {
                    my $exp = $1;
                    $exp =~ s/\$RELEASE/\$mod_release/g;
                    eval "\$mod_version =~ $exp;";
                    die "Failed to eval $1 from $_ in $file at line $.: $@\n"
                      if ($@);
                    last;
                }
                if (
/\$VERSION\s*=\s*version->(?:new|parse|declare)\s*\(\s*"([vV]\d+\.\d+\.\d+(?:_\d+)?)"\s*\)/
                  )
                {
                    $mod_version = $1;
                    last;
                }
                if (
/^\s*(?:our\s+)?\$(?:\w*::)*(RELEASE|VERSION)\s*=[^~]\s*(.*?);/
                  )
                {
                    eval "\$mod_" . lc($1) . " = $2;";
                    die "Failed to eval $2 from $_ in $file at line $.: $@\n"
                      if ($@);
                    next;
                }
                next;
            }
            next unless (/^\s*(?:our\s+)?\$(?:\w*::)*VERSION\s*=\s*(.*?);/);
            eval "\$mod_version = $1;";

    # die "Failed to eval $1 from $_ in $file at line $. $@\n" if( $@ ); # DEBUG
            last;
        }
        close $mf;
        return ( 1, $mod_version, "$dir/$file" );
    }

    return ( 0, undef );
}

sub getTemplateParser {
    if ( !$templateParser ) {

        # get the template parser
        eval 'use Foswiki::Configure::TemplateParser ()';
        if ($@) {
            die "TemplateParser could not be loaded:" . join( " ", $@ );
        }

        $templateParser = Foswiki::Configure::TemplateParser::getParser(
            $DEFAULT_TEMPLATE_PARSER);

        # skin can be set using url parameter 'skin'
        my $skin;
        $skin = $Foswiki::query->param('skin') if $Foswiki::query;
        $templateParser->setSkin($skin) if $skin;
    }
    return $templateParser;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
