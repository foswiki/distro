# See bottom of file for license and copyright information
use v5.14;

=begin TML

---+!! package Foswiki::Engine::CGI

Class that implements default CGI behavior.

Refer to Foswiki::Engine documentation for explanation about methods below.

=cut

package Foswiki::Engine::CGI;
use v5.14;

use CGI::Carp qw(fatalsToBrowser);
use Data::Dumper;

use Foswiki                  ();
use Foswiki::Request         ();
use Foswiki::Request::Upload ();
use Foswiki::Response        ();
use Unicode::Normalize;
use Try::Tiny;

use CGI;

use Moo;
use namespace::clean;
extends qw(Foswiki::Engine);

use constant HTTP_COMPLIANT => 1;

use Assert;

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }

    unless ( CGI->can('multi_param') ) {
        no warnings 'redefine';
        *CGI::multi_param = \&CGI::param;
        use warnings 'redefine';
    }
}

# ****
# CGI.pm has a private class called CGITempFile which is used to hold
# a handle to a temporary file. The idea is that when the CGI object
# is reaped, the temporary files are automatically unlinked. However,
# when Sandbox::sysCommand is invoked - for example, by loading a topic
# before the uploads have been processed - a subprocess is created that
# gets a copy of the parent process, including these objects. When the
# subprocess terminates, the CGITempFiles are DESTROYed and the external
# files unlinked, leaving the parent process with pointers to non-
# existant temporary files.
#
# We solve this problem by patching the DESTROY method on CGITempFile so
# that the temporary files are only ever destroyed by the parent process,
# and never by the child. We do this by comparing the PID with a PID
# recorded when the CGI object is constructed.

our $CONSTRUCTOR_PID;
our $SAVE_DESTROY;
eval {
    # In an eval in case it's ever removed from CGI
    $SAVE_DESTROY = \&CGITempFile::DESTROY;
};
if ( defined $SAVE_DESTROY ) {
    no warnings 'redefine';
    *CGITempFile::DESTROY = sub {
        if ( defined $CONSTRUCTOR_PID && $$ == $CONSTRUCTOR_PID ) {

            # Parent process, unlink the temp file
            &$SAVE_DESTROY(@_);
        }
    };
}

has cgi => (
    is      => 'rw',
    clearer => 1,
    lazy    => 1,
    isa     => Foswiki::Object::isaCLASS( 'cgi', 'CGI' ),
    default => sub {
        my $this = shift;

        return unless $this->env->{CONTENT_LENGTH};

        # Record the master process so we don't reap temp files in
        # sub-processes (see long comment ****)
        $CONSTRUCTOR_PID = $$;

        # Note that we handle unicode conversion in the various prepare*
        # methods, rather than using the CGI -utf8 option, which is documented
        # as breaking uploads (though cdot believes this is because of the
        # deprecated dual nature of param delivering lightweight file handles,
        # and it would probably work in Foswiki. Just not tried it)
        my $cgi = new CGI();
        my $err = $cgi->cgi_error;
        Foswiki::Exception::Engine->throw( status => $1, text => $2 )
          if defined $err && $err =~ m/\s*(\d{3})\s*(.*)/;
        return $cgi;
    },
);
has uploads => ( is => 'rw', lazy => 1, clearer => 1, default => sub { {} }, );

# Check if this is CGI ennvironment.
sub probe {
    my %params = @_;
    return $params{env}{GATEWAY_INTERFACE} || $params{env}{MOD_PERL};
}

