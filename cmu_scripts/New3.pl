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
our $common_args = "-w Hetero.wl -t 10000 -bw '6000:3000:0.33 1500:400:0.33 784:128:0.34' -maxu 5 -fsize 819200 -jr 100 -j 10";

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

sub RunHetero
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
    }
}

## Run heterogeneity expt.
{
    my $mach = 'iris-d-10';
    $OUTPUT_REDIR = "/home/mercury/msr/data/$mach.progress";
    rsystem_opts(0, 1, $USER, $mach, \&RunHetero, "$PROG $common_args ", "heterog", 400, 800, 1500, 3000);
}

