# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Serialise::Embedded

This is __the__ on disk format serialiser and deserialise for
Foswiki topics legacy .txt format.

__WARNING__ this is only for Foswiki::Meta objects.

=cut

package Foswiki::Serialise::Embedded;

use strict;
use warnings;
use Foswiki       ();
use Foswiki::Meta ();
use Assert;

=begin TML

---++ ClassMethod new( $class,  ) -> $cereal

=cut

sub new {
    my $class = shift;
    my $this = bless( {}, $class );
    return $this;
}

# Generate the embedded store form of the topic. The embedded store
# form has meta-data values embedded using %META: lines. The text
# stored in the meta is taken as the topic text.
#
# TODO: Soooo.... if we wanted to make a meta->setPreference('VARIABLE', 'Values...'); we would have to change this to
#    1 see if that preference is set in the {_text} using the    * Set syntax, in which case, replace that
#    2 or let the META::PREF.. work as it does now..
sub write {
    my ( $this, $meta ) = @_;

    ASSERT( $meta->isa('Foswiki::Meta') ) if DEBUG;

    my $ti = $meta->get('TOPICINFO');
    delete $ti->{rev} if $ti;    # don't want this written

    my $text = _writeTypes( $meta, 'TOPICINFO', 'TOPICPARENT' );
    $text .= ( $meta->text() || '' );
    my $end =
      _writeTypes( $meta, 'FORM', 'FIELD', 'FILEATTACHMENT', 'TOPICMOVED' )
      . _writeTypes( $meta, 'not', 'TOPICINFO', 'TOPICPARENT', 'FORM', 'FIELD',
        'FILEATTACHMENT', 'TOPICMOVED' );
    $text .= "\n" if $end;

    $ti->{rev} = $ti->{version} if $ti;

    return $text . $end;
}

sub read {
    my ( $this, $text, $meta ) = @_;

    ASSERT( $meta->isa('Foswiki::Meta') ) if DEBUG;
    my $format = Foswiki::Meta::EMBEDDING_FORMAT_VERSION;

    # head meta-data
    # NO THIS CANNOT BE /g - TOPICINFO is _only_ valid as the first line!
    $text =~ s<^(%META:(TOPICINFO)\{(.*)\}%\n)>
              <_readMETA($meta, $1, $2, $3, 1)>e;

    # WARNING: if the TOPICINFO *looks* valid but has has unrecognisable
    # fields in it, it will fail the Meta::isValidEmbedding test and
    # a default TOPICINFO wil be used - but the bad TOPICINFO will be left
    # in the topic so it looks like there are two TOPICINFOs. Admins
    # will have to fix up the broken topic.

    my $ti = $meta->get('TOPICINFO');
    if ($ti) {
        $format = $ti->{format} || 0;

        # Make sure we update the topic format for when we save
        $ti->{format} = Foswiki::Meta::EMBEDDING_FORMAT_VERSION;

        # Clean up SVN and other malformed rev nums. This can happen
        # when old code (e.g. old plugins) generated the meta.
        $ti->{version} = Foswiki::Store::cleanUpRevID( $ti->{version} );
        $ti->{rev} = $ti->{version};    # not used, maintained for compatibility
        $ti->{reprev} = Foswiki::Store::cleanUpRevID( $ti->{reprev} )
          if defined $ti->{reprev};
    }
    else {

        #defaults..
    }

    # Other meta-data
    my $endMeta = 0;
    if ( $format !~ /^[\d.]+$/ || $format < 1.1 ) {
        require Foswiki::Compatibility;
        if (
            $text =~ s/^%META:([^{]+)\{(.*)\}%\n/
              Foswiki::Compatibility::readSymmetricallyEncodedMETA(
                  $meta, $1, $2 ); ''/gem
          )
        {
            $endMeta = 1;
        }
    }
    else {
        if (
            $text =~ s<^(%META:([^{]+)\{(.*)\}%\n)>
                      <_readMETA($meta, $1, $2, $3, 0)>gem
          )
        {
            $endMeta = 1;
        }
    }

    # eat extra newlines put in to separate text from tail meta-data
    $text =~ s/\n$//s if $endMeta;

    # If there is no meta data then convert from old format
    if ( !$meta->count('TOPICINFO') ) {

        # The T-word string must remain unchanged for the compatibility
        if ( $text =~ m/<!--TWikiAttachment-->/ ) {
            require Foswiki::Compatibility;
            $text = Foswiki::Compatibility::migrateToFileAttachmentMacro(
                $meta->{_session}, $meta, $text );
        }

        # The T-word string must remain unchanged for the compatibility
        if ( $text =~ m/<!--TWikiCat-->/ ) {
            require Foswiki::Compatibility;
            $text =
              Foswiki::Compatibility::upgradeCategoryTable( $meta->{_session},
                $meta->{_web}, $meta->{_topic}, $meta, $text );
        }
    }
    elsif ( $format eq '1.0beta' ) {
        require Foswiki::Compatibility;

        # This format used live at DrKW for a few months
        # The T-word string must remain unchanged for the compatibility
        if ( $text =~ m/<!--TWikiCat-->/ ) {
            $text =
              Foswiki::Compatibility::upgradeCategoryTable( $meta->{_session},
                $meta->{_web}, $meta->{_topic}, $meta, $text );
        }
        Foswiki::Compatibility::upgradeFrom1v0beta( $meta->{_session}, $meta );
        if ( $meta->count('TOPICMOVED') ) {
            my $moved = $meta->get('TOPICMOVED');
            $meta->put( 'TOPICMOVED', $moved );
        }
    }

    if ( $format !~ /^[\d.]+$/ || $format < 1.1 ) {

        # compatibility; topics version 1.0 and earlier equivalenced tab
        # with three spaces. Respect that.
        $text =~ s/\t/   /g;
    }

    $meta->text($text);
}

# STATIC Build a hash by parsing name=value comma separated pairs
# SMELL: duplication of Foswiki::Attrs, using a different
# system of escapes :-(
sub _readKeyValues {
    my ($args) = @_;
    my %res;

    # Format of data is name='value' name1='value1' [...]
    $args =~ s/\s*([^=]+)="([^"]*)"/
      $res{$1} = Foswiki::Meta::dataDecode( $2 ), ''/ge;

    return \%res;
}

