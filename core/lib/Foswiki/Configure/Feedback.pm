# See bottom of file for license and copyright information

# ######################################################################
# Feedback generator (AJAX responder)
# ######################################################################

# Needs to be an object in order to use Visitor to traverse the UI

package Foswiki::Configure::Feedback;

require Foswiki::Configure::Root;
require Foswiki::Configure::Valuer;

require Foswiki::Configure::Visitor;
our @ISA = ('Foswiki::Configure::Visitor');

=begin TML

The Feedback mechanism provides immediate or on-click feedback to the
configure user without re-generating the main screen.  This is accomplished
using client AJAX requests.

These can be initiated transparently or by physical buttons as directed
by the FEEDBACK option in the configuration specificaton files (or dynamically
generated UI elements).

This module contains the Feedback server.  It is loaded when an authenticated
feedback request has been received.

=cut

# Interface to dispatcher lives in Foswiki

{

    package Foswiki;

    sub _authenticatefeedbackUI {
        my ( $action, $session, $cookie ) = @_;

        # feedback tags along with the main UI, but has a small window
        # for while login screens are being produced.

        if ( loggedIn($session) ) {
            refreshLoggedIn($session);

            return;
        }

        # Do not establish a new session

        my $html =
          Foswiki::Configure::UI::getTemplateParser()
          ->readTemplate('feedbackerror');
        $html = Foswiki::Configure::UI::getTemplateParser()
          ->parse( $html, { RESOURCEURI => $resourceURI, } );
        Foswiki::Configure::UI::getTemplateParser()
          ->cleanupTemplateResidues($html);

        htmlResponse( $html, 200 );

    }

    sub _actionfeedbackUI {
        binmode STDOUT;
        _loadSiteConfig();

        return Foswiki::Configure::Feedback::deliver(@_);
    }
}

# ######################################################################
# new
# ######################################################################

sub new {
    my $class = shift;

    return bless( {}, $class );
}

# ######################################################################
# Deliver feedback
# ######################################################################

