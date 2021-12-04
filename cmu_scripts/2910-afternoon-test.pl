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

sub RunMaxU
{
    my ($cmd, $outdir, @maxus) = @_;
    $outdir = "data/$outdir";

    chdir($TOPDIR);
    foreach my $u (@maxus) {
	my $fodir = "$outdir/u-$u";
	my $fcmd = "$cmd -maxu $u -o $fodir/default.out";

	psystem("mkdir -p $fodir");
	psystem("$fcmd");
	psystem("gzip --force $fodir/default.out.*");
	psystem("perl /home/mercury/msr/data/DoallAll.pl \$PWD $fodir");
	psystem("rsync -az $TOPDIR/data/ /home/mercury/msr/data/");
    }

}

our $common_args = "-t 10000 -maxu 5 -fsize 819200 -b 2048 -rnd r -jr 100 -j 10 -d 40";
our $hetero_args = "-w Hetero.wl $common_args";
our $homog_args  = "-w Homog.wl $common_args -bw '1500:400:1.0'";

# run with FEC for various FEC values 
{
    my $args = "$homog_args";
    my %fec_settings = (
#'iris-d-02', [ 'withnsu', '-nsu'],
#	    'iris-d-03', [ 'nonsu', '' ]
            'iris-d-03', [ 'onlysmartseed', '-smartseed' ]
	    );

    foreach my $mach (keys %fec_settings) {
	$OUTPUT_REDIR = "/home/mercury/msr/data/$mach.progress";
	my $aref = $fec_settings{$mach};
	my $name = shift @$aref;
	my $add  = shift @$aref;

	rsystem_opts(0, 1, $USER, $mach, \&RunSeedsBw, "$PROG $args $add", 
		"2510-morning/fec-test/$name",  400);
    }
}

