# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2007 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root of
# this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
# Copyright (C) 2005 Martin Cleaver.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.

=pod

---+ package TWiki::Plurals

Handle conversion of plural topic names to singular form.

=cut

package TWiki::Plurals;

use strict;

=pod

---++ StaticMethod singularForm($web, $pluralForm) -> $singularForm

Try to singularise plural topic name.
   * =$web= - the web the topic must be in
   * =$pluralForm= - topic name
Returns undef if no singular form exists, otherwise returns the
singular form of the topic

I18N - Only apply plural processing if site language is English, or
if a built-in English-language web (Main, TWiki or Plugins).  Plurals
apply to names ending in 's', where topic doesn't exist with plural
name.

Note that this is highly langauge specific, and need to be enabled
on a per-installation basis with $TWiki::cfg{PluralToSingular}.

=cut

sub singularForm {
    my( $web, $pluralForm ) = @_;
    $web =~ s#\.#/#go;

    # Plural processing only if enabled in configure or one of the
    # distributed webs
    return undef unless( $TWiki::cfg{PluralToSingular} or 
                         $web eq $TWiki::cfg{UsersWebName} or 
                          $web eq $TWiki::cfg{SystemWebName} );
    return undef unless( $pluralForm =~ /s$/ );

    # Topic name is plural in form
    my $singularForm = $pluralForm;
    $singularForm =~ s/ies$/y/;      # plurals like policy / policies
    $singularForm =~ s/sses$/ss/;    # plurals like address / addresses
    $singularForm =~ s/ches$/ch/;    # plurals like search / searches
    $singularForm =~ s/(oes|os)$/o/; # plurals like veto / vetoes
    $singularForm =~ s/([Xx])es$/$1/;# plurals like box / boxes
    $singularForm =~ s/([^s])s$/$1/; # others, excluding ss like address(es)
    return $singularForm
}

1;
