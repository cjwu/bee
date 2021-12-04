#!/usr/bin/perl

use strict;
use conf;
use Net::hostent;
use Socket;
use Getopt::Std;
require "./inc.pl";

our $USER = "ashu";
our $PROG = "mono ./OctoSim/OctoSim.exe";

sub RunSeedsBw
{
	my ($cmd, $outdir, @seedbws) = @_;
	$outdir = "data/$outdir";

	chdir($TOPDIR);
	foreach my $sbw (@seedbws) {
		my $fodir = "$outdir/sbw-$sbw";
		my $fcmd = "$cmd -sbw $sbw -o $fodir/default.out";

		psystem("mkdir -p $fodir");
		psystem("$fcmd");
		psystem("gzip --force $fodir/default.out.*");
		psystem("perl /home/mercury/msr/data/DoallAll.pl \$PWD $fodir");
		psystem("perl /home/mercury/msr/data/RunSomeScript.pl caputil2 \$PWD $fodir");
		psystem("rsync -az $TOPDIR/data/ /home/mercury/msr/data/");
	}
}

sub RunTFT
{
	my ($cmd, $outdir, @fths) = @_;
	$outdir = "data/$outdir";

	chdir($TOPDIR);

# running out of time; only use 3000, 1500, 800
	foreach my $sbw (3000, 1500, 800, 6000)
	{
		foreach my $th (@fths) {
			my $fodir = "$outdir/sbw-$sbw/fth-$th";
			my $fcmd = "$cmd -sbw $sbw -fth $th -o $fodir/default.out";

			psystem("mkdir -p $fodir");
			psystem("$fcmd");
			psystem("gzip --force $fodir/default.out.*");
			psystem("perl /home/mercury/msr/data/DoallAll.pl \$PWD $fodir");
			psystem("perl /home/mercury/msr/data/RunSomeScript.pl caputil2 \$PWD $fodir");
			psystem("rsync -az $TOPDIR/data/ /home/mercury/msr/data/");
		}
	}
}

our $common_args = "-t 10000 -maxu 5 -fsize 819200 -b 2048 -rnd r -jr 100 -j 10 -d 40";
our $hetero_args = "-w Hetero.wl $common_args";
our $homog_args  = "-w Homog.wl $common_args -bw '1500:400:1.0'";

## # run basic BT -- with different seed bandwidths;
## {
##     my $mach = "iris-d-02";
##     my $args = "$hetero_args -bw '6000:3000:0.33 1500:400:0.33 784:128:0.34' -smartseed -nsu ";
##     $OUTPUT_REDIR = "/home/mercury/msr/data/$mach.progress";
##     rsystem_opts(0, 1, $USER, $mach, \&RunSeedsBw, "$PROG $args ", "2510-morning/dumbtracker/bt-heterog",
## 	    6000); 
## # , /* 3000, 1500, 800 );
## }
## # run basic BT -- with IBW -- with different seed bandwidths;
## {
##     my $mach = "iris-d-03";
##     my $args = "$hetero_args -bw '6000:3000:0.33 1500:400:0.33 784:128:0.34' -smartseed -nsu -ibw ";
##     $OUTPUT_REDIR = "/home/mercury/msr/data/$mach.progress";
##     rsystem_opts(0, 1, $USER, $mach, \&RunSeedsBw, "$PROG $args ", "2510-morning/dumbtracker/bt-ibw",
## 	    6000); 
## #3000, 1500, 800);
## }

# run pairTFT -- for various seed-bws (4) x thresholds (3);
{    
my $mach = "iris-d-05";
my $args = "$hetero_args -bw '6000:3000:0.33 1500:400:0.33 784:128:0.34' -smartseed -nsu -pairtft ";
$OUTPUT_REDIR = "/home/mercury/msr/data/$mach.progress";
rsystem_opts(0, 1, $USER, $mach, \&RunTFT, "$PROG $args ", "2510-morning/dumbtracker/pairtft",
2);
}

# run pairTFT -- for various seed-bws (4) x thresholds (3)
{    
my $mach = "iris-d-06";
my $args = "$hetero_args -bw '6000:3000:0.33 1500:400:0.33 784:128:0.34' -smartseed -nsu -pairtft ";
$OUTPUT_REDIR = "/home/mercury/msr/data/$mach.progress";
rsystem_opts(0, 1, $USER, $mach, \&RunTFT, "$PROG $args ", "2510-morning/dumbtracker/pairtft",
1);
}

