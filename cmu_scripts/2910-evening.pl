#!/usr/bin/perl

use strict;
use conf;
use Net::hostent;
use Socket;
use Getopt::Std;
require "./inc.pl";

our $USER = "ashu";
our $PROG = "mono ./OctoSim/OctoSim.exe";

sub RunBlocks
{
    my ($cmd, $outdir, @blocks) = @_;
    $outdir = "data/$outdir";
    
    chdir($TOPDIR);
    foreach my $b (@blocks) {
        my $blocksize = 819200 / $b;
        
	my $fodir = "$outdir/blocks-$b";
	my $fcmd = "$cmd -b $blocksize -o $fodir/default.out";

	psystem("mkdir -p $fodir");
	psystem("$fcmd");
	psystem("gzip --force $fodir/default.out.*");
	psystem("perl /home/mercury/msr/data/DoallAll.pl \$PWD $fodir");
	psystem("rsync -az $TOPDIR/data/ /home/mercury/msr/data/");
    }
}

our $common_args = "-t 10000 -maxu 5 -fsize 819200 -rnd r -jr 100 -d 40 -sbw 6000 ";
our $homog_args  = "-w Homog.wl $common_args -bw '1500:400:1.0'";

{
    my $args = "$homog_args";
    my %block_settings = (
            'iris-d-02', [ 1000, 512, 320, 200 ],
            'iris-d-04', [ 200, 512, 400, 320, 200, 100, 50, 20 ]
	    );

    foreach my $mach (keys %block_settings) {
	$OUTPUT_REDIR = "/home/mercury/msr/data/$mach.progress";
	my $aref = $block_settings{$mach};
	my $nodes = shift @$aref;
        my $jointime = $nodes / 100;
        my @blocks = @$aref;

	rsystem_opts(0, 1, $USER, $mach, \&RunBlocks, "$PROG $args -j $jointime", 
		"2510-morning/numblocks/nodes-$nodes",  @blocks);
    }
}

