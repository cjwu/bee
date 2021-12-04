#!/usr/bin/perl
use strict;

my $file = shift;
defined $file or die "no file given to process!";

my $cmd;
my $cmd2;
$cmd = "cat $file.nds | grep 'r p' | perl -ne '/n 1\r/ and print;' ";
$cmd2 = 'awk \'{ print $1, " ", $5 }\' | sort -n +1 --stable | uniq -f 1  | sort -n --stable | awk \'{ print NR, $0 }\'';

system ("$cmd | $cmd2 > $file.sdc");
