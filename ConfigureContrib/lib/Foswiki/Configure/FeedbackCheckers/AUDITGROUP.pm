# See bottom of file for license and copyright information
package Foswiki::Configure::FeedbackCheckers::AUDITGROUP;

use strict;
use warnings;

use Foswiki::Configure (); #(qw/:util/);

use Foswiki::Configure::Checker;
require Foswiki::Configure::Visitor;

our @ISA = qw(Foswiki::Configure::Checker Foswiki::Configure::Visitor);

sub startVisit {
    my ( $this, $visitee ) = @_;

    return 1 unless ( $visitee->isa('Foswiki::Configure::Value') );

    my $keys = $visitee->{keys};

    # Hidden items have no status window and their checkers are never run.
    # Prevent default checkers for their type from activating and generating
    # output for missing windows.

    return 1 if ( $visitee->{hidden} && $keys !~ /^\{ConfigureGUI\}/ );

    # Match visitee's audit groups to this button's audit groups
    # Visitee specifies member groups & button to press
    # The audit button selects which of its items groups are considered.
    #
    # E.g. {Foo} belongs to PARS:0 and DIRS:1
    #   The audit button pressed is number 4.  It belongs to
    #   WEB:2 NET:4 and DIRS:4.
    #   Only NET and DIRS are considered for this button press.
    #   Since {Foo} belongs to DIRS, it is selected, and its button 1
    #  will be pressed.
    #
    # Add the item to the audit list if there's an intersection
    # Note that an audit can run multiple checks on a given item.

    my $auditButton = $this->{auditButton};

    foreach my $vspec ( @{ $visitee->{AUDIT} } ) {
        my ( $vgroup, $vbutton ) = ( $vspec->{group}, $vspec->{button} );

        foreach my $aspec ( @{ $this->{AUDIT_GROUPS} } ) {
            next unless ( $aspec->{button} == $auditButton );

            if ( $aspec->{group} eq $vgroup ) {
                push @{ $this->{auditItems} }, $visitee->{keys} . $vbutton;
            }
        }
    }
    return 1;
}

sub endVisit {
    my ( $this, $visitee ) = @_;

    return 1;
}

