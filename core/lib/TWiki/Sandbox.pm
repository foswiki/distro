# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2004 Florian Weimer, Crawford Currie http://c-dot.co.uk
# Copyright (C) 2004-2007 TWiki Contributors. All Rights Reserved.
# TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
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

=pod

---+ package TWiki::Sandbox

This object provides an interface to the outside world. All calls to
system functions, or handling of file names, should be brokered by
this object.

NOTE: TWiki creates a singleton sandbox that is *shared* by all TWiki
runs under a single mod_perl instance. If any TWiki run modifies the
sandbox, that modification will carry over in to subsequent runs.
Be very, very careful!

=cut

package TWiki::Sandbox;

use strict;
use Assert;
use Error qw( :try );

require File::Spec;

require TWiki;

# Set to 1 to trace commands to STDERR
sub TRACE { 0 }

# TODO: Sandbox module should probably use custom 'die' handler so that
# output goes only to web server error log - otherwise it might give
# useful debugging information to someone developing an exploit.

=pod

---++ ClassMethod new( $os, $realOS )

Construct a new sandbox suitable for $os, setting
flags for platform features that help.  $realOS distinguishes
Perl variants on platforms such as Windows.

=cut

sub new {
    my ( $class, $os, $realOS ) = @_;
    my $this = bless( {}, $class );

    ASSERT( defined $os ) if DEBUG;
    ASSERT( defined $realOS ) if DEBUG;

    $this->{REAL_SAFE_PIPE_OPEN} = 1;     # supports open(FH, '-|")
    $this->{EMULATED_SAFE_PIPE_OPEN} = 1; # supports pipe() and fork()

    # filter the support based on what platforms are proven
    # not to work.
    #from the Activestate Docco this is _only_ defined on ActiveState Perl
    if( defined( &Win32::BuildNumber )) {	
         $this->{REAL_SAFE_PIPE_OPEN} = 0;
         $this->{EMULATED_SAFE_PIPE_OPEN} = 0;
    }

    # 'Safe' means no need to filter in on this platform - check 
    # sandbox status at time of filtering
    $this->{SAFE} = ($this->{REAL_SAFE_PIPE_OPEN} ||
                       $this->{EMULATED_SAFE_PIPE_OPEN});

    # Shell quoting - shell used only on non-safe platforms
    if ($os eq 'UNIX' or ($os eq 'WINDOWS' and $realOS eq 'cygwin'  ) ) {
        $this->{CMDQUOTE} = '\'';
    } else {
        $this->{CMDQUOTE} = '"';
    }

    return $this;
};

=begin twiki

---++ ObjectMethod finish()
Break circular references.

=cut

# Note to developers; please undef *all* fields in the object explicitly,
# whether they are references or not. That way this method is "golden
# documentation" of the live fields in the object.
sub finish {
    my $this = shift;
}

=pod

---++ StaticMethod untaintUnchecked ( $string ) -> $untainted

Untaints $string without any checks (dangerous).  If $string is
undefined, return undef.

The intent is to use this routine to be able to find all untainting
places using grep.

=cut

sub untaintUnchecked {
    my ( $string ) = @_;

    if ( defined( $string) && $string =~ /^(.*)$/ ) {
        return $1;
    }
    return $string;            # Can't happen.
}

=pod

---++ StaticMethod normalizeFileName( $string ) -> $filename

Errors out if $string contains filtered characters.

The returned string is not tainted, but it may contain shell
metacharacters and even control characters.

=cut

