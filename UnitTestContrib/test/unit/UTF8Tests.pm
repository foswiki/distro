#
# Currently a mostly empty test package; waiting for someone with an interest
# in UTF-8 to develop some meaningful tests. Specifically, manipulation of
# $Foswiki::cfg{Site}{CharSet}
# $Foswiki::cfg{UseLocale}
# $Foswiki::cfg{Site}{Locale}
# $Foswiki::cfg{Site}{Lang}
# $Foswiki::cfg{Site}{FullLang}
# $Foswiki::cfg{Site}{LocaleRegexes}
# to provide coverage of all the options (bearing in mind that you are going
# to have to work out how to re-initialise Foswiki for each test)
#
package UTF8Tests;
use base qw(FoswikiFnTestCase);

use strict;

use Foswiki;

sub DISABLEtest_urlEncodeDecode {
    my $this = shift;
    my $s    = '';
    my $t    = '';

    for ( my $i = 0 ; $i < 256 ; $i++ ) {
        $s .= chr($i);
    }
    $t = Foswiki::urlEncode($s);
    $this->assert( $s eq Foswiki::urlDecode($t) );

    $s = Foswiki::urlDecode('%u7FFF%uA1EE');
    $this->assert_equals( chr(0x7FFF) . chr(0xA1EE), $s );

    $s = Foswiki::urlDecode('%ACTION{}%');
    $this->assert_equals( chr(0xAC) . 'TION{}%', $s );
}

