#!/usr/bin/perl

use strict;
use conf;
use Net::hostent;
use Socket;
use Getopt::Std;
require "./inc.pl";

our $USER = "ashu";
our $PROG = "mono ./OctoSim/OctoSim.exe";

our $common_args = "-t 10000 -maxu 5 -smartseed -nsu -fsize 819200 -b 2048 -rnd r -jr 100 -j 10 -d 40 ";
# our $hetero_args = "-w Hetero.wl $common_args -bw '6000:3000:0.33 1500:400:0.33 784:128:0.34'";
our $homog_args  = "-w Homog.wl $common_args -bw '1500:400:1.0'";

sub RunSeedsBw
{
    my ($cmd, $outdir, @blockperc) = @_;
    $outdir = "data/$outdir";
    
    chdir($TOPDIR);
	foreach my $bp (@blockperc) {
		my $fodir = "$outdir/bp-$bp";
		my $fcmd = "$cmd -nwb 200/$bp/1499:400 -o $fodir/default.out";

		psystem("mkdir -p $fodir");
		psystem("$fcmd");
		psystem("gzip --force $fodir/default.out.*");
		psystem("perl /home/mercury/msr/data/DoallAll.pl \$PWD $fodir");
		psystem("rsync -az $TOPDIR/data/ /home/mercury/msr/data/");
	}
}

sub RunD
{
    my ($cmd, $outdir, @ds) = @_;
    $outdir = "data/$outdir";
    
    chdir($TOPDIR);
	foreach my $d (@ds) {
		my $fodir = "$outdir/d-$d";
		my $fcmd = "$cmd -d $d -o $fodir/default.out";

		psystem("mkdir -p $fodir");
		psystem("$fcmd");
		psystem("gzip --force $fodir/default.out.*");
		psystem("perl /home/mercury/msr/data/DoallAll.pl \$PWD $fodir");
		psystem("rsync -az $TOPDIR/data/ /home/mercury/msr/data/");
	}
}

if (1) {	
	my $mach = 'iris-d-02';
    
	$OUTPUT_REDIR = "/home/mercury/msr/data/$mach.progress";
	rsystem_opts(0, 1, $USER, $mach, \&RunSeedsBw,  "$PROG $homog_args -sbw 6000 ",
                "1701-testing/nwb/sbw-6000", 5);
}

if (1) {
	my %settings = ('iris-d-03', [ 75, 99 ], 'iris-d-04', [ 85, 95 ]);
	foreach my $mach (keys %settings) {
		my $aref = $settings{$mach};
		$OUTPUT_REDIR = "/home/mercury/msr/data/$mach.progress";
		rsystem_opts(0, 1, $USER, $mach, \&RunSeedsBw,  "$PROG $homog_args -sbw 6000 -fec 2",
				"1701-testing/nwb-fec/sbw-6000", @$aref);
	}
}

if (1) {
	my %settings = ('iris-d-05', [ 5, 10 ], 'iris-d-06', [ 20, 40 ]);
	foreach my $mach (keys %settings) {
		my $aref = $settings{$mach};
		$OUTPUT_REDIR = "/home/mercury/msr/data/$mach.progress";
		rsystem_opts(0, 1, $USER, $mach, \&RunD,  "$PROG $homog_args -sbw 6000 -nwb 200/99.75/1499:400 ",
				"1701-testing/nwb-d/sbw-6000", @$aref);
	}

}