sub normalizeFileName {
    my ($string) = @_;
    return '' unless $string;
    my ($volume, $dirs, $file) = File::Spec->splitpath($string);
    my @result;
    my $first = 1;
    foreach my $component (File::Spec->splitdir($dirs)) {
        next unless (defined($component) && $component ne '' || $first);
        $first = 0;
        $component ||= '';
        next if $component eq '.';
        if ($component eq '..') {
            throw Error::Simple( 'relative path in filename '.$string );
        } elsif ($component =~ /$TWiki::cfg{NameFilter}/) {
            throw Error::Simple( 'illegal characters in file name component '.
                                   $component.' of filename '.$string );
        }
        push(@result, $component);
    }

    if (scalar(@result)) {
        $dirs = File::Spec->catdir(@result);
    } else {
        $dirs = '';
    }
    $string = File::Spec->catpath($volume, $dirs, $file);

    # We need to untaint the string explicitly.
    # FIXME: This might be a Perl bug.
    return untaintUnchecked($string);
}

=pod

---++ StaticMethod sanitizeAttachmentName($fname) -> ($fileName, $origName)

Given a file name received in a query parameter, sanitise it. Returns
the sanitised name together with the basename before sanitisation.

Sanitisation includes filtering illegal characters and mapping client
file names to legal server names.

=cut

sub sanitizeAttachmentName {
    my $fileName = shift;		# Full pathname if browser is IE
    
    # Homegrown split equivalent because File::Spec functions will assume that
    # directory path is using / in UNIX and \ in Windows as defined in the HOST
    # environment.  And we don't know the client OS. Problem is specific to IE
    # which sends the full original client path when you upload files. See
    # Item2859 and Item2225 before trying again to use File::Spec functions and
    # remember to test with IE.  
    $fileName =~ s{[\\/]+$}{};		# Get rid of trailing slash/backslash (unlikely)
    $fileName =~ s!^.*[\\/]!!;		# Get rid of directory part

    my $origName = $fileName;
    # Change spaces to underscore
    $fileName =~ s/ /_/go;
    # Strip dots and slashes at start
    # untaint at the same time
    $fileName =~ s/^([\.\/\\]*)*(.*?)$/$2/go;

    if ( $TWiki::cfg{UseLocale} ) {
	# Filter out (less secure) only if using locales
	# TODO: Make this use filtering in, using locales or full Codev.UnicodeSupport
	$fileName =~ s/$TWiki::cfg{NameFilter}//goi;
    } else {
    	# No I18N, so just filter in alphanumeric etc 
	$fileName =~ s/$TWiki::regex{filenameInvalidCharRegex}//g;
    }

    # Append .txt to some files
    $fileName =~ s/$TWiki::cfg{UploadFilter}/$1\.txt/goi;
    
    # Untaint
    $fileName = untaintUnchecked($fileName);

    return ($fileName, $origName);
}

# $template is split at whitespace, and '%VAR%' strings contained in it
# are replaced with $params{VAR}.  %params may consist of scalars and
# array references as values.  Array references are dereferenced and the
# array elements are inserted into the command line at the indicated
# point.
#
# '%VAR%' can optionally take the form '%VAR|FLAG%', where FLAG is a
# single character flag.  Permitted flags are
#   * U untaint without further checks -- dangerous,
#   * F normalize as file name,
#   * N generalized number,
#   * S simple, short string,
#   * D rcs format date

