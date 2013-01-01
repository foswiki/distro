# See bottom of file for license and copyright information

# ######################################################################
# Feedback generator (AJAX responder)
# ######################################################################

use warnings;
use strict;

# Needs to be an object in order to use Visitor to traverse the UI

package Foswiki::Configure::Feedback;

use Foswiki::Configure(qw/:auth :cgi :config :feedback :keys/);

$changesDiscarded = 0;

require Foswiki::Configure::Root;
require Foswiki::Configure::Valuer;

require Foswiki::Configure::Visitor;
our @ISA = ('Foswiki::Configure::Visitor');

our $pendingChanges = 0;

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

    use Foswiki::Configure qw/:auth :cgi/;

    sub _authenticatefeedbackUI {
        my ( $action, $session, $cookie ) = @_;

        # feedback tags along with the main UI, but has a small window
        # for while login screens are being produced.

        if ( loggedIn($session) || $badLSC || $query->auth_type ) {
            refreshLoggedIn($session);

            return;
        }

        if ( ( $query->param('FeedbackRequest') || '' ) eq
            '{ConfigureGUI}{Modals}{Login}feedreq1' )
        {
            refreshSession($session);
            return;
        }

        # Allow re-authenticating

        refreshSession($session);

        # This is an unusual path, so we have some magic to perform.

        binmode STDOUT;
        _loadSiteConfig();

        my $keys = '{ConfigureGUI}{Modals}{SessionTimeout}';

        require Foswiki::Configure::UI;
        require Foswiki::Configure::Value;
        my $value = Foswiki::Configure::Value->new( 'UNKNOWN', keys => $keys );

        my $ui = Foswiki::Configure::UI->new($value);

        if ( Foswiki::Configure::UI::passwordState() eq 'PASSWORD_NOT_SET' ) {

            # Main screen or modal function will complain, so we don't want to
            # duplicate that here.
            return;
        }

        my $checker =
          Foswiki::Configure::UI::loadChecker(
            'ConfigureGUI::Modals::SessionTimeout', $ui );

        local $Foswiki::Configure::UI::feedbackEnabled = 1;

        my $html = $checker->provideFeedback( $value, 1, 'No button' );
        $html .= $checker->provideFeedback( $value, 2, 'No button' );

        Foswiki::Configure::Feedback::deliverResponse( [ $keys => $html ],
            undef );

        # Does not return
    }

    sub _actionfeedbackUI {

        #        my ( $action, $session, $cookie ) = @_;

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
    my ( $action, $session, $cookie ) = @_;
    my $query = $Foswiki::query;

    local $Foswiki::Configure::UI::feedbackEnabled = 1;

    my $valuer =
      Foswiki::Configure::Valuer->new( $Foswiki::defaultCfg, \%Foswiki::cfg );

    # Get request from CGI
    my $request = $query->param('FeedbackRequest');

    # Handle an unsaved changes request without any checking or UI

    require Foswiki::Configure::Feedback::Cart;

    my %updated;
    my $cart = Foswiki::Configure::Feedback::Cart->get($session);

    if ( $request eq '{ConfigureGUI}{Unsaved}status' ) {
        $cart->loadParams($query);
        my $modified = $valuer->loadCGIParams( $query, \%updated );
        $cart->removeParams($query);

        checkpointChanges( $session, $query, \%updated );
        deliverResponse( [], \%updated );

        # Does not return
    }

    my $this = Foswiki::Configure::Feedback->new;

    $this->{oldCfg} = _copy( \%Foswiki::cfg );

    $cart->loadParams($query);

    my $modified = $valuer->loadCGIParams( $query, \%updated );

    $pendingChanges = $modified + $cart->param;

    my $root = new Foswiki::Configure::Root();

    require Foswiki::Configure::Checkers::Introduction;
    $root->addChild( Foswiki::Configure::Checkers::Introduction->new($root) );

    use Config;

    if ( my $oscfg = $Config{osname} ) {

        # See if this platform has special detection or checking requirements
        my $osospecial = "Foswiki::Configure::Checkers::$oscfg";
        eval "require $osospecial";
        unless ($@) {
            my $os_checker = $osospecial->new($root);
            $root->addChild($os_checker) if $os_checker;
        }
    }

    Foswiki::Configure::FoswikiCfg::load( $root, !$badLSC );

    # These items don't actually exist, but are used to get Feedback
    # for modal forms and special functions.  The checkers may change
    # other items.  For convenience, we just attach these items to
    # the root section.  Note they usually don't exist in all forms.
    # Since they don't actually check anything, they all are given the
    # type of "UNKNOWN" - the main screen should never render them.

    require File::Spec;

    sub _findModals {
        my ( $keys, $path ) = @_;

        my @found;
        opendir( my $sdh, $path ) or return;
        foreach my $file ( readdir($sdh) ) {
            next if ( $file =~ /^\./ );
            $file =~ /^([\w_.-]+)$/ or next;
            $file = $1;
            my $fs = File::Spec->catdir( $path, $file );
            if ( -d $fs ) {
                $file =~ tr/-/_/;
                push @found, _findModals( "$keys\{$file}", $fs );
                next;
            }
            next
              unless ( -f File::Spec->catfile( $path, $file )
                && $file =~ /\.pm$/ );

            $file =~ /^([\w_-]+)\.pm$/ or next;
            my $mkey = $1;
            $mkey =~ tr/-/_/;
            push @found, "$keys\{$mkey}";
        }
        closedir($sdh);
        return @found;
    }
    my @GUIitems;
    foreach my $path (@INC) {
        my $libpath = File::Spec->catdir( $path,
            "Foswiki/Configure/Checkers/ConfigureGUI/Modals" );
        push @GUIitems, _findModals( '{ConfigureGUI}{Modals}', $libpath );
    }
    while ( Foswiki::sortHashkeyList(@GUIitems) ) {
        my $keys  = shift @GUIitems;
        my $value = Foswiki::Configure::Value->new(
            'UNKNOWN',
            keys => $keys,
            opts => 'H',
        );
        $root->addChild($value);
    }

    my $ui = Foswiki::_checkLoadUI( 'Root', $root );

    # Need an object to go visiting

    $this->{valuer} = $valuer;
    $this->{root}   = $root;
    $this->{fb}     = [];
    $this->{errors} = {};
    $this->{checks} = [];

    # 0 = no other; 1 = only changes; 2 = all
    $this->{checkall} = $query->param('DEBUG') ? 2 : 1;
    $this->{changed} = \%updated;

    # Decode feedback button request

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
                my $item   = shift @items;
                my $button = 1;
                die "Bad FB chain $item from $this->{request}\n"
                  unless ( $item =~ /^(\*)?(${configItemRegex})(-?\d+)?$/ );
                $this->{button} = $3 if ( defined $3 );
                $this->{request} = $2;
                $root->visit($this);
                $this->{button} = $button;

                # Deal with "must be last" items
                if ( ref( $this->{checkall} ) eq 'ARRAY' ) {
                    if ( @items && $items[-1] =~ /^\*/ ) {
                        splice( @items, -1, 0, @{ $this->{checkall} } );
                    }
                    else {
                        push @items, @{ $this->{checkall} };
                    }
                }
            }
        }
        else {
            delete $this->{fbpass};

            $root->visit($this);
        }
    }

    # Because checkers can make changes to any item, we must
    # recompute what's changed vs. what's on disk.
    # Any params in the cart are counted as changes

    $cart = Foswiki::Configure::Feedback::Cart->get($session);

    %updated = ();

    {

        package Foswiki::Configure::Feedback::Compare;

        our @ISA = (qw(Foswiki::Configure::Feedback));

        sub startVisit {
            my ( $this, $visitee ) = @_;

            return 1 unless ( $visitee->isa('Foswiki::Configure::Value') );

            delete $visitee->{_fbChanged};

            my $keys = $visitee->getKeys();
            return 1 if ( $keys =~ /^\{ConfigureGUI}/ );

            my $type = $visitee->getType();

            $this->{changed}{$keys} = 1
              unless (
                $type->equals(
                    $this->{valuer}->currentValue($visitee),
                    $this->{valuer}->defaultValue($visitee)
                )
              );

            return 1;
        }
        bless( $this, __PACKAGE__ );
    }

    if ( $changesDiscarded == 1 ) {
        %Foswiki::cfg = ( %{ _copy( $this->{oldCfg} ) } );
    }
    else {
        unless ( $changesDiscarded == -1 ) {    # unless saved
            $this->{valuer} =                   # Find changes
              Foswiki::Configure::Valuer->new( $this->{oldCfg},
                \%Foswiki::cfg );

            $root->visit($this);
        }

        $cart->removeParams($query);

        $updated{$_} = 1 foreach ( $cart->param() );

        checkpointChanges( $session, $query, \%updated );
    }

    my $fb = $this->{fb};

    # Reduce errors to those that changed and generate updates

    for my $key ( keys %{ $this->{errors} } ) {
        next if ( $key =~ m/\{ConfigureGUI}/ );

        my $old = $query->param("${key}errors");
        $old = "0 0" unless ( defined $old );
        my $new = $this->{errors}{$key};
        push @$fb, "${key}errors" => $ui->FB_GUIVAL( "${key}errors", $new )
          if ( $new ne $old );
    }

    deliverResponse( $fb, \%updated );
}

