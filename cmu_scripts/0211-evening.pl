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
	psystem("rsync -az $TOPDIR/data/ /home/mercury/msr/data/");
    }
}

our $bandwidths = "-bw '784:128:0.20 1500:384:0.40 3000:1000:0.25 10000:5000:0.15'";
our $common_args = "-t 10000 -smartseed -nsu -maxnodes 3000 -maxu 5 -fsize 1638400 -b 2048 -rnd r -jr 100 -j 10 -d 40";
our $redhat_args  = "-w Hetero.wl $common_args $bandwidths";

{
    my $args = "$homog_args -pfcbatches 1800/100/1801/10/1499:400";
    my %settings = (
            'iris-d-03', [ 'lr', '' ],
            'iris-d-04', [ 'random', '-permutations' ]
	    );

    foreach my $mach (keys %settings) {
	$OUTPUT_REDIR = "/home/mercury/msr/data/$mach.progress";
        my $aref = $settings{$mach};
	my $name = "policy-" . $aref->[0];
        my $fargs = "$args " . $aref->[1];

	rsystem_opts(0, 1, $USER, $mach, \&RunSeedsBw, "$PROG $fargs", 
		"2510-morning/pfc-objectives/$name",  800, 400);
    }
         rsystem_opts(0, 0, $USER, $d, \&RunSeedsBw, 
                 "$PROG $common_args -w Redhat-1.wl -bw $bw -t 10000 -sbw 800 -maxnodes 2000 ", "test/test");
}

