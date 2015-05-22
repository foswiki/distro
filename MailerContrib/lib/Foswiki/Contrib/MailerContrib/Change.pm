# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Contrib::MailerContrib::Change
Object that represents a change to a topic.

=cut

package Foswiki::Contrib::MailerContrib::Change;

use strict;
use warnings;
use Assert;

use Foswiki          ();
use Foswiki::Plugins ();
use Foswiki::Time    ();

=begin TML

---++ new($web, $topic, $author, $time, $rev)
   * =$web= - Web name
   * =$topic= - Topic name
   * =$author= - String author of change
   * =$time= - String time of change
   * =$rev= - Revision identifier
Construct a new change object.

=cut

sub new {
    my ( $class, $web, $topic, $author, $time, $rev ) = @_;

    my $this = bless( {}, $class );

    $this->{WEB}   = $web;
    $this->{TOPIC} = $topic;
    my $user;

    $this->{AUTHOR} = Foswiki::Func::getWikiName($author);

    $this->{TIME} = $time;
    ASSERT( defined $rev ) if DEBUG;

    # rev at this change
    $this->{CURR_REV} = $rev;

    # previous rev
    $this->{BASE_REV} = $rev - 1 || 1;

    return $this;
}

sub stringify {
    my $this = shift;

    return
"$this->{WEB}.$this->{TOPIC} by $this->{AUTHOR} at $this->{TIME} from r$this->{BASE_REV} to r$this->{CURR_REV}";
}

=begin TML

---++ merge($change)
   * =$change= - Change record to merge
Merge another change record with this one, so that the combined
record is a reflection of both changes.

=cut

sub merge {
    my ( $this, $other ) = @_;
    ASSERT( $this->isa('Foswiki::Contrib::MailerContrib::Change') )  if DEBUG;
    ASSERT( $other->isa('Foswiki::Contrib::MailerContrib::Change') ) if DEBUG;

    if ( $other->{TIME} > $this->{TIME} ) {
        $this->{CURR_REV} = $other->{CURR_REV};
        $this->{AUTHOR}   = $other->{AUTHOR};
        $this->{TIME}     = $other->{TIME};
    }

    $this->{BASE_REV} = $other->{BASE_REV}
      if ( $other->{BASE_REV} < $this->{BASE_REV} );
}

=begin TML

---++ expandHTML($template) -> string

   * =$template= - Template to expand keys within

Expand an HTML template using the values in this change. The following
keys are expanded: %<nop>WEB%, %<nop>TOPIC%, %<nop>AUTHOR%, %<nop>TIME%,
%<nop>REVISION%, %<nop>BASE_REV%, %<nop>CUR_REV%, %<nop>TEXTHEAD%.

Returns the expanded template.

=cut

sub expandHTML {
    my ( $this, $template ) = @_;

    unless ( defined $this->{HTML_SUMMARY} ) {
        if ( defined &Foswiki::Func::summariseChanges ) {
            $this->{HTML_SUMMARY} =
              Foswiki::Func::summariseChanges( $this->{WEB}, $this->{TOPIC},
                $this->{BASE_REV}, $this->{CURR_REV}, 1, 1 );
        }
        else {
            $this->{HTML_SUMMARY} =
              $Foswiki::Plugins::SESSION->{renderer}
              ->summariseChanges( undef, $this->{WEB}, $this->{TOPIC},
                $this->{BASE_REV}, $this->{CURR_REV}, 1 );
        }
    }

    $template = $this->expandVariables($template);

    $template =
      Foswiki::Func::expandCommonVariables( $template, $this->{TOPIC},
        $this->{WEB} );
    $template = Foswiki::Func::renderText($template);

    $template =~ s/%TEXTHEAD%/$this->{HTML_SUMMARY}/g;

    return $template;
}

=begin TML

---++ expandPlain() -> string
Generate a plaintext version of this change.

=cut

