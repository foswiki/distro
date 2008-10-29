# See bottom of file for copyright and license details

=begin twiki

---+ package TWiki::If::OP_allows

=cut

package TWiki::If::OP_allows;
use base 'TWiki::Query::BinaryOP';

use strict;

sub new {
    my $class = shift;
    return $class->SUPER::new( name => 'allows', prec => 600 );
}

sub evaluate {
    my $this = shift;
    my $node = shift;
    my $a = $node->{params}->[0]; # topic name (string)
    my $b = $node->{params}->[1]; # access mode (string)
    my $mode = $b->_evaluate(@_) || 'view';
    my %domain = @_;
    my $session = $domain{tom}->session;
    throw Error::Simple('No context in which to evaluate "'.
                          $a->stringify().'"') unless $session;
    my $str = $a->evaluate(@_);
    return 0 unless $str;
    my ($web, $topic) = $session->normalizeWebTopicName(
        $session->{webName}, $str);
    my $ok = 0;
    if ($session->{store}->topicExists($web, $topic)) {
        #try the non-precise name as an existant topic first.
        $ok = $session->security->checkAccessPermission(
            uc($mode), $session->{user}, undef, undef, $topic, $web);
    } elsif ($session->{store}->webExists($str)) {
        $ok = $session->security->checkAccessPermission(
            uc($mode), $session->{user}, undef, undef, undef, $str);
    } elsif ($session->{store}->webExists($web)) {
        #not an existing topic or web - assume any lone name is a topic without a web specified
        $ok = $session->security->checkAccessPermission(
            uc($mode), $session->{user}, undef, undef, $topic, $web);
    } else {
    	$ok = 0;
    }
    return $ok ? 1 : 0;
}

1;

__DATA__

Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/

Copyright (C) 2005-2007 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root of
this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.

Author: Crawford Currie http://c-dot.co.uk
# See bottom of file for copyright and license details

=begin twiki

---+ package TWiki::If::OP_allows

=cut

package TWiki::If::OP_allows;
use base 'TWiki::Query::BinaryOP';

use strict;

sub new {
    my $class = shift;
    return $class->SUPER::new( name => 'allows', prec => 600 );
}

sub evaluate {
    my $this = shift;
    my $node = shift;
    my $a = $node->{params}->[0]; # topic name (string)
    my $b = $node->{params}->[1]; # access mode (string)
    my $mode = $b->_evaluate(@_) || 'view';
    my %domain = @_;
    my $session = $domain{tom}->session;
    throw Error::Simple('No context in which to evaluate "'.
                          $a->stringify().'"') unless $session;
    my $str = $a->evaluate(@_);
    return 0 unless $str;
    my ($web, $topic) = $session->normalizeWebTopicName(
        $session->{webName}, $str);
    my $ok = 0;
    if ($session->{store}->topicExists($web, $topic)) {
        #try the non-precise name as an existant topic first.
        $ok = $session->security->checkAccessPermission(
            uc($mode), $session->{user}, undef, undef, $topic, $web);
    } elsif ($session->{store}->webExists($str)) {
        $ok = $session->security->checkAccessPermission(
            uc($mode), $session->{user}, undef, undef, undef, $str);
    } elsif ($session->{store}->webExists($web)) {
        #not an existing topic or web - assume any lone name is a topic without a web specified
        $ok = $session->security->checkAccessPermission(
            uc($mode), $session->{user}, undef, undef, $topic, $web);
    } else {
    	$ok = 0;
    }
    return $ok ? 1 : 0;
}

1;

__DATA__

Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/

Copyright (C) 2005-2007 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root of
this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.

Author: Crawford Currie http://c-dot.co.uk
# See bottom of file for copyright and license details

=begin twiki

---+ package TWiki::If::OP_allows

=cut

package TWiki::If::OP_allows;
use base 'TWiki::Query::BinaryOP';

use strict;

sub new {
    my $class = shift;
    return $class->SUPER::new( name => 'allows', prec => 600 );
}

sub evaluate {
    my $this = shift;
    my $node = shift;
    my $a = $node->{params}->[0]; # topic name (string)
    my $b = $node->{params}->[1]; # access mode (string)
    my $mode = $b->_evaluate(@_) || 'view';
    my %domain = @_;
    my $session = $domain{tom}->session;
    throw Error::Simple('No context in which to evaluate "'.
                          $a->stringify().'"') unless $session;
    my $str = $a->evaluate(@_);
    return 0 unless $str;
    my ($web, $topic) = $session->normalizeWebTopicName(
        $session->{webName}, $str);
    my $ok = 0;
    if ($session->{store}->topicExists($web, $topic)) {
        #try the non-precise name as an existant topic first.
        $ok = $session->security->checkAccessPermission(
            uc($mode), $session->{user}, undef, undef, $topic, $web);
    } elsif ($session->{store}->webExists($str)) {
        $ok = $session->security->checkAccessPermission(
            uc($mode), $session->{user}, undef, undef, undef, $str);
    } elsif ($session->{store}->webExists($web)) {
        #not an existing topic or web - assume any lone name is a topic without a web specified
        $ok = $session->security->checkAccessPermission(
            uc($mode), $session->{user}, undef, undef, $topic, $web);
    } else {
    	$ok = 0;
    }
    return $ok ? 1 : 0;
}

1;

__DATA__

Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/

Copyright (C) 2005-2007 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root of
this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.

Author: Crawford Currie http://c-dot.co.uk
