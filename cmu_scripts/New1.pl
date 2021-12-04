#!/usr/bin/perl
use strict;
use conf;
use Net::hostent;
use Socket;
use Getopt::Std;
require "./inc.pl";

###########################

our $USER = "ashu";
our $PROG = "mono ./OctoSim/OctoSim.exe";
# our $common_args = "-w Hetero.wl -t 10000 -maxu 5 -sbw 6000 -fsize 819200 -b 2048 -jr 100 -j 10";
our $common_args = "-w Homog.wl -t 10000 -rnd r -maxu 5 -fec 1 -fsize 819200 -jr 100 -j 10 -d 40";

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

sub RunSeedsBw
{
    my ($cmd, $outdir, @seedbws) = @_;
    $outdir = "data/$outdir";
    
    chdir($TOPDIR);
    foreach my $sbw (@seedbws) {
	foreach my $nseeds (1, 3, 5, 10) {
	    my $fodir = "$outdir/numSeedsBw-$nseeds-$sbw";
	    my $fcmd = "$cmd -sbw $sbw -seeds $nseeds -o $fodir/default.out";
	    
	    psystem("mkdir -p $fodir");
	    psystem("$fcmd");
	    psystem("gzip --force $fodir/default.out.*");
	}
    }
}

## Run the LR, Random, Permute expts
{
    my %hash = (
	    'iris-d-02', [ '750:200:1.0', 200, 400 ],
	    'iris-d-03', [ '750:200:1.0', 800, 1500 ], 
	    'iris-d-04', [ '2250:600:1.0', 200, 400 ],
	    'iris-d-05', [ '2250:600:1.0', 800, 1500 ]
	    );

    foreach my $d (keys %hash) {
	my $aref = $hash{$d};
	my $bw  = shift @$aref;
	my @sbws = @$aref;
	
	$OUTPUT_REDIR = "/home/mercury/msr/data/$d.progress";
	rsystem_opts(0, 1, $USER, $d, \&RunSeedsBw, "$PROG $common_args -bw $bw", "nseedbw/$bw", @sbws);
    }
}

