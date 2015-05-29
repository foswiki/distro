# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Users::HtPasswdUser

Support for htpasswd and htdigest format password files.

Subclass of =[[%SCRIPTURL{view}%/%SYSTEMWEB%/PerlDoc?module=Foswiki::Users::Password][Foswiki::Users::Password]]=.
See documentation of that class for descriptions of the methods of this class.

=cut

package Foswiki::Users::HtPasswdUser;
use strict;
use warnings;

use Foswiki::Users::Password ();
our @ISA = ('Foswiki::Users::Password');

use Assert;
use Error qw( :try );
use Fcntl qw( :DEFAULT :flock );

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

our ( $GlobalCache, $GlobalTimestamp );

sub PasswordData {
    my $this = shift;

    if ( $Foswiki::cfg{Htpasswd}{GlobalCache} ) {
        $HtPasswdUser::GlobalCache = shift if @_;
        return $HtPasswdUser::GlobalCache;
    }
    else {
        $this->{LocalCache} = shift if @_;
        return $this->{LocalCache};
    }
}

sub PasswordTimestamp {
    my $this = shift;
    if ( $Foswiki::cfg{Htpasswd}{GlobalCache} ) {
        $HtPasswdUser::GlobalTimestamp = shift if @_;
        return $HtPasswdUser::GlobalTimestamp;
    }
    else {
        $this->{LocalTimestamp} = shift if @_;
        return $this->{LocalTimestamp};
    }
}

# Used in unit tests to reset the cache.  Also used to clear the cache if the
# Password file has been modified externally.
sub ClearCache {
    my $this = shift;
    if ( $Foswiki::cfg{Htpasswd}{GlobalCache} ) {
        $HtPasswdUser::GlobalCache     = ();
        $HtPasswdUser::GlobalTimestamp = 0;
    }
    else {
        undef $this->{LocalCache};
        undef $this->{LocalTimestamp};
    }
}

# Set TRACE to 1 to enable trace of password activity
# Set TRACE to 2 for verbose auto-encoding report
use constant TRACE => 0;

sub new {
    my ( $class, $session ) = @_;
    my $this = bless( $class->SUPER::new($session), $class );
    $this->{error} = undef;

    if ( $Foswiki::cfg{Htpasswd}{AutoDetect} ) {

      # For autodetect, soft errors are allowed.  If the .htpasswd file contains
      # a password for an unsupported encoding, it will not match.
        eval 'use Digest::SHA';
        $this->{SHA} = 1 unless ($@);
        eval 'use Crypt::PasswdMD5';
        $this->{APR} = 1 unless ($@);
        eval 'use Crypt::Eksblowfish::Bcrypt;';
        $this->{BCRYPT} = 1 unless ($@);
    }

    if (   $Foswiki::cfg{Htpasswd}{Encoding} eq 'md5'
        || $Foswiki::cfg{Htpasswd}{Encoding} eq 'htdigest-md5' )
    {
        require Digest::MD5;
        if ( $Foswiki::cfg{AuthRealm} =~ m/\:/ ) {
            print STDERR
"ERROR: the AuthRealm cannot contain a ':' (colon) as it corrupts the password file\n";
            throw Error::Simple(
"ERROR: the AuthRealm cannot contain a ':' (colon) as it corrupts the password file"
            );
        }
    }
    elsif ( $Foswiki::cfg{Htpasswd}{Encoding} eq 'crypt' ) {
    }
    elsif ( $Foswiki::cfg{Htpasswd}{Encoding} eq 'plain' ) {
    }
    elsif ( $Foswiki::cfg{Htpasswd}{Encoding} eq 'sha1' ) {
        require Digest::SHA;
        $this->{SHA} = 1;
    }
    elsif ( $Foswiki::cfg{Htpasswd}{Encoding} eq 'apache-md5' ) {
        require Crypt::PasswdMD5;
        $this->{APR} = 1;
    }
    elsif ( $Foswiki::cfg{Htpasswd}{Encoding} eq 'crypt-md5' ) {
        eval 'use Crypt::PasswdMD5';
        $this->{APR} = 1 unless ($@);
    }
    elsif ( $Foswiki::cfg{Htpasswd}{Encoding} eq 'bcrypt' ) {
        eval 'use Crypt::Eksblowfish::Bcrypt;';
        $this->{BCRYPT} = 1 unless ($@);
    }
    else {
        print STDERR "ERROR: unknown {Htpasswd}{Encoding} setting : "
          . $Foswiki::cfg{Htpasswd}{Encoding} . "\n";
        throw Error::Simple( "ERROR: unknown {Htpasswd}{Encoding} setting : "
              . $Foswiki::cfg{Htpasswd}{Encoding}
              . "\n" );
    }

    return $this;
}

