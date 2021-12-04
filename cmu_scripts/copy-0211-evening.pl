#!/usr/bin/perl

use strict;
use conf;
use Net::hostent;
use Socket;
use Getopt::Std;
require "./inc.pl";

our $USER = "ashu";
our $PROG = "mono ./OctoSim/OctoSim.exe";

sub RunCommand
{
    my ($cmd, $outdir) = @_;
    $outdir = "data/$outdir";
    
    chdir($TOPDIR);

    my $fodir = "$outdir";
    my $fcmd = "$cmd -o $fodir/default.out";

    psystem("mkdir -p $fodir");
    psystem("$fcmd");
    psystem("gzip --force $fodir/default.out.*");
    psystem("perl /home/mercury/msr/data/DoallAll.pl \$PWD $fodir");
    psystem("rsync -az $TOPDIR/data/ /home/mercury/msr/data/");
}

our $bandwidths = "-bw '784:128:0.20 1500:384:0.40 3000:1000:0.25 10000:5000:0.15' -sbw 6000";
our $days = 20;
our $time = 86400 * $days;
our $common_args = "-w Redhat-1.wl -t $time -maxnodes 3000 -maxu 5 -fsize 4915200 -b 2048 -rnd r -d 40 $bandwidths";
our $rh_vanilla = "$common_args";
our $rh_cascade   = "$common_args -smartseed -nsu -pairtft -fth 2 ";

{
    my %settings = (
            'iris-d-02', [ 'vanilla', $rh_vanilla ],
            'iris-d-03', [ 'cascade', $rh_cascade ]
	    );

    foreach my $mach (keys %settings) {
	$OUTPUT_REDIR = "/home/mercury/msr/data/$mach.progress.redhat";
        my $aref = $settings{$mach};
	my $name = $aref->[0];
        my $args = $aref->[1];

	rsystem_opts(0, 1, $USER, $mach, \&RunCommand, "$PROG $args", 
		"2510-morning/redhat-trace/$name");
    }
}
