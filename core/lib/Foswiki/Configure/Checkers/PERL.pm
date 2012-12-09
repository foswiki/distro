# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::PERL;

use strict;
use warnings;

require Foswiki::Configure::Types::PERL;

use Foswiki::Configure(qw/:cgi/);

require Foswiki::Configure::Checker;
our @ISA = ('Foswiki::Configure::Checker');

# check & provideFeedback could be restructured to remove
# redundant code, but since these are all error cases, it
# doesn't seem worth the trouble.

sub check {
    my $this   = shift;
    my $valobj = shift;

    my $keys  = $valobj->getKeys();
    my $value = $this->getItemCurrentValue();
    return '' if ( defined $value );

    # Not defined, there was a parsing or eval problem.
    # Re-do it here where we can diagnose the error.
    #
    # The CGI value is a string '[ expressions ]' - we hope.
    $value = $query->param($keys);
    return $this->ERROR("No value for this item")
      unless ( defined $value );

    $value =~ s/^[[:space:]]+(.*?)$/$1/s;
    $value =~ s/^(.*?)[[:space:]]+$/$1/s;

    my $s;
    if ( $s = Foswiki::Configure::Types::PERL::_rvalue($value) ) {
        my $top = substr( $value, 0, length($value) - length($s) );
        my $line = ( $top =~ tr/\n// );
        my $lines = join(
            "\n",
            (
                split(
                    /\n/,
                    $top
                      . qq{<span style="background-color:yellow;">&lt;&lt;&lt;=== HERE</span>\n}
                      . $s
                )
              )[
              max( 0, $line - 5 ) .. $line + 1 + min( ( $s =~ tr /\n// ), 5 )
              ]
        );
        $line++;
        return $this->ERROR(
            "Error detected in structure near line $line.<pre>$lines</pre>");
    }
    $value =~ /(.*)/s;
    eval $1;
    if ($@) {
        $@ =~ s/\(eval\s+\d+\)\s+//;
        return $this->ERROR( "Error in structure: <pre>"
              . $this->stripTraceback($@)
              . "</pre>" );
    }

    return '';
}

# Note that check() is always called, so it's not necessary
# to do a second eval; if there was an error, it's obtained
# from check.  The only reason to do something different here
# is that we can insert a marker into the textarea where we
# think an error is.

sub provideFeedback {
    my $this = shift;
    my ( $valobj, $button, $label ) = @_;

    $this->{FeedbackProvided} = 1;

    # Normally, we call check first, but not if called by check.

    my $e = $button ? $this->check($valobj) : '';

    delete $this->{FeedbackProvided};

    if ( $button && $e ) {
        my $keys  = $valobj->getKeys();
        my $value = $this->getItemCurrentValue();
        unless ( defined $value ) {
            $value = $query->param($keys);
            if ( defined $value ) {
                $value =~ s/^[[:space:]]+(.*?)$/$1/s;
                $value =~ s/^(.*?)[[:space:]]+$/$1/s;

                my $s;
                if ( $s = Foswiki::Configure::Types::PERL::_rvalue($value) ) {
                    my $top =
                      substr( $value, 0, length($value) - length($s) )
                      . qq{<<< ============ HERE\n};

                    $e .=
                        $this->FB_VALUE( "$keys", $top )
                      . $this->FB_ACTION( $keys, 'b,m,A,M', $s );
                }
            }
        }
    }
    return wantarray ? ( $e, 0 ) : $e;
}

sub max {
    return unless (@_);
    my $max = shift;

    while (@_) {
        my $next = shift;
        $max = $next if ( $next > $max );
    }
    return $max;
}

sub min {
    return unless (@_);
    my $min = shift;

    while (@_) {
        my $next = shift;
        $min = $next if ( $next < $min );
    }
    return $min;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2012 Foswiki Contributors. Foswiki Contributors
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
