#!/usr/bin/perl

use strict;
use conf;
use Net::hostent;
use Socket;
use Getopt::Std;
require "./inc.pl";

our $USER = "ashu";
our $PROG = "mono ./OctoSim/OctoSim.exe";

our $common_args = "-t 10000 -maxu 5 -smartseed -nsu -fsize 819200 -b 2048 -rnd r -jr 100 -j 10 -d 40 -originload 1.05";
our $hetero_args = "-w Hetero.wl $common_args -bw '6000:3000:0.33 1500:400:0.33 784:128:0.34'";
our $homog_args  = "-w Homog.wl $common_args -bw '1500:400:1.0'";

sub RunSeveral
{
    my ($outdir, $prog, $hetero_args, $homog_args) = @_;
    my %settings = (
            'hetero-hibw', "$hetero_args -sbw 6000",
            'hetero-lobw', "$hetero_args -sbw 800",
            'homog-hibw', "$homog_args -sbw 6000",
            'homog-lobw', "$homog_args -sbw 400"
            );
            
    $outdir = "data/$outdir";
    
    chdir($TOPDIR);
    foreach my $expt (keys %settings) {
	my $fodir = "$outdir/$expt";
	my $fcmd = "$prog $settings{$expt} -o $fodir/default.out";

	psystem("mkdir -p $fodir");
	psystem("$fcmd");
	psystem("gzip --force $fodir/default.out.*");
	psystem("perl /home/mercury/msr/data/DoallAll.pl \$PWD $fodir");
	psystem("rsync -az $TOPDIR/data/ /home/mercury/msr/data/");
    }
}

{

    my @machines = ('iris-d-02', 'iris-d-03', 'iris-d-04');
    my $run = 1;
    
    foreach my $mach (@machines) {
	$OUTPUT_REDIR = "/home/mercury/msr/data/$mach.progress";

	rsystem_opts(0, 1, $USER, $mach, \&RunSeveral, 	"2510-morning/seed-leaves/run-$run", 
                $PROG, $hetero_args, $homog_args);
        $run++;
    }
}

