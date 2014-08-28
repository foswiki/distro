# Foswiki Installation based on git

You can run a Foswiki instance from this clone simply by pointing Apache at it in the normal way and running `configure`.
Note however it will be missing all the extensions.  Read on for instructions on how to install the default extensions shipped with Foswiki.

**Note: Configure is currently broken in the master branch.  We hope to resovle this shortly.  We recommend using the Release01x01 branch.**

By default the cloned Foswiki core won't have any of the extensions (plugins or contribs) installed.   Default extensions are downloaded one level up from the Foswiki core:

To "install" extensions in a checkout area, you should use the `pseudo-install.pl` script to install them. On Unix/Linux this script generates soft-links from the core tree
to the extensions, so you can work on your code in situ and see the impact of the changes on your live foswiki without needing to do an install step.
Windows doesn't support soft links, so the script can also be run in `-copy` mode (the default on Windows), but in this case you will have to re-run it each time you change your extension.
*Remember that you have to enable any plugins you want to test* in `configure`. Use:
 - `pseudo-install.pl default` to install the default contribs and plugins (e.g. Extensions.TwistyContrib which is relied on by Extensions.PatternSkin)
 - `pseudo-install.pl developer` to install the additional developer extensions.  The developer option also installs all the default extensions.
See the header comment of the `pseudo-install.pl` script (core directory of checkout) for options and more information.
Note that `pseudo-install.pl` only works with extensions that have a MANIFEST file, as required by the Extensions.BuildContrib.

Script examples below are for `bash` shell.
## Example of running pseudo-install

The typical situation is that you want to run a pseudo-installed Foswiki checked out from "master" branch. (But use Release01x01 for now)
And if you develop plugins, you want to be able to activate your plugin in this installation. This is the entire sequence for checking out the master branch from git
and doing the pseudo-install. We assume that you want to run your git based install in `/var/www/foswiki`

The following commands check out an _absolutely minimal_ Foswiki (the core + default user mapping only). This is the smallest checkout that will run. The steps are:
 1. create the root directory called foswiki
 1. `git clone https://github.com/foswiki/distro.git foswiki`
 1. This will check out core and all the default and developer extensions, however they are not installed yet.
 1. `cd core && ./pseudo-install default`
 1. change the ownership so the entire tree is owned by the user running the Apache. In this example the user name is "apache".
 1. point Apache at the checkout
Change the commands to fit your actual file locations and Apache user. Some commands may have to be run as root.

