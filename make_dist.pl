#!/usr/bin/perl

my $dir = "$ENV{HOME}/tmp/bt_simulator";
system ("rm -rf $dir");
system ("rsync -a . $dir");

chdir ($dir);
system ("find . -name CVS -prune -exec rm -rf {} \\;");
chdir ("..");
# system ("tar zcf bt_simulator.tar.gz bt_simulator");
system ("rm -f bt_simulator.zip");
system ("zip -r bt_simulator bt_simulator");
