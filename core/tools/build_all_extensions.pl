#!/usr/bin/perl
# Build and upload all the extensions, zipping those that don't have
# proper build scripts
use strict;

my $upload_files = ( $ARGV[0] =~ /^upload$/ ) || 0;

my $pr = "../twikiplugins";
chomp( my @knowns = `grep '!include' MANIFEST` );
my @exts;

opendir( D, $pr );
foreach my $e ( grep { -d "$pr/$_" && !/^\./ } sort readdir D ) {
    next if grep { /^$e$/ } @knowns;
    print STDERR "BUILDING $e\n";
    my $type;
    my $dir;
    if ( -e "$pr/$e/$e.tgz" ) {
        if ( $ARGV[0] eq "keep" ) {
            push( @exts, $e );
            next;
        }
        else {
            unlink "$pr/$e/$e.tgz";
        }
    }
    if ( $e =~ /Plugin$/ ) {
        build( $e, "Plugins" );
    }
    elsif ( $e =~ /Contrib$/ ) {
        build( $e, "Contrib" );
    }
    elsif ( $e =~ /AddOn$/ ) {
        build( $e, "AddOn" );
    }
    elsif ( $e =~ /Skin/ ) {
        unless ( build( $e, "Contrib" ) ) {
            just_zip($e);
        }
    }
    else {
        just_zip($e);
    }
    if ( -f "$pr/$e/$e.tgz" ) {
        push( @exts, $e );
    }
    else {
        print STDERR "Failed to build $e\n";
    }
}

sub build {
    my ( $name, $inDir ) = @_;

    return 0 unless -f "$pr/$name/lib/Foswiki/$inDir/$name/build.pl";

    print STDERR `perl $pr/$name/lib/Foswiki/$inDir/$name/build.pl release`;

    return 0 unless -f "$pr/$name/$name.tgz";

    return 1;
}

sub just_zip {
    my ($name) = @_;

    print STDERR `cd $pr/$name && tar zcf $name.tgz .`;
    print STDERR "JUST ZIPPED $name\n";
}

################################################################################

use LWP;

{

    package UserAgent;

    @UserAgent::ISA = qw(LWP::UserAgent);

    use vars qw( $knownUser $knownPass );

    sub get_basic_credentials {
        my ( $self, $realm, $uri ) = @_;
        unless ($knownUser) {
            print 'Logon to ', $uri->host_port, "\n";
            print 'Enter ', $realm, ': ';
            $knownUser = <STDIN>;
            chomp($knownUser);
            return ( undef, undef ) unless length $knownUser;
            print 'Password on ', $uri->host_port, ': ';
            system('stty -echo');
            $knownPass = <STDIN>;
            system('stty echo');
            print "\n";    # because we disabled echo
            chomp($knownPass);
        }
        return ( $knownUser, $knownPass );
    }
}

if ($upload_files) {
    my $userAgent = UserAgent->new();
    $userAgent->agent('build_all_extensions');

    foreach my $e (@exts) {
        print "Uploading $e.tgz\n";
        my $response = $userAgent->post(
            'http://twiki.org/cgi-bin/upload/Plugins/TWiki',
            [
                filename => $e . '.tgz',
                filepath => ["$pr/$e/$e.tgz"],
                filecomment =>
                  "See $e for details. Untar and run the installer script"
            ],
            'Content_Type' => 'form-data'
        );

        print STDERR 'Upload of $e.tgz failed ', $response->request->uri,
          ' -- ', $response->status_line, "\n", 'Aborting', "\n",
          $response->as_string
          unless $response->is_redirect
              && $response->headers->header('Location') =~
              /view([\.\w]*)\/Plugins\/Foswiki/;
    }
}
