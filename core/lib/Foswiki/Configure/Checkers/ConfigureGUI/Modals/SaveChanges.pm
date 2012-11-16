# See bottom of file for license and copyright information

use strict;
use warnings;

package Foswiki::Configure::Checkers::ConfigureGUI::Modals::SaveChanges;

use Foswiki::Configure(qw(:auth :config :util));

# Modal action checker for Save Changes.

require Foswiki::Configure::Checkers::ConfigureGUI::MODAL;
our @ISA = ('Foswiki::Configure::Checkers::ConfigureGUI::MODAL');

# Called to save configuration

sub generateForm {
    my $this = shift;
    my ( $keys, $query, $session, $template ) = @_;

    my $templateArgs = $template->getArgs;

    $template->renderButton;
    $template->renderFeedbackWindow;

    my $updated  = $this->{item}{_fbChanged};
    my $modified = keys %$updated;

    my $cart = Foswiki::Configure::Feedback::Cart->get($session);

    my $changesList = [];
    foreach my $key ( sortHashkeyList( keys %$updated ) ) {
        my $valueString = join( ',', $query->param($key) ) || '';
        push( @$changesList, { key => $key, value => $valueString } );
    }
    my @items = sortHashkeyList( keys %$updated ) if $modified;

    $template->addArgs(
        items         => \@items,
        changesList   => $changesList,
        modifiedCount => $modified,
        user          => ( $query->remote_user() || $ENV{REMOTE_USER} ),
    );
    $template->addArgs(
        displayStatus => (
            ( $cart->param('{Password}') || $modified )
            ? $MESSAGE_TYPE->{OK}
            : $MESSAGE_TYPE->{NONE}
        ),
    );

    $template->addArgs( changePassword => 1 ) if ( $cart->param('{Password}') );
    my $passwordProblem =
      ( $query->auth_type() || Foswiki::Configure::UI::passwordState() eq 'OK' )
      ? 0
      : 1;

    my ( $errors, $warnings ) = (0) x 2;
    for my $param ( $query->param ) {
        next unless ( $param =~ /^\{.*\}errors$/ );
        my $value = $query->param($param);
        if ( $value =~ /^(\d+) (\d+)$/ ) {
            $errors   += $1;
            $warnings += $2;
        }
    }
    $template->addArgs(
        totalErrors     => $errors,
        totalWarnings   => $warnings,
        passwordProblem => $passwordProblem,
        someProblems    => $errors + $warnings + $passwordProblem,
    );

    # The template is intentionally parsed twice - see MODAL.pm

    my $html = $template->extractArgs('savechanges');
    $html = Foswiki::Configure::UI::getTemplateParser()
      ->parse( $html, $templateArgs );
    $html = Foswiki::Configure::UI::getTemplateParser()
      ->parse( $html, $templateArgs );
    Foswiki::Configure::UI::getTemplateParser()->cleanupTemplateResidues($html);

    $html = $this->FB_MODAL( 'r,o', $html );

    return $html;
}

sub processForm {
    my $this = shift;
    my ( $keys, $query, $session, $template ) = @_;

    my $templateArgs = $template->getArgs;

    my $e = '';

    unless ( saveAuthorized($session) || $badLSC ) {
        ( my $ok, $e ) =
          $template->passwordRequiredForm( $query, 'savechanges' );

        return $e unless ($ok);
    }

    refreshLoggedIn($session);
    refreshSaveAuthorized($session);

    require Foswiki::Configure::Feedback::Cart;

    my $updated  = $this->{item}{_fbChanged};
    my $modified = keys %$updated;

    my $cart = Foswiki::Configure::Feedback::Cart->get($session);

    # create the root of the UI
    my $root = new Foswiki::Configure::Root();

    # Load the specs from the .spec files and generate the UI template
    Foswiki::Configure::FoswikiCfg::load( $root, 1 );

    my $ui = Foswiki::_checkLoadUI( 'UPDATE', $root );

    $ui->setInsane() if $insane;
    my $valuer =
      new Foswiki::Configure::Valuer( $Foswiki::defaultCfg, \%Foswiki::cfg );

    my $filesUpdated = $ui->commitChanges( $root, $valuer, $updated );

    undef $ui;

    my $passChanged = $cart->param('{Password}') ? 1 : 0;

    Foswiki::Configure::Feedback::Cart->empty($session);

    # This seems redundant, but I suppose some time could have elapsed
    # between the initial form and these results.  We can remove this
    # if it's annoying, but this is how the old interface worked.

    # Build list of hashes with each changed key and its value(s) for template

    my $changesList = [];
    foreach my $key ( sortHashkeyList( keys %$updated ) ) {
        my $valueString = join( ',', $query->param($key) );
        push( @$changesList, { key => $key, value => $valueString } );
    }
    push @$changesList, { key => 'No configuration items changed', value => '' }
      unless (@$changesList);

    $template->addArgs(
        modifiedCount   => $modified,
        changesList     => $changesList,
        passwordChanged => $passChanged,
        fileUpdates     => $filesUpdated,
    );
    my $html = $template->extractArgs('saveresults');
    $html = Foswiki::Configure::UI::getTemplateParser()
      ->parse( $html, $templateArgs );
    Foswiki::Configure::UI::getTemplateParser()->cleanupTemplateResidues($html);

    return $this->FB_MODAL( 'r,o', $html ) . $e;
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
