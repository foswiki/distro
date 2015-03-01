# See bottom of file for license and copyright information
package Foswiki::Prefs::Request;

use strict;
use Assert;

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

Support setting topic preferences when saving a topic.
URL parameters are parsed and * Set commands extracted and
used to update settings in the topic on the fly, usually during
a topic save.

Parameters have the form:
<verbatim>
http://....?[Local|Set|Unset|Default]+<key>=<value>
</verbatim>

=cut

use constant ACTION_UNSET => 0;
use constant ACTION_SET   => 1;

=begin TML

---++ StaticMethod set($request, $meta)

   * =$request= a Foswiki::Request
   * =$meta= a Foswiki::Meta topic object

Given a Foswiki request and a Foswiki::Meta object, identify and parse
parameters in the request and use them to set corresponding
preferences in the meta object.

=cut

sub set {
    my ( $request, $meta ) = @_;

    # create rules from Set+MACRONAME, Local+MACRONAME,
    # Unset+MACRONAME Default+MACRONAME urlparams
    my $rules = [];

    foreach my $key ( $request->multi_param() ) {

        next unless $key =~ m/^(Local|Set|Unset)\+(.*)$/;
        my $type   = $1;
        my $name   = $2;
        my @values = $request->multi_param($key);
        next unless @values;
        @values = grep { !/^$/ } @values if @values > 1;
        my $value = join( ", ", @values );

        #writeDebug("key=$key, value=$value");

        # convert a set to an unset if that's already default
        if ( $type =~ m/Local|Set/ ) {
            my @defaultValues = $request->multi_param("Default+$name");
            if (@defaultValues) {
                @defaultValues = grep { !/^$/ } @defaultValues
                  if @defaultValues > 1;
                my $defaultValue = join( ', ', @defaultValues );
                if ( $defaultValue eq $value ) {
                    $type = 'Unset';

                 #writeDebug("found set to default/undef ... unsetting ".$name);
                }
            }
        }

        # create a rule
        if ( $type eq 'Unset' ) {
            _addRule(
                $rules, ACTION_UNSET,
                var  => $name,
                prio => 2,
            );
        }
        else {
            _addRule(
                $rules, ACTION_SET,
                var   => $name,
                value => $value,
                type  => $type,
                prio  => 2,
            );
        }
    }

    # execute rules in the given order
    _applyRules( $rules, $meta );
}

sub _addRule {
    my $rules  = shift;
    my $action = shift;

    my $record = {
        action => $action,
        @_
    };

    push @{$rules}, $record;

    return $record;
}

sub _applyRules {
    my ( $rules, $meta ) = @_;

    #  if (DEBUG) {
    #    require Data::Dumper;
    #    writeDebug(Data::Dumper->Dump([$rules]));
    #  }

    my @fields = $meta->find('FIELD');

    # iterate over all rules in the given order
    foreach my $record ( sort { $b->{prio} <=> $a->{prio} } @{$rules} ) {

        # get settings
        my $var   = $record->{var};
        my $type  = $record->{type} || 'Local';
        my $value = $record->{value};
        if ( defined $value ) {
            $value = $meta->expandMacros($value);
        }

        if ( $record->{action} eq ACTION_SET && defined($value) ) {

#writeDebug("... setting preference $var to $value, type=$type, prio=$record->{prio}");
            $meta->putKeyed( 'PREFERENCE',
                { name => $var, title => $var, value => $value, type => $type }
            );
        }
        else {    # unset
             #writeDebug("... unsetting preference $var, prio=$record->{prio}");
            $meta->remove( 'PREFERENCE', $record->{var} );
        }
    }

    return $meta;
}

1;
__END__

Copyright (C) 2012-2013 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details, published at 
http://www.gnu.org/copyleft/gpl.html
