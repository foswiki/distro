#
# Copyright (C) 2004-2015 C-Dot Consultants - All rights reserved
# Copyright (C) 2008-2015 Foswiki Contributors
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#
package Foswiki::Contrib::Build;

use strict;
use warnings;

use LWP;
use LWP::UserAgent;

# number of seconds to sleep between uploads,
# to reduce average load on server
use constant GLACIERMELT => 10;

my $lastUpload = 0;    # time of last upload (0 means none yet)

{

    package Foswiki::Contrib::Build::UserAgent;
    our @ISA = qw( LWP::UserAgent );

    sub new {
        my ( $class, $id, $bldr ) = @_;
        my $this = $class->SUPER::new(
            keep_alive => 1,

            # Item721: Get proxy settings from environment variables
            env_proxy => 1
        );
        $this->{domain}  = $id;
        $this->{builder} = $bldr;
        require HTTP::Cookies;
        $this->cookie_jar(
            new HTTP::Cookies(
                file           => "$ENV{HOME}/.lwpcookies",
                autosave       => 1,
                ignore_discard => 1
            )
        );

        return $this;
    }

    sub get_basic_credentials {
        my ( $this, $realm, $uri ) = @_;
        return $this->{builder}->getCredentials( $uri->host() );
    }
}

sub recover_form {

    #my ($text, $form) = @_;
    my $sawn = 0;

    while ( $_[0] =~
s/(^|\n)%META:FIELD\{name="([^"]*?)"[^}]*?value="([^"]*?)"[^}]*?}%(\n|$)/$1/s
      )
    {
        my $name = $2;
        my $val  = $3;

        # decode the value
        $val =~ s/%([\da-f]{2})/chr(hex($1))/gei;

        # Trim null values or we end up damaging the form
        if ( defined $val && length($val) ) {
            $_[1]->{$name} = $val;
        }
        $sawn++;
    }
    $_[0] =~ s/(^|\n)%META:FORM\{name=[^}]*?}%(\n|$)/$1/s;

    return $sawn;
}

=begin TML

---++++ target_upload
Upload to a repository. Prompts for username and password. Uploads the zip and
the text topic to the appropriate places. Creates the topic if
necessary.

=cut

