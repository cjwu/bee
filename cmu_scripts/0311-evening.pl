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

{

    my %settings = (
            'iris-d-02', 400,
            'iris-d-03', 800, 
            'iris-d-04', 6000
            );
    
    foreach my $mach (keys %settings) {
	$OUTPUT_REDIR = "/home/mercury/msr/data/$mach.progress";
	rsystem_opts(0, 1, $USER, $mach, \&RunSeedsBw,  "$PROG $homog_args -sbw $settings{$mach}",
                "2510-morning/nwb/sbw-$settings{$mach}", 75, 85, 95, 99);
    }
}

