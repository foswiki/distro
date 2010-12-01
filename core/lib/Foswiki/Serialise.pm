# See bottom of file for license and copyright information
package Foswiki::Serialise;

use strict;
use warnings;
use Foswiki ();


#NOTE that JSON::XS is essentially so fast its a nop, whereas the non-XS version is slow as a slow thing,

#should this really be a register/request?

#TODO: do we need to use Foswiki, or can we throw a Simple exception instead?
#I think to be reusable we catually have to throw..
sub serialise {
    my $session = shift;
    my $result = shift;
    my $style = shift;
    
    #test to make sure we exist, and other things
    
    no strict 'refs';
    my $data = &$style($session, $result);
    use strict 'refs';
    return $data;
}


sub perl {
    my ( $session, $result ) = @_;
    use Data::Dumper ();
    local $Data::Dumper::Indent = 0;
    local $Data::Dumper::Terse  = 1;
    return Data::Dumper->Dump( [$result] );
}

#TODO: should really use encode_json / decode_json as those will use utf8, 
#but er, that'll cause other issues - as QUERY will blast the json into a topic..
sub json {
    my ( $session, $result ) = @_;
    eval "require JSON::XS";
    if ($@) {
        return $session->inlineAlert( 'alerts', 'generic',
            'Perl JSON module is not available' );
    }
    return JSON::to_json( $result, { allow_nonref => 1 } );
}

# Default serialiser
sub default {
    my ( $session, $result ) = @_;
    if ( ref($result) eq 'ARRAY' ) {

        # If any of the results is non-scalar, have to perl it
        foreach my $v (@$result) {
            if ( ref($v) ) {
                return perl($result);
            }
        }
        return join( ',', @$result );
    }
    elsif ( ref($result) ) {
        return perl($result);
    }
    else {
        return defined $result ? $result : '';
    }
}

#filter out parts of a meta object that don't make sense serialise (for example, json doesn't really like being sent a blessed object
sub convertMeta {
    my $savedMeta = shift;

    my $meta = {
        _web   => $savedMeta->web(),
        _topic => $savedMeta->topic()
    };

    foreach my $key ( keys(%$savedMeta) ) {
        next if ( $key eq '_session' );
        next if ( $key eq '_indices' );
        
        $meta->{$key} = $savedMeta->{$key};
    }

    $meta->{_raw_text} = $savedMeta->getEmbeddedStoreForm();

    return $meta;
}


#TODO: ok, ugly, and incomplete
sub deserialise {
    my $session = shift;
    my $result = shift;
    my $style = shift;
    
    $style = $style.'_un';
    #test to make sure we exist, and other things
    
    no strict 'refs';
    my $data = &$style($session, $result);
    use strict 'refs';
    return $data;
}


sub perl_un {
    die 'not implemented';
}

#TODO: should really use encode_json / decode_json as those will use utf8, 
#but er, that'll cause other issues - as QUERY will blast the json into a topic..
sub json_un {
    my ( $session, $result ) = @_;
    eval "require JSON::XS";
    if ($@) {
        return $session->inlineAlert( 'alerts', 'generic',
            'Perl JSON module is not available' );
    }
    return JSON::from_json( $result );
}

# Default serialiser
sub default_un {
    die 'not implemented';
}



1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2010 Foswiki Contributors. Foswiki Contributors
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