sub target_upload {
    my $this = shift;

    my $to = $this->{project};

    while (1) {
        print <<END;
Preparing to upload to:
Web:     $this->{UPLOADTARGETWEB}
PubDir:  $this->{UPLOADTARGETPUB}
Scripts: $this->{UPLOADTARGETSCRIPT}
Suffix:  $this->{UPLOADTARGETSUFFIX}
 
If upload target does not exist, recover package form from:
Web:     $this->{DOWNTARGETWEB}
Scripts: $this->{DOWNTARGETSCRIPT}
Suffix:  $this->{DOWNTARGETSUFFIX}
END

        last if ask( "Is that correct? Answer 'n' to change", 1 );
        print "Enter the name of the web that contains the target repository\n";
        $this->{UPLOADTARGETWEB} = prompt( "Web", $this->{UPLOADTARGETWEB} );
        print "Enter the full URL path to the pub directory\n";
        $this->{UPLOADTARGETPUB} = prompt( "PubDir", $this->{UPLOADTARGETPUB} );
        print "Enter the full URL path to the bin directory\n";
        $this->{UPLOADTARGETSCRIPT} =
          prompt( "Scripts", $this->{UPLOADTARGETSCRIPT} );
        print
"Enter the file suffix used on scripts in the bin directory (enter 'none' for none)\n";
        $this->{UPLOADTARGETSUFFIX} =
          prompt( "Suffix", $this->{UPLOADTARGETSUFFIX} );
        $this->{UPLOADTARGETSUFFIX} = ''
          if $this->{UPLOADTARGETSUFFIX} eq 'none';
        print
"\nEnter the alternate name of the web that contains the package form\n";
        $this->{DOWNTARGETWEB} = prompt( "Web", $this->{DOWNTARGETWEB} );

        print "Enter the full URL path to the alternate bin directory\n";
        $this->{DOWNTARGETSCRIPT} =
          prompt( "Scripts", $this->{DOWNTARGETSCRIPT} );
        print
"Enter the file suffix used on scripts in the alternate bin directory (enter 'none' for none)\n";
        $this->{DOWNTARGETSUFFIX} =
          prompt( "Suffix", $this->{DOWNTARGETSUFFIX} );
        $this->{DOWNTARGETSUFFIX} = ''
          if $this->{DOWNTARGETSUFFIX} eq 'none';

        my $rep = $this->{config}->{repositories}->{ $this->{project} } || {};
        $rep->{pub}        = $this->{UPLOADTARGETPUB};
        $rep->{script}     = $this->{UPLOADTARGETSCRIPT};
        $rep->{suffix}     = $this->{UPLOADTARGETSUFFIX};
        $rep->{web}        = $this->{UPLOADTARGETWEB};
        $rep->{downscript} = $this->{DOWNTARGETSCRIPT};
        $rep->{downsuffix} = $this->{DOWNTARGETSUFFIX};
        $rep->{downweb}    = $this->{DOWNTARGETWEB};
        $this->{config}->{repositories}->{ $this->{project} } = $rep;
        $this->saveConfig();
    }

    my $userAgent =
      new Foswiki::Contrib::Build::UserAgent( $this->{UPLOADTARGETSCRIPT},
        $this );
    $userAgent->agent(
        'ContribBuild/' . $Foswiki::Contrib::Build::VERSION . ' ' );
    $userAgent->cookie_jar( {} );
    $userAgent->timeout(420);

    my $topic = $this->getTopicName();

    # Ask for username and password
    my ( $user, $pass ) = $this->_getCredentials( $this->{UPLOADTARGETSCRIPT} );

    # Ask what the user wants to upload
    my $doUploadArchivesAndInstallers =
      ask( "Do you want to upload the archives and installers?", 1 );

    #need the topic at this point.
    $this->build('release');
    my $topicText;
    my $baseTopic = $this->{basedir} . '/' . $to . '.txt';
    local $/ = undef;    # set to read to EOF
    if ( open( IN_FILE, '<', $baseTopic ) ) {
        print "Basing new topic on " . $baseTopic . "\n";
        $topicText = <IN_FILE>;
        close(IN_FILE);
    }
    else {
        warn 'Failed to open base topic(' . $baseTopic . '): ' . $!;
        $topicText = <<END;
Release $to
END
        print "Basing new topic on some default text:\n$topicText\n";
    }
    my @attachments;
    $topicText =~ s/%META:FILEATTACHMENT(.*)%/
      push(@attachments, $1);''/ge;

    my $doUploadAttachments = scalar(@attachments)
      && ask( "Do you want to upload the attachments?", 1 );

    # No more questions after this point

    $this->_login( $userAgent, $user, $pass );

    my $url =
"$this->{UPLOADTARGETSCRIPT}/view$this->{UPLOADTARGETSUFFIX}/$this->{UPLOADTARGETWEB}/$topic";
    my $alturl =
"$this->{DOWNTARGETSCRIPT}/view$this->{DOWNTARGETSUFFIX}/$this->{DOWNTARGETWEB}/$topic";

    # Get the old form data and attach it to the update
    print "Downloading $topic to recover form\n";
    my $response = $userAgent->get("$url?raw=all");
    my $etype    = "Contrib";
    if ( $this->{project} =~ /(Plugin|Skin|Contrib|AddOn)$/ ) {
        $etype = $1 unless $1 eq 'AddOn';
    }

    my %form = (
        formtemplate  => 'PackageForm',
        ExtensionType => $etype . 'Package',
        SupportUrl    => 'Support.' . $this->{project},
        DemoUrl       => 'http://'
    );

    # SMELL: There appears to be no way to distinguish if Foswiki didn't
    # find the topic and returns the topic creator form, or if the GET
    # was successful.  Foswiki always returns 200 for the status
    # We need a better way of handling the not-found condition.
    # For now, look to see if there is a newtopicform present. If found,
    # it means that the get should be treated as a NOT FOUND.

    if ( $response->is_success()
        && !( $response->content() =~ m/<form name="newtopicform"/s ) )
    {
        print "Recovering form from $topic\n";

        # SMELL: would be better to use Foswiki::Meta to do this
        unless ( recover_form( $response->content(), \%form ) ) {
            print STDERR "======= WARNING =======\n";
            print STDERR
"A default package form was created.  Please verify the setting on the uploaded topic\n";
        }
    }
    else {
        if ( !$response->is_success ) {
            print 'Failed to GET old topic ', $response->request->uri,
              ' -- ', $response->status_line, "\n";
        }

        if (   ( $this->{DOWNTARGETSCRIPT} ne $this->{UPLOADTARGETSCRIPT} )
            || ( $this->{DOWNTARGETWEB} ne $this->{UPLOADTARGETWEB} ) )
        {
            print "Downloading $topic from $alturl to recover form\n";
            $response = $userAgent->get("$alturl?raw=all");
            if (   $response->is_success
                && !( $response->content() =~ m/<form name="newtopicform"/s )
                && recover_form( $response->content(), \%form ) )
            {
            }
            else {
                unless ( $response->is_success ) {
                    print 'Failed to GET old topic from Alternate location',
                      $response->request->uri,
                      ;
                }
                print STDERR "======= WARNING =======\n";
                print STDERR
"A default package form was created.  Please verify the setting on the uploaded topic\n";
            }
        }
    }

    #print STDERR "========= Form from web =========\n";
    #foreach my $k ( keys %form ) {
    #    next if ( $k eq 'text' );
    #    print STDERR sprintf("%-26s %s\n", $k, $form{$k});
    #}
    #print STDERR "=================================\n";

    # Override what is read from the web with the form in the new topic
    recover_form( $topicText, \%form );
    $form{text} = $topicText;
    $this->_uploadTopic( $userAgent, $user, $pass, $topic, \%form );

    # Upload any 'Var*.txt' topics published by the extension
    my $dataDir = $this->{basedir} . '/data/System';
    if ( opendir( DIR, $dataDir ) ) {
        foreach my $f ( grep( /^Var\w+\.txt$/, readdir DIR ) ) {
            if ( open( IN_FILE, '<', $this->{basedir} . '/data/System/' . $f ) )
            {
                my %newform = ( text => <IN_FILE> );
                close(IN_FILE);
                $f =~ s/\.txt$//;
                $this->_uploadTopic( $userAgent, $user, $pass, $f, \%newform );
            }
        }
        closedir DIR;
    }

    return if ( $this->{-topiconly} );

    # upload any attachments to the developer's version of the topic. Any other
    # attachments to the topic on t.o. will still be there.
    my %uploaded;    # flag already uploaded

    if ($doUploadAttachments) {
        foreach my $a (@attachments) {
            $a =~ /name="([^"]*)"/;
            my $name = $1;
            next if $uploaded{$name};
            next if $name =~ /^$to(\.zip|\.tgz|_installer|\.md5|\.sha1)$/;
            $a =~ /comment="([^"]*)"/;
            my $comment = $1;
            $a =~ /attr="([^"]*)"/;
            my $attrs = $1 || '';

            $this->_uploadAttachment(
                $userAgent,
                $user,
                $pass,
                $name,
                $this->{basedir}
                  . '/pub/System/'
                  . $this->{project} . '/'
                  . $name,
                $comment,
                $attrs =~ /h/ ? 1 : 0
            );
            $uploaded{$name} = 1;
        }
    }

    return unless $doUploadArchivesAndInstallers;

    # Upload the standard files
    foreach my $ext (qw(.zip .tgz _installer .md5 .sha1)) {
        my $name = $to . $ext;
        next if $uploaded{$name};
        $this->_uploadAttachment( $userAgent, $user, $pass, $to . $ext,
            $this->{basedir} . '/' . $to . $ext, '' );
        $uploaded{$name} = 1;
    }
}

