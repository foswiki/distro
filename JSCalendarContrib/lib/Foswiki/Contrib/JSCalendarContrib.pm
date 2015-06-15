# See bottom of file for license and copyright information

=begin TML

Read [[%ATTACHURL%/doc/html/reference.html][the Mishoo documentation]] or
[[%ATTACHURL%][visit the demo page]] for detailed information on using the
calendar widget.

This package also includes a small Perl module to make using the calendar
easier from Foswiki plugins. This module includes the functions:

=cut

package Foswiki::Contrib::JSCalendarContrib;

use strict;
use warnings;

use Foswiki::Func ();    # The plugins API

our $VERSION = '1.55';
our $RELEASE = '1.55';
our $SHORTDESCRIPTION =
"[[http://dynarch.com/mishoo/calendar.epl][Mishoo JSCalendar]] date and time picker, packaged for use by plugins, skins and add-ons";

# Max width of different mishoo format components
my %w = (
    'a' => 3,            # abbreviated weekday name
    'A' => 9,            # full weekday name
    'b' => 3,            # abbreviated month name
    'B' => 9,            # full month name
    'C' => 2,            # century number
    'd' => 2,            # the day of the month ( 00 .. 31 )
    'e' => 2,            # the day of the month ( 0 .. 31 )
    'H' => 2,            # hour ( 00 .. 23 )
    'I' => 2,            # hour ( 01 .. 12 )
    'j' => 3,            # day of the year ( 000 .. 366 )
    'k' => 2,            # hour ( 0 .. 23 )
    'l' => 2,            # hour ( 1 .. 12 )
    'm' => 2,            # month ( 01 .. 12 )
    'M' => 2,            # minute ( 00 .. 59 )
    'n' => 1,            # a newline character
    'p' => 2,            # 'PM' or 'AM'
    'P' => 2,            # 'pm' or 'am'
    'S' => 2,            # second ( 00 .. 59 )
    's' => 12,           # number of seconds since Epoch
    't' => 1,            # a tab character
    'U' => 2,            # the week number
    'u' => 1,            # the day of the week ( 1 .. 7, 1 = MON )
    'W' => 2,            # the week number
    'w' => 1,            # the day of the week ( 0 .. 6, 0 = SUN )
    'V' => 2,            # the week number
    'y' => 2,            # year without the century ( 00 .. 99 )
    'Y' => 4,            # year including the century ( ex. 1979 )
);

=begin TML

---+++ Foswiki::Contrib::JSCalendarContrib::renderDateForEdit($name, $value, $format [, \%cssClass]) -> $html

This is the simplest way to use calendars from a plugin.
   * =$name= is the name of the CGI parameter for the calendar
     (it should be unique),
   * =$value= is the current value of the parameter (may be undef)
   * =$format= is the format to use (optional; the default is set
     in =configure=). The HTML returned will display a date field
     and a drop-down calendar.
   * =\%options= is an optional hash containing base options for
     the textfield.
Example:
<verbatim>
use Foswiki::Contrib::JSCalendarContrib ();
...
my $fromDate = Foswiki::Contrib::JSCalendarContrib::renderDateForEdit(
   'from', '1 April 1999');
my $toDate = Foswiki::Contrib::JSCalendarContrib::renderDateForEdit(
   'to', undef, '%Y');
</verbatim>

=cut

sub renderDateForEdit {
    my ( $name, $value, $format, $options ) = @_;

    $format ||=
         Foswiki::Func::getPreferencesValue('JSCALENDARCONTRIB_FORMAT')
      || $Foswiki::cfg{JSCalendarContrib}{format}
      || '%e %b %Y';

    addHEAD('foswiki');

    # Work out how wide it has to be from the format
    # SMELL: add a space because pattern skin default fonts on FF make the
    # box half a character too narrow if the exact size is used
    my $wide = $format . ' ';
    $wide =~ s/(%(.))/$w{$2} ? ('_' x $w{$2}) : $1/ge;
    $options ||= {};
    $options->{name}  = $name;
    $options->{id}    = 'id_' . $name;
    $options->{value} = $value || '';
    $options->{size} ||= length($wide);

    return CGI::textfield($options)
      . CGI::image_button(
        -name    => 'img_' . $name,
        -onclick => "javascript: return showCalendar('id_$name','$format')",
        -src     => Foswiki::Func::getPubUrlPath() . '/'
          . $Foswiki::cfg{SystemWebName}
          . '/JSCalendarContrib/img.gif',
        -alt   => 'Calendar',
        -align => 'middle'
      );
}

=begin TML

---+++ Foswiki::Contrib::JSCalendarContrib::addHEAD($setup)