# ######################################################################
# Standard hash copy (from BasicSanity)
# ######################################################################

sub _copy {
    my $n = shift;

    return unless defined($n);

    if ( UNIVERSAL::isa( $n, 'ARRAY' ) ) {
        my @new;
        for ( 0 .. $#$n ) {
            push( @new, _copy( $n->[$_] ) );
        }
        return \@new;
    }
    elsif ( UNIVERSAL::isa( $n, 'HASH' ) ) {
        my %new;
        for ( keys %$n ) {
            $new{$_} = _copy( $n->{$_} );
        }
        return \%new;
    }
    elsif ( UNIVERSAL::isa( $n, 'Regexp' ) ) {
        return qr/$n/;
    }
    elsif ( UNIVERSAL::isa( $n, 'REF' ) || UNIVERSAL::isa( $n, 'SCALAR' ) ) {
        $n = _copy($$n);
        return \$n;
    }
    else {
        return $n;
    }
}

# ######################################################################
# checkpointChanges
# ######################################################################

sub checkpointChanges {
    my ( $session, $query, $updated ) = @_;

    require Foswiki::Configure::Feedback::Cart;

    my $cart = Foswiki::Configure::Feedback::Cart->get($session);
    $cart->update( $query, $updated );
    $cart->save($session);

    return;
}