sub _login {
    my ( $this, $userAgent, $user, $pass ) = @_;

    #Send a login request - to get a validation key for strikeone
    my $response = $userAgent->get(
        "$this->{UPLOADTARGETSCRIPT}/login$this->{UPLOADTARGETSUFFIX}");

    # "(Foswiki login)" or "Login - Foswiki"
    unless ( ( $response->code == 200 || $response->code == 400 )
        and $response->header('title') =~ /login/i )
    {
        die 'Failed to GET login form '
          . $response->request->uri . ' -- '
          . $response->status_line . "\n";
    }

    my $validationKey = $this->_strikeone( $userAgent, $response );

    $response = $userAgent->post(
        "$this->{UPLOADTARGETSCRIPT}/login$this->{UPLOADTARGETSUFFIX}",
        {
            username       => $user,
            password       => $pass,
            validation_key => $validationKey
        }
    );

    die 'Login failed '
      . $response->request->uri . ' -- '
      . $response->status_line . "\n"
      . 'Aborting' . "\n"
      unless $response->is_redirect
      && $response->headers->header('Location') !~ m{/oops};
}

sub _uploadTopic {
    my ( $this, $userAgent, $user, $pass, $topic, $form ) = @_;

    print STDERR "========= Form Data for review =========\n";
    foreach my $k ( keys %$form ) {
        next if ( $k eq 'text' );
        print STDERR sprintf( "%-26s %s\n", $k, $form->{$k} );
    }
    print STDERR "========================================\n";

    # send an edit request to get a validation key
    my $response = $userAgent->get(
"$this->{UPLOADTARGETSCRIPT}/edit$this->{UPLOADTARGETSUFFIX}/$this->{UPLOADTARGETWEB}/$topic"
    );
    unless ( $response->is_success ) {
        die 'Request to edit '
          . $this->{UPLOADTARGETWEB} . '/'
          . $topic
          . ' failed '
          . $response->request->uri . ' -- '
          . $response->status_line . "\n";
    }

    $form->{validation_key} = $this->_strikeone( $userAgent, $response );

    $form->{text} =~ s/^%META:TOPICINFO\{.*?\n//;    # Delete any old topicinfo
    my $url =
"$this->{UPLOADTARGETSCRIPT}/save$this->{UPLOADTARGETSUFFIX}/$this->{UPLOADTARGETWEB}/$topic";
    $form->{text} = <<EXTRA. $form->{text};
<!--
This topic is part of the documentation for $this->{project} and is
automatically generated from Subversion. You can edit it, but if you do,
please make sure the maintainer of the extension knows about your changes,
otherwise your edits might be lost the next time the topic is uploaded.

If you want to report an error in the topic, please raise a report at
http://foswiki.org/Tasks/$this->{project}
-->
EXTRA
    print "Saving $topic\n";
    $this->_postForm( $userAgent, $user, $pass, $url, $form );
}

sub _uploadAttachment {
    my ( $this, $userAgent, $user, $pass, $filename, $filepath, $filecomment,
        $hide )
      = @_;

    # send an edit request to get a validation key
    my $response = $userAgent->get(
"$this->{UPLOADTARGETSCRIPT}/edit$this->{UPLOADTARGETSUFFIX}/$this->{UPLOADTARGETWEB}/$this->{project}"
    );
    unless ( $response->is_success ) {
        die 'Request to edit '
          . $this->{UPLOADTARGETWEB} . '/'
          . $this->{project}
          . ' failed '
          . $response->request->uri . ' -- '
          . $response->status_line . "\n";
    }

    my $url =
"$this->{UPLOADTARGETSCRIPT}/upload$this->{UPLOADTARGETSUFFIX}/$this->{UPLOADTARGETWEB}/$this->{project}";
    my $form = [
        'filename'       => $filename,
        'filepath'       => [$filepath],
        'filecomment'    => $filecomment,
        'hidefile'       => $hide || 0,
        'validation_key' => $this->_strikeone( $userAgent, $response ),
    ];

    print "Uploading $this->{UPLOADTARGETWEB}/$this->{project}/$filename\n";
    $this->_postForm( $userAgent, $user, $pass, $url, $form );
}

sub _strikeone {
    my ( $this, $userAgent, $response ) = @_;

    my $f = $response->content();
    $f =~ s/<\/form>.*//sm;
    $f =~ s/.*<form.*?>//sm;
    my $validationKey;
    while ( $f =~ /<input([^>]*)>/g ) {
        my $attrs = $1;
        if (    $attrs =~ /\bname=["']validation_key["']/
            and $attrs =~ /\bvalue=["'](.*?)["']/ )
        {
            $validationKey = $1;
            last;
        }
    }
    if ( not defined $validationKey ) {
        warn "WARNING: The form does not have a validation_key field\n";
        return '';
    }

    my $cookie;
    $userAgent->cookie_jar()->scan(
        sub {
            my ( $version, $key, $value ) = @_;
            $cookie = $value if $key eq 'FOSWIKISTRIKEONE';
        }
    );
    if ( not defined $cookie ) {
        warn
"WARNING: Could not find strikeone cookie in cookiejar - disabling strikeone\n";
        return $validationKey;
    }

    $validationKey =~ s/^\?//;

    return Digest::MD5::md5_hex( $validationKey . $cookie );
}

sub _postForm {
    my ( $this, $userAgent, $user, $pass, $url, $form ) = @_;

    if ( $this->{-N} ) {
        print STDERR "SKIPPING UPLOAD because -N was on the command line\n";
        return;
    }

    my $pause = GLACIERMELT - ( time - $lastUpload );
    if ( $pause > 0 ) {
        print "Taking a ${pause}s breather after the last upload...\n";
        sleep($pause);
    }
    $lastUpload = time();

    my $response =
      $userAgent->post( $url, $form, 'Content_Type' => 'form-data' );

    die 'Upload failed ', $response->request->uri,
      ' -- ', $response->status_line, "\n", 'Aborting', "\n",
      $response->as_string
      unless $response->is_redirect
      && $response->headers->header('Location') !~ m{/oops|/log.n/};
}

sub _getCredentials {
    my ( $this, $host ) = @_;
    my $config = $this->_loadConfig();
    my $pws    = $config->{passwords}->{$host};
    if ($pws) {
        print "Using credentials for $host saved in $config->{file}\n";
    }
    else {
        local $/ = "\n";
        print 'Enter username for ', $host, ': ';
        my $knownUser = <STDIN>;
        chomp($knownUser);
        die "Inadequate user" unless length $knownUser;
        print 'Password: ';
        system('stty -echo');
        my $knownPass = <STDIN>;
        system('stty echo');
        print "\n";    # because we disabled echo
        chomp($knownPass);
        $pws = { user => $knownUser, pass => $knownPass };
        $config->{passwords}->{$host} = $pws;
        $this->saveConfig();
    }
    return ( $pws->{user}, $pws->{pass} );
}

1;
