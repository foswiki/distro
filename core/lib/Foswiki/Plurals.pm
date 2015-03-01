# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Plurals

Handle conversion of plural topic names to singular form.

=cut

package Foswiki::Plurals;

use strict;
use warnings;
use Assert;

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

---++ StaticMethod singularForm($web, $pluralForm) -> $singularForm

Try to singularise plural topic name.
   * =$web= - the web the topic must be in
   * =$pluralForm= - topic name
Returns undef if no singular form exists, otherwise returns the
singular form of the topic

I18N - Only apply plural processing if site language is English, or
if a built-in English-language web.  Plurals
apply to names ending in 's', where topic doesn't exist with plural
name.

Note that this is highly langauge specific, and need to be enabled
on a per-installation basis with $Foswiki::cfg{PluralToSingular}.

=cut

sub singularForm {
    my ( $web, $pluralForm ) = @_;
    $web =~ s#\.#/#g;

    # Plural processing only if enabled in configure or one of the
    # distributed webs
    return
      unless ( $Foswiki::cfg{PluralToSingular}
        or $web eq $Foswiki::cfg{UsersWebName}
        or $web eq $Foswiki::cfg{SystemWebName} );
    return unless ( $pluralForm =~ m/s$/ );

    # Topic name is plural in form
    my $singularForm = $pluralForm;
    $singularForm =~ s/ies$/y/;          # plurals like policy / policies
    $singularForm =~ s/sses$/ss/;        # plurals like address / addresses
    $singularForm =~ s/ches$/ch/;        # plurals like search / searches
    $singularForm =~ s/(oes|os)$/o/;     # plurals like veto / vetoes
    $singularForm =~ s/(?<=[Xx])es$//;   # plurals like box / boxes
    $singularForm =~ s/(?<=[^s])s$//;    # others, excluding ss like address(es)
    return $singularForm;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:
Copyright (C) 2005 Martin Cleaver.
Copyright (C) 1999-2007 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root of
this distribution.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