```
cd /var/www
mkdir foswiki

git clone https://github.com/foswiki/distro.git foswiki
Cloning into 'foswiki'...
remote: Counting objects: 134190, done.
remote: Compressing objects: 100% (37847/37847), done.
remote: Total 134190 (delta 87343), reused 132136 (delta 85289)
Receiving objects: 100% (134190/134190), 66.86 MiB | 1.63 MiB/s, done.
Resolving deltas: 100% (87343/87343), done.
Checking connectivity... done.

# By default this will leave you in the "master" branch, where leading edge development happens
# If you want to use the current release branch, change to the Release01x01 branch
# Skip this step if you want to remain on the experimental master branch.

cd foswiki
git checkout Release01x01
Branch Release01x01 set up to track remote branch Release01x01 from origin.
Switched to a new branch 'Release01x01'

# The extensions have all been checked out one level up from the "core" directory
# the next step is to link / copy them into the installation.  This is done with pseudo-install.

cd core
perl -T pseudo-install.pl default
Installing extensions: PatchFoswikiContrib, AutoViewTemplatePlugin, CompareRevisionsAddOn, CommentPlugin, EditTablePlugin, EmptyPlugin, FamFamFamContrib, HistoryPlugin, InterwikiPlugin, JSCalendarContrib, JQueryPlugin, MailerContrib, TablePlugin, TwistyPlugin, PatternSkin, PreferencesPlugin, RenderListPlugin, SlideShowPlugin, SmiliesPlugin, SpreadSheetPlugin, TipsContrib, WysiwygPlugin, TinyMCEPlugin, TopicUserMappingContrib, TWikiCompatibilityPlugin, core
Processing AutoViewTemplatePlugin
Linked data/System/AutoViewTemplatePlugin.txt
mkdir /var/www/fw/core/lib/Foswiki/Plugins
...
#...
#... A large amount of output is generated.
#... Errors about dependencies on foswiki extensions can generally be ignored.
#... The extensions are not installed in the order that would resolve all dependencies.
#...


# If necessary, change ownership of all files to the webserver user.
# In this case that is 'apache:apache', though it may also be 'www-data:www-data'
# e.g. on Debian and Ubuntu systems, or something else entirely. Check first.
chown -R apache:apache foswiki

# Now configure Apache to use the Foswiki in /var/www/foswiki/core
```

 1. Use the [ApacheConfigGenerator](http://foswiki.org/Support/ApacheConfigGenerator?foswikiversion=1.1&vhost=&port=&timeout=&dir=%2Fvar%2Fwww%2Ffoswiki&symlink=on&pathurl=%2Ffoswiki&shorterurls=enabled&engine=CGI&fastcgimodule=fastcgi&fcgidreqlen=&apver=2&allowconf=&reqandor=and&requireconf=&loginmanager=Template&htpath=&errordocument=UserRegistration&errorcustom=&phpinstalled=PHP4&blockpubhtml=on#HighLight)
 1. Clipboard copy and save this to core/../foswiki.httpd.conf
 -* cat &gt; foswiki-svn_httpd.conf
 1. Include this httpd.conf from your apache httpd.conf
 -* If you are on a Mac, you can put this file into /etc/apache2/other/ and line "Include /private/etc/apache2/other/*.conf" will pick it up.
 -* Otherwise, edit your httpd.conf and add: Include /path/to/foswiki-svn_httpd.conf
 -* Ensure your new .conf file has chmod a+r access
**Note:** If the apache error log has lots of `Symbolic link not allowed or link target not accessible` type messages, then you probably need to add `+FollowSymLinks`
to the `Options` for the `/var/www/foswiki/dev/core/pub` directory in your apache configuration.

Now and then you will want to keep your installation in sync with the latest version in the foswiki git repository. The pseudo-install script is not intelligent enough to cope with changes to MANIFESTs, so this is the idiot proof way to update. It first removes all the links (or copied files), git fetch. And finally does a new pseudo-install.
```
cd /var/www/foswiki/core
./pseudo-install.pl -uninstall all
git pull
./pseudo-install.pl default
chown -R apache:apache ..
```

Normally just doing the git pull will be enough, unless someone has removed files (and even then you can usually ignore it).

If you are a developer you can also install the kit required to run unit tests, by passing the `developer` parameter to `pseudo-install.pl`
```
cd /var/www/foswiki/core
./pseudo-install.pl developer
```

This will also install [BuildContrib](http://foswiki.org/Extensions/BuildContrib) and a number of other components useful to developers.

## Tips, hints, and useful commands
### Enable ASSERTS for more extensive testing

The unit tests run with ASSERTS enabled, but the live web environment does not.  In order to enable ASSERTS, edit `bin/LocalLib.cfg` (If it's not there, create it by copying `bin/LocalLib.cfg.txt`) and un-comment the following line
```
$ENV{FOSWIKI_ASSERTS} ` 1;
```

This enables additional validation tests that will impact performance, but will catch some issues that might be missed during normal web usage.


### Use the CPAN modules shipped with Foswiki

Foswiki ships with a number of CPAN modules that are used only when the underlying platform is missing the modules.  In order to test using the modules that are shipped with Foswiki, CPAN lib prepending should be enabled in <span>bin/LocalLib.cfg</span>by uncommenting the following line:

```
$CPANBASE ` '';                     # Uncommented: Default path prepended
```

.   See the comments in `bin/LocalLib.cfg.txt` for more details.

It is probably best to test using platform modules as well as the shipped modules.

### Installing non-default extensions

The example commands above describe how to install a _minimalist_ Foswiki.    The pseudo-install script knows some additional tricks to use with non-default extensions. If you pseudo-install an extension that is not currently checked out,  pseudo-install will automatically clone the extension from github using  `https://github.com/foswiki/ExtensionName.git`

**Note:** Although we use release managed branches  (master, Release01x00, Release01x01) in the Foswiki core distribution ("distro"), non-default extensions typically only have a "master" branch.

Here's how to install a non-default extension, using AntiWikiSpamPlugin as an example:
```
cd foswiki/core
 ./pseudo-install.pl AntiWikiSpamPlugin
Useless use of \E at ./pseudo-install.pl line 1553.
Useless use of \E at ./pseudo-install.pl line 1553.
Installing extensions: AntiWikiSpamPlugin
Processing AntiWikiSpamPlugin
Trying clone from git://github.com/foswiki/AntiWikiSpamPlugin.git...
Cloning into 'AntiWikiSpamPlugin'...
remote: Counting objects: 489, done.
remote: Total 489 (delta 0), reused 0 (delta 0)
Receiving objects: 100% (489/489), 86.42 KiB | 0 bytes/s, done.
Resolving deltas: 100% (185/185), done.
Checking connectivity... done.
Cloned AntiWikiSpamPlugin OK
Linked data/Main/AntiWikiSpamBypassGroup.txt
Linked data/System/AntiWikiSpamLocalList.txt
Linked data/System/AntiWikiSpamRegistrationWhiteList.txt
Linked data/System/AntiWikiSpamRegistrationBlackList.txt
Linked data/Sandbox/AntiWikiSpamTestTopic.txt
Linked data/System/AntiWikiSpamPlugin.txt
Linked lib/Foswiki/Plugins/AntiWikiSpamPlugin.pm
Linked lib/Foswiki/Plugins/AntiWikiSpamPlugin
Linked test/unit/AntiWikiSpamPlugin
Linked /var/www/fw/core/tools/develop/githooks/commit-msg as /var/www/fw/AntiWikiSpamPlugin/.git/hooks/commit-msg
Linked /var/www/fw/core/tools/develop/githooks/pre-commit as /var/www/fw/AntiWikiSpamPlugin/.git/hooks/pre-commit
Linked /var/www/fw/core/tools/develop/githooks/commit-msg as /var/www/fw/AntiWikiSpamPlugin/../.git/hooks/commit-msg
Linked /var/www/fw/core/tools/develop/githooks/pre-commit as /var/www/fw/AntiWikiSpamPlugin/../.git/hooks/pre-commit
 AntiWikiSpamPlugin installed
Linked /var/www/fw/core/tools/develop/githooks/commit-msg as /var/www/fw/core/.git/hooks/commit-msg
Linked /var/www/fw/core/tools/develop/githooks/pre-commit as /var/www/fw/core/.git/hooks/pre-commit
Linked /var/www/fw/core/tools/develop/githooks/commit-msg as /var/www/fw/core/../.git/hooks/commit-msg
Linked /var/www/fw/core/tools/develop/githooks/pre-commit as /var/www/fw/core/../.git/hooks/pre-commit
```

### Delete all broken soft links

This is handy if you have changed a lot of MANIFESTS or have manually soft-linked any files, and want to remove any broken soft links. Assume your trunk checkout is at `/var/www/foswiki`.
You'll also need to do this when switching between Release01x01 and master branches.

```
find -L /var/www/foswiki/core -type l -exec rm \{\} \;
```

### Create a new extension

You can quickly and easily create a new extension using the `create_new_extension.pl` script that is installed in `core` when you pseudo-install the Extensions.BuildContrib.

### Set up the unit test framework

If you are developing new code you will want to set up the development and test environment. For this you will need to pseudo-install !BuildContrib, !UnitTestContrib and !TestFixturePlugin.

```
./pseudo-install.pl developer
```

Then:
```
cd test/unit
export FOSWIKI_LIBS`/var/www/foswiki/core/lib
perl ../bin/TestRunner.pl FoswikiSuite
```

(or equivalent on Windows)

For full details, see http://foswiki.org/Development/UnitTests#SettingUpATestEnvironment