sub test_segfault1 {
    my $this = shift;
    my $s    = <<'EOS';
---+!! %TOPIC%

i spoke with Spum Garbo on IRC today (transcript enclosed).  it didn't start out as a long chat, but evolved into one.  

in the short term, 


<verbatim>
*** Logfile started
*** on Thu Mar 16 14:05:04 2006

zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz?
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz zz zz TODO zzzz
[Tzz Mzz 16 2006] [14:42:10] *RzzRzzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz zzzz zzzzzz :)
[Tzz Mzz 16 2006] [14:42:31] *RzzRzzzzz*	zzz zzzzz zzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:42:44] *zzzzz*zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz"
[Tzz Mzz 16 2006] [14:42:55] *zzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:43:01] *RzzRzzzzz*	zzzzzzzzzzz zzzzzz
[Tzz Mzz 16 2006] [14:43:03] *zzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz zzzzzz
[Tzz Mzz 16 2006] [14:43:39] *zzzzz*	zzzzz zzz
[Tzz Mzz 16 2006] [14:44:02] *zzzzz*	zz zzzzz zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:44:18] *zzzzz*	zzzzzz z zzzzz zzzzz
[Tzz Mzz 16 2006] [14:44:25] *RzzRzzzzz*	zzz zzz zz zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:44:35] *zzzzz*	zzz
[Tzz Mzz 16 2006] [14:44:53] *zzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:45:21] *zzzzz*	(zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz)
[Tzz Mzz 16 2006] [14:45:39] *zzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:45:46] *zzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:45:52] *zzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzz)
[Tzz Mzz 16 2006] [14:46:09] *zzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz, zzz), zzz, zzz, zzz
[Tzz Mzz 16 2006] [14:46:24] *zzzzz*	z zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:46:33] *zzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:46:58] *zzzzz*	(zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz...)
[Tzz Mzz 16 2006] [14:47:05] *zzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:48:01] *zzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz"
[Tzz Mzz 16 2006] [14:48:09] *zzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:48:15] *zzzzz*	zz zzzzzzzz
[Tzz Mzz 16 2006] [14:48:23] *RzzRzzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz?
[Tzz Mzz 16 2006] [14:49:01] *zzzzz*	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;z
[Tzz Mzz 16 2006] [14:49:06] *RzzRzzzzz*	zz''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''zzz
[Tzz Mzz 16 2006] [14:49:20] *zzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz?
[Tzz Mzz 16 2006] [14:49:21] *RzzRzzzzz*	z00000000000000000000000000000000000000000000000000000000000000000000000000000000000zz
[Tzz Mzz 16 2006] [14:49:28] *RzzRzzzzz*	zzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:49:32] *RzzRzzzzz*	zzzzzzzzz zzzz zzzzzzz
[Tzz Mzz 16 2006] [14:49:41] *zzzzz*	zzzzzzzzzz?
[Tzz Mzz 16 2006] [14:49:43] *RzzRzzzzz*	zzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:49:51] *RzzRzzzzz*	zzzzzzzz zzzz
[Tzz Mzz 16 2006] [14:49:53] *zzzzz*	zz
[Tzz Mzz 16 2006] [14:50:02] *zzzzz*	zzzzzzzzzzzzzzzzzzz6666666666666666zz
[Tzz Mzz 16 2006] [14:50:05] *RzzRzzzzz*	z666666666666666666666666666666666666666666666666z zzz zz zz
[Tzz Mzz 16 2006] [14:50:09] *zzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz" :)
[Tzz Mzz 16 2006] [14:50:16] *zzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:50:27] *zzzzz*	1333333333333333333333333333333333333333333333333333333333zzzz
[Tzz Mzz 16 2006] [14:50:34] *zzzzz*	2zzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:50:59] *RzzRzzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:51:06] *zzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:51:10] *zzzzz*	z2222222222222zz 
[Tzz Mzz 16 2006] [14:51:15] *RzzRzzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:51:17] *zzzzz*	zzzz
[Tzz Mzz 16 2006] [14:51:25] *zzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:51:38] *zzzzz*	(zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz)
[Tzz Mzz 16 2006] [14:51:58] *zzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:52:31] *zzzzz*	(z66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666zzz
[Tzz Mzz 16 2006] [14:52:36] *zzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:52:47] *zzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:53:01] *zzzzz*	88888888888888888888888888888888888888888888888888888888zzzz
[Tzz Mzz 16 2006] [14:53:09] *zzzzz*	z666666666666666666666666666666666666zz
[Tzz Mzz 16 2006] [14:53:17] *RzzRzzzzz*	:)
[Tzz Mzz 16 2006] [14:53:34] *RzzRzzzzz*	z6666666666666666666666666666666666666666666666666666666zz :)
[Tzz Mzz 16 2006] [14:53:43] *zzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz),
[Tzz Mzz 16 2006] [14:54:13] *zzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:54:21] *zzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:54:27] *RzzRzzzzz*	zzzz
[Tzz Mzz 16 2006] [14:54:30] *zzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:54:45] *zzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:54:57] *RzzRzzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:55:10] *RzzRzzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz?
[Tzz Mzz 16 2006] [14:55:34] *zzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz...
[Tzz Mzz 16 2006] [14:55:43] *zzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:55:47] *zzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzz :)
[Tzz Mzz 16 2006] [14:55:58] *zzzzz*	zzzzzz = zzzzzzz
[Tzz Mzz 16 2006] [14:56:11] *RzzRzzzzz*	zzz
[Tzz Mzz 16 2006] [14:56:16] *zzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:56:23] *zzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz :)
[Tzz Mzz 16 2006] [14:56:38] *RzzRzzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:56:49] *zzzzz*	zzzzzzzzzz!
[Tzz Mzz 16 2006] [14:56:57] *zzzzz*	zzz zzzzzzzzzzzzzzzzzzzzzzzzzzzzz ;-(
[Tzz Mzz 16 2006] [14:57:15] *RzzRzzzzz*	zzz zz zzz zzzz zzzzzzzzzzzzzzzzzzzzzz?
[Tzz Mzz 16 2006] [14:57:19] *zzzzz*	HORRIBLE
[Tzz Mzz 16 2006] [14:57:31] *RzzRzzzzz*	z zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:57:33] *zzzzz*	zz zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz'z zzzzz zz zzzzzzz
[Tzz Mzz 16 2006] [14:57:41] *zzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz zzzzzz
[Tzz Mzz 16 2006] [14:57:47] *zzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:57:56] *zzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz zzzzz
[Tzz Mzz 16 2006] [14:58:08] *zzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz)
[Tzz Mzz 16 2006] [14:58:12] *RzzRzzzzz*	zzzzzzzzzzzzzzzzzzzz :)
[Tzz Mzz 16 2006] [14:58:17] *zzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:58:31] *zzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:58:35] *zzzzz*	(zzzzzzzzzzzzzzzzzzzzzzz)
[Tzz Mzz 16 2006] [14:58:50] *RzzRzzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:58:53] *zzzzz*	zzzzz, zzzz
[Tzz Mzz 16 2006] [14:59:08] *RzzRzzzzz*	zzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:59:24] *zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz :)
[Tzz Mzz 16 2006] [14:59:26] *zzzzz*	zzzz, zzzzzz
[Tzz Mzz 16 2006] [14:59:31] *RzzRzzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzD
[Tzz Mzz 16 2006] [14:59:44] *zzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:59:58] *zzzzz*	zzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [15:00:02] *zzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [15:00:09] *RzzRzzzzz*	zzzz
[Tzz Mzz 16 2006] [15:00:21] *RzzRzzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [15:01:47] *RzzRzzzzz*	zz55554zzzzzzzzzzzzz3zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [15:02:00] *RzzRzzzzz*	zzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [15:03:26] *RzzRzzzzz*	zzz zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [15:03:41] *RzzRzzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [15:07:10] *zzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz"
[Tzz Mzz 16 2006] [15:07:21] *zzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz zzzz 
[Tzz Mzz 16 2006] [15:07:23] *zzzzz*	zzzzzzzzzz
[Tzz Mzz 16 2006] [15:07:31] *RzzRzzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz zzz
[Tzz Mzz 16 2006] [15:07:38] *zzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz)
[Tzz Mzz 16 2006] [15:07:40] *RzzRzzzzz*	z zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz zz
[Tzz Mzz 16 2006] [15:07:48] *zzzzz*	z zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [15:07:56] *zzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [15:08:08] *zzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz :)
[Tzz Mzz 16 2006] [15:08:26] *zzzzz*	zzzzzzzzzzzzzzzzzzzzz zz zzz
[Tzz Mzz 16 2006] [15:08:46] *zzzzz*	zz zzzzzzzzz zzzz z zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz zz
[Tzz Mzz 16 2006] [15:09:00] *zzzzz*	zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [15:09:08] *zzzzz*	zzzz z zzzz zzzzzz
[Tzz Mzz 16 2006] [15:09:25] *zzzzz*	zzz z zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz)
[Tzz Mzz 16 2006] [15:09:32] *zzzzz*	zzzz zzz zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [15:10:01] *zzzzz*	(zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz)
[Tzz Mzz 16 2006] [15:10:04] *RzzRzzzzz*	zzzz zzzz, zzzz z zzz zzz zzzzzzzzz z zzz zzzzz, zzz z'z zzzzzzzzz zz zzzzzzzzzz zzzzzzz
[Tzz Mzz 16 2006] [15:10:59] *zzzzz*	zzzzzzz zz zz zzzzz zzzzzzz zzzz zzzzz z zzz zzzzzzzzzzz zzz zzz zzzzzzz zzzzz zzzzz zzzzzzz zzz zzzzzzz zzzz zzz zzzzzzzzz
[Tzz Mzz 16 2006] [15:11:05] *RzzRzzzzz*	zzz zz zzz zzz zzz zz zz z zzzzzz zzzzzzz zzzzzzz, z zzzzz z zzzzzzzzzz zzzzzzz zzzzz zz z zzz zzzz zzzzzzzzzzz
[Tzz Mzz 16 2006] [15:11:09] *zzzzz*	zz zzz zz zzzzzzzz zzzzzzz, zzzz zzzzzzz 
[Tzz Mzz 16 2006] [15:11:22] *RzzRzzzzz*	zzzzzzz = PXE?
[Tzz Mzz 16 2006] [15:11:32] *zzzzz*	PXE zz zzzzzz, zzz
[Tzz Mzz 16 2006] [15:11:37] *zzzzz*	zzzzz zz zzzzzz
[Tzz Mzz 16 2006] [15:11:58] *RzzRzzzzz*	zzz.. zzz zzzz zzzzzzz zzzz zzzzz zzzz zzzz zz zzzzzzzz zzz z zzzzzz zzzz
[Tzz Mzz 16 2006] [15:12:08] *RzzRzzzzz*	zzzzz zzz
[Tzz Mzz 16 2006] [15:12:22] *zzzzz*	zz, zzz zzzz zzzzzzz zzz zzzzz zzzz zzz zzzzzzzz zzz, zz zzzzz zzzz zzzz zzz "zzzzzzz zzzzzz", zzzzz zzzzz zzzzzzz zzz zzzzzzz zzzz zzz zzz zzz zzzz zzz zzzzzzz86 zzz zz zzzz zz zzzz zzzzzz zz "zzzz zz" zzz zzzzzzz
[Tzz Mzz 16 2006] [15:12:38] *zzzzz*	zz zzz zzzzzz zzzzz, zz z zz zzz zz zzzzzz ;-)
[Tzz Mzz 16 2006] [15:12:48] *RzzRzzzzz*	zzzzzz zzzzzz zzzz
[Tzz Mzz 16 2006] [15:13:20] *zzzzz*	zzzz, z'z z zzzz, z zzzzzzzz zzzzzz zzzz zzzz zzz :)
[Tzz Mzz 16 2006] [15:13:27] *RzzRzzzzz*	zz zzz
[Tzz Mzz 16 2006] [15:13:31] *zzzzz*	:)
[Tzz Mzz 16 2006] [15:13:53] *RzzRzzzzz*	zz zzz zzzz zzzz zzzzzzzz zz zzzzz zzzz zzz'zz zzzz?
[Tzz Mzz 16 2006] [15:14:25] *zzzzz*	zzz zzzzzzzzzz zzzzz z zzzzzzzzzz zzzz zz zzzzz (zz z zz, zzzzzzzzz zzzzzzz) zz zzz (zz) zzzzzzz zzzzzzzzzzz
[Tzz Mzz 16 2006] [15:14:34] *zzzzz*	zzz zzz ;-) ?
[Tzz Mzz 16 2006] [15:14:37] *zzzzz*	zzz zzzzzzzzz,
[Tzz Mzz 16 2006] [15:14:59] *zzzzz*	z'zz zzzzzz zzzz zzzz zzzzzzz zzzz zz zzzzz
[Tzz Mzz 16 2006] [15:15:03] *zzzzz*	(zzzzzzz zz zzz zzzz zzzz zz zz)
[Tzz Mzz 16 2006] [15:15:05] *zzzzz*	zzz
[Tzz Mzz 16 2006] [15:15:40] *zzzzz*	z'z zzz zzzzzzzzzz zzz TWzzzIzzzzzzzzCzzzzzz zzz TWzzzPzzzzzIzzzzzzzzCzzzzzz
[Tzz Mzz 16 2006] [15:15:56] *zzzzz*	z'zz zzz zzzz zzzzzz "zzzzzzzz" zzzzz zzzz, zzzzzz zzzzzzz zzz zzz zzzzzzz
[Tzz Mzz 16 2006] [15:15:58] *RzzRzzzzz*	z, zzzzz zzzz zz 2 zzzz zzzzzzzzz zzzzzzzz zz zzzz zzzzzzz
[Tzz Mzz 16 2006] [15:16:13] *RzzRzzzzz*	zzzzzzz zzz zzzzzzzzz zzzz zzzz z zzzz zzzzzz zzzzzzzzz zz zzzzzzz zzzzzzz
[Tzz Mzz 16 2006] [15:16:16] *zzzzz*	z zzz zzz zzzzzzzz z zzzz zzzzzzzz zzzz zzz zzz zzzz zzzzzzz, zzz
[Tzz Mzz 16 2006] [15:16:20] *RzzRzzzzz*	zzz zzzzzz zzzzzzz zzz zzz zzz
[Tzz Mzz 16 2006] [15:16:21] *zzzzz*	(zzz zzzzz, zzz)
[Tzz Mzz 16 2006] [15:16:44] *zzzzz*	zzz, z'zz zzzz (zzzzzzzz zzzzzzzz) zzzzzzzz zzz zzzzz zzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [15:17:00] *RzzRzzzzz*	zz zzzzz.. zzzzzzzzz, zz zzz zzzz zzzzzzzzz zzz zzz zzz zzzzzz zzzz zzz zzzzzzz zzzz zzzzzzz zzz zzzzzzzzzz zzz zzzzz zzzz?
[Tzz Mzz 16 2006] [15:17:25] *zzzzz*	zz
[Tzz Mzz 16 2006] [15:17:27] *zzzzz*	zzz zzz
[Tzz Mzz 16 2006] [15:17:35] *zzzzz*	zz, z zzz'z zzzzzzzzzz zzz zz zzz zzzz
[Tzz Mzz 16 2006] [15:17:41] *zzzzz*	zzzz, z zzzzz'z zzzzzz zz zzz zz zz
[Tzz Mzz 16 2006] [15:17:57] *zzzzz*	zzz z zzzz zzz zzzzzzzzzz zzzz zzzzzzz
[Tzz Mzz 16 2006] [15:17:58] *zzzzz*	zzz
[Tzz Mzz 16 2006] [15:18:14] *zzzzz*	zz'z zzz zzzz zz zzz'z zz zzzzzzzzzzz
[Tzz Mzz 16 2006] [15:18:22] *zzzzz*	z'z zzzzzzz zzzz zzzzz zzzzz zzzz zzzz zzzzzzzz
[Tzz Mzz 16 2006] [15:18:30] *zzzzz*	zzz zz zzzz *zzzzzzzzzz* zzzzz zzz zzzzz zzzz zz zzzz zzzzz
[Tzz Mzz 16 2006] [15:18:34] *RzzRzzzzz*	zzzz
[Tzz Mzz 16 2006] [15:18:37] *zzzzz*	(zzzzzz zzzzzzzzzzzz zzzz zz zz zzz zzzzz)
[Tzz Mzz 16 2006] [15:19:10] *zzzzz*	zzz, z zzzz zzzz zz zzzzzzzz zz "zzzzzzzzz"
[Tzz Mzz 16 2006] [15:19:10] *RzzRzzzzz*	z zzz zzzzzzzzzz zzzzzzzzzzz zzzz zzzzzzzz zzz z zzzzzz zzzzzz zzzz zzzzz zzzz zzzzzz2+
[Tzz Mzz 16 2006] [15:19:33] *zzzzz*	zz z zzzz zz zzzzz zzzz z zzzzzz zzzz z zzz zzzz zzzz z zz, zzz zzzzz zzzz zzzz zzzzz zz zzzz zzzz zzzzz zzzzzzzz zzzz
[Tzz Mzz 16 2006] [15:19:39] *RzzRzzzzz*	z zzzz z zzzzzzz zzz zzz z zzzzzzz zzz
[Tzz Mzz 16 2006] [15:19:39] *zzzzz*	(zzzz zz zzzzz, zz zzzz zzzzz zzz zzzzz)
[Tzz Mzz 16 2006] [15:19:53] *RzzRzzzzz*	z zzzz zzzz zzz zzzz.. z zzzz zzz zzzz zzz
[Tzz Mzz 16 2006] [15:19:59] *zzzzz*	zzzz
[Tzz Mzz 16 2006] [15:20:17] *zzzzz*	zzzzz zz, zzzz zzz'zz zzzzzzzz zz zzz zz zzzzzzz zzz zzzzz z'zz zzzz zzzzzzz zz
[Tzz Mzz 16 2006] [15:20:32] *zzzzz*	zz zzzz zzzzzzz zz zzz zzzzzzzzz zzzzzzz zzzzzzz zzzz zzz zzzz zz zz zzz zzzz z zzzz zz zz
[Tzz Mzz 16 2006] [15:20:33] *zzzzz*	zzz
[Tzz Mzz 16 2006] [15:20:41] *zzzzz*	zzzzzzzzz zzzz zzzzzzz zzz zz z zzzz zzzzz
[Tzz Mzz 16 2006] [15:20:41] *RzzRzzzzz*	zz zzz zzzz zzzz zzzzz zzz zzzzzzzzz zzzzzzzzz zzzzzzz zzz zzzzz?
[Tzz Mzz 16 2006] [15:20:48] *zzzzz*	zzz zzzz zz zzzz zz zzz zzzzzzzz
[Tzz Mzz 16 2006] [15:21:18] *zzzzz*	z zzz, zz.  zzz z'zz zzzzzz zz z zzz zzzzz zzzzz zzzzz zz zzz zzzz zzzzzz zz zzzzz
[Tzz Mzz 16 2006] [15:21:24] *zzzzz*	z zzzzz zzz
[Tzz Mzz 16 2006] [15:21:29] *RzzRzzzzz*	z'z zzz zzz zzzzzzzzz zzzzz zzz zzzzzzz
[Tzz Mzz 16 2006] [15:21:29] *zzzzz*	zzz zzzzzzz, z'z zzzzzz zz zzzzzzzz zzz zzzz
[Tzz Mzz 16 2006] [15:21:45] *RzzRzzzzz*	zz zzzzz zz zzzz zzzz zzz zzz zzzzzzzzzz zz zzzzz zzzzzzz zzzzzz zzzzzz
[Tzz Mzz 16 2006] [15:21:52] *zzzzz*	zz zzz z 486-zzzz zzzzzz zzzzz zzzzzz zzzz CF
[Tzz Mzz 16 2006] [15:21:58] *RzzRzzzzz*	zzz z zzz zzzz zz zzzz zzzz zzzzzzzz :)
[Tzz Mzz 16 2006] [15:22:29] *RzzRzzzzz*	z'z zzzzzzz zzz z zzzzzz zzzzzz zzzz zz zzzzzzzz zzzzzz zz zzzz zzzzzz zzzz zz zzzzzz zz zzzz zz zzzz zz zz zzz zzzzz zz z zzzzz
[Tzz Mzz 16 2006] [15:22:53] *zzzzz*	X zz zz?
[Tzz Mzz 16 2006] [15:22:56] *RzzRzzzzz*	zzzz zzzz zzzz zz zz, zzz zzzzzzzzz zzzz zzzzzzz zzzzzzzz zzzzz z zzzzzz zzzzz zz zzz zzzzz zzzzz zzz z LED
[Tzz Mzz 16 2006] [15:23:10] *zzzzz*	zz, zzzzz zzz :)
[Tzz Mzz 16 2006] [15:23:18] *RzzRzzzzz*	zzz zzzz zzzzz zzz zzzzzz zzzzzz, zzzz zzzzz zzzzz zzz zzzzzzz zz zzz zz zzz zzzz zzzz zzzzz
[Tzz Mzz 16 2006] [15:23:40] *RzzRzzzzz*	z zzz zz zzzz z zzzz zz zz zz zzz zzzzzzzzz zzzzzz zzz zzzz
[Tzz Mzz 16 2006] [15:23:47] *zzzzz*	zzz, zzzzzz zzzz z zzzz zzzzzzzz zzzzz
[Tzz Mzz 16 2006] [15:23:59] *zzzzz*	zzzzzz zzzzzzz zz zzzz zzz zzzz zz zzzzz zzzzzzzzz zzzzzz
[Tzz Mzz 16 2006] [15:24:08] *RzzRzzzzz*	zzz zzz zzzz zzzzzzzz zzzzz zz zzz zzzzz
[Tzz Mzz 16 2006] [15:24:11] *zzzzz*	"zzz zzzzzzzzz zzzzzz zzz zzzz" ?
[Tzz Mzz 16 2006] [15:24:22] *zzzzz*	zzzzzzzz, zz... zzzzzzzzzzz
[Tzz Mzz 16 2006] [15:24:24] *zzzzz*	z'z zzzzzzzz
[Tzz Mzz 16 2006] [15:24:31] *zzzzz*	z'z zzzzzzzzzzz
[Tzz Mzz 16 2006] [15:24:40] *RzzRzzzzz*	zzz zzzz zz zzzzz.. zz'z zzzz zz zzzz zzzzzz zz zzzz zz
[Tzz Mzz 16 2006] [15:24:54] *zzzzz*	zzz zzzzzzzzzzz zz zzzzzzz zzz zzz zzzz zz zzzzz zzz zzzzzzzzzzzzz zz zz zzz XML::Wzzzzzzz
[Tzz Mzz 16 2006] [15:24:55] *RzzRzzzzz*	zzz zzzzzzz zzzzz zzz zzzzzzzzzzz z zzzzz zz zz zzzzzzz zz'z zzzz zz zzzz
[Tzz Mzz 16 2006] [15:25:03] *zzzzz*	(zz zzzzzzzz zzzzzzzz zzzzzzzz zz zzzzzzz zzzz)
[Tzz Mzz 16 2006] [15:25:18] *zzzzz*	zz'z zzzz zz zzzzz zzzz z zzzzz zzzz
[Tzz Mzz 16 2006] [15:25:25] *zzzzz*	zzzz, zzz zzzz zzz'z z zzzz zzzzzz
[Tzz Mzz 16 2006] [15:26:11] *RzzRzzzzz*	zzzz.. zzz zzzzzzzzzzz zz zzzzzzzzz zzzzzzzzzz zzzzzzzzz zzzz zzzz zzzzzzz zzzzz zz zzzzzzzzzzzz
[Tzz Mzz 16 2006] [15:26:26] 	 * zzzzz zzzz
[Tzz Mzz 16 2006] [15:26:30] *RzzRzzzzz*	zz zzzzzzzzz zzzz zzzzzzzzz zzzzzz zzzzz zz zzz zzz zzzzzzz zzz.. zzzz zzzz zzz zzzzzzzzzzz, zzzz zzzz zzzzz zz zzzzzzz zzzz
[Tzz Mzz 16 2006] [15:27:15] *RzzRzzzzz*	zzzz zzzzzz zzzzz
[Tzz Mzz 16 2006] [15:27:24] *zzzzz*	zzzzz, zzzzzz zzzz zz z zzzz zz "zzzzz" zzzz
[Tzz Mzz 16 2006] [15:27:31] *zzzzz*	zzz zzz zzzz zzzzz/zzzzzzz zzzz zz zzzzz zzz zzzz
[Tzz Mzz 16 2006] [15:27:38] *zzzzz*	zzzz, zzzz zzzz zzzzz zzzzz
[Tzz Mzz 16 2006] [15:27:46] *zzzzz*	z zzzz zzzzzzz zz zzzzzz zzzz zz zz, zzz
[Tzz Mzz 16 2006] [15:27:50] *RzzRzzzzz*	zzzzzzz
[Tzz Mzz 16 2006] [15:28:19] *RzzRzzzzz*	zzz, zz zzz zzzz zzzz zzzzz zzzzzz?
[Tzz Mzz 16 2006] [15:28:40] *zzzzz*	zzzz zzzzzz, z'z zzzzzzzzz zzzzzzzz zz zzzz
[Tzz Mzz 16 2006] [15:28:44] *zzzzz*	(zzz zzzz z zzz'z zzzz zz zzzz zzzz,
[Tzz Mzz 16 2006] [15:28:44] *RzzRzzzzz*	z..
[Tzz Mzz 16 2006] [15:28:50] *zzzzz*	zzzzzzz z zzzzz zz'z zzzz zz zzz zzzzzzzz zzzzzzzz
[Tzz Mzz 16 2006] [15:28:57] *RzzRzzzzz*	zz zzz
[Tzz Mzz 16 2006] [15:29:10] *zzzzz*	zzz zzzz zzzzzzz zzzzz z zzzzz'z zzz zzzz zz zzz zzzzzz zz 
[Tzz Mzz 16 2006] [15:29:40] *RzzRzzzzz*	z.. z zzz zzzzzzzz zz zzzzzzz zzzz zzzz zzzzz zzzz zz zzz zzzzzz zzzz zz zzzz
[Tzz Mzz 16 2006] [15:29:49] *zzzzz*	zzzzz zzzzz
[Tzz Mzz 16 2006] [15:30:07] *zzzzz*	(zzz zzzzz zzzzzzz zzzz zzzz zzzz zzzzzzzzz zz zzzz, zzzzzz (zzzzzzzzz...))
[Tzz Mzz 16 2006] [15:30:22] *RzzRzzzzz*	zzz, zz zzzzzz zzzz zzz zzzzzzzzz, zzzzz zzz zz zzzzzzzzzz zz zzzzzzz zzz z zzzzz zzzzzz zzz, zzz zz zzzzzzzzz zzzzz zz zzzz zzzzzzz z'z zzzzzzz?
[Tzz Mzz 16 2006] [15:30:44] *RzzRzzzzz*	zzzz zzzzzzz zzzzzz
[Tzz Mzz 16 2006] [15:30:52] *RzzRzzzzz*	zz zzzz zz'z zzzz zzzzzzzzzzzz
[Tzz Mzz 16 2006] [15:31:20] *RzzRzzzzz*	z zzzzz zzzzz zz z zzz zz zzzzzzzzzzz zzzz
[Tzz Mzz 16 2006] [15:31:26] *zzzzz*	z'z zzzzzzzzz zzzz zz zzzz.  z zz zzzz z zzz zz zzzzzzzzzzz zz zz zzzzz zzzzzzz, zz z zzzzzzzzz zzzzzzz, zzz z zzzz zzzz 25 zzzzz/MONTH, zzzzz zz zzzzzz zzzz z zzzz zz zzzzzzz zzzzzz
[Tzz Mzz 16 2006] [15:31:56] *RzzRzzzzz*	zzzz zz zzzz
[Tzz Mzz 16 2006] [15:32:06] *RzzRzzzzz*	z'zz zzz zzzz zz zzz zzzzzzz!
[Tzz Mzz 16 2006] [15:32:12] *zzzzz*	zz, z8z
[Tzz Mzz 16 2006] [15:32:15] *zzzzz*	zzzz zzzzzzz zz zzz :)
[Tzz Mzz 16 2006] [15:32:20] *RzzRzzzzz*	zzzzz zzz.  zzzz zzzzzzz zz zzz
</verbatim>



%ACTION{ due="16-Mum-2006" uid="000010" creator="Main.BammQuarry" state="open" created="16-Mum-2006" who="Main.BammQuarry" }% 

%ACTION{ due="16-Mum-2006" uid="000011" creator="Main.BammQuarry" state="open" created="16-Mum-2006" who="Main.BammQuarry" }% 

%ACTION{ due="16-Mum-2006" uid="000012" creator="Main.BammQuarry" state="open" created="16-Mum-2006" who="Main.BammQuarry" }% 

%ACTION{ due="16-Mum-2006" uid="000013" creator="Main.BammQuarry" state="open" created="16-Mum-2006" who="Main.BammQuarry" }% 


-- Main.BammQuarry - 17 Mum 2006


EOS

    my $t = $this->segfaulting_urlDecode($s);
}

sub segfaulting_urlDecode {
    my ( $this, $text ) = @_;

    $text =~ s/%([\da-f]{2})/chr(hex($1))/gei;
    $text =~ s/%u([\da-f]{4})/chr(hex($1))/gei;

    my $t = $this->{session}->UTF82SiteCharSet($text);

    $text = $t if ($t);

    return $text;
}

1;
