# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Contrib::MailerContrib::UpData
Object that lazy-scans topics to extract
parent relationships.

=cut

package Foswiki::Contrib::MailerContrib::UpData;

use strict;
use warnings;

=begin TML

---++ new($web)
   * =$web= - Web we are building parent relationships for
Constructor for a web; initially empty, will lazy-load as topics
are referenced.

=cut

sub new {
    my ( $class, $web ) = @_;
    my $this = bless( { web => $web }, $class );

    return $this;
}

=begin TML

---++ getParent($topic) -> string
Get the name of the parent topic of the given topic

=cut

sub getParent {
    my ( $this, $topic ) = @_;

    if ( !defined( $this->{parent}{$topic} ) ) {
        my ( $meta, $text ) = Foswiki::Func::readTopic( $this->{web}, $topic );
        my $parent = $meta->get('TOPICPARENT');
        $this->{parent}{$topic} = $parent->{name} if $parent;
        $this->{parent}{$topic} ||= '';
    }

    return $this->{parent}{$topic};
}

1;
__END__
Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2009 Foswiki Contributors. All Rights Reserved.
Foswiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 1999-2006 TWiki Contributors.
Copyright (C) 2004 Wind River Systems Inc.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
