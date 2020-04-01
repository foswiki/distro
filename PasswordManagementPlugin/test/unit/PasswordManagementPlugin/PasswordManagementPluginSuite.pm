package PasswordManagementPluginSuite;

use Unit::TestSuite;
our @ISA = qw( Unit::TestSuite );

sub name { 'PasswordManagementPluginSuite' }

sub include_tests {
    'PasswordManagementResetTests', 'PasswordManagementChangeTests';
}

1;

