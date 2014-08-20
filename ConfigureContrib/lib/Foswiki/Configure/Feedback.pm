# See bottom of file for license and copyright information

# ######################################################################
# Feedback generator (AJAX responder)
# ######################################################################

use warnings;
use strict;

# Needs to be an object in order to use Visitor to traverse the UI

package Foswiki::Configure::Feedback;

use Foswiki::Configure ();#(qw/:auth :cgi :config :feedback :keys/);

$Foswiki::Configure::changesDiscarded = 0;

require Foswiki::Configure::Root;
require Foswiki::Configure::Valuer;
use Foswiki::Configure::Load ();

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

    use Foswiki::Configure ();#qw/:auth :cgi/;

    sub _authenticatefeedbackUI {
        my ( $action, $session, $cookie ) = @_;

        # feedback tags along with the main UI, but has a small window
        # for while login screens are being produced.

        if ( loggedIn($session) || $Foswiki::Configure::badLSC || $Foswiki::Configure::query->auth_type ) {
            refreshLoggedIn($session);

            return;
        }

        if ( ( $Foswiki::Configure::query->param('FeedbackRequest') || '' ) eq
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

        $ui->{keys} = $keys;
        my $feedbacker = Foswiki::Configure::UI::loadFeedbacker( $ui );

        local $Foswiki::Configure::UI::feedbackEnabled = 1;

        my $html = $feedbacker->provideFeedback( 1, 'No button' );
        $html .= $feedbacker->provideFeedback( 2, 'No button' );

        _deliverResponse( [ $keys => $html ],
            undef );

        # Does not return
    }

    sub _actionfeedbackUI {

        #        my ( $action, $session, $cookie ) = @_;

        binmode STDOUT;

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

    local $Foswiki::Configure::UI::feedbackEnabled = 1;

    Foswiki::_loadSiteConfig();

    die "SUCK DICK" unless $Foswiki::cfg{DefaultUrlHost};
    my $valuer = Foswiki::Configure::Valuer->new( \%Foswiki::cfg );

    # Get request from CGI
    my $request = $Foswiki::Configure::query->param('FeedbackRequest');

    # Handle an unsaved changes request without any checking or UI

    require Foswiki::Configure::Feedback::Cart;

    my %updated;
    my $cart = Foswiki::Configure::Feedback::Cart->get($session);

    if ( $request eq '{ConfigureGUI}{Unsaved}status' ) {
        $cart->loadParams($Foswiki::Configure::query);
        my $modified = $valuer->loadCGIParams( $Foswiki::Configure::query, \%updated );
        $cart->removeParams($Foswiki::Configure::query);

        checkpointChanges( $session, $Foswiki::Configure::query, \%updated );
        _deliverResponse( [], \%updated );

        # Does not return
    }

    my $this = Foswiki::Configure::Feedback->new;

    $this->{oldCfg} = _copy( \%Foswiki::cfg );

    $cart->loadParams($Foswiki::Configure::query);

    my $modified = $valuer->loadCGIParams( $Foswiki::Configure::query, \%updated );

    $pendingChanges = $modified + $cart->param;

    my $root = loadConfig($session);

    my $ui = Foswiki::_checkLoadUI( 'Root', $root );

    # Need an object to go visiting

    $this->{valuer} = $valuer;
    $this->{root}   = $root;
    $this->{fb}     = [];
    $this->{errors} = {};
    $this->{checks} = [];

    # 0 = no other; 1 = only changes; 2 = all
    $this->{checkall} = $Foswiki::Configure::query->param('DEBUG') ? 2 : 1;
    $this->{changed} = \%updated;

    # Decode feedback button request

    $request =~ /^(\{.*\})feedreq(\d+)$/ or die "Invalid FB target $request\n";
    $this->{request}     = $1;
    $this->{button}      = $2;
    $this->{buttonValue} = $Foswiki::Configure::query->param('FeedbackButtonValue');

    $this->{fbpass} = 1;

    # Walk the configuration to find the target and invoke feedback

    $root->visit($this);

    # If target wants a full check run or specific items, do it

    if ( $this->{checkall} ) {

        # Check specific list of additional items
        if ( ref( $this->{checkall} ) eq 'ARRAY' ) {
            my @items = @{ $this->{checkall} };
            while (@items) {
                $this->{checkall} = $Foswiki::Configure::query->param('DEBUG') ? 2 : 1;
                my $item   = shift @items;
                my $button = 1;
                die "Bad FB chain $item from $this->{request}\n"
                  unless ( $item =~
                    /^(\*)?(${Foswiki::Configure::Load::ITEMREGEX})(-?\d+)?$/ );
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

            my $keys = $visitee->{keys};
            return 1 if ( $keys =~ /^\{ConfigureGUI}/ );

            my $type =
              Foswiki::Configure::TypeUI::load( $visitee->{typename},
                $visitee->{keys} );

            $this->{changed}{$keys} = 1
              unless (
                $type->equals(
                    $this->{valuer}->currentValue($visitee),
                    eval { $visitee->{default} }
                )
              );

            return 1;
        }
        bless( $this, __PACKAGE__ );
    }

    if ( $Foswiki::Configure::changesDiscarded == 1 ) {
        %Foswiki::cfg = ( %{ _copy( $this->{oldCfg} ) } );
    }
    else {

        unless ( $Foswiki::Configure::changesDiscarded == -1 ) {    # unless saved
            $this->{valuer} =                   # Find changes
              Foswiki::Configure::Valuer->new( {} );

            $root->visit($this);
        }

        $cart->removeParams($Foswiki::Configure::query);

        $updated{$_} = 1 foreach ( $cart->param() );

        checkpointChanges( $session, $Foswiki::Configure::query, \%updated );
    }

    my $fb = $this->{fb};

    # Reduce errors to those that changed and generate updates

    for my $key ( keys %{ $this->{errors} } ) {
        next if ( $key =~ m/\{ConfigureGUI}/ );

        my $old = $Foswiki::Configure::query->param("${key}errors");
        $old = "0 0" unless ( defined $old );
        my $new = $this->{errors}{$key};
        push @$fb, "${key}errors" => $ui->FB_GUIVAL( "${key}errors", $new )
          if ( $new ne $old );
    }

    _deliverResponse( $fb, \%updated );
}

# ######################################################################
# Obtain the current configuration data
# ######################################################################

sub loadConfig {
    my ($session) = @_;

    # Obtains a version of the UI model adequate for feedback.
    #
    # Returns a cached copy if possible.
    #
    # Otherwise, removes descriptions and GUI information that
    # is not needed.  Stores a copy in $session so it doesn't
    # need to be recompute on every feedback action.

    # Need an efficient mechanism that can validate cached copy
    # Depends on .spec files (and .pms.)  Need to check directories for
    # spec adds/deletes.
    # LoadSpec load => find, load.  Dir mtimes.?
    #
    # Saves about 250 msec - probably not worth the complexity...

    my $root;

    #print STDERR "Times (u, s, cu, cs): " . join( ',', times() ) . "\n";

    if (0) {    # cache
        my $fbc = $session->param('FBC');
        my $files;

        if ( $fbc && ref $fbc eq 'ARRAY' ) {
            ( my ( $version, $files, $modules ), $root ) = @$fbc;

            if ( $version == 1 ) {
                my @files = @$files;
                while (@files) {
                    my $file = shift @files;
                    last unless ( ( ( stat $file )[9] || 0 ) == $files[0] );
                    shift @files;
                }

                if ( !@files && defined $root && defined $modules ) {
                    eval $modules;
                    die "$@\n" if ($@);
                    goto EXIT;
                }
            }
        }
    }

    $root = new Foswiki::Configure::Root();

 #    This doesn't add anything that I know of.
 #
 #    require Foswiki::Configure::Checkers::Introduction;
 #    $root->addChild( Foswiki::Configure::Checkers::Introduction->new($root) );

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

    # Only read the first section if LSC is bad
    $Foswiki::Configure::LoadSpec::FIRST_SECTION_ONLY ||= $Foswiki::Configure::badLSC;
    Foswiki::Configure::LoadSpec::readSpec($root);

    # Verification not required here

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
              unless ( -f File::Spec->catfile( $path, $file ) );

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

    return $root if (1);    # cache

    {

        package Foswiki::Configure::Feedback::Cleanup;

        sub new {
            my $class = shift;

            return bless {}, $class;
        }

        sub startVisit {
            my ( $this, $visitee ) = @_;

            return 1
              unless ( $visitee->isa('Foswiki::Configure::Value')
                || $visitee->isa('Foswiki::Configure::Section') );

            $visitee->{desc}     = '' if ( exists $visitee->{desc} );
            $visitee->{headline} = '' if ( exists $visitee->{headline} );
            delete $visitee->{defined_at};
            delete $visitee->{DISPLAY_IF};

            return 1;
        }

        sub endVisit {
            return 1;
        }
    }
    $root->visit( Foswiki::Configure::Feedback::Cleanup->new );

    my ( @files, $modules );
    foreach my $required ( sort keys %INC ) {
        my $file = $required;
        if ( $file =~ /^(Foswiki.*)\.pm$/ ) {

            # Record required Foswiki modules
            $file = $1;
            $file =~ s,/,::,g;
            $modules .= ' && ' if ( defined $modules );
            $modules .= "require $file";
            next;
        }
        if ( $file =~ /\.spec$/ ) {
            $file = $INC{$file};
            push @files, ( $file => ( stat $file )[9] );
        }
    }
    $modules .= ';' if ( defined $modules );

    $session->param( 'FBC', [ 1, [@files], $modules, $root ] );

    # Must not return a reference to data in $session, as flush
    # will write with any updates.  We really want to cache only
    # what has been built so far.

  EXIT:
    require Storable;
    my $copy = Storable::dclone($root);
    die unless $copy->isa('HASH');

    #print STDERR "Times (u, s, cu, cs): " . join( ',', times() ) . "\n";

    return ($copy);
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

sub _deliverResponse {
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
      if ( $updated && ( loggedIn($session) || $Foswiki::Configure::badLSC || $Foswiki::Configure::query->auth_type ) );

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

    my $keys = $visitee->{keys};

    # Hidden items have no status window and their checkers are never run.
    # Prevent default checkers for their type from activating and generating
    # output for missing windows.

    return 1 if ( $visitee->{hidden} && $keys !~ /^\{ConfigureGUI\}/ );

    $visitee->{errorcount}   = 0;
    $visitee->{warningcount} = 0;
    $visitee->{_fbChanged}   = $this->{changed};    # Pass in item for checkers
    $visitee->{_fbRoot}      = $this->{root};
    $visitee->{visitor}      = $this;

    #        my $value = $this->{valuer}->currentValue($visitee);
    if ( $this->{fbpass} ) {

        # Looking for supplier

        return 1 unless ( $keys eq $this->{request} );

        $this->defaultOptions( $visitee, $keys );

        # Found supplier, instantiate checker
        # Retain for AUDIT reruns to save load and allow audit
        # to save state

        my $checker = $visitee->{_checker}
          || Foswiki::Configure::UI::loadChecker( $visitee );
        my $feedbacker = $visitee->{_feedbacker}
          || Foswiki::Configure::UI::loadFeedbacker( $visitee );
        $visitee->{_feedbacker} = = $feedbacker;

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
        if ( $feedbacker && $button ) {
            push @{ $this->{checks} }, $keys;
            my ( $text, $checkall ) = eval {
                $feedbacker->provideFeedback( $button,
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
        $this->{errors}{$keys} =
          "$visitee->{errorcount} $visitee->{warningcount}";

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

        my $checker = $visitee->{_checker}
          || Foswiki::Configure::UI::loadChecker( $visitee );
        $visitee->{_checker} = $checker;

        if ($checker) {
            push @{ $this->{checks} }, $keys;
            my $check = eval { return $checker->check($checker->{item}); };
            if ($@) {
                $check = $checker->ERROR(
"Checker for $keys failed: check for .spec issues: <pre>$@</pre>"
                );
            }
            $check = '' unless ( defined $check );
            unless ( $check eq 'NOT USED IN THIS CONFIGURATION' ) {
                push @{ $this->{fb} }, $keys => $check;
            }
            $this->{errors}{$keys} =
              "$visitee->{errorcount} $visitee->{warningcount}";
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

    return if ( $visitee->{fbDefaulted} );

    $visitee->{fbDefaulted} = 1;

    # Get any default CHECK options from type

    my $type =
      Foswiki::Configure::TypeUI::load( $visitee->{typename},
        $visitee->{keys} );

    if ( $type->can('defaultOptions') ) {
        $type->defaultOptions($visitee);
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