sub _readMETA {
    my ( $meta, $expr, $type, $args, $readTOPICINFO ) = @_;
    return $expr if $type eq 'TOPICINFO' && !$readTOPICINFO;
    my $keys = _readKeyValues($args);
    if ( Foswiki::Meta::isValidEmbedding( $type, $keys ) ) {
        if ( defined( $keys->{name} ) ) {

            # save it keyed if it has a name
            $meta->putKeyed( $type, $keys );
        }
        else {
            $meta->put( $type, $keys );
        }
        return '';
    }
    else {
        return $expr;
    }
}

# PRIVATE STATIC Write a meta-data key=value pair
# The encoding is reversed in _readKeyValues
sub _writeKeyValue {
    my ( $key, $value ) = @_;

    if ( defined($value) ) {
        $value = dataEncode($value);
    }
    else {
        $value = '';
    }

    return $key . '="' . $value . '"';
}

# PRIVATE STATIC: Write all the key=value pairs for the types listed
sub _writeTypes {
    my ( $meta, @types ) = @_;

    my $text = '';

    if ( $types[0] eq 'not' ) {

        # write all types that are not in the list
        my %seen;
        @seen{@types} = ();
        @types = ();    # empty "not in list"
        foreach my $key ( keys %$meta ) {
            push( @types, $key )
              unless ( exists $seen{$key} || $key =~ m/^_/ );
        }
    }

    foreach my $type (@types) {
        next if ( $type =~ m/^_/ );
        my $data = $meta->{$type};
        next if !defined $data;
        foreach my $item (@$data) {
            next if ( $item =~ m/^_/ );
            my $sep = '';
            $text .= '%META:' . $type . '{';
            my $name = $item->{name};
            if ($name) {

                # If there's a name field, put first to make regexp
                # based searching easier
                $text .= _writeKeyValue( 'name', $item->{name} );
                $sep = ' ';
            }
            foreach my $key ( sort keys %$item ) {

                #next if ($key =~ m/^_/ );
                if ( $key ne 'name' ) {
                    $text .= $sep;
                    $text .= _writeKeyValue( $key, $item->{$key} );
                    $sep = ' ';
                }
            }
            $text .= '}%' . "\n";
        }
    }

    return $text;
}

=begin TML

---++ StaticMethod dataEncode( $uncoded ) -> $coded

Encode meta-data field values, escaping out selected characters.
The encoding is chosen to avoid problems with parsing the attribute
values in embedded meta-data, while minimising the number of
characters encoded so searches can still work (fairly) sensibly.

The encoding has to be exported because Foswiki (and plugins) use
encoded field data in other places e.g. RDiff, mainly as a shorthand
for the properly parsed meta object. Some day we may be able to
eliminate that....

=cut

sub dataEncode {
    my $datum = shift;

    $datum =~ s/([%"\r\n{}])/'%'.sprintf('%02x',ord($1))/ge;
    return $datum;
}

1;
__END__
Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/, http://Foswiki.org/

Copyright (C) 2008-2014 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2001-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
