# See bottom of file for license and copyright information

=pod

---+ package Foswiki::Configure::Value

A Value object is a Foswiki::Configure::Item that represents a single entry
in a *.spec or LocalSite.cfg file i.e. it is the leaf type in a configuration
model.

Values come in two types; 'DEFAULT' and 'CURRENT'; a DEFAULT type is read
from a *.spec file and a CURRENT type from LocalSite.cfg (or taken from
URL parameters)

Note that this object does *not* store the "actual" value of a configuration
item; that is done by a Foswiki::Configure::Valuer. This object is
the *model* only.

=cut

package Foswiki::Configure::Value;

use strict;
use warnings;

require Foswiki::Configure::Item;
our @ISA = ('Foswiki::Configure::Item');

require Foswiki::Configure::Type;

our $VALUE_TYPE = {
    CURRENT => ( 1 << 0 ),    # 1
    DEFAULT => ( 1 << 1 ),    # 2
};

=begin TML

---++ ClassMethod new($typename, %params)
   * =$typename= e.g 'STRING', name of one of the Foswiki::Configure::Types
     Defaults to 'UNKNOWN' if not given ('', 0 or undef).

%params may include:
   * parent     node
   * keys       e.g {Garden}{Flowers}
   * expertsOnly boolean
   * opts options
Constructor. The opts are attributes, and by convention may
be a number (for a string length), a comma separated list of values
(for a select) and may also have an M for mandatory, or a H for hidden.

Other standard attributes include EXPERT, DISPLAY_IF, ENABLE_IF and FEEDBACK.

=cut

sub new {
    my $class    = shift;
    my $typename = shift;

    my $this =
      bless( $class->SUPER::new('Foswiki::Configure::UIs::Value'), $class );

    $this->{typename}    = ( $typename || 'UNKNOWN' );
    $this->{keys}        = '';
    $this->{opts}        = '';
    $this->{expertsOnly} = 0;

    # Transfer remaining params into the object
    $this->set(@_);

    return $this;
}

# Intercept options for special parsing

sub set {
    my $this = shift;
    return unless (@_);
    my $append;
    if ( !defined $_[0] ) {
        $append = 1;
        shift;
    }
    my %params = @_;

    foreach my $k ( keys %params ) {
        my $v = $params{$k};
        if ( $k eq 'opts' ) {

            # DEBUG:
            # $this->{fullopts} = ($append? $this->{fullopts} . "|$v" : $v);
            $this->{$k} = $this->_setopts( $v, $append );
        }
        else {
            $this->{$k} = $v;
        }
    }
}

# Special parsing for options string

sub _fixqs {
    my ($qs) = @_;

    chop $qs;
    $qs = substr( $qs, 1 );
    $qs =~ s/\\(.)/$1/g;
    return $qs;
}

