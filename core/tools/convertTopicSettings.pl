#!/usr/bin/perl
# See bottom of file for license and copyright information
#

# This tool is expected to be run after a Foswiki site is upgraded to
# Foswiki 1.2.0 or newer.  It can also be used on a Foswik 1.1.x
# installation if the PatchItem12849Contrib is installed
#
# It performs several tasks, depending up on the selected options:
#  - Convert empty DENYTOPIC ACLs into the corresponding ALLOWTOPIC = *
#  - Convert from inline Set ACL's into META Settings
#  - Convert all preference settings into META settings.
#

# You must add the Foswiki bin dir to the
# search path for this script, so it can find the rest of Foswiki e.g.
# perl -I /usr/local/Foswiki/bin /usr/local/Foswiki/tools/rewriteTopicACLs

# SYNOPSIS
#    convertTopicSettings [-update] [-fixdeny] [-convert] [-all] [-verbose] [-debug] [WEB ...]
#
# DESCRIPTION
#
#    -update: topics will be updated.  Without the -update
#    option, candidate topic changes will be reported but will not be written.
#
#    -fixdeny: Removes empty DENYTOPIC rules, replacing them with ALLOWTOPIC wildcard
#
#    -convert: Convert Preference into META settings.  Inline ACLs are removed.
#
#    -all:     Convert all settings from inline sets to meta settings.  Default is to
#              process ACL settings
#
#    -verbose: Report details on what is changed.
#
#    -debug:   Print additional detailed information
#
#    If you specify web names, only those specified are processed. Otherwise,
#    all writable webs are processed.
#
# WARNING
#    This script uses the Foswiki APIs.  It MUST be run as the web server user
#    (apache, or www-data depending on the distribution).  If run as root, it
#    will make the foswiki log unusable by the foswiki web server.
#

use warnings;
use strict;

BEGIN {
    require 'setlib.cfg';
}

use Foswiki;
use Foswiki::Func;
use Foswiki::Meta;
use Getopt::Long;

my $update;
my $all;
my $fixdeny;
my $convert;
my $verbose;
my $debug;

my $session = Foswiki->new('unknown');    #$Foswiki::cfg{AdminUserLogin} );

GetOptions(
    update  => \$update,
    fixdeny => \$fixdeny,
    convert => \$convert,
    all     => \$all,
    verbose => \$verbose,
    debug   => \$debug,
);

my @weblist;
if (@ARGV) {
    @weblist = @ARGV;
}
else {
    @weblist = Foswiki::Func::getListOfWebs('user');
}
foreach my $web (@weblist) {
    print STDERR "Scanning WEB: $web, \n";
    my $topicCounter = 0;
    foreach my $topic ( Foswiki::Func::getTopicList($web) ) {

        #next unless ( $topic =~ /TestTopic/ );
        next if ( $topic eq $Foswiki::cfg{WebPrefsTopicName} );
        scanTopic( $web, $topic );
        $topicCounter++;
    }
    print STDERR "Processed $topicCounter topics in $web\n";
}

exit 0;

sub scanTopic {
    my ( $web, $topic ) = @_;

    my $topicObject = Foswiki::Meta->new( $session, $web, $topic );
    my $text = $topicObject->text();

    my %aclHash = ();
    print STDERR "Processing $web.$topic\n" if $verbose;

    use Data::Dumper;
    print STDERR "=================$topic BEFORE====================\n"
      if $debug;
    print STDERR Data::Dumper::Dumper( \$text ) if $debug;

    my $newText = parse( $topicObject, \%aclHash );

    print STDERR "=================$topic AFTER=====================\n"
      if $debug;
    print STDERR Data::Dumper::Dumper( \$newText ) if $debug;

    if ( %aclHash && $verbose ) {
        foreach my $type ( keys %aclHash ) {
            next if ( $type eq 'fixup' );
            foreach my $key ( keys %{ $aclHash{$type} } ) {
                print STDERR
                  "   PREFERENCE: $type  $key = $aclHash{$type}{$key}\n";
            }
        }
    }

    if ($update) {
        $topicObject->text($newText);
        if ( $convert && %aclHash ) {
            foreach my $type ( keys %aclHash ) {
                next if ( $type eq 'fixup' );
                foreach my $key ( keys %{ $aclHash{$type} } ) {
                    $topicObject->putKeyed(
                        'PREFERENCE',
                        {
                            name  => $key,
                            type  => $type,
                            title => 'PREFERENCE_' . $key,
                            value => $aclHash{$type}{ $key, }
                        }
                    );
                }
            }
        }
        if ( $text ne $newText ) {
            my $newrev = $topicObject->save();
            print STDERR "Saved $web.$topic as rev $newrev\n";
            print STDERR
"---------------------------------------------------------------------------------------------------\n";
        }
    }

    return;
}

=begin TML

---++ parse( $topicObject, $prefs )

This code is copied from Foswiki::Prefs::Parser, modified to extract
and optionally remove the preferences that it extracts from a topic.

If $convert global is true, then this code removes each ACL from the
inline topic text, for later conversion to Meta prefs.

Parse settings from the topic and return the cleaned topic text.. 

=cut