sub expandPlain {
    my ( $this, $template ) = @_;

    unless ( defined $this->{TEXT_SUMMARY} ) {
        my $s;
        if ( defined &Foswiki::Func::summariseChanges ) {
            $s =
              Foswiki::Func::summariseChanges( $this->{WEB}, $this->{TOPIC},
                $this->{BASE_REV}, $this->{CURR_REV}, 0, 1 );
        }
        else {
            $s =
              $Foswiki::Plugins::SESSION->{renderer}
              ->summariseChanges( undef, $this->{WEB}, $this->{TOPIC},
                $this->{BASE_REV}, $this->{CURR_REV}, 0 );
        }
        $s =~ s/\n/\n   /gs;
        $s = "   $s";
        $this->{TEXT_SUMMARY} = $s;
    }

    return $this->expandVariables( $template, 'TEXT_SUMMARY' );
}

=begin TML

---++ expandDiff($template) -> string
Generate a unified diff version of this change.

=cut

sub expandDiff {
    my ( $this, $template ) = @_;

    unless ( $this->{TEXT_DIFF} ) {
        my $b =
          Foswiki::Meta->load( $Foswiki::Plugins::SESSION, $this->{WEB},
            $this->{TOPIC}, $this->{CURR_REV} );
        return '' unless ( $b->haveAccess('VIEW') );
        my $btext = Foswiki::Serialise::serialise( $b, 'Embedded' );
        $btext =~ s/^%META:TOPICINFO\{.*\}%$//;

        return $btext if ( $this->{BASE_REV} < 1 );

        my $a =
          Foswiki::Meta->load( $Foswiki::Plugins::SESSION, $this->{WEB},
            $this->{TOPIC}, $this->{BASE_REV} );
        return '' unless ( $a->haveAccess('VIEW') );
        my $atext = Foswiki::Serialise::serialise( $a, 'Embedded' );
        $atext =~ s/^%META:TOPICINFO\{.*\}%$//;

        require Foswiki::Merge;
        my $blocks = Foswiki::Merge::simpleMerge( $atext, $btext, qr/[\r\n]+/ );
        $this->{TEXT_DIFF} =
          '<verbatim>' . join( "\n", @$blocks ) . '</verbatim>';
    }

    return $this->expandVariables( $template, 'TEXT_DIFF' );
}

=begin TML

---++ expandVariables($template, $textHeadAttr) -> string

Expand an template using the values in this change. The following
keys are expanded: 

   * %<nop>AUTHOR%
   * %<nop>BASE_REV%
   * %<nop>CUR_REV%
   * %<nop>REVISION%
   * %<nop>TEXTHEAD%
   * %<nop>TIME%
   * %<nop>TOPIC%
   * %<nop>WEB%

=cut

sub expandVariables {
    my ( $this, $template, $textHeadAttr ) = @_;

    my $tim = Foswiki::Time::formatTime( $this->{TIME} );

    # URL-encode topic names for use of I18N topic names in plain text
    # DEPRECATED! DO NOT USE!
    $template =~ s#%URL%#%SCRIPTURL{view}%/%ENCODE{%WEB%}%/%ENCODE{%TOPIC%}%#g;

    $template =~ s/%AUTHOR%/$this->{AUTHOR}/g;
    $template =~ s/%BASE_REV%/$this->{BASE_REV}/g;
    $template =~ s/%CUR_REV%/$this->{CURR_REV}/g;
    $template =~ s/%TIME%/$tim/g;
    $template =~ s/%WEB%/$this->{WEB}/g;
    $template =~ s/%TOPIC%/$this->{TOPIC}/g;
    $template =~ s/%TOPICNAME%/$this->{TOPIC}/g;     # deprecated DO NOT USE!

    my $frev = '';

    if ( $this->{CURR_REV} ) {

        if ( $this->{CURR_REV} > 1 ) {
            $frev = 'r' . $this->{BASE_REV} . '->r' . $this->{CURR_REV};
        }
        else {

            # new _since the last notification_
            $frev = 'NEW';
        }
    }

    $template =~ s/%REVISION%/$frev/g;
    $template =~ s/%TEXTHEAD%/$this->{$textHeadAttr}/g if defined $textHeadAttr;

    return $template;
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