sub _buildCommandLine {
    my ($this, $template, %params) = @_;
    my @arguments;

    $template ||= '';

    for my $tmplarg (split /\s+/, $template) {
        next if $tmplarg eq ''; # ignore leading/trailing whitespace

        # Split single argument into its parts.  It may contain
        # multiple substitutions.

        my @tmplarg = $tmplarg =~ /([^%]+|%[^%]+%)/g;
        my @targs;
        for my $t (@tmplarg) {
            if ($t =~ /%(.*?)(|\|[A-Z])%/) {
                my ($p, $flag) = ($1, $2);
                if (! exists $params{$p}) {
                    throw Error::Simple( 'unknown parameter name '.$p );
                }
                my $type = ref $params{$p};
                my @params;
                if ($type eq '') {
                    @params = ($params{$p});
                } elsif ($type eq 'ARRAY') {
                    @params =  @{$params{$p}};
                } else {
                    throw Error::Simple( $type.' reference passed in '.$p );
                }

                for my $param (@params) {
                    unless ($flag) {
                        push @targs, $param;
                        next;
                    }
                    if ($flag =~ /U/) {
                        push @targs, untaintUnchecked($param);
                    } elsif ($flag =~ /F/) {
                        $param = normalizeFileName($param);
                        $param = "./$param" if $param =~ /^-/;
                        push @targs, $param;
                    } elsif ($flag =~ /N/) {
                        # Generalized number.
                        if ( $param =~ /^([0-9A-Fa-f.x+\-]{0,30})$/ ) {
                            push @targs, $1;
                        } else {
                            throw Error::Simple( "invalid number argument '$param' $t" );
                        }
                    } elsif ($flag =~ /S/) {
                        # "Harmless" string. Aggressively filter-in on unsafe
                        # platforms.
                        if( $this->{SAFE} || $param =~ /^[-0-9A-Za-z.+_]+$/ ) {
                            push @targs, untaintUnchecked( $param );
                        } else {
                            throw Error::Simple( "invalid string argument '$param' $t" );
                        }
                    } elsif ($flag =~ /D/) {
                        # RCS date.
                        if ( $param =~ m|^(\d\d\d\d/\d\d/\d\d \d\d:\d\d:\d\d)$| ) {
                            push @targs, $1;
                        } else {
                            throw Error::Simple( "invalid date argument '$param' $t" );
                        }
                    } else {
                        throw Error::Simple( 'illegal flag in '.$t );
                    }
                }
            } else {
                push @targs, $t;
            }
        }

        # Recombine the argument if the template argument contained
        # multiple parts.

        if (@tmplarg == 1) {
            push @arguments, @targs;
        } else {
            map { ASSERT(defined($_)) } @targs if( DEBUG );
            push @arguments, join ('', @targs);
        }
    }

    return @arguments;
}

# Catch and redirect error reports from programs and argument processing,
# to avert the risk of exposing server paths to a hacker.
sub _safeDie {
    print STDERR $_[0];
    die "TWiki experienced a fatal error. Please check your webserver error logs for details."
}

=pod

---++ ObjectMethod sysCommand( $template, @params ) -> ( $data, $exit )

Invokes the program described by $template
and @params, and returns the output of the program and an exit code.
STDOUT is returned. STDERR is THROWN AWAY.

The caller has to ensure that the invoked program does not react in a
harmful way to the passed arguments.  sysCommand merely
ensures that the shell does not interpret any of the passed arguments.

=cut

# TODO: get emulated pipes or even backticks working on ActivePerl...

