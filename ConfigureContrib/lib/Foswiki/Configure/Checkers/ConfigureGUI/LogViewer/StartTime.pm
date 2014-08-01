# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::ConfigureGUI::LogViewer::StartTime;

use warnings;
use strict;

use Foswiki::Configure qw/:cgi/;

use Foswiki::Configure::Checkers::DATE;
our @ISA = qw/Foswiki::Configure::Checkers::DATE/;

sub check {
    my $this = shift;
    my ($valobj) = @_;

    my $keys = ref $valobj ? $valobj->{keys} : $valobj;

    my $value =
        $query->request_method eq 'POST'
      ? $query->param($keys)
      : $this->getCfgUndefOk($keys);

    $this->setItemValue( $value, $keys );
    return $this->SUPER::check(@_);
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2013 Foswiki Contributors. Foswiki Contributors
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
# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::ConfigureGUI::LogViewer::StartTime;

use warnings;
use strict;

use Foswiki::Configure qw/:cgi/;

use Foswiki::Configure::Checkers::DATE;
our @ISA = qw/Foswiki::Configure::Checkers::DATE/;

sub check {
    my $this = shift;
    my ($valobj) = @_;

    my $keys = ref $valobj ? $valobj->{keys} : $valobj;

    my $value = $query->request_method eq 'POST'? $query->param($keys) : $this->getCfgUndefOk($keys);

    $this->setItemValue( $value, $keys );
    return $this->SUPER::check(@_);
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2013 Foswiki Contributors. Foswiki Contributors
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
# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::ConfigureGUI::LogViewer::StartTime;

use warnings;
use strict;

use Foswiki::Configure qw/:cgi/;

use Foswiki::Configure::Checkers::DATE;
our @ISA = qw/Foswiki::Configure::Checkers::DATE/;

sub check {
    my $this = shift;
    my ($valobj) = @_;

    my $keys = ref $valobj ? $valobj->{keys} : $valobj;

    my $value = $query->request_method eq 'POST'? $query->param($keys) : $this->getCfgUndefOk($keys);

    $this->setItemValue( $value, $keys );
    return $this->SUPER::check(@_);
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2013 Foswiki Contributors. Foswiki Contributors
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
# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::ConfigureGUI::LogViewer::StartTime;

use warnings;
use strict;

use Foswiki::Configure qw/:cgi/;

use Foswiki::Configure::Checkers::DATE;
our @ISA = qw/Foswiki::Configure::Checkers::DATE/;

sub check {
    my $this = shift;
    my ($valobj) = @_;

    my $keys = ref $valobj ? $valobj->{keys} : $valobj;

    my $value = $query->request_method eq 'POST'? $query->param($keys) : $this->getCfgUndefOk($keys);

    $this->setItemValue( $value, $keys );
    return $this->SUPER::check(@_);
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2013 Foswiki Contributors. Foswiki Contributors
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