This function will automatically add the headers for the calendar to the page
being rendered. It's intended for use when you want more control over the
formatting of your calendars than =renderDateForEdit= affords. =$setup= is
the name of
the calendar setup module; it can either be omitted, in which case the method
described in the Mishoo documentation can be used to create calendars, or it
can be ='foswiki'=, in which case a Javascript helper function called
'showCalendar' is added that simplifies using calendars to set a value in a
text field. For example, say we wanted to display the date with the calendar
icon _before_ the text field, using the format =%Y %b %e=
<verbatim>
# Add styles and javascript for the calendar
use Foswiki::Contrib::JSCalendarContrib ();
...

sub commonTagsHandler {
  ....
  # Enable 'showCalendar'
  Foswiki::Contrib::JSCalendarContrib::addHEAD( 'foswiki' );

  my $cal = CGI::image_button(
      -name => 'img_datefield',
      -onclick =>
       "return showCalendar('id_datefield','%Y %b %e')",
      -src=> Foswiki::Func::getPubUrlPath() . '/' .
             $Foswiki::cfg{SystemWebName} .
             '/JSCalendarContrib/img.gif',
      -alt => 'Calendar',
      -align => 'middle' )
    . CGI::textfield(
      { name => 'date', id => "id_datefield" });
  ....
}
</verbatim>
The first parameter to =showCalendar= is the id of the textfield, and the second parameter is the date format. Default format is '%e %B %Y'.

#FormatSpecifiers
All available date specifiers:
<verbatim>
%a - abbreviated weekday name 
%A - full weekday name 
%b - abbreviated month name 
%B - full month name 
%C - century number 
%d - the day of the month ( 00 .. 31 ) 
%e - the day of the month ( 0 .. 31 ) 
%H - hour ( 00 .. 23 ) 
%I - hour ( 01 .. 12 ) 
%j - day of the year ( 000 .. 366 ) 
%k - hour ( 0 .. 23 ) 
%l - hour ( 1 .. 12 ) 
%m - month ( 01 .. 12 ) 
%M - minute ( 00 .. 59 ) 
%n - a newline character 
%p - "PM" or "AM"
%P - "pm" or "am"
%S - second ( 00 .. 59 ) 
%s - number of seconds since Epoch (since Jan 01 1970 00:00:00 UTC) 
%t - a tab character 
%U, %W, %V - the week number
   The week 01 is the week that has the Thursday in the current year,
   which is equivalent to the week that contains the fourth day of January. 
   Weeks start on Monday.
%u - the day of the week ( 1 .. 7, 1 = MON ) 
%w - the day of the week ( 0 .. 6, 0 = SUN ) 
%y - year without the century ( 00 .. 99 ) 
%Y - year including the century ( ex. 1979 ) 
%% - a literal % character 
</verbatim>

=addHEAD= can be called from =commonTagsHandler= for adding the header to all pages, or from =beforeEditHandler= just for edit pages etc.

An alternative to =commonTagsHandler= is =postRenderingHandler= which is more efficient since it is called less often.

=cut

sub addHEAD {
    my $setup = shift;
    $setup ||= 'calendar-setup';
    my $style =
         Foswiki::Func::getPreferencesValue('JSCALENDARCONTRIB_STYLE')
      || $Foswiki::cfg{JSCalendarContrib}{style}
      || 'large';
    my $lang =
         Foswiki::Func::getPreferencesValue('JSCALENDARCONTRIB_LANG')
      || $Foswiki::cfg{JSCalendarContrib}{lang}
      || 'en';
    my $base = '%PUBURLPATH%/%SYSTEMWEB%/JSCalendarContrib';

    my $css = <<HERE;
<style type='text/css' media='all'>
 \@import url('$base/calendar-$style.css');
 .calendar {z-index:2000;}
</style>
HERE
    Foswiki::Func::addToZone( 'head', 'JSCalendarContrib/css', $css );

    Foswiki::Func::addToZone( 'script', 'JSCalendarContrib/calendar',
        "<script type='text/javascript' src='$base/calendar.js'></script>" );

    Foswiki::Func::addToZone(
        'script',
        'JSCalendarContrib/calendar-lang',
"<script type='text/javascript' src='$base/lang/calendar-$lang.js'></script>",
        'JSCalendarContrib/calendar'
    );

    # Add the setup separately; there might be different setups required
    # in a single HTML page.
    Foswiki::Func::addToZone( 'script', "JSCalendarContrib/$setup",
        "<script type='text/javascript' src='$base/$setup.js'></script>",
        'JSCalendarContrib/calendar' );
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2015 Foswiki Contributors. Foswiki Contributors
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
