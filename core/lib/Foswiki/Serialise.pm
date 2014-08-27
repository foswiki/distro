# See bottom of file for license and copyright information
package Foswiki::Serialise;

use strict;
use warnings;
use Foswiki ();

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

---+ package Foswiki::Serialise

API to allow structures to be serialised and de-serialized. This API will only return
basic types like hashes and arrarys

=cut

#lets only load the serialiser once per execution
my %serialisers = ();

#should this really be a register/request?

=begin TML

---++ StaticMethod serialise( $session, $value, $style ) -> $cereal
   * =$session= Foswiki Session object
   * =$value= the perl object we're serializing (typically a ref/obj)
   * =$style= serialization format

#TODO: do we need to use Foswiki, or can we throw a Simple exception instead?
#I think to be reusable we catually have to throw..

=cut

sub serialise {
    my $session = shift;
    my $value   = shift;
    my $style   = shift;

    return getSerialiser( $session, $style )->write( $session, $value );
}

=begin TML

---++ StaticMethod deserialise( $session, $cereal, $style ) -> $data
   * =$session= Foswiki Session object
   * =$cereal= the perl object we're serializing (typically a ref/obj)
   * =$style= serialization format

#TODO: do we need to use Foswiki, or can we throw a Simple exception instead?
#I think to be reusable we actually have to throw..

#TODO: please work out how to add _some_ autodetection of format

=cut

sub deserialise {
    my $session = shift;
    my $cereal  = shift;
    my $style   = shift;

    return getSerialiser( $session, $style )->read( $session, $cereal );
}

#in the event of trouble, return 'Simplified'
sub getSerialiser {
    my $session = shift;
    my $style = shift || 'Simplified';

    return $serialisers{$style}
      if ( defined( $serialisers{$style} ) );

    $style = 'Simplified' if ( $style eq 'Default' );
    my $module = "Foswiki::Serialise::$style";

    eval "require $module";
    my $cereal;
    $cereal = getSerialiser( $session, 'Simplified' ) if $@;

    # Devel::Leak::Object implies we're leaking Eg. Foswiki::Serialise::Embedded
    # objects here, but they're just singletons we let hang around for minor
    # perf reasons. See Item11349
    $cereal = $module->new() if ( not defined($cereal) );
    $serialisers{$style} = $cereal;
    return $cereal;
}

#filter out parts of a meta object that don't make sense serialise (for example, json doesn't really like being sent a blessed object
sub convertMeta {
    my $savedMeta = shift;

    my $meta = {};
    $meta->{_web}   = $savedMeta->web()   if ( defined( $savedMeta->web() ) );
    $meta->{_topic} = $savedMeta->topic() if ( defined( $savedMeta->topic() ) );

    foreach my $key ( keys(%$savedMeta) ) {
        use Scalar::Util qw(blessed reftype);
        if ( blessed( $savedMeta->{$key} ) ) {

            #print STDERR "WARNING: skipping $key, its a blessed object\n";
            next;
        }
        else {

#print STDERR "WARNING: using $key - itsa ".(blessed($savedMeta->{$key})||reftype($savedMeta->{$key})||ref($savedMeta->{$key}||'notaref'))."\n";
        }

        #TODO: next if ( $key is one of the array types... and has no elements..

        $meta->{$key} = $savedMeta->{$key};
    }
    if ( defined( $meta->{_topic} ) ) {

        #TODO: exclude attachment meta too..
        my $raw = $savedMeta->getEmbeddedStoreForm();
        if ( defined($raw) ) {
            $meta->{_raw_text} = $raw;
        }
    }

    return $meta;
}

=begin TML

---++ StaticMethod finish

Finishes all instantiated serialisers. There should only be at most one of each
serialiser instantiated at any given time, so you normally wouldn't want to call
this, except perhaps from the unit test framework; see Item11349.

=cut

sub finish {
    my ($this) = @_;

    while ( my ( $name, $cereal ) = each %serialisers ) {
        if ( $cereal->can('finish') ) {
            $cereal->finish();
        }
        delete $serialisers{$name};
    }

    return;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2010-2011 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
