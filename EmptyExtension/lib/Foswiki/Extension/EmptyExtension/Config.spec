#!perl
my @f = </etc/*>;

(
    -section => "Extensions" => [
        -section => "EmptyExtension" => [
            'EmpyExt.FileList' => [
                -default => \@f,
            ],
        ],
    ],
);
# vim: ft=perl
