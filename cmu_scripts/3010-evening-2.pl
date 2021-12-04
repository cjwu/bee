#!/usr/bin/perl

use strict;
use conf;
use Net::hostent;
use Socket;
use Getopt::Std;
require "./inc.pl";

our $USER = "ashu";
our $PROG = "mono ./OctoSim/OctoSim.exe";

sub RunFEC
{
    my ($cmd, $outdir, @fec) = @_;
    $outdir = "data/$outdir";
    
    chdir($TOPDIR);
    foreach my $f (@fec) {
	my $fodir = "$outdir/fec-$f";
	my $fcmd = "$cmd -fec $f -o $fodir/default.out";

	psystem("mkdir -p $fodir");
	psystem("$fcmd");
	psystem("gzip --force $fodir/default.out.*");
	psystem("perl /home/mercury/msr/data/DoallAll.pl \$PWD $fodir");
	psystem("rsync -az $TOPDIR/data/ /home/mercury/msr/data/");
    }
}

sub RunNodes
{
	my ($cmd, $outdir, @nodes) = @_;
	$outdir = "data/$outdir";

	chdir($TOPDIR);
	foreach my $n (@nodes) {
		my $fodir = "$outdir/nodes-$n";
		my $jointime = $n / 100;
		my $maxnodes = $n + 200;
		my $fcmd = "$cmd -j $jointime -maxnodes $maxnodes -o $fodir/default.out";

		psystem("mkdir -p $fodir");
		psystem("$fcmd");
		psystem("gzip --force $fodir/default.out.*");
		psystem("perl /home/mercury/msr/data/DoallAll.pl \$PWD $fodir");
		psystem("rsync -az $TOPDIR/data/ /home/mercury/msr/data/");
	}
}

our $common_args = "-t 10000 -maxu 5 -fsize 819200 -b 2048 -rnd r -jr 100 -sbw 6000 ";
our $homog_args  = "-w Homog.wl $common_args -bw '1500:400:1.0'";

# small 'd' -- util is low. run on more machines
{
    my $args = "$homog_args -d 3 -j 10 ";
    my %fec_settings = (
            'iris-d-02', [ 5.0, 6.0, 7.0, 8.0 ]
	    );

    foreach my $mach (keys %fec_settings) {
	$OUTPUT_REDIR = "/home/mercury/msr/data/$mach.progress";
	my $aref = $fec_settings{$mach};

	rsystem_opts(0, 1, $USER, $mach, \&RunFEC, "$PROG $args", 
		"2510-morning/fec-smalld",  @$aref);
    }
}

# d = 5, run for various #nodes
{
    my $args = "$homog_args -d 5";
    my %nodes_settings = (
            'iris-d-03', [ 4000, 5000 ]
            );

    foreach my $mach (keys %nodes_settings) {
        $OUTPUT_REDIR = "/home/mercury/msr/data/$mach.progress";
        my $aref = $nodes_settings{$mach};

        rsystem_opts(0, 1, $USER, $mach, \&RunNodes, "$PROG $args",
                "2510-morning/d3varyn", @$aref);
    }
}

# d = 40, run for various #nodes
{
    my $args = "$homog_args -d 40 ";
    my %nodes_settings = (
            'iris-d-04', [ 2000, 3000, 4000, 5000 ]
            );

    foreach my $mach (keys %nodes_settings) {
        $OUTPUT_REDIR = "/home/mercury/msr/data/$mach.progress";
        my $aref = $nodes_settings{$mach};

        rsystem_opts(0, 1, $USER, $mach, \&RunNodes, "$PROG $args",
                "2510-morning/varyn-extfig1", @$aref);
    }
}

