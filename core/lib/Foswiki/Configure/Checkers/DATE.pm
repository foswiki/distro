# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::DATE;

# Default checker for DATE items
#
# CHECK options in spec file
#  CHECK="option option:val option:val,val,val"
#    zone: utc or local - default timezone
#    raw   Return raw user input (don't normalize to ISO format)
#    nullok
#
# Use this checker if possible; otherwise subclass the item-specific checker from it.

use strict;
use warnings;

use Foswiki::Time qw/-nofoswiki/;

BEGIN {
    die "Bad version of Foswiki::Time" if ( exists $INC{'Foswiki.pm'} );
}

use Foswiki::Configure::Checker ();
our @ISA = qw/Foswiki::Configure::Checker/;

sub check {
    my $this   = shift;
    my $valobj = shift;

    my $keys = ref $valobj ? $valobj->getKeys() : $valobj;

    my $e = '';

    my @optionList = $this->parseOptions();

    $optionList[0] = {} unless (@optionList);

    $e .= $this->ERROR(".SPEC error: multiple CHECK options for DATE $keys")
      if ( @optionList > 1 );

    my $zone      = $optionList[0]->{zone}[0] || 'utc';
    my $normalize = !$optionList[0]->{raw}[0];
    my $value     = $this->getCfgUndefOk($keys);

    if ( defined $value && $value =~ /\S/ ) {
        my $binval = Foswiki::Time::parseTime( $value, $zone eq 'local' );
        if ( defined $binval ) {
            if ($normalize) {    # undef uses configured display format
                my $normval = Foswiki::Time::formatTime( $binval,
                    '$year-$mo-$dayT$hour:$min:$sec$isotz', undef );
                $e .= $this->FB_VALUE( $keys, $normval )
                  if ( $normval ne $value );
            }
        }
        else {
            $e .= $this->ERROR("Unrecognized format for date");
        }
    }
    elsif ( !$optionList[0]->{nullok}[0] ) {
        $e .= $this->ERROR('A date/time must be provided for this item');
    }

    $value = $this->getItemCurrentValue();
    $e     = $this->showExpandedValue($value) . $e;

    if ( !$this->{item}->feedback && !$this->{FeedbackProvided} ) {

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

    delete $this->{FeedbackProvided};

    # check() does all that's necessary
    # We simply re-do if a button (usually autocheck) is provided.

    return wantarray ? ( $e, 0 ) : $e;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2013 Foswiki Contributors. Foswiki Contributors
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
# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::DATE;

# Default checker for DATE items
#
# CHECK options in spec file
#  CHECK="option option:val option:val,val,val"
#    zone: utc or local - default timezone
#    raw   Return raw user input (don't normalize to ISO format)
#    nullok
#
# Use this checker if possible; otherwise subclass the item-specific checker from it.

use strict;
use warnings;

use Foswiki::Time qw/-nofoswiki/;

BEGIN {
    die "Bad version of Foswiki::Time" if ( exists $INC{'Foswiki.pm'} );
}

use Foswiki::Configure::Checker ();
our @ISA = qw/Foswiki::Configure::Checker/;

sub check {
    my $this   = shift;
    my $valobj = shift;

    my $keys = ref $valobj ? $valobj->getKeys() : $valobj;

    my $e = '';

    my @optionList = $this->parseOptions();

    $optionList[0] = {} unless (@optionList);

    $e .= $this->ERROR(".SPEC error: multiple CHECK options for DATE $keys")
      if ( @optionList > 1 );

    my $zone      = $optionList[0]->{zone}[0] || 'utc';
    my $normalize = !$optionList[0]->{raw}[0];
    my $value     = $this->getCfgUndefOk($keys);

    if ( defined $value && $value =~ /\S/ ) {
        my $binval = Foswiki::Time::parseTime( $value, $zone eq 'local' );
        if ( defined $binval ) {
            if ($normalize) {    # undef uses configured display format
                my $normval = Foswiki::Time::formatTime( $binval,
                    '$year-$mo-$dayT$hour:$min:$sec$isotz', undef );
                $e .= $this->FB_VALUE( $keys, $normval )
                  if ( $normval ne $value );
            }
        }
        else {
            $e .= $this->ERROR("Unrecognized format for date");
        }
    }
    elsif ( !$optionList[0]->{nullok}[0] ) {
        $e .= $this->ERROR('A date/time must be provided for this item');
    }

    $value = $this->getItemCurrentValue();
    $e     = $this->showExpandedValue($value) . $e;

    if ( !$this->{item}->feedback && !$this->{FeedbackProvided} ) {

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

    delete $this->{FeedbackProvided};

    # check() does all that's necessary
    # We simply re-do if a button (usually autocheck) is provided.

    return wantarray ? ( $e, 0 ) : $e;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2013 Foswiki Contributors. Foswiki Contributors
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
# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::DATE;

# Default checker for DATE items
#
# CHECK options in spec file
#  CHECK="option option:val option:val,val,val"
#    zone: utc or local - default timezone
#    raw   Return raw user input (don't normalize to ISO format)
#    nullok
#
# Use this checker if possible; otherwise subclass the item-specific checker from it.

use strict;
use warnings;

use Foswiki::Time qw/-nofoswiki/;

BEGIN {
    die "Bad version of Foswiki::Time" if ( exists $INC{'Foswiki.pm'} );
}

use Foswiki::Configure::Checker ();
our @ISA = qw/Foswiki::Configure::Checker/;

sub check {
    my $this   = shift;
    my $valobj = shift;

    my $keys = ref $valobj ? $valobj->getKeys() : $valobj;

    my $e = '';

    my @optionList = $this->parseOptions();

    $optionList[0] = {} unless (@optionList);

    $e .= $this->ERROR(".SPEC error: multiple CHECK options for DATE $keys")
      if ( @optionList > 1 );

    my $zone      = $optionList[0]->{zone}[0] || 'utc';
    my $normalize = !$optionList[0]->{raw}[0];
    my $value     = $this->getCfgUndefOk($keys);

    if ( defined $value && $value =~ /\S/ ) {
        my $binval = Foswiki::Time::parseTime( $value, $zone eq 'local' );
        if ( defined $binval ) {
            if ($normalize) {    # undef uses configured display format
                my $normval = Foswiki::Time::formatTime( $binval,
                    '$year-$mo-$dayT$hour:$min:$sec$isotz', undef );
                $e .= $this->FB_VALUE( $keys, $normval )
                  if ( $normval ne $value );
            }
        }
        else {
            $e .= $this->ERROR("Unrecognized format for date");
        }
    }
    elsif ( !$optionList[0]->{nullok}[0] ) {
        $e .= $this->ERROR('A date/time must be provided for this item');
    }

    $value = $this->getItemCurrentValue();
    $e     = $this->showExpandedValue($value) . $e;

    if ( !$this->{item}->feedback && !$this->{FeedbackProvided} ) {

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

    delete $this->{FeedbackProvided};

    # check() does all that's necessary
    # We simply re-do if a button (usually autocheck) is provided.

    return wantarray ? ( $e, 0 ) : $e;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2013 Foswiki Contributors. Foswiki Contributors
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
# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::DATE;

# Default checker for DATE items
#
# CHECK options in spec file
#  CHECK="option option:val option:val,val,val"
#    zone: utc or local - default timezone
#    raw   Return raw user input (don't normalize to ISO format)
#    nullok
#
# Use this checker if possible; otherwise subclass the item-specific checker from it.

use strict;
use warnings;

use Foswiki::Time qw/-nofoswiki/;

BEGIN {
    die "Bad version of Foswiki::Time" if ( exists $INC{'Foswiki.pm'} );
}

use Foswiki::Configure::Checker ();
our @ISA = qw/Foswiki::Configure::Checker/;

sub check {
    my $this   = shift;
    my $valobj = shift;

    my $keys = ref $valobj ? $valobj->getKeys() : $valobj;

    my $e = '';

    my @optionList = $this->parseOptions();

    $optionList[0] = {} unless (@optionList);

    $e .= $this->ERROR(".SPEC error: multiple CHECK options for DATE $keys")
      if ( @optionList > 1 );

    my $zone      = $optionList[0]->{zone}[0] || 'utc';
    my $normalize = !$optionList[0]->{raw}[0];
    my $value     = $this->getCfgUndefOk($keys);

    if ( defined $value && $value =~ /\S/ ) {
        my $binval = Foswiki::Time::parseTime( $value, $zone eq 'local' );
        if ( defined $binval ) {
            if ($normalize) {    # undef uses configured display format
                my $normval = Foswiki::Time::formatTime( $binval,
                    '$year-$mo-$dayT$hour:$min:$sec$isotz', undef );
                $e .= $this->FB_VALUE( $keys, $normval )
                  if ( $normval ne $value );
            }
        }
        else {
            $e .= $this->ERROR("Unrecognized format for date");
        }
    }
    elsif ( !$optionList[0]->{nullok}[0] ) {
        $e .= $this->ERROR('A date/time must be provided for this item');
    }

    $value = $this->getItemCurrentValue();
    $e     = $this->showExpandedValue($value) . $e;

    if ( !$this->{item}->feedback && !$this->{FeedbackProvided} ) {

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

    delete $this->{FeedbackProvided};

    # check() does all that's necessary
    # We simply re-do if a button (usually autocheck) is provided.

    return wantarray ? ( $e, 0 ) : $e;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2013 Foswiki Contributors. Foswiki Contributors
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
