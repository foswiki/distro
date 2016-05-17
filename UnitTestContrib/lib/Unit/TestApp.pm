# See bottom of file for license and copyright

package Unit::TestApp;
use v5.14;

use Scalar::Util qw(blessed);

use Moo;
use namespace::clean;
extends qw(Foswiki::App);

#with qw(Foswiki::Aux::Localize);

#sub setLocalizableAttributes {
#    return
#        qw(
#          access attach cache cfg env forms
#          logger engine heap i18n plugins prefs
#          renderer request _requestParams response
#          search store templates macros context
#          ui remoteUser user users zones _dispatcherAttrs
#          )
#    ;
#}

sub BUILD {
    my $this = shift;

    # Fixup Foswiki::AppObject descendants which have been cloned from objects
    # on another Foswiki::App instance.
    foreach my $attr ( keys %$this ) {
        if (
               blessed( $this->{$attr} )
            && $this->$attr->isa('Foswiki::Object')
            && $this->$attr->does('Foswiki::AppObject')
            && ( !defined( $this->$attr->app )
                || ( $this->$attr->app != $this ) )
          )
        {
            $this->$attr->_set_app($this);
        }
    }
}

=begin TML

---++ ObjectMethod cloneEnv => \%envHash

Clones current application =env= hash.

=cut

sub cloneEnv {
    my $this = shift;

    # SMELL Use Foswiki::Object internals.
    return $this->_cloneData( $this->env, 'env' );
}

1;

__DATA__

Author: Crawford Currie, http://c-dot.co.uk

Copyright (C) 2007-2016 Foswiki Contributors
All Rights Reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
