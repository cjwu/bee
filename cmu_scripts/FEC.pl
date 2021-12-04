#!/usr/bin/perl

use strict;
use conf;
use Net::hostent;
use Socket;
use Getopt::Std;
require "inc.pl";

our $USER = "ashu";
our $PROG = "mono ./OctoSim/OctoSim.exe";

sub RunCommand 
{
    my ($cmd, $outdir) = @_;
    $outdir = "data/$outdir";
    
    chdir($TOPDIR);

    $OUTPUT_REDIR = "data/OUTPUT-FEC.log";
    psystem("mkdir -p $outdir");
    psystem("$cmd -o $outdir/default.out");
    psystem("gzip --force $outdir/default.out.*");
}

# 3 situations: seed constrained; nodes constrained; small d
#               vary 3 times. total 9 expts.
our $stupid_seed = ' -sbw 400 '; our $normal_seed = ' -sbw 6000 ';
our $stupid_node = " -bw '400:400:1.0' "; our $normal_node = " -bw '1500:400:1.0' ";
our $stupid_d = " -d 3 ";  our $normal_d = " -d 40 ";

## Run FEC in the situation
{
    my $common_args = "-w Homog.wl -t 10000 -maxu 5 -fsize 819200 -b 2048 -jr 100 -j 10";

    my %hash = (
	    'iris-d-02', [ 'slowseed-fec1.2', $stupid_seed, $normal_node, $normal_d, 1.2 ],
	    'iris-d-03', [ 'slowseed-fec1.5', $stupid_seed, $normal_node, $normal_d, 1.5 ],
	    'iris-d-04', [ 'slowseed-fec2.0', $stupid_seed, $normal_node, $normal_d, 2.0 ],
	    'iris-d-05', [ 'slownode-fec1.2', $normal_seed, $stupid_node, $normal_d, 1.2 ],
	    'iris-d-06', [ 'slownode-fec1.5', $normal_seed, $stupid_node, $normal_d, 1.5 ],
	    'iris-d-07', [ 'slownode-fec2.0', $normal_seed, $stupid_node, $normal_d, 2.0 ]);
	    
    foreach my $mach (keys %hash) {
	my $aref = $hash{$mach};
	my $args = "$common_args $aref->[1] $aref->[2] $aref->[3] -fec $aref->[4] ";

	rsystem_opts(0, 1, $USER, $mach, \&RunCommand, "$PROG $args " , "fec/$aref->[0]");
    }
}

sub RunSpecialFEC {
    my ($cmd, $outdir) = @_;
    $outdir = "data/$outdir";
    
    chdir($TOPDIR);
    
    my @fecs = (1.2, 1.5, 2.0);

    $OUTPUT_REDIR = "data/OUTPUT-FEC.log";
    foreach my $fec (@fecs) {
	psystem("mkdir -p $outdir/smalld-fec$fec");
	psystem("$cmd -fec $fec -o $outdir/smalld-fec$fec/default.out");
	psystem("gzip --force $outdir/smalld-fec$fec/default.out.*");
    }
}

{
    my $common_args = "-w Homog.wl -t 10000 -maxu 5 -fsize 819200 -b 2048 -jr 100 -j 10";
    my $args = "$common_args $normal_seed $normal_node $stupid_d";
    rsystem_opts(0, 1, $USER, 'iris-d-10', \&RunSpecialFEC, "$PROG $args ", "fec");
}