sub deliver {
    my $query = $Foswiki::query;

    my $valuer =
      new Foswiki::Configure::Valuer( $Foswiki::defaultCfg, \%Foswiki::cfg );

    my %updated;
    my $modified = $valuer->loadCGIParams( $query, \%updated );

    my $root = new Foswiki::Configure::Root();

    require Foswiki::Configure::Checkers::Introduction;
    $root->addChild( Foswiki::Configure::Checkers::Introduction->new($root) );

    if ( my $oscfg = $Config::Config{osname} ) {

        # See if this platform has special detection or checking requirements
        my $osospecial = "Foswiki::Configure::Checkers::$oscfg";
        eval "require $osospecial";
        unless ($@) {
            my $os_checker = $osospecial->new($root);
            $root->addChild($os_checker) if $os_checker;
        }
    }

    require Foswiki::Configure::CGISetup;
    $root->addChild( Foswiki::Configure::CGISetup->new($root) );

    Foswiki::Configure::FoswikiCfg::load( $root, !$badLSC );

    my $ui = Foswiki::_checkLoadUI( 'Root', $root );

    # Need an object to go visiting

    my $this = new Foswiki::Configure::Feedback;

    $this->{valuer} = $valuer;
    $this->{root}   = $root;
    $this->{fb}     = {};

    # 0 = no other; 1 = only changes; 2 = all
    $this->{checkall} = $query->param('DEBUG') ? 2 : 1;
    $this->{changed} = \%updated;

    # Get request from feedback button

    my $request = $query->param('FeedbackRequest');
    $request =~ /^(\{.*\})feedreq(\d+)$/ or die "Invalid FB target $request\n";
    $this->{request}     = $1;
    $this->{button}      = $2;
    $this->{buttonValue} = $query->param('FeedbackButtonValue');

    $this->{fbpass} = 1;

    # Walk the configuration to find the target and invoke feedback

    $root->visit($this);

    # If target wants a full check run or specific items, do it

    if ( $this->{checkall} ) {

        # Check specific list of additional items
        if ( ref( $this->{checkall} ) eq 'ARRAY' ) {
            my @items = @{ $this->{checkall} };
            while (@items) {
                $this->{checkall} = $query->param('DEBUG') ? 2 : 1;
                my $item = shift @items;
                $this->{request} = $item;
                $root->visit($this);
                push @items, @{ $this->{checkall} }
                  if ( ref( $this->{checkall} ) eq 'ARRAY' );
            }
        }
        else {
            delete $this->{fbpass};

            $root->visit($this);
        }
    }

    my $html = '';

# Return encoded responses to each responding key.
#
# Effectively join( "\001", ("$keys\002$value") ... )
#
# Protocol: (see Configur/UI.pm and Configure/resourcdes/scripts.js for
# other key players).
# Stream starts with { (a key name), or it's interpreted as an html error
# (e.g. die) that creates a pop-up.
# A null response is indicated by \177
# A stream can have an arbitrary number of packets.
#   \001 delimits data packets.
#   Each packet has a key (target) and value, delimited by \002 or \003
#   \002 is for feedback windows; these are the <div>s named {item}status
#        The content replaces the innerHTML of the <div>
#   \003 is for data sent to <input> items, targeting value, checked, or selected
#        In the case of multiple values (e.g. <select multiple>), the values are
#        delimited by \004
#   \002 can actually update any <div> named {something}status; the {ConfigureGUI}
#        namespace is reserved for such <divs>, and will not be written to LSC.

    my $fb = $this->{fb};

    # Remove any {ConfigureGUI} pseudo-keys from %updated and count the rest.

    my $pending = 0;
    foreach my $keys ( keys %updated ) {
        if ( $keys =~ /^\{ConfigureGUI\}/ ) {
            delete $updated{$keys};
        }
        else {
            $pending++;
        }
    }
    my @pendingItems = map { { item => $_->[0] } } sort {
        my @a = @{ $a->[1] };
        my @b = @{ $b->[1] };
        while ( @a && @b ) {
            my $c = shift(@a) cmp shift(@b);
            return $c if ($c);
        }
        return @a <=> @b;
      } map {
        [ $_, [ map { s/(?:^\{)|(?:\}$)//g; $_ } split( /\}\{/, $_ ) ] ]
      } keys %updated
      if (DISPLAY_UNSAVED);

    my $pendingHtml =
      Foswiki::Configure::UI::getTemplateParser()
      ->readTemplate('feedbackunsaved');
    $pendingHtml = Foswiki::Configure::UI::getTemplateParser()->parse(
        $pendingHtml,
        {
            pendingCount => $pending,
            listPending  => DISPLAY_UNSAVED,
            pendingItems => \@pendingItems,
        }
    );
    Foswiki::Configure::UI::getTemplateParser()
      ->cleanupTemplateResidues($pendingHtml);

    $fb->{'{ConfigureGUI}{Unsaved}'} = $pendingHtml;

    my $first = 1;
    foreach my $keys ( keys %$fb ) {
        my $fb = $fb->{$keys};
        $html .= "\001" unless ($first);
        if ( $fb =~ s/\A\001// ) {    # FB_FOR/FB_VALUE pre-encoded data
            $html .= $fb;
        }
        else {
            $html .= "$keys\002$fb";
        }
        undef $first;
    }
    $html .= "\177"
      if ($first);    # no-data marker for client.  Really shouldn't happen.

    Foswiki::htmlResponse( $html, Foswiki::NO_REDIRECT );

    # Does not redirect or return
}

# ######################################################################
# Visit every UI element
# ######################################################################

# Called for two passes:
#  Pass 1: Locate target item and deliver feedback
#  Pass 2: Run checkers for (other changed or all) other items (optional)
#
# Must return true to continue walk

sub startVisit {
    my ( $this, $visitee ) = @_;

    if ( $visitee->isa('Foswiki::Configure::Value') ) {
        my $keys = $visitee->getKeys();

        #        my $value = $this->{valuer}->currentValue($visitee);
        if ( $this->{fbpass} ) {

            # Looking for supplier

            return 1 unless ( $keys eq $this->{request} );

            # Found supplier, instantiate checker

            my $checker =
              Foswiki::Configure::UI::loadChecker( $keys, $visitee );
            die if ( exists $this->{fb}{$keys} );

            # See if it provides feedback.  If not, just re-check.

            if ( $checker && $checker->can('provideFeedback') ) {
                my ( $text, $checkall ) = eval {
                    $checker->provideFeedback( $visitee, $this->{button},
                        $this->{buttonValue} );
                };
                if ($@) {
                    $text = $checker->ERROR(
                        "Feedback for $keys failed:  check for .spec issues: $@"
                    );
                    $checkall = 0;
                }
                $this->{fb}{$keys} = $text if ($text);
                $this->{checkall} = $checkall || 0;
            }
            elsif ($checker) {
                my $check = eval { return $checker->check($visitee); };
                if ($@) {
                    $check = $checker->ERROR(
                        "Checker for $keys failed: check for .spec issues:$@");
                }
                unless ( !$check
                    || $check && $check eq 'NOT USED IN THIS CONFIGURATION' )
                {
                    $this->{fb}{$keys} = $check;
                }
            }
            else {
                die ".spec ERROR: No source for specified feedback for $keys\n";
            }
            return 0;    # Stop scan
        }
        else {

            # Run checkers

            return 1
              if ( $this->{checkall} == 1 && !$this->{changed}{$keys}
                || $keys eq $this->{request} );

            my $checker =
              Foswiki::Configure::UI::loadChecker( $keys, $visitee );
            if ($checker) {
                my $check = eval { return $checker->check($visitee); };
                if ($@) {
                    $check = $checker->ERROR(
                        "Checker for $keys failed: check for .spec issues:$@");
                }
                unless ( !$check
                    || $check && $check eq 'NOT USED IN THIS CONFIGURATION' )
                {
                    if ( exists $this->{b}{$keys} ) {
                        $this->{fb}{$keys} .= $check;
                    }
                    else {
                        $this->{fb}{$keys} = $check;
                    }
                }
            }
        }
    }
    return 1;
}

# ######################################################################
# End of item callback
# ######################################################################

# Nothing to do but return true

sub endVisit {
    my ( $this, $visitee ) = @_;

    return 1;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2007 TWiki Contributors. All Rights Reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
