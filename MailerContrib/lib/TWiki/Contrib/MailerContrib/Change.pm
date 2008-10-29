# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2004 Wind River Systems Inc.
# Copyright (C) 1999-2006 TWiki Contributors.
# All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
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

use strict;

=pod

---+ package TWiki::Contrib::MailerContrib::Change
Object that represents a change to a topic.

=cut

package TWiki::Contrib::MailerContrib::Change;

use TWiki;

use URI::Escape;
use Assert;

=pod

---++ new($web)
   * =$web= - Web name
   * =$topic= - Topic name
   * =$author= - String author of change
   * =$time= - String time of change
   * =$rev= - Revision identifier
Construct a new change object.

=cut

sub new {
    my ( $class, $session, $web, $topic, $author, $time, $rev ) = @_;

    my $this = bless( {}, $class );

    $this->{SESSION} = $session;
    $this->{WEB} = $web;
    $this->{TOPIC} = $topic;
    my $user;
    # SMELL: call to unpublished core function
    if (defined(&TWiki::Users::findUser)) {
        $user = $session->{users}->findUser( $author, undef, 1 );
        $this->{AUTHOR} = $user ? $user->wikiName() : $author;
    } else {
        $this->{AUTHOR} = TWiki::Func::getWikiName($author);
    }
    $this->{TIME} = $time;
    ASSERT($rev) if DEBUG;
    # rev at this change
    $this->{CURR_REV} = $rev;
    # previous rev
    $this->{BASE_REV} = $rev - 1 || 1;

    return $this;
}

sub stringify {
    my $this = shift;

    return "$this->{WEB}.$this->{TOPIC} by $this->{AUTHOR} at $this->{TIME} from r$this->{BASE_REV} to r$this->{CURR_REV}";
}

=pod

---++ merge($change)
   * =$change= - Change record to merge
Merge another change record with this one, so that the combined
record is a reflection of both changes.

=cut

sub merge {
    my( $this, $other ) = @_;
    ASSERT($this->isa( 'TWiki::Contrib::MailerContrib::Change' )) if DEBUG;
    ASSERT($other->isa( 'TWiki::Contrib::MailerContrib::Change' )) if DEBUG;

    if( $other->{CURR_REV} > $this->{CURR_REV} ) {
        $this->{CURR_REV} = $other->{CURR_REV};
        $this->{AUTHOR} = $other->{AUTHOR};
        $this->{TIME} = $other->{TIME};
    }

    $this->{BASE_REV} = $other->{BASE_REV}
      if($other->{BASE_REV} < $this->{BASE_REV});
}

=pod

---++ expandHTML($html) -> string
   * =$html= - Template to expand keys within
Expand an HTML template using the values in this change. The following
keys are expanded: %<nop>TOPICNAME%, %<nop>AUTHOR%, %<nop>TIME%,
%<nop>REVISION%, %<nop>BASE_REV%, %<nop>CUR_REV%, %<nop>TEXTHEAD%.

Returns the expanded template.

=cut

sub expandHTML {
    my ( $this, $html ) = @_;

    unless( defined $this->{HTML_SUMMARY} ) {
        if( defined &TWiki::Func::summariseChanges ) {
            $this->{HTML_SUMMARY} =
              TWiki::Func::summariseChanges(
                  $this->{WEB}, $this->{TOPIC}, $this->{BASE_REV},
                  $this->{CURR_REV}, 1 );
        } else {
            $this->{HTML_SUMMARY} =
              $this->{SESSION}->{renderer}->summariseChanges
                ( undef, $this->{WEB}, $this->{TOPIC}, $this->{BASE_REV},
                  $this->{CURR_REV}, 1 );
        }
    }

    $html =~ s/%TOPICNAME%/$this->{TOPIC}/g;
    $html =~ s/%AUTHOR%/$this->{AUTHOR}/g;
    my $tim =  TWiki::Time::formatTime( $this->{TIME} );
    $html =~ s/%TIME%/$tim/go;
    $html =~ s/%CUR_REV%/$this->{CURR_REV}/g;
    $html =~ s/%BASE_REV%/$this->{BASE_REV}/g;
    my $frev = '';
    if( $this->{CURR_REV} ) {
        if( $this->{CURR_REV} > 1 ) {
            $frev = 'r'.$this->{BASE_REV}.
              '-&gt;r'.$this->{CURR_REV};
        } else {
            # new _since the last notification_
            $frev = CGI::span( { class=>'twikiNew' }, 'NEW' );
        }
    }
    $html =~ s/%REVISION%/$frev/g;
    $html = TWiki::Func::expandCommonVariables(
        $html, $this->{TOPIC}, $this->{WEB} );
    $html = TWiki::Func::renderText( $html );
    $html =~ s/%TEXTHEAD%/$this->{HTML_SUMMARY}/g;

    return $html;
}

=pod

---++ expandPlain() -> string
Generate a plaintext version of this change.

=cut

sub expandPlain {
    my ( $this, $template ) = @_;

    unless( defined $this->{TEXT_SUMMARY} ) {
        my $s;
        if( defined &TWiki::Func::summariseChanges ) {
            $s = TWiki::Func::summariseChanges(
                $this->{WEB}, $this->{TOPIC}, $this->{BASE_REV},
                $this->{CURR_REV}, 0 );
        } else {
            $s = $this->{SESSION}->{renderer}->summariseChanges(
                undef, $this->{WEB}, $this->{TOPIC}, $this->{BASE_REV},
                $this->{CURR_REV}, 0 );
        }
        $s =~ s/\n/\n   /gs;
        $s = "   $s";
        $this->{TEXT_SUMMARY} = $s;
    }

    my $tim =  TWiki::Time::formatTime( $this->{TIME} );

    # URL-encode topic names for use of I18N topic names in plain text
    # DEPRECATED! DO NOT USE!
    $template =~ s#%URL%#%SCRIPTURL{view}%/%ENCODE{%WEB%}%/%ENCODE{%TOPIC%}%#g;

    $template =~ s/%AUTHOR%/$this->{AUTHOR}/g;
    $template =~ s/%TIME%/$tim/g;
    $template =~ s/%CUR_REV%/$this->{CURR_REV}/g;
    $template =~ s/%BASE_REV%/$this->{BASE_REV}/g;
    $template =~ s/%TOPICNAME%/$this->{TOPIC}/g; # deprecated DO NOT USE!
    $template =~ s/%TOPIC%/$this->{TOPIC}/g;
    my $frev = '';
    if( $this->{CURR_REV} ) {
        if( $this->{CURR_REV} > 1 ) {
            $frev = 'r'.$this->{BASE_REV}.
              '->r'.$this->{CURR_REV};
        } else {
            # new _since the last notification_
            $frev = 'NEW';
        }
    }
    $template =~ s/%REVISION%/$frev/g;

    $template =~ s/%TEXTHEAD%/$this->{TEXT_SUMMARY}/g;
    return $template;
}

1;
