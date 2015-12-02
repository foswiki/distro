# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Sandbox

This package provides an interface to the outside world. All calls to
system functions, or handling of file names, should be brokered by
the =sysCommand= function in this package.

*Since* _date_ indicates where functions or parameters have been added since
the baseline of the API (TWiki release 4.2.3). The _date_ indicates the
earliest date of a Foswiki release that will support that function or
parameter.

*Deprecated* _date_ indicates where a function or parameters has been
[[http://en.wikipedia.org/wiki/Deprecation][deprecated]]. Deprecated
functions will still work, though they should
_not_ be called in new plugins and should be replaced in older plugins
as soon as possible. Deprecated parameters are simply ignored in Foswiki
releases after _date_.

*Until* _date_ indicates where a function or parameter has been removed.
The _date_ indicates the latest date at which Foswiki releases still supported
the function or parameter.

=cut

package Foswiki::Sandbox;

use strict;
use warnings;
use Assert;
use Error qw( :try );
use Encode;

use File::Spec ();
use File::Temp ();

use Foswiki ();

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

# Set to 1 to trace commands to STDERR, and redirect STDERR from
# the command subprocesses to /tmp/foswiki_sandbox.log
use constant TRACE => 0;

our $REAL_SAFE_PIPE_OPEN;
our $EMULATED_SAFE_PIPE_OPEN;
our $SAFE;
our $CMDQUOTE;    # leave undef until _assessPipeSupport has run

# TODO: Sandbox module should probably use custom 'die' handler so that
# output goes only to web server error log - otherwise it might give
# useful debugging information to someone developing an exploit.

# Assess pipe support for =$os=, setting flags for platform features
# that help.
sub _assessPipeSupport {

    # filter the support based on what platforms are proven not to work.

    $REAL_SAFE_PIPE_OPEN     = 1;
    $EMULATED_SAFE_PIPE_OPEN = 1;

# Detect ActiveState and Strawberry perl.   (Cygwin perl returns "cygwin" for $^O)
    if ( $^O eq 'MSWin32' ) {
        $REAL_SAFE_PIPE_OPEN     = 0;
        $EMULATED_SAFE_PIPE_OPEN = 0;
    }

    # 'Safe' means no need to filter in on this platform - check
    # sandbox status at time of filtering
    $SAFE = ( $REAL_SAFE_PIPE_OPEN || $EMULATED_SAFE_PIPE_OPEN ) ? 1 : 0;

    # Shell quoting - shell used only on non-safe platforms
    if (
        $Foswiki::cfg{OS} eq 'UNIX'
        || (   $Foswiki::cfg{OS} eq 'WINDOWS'
            && $Foswiki::cfg{DetailedOS} eq 'cygwin' )
      )
    {
        $CMDQUOTE = "'";
    }
    else {
        $CMDQUOTE = '"';
    }
}

=begin TML

---++ StaticMethod untaintUnchecked ( $string ) -> $untainted

Untaints =$string= without any checks.  If $string is
undefined, return undef.

This function doesn't perform *any* checks on the data being untainted.
Callers *must* ensure that =$string= does not contain any dangerous content,
such as interpolation characters, if it is to be used in potentially
unsafe operations.

=cut

sub untaintUnchecked {
    my ($string) = @_;

    if ( defined($string) && $string =~ m/^(.*)$/s ) {
        return $1;
    }
    return $string;
}

=begin TML

---++ StaticMethod untaint ( $datum, \&method, ... ) -> $untainted

Calls &$method($datum, ...) and if it returns a non-undef result, returns
that result after untainting it. Otherwise returns undef.

\&method can indicate a validation problem in a couple of ways. First, it
can throw an exception. Second, it can return undef, which then causes
the untaint function to return undef.

=cut

sub untaint {
    my $datum  = shift;
    my $method = shift;
    ASSERT( ref($method) ) if DEBUG;
    return $datum unless defined $datum;

    # Untaint the datum before validating it
    return undef unless $datum =~ m/^(.*)$/s;
    return &$method( $1, @_ );
}

=begin TML

---++ StaticMethod validateWebName($name) -> $web

Check that the name is valid for use as a web name. Method used for
validation with untaint(). Returns the name, or undef if it is invalid.

=cut

sub validateWebName {
    my $web = shift;
    return $web if Foswiki::isValidWebName( $web, 1 );
    return;
}

=begin TML

---++ StaticMethod validateTopicName($name) -> $topic

Check that the name is valid for use as a topic name. Method used for
validation with untaint(). Returns the name, or undef if it is invalid.

=cut

sub validateTopicName {
    my $topic = shift;
    return $topic if Foswiki::isValidTopicName( $topic, 1 );
    return;
}

=begin TML

---++ StaticMethod validateAttachmentName($name) -> $attachment

Check that the name is valid for use as an attachment name. Method used for
validation with untaint(). Returns the name, or undef if it is invalid.

Note that the name may contain path separators. This is to permit validation
of an attachment that is stored in a subdirectory somewhere under the
standard Web/Topic/attachment level e.g
Web/Topic/attachmentdir/subdir/attachment.gif. While such attachments cannot
be created via the UI, they *can* be created manually on the server.

The individual path components are filtered by $Foswiki::cfg{AttachmentNameFilter}

=cut

sub validateAttachmentName {
    my $string = shift;

    return undef unless $string;

    # Attachment names are always relative to web/topic, so leading /'s
    # are simply an expression of that root.
    $string =~ s/^\/+//;

    my @dirs = split( /\/+/, $string );
    my @result;
    foreach my $component (@dirs) {
        return undef unless defined($component) && $component ne '';
        next if $component eq '.';
        if ( $component eq '..' ) {
            if ( scalar(@result) ) {

                # path name is relative within its own length - we can
                # do that
                pop(@result);
            }
            else {

                # Illegal relative path name
                return undef;
            }
        }
        else {

            # Filter nasty characters
            $component =~ s/$Foswiki::cfg{AttachmentNameFilter}//g;
            push( @result, $component );
        }
    }

    #SMELL: there is a proper way to do this.... File::Spec
    return join( '/', @result );
}

# Validate, clean up and untaint filename passed to an external command
sub _cleanUpFilePath {
    my $string = shift;
    return '' unless defined $string;
    my ( $volume, $dirs, $file ) = File::Spec->splitpath($string);
    my @result;
    my $first = 1;
    foreach my $component ( File::Spec->splitdir($dirs) ) {
        next unless ( defined($component) && $component ne '' || $first );
        $first = 0;
        $component ||= '';
        next if $component eq '.';
        if ( $component eq '..' ) {
            throw Error::Simple( 'relative path in filename ' . $string );
        }
        elsif ( $component =~ m/$Foswiki::cfg{AttachmentNameFilter}/ ) {
            throw Error::Simple( 'illegal characters in file name component "'
                  . $component
                  . '" of filename '
                  . $string );
        }
        push( @result, $component );
    }

    if ( scalar(@result) ) {
        $dirs = File::Spec->catdir(@result);
    }
    else {
        $dirs = '';
    }
    $string = File::Spec->catpath( $volume, $dirs, $file );

    # Validated, can safely untaint
    return untaintUnchecked($string);
}

=begin TML

---++ StaticMethod normalizeFileName( $string ) -> $filename

Throws an exception if =$string= contains filtered characters, as
defined by =$Foswiki::cfg{AttachmentNameFilter}=

The returned string is not tainted, but it may contain shell
metacharacters and even control characters.

*DEPRECATED* - provided for compatibility only. Do not use!
If you want to validate an attachment, use
untaint($name, \&validateAttachmentName)

=cut

sub normalizeFileName {
    return _cleanUpFilePath(@_);
}

=begin TML

---++ StaticMethod sanitizeAttachmentName($fname) -> ($fileName, $origName)

Given a file name received in a query parameter, sanitise it. Returns
the sanitised name together with the basename before sanitisation.

Sanitation includes removal of all leading path components,
filtering illegal characters and mapping client
file names to a subset of legal server file names.

Avoid using this if you can; encoding attachment names this way is badly
broken, much better to use point-of-source validation to ensure only valid
attachment names are ever uploaded.

=cut

sub sanitizeAttachmentName {
    my $fileName = shift;    # Full pathname if browser is IE

    # Homegrown split equivalent because File::Spec functions will assume that
    # directory path is using / in UNIX and \ in Windows as defined in the HOST
    # environment.  And we don't know the client OS. Problem is specific to IE
    # which sends the full original client path when you upload files. See
    # Item2859 and Item2225 before trying again to use File::Spec functions and
    # remember to test with IE.
    # This should take care of any silly ../ shenanigans
    $fileName =~ s{[\\/]+$}{};  # Get rid of trailing slash/backslash (unlikely)
    $fileName =~ s!^.*[\\/]!!;  # Get rid of leading directory components

    my $origName = $fileName;

    # Check that on non-utf8 systems, the requested filename can be supported
    # by the store encoding.  If not supported, throw an error, rather than
    # attempting to scrub it to a usable name.
    # SMELL: This ought to be handled in Foswiki.pm.
    if (   $Foswiki::cfg{Store}{Encoding}
        && $Foswiki::cfg{Store}{Encoding} ne 'utf-8'
        && $fileName =~ m/[^[:ascii:]]+/ )
    {
        try {
            require Foswiki::Store;
            my $encoded = Foswiki::Store::encode( $fileName, 1 );
        }
        catch Error with {
            throw Foswiki::OopsException(
                'attention',
                def    => 'unsupported_filename',
                params => [
                    ( "$fileName", $Foswiki::cfg{Store}{Encoding} || 'utf-8' )
                ]
            );
        };
    }

    # Change spaces to underscore
    $fileName =~ s/ /_/g if ( $Foswiki::cfg{AttachmentReplaceSpaces} );

    # See Foswiki.pm filenameInvalidCharRegex definition and/or Item11185
    #$fileName =~ s/$Foswiki::regex{filenameInvalidCharRegex}//g;
    $fileName =~ s/$Foswiki::cfg{AttachmentNameFilter}//g;

    # Append .txt to some files
    $fileName =~ s/$Foswiki::cfg{UploadFilter}/$1\.txt/g;

    # Untaint
    $fileName = untaintUnchecked($fileName);

    return ( $fileName, $origName );
}

sub _buildCommandLine {
    my ( $template, %params ) = @_;
    my @arguments;

    $template ||= '';

    for my $tmplarg ( split /\s+/, $template ) {
        next if $tmplarg eq '';    # ignore leading/trailing whitespace

        # Split single argument into its parts.  It may contain
        # multiple substitutions.

        my @tmplarg = $tmplarg =~ m/([^%]+|%[^%]+%)/g;
        my @targs;
        for my $t (@tmplarg) {
            if ( $t =~ m/%(.*?)(?:\|([A-Z]))?%/ ) {

                # implicit untaint of template OK
                my ( $p, $flag ) = ( $1, $2 );
                if ( !exists $params{$p} ) {
                    throw Error::Simple( 'unknown parameter name ' . $p );
                }
                my $type = ref $params{$p};
                my @params;
                if ( $type eq '' ) {
                    @params = ( $params{$p} );
                }
                elsif ( $type eq 'ARRAY' ) {
                    @params = @{ $params{$p} };
                }
                else {
                    throw Error::Simple( $type . ' reference passed in ' . $p );
                }

                for my $param (@params) {
                    unless ($flag) {
                        push @targs, $param;
                        next;
                    }
                    if ( $flag eq 'U' ) {
                        push @targs, untaintUnchecked($param);
                    }
                    elsif ( $flag eq 'F' ) {
                        $param = _cleanUpFilePath($param);

                        # Some command interpreters are too stupid to deal
                        # with filenames that start with a non-alphanumeric
                        $param = "./$param" if $param =~ m/^[^\w\/\\]/;
                        push @targs, $param;
                    }
                    elsif ( $flag eq 'N' ) {

                        # Generalized number.
                        if ( $param =~ m/^([0-9A-Fa-f.x+\-]{0,30})$/ ) {
                            push @targs, $1;
                        }
                        else {
                            throw Error::Simple(
                                "invalid number argument '$param' $t");
                        }
                    }
                    elsif ( $flag eq 'S' ) {

                        # "Harmless" string. Aggressively filter-in on unsafe
                        # platforms.
                        if ( $SAFE || $param =~ m/^[-0-9A-Za-z.+_]+$/ ) {
                            push @targs, untaintUnchecked($param);
                        }
                        else {
                            throw Error::Simple(
                                "invalid string argument '$param' $t");
                        }
                    }
                    elsif ( $flag eq 'D' ) {

                        # RCS date.
                        if (
                            $param =~ m|^(\d\d\d\d/\d\d/\d\d \d\d:\d\d:\d\d)$| )
                        {
                            push @targs, $1;
                        }
                        else {
                            throw Error::Simple(
                                "invalid date argument '$param' $t");
                        }
                    }
                    else {
                        throw Error::Simple( 'illegal flag in ' . $t );
                    }
                }
            }
            else {
                push @targs, $t;
            }
        }

        # Recombine the argument if the template argument contained
        # multiple parts.

        if ( @tmplarg == 1 ) {
            push @arguments, @targs;
        }
        else {
            map { ASSERT( defined($_) ) } @targs if (DEBUG);
            push @arguments, join( '', @targs );
        }
    }

    return @arguments;
}

# Catch and redirect error reports from programs and argument processing,
# to avert the risk of exposing server paths to a hacker.
sub _safeDie {
    print STDERR $_[0];
    die
'Foswiki experienced a fatal error. Please check your webserver error logs for details.';
}

=begin TML

---++ StaticMethod sysCommand( $class, $template, %params ) -> ( $data, $exit, $stderr )

Invokes the program described by =$template=
and =%params=, and returns the output of the program and an exit code.
STDOUT is returned. STDERR is returned *if possible* (or is undef if not).
$class is ignored, and is only present for compatibility.

The caller has to ensure that the invoked program does not react in a
harmful way to the passed arguments. =sysCommand= merely
ensures that the shell does not interpret any of the passed arguments.

$template is a template command-line for the program, which contains
typed tokens that are replaced with parameter values passed in the
=sysCommand= call. For example,
<verbatim>
    my ( $output, $exit ) = Foswiki::Sandbox->sysCommand(
        $command,
        FILENAME => $filename );
</verbatim>
where =$command= is a template for the command - for example,
<verbatim>
/usr/bin/rcs -i -t-none -kb %FILENAME|F%
</verbatim>
=$template= is split at whitespace, and '%VAR%' strings contained in it
are replaced with =$params{VAR}=.  =%params= values may consist of scalars and
array references.  Array references are dereferenced and the
array elements are inserted. '%VAR%' can optionally take the form '%VAR|T%',
where FLAG is a single character type flag.  Permitted type flags are
   * =U= untaint without further checks -- dangerous,
   * =F= normalize as file name,
   * =N= generalized number,
   * =S= simple, short string,
   * =D= RCS format date

=cut

# TODO: get emulated pipes or even backticks working on ActivePerl...

sub sysCommand {
    ASSERT( scalar(@_) % 2 == 0 ) if DEBUG;
    my ( $ignore, $template, %params ) = @_;

    #local $SIG{__DIE__} = &_safeDie;

    my $data = '';    # Output
    my $handle;       # Holds filehandle to read from process
    my $exit = 0;     # Exit status of child process

    return '' unless $template;

    # Implicit untaint OK; $template is safe
    $template =~ m/^(.*?)(?:\s+(.*))?$/;
    my $path  = $1;
    my $pTmpl = $2;
    my $cmd;

    # Writing to a cache file is the only way I can find of redirecting
    # STDERR.

    # Note:  Use of the file handle $fh returned here would be safer than
    # using the file name. But it is less portable, so filename wil have to do.
    my ( $fh, $stderrCache ) = File::Temp::tempfile(
        "STDERR.$$.XXXXXXXXXX",
        DIR    => File::Spec->tmpdir(),
        UNLINK => 0
    );
    close $fh;

    # Item5449: A random key known by both parent and child.
    # Used to make it possible that the parent detects when
    # child execution fails. Child can't throw exceptions
    # cause they are separated processes, so it's up to
    # the parent.
    my $key = int( rand(255) ) + 1;

    _assessPipeSupport() unless defined $CMDQUOTE;

    # Build argument list from template
    my @args = _buildCommandLine( $pTmpl, %params );
    if ($REAL_SAFE_PIPE_OPEN) {

        # Real safe pipes, open from process directly - works
        # for most Unix/Linux Perl platforms and on Cygwin.  Based on
        # perlipc(1).

        # Note that there doesn't seem to be any way to redirect
        # STDERR when using safe pipes.

        my $pid = open( $handle, '-|' );

        throw Error::Simple( 'open of pipe failed: ' . $! ) unless defined $pid;

        if ($pid) {

            # Parent - read data from process filehandle
            local $/ = undef;    # set to read to EOF
            $data = <$handle>;
            close $handle;
            $exit = ( $? >> 8 );
            if ( $exit == $key && $data =~ m/$key: (.*)/ ) {
                throw Error::Simple("exec of $template failed: $1");
            }
        }
        else {

            # Child - run the command
            untie(*STDERR);
            open( STDERR, '>', $stderrCache )
              || die "Can't redirect STDERR: '$!'";

            unless ( exec( $path, @args ) ) {
                syswrite( STDOUT, $key . ": $!\n" );
                exit($key);
            }

            # can never get here
        }

    }
    elsif ($EMULATED_SAFE_PIPE_OPEN) {

        # Safe pipe emulation mostly on Windows platforms

        # Create pipe
        my $readHandle;
        my $writeHandle;

        pipe( $readHandle, $writeHandle )
          || throw Error::Simple( 'could not create pipe: ' . $! );

        my $pid = fork();
        throw Error::Simple( 'fork() failed: ' . $! ) unless defined($pid);

        if ($pid) {

            # Parent - read data from process filehandle and remove newlines

            close($writeHandle) or die;

            local $/ = undef;    # set to read to EOF
            $data = <$readHandle>;
            close($readHandle);
            $pid = wait;    # wait for child process so we can get exit status
            $exit = ( $? >> 8 );
            if ( $exit == $key && $data =~ m/$key: (.*)/ ) {
                throw Error::Simple( 'exec failed: ' . $1 );
            }

        }
        else {

            # Child - run the command, stdout to pipe

            # close the read side of the pipe and streams inherited from parent
            close($readHandle) || die;

            # Despite documentation apparently to the contrary, closing
            # STDOUT first makes the subsequent open useless. So don't.
            # When running tests -log, then STDOUT is tied to an object
            # that tees the output. Unfortunately, what we need here is a plain
            # file handle, so we need to make sure we untie it. untie is a
            # NOP if STDOUT is not tied.
            untie(*STDOUT);
            untie(*STDERR);

            open( STDOUT, ">&=", fileno($writeHandle) ) or die;

            open( STDERR, '>', $stderrCache )
              || die "Can't kill STDERR: $!";

            unless ( exec( $path, @args ) ) {
                syswrite( STDOUT, $key . ": $!\n" );
                exit($key);
            }

            # can never get here
        }

    }
    else {

        # No safe pipes available, use the shell as last resort (with
        # earlier filtering in unless administrator forced filtering out)

        # This appears to be the only way to get ActiveStatePerl working
        # Escape the cmd quote using \
        if ( $CMDQUOTE eq '"' ) {

            # DOS shell :-( Tried dozens of ways of trying to get the quotes
            # right, but it just won't play nicely
            $cmd = $path . ' "' . join( '" "', @args ) . '"';
        }
        else {
            $cmd =
                $path . ' '
              . $CMDQUOTE
              . join(
                $CMDQUOTE . ' ' . $CMDQUOTE,
                map { s/$CMDQUOTE/\\$CMDQUOTE/g; $_ } @args
              ) . $CMDQUOTE;
        }

        if (   ( $Foswiki::cfg{DetailedOS} eq 'MSWin32' )
            && ( length($cmd) > 8191 ) )
        {

      #heck, on pre WinXP its only 2048 - http://support.microsoft.com/kb/830473
            print STDERR
              "WARNING: Sandbox::sysCommand commandline probably too long ("
              . length($cmd) . ")\n";
            ASSERT( length($cmd) < 8191 ) if DEBUG;
        }

        open( my $oldStderr, '>&STDERR' ) || die "Can't steal STDERR: $!";

        open( STDERR, '>', $stderrCache )
          || die "Can't redirect STDERR: $!";

        $data = `$cmd`;

        # restore STDERR
        close(STDERR);
        open( STDERR, '>&', $oldStderr ) || die "Can't restore STDERR: $!";
        close($oldStderr);

        $exit = ( $? >> 8 );

        # Do *not* return the error message; it contains sensitive path info.
        print STDERR "\n$cmd failed: $exit\n" if ( TRACE && $exit );
    }

    if (TRACE) {
        $cmd ||=
            $path . ' '
          . $CMDQUOTE
          . join( $CMDQUOTE . ' ' . $CMDQUOTE, @args )
          . $CMDQUOTE;
        $data ||= '';
        print STDERR $cmd, ' -> ', $data, "\n";
    }

    my $stderr;
    if ( open( $handle, '<', $stderrCache ) ) {
        local $/;
        $stderr = <$handle>;
        close($handle);
    }
    unlink($stderrCache);

    return ( $data, $exit, $stderr );
}

1;
__END__
Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. All Rights Reserved.
Foswiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2004-2007 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.
Copyright (C) 2004 Florian Weimer, Crawford Currie http://c-dot.co.uk

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