#around run => sub {
#    my $orig = shift;
#    my $this = shift;
#    try {
#        my $req = $this->prepare;
#        my $requestor = $req->http('x-requested-with') || '';
#        unless (
#               $Foswiki::cfg{isVALID}
#            || $Foswiki::cfg{isBOOTSTRAPPING}
#            || $requestor eq 'XMLHttpRequest'
#
#            # Configure uses FoswikiReflectionRequest to query values
#            # before LSC is ready
#            || $requestor eq 'FoswikiReflectionRequest'
#          )
#        {
#            print STDOUT "Content-type: text/html\n\n";
#            print STDOUT
#              '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"'
#              . "\n    "
#              . '"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">' . "\n";
#            print STDOUT
#"<html><head></head><body><h1>Foswiki Configuration Error</h1><br>Please run <code>configure</code> to create a valid configuration<br />\n";
#            print STDOUT
#"If you've already done this, then your <code>lib/LocalSite.cfg</code> is most likely damaged\n</body></html>";
#            exit 1;
#        }
#        if ( UNIVERSAL::isa( $req, 'Foswiki::Request' ) ) {
#            my $res = Foswiki::UI::handleRequest($req);
#            $this->finalize( $res, $req );
#        }
#    }
#    catch {
## Whatever error we get here – we generate valid HTTP response. At least we try...
## This is the last frontier of error handling.
## SMELL XXX Test code.
#
#        # SMELL This block is to be reconsidered.
#        if ( !ref($_) ) {
#            say STDERR "CGI::catch simple text: $_";
#            CGI::Carp::confess($_);
#        }
#        elsif ( $_->isa('Error') || $_->isa('Error::Simple') ) {
#            say STDERR "CGI::catch Error derivative: $_->{-text}";
#            CGI::Carp::confess( $_->{-text} );
#        }
#        else {
#            say STDERR "CGI::catch Foswiki::Exception derivative: ", $_->text;
#            CGI::Carp::confess( $_->text );
#        }
#
#    };
#};

around _prepareConnection => sub {
    my $orig = shift;
    my $this = shift;

    my $secure = 0;
    if ( $this->env->{HTTPS} && uc( $this->env->{HTTPS} ) eq 'ON' ) {
        $secure = 1;
    }
    return {
        remoteAddress => $this->env->{REMOTE_ADDR},
        method        => $this->env->{REQUEST_METHOD},
        secure        => $secure,
        serverPort    => $this->env->{SERVER_PORT},
    };
};

# XXX The base class method now fetches QUERY_STRING on its own. So, why wasting
# time on extra call?
#around _prepareQueryParameters => sub {
#    my $orig = shift;
#    my ( $this, $req ) = @_;
#    $orig->( $this, $req, $this->env->{QUERY_STRING} )
#      if $this->env->{QUERY_STRING};
#};

around _prepareHeaders => sub {
    my $orig    = shift;
    my $this    = shift;
    my $headers = $orig->($this);
    foreach my $header ( keys %{ $this->env } ) {
        next unless $header =~ m/^(?:HTTP|CONTENT|COOKIE)/i;
        ( my $field = $header ) =~ s/^HTTPS?_//;
        $headers->{$field} = $this->env->{$header};
    }
    return $headers;
};

around _prepareUser => sub {
    my $orig = shift;
    my $this = shift;
    return $this->env->{REMOTE_USER};
};