sub parse {
    my ( $topicObject, $prefs ) = @_;

    # Process text first
    my $key   = '';
    my $value = '';
    my $type;
    my $text = $topicObject->text();
    $text = '' unless defined $text;
    my @newText;
    my $line;

 # This processes the topic text line-by-line to capture multi-line preferences.
    foreach $line ( split( "\n", $text ) ) {

        if ( $line =~ m/$Foswiki::regex{setVarRegex}/os ) {

            # hit a new setting, capture the cached setting.
            if ( defined $type ) {
                print STDERR "a - Found a pref:  $type / $key / $value \n"
                  if $debug;
                insert_pref( $prefs, $type, $key, $value );
            }

            # Cache this setting
            $type  = $1;
            $key   = $2;
            $value = ( defined $3 ) ? $3 : '';

            unless ( $all || $key =~ m/^(?:ALLOW|DENY)(?:WEB|TOPIC)/ ) {
                $type = undef;
                print STDERR "Not an ACL: $key = $value\n";
            }

            # Convert the empty DENY here so it can be written inline.
            if ( convert_DENY( $prefs, $type, $key, $value ) ) {
                $line = "   * $type $key = $value";
            }

            next
              if ( $convert && defined $type );   # drop the line from the text.
        }

        # Next line is not a setting,  check if it's a continuation
        elsif ( defined $type ) {

            #print STDERR "LINE:($line)\n";
            if ( $line =~ /^(   |\t)+ *[^\s]/
                && !( $line =~ /$Foswiki::regex{bulletRegex}/o ) )
            {
                #print STDERR "Processing continuation\n";

                # follow up line, extending value
                $value .= "\n" . $line;
                next if ($convert);    # drop the line from the text.
            }
            else {
                # Next line wasn't a continuation, capture the cached setting
                print STDERR "b - Found a pref:  $type / $key / $value \n"
                  if $debug;
                insert_pref( $prefs, $type, $key, $value );
                undef $type;
            }
        }
        push @newText, $line if defined $line;
        undef $line;
    }
    if ( defined $type ) {
        print STDERR "c - Found a pref:  $type / $key / $value \n" if $debug;
        insert_pref( $prefs, $type, $key, $value );
    }

    # Output any final line if not already done.
    push @newText, $line if defined $line;

    # Now process PREFERENCEs
    my @fields = $topicObject->find('PREFERENCE');
    foreach my $field (@fields) {
        print STDERR
"d - Found a meta pref: $field->{type} / $field->{name} /  $field->{value} \n"
          if $debug;
        $type = $field->{type} || 'Set';
        insert_pref( $prefs, $type, $field->{name}, $field->{value} );
    }

    # If original topic didn't end with a newline, don't add one.
    my $nl = ( substr( $text, -1 ) eq "\n" ) ? "\n" : '';
    return join( "\n", @newText ) . $nl;

    #    #### Code to process prefs in Forms ... NOT USED ###
    #    # Note that the use of the "S" attribute to support settings in
    #    # form fields has been deprecated.
    #    my $form = $topicObject->get('FORM');
    #    if ($form) {
    #        my @fields = $topicObject->find('FIELD');
    #        foreach my $field (@fields) {
    #            my $attributes = $field->{attributes};
    #            if ( $attributes && $attributes =~ /S/o ) {
    #                my $value = $field->{value};
    #                my $name  = $field->{name};
    #                insert_pref($prefs, 'Set', 'FORM_' . $name, $value );
    #                insert_pref($prefs, 'Set', $name,           $value );
    #            }
    #        }
    #    }
}

sub insert_pref {
    my ( $prefs, $type, $key, $value ) = @_;

  # Detect duplicate settings - last one is kept unless we created the duplicate
    if ( exists $prefs->{$type}{$key} ) {

        # Detect if the dup is due to the DENY -> ALLOW * conversion
        # And if so, merge it instead of dropping it.
        # This only works if converting to Meta type settings.

     # If not converting to Meta style settings, then some errors won't be fixed
     # The setting remains in the topic, but will be ignored by Foswiki.

        my $action;
        $action = ($convert) ? 'DROPPED`' : 'IGNORED';
        if ( $fixdeny && $prefs->{fixup}{$key} ) {
            $value  = '*, ' . $value;    # unless $value =~ m/\s?\*[ ,]?/;
            $action = 'MERGED';
        }

        print STDERR "   ERROR: Duplicate setting detected\n";
        print STDERR "      First PREFERENCE ($action): $type  $key  = "
          . $prefs->{$type}{$key} . "\n";
        print STDERR
          "      Second PREFERENCE (active): $type $key = $value  \n";
    }

    $prefs->{$type}{$key} = $value;
    return 1;
}

sub convert_DENY {

    # my ( $prefs, $type, $key, $value ) = @_;    Don't extractA

    # Convert empty DENY to ALLOW *
    if ( $_[3] =~ m/^\s?$/ && $_[2] =~ m/DENY(TOPIC[A-Z]+)$/ ) {
        print STDERR "   EMPTY DENY$1 converted to ALLOW$1\n";
        $_[3] = '*';
        $_[2] = "ALLOW$1";

      # Flag that a fixup was made,  so that it can be merged if a dup is found.
        $_[0]->{fixup}{"ALLOW$1"} = '*';
        return 1;
    }
    return 0;
}

__END__

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2014 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2005-2007 TWiki Contributors. All Rights Reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
Foswiki - The Free and Open Source Wiki, http://foswiki.org/
