#! /usr/bin/env perl
# Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008-2015 Foswiki Contributors. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 2005-2007 TWiki Contributors. All Rights Reserved.
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
# Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#

use warnings;
use strict;

# Assume we are in the tools dir, and we can find bin and lib from there
use FindBin ();
$FindBin::Bin =~ /^(.*)$/;
my $bin = $1;

use lib "$FindBin::Bin/../bin";
use lib "$FindBin::Bin/../lib";

use Foswiki;
use Foswiki::Func;
use Foswiki::Meta;
use Getopt::Long;
use Pod::Usage;

my $update;
my $all;
my $fixdeny;
my $convert;
my $verbose;
my $debug;
my $help;

my $savedTopics = 0;    # Global counter of saved topics

my $session = Foswiki->new('unknown');    #$Foswiki::cfg{AdminUserLogin} );

GetOptions(
    update  => \$update,
    fixdeny => \$fixdeny,
    convert => \$convert,
    all     => \$all,
    verbose => \$verbose,
    debug   => \$debug,
    help    => \$help,
) or Pod::Usage::pod2usage( -exitstatus => 0, -verbose => 0 );

if ($help) {
    Pod::Usage::pod2usage( -exitstatus => 0, -verbose => 2 );
}

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

        next if ( $topic eq $Foswiki::cfg{WebPrefsTopicName} );
        scanTopic( $web, $topic );
        $topicCounter++;
    }
    print STDERR
      "Processed $topicCounter topics in $web;  Updated $savedTopics\n";
    $savedTopics = 0;
}

exit 0;

sub scanTopic {
    my ( $web, $topic ) = @_;

    my $topicObject = Foswiki::Meta->new( $session, $web, $topic );
    my $text = $topicObject->text();

    my %aclHash = ();
    print STDERR "Processing $web.$topic\n" if $verbose;

    _dumpTopic( "$topic BEFORE", $topicObject->getEmbeddedStoreForm() )
      if $debug;
    my $newText = parse( \$topicObject, \%aclHash );

    if ( %aclHash && $verbose ) {
        foreach my $type ( keys %aclHash ) {
            next if ( $type eq 'fixup' );
            foreach my $key ( keys %{ $aclHash{$type} } ) {
                print STDERR
                  "   PREFERENCE: $type  $key = $aclHash{$type}{$key}\n";
            }
        }
    }

    print STDERR "$topic.$web text has been updated.\n"
      unless ( $text eq $newText );

    if ($update) {
        $topicObject->text($newText);
        if ( $convert && %aclHash ) {
            foreach my $type ( keys %aclHash ) {
                next if ( $type eq 'fixup' );
                foreach my $key ( keys %{ $aclHash{$type} } ) {
                    print STDERR "PUT $key value $aclHash{$type}{ $key, } \n";
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
        if ( $text ne $newText || $aclHash{fixup} ) {
            _dumpTopic( "$topic AFTER", $topicObject->getEmbeddedStoreForm() )
              if $debug;
            my $newrev = $topicObject->save();
            print STDERR "Saved $web.$topic as rev $newrev\n";
            $savedTopics++;
            print STDERR
"---------------------------------------------------------------------------------------------------\n";
        }
    }

    return;
}

sub _dumpTopic {

    print STDERR "================= $_[0] =====================\n";
    require Data::Dumper;
    print STDERR Data::Dumper::Dumper( \$_[1] );

#my $hex = '';
#foreach my $ch ( split ( //, $newText ) ) {
#    $hex .= ( $ch lt "\x20" || $ch gt "\x7e" ) ? "\'" . unpack("H2",$ch) . "\'" : $ch;
#	}
#print STDERR "($hex)\n";
}

# ---++ parse( $topicObject, $prefs )

# This code is copied from Foswiki::Prefs::Parser, modified to extract
# and optionally remove the preferences that it extracts from a topic.
#
# If $convert global is true, then this code removes each ACL from the
# inline topic text, for later conversion to Meta prefs.

# Parse settings from the topic and return the cleaned topic text..

sub parse {
    my ( $topicObject, $prefs ) = @_;

    #use Data::Dumper;
    #print STDERR Data::Dumper::Dumper( \$topicObject );

    # Process text first
    my $key   = '';
    my $value = '';
    my $type;
    my $text = $$topicObject->text();
    $text = '' unless defined $text;
    my @newText;
    my $line;

 # This processes the topic text line-by-line to capture multi-line preferences.
 # Use -1 limit so that trailing lines are preserved

    foreach $line ( split( /\n/ms, $text, -1 ) ) {

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
                print STDERR "Not an ACL: $key = $value\n" if $verbose;
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
    my @fields = $$topicObject->find('PREFERENCE');
    foreach my $field (@fields) {
        print STDERR
"d - Found a meta pref: $field->{type} / $field->{name} /  $field->{value} \n"
          if $debug;

        # Copy the values, convert_DENY updates in place!
        my $key   = $field->{name};
        my $value = $field->{value};
        $type = $field->{type} || 'Set';
        if ( convert_DENY( $prefs, $type, $key, $value ) ) {
            print STDERR "Removing $type, $field->{name} \n";
            $$topicObject->remove( 'PREFERENCE', $field->{name} );
        }
        insert_pref( $prefs, $type, $key, $value );
    }

    return join( "\n", @newText );

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

1;

=head1 tools/convertTopicSettings.pl

Convert inline topic settings into META settings.

=head1 SYNOPSIS

 tools/convertTopicSettings.pl [-update] [-fixdeny] [-convert] [-all] [-verbose] [-debug] [WEB ...]

This tool should be run after a Foswiki site is upgraded to
Foswiki 2.0 or newer.  It can also be used on a Foswik 1.1.x
installation if the PatchItem12849Contrib is installed

It performs several tasks, depending up on the selected options:

=over 2 

=item *

Convert empty DENYTOPIC ACLs into the corresponding ALLOWTOPIC = *

=item *

Convert from inline Set ACL's into META Settings

=item *

Convert all preference settings into META settings.

=back

B<WARNING>

This script uses the Foswiki APIs.  It MUST be run as the web server user
(apache, or www-data depending on the distribution).  If run as root, it
will make the foswiki log unusable by the foswiki web server.

=head1 OPTIONS

=over 8

=item B<-update>

Write the changes to the web. Otherwise only a report is produced. No topics
are changed if this option is not provided.

=item B<-fixdeny>

Removes empty DENYTOPIC* rules, and replaces them with an 
ALLOWTOPIC* wildcard rule.

=item B<-convert>

Convert inline preference settings into META settings. Inline settings are removed.
By default, this option only applies to Access (ALLOW/DENY) rules.

=item B<-all> 

Convert ALL inline settings into META settings.  Unless this option is specified,
then only ACLs will be converted.

=item B<-verbose>

Report details on changes.

=item B<-debug>

Report additional details on the conversion process.

=back

=head1 EXAMPLES


 $ tools/convertTopicSettings

will scan all webs and report any ACLs that need conversion.

 $ tools/convertTopicSettings -fixdeny -update

Scan all webs. Convert empty DENY rules into ALLOW * wildcards.
Settings are left "inline" in the topic text and changes are written.

 $ tools/convertTopicSettings -fixdeny -convert -update Sandbox Main

Scan only the Sandbox and Main webs for empty DENY rules.  Convert
them into ALLOW * wildcard rules, and move them into META settings.

 $ tools/convertTopicSettings -fixdeny -convert -all -verbose

Scan all webs for any inline * Set statements.  Change all of them into META
settings, convert empty DENY rules into ALLOW * wildcards, and report details
on all expected changes.   No changes are written.



=cut