around _preparePath => sub {
    my $orig = shift;
    my ($this) = @_;

    # SMELL: "The Microsoft Internet Information Server is broken with
    # respect to additional path information. If you use the Perl DLL
    # library, the IIS server will attempt to execute the additional
    # path information as a Perl script. If you use the ordinary file
    # associations mapping, the path information will be present in the
    # environment, but incorrect. The best thing to do is to avoid using
    # additional path information."

    # Clean up PATH_INFO problems, e.g.  Support.CobaltRaqInstall.  A valid
    # PATH_INFO is '/Main/WebHome', i.e. the text after the script name;
    # invalid PATH_INFO is often a full path starting with '/cgi-bin/...'.
    my $pathInfo = $this->env->{PATH_INFO} || '';

    if ( $pathInfo =~ m/['"]/g ) {
        $pathInfo = substr( $pathInfo, 0, ( ( pos $pathInfo ) - 1 ) );
    }

    unless ( defined $this->env->{SCRIPT_NAME} ) {

        # CGI/1.1 (rfc3875) states that the server MUST set
        # SCRIPT_NAME, so if it doens't we have a broken server
        Foswiki::Exception::Engine->throw(
            header => 'Inernal Server Error',
            text   => 'SCRIPT_NAME environment variable not defined',
        );
    }
    my $cgiScriptPath = $this->env->{SCRIPT_NAME};
    $pathInfo =~ s{^$cgiScriptPath(?:/+|$)}{/};
    my $cgiScriptName = $cgiScriptPath;
    $cgiScriptName =~ s/.*?(\w+)(\.\w+)?$/$1/;

    my $action;
    if ( exists $this->env->{FOSWIKI_ACTION} ) {

        # This handles scripts that have set $FOSWIKI_ACTION
        $action = $this->env->{FOSWIKI_ACTION};
    }
    elsif ( exists $Foswiki::cfg{SwitchBoard}{$cgiScriptName} ) {

        # This handles other named CGI scripts that have a switchboard entry
        # but haven't set $FOSWIKI_ACTION (old-style run scripts)
        $action = $cgiScriptName;
    }
    elsif ( length $pathInfo > 1 ) {

        # Use the first path el after the script
        # name as the function
        $pathInfo =~ m{^/([^/]+)(.*)};
        my $first = $1;    # implicit untaint OK; checked below
        if ( exists $Foswiki::cfg{SwitchBoard}{$first} ) {

            # The path is of the form script/function/...
            $action = $first;
            $pathInfo = $2 || '';
        }
    }
    $action ||= 'view';
    ASSERT( defined $pathInfo ) if DEBUG;
    return {
        action    => $action,
        path_info => $pathInfo,
        uri       => $this->env->{REQUEST_URI} // undef,
    };
};

sub _prepareCGI {
    my ($this) = @_;

    return unless $this->env->{CONTENT_LENGTH};

    # Record the master process so we don't reap temp files in
    # sub-processes (see long comment ****)
    $CONSTRUCTOR_PID = $$;

    # Note that we handle unicode conversion in the various prepare*
    # methods, rather than using the CGI -utf8 option, which is documented
    # as breaking uploads (though cdot believes this is because of the
    # deprecated dual nature of param delivering lightweight file handles,
    # and it would probably work in Foswiki. Just not tried it)
    my $cgi = new CGI();
    my $err = $cgi->cgi_error;
    Foswiki::Exception::Engine->throw( status => $1, text => $2 )
      if defined $err && $err =~ m/\s*(\d{3})\s*(.*)/;
    return $cgi;
}

around _prepareBodyParameters => sub {
    my $orig = shift;
    my $this = shift;

    return [] unless $this->env->{CONTENT_LENGTH};
    my @plist = $this->cgi->multi_param();
    my @params;
    foreach my $pname (@plist) {
        my $upname = NFC( Foswiki::decode_utf8($pname) );
        my @values;
        if ($Foswiki::UNICODE) {
            @values =
              map { NFC( Foswiki::decode_utf8($_) ) }
              $this->cgi->multi_param($pname);
        }
        else {
            @values = $this->cgi->multi_param($pname);
        }
        my $param = { -name => $upname, -value => \@values };

        # Note that we record the encoded name of the upload. It will be
        # decoded in prepareUploads, which rewrites the {uploads} hash.
        $param->{-upload} = 1 if scalar( $this->cgi->upload($pname) );

        push @params, $param;
    }
    return \@params;
};

around prepareUploads => sub {
    my $orig = shift;
    my ( $this, $req ) = @_;

    return unless $this->env->{CONTENT_LENGTH};
    my %uploads;
    foreach my $key ( keys %{ $this->uploads } ) {
        my $fname  = $this->cgi->param($key);
        my $ufname = NFC( Foswiki::decode_utf8($fname) );
        $uploads{$ufname} = new Foswiki::Request::Upload(
            headers => $this->cgi->uploadInfo($fname),
            tmpname => $this->cgi->tmpFileName($fname),
        );
    }
    $this->clear_uploads;
    $req->uploads( \%uploads );
};

around finalizeReturn => sub {
    my $orig     = shift;
    my $this     = shift;
    my ($return) = @_;

    $this->write( $this->stringifyHeaders($return) );
    $this->write( @{ $return->[2] } );

    return 0;
};

around stringifyHeaders => sub {
    my $orig     = shift;
    my $this     = shift;
    my ($return) = @_;

    # Add the Status header which is not there by PSGI spec.
    push @{ $return->[1] }, 'Status' => $return->[0];
    return $orig->( $this, $return );
};

around write => sub {
    my $orig = shift;
    my ( $this, $buffer ) = @_;
    print $buffer;
};

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved. TWiki Contributors
are listed in the AUTHORS file in the root of this distribution.

This module is based/inspired on Catalyst framework. Refer to
http://search.cpan.org/~mramberg/Catalyst-Runtime-5.7010/lib/Catalyst.pm
for credits and license details.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