# ######################################################################
# Deliver feedback response message
# ######################################################################

sub deliverResponse {
    my $fb      = shift;
    my $updated = shift;

    my $response;

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
#   \005 delivers data to the modal window.
#        The target and action are specified by the key.
#   \006 executes miscellaneous actions

    push @$fb,
      '{ConfigureGUI}{Unsaved}' => Foswiki::unsavedChangesNotice($updated)
      if ( $updated && ( loggedIn($session) || $badLSC || $query->auth_type ) );

    # Feedback is ordered so that commands from chained checkers execute in the
    # specified order.  Internally, checkers can produce arbitrary mixes of
    # text and command blocks.  The internal blocks contain a length field so
    # they can be separated from any text that follows.  The text segments
    # need to be coalesced into a single status window update, and the command
    # blocks converted to the wire format (without lengths.)

    while ( @$fb >= 2 ) {
        my ( $keys, $txt ) = splice( @$fb, 0, 2 );

        my $r    = Foswiki::Configure::UI::parseCheckerText($txt);
        my $cmds = $r->{cmds};
        my $text = $r->{text};

        if ( defined $text ) {
            $text = Foswiki::Configure::UI::_fbEncode($text);
            $cmds = "\001$keys\002$text$cmds"                   # FB_VALUE()
        }

        if ( defined $response ) {
            $response .= $cmds;
        }
        else {
            $response = substr( $cmds, 1 );
        }
    }
    die "Invalid feedback list\n" if (@$fb);

    $response = "\177"
      unless ( defined $response );    # no-data marker for client.

    Foswiki::htmlResponse( $response, Foswiki::NO_REDIRECT() );

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

    return 1 unless ( $visitee->isa('Foswiki::Configure::Value') );

    my $keys = $visitee->getKeys();

    # Hidden items have no status window and their checkers are never run.
    # Prevent default checkers for their type from activating and generating
    # output for missing windows.

    return 1 if ( $visitee->{hidden} && $keys !~ /^\{ConfigureGUI\}/ );

    $visitee->{errors}     = 0;
    $visitee->{warnings}   = 0;
    $visitee->{_fbChanged} = $this->{changed};    # Pass in item for checkers
    $visitee->{_fbRoot}    = $this->{root};
    $visitee->{_visitor}   = $this;

    #        my $value = $this->{valuer}->currentValue($visitee);
    if ( $this->{fbpass} ) {

        # Looking for supplier

        return 1 unless ( $keys eq $this->{request} );

        $this->defaultOptions( $visitee, $keys );

        # Found supplier, instantiate checker
        # Retain for AUDIT reruns to save load and allow audit
        # to save state

        $visitee->{_fbchecker} = my $checker = $visitee->{_fbchecker}
          || Foswiki::Configure::UI::loadChecker( $keys, $visitee );

        # Multiple checks possible in audit AUDITGROUP.  The arbitrary
        # upper bound here is simply to catch a loop where a
        # provider re-requests itself every time - or a depenency loop
        # of n checkers that has the same effect.  We should never see
        # anything like this number of visits to the same checker in a
        # single event.
        die "$keys run loop\n"
          if ( ++$this->{nrun}{$keys} > 100 );

        # See if it provides feedback.  If not, just re-check.

        my $button = $this->{button};
        if ( $checker && $button && $checker->can('provideFeedback') ) {
            push @{ $this->{checks} }, $keys;
            my ( $text, $checkall ) = eval {
                $checker->provideFeedback( $visitee, $button,
                    $this->{buttonValue} );
            };
            if ($@) {
                $text = $checker->ERROR(
"Feedback for $keys:$button failed:  check for .spec issues:  <pre>$@</pre>"
                );
                $checkall = 0;
            }

            # Return even empty strings to clear old status
            $text = '' unless ( defined $text );
            push @{ $this->{fb} }, $keys => $text;

            $this->{checkall} = $checkall || 0;
        }
        elsif ($checker) {
            push @{ $this->{checks} }, $keys;
            my $check = eval { return $checker->check($visitee); };
            if ($@) {
                $check = $checker->ERROR(
"Feedback for $keys failed: check for .spec issues:  <pre>$@</pre>"
                );
            }
            $check = '' unless ( defined $check );
            unless ( $check eq 'NOT USED IN THIS CONFIGURATION' ) {
                push @{ $this->{fb} }, $keys => $check;
            }
        }
        elsif ($button) {
            die ".spec ERROR: No source for $keys feedback\n";
        }
        $this->{errors}{$keys} = "$visitee->{errors} $visitee->{warnings}";

        return 0;    # Stop scan
    }
    else {

        # Run checkers

        return 1
          if ( $this->{checkall} == 1 && !$this->{changed}{$keys}
            || $keys eq $this->{request} );

        return 1
          if ( $keys =~ /^{ConfigureGUI}{Modals}/ );

        $this->defaultOptions( $visitee, $keys );

        $visitee->{_fbchecker} = my $checker = $visitee->{_fbchecker}
          || Foswiki::Configure::UI::loadChecker( $keys, $visitee );

        if ($checker) {
            push @{ $this->{checks} }, $keys;
            my $check = eval { return $checker->check($visitee); };
            if ($@) {
                $check = $checker->ERROR(
"Checker for $keys failed: check for .spec issues: <pre>$@</pre>"
                );
            }
            $check = '' unless ( defined $check );
            unless ( $check eq 'NOT USED IN THIS CONFIGURATION' ) {
                push @{ $this->{fb} }, $keys => $check;
            }
            $this->{errors}{$keys} = "$visitee->{errors} $visitee->{warnings}";
        }
    }

    return 1;
}

# ######################################################################
# Obtain option defaults for item from Type
# ######################################################################

sub defaultOptions {
    my $this = shift;
    my ( $visitee, $keys ) = @_;

    return if ( $visitee->{_fbDefaulted} );

    $visitee->{_fbDefaulted} = 1;

    # Get any default CHECK options from type

    my $type = $visitee->getType;
    if ( $type->can('defaultOptions') ) {
        my $opts = my $prev = $visitee->{opts} || '';
        my $updated = $type->defaultOptions(
            $keys, $opts,
            $visitee->feedback && 1,
            $visitee->getCheckerOptions && 1
        );
        if ( $updated ne $prev ) {
            $visitee->set( undef, opts => $updated );
        }
    }
    return;
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
