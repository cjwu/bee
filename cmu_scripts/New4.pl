#!/usr/bin/perl
use strict;
use conf;
use Net::hostent;
use Socket;
use Getopt::Std;
require "./inc.pl";

#############################
# vary sbw along with degree -- higher degrees are useless.

our $USER = "ashu";
our $PROG = "mono ./OctoSim/OctoSim.exe";
our $common_args = "-w Homog.wl -t 10000 -maxu 5 -fsize 819200 -jr 100 -j 10 -bw '1500:400:1.0'";

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

sub Rund
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

## Run changing 'd' expts
{
    my %expts = (
	    'iris-d-02', [ 2, 400 ],
	    'iris-d-03', [ 2, 800, 1500, 3000 ],
	    'iris-d-04', [ 3, 400, 800, 1500, 3000 ],
	    'iris-d-05', [ 5, 400, 800, 1500, 3000 ]
	    );

    foreach my $mach (keys %expts) {
	my $aref = $expts{$mach};
	my $d = shift @$aref;
	my @sbws = @$aref;
	
	$OUTPUT_REDIR = "/home/mercury/msr/data/$mach.progress";
	rsystem_opts(0, 1, $USER, $mach, \&Rund, "$PROG $common_args -d $d", "varyd/d-$d", @sbws);
    }
}

