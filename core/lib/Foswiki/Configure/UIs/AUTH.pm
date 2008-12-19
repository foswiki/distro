# See bottom of file for license and copyright information

package Foswiki::Configure::UIs::AUTH;

use strict;

use Foswiki::Configure::UI;

use base 'Foswiki::Configure::UI';

my %nonos = (
    cfgAccess => 1,
    newCfgP   => 1,
    confCfgP  => 1,
);

sub ui {
    my ( $this, $canChangePW, $actionMess ) = @_;
    my $output = '';

    my @script     = File::Spec->splitdir( $ENV{SCRIPT_NAME} );
    my $scriptName = pop(@script);
    $scriptName =~ s/.*[\/\\]//;    # Fix for Item3511, on Win XP

    $output .= CGI::start_form( { name => 'twiki_configure', action => $scriptName, method => 'post' } );

    # Pass URL params through, except those below
    foreach my $param ( $Foswiki::query->param ) {
        next if ( $nonos{$param} );
        $output .= $this->hidden( $param, $Foswiki::query->param($param) );
        $output .= "\n";
    }

    # and add a few more
    $output .= "<div id ='twikiPassword'><div class='foswikiFormSteps'>\n";

    $output .= CGI::div( { class => 'foswikiFormStep' },
        CGI::h3('Enter the configuration password') );

    $output .= CGI::div(
        { class => 'foswikiFormStep' },
        CGI::h3( CGI::strong("Your Password:") )
          . CGI::p(
                CGI::password_field( -name=>'cfgAccess', -size =>20, -maxlength=>80, -class => 'foswikiInputField' ) 
              . '&nbsp;'
              . CGI::submit(
                -class => 'foswikiSubmit',
                -value => $actionMess
              )
          )
    );

    if ( $Foswiki::cfg{Password} ne '' ) {
        $output .= CGI::div(
            { class => 'foswikiFormStep' },
            CGI::p( CGI::strong('Forgotten your password?') )
              . CGI::p(<<'HERE') );
To reset the password, log in to the server and delete the
<code>$Foswiki::cfg{Password} = '...';</code> line from
<code>lib/LocalSite.cfg</code>
HERE
    }

    $output .= '</div><!--/foswikiFormSteps--></div><!--/twikiPassword-->';

    if ($canChangePW) {
        $output .=
          "<div id='twikiPasswordChange'><div class='foswikiFormSteps'>\n";
        $output .= '<div class="foswikiNotification" style="margin:1em;">';
        $output .= CGI::img(
            {
                width  => '16',
                height => '16',
                src    => $scriptName
                  . '?action=image;image=warning.gif;type=image/gif',
                alt => ''
            }
        );
        $output .= '&nbsp;'
          . CGI::span( { class => 'foswikiAlert' },
            CGI::strong('Notes on Security') );
        $output .= <<HERE;
<ul>
 <li>
  If you don't set a password, or the password is cracked, then
  <code>configure</code> could be used to do <strong>very</strong> nasty
  things to your server.
 </li>
 <li>
  If you are running Foswiki on a public website, you are
  <strong>strongly</strong> advised to totally disable saving from
  <code>configure</code> by making <code>lib/LocalSite.cfg</code> readonly once
  you are happy with your configuration.
 </li>
</ul>
</div><!--expanation-->
HERE

        my $submitStr = $actionMess;
        $output .= CGI::div(
            { class => 'foswikiFormStep' },
            CGI::h3(
                { class => 'foswikiFormStep' },
                'You may set a new password here:'
            )
        );
        $output .= CGI::div(
            { class => 'foswikiFormStep' },
            CGI::strong('New Password:')
              . CGI::p( CGI::password_field( -name=>'newCfgP', -size=>20, -maxlength=>80, -class => 'foswikiInputField' ) )
        );
        $output .= CGI::div(
            { class => 'foswikiFormStep' },
            CGI::strong('Confirm Password:')
              . CGI::p( CGI::password_field( -name=>'confCfgP', size=>20, -maxlength=>80, -class => 'foswikiInputField' ) )
        );
        $submitStr = 'Change Password and ' . $submitStr;
        $output .= CGI::div( { class => 'foswikiFormStep foswikiLast' },
            CGI::submit( -class => 'foswikiSubmit', -value => $submitStr ) );
        $output .=
          "</div><!--/foswikiFormSteps--></div><!--/twikiPasswordChange-->";
    }

    return $output . CGI::end_form();
}

1;
__DATA__
#
# Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008 Foswiki Contributors. All Rights Reserved.
# Foswiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
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
