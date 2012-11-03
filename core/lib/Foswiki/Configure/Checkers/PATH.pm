# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::PATH;

# Default checker for PATH items
#
# CHECK options in spec file
#  CHECK="option option:val option:val,val,val"
#    guess:dir,rootkey,silent - guess  value
#          dir = subdirectory name to guess
#          rootkey = {key} under which to place dir (install root is default)
#          silent = directory need not exist
#    perms:code - validate tree permissions using code (default is no check)
#                 See Checker::checkTreePerms (current codes: rwxdfp)
#    filter:'regex' - Files to exclude.  Note nested quotes mean \ is \\, e.g.
#                     filter:'\\\\.pl$' (CHECK="" => '\\.pl$'; filter: => \.pl$
#                     which filters by file extension.)
#
# An item can have multiple CHECK requirements, e.g. with different filters.
#
# Use this checker if possible; otherwise subclass the item-specific checker from it.

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

sub check {
    my $this   = shift;
    my $valobj = shift;

    my $keys = $valobj->getKeys();

    my $e = '';

    $e = $this->NOTE("Please click the Validate button to test this path")
      unless ( $this->{FeedbackProvided} || !$this->{item}->feedback );

    my @optionList = $this->parseOptions();

    my $guessed;
    foreach my $opts (@optionList) {
        my $guess = $opts->{guess};
        if ($guess) {
            $guessed = 1;
            my ( $dir, $rootkey, $silent ) = @$guess;
            return $this->ERROR(".spec error: no guess") unless ($dir);
            $e .= $this->guessDirectory( $keys, $rootkey, $dir, $silent );
        }
    }

    my $value = $this->getItemCurrentValue();
    if ( $guessed && $e =~ /I guessed this/ ) {
        $this->{GuessedValue} = $value;
    }

    $e .= $this->warnAboutWindowsBackSlashes($value);

    $e = $this->showExpandedValue($value) . $e
      unless ( $this->{GuessedValue} );

    if ( !$this->{item}->feedback && !$this->{FeedbackProvided} ) {

        # There is no feedback configured for this item, so do any
        # specified tests in the checker (not a good thing).

        $e .= $this->provideFeedback( $valobj, 0, 'No Feedback' );
    }

    return $e;
}

sub provideFeedback {
    my $this = shift;
    my ( $valobj, $button, $label ) = @_;

    $this->{filecount}        = 0;
    $this->{fileErrors}       = 0;
    $this->{excessPerms}      = 0;
    $this->{misingFile}       = 0;
    $this->{FeedbackProvided} = 1;

    # Normally, we call check first, but not if called by check.

    my $e = $button ? $this->check($valobj) : '';

    delete $this->{FeedbackProvided};

    my $e2 = '';

    my $keys = $valobj->getKeys();

    my @optionList = $this->parseOptions();

    foreach my $opts (@optionList) {
        my $perms  = $opts->{perms};
        my $filter = $opts->{filter}[0];

        if ($perms) {
            my $checkPerms = $perms->[0];
            $checkPerms =~ s/d//g if ( $Foswiki::cfg{OS} eq 'WINDOWS' );

            $e2 .=
              $this->checkTreePerms( $this->getCfg($keys), $checkPerms,
                $filter );
        }
    }

    if ( $this->{filecount} >= $Foswiki::cfg{PathCheckLimit} ) {
        $e .= $this->NOTE(
"File checking limit $Foswiki::cfg{PathCheckLimit} reached, checking stopped - see expert options"
        );
    }
    else {
        $e .= $this->NOTE("File count: $this->{filecount} ");
    }

    my $dperm = sprintf( '%04o', $Foswiki::cfg{RCS}{dirPermission} );
    my $fperm = sprintf( '%04o', $Foswiki::cfg{RCS}{filePermission} );

    if ( $this->{fileErrors} ) {
        my $insufficientMsg =
          $this->{fileErrors} == 1
          ? "$this->{fileErrors} directory or file has insufficient permissions."
          : "$this->{fileErrors} directories or files have insufficient permissions.";

        $e .= $this->ERROR(<<ERRMSG)
$insufficientMsg Insufficient permissions
could prevent Foswiki or the web server from accessing or updating the files.
<p>Verify that the Store expert settings of {RCS}{filePermission} ($fperm) and {RCS}{dirPermission} ($dperm)
are set correctly for your environment and correct the file permissions listed below.
ERRMSG
    }

    if ( $this->{missingFile} ) {
        my $missingMsg =
          $this->{missingFile} == 1
          ? "$this->{missingFile} file is missing."
          : "$this->{missingFile} files are missing.";
        $e .= $this->WARN(<<PREFS)
This warning can be safely ignored in many cases.  The web directories have been checked for a $Foswiki::cfg{WebPrefsTopicName} topic and $missingMsg
If this file is missing, Foswiki will not recognize the directory as a Web and the contents will not be 
accessible to Foswiki.  This is expected with some extensions and might not be a problem. <br /><br />Verify whether or not each directory listed as missing $Foswiki::cfg{WebPrefsTopicName} is
intended to be a web.  If Foswiki web access is desired, copy in a $Foswiki::cfg{WebPrefsTopicName} topic.
PREFS
    }

    if ( $this->{excessPerms} ) {
        $e .= $this->WARN(<< "PERMS");
$this->{excessPerms} or more directories appear to have more access permission than requested in the Store configuration.
<p>Excess permissions might allow other users on the web server to have undesired access to the files.
<p>Verify that the Store expert settings of {RCS}{filePermission} ($fperm} and {RCS}{dirPermission}) ($dperm})
are set correctly for your environment and correct the file permissions listed below.  (Files were not checked for
excessive permissions.)
PERMS
    }

    $e .= $this->NOTE(
        '<b>First 10 detected errors of inconsistent permissions</b> <br/> '
          . $e2 )
      if $e2;

    $this->{filecount}   = 0;
    $this->{fileErrors}  = 0;
    $this->{excessPerms} = 0;

    if ( $this->{GuessedValue} ) {
        $e .= $this->FB_VALUE( $keys, ( delete $this->{GuessedValue} || '' ) );
    }

    return wantarray ? ( $e, 0 ) : $e;
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
