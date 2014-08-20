# Verify values vs. spec
package Foswiki::Configure::VerifyCfg;

use strict;

use Assert;
use Foswiki::Configure::LoadSpec ();

# If spec files were parsed, but require failed, all kinds of
# trouble follows because the UI has references, but there are no defaults.
# Complicating matters, certain parameters in the spec file are
# commented out so as to have NO default, but require initial setup.
# These are classified as warnings here only if they have no current value.
#
# To try to report the trouble intelligently, we walk the UI and try
# to fetch the value of each variable.

use Foswiki::Configure         ();
use Foswiki::Configure::Root   ();
use Foswiki::Configure::Valuer ();

use Foswiki::Configure::Visitor ();
our @ISA = ('Foswiki::Configure::Visitor');

sub new {
    my $class = shift;
    return bless( {@_}, $class );
}

# Strip traceback from die and carp for a user message
sub _stripTraceback {
    my $message = shift;

    return '' unless ( length $message );

    return $message if ( $Foswiki::cfg::{DebugTracebacks} );

    $message = ( split( /\n/, $message ) )[0];
    $message =~ s/ at .*? line \d+\.$//;
    return $message;
}

sub startVisit {
    my ( $this, $visitee ) = @_;

    if ( $visitee->isa('Foswiki::Configure::Value') ) {

        # See if this item is exempt
        return 1 if ( $visitee->{EXEMPT} );

        my $valuer = $this->{valuer};

        # If a value exists, we're cooking with gas.
        return 1 if defined $valuer->currentValue($visitee);

        # Some dynamically-created items (e.g. Languages) don't have
        # defaults.

        return 1 unless exists $visitee->{default};

        # Known items materialized without a .spec entry can provide
        # a default. All items from the spec files record file and line
        # for diagnostics
        # Spec file items that are optional (commented-out for guessing
        # support) provide the default as "undef"; we set based on type,
        # but don't report.

        my $default =
          defined $visitee->{default} ? eval $visitee->{default} : undef;
        my $keys = $visitee->{keys};

        my $hasMissingValue;
        eval <<SCRIPT;
\$hasMissingValue = !exists \$Foswiki::cfg$keys ||
     !ref( \$Foswiki::cfg$keys) && \$Foswiki::cfg$keys =~ /NOT SET/;
\$Foswiki::cfg$keys = \$default unless ( exists \$Foswiki::cfg$keys );
\$Foswiki::Configure::defaultCfg->$keys = \$default
    unless( exists \$Foswiki::Configure::defaultCfg->$keys );
SCRIPT

        # Report unless default was provided by the item.

        if ($hasMissingValue) {
            if ( !exists( $visitee->{default} ) ) {
                my ( $file, $line ) = @{ $visitee->{defined_at} };
                Foswiki::Configure::LoadSpec::warning( $file, $line,
"$keys is not defined in LocalSite.cfg, and no default was found: "
                      . _stripTraceback($@) );
            }
        }
    }
    return 1;
}

sub endVisit {
    my ( $this, $visitee ) = @_;

    return 1;
}

sub verify {
    my ( $root, $haveLSC ) = @_;

    my $valuer = new Foswiki::Configure::Valuer( \%Foswiki::cfg );
    my $this   = Foswiki::Configure::VerifyCfg->new(
        valuer => $valuer,
        root   => $root,
    );
    $root->visit($this);

    # Skip rendering warning messages on first run -- the user already knows
    # we don't have a working setup yet
    return unless $haveLSC;

    if (   @Foswiki::Configure::LoadSpec::errors
        || @Foswiki::Configure::LoadSpec::warnings )
    {
        my $errors = SectionMarker->new( 0, qq{Configuration file errors} );
        if (@Foswiki::Configure::LoadSpec::errors) {
            $errors->append( 'desc',
"<p>Errors were detected in component specification files.  Contact the developer of the associated component to have them corrected.<ul>"
            );
            foreach my $error (@Foswiki::Configure::LoadSpec::errors) {
                $errors->append(
                    'desc',
                    "<li>$error->[2]"
                      . (
                        $error->[0]
                        ? " in $error->[0] at line $error->[1]"
                        : ''
                      )
                      . "</li>"
                );
            }
            $errors->append( 'desc', "</ul>" );
        }
        if (@Foswiki::Configure::LoadSpec::warnings) {
            $errors->append( 'desc',
"<p>Configuration items are missing from your site configuration file. Please define them and save your configuration before proceeding.<ul>"
            );
            foreach my $warning (@Foswiki::Configure::LoadSpec::warnings) {
                $errors->append(
                    'desc',
                    "<li>$warning->[2]"
                      . (
                        $warning->[0]
                        ? " in $warning->[0] at line $warning->[1]"
                        : ''
                      )
                      . "</li>"
                );
            }
            $errors->append( 'desc', "</ul>" );
        }

# WTF?        my $item = new Foswiki::Configure::Value( 'BOOLEAN', keys => 'DUMMY' );
#        _extractSections( [ $errors, $item ], $root );
#
#        $item->inc('errorcount') foreach (@Foswiki::Configure::LoadSpec::errors);
#        {
#            no warnings 'once';
#            $Foswiki::Configure::UI::toterrors += @Foswiki::Configure::LoadSpec::errors;
#            $item->inc('warningcount') foreach (@Foswiki::Configure::LoadSpec::warnings);
#            $Foswiki::Configure::UI::totwarnings += @Foswiki::Configure::LoadSpec::warnings;
#        }
#        delete $item->{_parent}->{children};
#        undef $item;
    }
}

1;
