#
# Copyright (C) 2004-2012 C-Dot Consultants - All rights reserved
# Copyright (C) 2008-2010 Foswiki Contributors
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

=begin TML

---++++ target_test
Basic CPAN:Test::Unit test target, runs &lt;project>Suite.

=cut

sub target_test {
    my $this = shift;
    $this->build('build');

    # find testrunner
    my $testrunner = $this->findRelative('core/test/bin/TestRunner.pl')
      || $this->findRelative('test/bin/TestRunner.pl');

    my $tests = $this->findRelative(
        'test/unit/' . $this->{project} . '/' . $this->{project} . 'Suite.pm' );
    unless ($tests) {
        $tests = $this->findRelative(
            '/core/test/unit/' . $this->{project} . 'Suite.pm' )
          || $this->findRelative(
            '/test/unit/' . $this->{project} . 'Suite.pm' );
        unless ($tests) {
            warn 'WARNING: COULD NOT FIND ANY UNIT TESTS FOR '
              . $this->{project};
            return;
        }
    }
    unless ($testrunner) {
        warn <<MESSY;
WARNING: CANNOT RUN TESTS; TestRunner.pl not found.
Did you remember to install UnitTestContrib?
MESSY
        return;
    }
    my @inc = map { ( '-I', $_ ) } @INC;
    my $testdir = $tests;
    $testdir =~ s/\/[^\/]*$//;
    print "Running tests in $tests\n";
    $this->pushd($testdir);
    $this->{-v} = 1;    # to get the command printed
    $this->sys_action( 'perl', '-w', @inc, $testrunner, $tests );
    $this->popd();
}

1;
