# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Configure::Checker;

Base class of all checkers. Checkers give checking and guessing support
for configuration values. Checkers are designed to be totally independent
of UI.

All 'Value' type configuration items in the model can have a checker.
Further, if a value doesn't have an individual checker, there may
be an associated type checker. If an item has an individual checker,
it's type checker is *not* invoked.

A checker must provide =check_current_value=, as described below.

Checkers *never* modify =$Foswiki::cfg=.

Checker objects are not instantiated directly. Rather, they are generated
using the =loadChecker= factory method described below.

=cut

package Foswiki::Configure::Checker;

use strict;
use warnings;

use Data::Dumper ();
use File::Spec   ();

use Assert;

use Foswiki::Configure::Load       ();
use Foswiki::Configure::Dependency ();

use constant GUESSED_MESSAGE => <<'HERE';
I had to guess this setting in order to continue checking. You must
confirm this setting (and any other guessed settings) and save
correct values before changing any other settings.
HERE

my %checkers;

# Construct a new Checker, attaching the given $item from the model.
# This is not normally used by other classes, but is provided in case
# a subclass needs to override it for any reason.
sub new {
    my ( $class, $item ) = @_;

    my $this = bless( { item => $item }, $class );
}

=begin TML

---++ StaticMethod loadChecker($item [, $explicit]) -> $checker

Loads the Foswiki::Configure::Checker subclass for the
given $item. For example, given the $item->{keys} '{Beans}{Mung}', it
will try and load Foswiki::Configure::Checkers::Beans::Mung

An item may specify a different checker to load if it has the
CHECKER attribute. This will be interpreted as keys for the 'real' checker
to lead for this item. This behaviour is suppressed if $explicit is
true (i.e. CHECKER will be ignored, and the default behaviour will apply.
This is useful in the case where an explicit CHECKER has to chain the
other checkers for an item.)

If the item doesn't have a subclass defined, the item's type class may
define a generic checker for that type.  If so, it is instantiated
for this item.

Finally, we will see if $item's type, or one it inherits from
has a generic checker.  If so, that's instantiated.

Returns the checker that's created or undef if no such checker is found.

Will die if the checker exists but fails to compile.

$item is passed on to the checker's constructor.

=cut

sub loadChecker {
    my ( $item, $explicit ) = @_;
    my $id;

    if ( !$explicit && $item->{CHECKER} ) {

        # Checker override
        $id = $item->{CHECKER};
    }
    else {
        ASSERT( $item && $item->{keys} ) if DEBUG;

        # Convert {key}{s} to key::s, removing illegal characters
        # [-_\w] are legal. - => _.
        $id = $item->{keys};

        $id =~ s{\{([^\}]*)\}}{
            my $lbl = $1;
            $lbl =~ tr,-_a-zA-Z0-9\x00-\xff,__a-zA-Z0-9,d;
            $lbl . '::'}ge
          and substr( $id, -2 ) = '';
    }

    foreach my $chkmod ( $id, $item->{typename} ) {
        if ( defined $checkers{$chkmod} ) {
            if ( $checkers{$chkmod} ) {

                #print STDERR "Returning cached $chkmod\n";
                return $checkers{$chkmod}->new($item);
            }
        }
        else {
            my $checkClass = 'Foswiki::Configure::Checkers::' . $chkmod;
            if (
                Foswiki::Configure::FileUtil::findFileOnPath(
                    $checkClass . '.pm'
                )
              )
            {
                eval("require $checkClass");
                unless ($@) {
                    $checkers{$chkmod} = $checkClass;

                    #print STDERR "Returning NEW cached $chkmod\n";
                    return $checkClass->new($item);
                }
                else {
                    die "Checker $checkClass failed to load: $@\n";
                }
            }

            #print STDERR "Caching empty $chkmod\n";
            $checkers{$chkmod} = '';
        }
    }
    return undef;
}

=begin TML

