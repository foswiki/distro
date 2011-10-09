# Run _all_ test suites in the current directory (core and plugins)
require 5.006;

package FoswikiSuite;
use Unit::TestSuite;
use Cwd;
our @ISA = qw( Unit::TestSuite );

use strict;

# Assumes we are run from the "test/unit" directory

sub list_tests {
    return ();
}

sub include_tests {
    my $this = shift;
    my $here = Cwd::abs_path;
    ($here) = $here =~ m/^(.*)$/;  # untaint
    push( @INC, $here );
    my @list;
    opendir( DIR, "." ) || die "Failed to open .";
    foreach my $i ( sort readdir(DIR) ) {
        next if $i =~ /^Empty/ || $i =~ /^\./;
next if $i =~ /^FoswikiSuite/;
next if $i =~ /^AccessControlTests/;
next if $i =~ /^AddressTests/;
next if $i =~ /^AdminOnlyAccessControlTests/;
next if $i =~ /^AttrsTests/;
next if $i =~ /^AutoAttachTests/;
next if $i =~ /^CacheTests/;
next if $i =~ /^ClientTests/;
next if $i =~ /^ConfigureTests/;
next if $i =~ /^DependencyTests/;
next if $i =~ /^ExampleTests/;
next if $i =~ /^ExceptionTests/;
next if $i =~ /^ExpandMacrosTests/;
next if $i =~ /^Fn_ENCODE/;
next if $i =~ /^Fn_FORMAT/;
next if $i =~ /^Fn_FORMFIELD/;
next if $i =~ /^Fn_GROUPINFO/;
next if $i =~ /^Fn_GROUPS/;
next if $i =~ /^Fn_ICON/;
next if $i =~ /^Fn_IF/;
next if $i =~ /^Fn_INCLUDE/;
next if $i =~ /^Fn_MAKETEXT/;
next if $i =~ /^Fn_NOP/;
next if $i =~ /^Fn_QUERY/;
next if $i =~ /^Fn_QUERYPARAMS/;
next if $i =~ /^Fn_REVINFO/;
next if $i =~ /^Fn_SCRIPTURL/;
next if $i =~ /^Fn_SEARCH/;
next if $i =~ /^Fn_SECTION/;
next if $i =~ /^Fn_SEP/;
next if $i =~ /^Fn_TOPICLIST/;
next if $i =~ /^Fn_URLPARAM/;
next if $i =~ /^Fn_USERINFO/;
next if $i =~ /^Fn_VAR/;
next if $i =~ /^Fn_WEBLIST/;
next if $i =~ /^FormDefTests/;
next if $i =~ /^FormattingTests/;
next if $i =~ /^FoswikiPmFunctionsTests/;
next if $i =~ /^FuncTests/;
next if $i =~ /^FuncUsersTests/;
next if $i =~ /^HTMLValidationTests/;
next if $i =~ /^HierarchicalWebsTests/;
next if $i =~ /^HoistREsTests/;
next if $i =~ /^InitFormTests/;
next if $i =~ /^JSCalendarContribTests/;
next if $i =~ /^LoadedRevTests/;
next if $i =~ /^ManageDotPmTests/;
next if $i =~ /^MergeTests/;
next if $i =~ /^MetaTests/;
next if $i =~ /^NetTests/;
next if $i =~ /^PasswordTests/;
next if $i =~ /^PluginHandlerTests/;
next if $i =~ /^PrefsTests/;
next if $i =~ /^QueryTests/;
next if $i =~ /^RCSHandlerTests/;
next if $i =~ /^RESTTests/;
next if $i =~ /^RegisterTests/;
next if $i =~ /^RenameTests/;
next if $i =~ /^RenderFormTests/;
next if $i =~ /^RequestCacheTests/;
next if $i =~ /^RequestTests/;
next if $i =~ /^ResponseTests/;
next if $i =~ /^RobustnessTests/;
next if $i =~ /^SaveScriptTests/;
next if $i =~ /^SeleniumConfigTests/;
next if $i =~ /^SemiAutomaticTestCaseTests/;
#next if $i =~ /^StoreTests/;
next if $i =~ /^TOCTests/;
next if $i =~ /^TemplatesTests/;
next if $i =~ /^TimeTests/;
next if $i =~ /^UIFnCompileTests/;
 next if $i =~ /^UTF8Tests/;
next if $i =~ /^UploadScriptTests/;

        if ( $i =~ /^Fn_[A-Z]+\.pm$/ || $i =~ /^.*Tests\.pm$/ ) {
            push( @list, $i )
              unless $i =~ /EngineTests\.pm/;

            # the engine tests break logging, so do them last
        }
last if $i =~ /^VCMetaTests/;
    }
    closedir(DIR);

#    # Add standard extensions tests
#    my $read_manifest = 0;
#    my $home          = "../..";
#    unless ( -e "$home/lib/MANIFEST" ) {
#        $home = $ENV{FOSWIKI_HOME};
#    }
#    require Cwd;
#    $home = Cwd::abs_path($home);
#    ($home) = $home =~ m/^(.*)$/;  # untaint
#
#    print STDERR "Getting extensions from $home/lib/MANIFEST\n";
#    if ( open( F, "$home/lib/MANIFEST" ) ) {
#        $read_manifest = 1;
#    }
#    else {
#
#        # dunno which extensions we require
#        $read_manifest = 0;
#    }
#    if ($read_manifest) {
#        local $/ = "\n";
#        while (<F>) {
#            if (m#^!include ([\w.]+)/.*?/(\w+)$#) {
#                my $d = "$home/test/unit/$2";
#                next unless ( -e "$d/${2}Suite.pm" );
#                push( @list, "${2}Suite.pm" );
#                ($d) = $d =~ m/^(.*)$/;
#                push( @INC,  $d );
#            }
#        }
#        close(F);
#    }
#    push( @list, "UnitTestContribSuite.pm" );
    push( @INC, "$here/UnitTestContrib");
#    push( @list, "EngineTests.pm" );

    print STDERR "Running tests from ", join( ', ', @list ), "\n";

    #foreach my $dir ( @INC ) {
    #   print "Checking $dir \n"; 
    #   Assert::UNTAINTED( $dir );
    #}

    return @list;
}

1;