=begin TML

---++ ObjectMethod finish()
Break circular references.

=cut

# Note to developers; please undef *all* fields in the object explicitly,
# whether they are references or not. That way this method is "golden
# documentation" of the live fields in the object.
sub finish {
    my $this = shift;
    $this->SUPER::finish();
    undef $this->{LocalCache};
    undef $this->{LocalTimestamp};
}

=begin TML

---++ ObjectMethod readOnly(  ) -> boolean

returns true if the password file is not currently modifyable

=cut

sub readOnly {
    my $this = shift;
    my $path = $Foswiki::cfg{Htpasswd}{FileName};

    # We expect the path to exist and be writable.
    if ( -e $path && -f _ && -w _ ) {
        $this->{session}->enterContext('passwords_modifyable');
        return 0;
    }

    # Otherwise, log a problem.
    $this->{session}->logger->log( 'warning',
            'The password file does not exist or cannot be written.'
          . 'Run =configure= and check the setting of {Htpasswd}{FileName}.'
          . ' New user registration has been disabled until this is corrected.'
    );

    # And disable registration (which will also disable password changes)
    $Foswiki::cfg{Register}{EnableNewUserRegistration} = 0;

    return 1;
}

sub canFetchUsers {
    return 1;
}

sub fetchUsers {
    my $this = shift;

    # Read passwords with shared lock
    my $db    = $this->_readPasswd(1);
    my @users = sort keys %$db;
    require Foswiki::ListIterator;
    return Foswiki::ListIterator->new( \@users );
}

# Lock the htpasswd semaphore file (create if it does not exist)
# Returns a file handle that you can later simply close with _unlockPasswdFile
sub _lockPasswdFile {
    my $operator     = @_;
    my $lockFileName = $Foswiki::cfg{Htpasswd}{LockFileName}
      || "$Foswiki::cfg{WorkingDir}/htpasswd.lock";

    sysopen( my $fh, $lockFileName, O_RDWR | O_CREAT, 0666 )
      || throw Error::Simple( $lockFileName
          . ' open or create password lock file failed -'
          . 'check access rights: '
          . $! );
    flock $fh, $operator;

    return $fh;
}

# Unlock the semaphore file. You must pass the filehandle for the lock file
# which was returned by _lockPasswdFile
sub _unlockPasswdFile {
    my $fh = shift;
    close($fh);
}

=begin TML

---++ _readPasswd ( $lock, $cache );

Read the password file. The content of the file is cached in
the password object.

We put a shared lock while reading if requested to prevent
other processes from writing while we read but still allows
parallel reading. The caller must never request a shared lock
if there is already an exclusive lock.

   * if $lockShared is true, a shared lock is requested./
   * if $cache is true, the in-memory cache will be returned if available.

This routine implements the auto-detection code for password entries:

%TABLE{sort="off"}%
| *Type* | *Length* | *Matches* |
| htdigest-md5 | n/a | $Foswiki::cfg{AuthRealm} | (Realm has to be an exact match) |
| sha1 | 33 | =^\{SHA\}= |
| crypt-md5 | 34 | =^\$1\$= |
| apache-md5 | 37 | =^\$apr1\$= |
| bcrypt | 60 | =^\$2a\$= |
| crypt | 13 | | next field contains an email address |
| plain | any | | next field contains an email address |
| sha | | | (I don't recall what this encoding is, maybe an older implementation?) |
| htdigest-md5 | any | | If next field contains a md5 hash, Fallthru match in case realm changed |

=cut

sub _readPasswd {
    my ( $this, $lockShared, $noCache ) = @_;

    unless ($noCache) {

        if (   $Foswiki::cfg{Htpasswd}{DetectModification}
            && $this->PasswordData()
            && -e $Foswiki::cfg{Htpasswd}{FileName} )
        {
            my $fileTime = ( stat(_) )[9];
            if ( $fileTime > $this->PasswordTimestamp() ) {
                $this->ClearCache();
            }
        }

        return $this->PasswordData() if ( $this->PasswordData() );
    }

    my $data = {};
    if ( !-e $Foswiki::cfg{Htpasswd}{FileName} ) {
        print STDERR
          "WARNING - $Foswiki::cfg{Htpasswd}{FileName} DOES NOT EXIST\n";
        return $data;
    }

    $lockShared |= 0;
    my $lockHandle;
    $lockHandle = _lockPasswdFile(LOCK_SH) if $lockShared;
    $this->PasswordTimestamp(
        ( stat( $Foswiki::cfg{Htpasswd}{FileName} ) )[9] );
    print STDERR "Loading Passwords, timestamp "
      . $this->PasswordTimestamp() . " \n"
      if (TRACE);
    my $IN_FILE;

    local $/ = "\n";

    my $enc = $Foswiki::cfg{Htpasswd}{CharacterEncoding} || 'utf-8';
    open( $IN_FILE, "<:encoding($enc)", $Foswiki::cfg{Htpasswd}{FileName} )
      || throw Error::Simple(
        $Foswiki::cfg{Htpasswd}{FileName} . ' open failed: ' . $! );
    my $line = '';
    my $tID;
    my $pwcount = 0;
    while ( defined( $line = <$IN_FILE> ) ) {
        next if ( substr( $line, 0, 1 ) eq '#' );
        chomp $line;
        $pwcount++;
        my @fields = split( /:/, $line, 5 );

        if ( TRACE > 1 ) {
            print STDERR "\nSplit LINE $line\n";
            foreach my $f (@fields) { print STDERR "split: $f\n"; }
        }

        my $hID = shift @fields;

        if ( $Foswiki::cfg{Htpasswd}{AutoDetect} ) {
            my $tPass = shift @fields;

            # tPass is either a password or a realm
            if (
                $tPass eq $Foswiki::cfg{AuthRealm}
                || (   defined $fields[0]
                    && length( $fields[0] ) eq 32
                    && defined $fields[1]
                    && $fields[1] =~ m/@/ )
              )
            {
                $data->{$hID}->{enc}    = 'htdigest-md5';
                $data->{$hID}->{realm}  = $tPass;
                $data->{$hID}->{pass}   = shift @fields;
                $data->{$hID}->{emails} = shift @fields || '';
                print STDERR "Auto ENCODING-1 $data->{$hID}->{enc} \n"
                  if ( TRACE > 1 );
                next;
            }

            if ( length($tPass) eq 33 && $tPass =~ m/^\{SHA\}/ ) {
                $data->{$hID}->{enc} = 'sha1';
            }
            elsif ( length($tPass) eq 34 && $tPass =~ m/^\$1\$/ ) {
                $data->{$hID}->{enc} = 'crypt-md5';
            }
            elsif ( length($tPass) eq 37 && $tPass =~ m/^\$apr1\$/ ) {
                $data->{$hID}->{enc} = 'apache-md5';
            }
            elsif ( length($tPass) eq 60 && $tPass =~ m/^\$2a\$/ ) {
                $data->{$hID}->{enc} = 'bcrypt';
            }
            elsif ( length($tPass) eq 13
                && ( !$fields[0] || $fields[0] =~ m/@/ ) )
            {
                $data->{$hID}->{enc} = 'crypt';
            }
            elsif ( length($tPass) gt 0 && !$fields[0]
                || $fields[0] =~ m/@/ )
            {
                $data->{$hID}->{enc} = 'plain';
            }
            elsif ( length($tPass) eq 0 && !$fields[0]
                || $fields[0] =~ m/@/ )
            {
                $data->{$hID}->{enc} = 'sha';
            }

            if ( $data->{$hID}->{enc} ) {
                $data->{$hID}->{pass} = $tPass;
                $data->{$hID}->{emails} = shift @fields || '';
                print STDERR "Auto ENCODING-2 $data->{$hID}->{enc} \n"
                  if ( TRACE > 1 );
                next;
            }

            print STDERR "Fell through - must be htdigest-md5   "
              . length($tPass)
              . "--$tPass \n"
              if ( TRACE > 1 );

            # Fell through - only thing left is digest encoding
            $data->{$hID}->{enc}    = 'htdigest-md5';
            $data->{$hID}->{realm}  = $tPass;
            $data->{$hID}->{pass}   = shift @fields;
            $data->{$hID}->{emails} = shift @fields || '';
            print STDERR "Auto ENCODING-3 $data->{$hID}->{enc} \n"
              if ( TRACE > 1 );
        }

        # Static configuration
        else {
            $data->{$hID}->{enc}   = $Foswiki::cfg{Htpasswd}{Encoding};
            $data->{$hID}->{realm} = shift @fields
              if ( $Foswiki::cfg{Htpasswd}{Encoding} eq 'md5'
                || $Foswiki::cfg{Htpasswd}{Encoding} eq 'htdigest-md5' );
            $data->{$hID}->{pass} = shift @fields;
            $data->{$hID}->{emails} = shift @fields || '';
            print STDERR
"Static Encoding - $hID:  $data->{$hID}->{enc} pass $data->{$hID}->{pass} emails $data->{$hID}->{emails} \n"
              if ( TRACE > 1 );
        }
    }
    close($IN_FILE);
    print STDERR "Loaded $pwcount passwords\n" if (TRACE);
    $this->PasswordData($data);
    $this->PasswordTimestamp(
        ( stat( $Foswiki::cfg{Htpasswd}{FileName} ) )[9] );

    _unlockPasswdFile($lockHandle) if $lockShared;

    return $data;
}

=begin TML

---++ _dumpPasswd( $db ) -> $boolean

Dumps the memory password database to a newline separated string


=cut

sub _dumpPasswd {
    my $db = shift;
    my @entries;
    my $pwcount = 0;
    foreach my $login ( sort( keys(%$db) ) ) {

        $pwcount++;
        my $entry = "$login:";
        if (
               $db->{$login}->{pass}
            && $db->{$login}->{enc}
            && (   $db->{$login}->{enc} eq 'md5'
                || $db->{$login}->{enc} eq 'htdigest-md5' )
          )
        {
            print STDERR
"Writing realm - $db->{$login}->{enc} for $login pass ($db->{$login}->{pass})\n"
              if ( TRACE > 1 );

            # htdigest format
            $entry .= "$db->{$login}->{realm}:";
        }
        $db->{$login}->{pass}   ||= '';
        $db->{$login}->{emails} ||= '';
        $entry .= $db->{$login}->{pass} . ':' . $db->{$login}->{emails};
        push( @entries, $entry );
    }
    print STDERR "Saving $pwcount entries\n" if (TRACE);

    #   if ( $pwcount < 50 ) {
    #        print STDERR Data::Dumper::Dumper( \@entries );
    #        die "REFUSE To Save:  Less than 50 passwords\n";
    #    }
    return join( "\n", @entries ) . "\n";
}

=begin TML

---++ _savePasswd( $db ) -> $passwordE

Creates a new password file, and saves the content of the
internal password database to the file.

After writing the file, the cache timestamp is reset.

The umask is overridden during save, so that the password file is not world or group readable.
=cut

sub _savePasswd {
    my $this = shift;
    my $db   = shift;

    unless ( -e "$Foswiki::cfg{Htpasswd}{FileName}" ) {

       # Item4544: Document special format used in .htpasswd for email addresses
        open( my $readme, '>', "$Foswiki::cfg{Htpasswd}{FileName}.README" )
          or throw Error::Simple(
            $Foswiki::cfg{Htpasswd}{FileName} . '.README open failed: ' . $! );

        print $readme <<'EoT';
Foswiki uses a specially crafted .htpasswd file format that should not be
manipulated using a standard htpasswd utility or loss of registered emails might occur.
(3rd-party utilities do not support the email address format used by Foswiki).

More information available at: http://foswiki.org/System/UserAuthentication.
EoT
        close($readme);
    }

    my $content = _dumpPasswd($db);
    print STDERR "CONTENT $content\n" if ( TRACE > 1 );

    my $oldMask = umask(077);    # Access only by owner
    my $fh;

    my $enc = $Foswiki::cfg{Htpasswd}{CharacterEncoding} || 'utf-8';
    open( $fh, ">:encoding($enc)", $Foswiki::cfg{Htpasswd}{FileName} )
      || throw Error::Simple(
        "$Foswiki::cfg{Htpasswd}{FileName} open failed: $!");
    print $fh $content;

    close($fh);

    # Reset the cache timestamp
    $this->PasswordData($db);
    $this->PasswordTimestamp(
        ( stat( $Foswiki::cfg{Htpasswd}{FileName} ) )[9] );
    umask($oldMask);    # Restore original umask
}

=begin TML

---++ encrypt( $login, $passwordU, $fresh ) -> $passwordE

Will return an encrypted password. Repeated calls
to encrypt with the same login/passU will return the same passE.

However if the passU is changed, and subsequently changed _back_
to the old login/passU pair, then the old passE is no longer valid.

If $fresh is true, then a new password not based on any pre-existing
salt will be used. Set this if you are generating a completely
new password.

=cut

sub encrypt {
    my ( $this, $login, $passwd, $fresh, $entry ) = @_;

    $passwd ||= '';

    my $enc = $entry->{enc};
    $enc ||= $Foswiki::cfg{Htpasswd}{Encoding};

    if ( $enc eq 'sha1' ) {

        unless ( $this->{SHA} ) {
            $this->{error} = "Unsupported Encoding";
            return 0;
        }

        my $encodedPassword = '{SHA}'
          . Digest::SHA::sha1_base64( Foswiki::encode_utf8($passwd) ) . '=';

        # don't use chomp, it relies on $/
        $encodedPassword =~ s/\s+$//;
        return $encodedPassword;

    }
    elsif ( $enc eq 'crypt' ) {

        # by David Levy, Internet Channel, 1997
        # found at http://world.inch.com/Scripts/htpasswd.pl.html

        my $salt;
        $salt = $this->fetchPass($login) unless $fresh;
        if ( $fresh || !$salt ) {
            my @saltchars = ( 'a' .. 'z', 'A' .. 'Z', '0' .. '9', '.', '/' );
            $salt =
                $saltchars[ int( rand( $#saltchars + 1 ) ) ]
              . $saltchars[ int( rand( $#saltchars + 1 ) ) ];
        }
        return crypt( Foswiki::encode_utf8($passwd),
            Foswiki::encode_utf8( substr( $salt, 0, 2 ) ) );

    }
    elsif ( $enc eq 'md5' || $enc eq 'htdigest-md5' ) {

        # SMELL: what does this do if we are using a htpasswd file?
        my $realm = $entry->{realm} || $Foswiki::cfg{AuthRealm};
        my $toEncode = "$login:$realm:$passwd";
        return Digest::MD5::md5_hex( Foswiki::encode_utf8($toEncode) );

    }
    elsif ( $enc eq 'apache-md5' ) {

        unless ( $this->{APR} ) {
            $this->{error} = "Unsupported Encoding";
            return 0;
        }

        my $salt;
        $salt = $this->fetchPass($login) unless $fresh;
        if ( $fresh || !$salt ) {
            $salt = '$apr1$';
            my @saltchars = ( '.', '/', 0 .. 9, 'A' .. 'Z', 'a' .. 'z' );
            foreach my $i ( 0 .. 7 ) {

                # generate a salt not only from rand() but also mixing
                # in the users login name: unecessary
                $salt .= $saltchars[
                  (
                      int( rand( $#saltchars + 1 ) ) +
                        $i +
                        ord( substr( $login, $i % length($login), 1 ) ) )
                  % ( $#saltchars + 1 )
                ];
            }
        }
        return Crypt::PasswdMD5::apache_md5_crypt(
            Foswiki::encode_utf8($passwd),
            Foswiki::encode_utf8( substr( $salt, 0, 14 ) ) );
    }
    elsif ( $enc eq 'crypt-md5' ) {
        my $salt;
        $salt = $this->fetchPass($login) unless $fresh;
        if ( $fresh || !$salt ) {
            $salt = '$1$';
            my @saltchars = ( '.', '/', 0 .. 9, 'A' .. 'Z', 'a' .. 'z' );
            foreach my $i ( 0 .. 7 ) {

                # generate a salt not only from rand() but also mixing
                # in the users login name: unecessary
                $salt .= $saltchars[
                  (
                      int( rand( $#saltchars + 1 ) ) +
                        $i +
                        ord( substr( $login, $i % length($login), 1 ) ) )
                  % ( $#saltchars + 1 )
                ];
            }
        }

        # crypt is not cross-plaform, so use Crypt::PasswdMD5 if it's available
        if ( $this->{APR} ) {
            return Crypt::PasswdMD5::unix_md5_crypt(
                Foswiki::encode_utf8($passwd),
                Foswiki::encode_utf8( substr( $salt, 0, 11 ) ) );
        }
        else {
            return crypt( Foswiki::encode_utf8($passwd),
                Foswiki::encode_utf8( substr( $salt, 0, 11 ) ) );
        }

    }
    elsif ( $enc eq 'plain' ) {
        return $passwd;

    }
    elsif ( $enc eq 'bcrypt' ) {
        unless ( $this->{BCRYPT} ) {
            $this->{error} = "Unsupported Encoding";
            return 0;
        }

        my $salt;
        $salt = $this->fetchPass($login) unless $fresh;
        if ( $fresh || !$salt ) {
            my @saltchars = ( '.', '/', 0 .. 9, 'A' .. 'Z', 'a' .. 'z' );
            foreach my $i ( 0 .. 15 ) {

                # generate a salt not only from rand() but also mixing
                # in the users login name: unecessary
                $salt .= $saltchars[
                  (
                      int( rand( $#saltchars + 1 ) ) +
                        $i +
                        ord( substr( $login, $i % length($login), 1 ) ) )
                  % ( $#saltchars + 1 )
                ];
            }
            $salt =
              Crypt::Eksblowfish::Bcrypt::en_base64(
                Foswiki::encode_utf8($salt) );
            $salt = '$2a$08$' . $salt;
        }
        $salt = substr( $salt, 0, 29 );
        return Crypt::Eksblowfish::Bcrypt::bcrypt(
            Foswiki::encode_utf8($passwd),
            Foswiki::encode_utf8($salt) );
    }
    die 'Unsupported password encoding ' . $enc;
}

=begin TML

---++ ObjectMethod fetchPass( $login ) -> $passwordE

Implements Foswiki::Password

Returns encrypted password if succeeds.
Returns 0 if login is invalid.
Returns undef otherwise.

=cut

sub fetchPass {
    my ( $this, $login ) = @_;
    my $ret = 0;
    my $enc = '';
    my $db;

    if ($login) {
        try {

            # Read passwords with shared lock
            $db = $this->_readPasswd(1);
            if ( exists $db->{$login} ) {
                $ret = $db->{$login}->{pass};
                $enc = $db->{$login}->{enc};
            }
            else {
                $this->{error} = "Login $login invalid";
                $ret = undef;
            }
        }
        catch Error with {
            my $e = shift;
            $this->{error} = $!;
            print STDERR "ERROR: failed to fetchPass - $! ($e)";
            $this->{error} = 'unknown error in fetchPass'
              unless ( $this->{error} && length( $this->{error} ) );
            return undef;
        };
    }
    else {
        $this->{error} = 'No user';
    }
    return (wantarray) ? ( $ret, $db->{$login} ) : $ret;
}

=begin TML

---++ setPassword( $login, $newPassU, $oldPassU ) -> $boolean

If the $oldPassU matches matches the user's password, then it will
replace it with $newPassU.

If $oldPassU is not correct and not 1, will return 0.

If $oldPassU is 1, will force the change irrespective of
the existing password, adding the user if necessary.

Otherwise returns 1 on success, undef on failure.

The password file is locked for exclusive access before being updated.

=cut

sub setPassword {
    my ( $this, $login, $newUserPassword, $oldUserPassword ) = @_;
    ASSERT($login) if DEBUG;

    if ( defined($oldUserPassword) ) {
        unless ( $oldUserPassword eq '1' ) {
            return 0 unless $this->checkPassword( $login, $oldUserPassword );
        }
    }
    elsif ( $this->fetchPass($login) ) {
        $this->{error} = $login . ' already exists';
        return 0;
    }

    my $lockHandle;
    try {
        $lockHandle = _lockPasswdFile(LOCK_EX);

        # Read password without shared lock as we have already exclusive lock
        #  - Don't trust cache
        my $db = $this->_readPasswd( 0, 1 );

        $db->{$login}->{pass} = $this->encrypt( $login, $newUserPassword, 1 );
        $db->{$login}->{enc} = $Foswiki::cfg{Htpasswd}{Encoding};
        $db->{$login}->{realm} =
          (      $Foswiki::cfg{Htpasswd}{Encoding} eq 'md5'
              || $Foswiki::cfg{Htpasswd}{Encoding} eq 'htdigest-md5' )
          ? $Foswiki::cfg{AuthRealm}
          : '';
        $db->{$login}->{emails} ||= '';
        print STDERR
"setPassword login $login pass $db->{$login}->{pass} enc $db->{$login}->{enc} realm $db->{$login}->{realm} emails $db->{$login}->{emails}\n"
          if (TRACE);
        $this->_savePasswd($db);

    }
    catch Error with {
        my $e = shift;
        $this->{error} = $!;
        print STDERR "ERROR: failed to setPassword - $! ($e)";
        $this->{error} = 'unknown error in setPassword'
          unless ( $this->{error} && length( $this->{error} ) );
        return undef;
    }
    finally {
        _unlockPasswdFile($lockHandle) if $lockHandle;
    };

    $this->{error} = undef;
    return 1;
}

=begin TML

---++ ObjectMethod removeUser( $login ) -> $boolean

Removes the user identified by $login from the database
and saves the password file.

Returns 1 on success, undef on failure.

=cut

sub removeUser {
    my ( $this, $login ) = @_;
    my $result = undef;
    $this->{error} = undef;

    my $lockHandle;
    try {
        $lockHandle = _lockPasswdFile(LOCK_EX);

        # Read password without shared lock as we have already exclusive lock
        #  - Don't trust cache
        my $db = $this->_readPasswd( 0, 1 );
        unless ( $db->{$login} ) {
            $this->{error} = 'No such user ' . $login;
        }
        else {
            delete $db->{$login};
            $this->_savePasswd($db);
            $result = 1;
        }
    }
    catch Error with {
        my $e = shift;
        $this->{error} = $!;
        print STDERR "ERROR: failed to removeUser - $! ($e)";
        $this->{error} = 'unknown error in removeUser'
          unless ( $this->{error} && length( $this->{error} ) );
        return undef;
    }
    finally {
        _unlockPasswdFile($lockHandle) if $lockHandle;
    };

    return $result;
}

=begin TML

---++ ObjectMethod checkPassword( $login, $password ) -> $boolean

Checks the validity of $password by looking up the user in the
password file, and comparing the stored hash to the computed
hash of the supplied password.

Returns 1 on success, 0 on failure.

=cut

sub checkPassword {
    my ( $this, $login, $password ) = @_;
    my ( $pw, $entry ) = $this->fetchPass($login);

    # $pw will be 0 if there is no pw
    return 0 unless defined $pw;

    my $encryptedPassword = $this->encrypt( $login, $password, 0, $entry );
    return 0 unless ($encryptedPassword);

    $this->{error} = undef;

    #print STDERR "Checking $pw against $encryptedPassword\n" if (TRACE);

    if ( length($pw) != length($encryptedPassword) ) {

    #print STDERR "Fail on length mismatch ($pw) vs enc ($encryptedPassword)\n";
        $this->{error} = 'Invalid user/password';
        return 0;
    }
    return 1 if ( $pw && ( $encryptedPassword eq $pw ) );

    # pw may validly be '', and must match an unencrypted ''. This is
    # to allow for sysadmins removing the password field in .htpasswd in
    # order to reset the password.
    return 1 if ( defined $password && $pw eq '' && $password eq '' );

    $this->{error} = 'Invalid user/password';
    return 0;
}

=begin TML

---++ ObjectMethod isManagingEmails()  -> $boolean

Returns true if the password manager is managing emails.  This
implementaiton always returns true.

=cut

sub isManagingEmails {
    return 1;
}

=begin TML

---++ ObjectMethod getEmails($login)  -> @array

Looks up the user in the database, Returns a list of email addresses
for the user.  or returns an empty list.
=cut

sub getEmails {
    my ( $this, $login ) = @_;

    # first try the mapping cache
    # read passwords with shared lock
    my $db = $this->_readPasswd(1);
    if ( $db->{$login}->{emails} ) {
        return split( /;/, $db->{$login}->{emails} );
    }

    return;
}

=begin TML

---++ ObjectMethod setEmails($login, @emails )  -> $boolean

Sets the identified user $login to the list of @emails.

=cut

sub setEmails {
    my $this   = shift;
    my $login  = shift;
    my $emails = join( ';', @_ );
    ASSERT($login) if DEBUG;
    my $lockHandle;

    try {
        $lockHandle = _lockPasswdFile(LOCK_EX);

        # Read password without shared lock as we have already exclusive lock
        #  - Don't trust cache
        my $db = $this->_readPasswd( 0, 1 );
        unless ( $db->{$login} ) {

            # Make sure the user is in the auth system, by adding them with
            # a null password if not.
            $db->{$login}->{pass} = '';
        }

        $db->{$login}->{emails} = $emails;

        $this->_savePasswd($db);
    }
    finally {
        _unlockPasswdFile($lockHandle) if $lockHandle;
    };
    return 1;
}

=begin TML

---++ ObjectMethod findUseByEmail($email )  -> @array

Searches the password DB for users who have set this email.
and returns and array of $login identifiers. 

=cut

sub findUserByEmail {
    my ( $this, $email ) = @_;
    my $logins = [];

    $email = lc($email);

    # read passwords with shared lock
    my $db = $this->_readPasswd(1);
    while ( my ( $k, $v ) = each %$db ) {
        my %ems = map { lc($_) => 1 } split( ';', $v->{emails} );
        if ( $ems{$email} ) {
            push( @$logins, $k );
        }
    }
    return $logins;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2014 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved. TWiki Contributors
are listed in the AUTHORS file in the root of this distribution.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