---++ ObjectMethod check_current_value($reporter)
    * =$reporter= - report logger; use ERROR, WARN etc on this
      object to record information.

The value to be checked is taken from $Foswiki::cfg. This is the
baseline check for values already in $Foswiki::cfg, and needs to
be as fast as possible (it should not do any heavy processing).

Old checkers may not provide =check_current_value= but instead
use the older signature =check=.

=cut

sub check_current_value {
    my ( $this, $reporter ) = @_;

    # If we get all the way back up the inheritance tree without
    # finding a check_current_value implementation, then see if
    # there is a check().
    if ( $this->can('check') ) {
        $this->{reporter} = $reporter;
        $this->check( $this->{item} );
        delete $this->{reporter};
    }
}

###################################################################
# Compatibility methods
# Note that ASSERT($this->{reporter} if DEBUG is used to confirm that
# the call has come from an implementation of check()

# Get the value of the named configuration var.
#    * =$keys= - optional keys to retrieve e.g
#      =getCfg("{Validation}{ExpireKeyOnUse}")=. Defaults to the
#     keys of the item associated with the checker.
#
# Any embedded references to other Foswiki::cfg vars will be expanded.
# Note that any embedded references to undefined variables will be
# expanded as the string 'undef'. Use =getCfgUndefOk= if you want a
# real undef for undefined values rather than the string.
#
# Synonymous with:
# <verbatim>
# my $x = '$Foswiki::cfg{Keys}';
# Foswiki::Configure::Load::expandValue($x, 0);
# </verbatim>
# Thus it returns the value as Foswiki will see it (i.e. with undef
# expanded as the string 'undef')
sub getCfg {
    my ( $this, $name ) = @_;
    $name ||= $this->{item}->{keys};

    my $item = '$Foswiki::cfg' . $name;
    Foswiki::Configure::Load::expandValue($item);
    return $item;
}

# As =getCfg=, except that =undef= will not be expanded to the string 'undef'.
# Note that recursive expansion of embedded =$Foswiki::cfg= will also return
# undef, and will result in a program error.
sub getCfgUndefOk {

    my ( $this, $name, $undef ) = @_;
    $name ||= $this->{item}->{keys};

    my $item = '$Foswiki::cfg' . $name;
    Foswiki::Configure::Load::expandValue( $item, defined $undef ? $undef : 1 );
    return $item;
}

# Provided for compatibility; if a checker tries to call SUPER::check and
# the superclass only has check_current_value, it will fold back to here.
sub check {
    my ($this) = @_;

    # Subclasses often use SUPER::check, so make sure it's there.
    # Passing the checker as the reporter is a bit of a hack, but
    # OK by design.
    ASSERT( $this->can('check_current_value') ) if DEBUG;
    $this->check_current_value($this);
}

# Provided for use by check() implementations *only* new checkers
# *must not* call this.
sub NOTE {
    my $this = shift;
    ASSERT( $this->{reporter} ) if DEBUG;
    $this->{reporter}->NOTE(@_);
    return join( ' ', @_ );
}

# Provided for use by check() implementations *only* new checkers
# *must not* call this.
sub WARN {
    my $this = shift;
    ASSERT( $this->{reporter} ) if DEBUG;
    $this->{reporter}->WARN(@_);
    return join( ' ', @_ );
}

# Provided for use by check() implementations *only* new checkers
# *must not* call this.
sub ERROR {
    my $this = shift;
    ASSERT( $this->{reporter} ) if DEBUG;
    $this->{reporter}->ERROR(@_);
    return join( ' ', @_ );
}

# Set the value of the checked configuration var.
# $keys are optional.
# Provided for use by check() implementations *only* new checkers
# *must not* call this.
sub setItemValue {
    my ( $this, $value, $keys ) = @_;
    $keys ||= $this->{item}->{keys};
    ASSERT( $this->{reporter} ) if DEBUG;

    eval("\$Foswiki::cfg$keys = \$value;");
    if ($@) {
        die "Unable to set value $value for $keys\n";
    }
    return wantarray ? ( $keys, $value ) : $keys;
}