sub provideFeedback {
    my ( $this, $button, $buttonLabel, $embedded ) = @_;

    my $keys = $this->{item}->{keys};
    my $e    = '';

    my $visit = $this->{item}->{visitor};

    if ( $button >= 0 ) {

        # Audit invocation, build list of items to check

        die "Recursive audit" if ( $buttonLabel eq '~Auditor' );

        my @items;
        my @groups = @{ $this->{item}{AUDIT_GROUPS} };
        $this->{auditGroups} = \@groups;
        $this->{auditItems}  = \@items;
        $this->{auditButton} = $button;

        my $root = $this->{item}->{_fbRoot};

        $root->visit($this);

        if (0) {    #Debug, distracting
            $e .= $this->NOTE( join( ', ', @items ) );
            $e .= $this->NOTE( sprintf "Auditing %u configuration items",
                scalar @items );
        }

        $visit->{buttonValue} = '~Auditor';

        $visit->{checks} = [];

        # Order checks, schedule this checker last to report

        return wantarray ? ( $e, [ @items, "\*${keys}-1000" ] ) : $e;
    }
    die "Pushed the wrong button ($button)\n" unless ( $button == -1000 );

    my $fb = $visit->{fb};

    unless ($fb) {
        $e .= $this->ERROR("No feedback returned");
        return wantarray ? ( $e, 0 ) : $e;
    }

    # Our response isn't modal, but the templates are convenient

    require Foswiki::Configure::ModalTemplates;

    my $limit = 10;

    #    $limit = 1_000_000; # Debug
    my $n = 0;
    my @uniq;
    my %uniq =
      map { my $name = $_; $name =~ s/\}\d+$/}/; ( $name => 0 ) }
      @{ $this->{auditItems} };
    my $uniq = keys %uniq;

    # Capture actual checks performed
    # Some requested may not have a checker; others may
    # invoke other checkers..

    foreach my $check ( @{ $visit->{checks} } ) {
        my $name = $check;
        $name =~ s/\}\d+$/}/;
        next if ( $uniq{$name}++ );
        $n++;
        last if ( $n > $limit );
        push @uniq, { item => $name };
    }
    if ( $n > $limit ) {
        push @uniq, { item => sprintf( "... and %u more", $uniq - $limit ) };
    }

    my ( $template, $templateArgs ) = Foswiki::Configure::ModalTemplates->new(
        $this,
        checksPerformed => scalar( @{ $visit->{checks} } ),
        itemsChecked    => \@uniq,
        itemCount       => $uniq,
        itemListLimit   => $limit,
        includeSuccess  => ( $embedded ? 0 : 1 ),
    );
    my ( @errors, @warnings, %items );

    # Collect items with errors and warnings
    # Skip items with feedback, but no issues

    for ( my $i = 0 ; $i < @$fb ; $i += 2 ) {
        my ( $keys, $text ) = ( @$fb[ $i + 0, $i + 1 ] );
        push @{ $items{$keys} }, $text
          if ( exists $visit->{errors}{$keys}
            && $visit->{errors}{$keys} ne '0 0' );
    }

    foreach my $keys ( sortHashkeyList( keys %items ) ) {
        my ( $errors, $warnings ) = ( 0, 0 );
        if ( exists $visit->{errors}{$keys} ) {
            ( $errors, $warnings ) = $visit->{errors}{$keys} =~ /^(\d+) (\d+)$/
              or die "Bad error record for $keys /$visit->{errors}/\n";
            if ( $errors || $warnings ) {
                push @errors,
                  {
                    item  => $keys,
                    count => $errors + $warnings,
                    list  => $this->_getFB( $items{$keys} ),
                  }
                  if ($errors);
                push @warnings,
                  {
                    item  => $keys,
                    count => $warnings,
                    list  => $this->_getFB( $items{$keys} ),
                  }
                  if ( $warnings && !$errors );
            }
        }
    }
    $template->addArgs(
        errorCount   => scalar(@errors),
        warningCount => scalar(@warnings),
        errorItems   => \@errors,
        warningItems => \@warnings
    );

    # Template is parsed twice intentionally.  See MODAL.pm for why.
    # If this audit is embedded in a larger one (e.g. CGISetup's audit
    # sections, return just HTML, and don't output details unless
    # there are issues.

    my $html = $template->extractArgs('simpleauditresults');
    $html .=
      Foswiki::Configure::UI::getTemplateParser()->readTemplate('auditdetails')
      if ( @errors || @warnings || !$embedded );
    $html = Foswiki::Configure::UI::getTemplateParser()
      ->parse( $html, $templateArgs );
    $html = Foswiki::Configure::UI::getTemplateParser()
      ->parse( $html, $templateArgs );
    Foswiki::Configure::UI::getTemplateParser()->cleanupTemplateResidues($html);

    return (
          $embedded
        ? $html
        : $this->FB_GUI( '{ConfigureGUI}{AUDIT}{RESULTS}', $html )
    );
}

sub _getFB {
    my $this      = shift;
    my $responses = shift;

    my $feedback = "";

    # Use only the status window updates.  If control updates or modal
    # data was generated, it has no place on this report.  (It is delivered
    # when the status windows are updated.)  Arguably, the FOR data should
    # be extracted earlier and sent to the target item.  But that requires
    # some fussing with the error counts.  To be continued.

    foreach my $string (@$responses) {

        my $fb = $this->parseCheckerText( $string, 1 );

        $feedback .= $fb->{text} if ( defined $fb->{text} );
        $feedback .= $_ foreach (
            map { $_->{message} }
            grep { $_->{action} eq 'FOR' } @{ $fb->{actions} }
        );

    }
    return $feedback;
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