sub sysCommand {
    ASSERT(scalar(@_) % 2 == 0) if DEBUG;
    my ($this, $template, %params) = @_;

    #local $SIG{__DIE__} = &_safeDie;

    my $data = '';          # Output
    my $handle;             # Holds filehandle to read from process
    my $exit = 0;           # Exit status of child process

    return '' unless $template;

    $template =~ /(^.*?)\s+(.*)$/;
    my $path = $1;
    my $pTmpl = $2;
    my $cmd;
    my $cq = $this->{CMDQUOTE};

    # Item5449: A random key known by both parent and child. 
    # Used to make it possible that the parent detects when
    # child execution fails. Child can't throw exceptions
    # cause they are separated processes, so it's up to
    # the parent.
    my $key = int(rand(255)) + 1;

    # Build argument list from template
    my @args = _buildCommandLine( $this, $pTmpl, %params );
    if ( $this->{REAL_SAFE_PIPE_OPEN} ) {
        # Real safe pipes, open from process directly - works
        # for most Unix/Linux Perl platforms and on Cygwin.  Based on
        # perlipc(1).

        # Note that there doesn't seem to be any way to redirect
        # STDERR when using safe pipes.

        my $pid = open($handle, '-|');

        throw Error::Simple( 'open of pipe failed: '.$! ) unless defined $pid;

        if ( $pid ) {
            # Parent - read data from process filehandle
            local $/ = undef; # set to read to EOF
            $data = <$handle>;
            close $handle;
            $exit = ( $? >> 8 );
            if ( $exit == $key && $data =~ /$key: (.*)/ ) {
                throw Error::Simple( 'exec failed: '. $1 );
            }
        } else {
            # Child - run the command
            untie(*STDERR);
            open (STDERR, '>'.File::Spec->devnull()) || die "Can't kill STDERR: '$!'";
            unless ( exec( $path, @args ) ) {
                syswrite(STDOUT, $key . ": $!\n");
                exit($key);
            }
            # can never get here
        }

    } elsif ( $this->{EMULATED_SAFE_PIPE_OPEN} ) {
        # Safe pipe emulation mostly on Windows platforms

        # Create pipe
        my $readHandle;
        my $writeHandle;

        pipe( $readHandle, $writeHandle ) ||
          throw Error::Simple( 'could not create pipe: '.$! );

        my $pid = fork();
        throw Error::Simple( 'fork() failed: '.$! ) unless defined( $pid );

        if ( $pid ) {
            # Parent - read data from process filehandle and remove newlines

            close( $writeHandle ) or die;

            local $/ = undef; # set to read to EOF
            $data = <$readHandle>;
            close( $readHandle );
            $pid = wait; # wait for child process so we can get exit status
            $exit = ( $? >> 8 );
            if ( $exit == $key && $data =~ /$key: (.*)/ ) {
                throw Error::Simple( 'exec failed: '. $1 );
            }

        } else {
            # Child - run the command, stdout to pipe

            # close the read side of the pipe and streams inherited from parent
            close( $readHandle ) || die;

            # Despite documentation apparently to the contrary, closing
            # STDOUT first makes the subsequent open useless. So don't.
            # When running tests -log, then STDOUT is tied to an object
            # that tees the output. Unfortunately, what we need here is a plain
            # file handle, so we need to make sure we untie it. untie is a
            # NOP if STDOUT is not tied.
            untie(*STDOUT);
            untie(*STDERR);

            open(STDOUT, ">&=".fileno( $writeHandle )) or die;

            open (STDERR, '>'.File::Spec->devnull());
            unless ( exec( $path, @args ) ) {
                syswrite(STDOUT, $key . ": $!\n");
                exit($key);
            }
            # can never get here
        }

    } else {
        # No safe pipes available, use the shell as last resort (with
        # earlier filtering in unless administrator forced filtering out)

        # This appears to be the only way to get ActiveStatePerl working
        # Escape the cmd quote using \
        if ($cq eq '"') {
            # DOS shell :-( Tried dozens of ways of trying to get the quotes
            # right, but it just won't play nicely
            $cmd = $path.' "'.join('" "', @args).'"';
        } else {
            $cmd = $path.' '.$cq.
              join($cq.' '.$cq, map { s/$cq/\\$cq/g; $_ } @args).$cq;
        }
        

        if (($TWiki::cfg{DetailedOS} eq 'MSWin32') && 
            (length($cmd) > 8192)) {
            #heck, on pre WinXP its only 2048 - http://support.microsoft.com/kb/830473
            print STDERR "WARNING: Sandbox::sysCommand commandline probably too long (".length($cmd).")\n";
        }
        
        open( OLDERR, '>&STDERR' ) || die "Can't steal STDERR: $!";
        open( STDERR, '>'.File::Spec->devnull());
        $data = `$cmd`;
        # restore STDERR
        close( STDERR );
        open( STDERR, '>&OLDERR' ) || die "Can't restore STDERR: $!";
        close(OLDERR);

        $exit = ( $? >> 8 );
        # Do *not* return the error message; it contains sensitive path info.
        print STDERR "\n$cmd failed: $exit\n" if (TRACE && $exit);
    }

    if( TRACE ) {
        $cmd ||= $path.' '.$cq.join($cq.' '.$cq, @args).$cq;
        $data ||= '';
        print STDERR $cmd,' -> ',$data,"\n";
    }
    return ( $data, $exit );
}

1;