# Provided for use by check() implementations *only* new checkers
# *must not* call this.
sub getItemCurrentValue {
    my $this = shift;
    my $keys = shift || $this->{item}->{keys};
    ASSERT( $this->{reporter} ) if DEBUG;
    my $value = eval("\$Foswiki::cfg$keys");
    if ($@) {
        die "Unable to get value for $keys\n";
    }
    return $value;
}

# Get the default value of the checked configuration var.
# $keys is optional
# Provided for use by check() implementations *only* new checkers
# *must not* call this.
sub getItemDefaultValue {
    my $this = shift;
    my $keys = shift || $this->{item}->{keys};
    ASSERT( $this->{reporter} ) if DEBUG;

    no warnings 'once';
    my $value = eval("\$$Foswiki::Configure::defaultCfg->$keys");
    if ($@) {
        die "Unable to get default $value for $keys\n";
    }
    return $value;
}

# Provided for use by check() implementations *only* new checkers
# *must not* call this.
sub checkGnuProgram {
    my ( $this, $prog ) = @_;
    ASSERT( $this->{reporter} ) if DEBUG;
    Foswiki::Configure::FileUtil::checkGNUProgram( $prog, $this );
    return '';
}

# Provided for use by check() implementations *only* new checkers
# *must not* call this.
sub checkPerlModule {
    my ( $this, $module, $note, $version ) = @_;
    ASSERT( $this->{reporter} ) if DEBUG;
    my %mod = (
        name           => $module,
        usage          => $note,
        disposition    => 'required',
        mimimumVersion => $version
    );
    Foswiki::Configure::Dependency::checkPerlModules( \%mod );
    if ( $mod{ok} ) {
        $this->{reporter}->NOTE( $mod{check_result} );
        return '';
    }
    else {
        $this->{reporter}->ERROR( $mod{check_result} );
        return 'ERROR';
    }
}

###################################################################
# Support methods, used by subclasses

=begin TML

---++ PROTECTED ObjectMethod warnAboutWindowsBackSlashes($path) -> $html

Generate a warning if the supplied pathname includes windows-style
path separators.

PROVIDED FOR COMPATIBILITY ONLY - DO NOT USE! Use inheritance of
Checkers::PATH behaviour instead.

=cut

sub warnAboutWindowsBackSlashes {
    my ( $this, $path ) = @_;
    if ( $path =~ m/\\/ ) {
        return $this->WARN(
                'You should use c:/path style slashes, not c:\path in "'
              . $path
              . '"' );
    }
}

=begin TML

---++ PROTECTED ObjectMethod checkExpandedValue($reporter) -> $value

Report the expanded value of a parameter. Return the expanded value.

=cut

sub checkExpandedValue {
    my ( $this, $reporter ) = @_;

    my $raw   = $this->{item}->getRawValue();
    my $value = $this->{item}->getExpandedValue();

    my $field = $value;

    if ( !defined $raw ) {
        $raw = 'undef';
    }

    if ( !defined $field ) {
        if ( !$this->{item}->CHECK_option('undefok') ) {
            $reporter->ERROR("May not be undefined");
        }
        $field = 'undef';
    }

    if ( $field eq '' && !$this->{item}->CHECK_option('emptyok') ) {
        $reporter->ERROR("May not be empty");
    }

    if ( ref($field) ) {
        $field = $this->{item}->encodeValue($field);
    }

    #print STDERR "field=$field, raw=$raw\n";

    if ( $field ne $raw ) {
        if ( $field =~ m/\n/ ) {
            $reporter->NOTE( 'Expands to: <verbatim>', $field, '</verbatim>' );
        }
        elsif ( $field eq '' ) {
            $reporter->NOTE("Expands to: '' (empty)");
        }
        else {
            $reporter->NOTE("Expands to: =$field=");
        }
    }

    return $value;
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
