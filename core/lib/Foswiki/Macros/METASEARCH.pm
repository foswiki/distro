# See bottom of file for license and copyright information
package Foswiki;

use strict;
use warnings;

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

# DEPRECATED

# callback for search function to collate results
sub _collate {
    my $ref = shift;

    $$ref .= join( ' ', @_ );
}

sub METASEARCH {
    my ( $this, $params, $topicObject ) = @_;

    my $attrType  = $params->{type}  || 'FIELD';
    my $attrWeb   = $params->{web}   || $this->{webName};
    my $attrTopic = $params->{topic} || $this->{topicName};

    my $searchVal = 'XXX';

    if ( $attrType eq 'parent' ) {
        $searchVal =
          "%META:TOPICPARENT[{].*name=\\\"($attrWeb\\.)?$attrTopic\\\".*[}]%";
    }
    elsif ( $attrType eq 'topicmoved' ) {
        $searchVal =
          "%META:TOPICMOVED[{].*from=\\\"$attrWeb\.$attrTopic\\\".*[}]%";
    }
    else {
        $searchVal = "%META:" . uc($attrType) . "[{].*";
        $searchVal .= "name=\\\"$params->{name}\\\".*"
          if ( defined $params->{name} );
        $searchVal .= "value=\\\"$params->{value}\\\".*"
          if ( defined $params->{value} );
        $searchVal .= "[}]%";
    }

    my $text = '';
    if ( $params->{format} ) {
        $text = $this->search->searchWeb(
            format    => $params->{format},
            search    => $searchVal,
            web       => $attrWeb,
            type      => 'regex',
            nosummary => 'on',
            nosearch  => 'on',
            noheader  => 'on',
            nototal   => 'on',
            noempty   => 'on',
            template  => 'searchmeta',
        );
    }
    else {
        $this->search->searchWeb(
            _callback => \&_collate,
            _cbdata   => \$text,
            ,
            search    => $searchVal,
            web       => $attrWeb,
            type      => 'regex',
            nosummary => 'on',
            nosearch  => 'on',
            noheader  => 'on',
            nototal   => 'on',
            noempty   => 'on',
            template  => 'searchmeta',
        );
    }
    my $attrTitle = $params->{title} || '';
    if ($text) {
        $text = $attrTitle . $text;
    }
    else {
        my $attrDefault = $params->{default} || '';
        $text = $attrTitle . $attrDefault;
    }

    return $text;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2007 TWiki Contributors. 
All Rights Reserved. TWiki Contributors
are listed in the AUTHORS file in the root of this distribution.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
