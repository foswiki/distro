package Foswiki::Configure::Checkers::MSWin32;

use strict;

sub check {
    my $this = shift;

    # ActivePerl-only function: returns number if
    # successful, otherwise treated as a literal (bareword).
    my $isActivePerl = eval 'Win32::BuildNumber !~ /Win32/';

    # FIXME: Advice in this section should be reviewed and tested by people
    # using ActivePerl
    my $perl5shell = $ENV{PERL5SHELL} || '';
    my $n = $perl5shell . $this->NOTE(<<HERE);
This environment variable is used by Win32 Perls to run
commands from Foswiki scripts - it determines which shell program is used to run
commands that use 'pipes'.  Examples of shell programs are cmd.exe,
command.com (aka 'DOS Prompt'), and Cygwin's 'bash'
(<strong>recommended</strong> if Cygwin is installed).
<p>
To use 'bash' with ActiveState or other Win32 Perl you should set the
PERL5SHELL environment variable to something like
<tt><strong>c:/YOURCYGWINDIR/bin/bash.exe -c</strong></tt>
This should be set in the System Environment, and ideally set directly in the
web server (e.g. using the Apache <tt>SetEnv</tt> directive).
HERE

    if ($isActivePerl) {
        $n .= $this->WARN(<<HERE);
ActiveState Perl on IIS does not support safe pipes, which is the mechanism used by Foswiki to prevent a range
of attacks aimed at arbitrary command execution on the server. You are <b>highly</b> recommended not to use this
particular configuration on a public server (one exposed to the internet)
HERE
        if ( Win32::BuildNumber() < 631 ) {
            $n .= $this->WARN(<<HERE);
ActiveState Perl must be upgraded to at least build 631
if you are going to use PERL5SHELL, which was broken in earlier builds.
HERE
        }
    }
    return $n;
}

1;
