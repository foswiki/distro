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
use FindBin    ();
use Digest::MD5 qw(md5_hex);
use File::Spec qw(splitpath catpath splitdir catdir);

our $totwarnings;
our $toterrors;
our $firsttime;

our $MESSAGE_TYPE = {
    NONE                      => ( 1 << 0 ),    # 1
    OK                        => ( 1 << 1 ),    # 2
    PASSWORD_CHANGED          => ( 1 << 2 ),    # 4
    PASSWORD_NOT_SET          => ( 1 << 3 ),    # 8
    PASSWORD_INCORRECT        => ( 1 << 4 ),    # 16
    PASSWORD_CONFIRM_NO_MATCH => ( 1 << 5 ),    # 32
    PASSWORD_EMPTY            => ( 1 << 6 ),    # 64
};
my $DEFAULT_TEMPLATE_PARSER = 'SimpleFreeMarker';
my $templateParser;

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
    my @root = File::Spec->splitdir( $this->{bin} );
    pop(@root);

    # SMELL: Force a trailing separator - Linux and Windows are inconsistent
    $this->{root} = File::Spec->catfile( @root, 'x' );
    chop $this->{root};

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

Returns the checker created or undef if no such checker is found.

Will die if the checker exists but fails to compile.

$item is passed on to the checker's constructor.

=cut

sub loadChecker {
    my ( $id, $item ) = @_;
    $id =~ s/}{/::/g;
    $id =~ s/[}{]//g;
    $id =~ s/'//g;
    $id =~ s/-/_/g;
    my $checkClass = 'Foswiki::Configure::Checkers::' . $id;
    eval "use $checkClass ()";

    # Can't locate errors are OK
    return if ( $@ && $@ =~ /Can't locate / );
    die $@ if ($@);

    return $checkClass->new($item);
}

=begin TML

---++ ObjectMethod getUrl() -> $response

Returns a response object as described in Foswiki::Net

=cut

sub getUrl {
    my ( $this, $url ) = @_;

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

---++ ObjectMethod hidden($value) -> $html
Used in place of CGI::hidden, which is broken in some CGI versions.
HTML encodes the value

=cut

sub hidden {
    my ( $name, $value ) = @_;
    $name ||= '';
    $name =~ s/([[\x01-\x09\x0b\x0c\x0e-\x1f"%&'*<=>@[_\|])/
      '&#'.ord($1).';'/ge;
    $value ||= '';
    $value =~ s/([[\x01-\x09\x0b\x0c\x0e-\x1f"%&'*<=>@[_\|])/
      '&#'.ord($1).';'/ge;
    return "<input type='hidden' name='$name' value='$value' />";
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

---++ StaticMethod authorised () -> ($isAuthorized, $messageType)

Invoked to confirm authorisation, and handle password changes. The password
is changed in $Foswiki::cfg, a change which is then detected and written when
the configuration file is actually saved.

=cut

sub authorised {

    my $pass    = $Foswiki::query->param('cfgAccess');
    my $newPass = $Foswiki::query->param('newCfgP');

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
        logPasswordFailure();
        return ( 0, $MESSAGE_TYPE->{PASSWORD_INCORRECT} );
    }

    # Change the password if so requested
    if ( $Foswiki::query->param('changePassword') ) {
        my $confPass = $Foswiki::query->param('confCfgP') || '';
        if ( !$newPass ) {
            return ( 0, $MESSAGE_TYPE->{PASSWORD_EMPTY} );
        }
        if ( $newPass ne $confPass ) {
            return ( 0, $MESSAGE_TYPE->{PASSWORD_CONFIRM_NO_MATCH} );
        }
        $Foswiki::cfg{Password} = _encode_MD5($newPass);

        _encode_Digest($newPass);
        return ( 1, $MESSAGE_TYPE->{PASSWORD_CHANGED} );
    }

    if ( !defined($pass) && $Foswiki::query->param('checkCfpP') ) {

        # first time, but using reload a password has been passed at least once

        my $confPass = $Foswiki::query->param('confCfgP');
        if ( $newPass ne $confPass ) {
            return ( 0, $MESSAGE_TYPE->{PASSWORD_CONFIRM_NO_MATCH} );
        }
        if ( !$newPass || !$confPass ) {
            return ( 0, $MESSAGE_TYPE->{PASSWORD_NOT_SET} );
        }
        $Foswiki::cfg{Password} = _encode_MD5($newPass);

        _encode_Digest($newPass);

        return ( 1, $MESSAGE_TYPE->{PASSWORD_CHANGED} );
    }

    # The first time we get here is after the "next" button is hit. A password
    # won't have been defined yet; so the authorisation must fail to force
    # a prompt.
    if ( !defined($pass) ) {
        return ( 0, $MESSAGE_TYPE->{NONE} );
    }

    # If we get this far, a password has been given. Check it.
    if ( !$Foswiki::cfg{Password} && !$Foswiki::query->param('confCfgP') ) {

        return ( 0, $MESSAGE_TYPE->{PASSWORD_NOT_SET} );
    }

    # Password is correct, or no password defined

    return ( 1, $MESSAGE_TYPE->{OK} );
}

sub collectMessages {
    my $this = shift;
    my ($item) = @_;

    my $errors   = $item->{errors}   || 0;
    my $warnings = $item->{warnings} || 0;

    return ( $errors, $warnings );
}

sub logPasswordFailure {
    my $logdir = $Foswiki::cfg{Log}{Dir};
    Foswiki::Configure::Load::expandValue($logdir);
    ($logdir) = $logdir =~ /^(.*)$/;
    unless ( -d $logdir ) {
        mkdir $logdir;
    }
    if ( open( my $lf, '>>', "$logdir/configure.log" ) ) {

        my $user = $Foswiki::query->remote_user() || $ENV{REMOTE_USER} || '';
        my $addr = $Foswiki::query->remote_addr() || $ENV{REMOTE_ADDR} || '';

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
    my $pass  = shift;                            # Password to encode
    my $realm = 'Foswiki System Configuration';

    my $oldMask = umask(077);                     # Access only by owner
    my $fh;

    # On very first run, pull this from url param, as config has not been saved.
    my $WorkingDir =
      ( defined $Foswiki::cfg{WorkingDir} )
      ? $Foswiki::cfg{WorkingDir}
      : $Foswiki::query->param('{WorkingDir}');
    ($WorkingDir) = $WorkingDir =~ m/(.*)/;    # Untaint, Hope admin knows best
    $WorkingDir =~ s#[/\\]+$##;                # Remove any trailing slash

    my ( $vol, $workdirs, $file ) = File::Spec->splitpath( $WorkingDir, 1 );
    my @wDirs = File::Spec->splitdir($workdirs);
    push( @wDirs, 'configure' );
    $workdirs = File::Spec->catdir(@wDirs);
    my $fqDigest =
      File::Spec->catpath( $vol, $workdirs, '.htdigest-configure' );

    my $data = '';

    # Read in existing file if any
    if ( -e $fqDigest ) {
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
        my $mod_version;

        # require instead of use = see Bugs:Item4585
        eval 'require ' . $mod->{name};
        if ($@) {
            $n = 'Not installed. ' . $mod->{usage};
        }
        else {
            no strict 'refs';
            eval '$mod_version = $' . $mod->{name} . '::VERSION';
            $mod_version ||= 0;
            $mod_version =~ s/(\d+(\.\d*)?).*/$1/;    # keep 99.99 style only
            use strict 'refs';
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
            $e .= $this->setting( $mod->{name}, $n );
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
        my $skin = $Foswiki::query->param('skin') if $Foswiki::query;
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
