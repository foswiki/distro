#! /usr/bin/perl -w
# See http://twiki.org/cgi-bin/view/Codev/FixUpHtaccess
# This will become a CommandSet for twikishell in Edinburgh

replaceBinHtaccess(@ARGV);
my @subdirs = qw(lib data templates locale);
installHtaccess('subdir-htaccess.txt', @subdirs);
installHtaccess('pub-htaccess.txt', 'pub');
#installRedirectRoot(".");
print adminLoginNameMessage();

use File::Copy;

sub installHtaccess {
    my ($htaccess, @targetDir) = @_;

    foreach my $dir (@targetDir) {
	my $targetFile = $dir.'/.htaccess';
	if (copy($htaccess, $targetFile)) {
	    print "Copied $htaccess to $targetFile\n";
	} else {
	    print "Failed to copy $htaccess to $targetFile $?\n";
	}
    } 
}

sub installRedirectRoot {
    my ($dir) = @_;
    my $rootIndexFile = '$dir/index.html';

    open FH, ">$rootIndexFile" || die "$@";
    print FH "<META HTTP-EQUIV='Refresh' CONTENT='0; URL=bin/view'>\n";
    close FH;
    print "Replaced $rootIndexFile with redirect\n";
}


# e.g. ("/home/mrjc/wikiconsulting.com/twiki/data", "wikiconsulting.com/twiki");

# {DataDir}
#    Get the value from =configure=
# {DefaultUrlHost}
#    Get the value from =configure=
# {ScriptUrlPath}
#    Get the value from =configure=
# {Administrators}

sub replaceBinHtaccess {
    my ($dataDir, $defaultUrlHost, $scriptUrlPath, $adminUsers) = getParams(@_); 

    my $patterns = {"{DataDir}" => $dataDir,
		    "{DefaultUrlHost}" => $defaultUrlHost,
		    "{ScriptUrlPath}" => $scriptUrlPath,
		    "{Administrators}" => $adminUsers};
    use Data::Dumper;
    print Dumper $patterns;

    unless (-d "bin") {
	die "This must be run in the top level directory";
    }
    
    use FileHandle;
    my $template = readBinHtaccessTemplate();
    writeBinHtaccess(doSubstitutions($template, $patterns));
}

sub readBinHtaccessTemplate {
    my $htaccessTXTfh = new FileHandle("< bin/.htaccess.txt");
    local $/; undef $/;
    my $content = <$htaccessTXTfh>;
    close $htaccessTXTfh;
    return $content;
}

sub doSubstitutions {
    my ($template, $patterns) = @_;
    foreach my $key (keys %$patterns) {
	my $value = $patterns->{$key};
	print "Replaced $key with $value ";
	my $count = $template =~ s/$key/$value/g;
	print "$count times\n";
    }
    return $template;
}

sub writeBinHtaccess {
    my ($content) = @_;
    my $htaccessFh = new FileHandle("> bin/.htaccess");
    print $htaccessFh $content;
    close $htaccessFh;
}

print `chmod og-w bin bin/*`;

sub getParams {
    my ($dataDir, $defaultUrlHost, $scriptUrlPath, $adminUsers) = @_;

  unless ($dataDir) {
    die "ERROR: dataDir missing\n".usage();
  }
  unless ($defaultUrlHost) {
    die "ERROR: defaultUrlHost missing\n".usage();
  }

  unless ($scriptUrlPath) {
    die "ERROR: scriptUrlPath missing\n".usage();
  } 

   unless ($adminUsers) {
	die "ERROR: adminUsers missing\n".usage();
    }


  unless (-d $dataDir) {
    die "The directory for dataDir '$dataDir' does not exist";
  }
  return ($dataDir, $defaultUrlHost, $scriptUrlPath, $adminUsers)

}

sub usage {
  my $ans = <<EOM;
Usage
=====

pseudo-install-twiki.pl \$dataDir, \$defaultUrlHost, \$scriptUrlPath, \$adminUsers

dataDir = location on the disk for TWiki root dir
defaultUrlHost = hostname TWiki is running on
scriptUrlPath  = base URL of TWiki when accessed by web 
adminUsers      = which .htpasswd users can access configure

e.g.
pseudo-install-twiki.pl /home/account/wikiconsulting.com/twiki/data wikiconsulting.com /twiki YourAdminLoginName

EOM
 $ans .= 

  return $ans.".";
}

sub adminLoginNameMessage {

return <<EOM

Note that you are responsible for putting an Admin LoginName into data/.htpasswd.
On UNIX you can use the htpasswd tool for this.

e.g. htpasswd -c data/.htpasswd AdminLoginName 
EOM

}