sub _setopts {
    my $this = shift;
    my ( $value, $append ) = @_;

    # Over-ride these on any new option string.  Note that audits is NOT
    # included so that the cursory checks can count on the inital audit group.
    #
    # The $append flag is used for late defaults and does not reset
    # items parsed out of the string.

    unless ($append) {
        delete @{$this}
          {qw/label checkerOpts feedback mandatory hidden displayIf enableIf/};
        $this->{expertsOnly} = 0;
    }

    my $qsRE = qr/(?:(?:"(?:\\.|[^"])*")|(?:'(?:\\.|[^'])*'))/o;

    # Quoted strings before anything else...
    $this->addAuditGroup( split( /\s+/, _fixqs($1) ) )
      while ( $value =~ s/(?:\b|^)AUDIT=($qsRE)(?:\s+|$)// );

    $this->{label} = _fixqs($1)
      if ( $value =~ s/(?:\b|^)LABEL=($qsRE)(?:\s+|$)// );

    push @{ $this->{checkerOpts} }, _fixqs($1)
      while ( $value =~ s/(?:\b|^)CHECK=($qsRE)(?:\s+|$)// );

    my $attrRE = qr/(?:;\s*([\w_-]+)(?:=($qsRE))?)/;

    while ( $value =~
s/(?:\b|^)FEEDBACK(?:(?:([:=])(?:(?:([\w_-]+)($attrRE*)(?:\b|$))|(?:($qsRE)($attrRE*)(?:\s+|$))))|($attrRE*)(?:\b|$))//
      )
    {
        my @h;
        if ( defined $1 ) {    # FEEDBACK(=)
            if ( defined $6 )
            {    # Quoted string (single or double; \-escape inner)
                push @h, '.label' => _fixqs($6);
            }
            else {    # FEEDBACK=keyword
                push @h, '.label' => {
                    AUTO        => '~',
                    'ON-CHANGE' => '~',
                    IMMEDIATE   => '~',
                    VALIDATE    => 'Validate',
                    FIX         => 'Repair',
                    TEST        => 'Test',
                  }->{ uc $2 }
                  || "Unknown FEEDBACK keyword '$2' in .spec";
            }
        }
        else {        # Default label
            push @h, '.label' => 'Validate';
        }

        # ;attr=value;attr=value;attr...
        my $attrs = ( $3 || $7 || $10 );
        if ($attrs) {
            $attrs =~
              s/$attrRE/push @h, $1 => (defined $2? _fixqs($2) : 1); ''/ge;
        }
        push @{ $this->{feedback} }, {@h};
    }
    $this->{label} = ''
      if ( $value =~ s/(\b|^)NOLABEL(\b|$)// );

    $this->{mandatory} = ( $value =~ /(\b|^)M(\b|$)/ );
    $this->{hidden}    = ( $value =~ /(\b|^)H(\b|$)/ );
    $this->{expertsOnly} ||= 1
      if ( $value =~ s/(\b|^)EXPERT(\b|$)// );
    $this->{displayIf} = $1
      if ( $value =~ s/(?:\b|^)DISPLAY_IF\s+(.*?)(\/DISPLAY_IF|$)// );
    $this->{enableIf} = $1
      if ( $value =~ s/(?:\b|^)ENABLE_IF\s+(.*?)(\/ENABLE_IF|$)// );

    return $value;
}

# Add one or more audit group to this item
# Group specifiers are Name:button, where
# :button is the button number to be pressed when
# audited in the named group.  :button defaults to 1.

sub addAuditGroup {
    my $this = shift;

    my $audits = $this->{audits};
    my %present = map { $_ => 1 } @$audits if ($audits);

    foreach my $item (@_) {
        unless ( $present{$item} ) {
            push @{ $this->{audits} }, $item;
            $present{$item} = 1;
        }
    }
}

# See Foswiki::Configure::Item
sub isExpertsOnly {
    my $this = shift;
    return $this->{expertsOnly};
}

sub displayIf {
    my $this = shift;
    return $this->{displayIf} || '';
}

sub enableIf {
    my $this = shift;
    return $this->{enableIf} || '';
}

# See Foswiki::Configure::Item
sub getKeys {
    my $this = shift;
    return $this->{keys};
}

sub feedback {
    my $this = shift;
    return $this->{feedback};
}

sub getCheckerOptions {
    my $this = shift;

    return $this->{checkerOpts};
}

sub label {
    my $this = shift;
    return $this->{label};
}

sub audits {
    my $this = shift;
    return @{ $this->{audits} } if ( $this->{audits} );
    return ();
}

sub getTypeName {
    my $this = shift;

    return $this->{typename};
}

=begin TML

---++ ObjectMethod getType() -> $type

Get the Foswiki::Configure::Type object that specifies the type of this
value.

=cut

sub getType {
    my $this = shift;
    unless ( $this->{type} ) {
        $this->{type} =
          Foswiki::Configure::Type::load( $this->{typename}, $this->{keys} );
    }
    return $this->{type};
}

# A value is a leaf, so this is a NOP.
sub getSectionObject {
    return;
}

=begin TML

---++ ObjectMethod getValueObject($keys)
Get the value

=cut

sub getValueObject {
    my ( $this, $keys ) = @_;

    return $this if ( $this->{keys} && $keys eq $this->{keys} );
    return;
}

# See if this value is changed from the default. The comparison
# is done according to the rules for the type of the value.
sub needsSaving {
    my ( $this, $valuer ) = @_;

    my $currentValue = $valuer->currentValue($this);
    my $defaultValue = $valuer->defaultValue($this);

    my $isEqual = $this->getType()->equals( $currentValue, $defaultValue );

#print STDERR "TEST $this->{keys} D'",($defaultValue||'undef'),"' C'",($currentValue||'undef'),"'\n";

    return !$isEqual;
}

=pod

asString( $valuer, $valueType) -> $value

- $valueType: (int) value of VALUE_TYPE, either 'CURRENT' or 'DEFAULT'

=cut

sub asString {
    my ( $this, $valuer, $type ) = @_;

    my $value;
    if ( !defined $type || $type == $VALUE_TYPE->{CURRENT} ) {
        $value = $valuer->currentValue($this);
    }
    elsif ( $type == $VALUE_TYPE->{DEFAULT} ) {
        $value = $valuer->defaultValue($this);
    }
    $value ||= '';

    # DEBUG: I don't think these 'Type's exist - no evidence of them.
    # [TL]   If they do somehow exist, they need checkers and other support.
    if ( ( my $tn = $this->{typename} ) =~ /^(?:HASH|ARRAY)$/ ) {
        require Carp;
        Carp::confess("Unexpected Type $tn encountered");
    }

    if ( $this->{typename} eq 'PERL' ) {

        # || $this->{typename} eq 'HASH'
        # || $this->{typename} eq 'ARRAY' ) {
        require Data::Dumper;

        local $Data::Dumper::Sortkeys;
        local $Data::Dumper::Terse;

        $Data::Dumper::Sortkeys = 1;
        $Data::Dumper::Terse    = 1;

        $value = Data::Dumper::Dumper($value);
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
