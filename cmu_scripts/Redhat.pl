#!/usr/bin/perl

use strict;
use conf;
use Net::hostent;
use Socket;
use Getopt::Std;
require "./inc.pl";

our $USER = "ashu";
our $PROG = "mono --profile ./OctoSim/OctoSim.exe";

sub RunCommand
{
    my ($cmd, $outdir) = @_;
    $outdir = "data/$outdir";
    
    chdir($TOPDIR);

    my $fodir = "$outdir";
    my $fcmd = "$cmd -o $fodir/default.out";

	doit($fodir, $fcmd);
}

our $bandwidths = "-bw '784:128:0.20 1500:384:0.40 3000:1000:0.25 10000:5000:0.15' -sbw 6000";
our $days = 20;
our $time = 1000; # 86400 * $days;
our $fsize = 17 * 819200;  # this translates to 1.7GB;
our $common_args = "-w Redhat-0.wl -t $time -maxnodes 10000 -maxu 5 -fsize $fsize -b 2048 -rnd r -d 40 $bandwidths";
our $rh_vanilla = "$common_args";
our $rh_cascade   = "$common_args -smartseed -nsu -pairtft -fth 2 ";

{
	my %settings = (
			'iris-d-10', [ 'vanilla', $rh_vanilla ],
			);

	foreach my $mach (keys %settings) {
		$OUTPUT_REDIR = "/home/mercury/msr/data/$mach.progress.redhat";
		my $aref = $settings{$mach};
		my $name = $aref->[0];
		my $args = $aref->[1];

		rsystem_opts(0, 0, $USER, $mach, \&RunCommand, "$PROG $args", 
				"test/$name");
	}
}
