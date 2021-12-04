#!/usr/bin/perl
use strict;
use conf;
use Net::hostent;
use Socket;
use Getopt::Std;
require "./inc.pl";

#############################

our $USER = "ashu";
our $PROG = "mono ./OctoSim/OctoSim.exe";
# our $common_args = "-w Hetero.wl -t 10000 -maxu 5 -sbw 6000 -fsize 819200 -b 2048 -jr 100 -j 10";
our $common_args = "-w Homog.wl -t 10000 -rnd r -maxu 5 -fec 1 -fsize 819200 -jr 100 -j 10 -d 40 -seeds 1 ";

sub RunCommand 
{
    my ($cmd, $outdir) = @_;

    $outdir = "data/$outdir";
    chdir($TOPDIR);
    psystem("mkdir -p $outdir"); 
    $OUTPUT_REDIR = "$outdir/OUTPUT.log";
    psystem("$cmd -o $outdir/default.out");
    psystem("gzip $outdir/default.out.*");
}

sub RunInBw
{
    my ($cmd, $outdir, @seedbws) = @_;
    $outdir = "data/$outdir";
    
    chdir($TOPDIR);
    foreach my $sbw (@seedbws) {
	foreach my $bw ('1500:400:1.0', '800:400:1.0', '400:400:1.0') {
	    my $fodir = "$outdir/sbw-$sbw/$bw";
	    my $fcmd = "$cmd -sbw $sbw -bw '$bw' -o $fodir/default.out";
	    
	    psystem("mkdir -p $fodir");
	    psystem("$fcmd");
	    psystem("gzip --force $fodir/default.out.*");
	}
    }
}

## Run in-bw expt
{
    my $mach = 'iris-d-06';
    $OUTPUT_REDIR = "/home/mercury/msr/data/$mach.progress";
    rsystem_opts(0, 1, $USER, $mach, \&RunInBw, "$PROG $common_args ", "inbw", 400, 800, 1500);
}

