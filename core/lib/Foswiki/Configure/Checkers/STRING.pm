# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::STRING;

# Default checker for STRING items
#
# CHECK options in spec file
#  CHECK="option option:val option:val,val,val"
#    min: length
#    max: length
#    accept: regexp,regexp
#            If present, must match one
#    filter: regexp, regexp
#            If present, any match fails
# Use this checker if possible; otherwise subclass the
# item-specific checker from it.

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

sub check {
    my $this   = shift;
    my $valobj = shift;

    my $keys  = $valobj->getKeys();
    my $value = $this->getCfg($keys) || '';
    my $len   = length($value);

    my $e = '';

    my @optionList = $this->parseOptions();

    $optionList[0] = {} unless (@optionList);

    $e .= $this->ERROR(".SPEC error: multiple CHECK options for STRING")
      if ( @optionList > 1 );

    my $min = $optionList[0]->{min}[0];
    my $max = $optionList[0]->{max}[0];

    my $accept = $optionList[0]->{accept};
    my $filter = $optionList[0]->{filter};
    my $ok     = 1;

    if ( defined $min && $len < $min ) {
        $e .= $this->ERROR("Length must be at least $min");
    }
    elsif ( defined $max && $len > $max ) {
        $e .= $this->ERROR("Length must be no greater than $max");
    }
    else {
        if ( defined $accept ) {
            $ok = 0;
            foreach my $are (@$accept) {
                if ( $value =~ $are ) {
                    $ok = 1;
                    last;
                }
            }
        }
        if ( $ok && defined $filter ) {
            foreach my $fre (@$filter) {
                if ( $value =~ $fre ) {
                    $ok = 0;
                    last;
                }
            }
        }
    }
    $e .= $this->ERROR("This value is not acceptable")
      unless ($ok);

    $value = $this->getItemCurrentValue();
    $e     = $this->showExpandedValue($value) . $e;

    if ( !$this->{item}->feedback ) {

        # There is no feedback configured for this item, so do any
        # specified tests in the checker (not a good thing).

        $e .= $this->provideFeedback( $valobj, 0, 'No Feedback' );
    }

    return $e;
}

sub provideFeedback {
    my $this = shift;
    my ( $valobj, $button, $label ) = @_;

    $this->{FeedbackProvided} = 1;

    # Normally, we call check first, but not if called by check.

    my $e = $button ? $this->check($valobj) : '';

    #    my $keys = $valobj->getKeys();

    delete $this->{FeedbackProvided};

    # check() does all that's necessary
    # We simply re-do if a button (usually autocheck) is provided.

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
