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
our $common_args = "-w Homog.wl -t 10000 -smartseed -rnd r -maxu 5 -fec 1 -fsize 819200 -jr 100 -j 10 -d 40";

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
	my $fodir = "$outdir/sbw-$sbw";
	my $fcmd = "$cmd -sbw $sbw -o $fodir/default.out";

	psystem("mkdir -p $fodir");
	psystem("$fcmd");
	psystem("gzip --force $fodir/default.out.*");
    }
}

## Run the LR, Random, Permute expts
{
    my %hash = (
	    'iris-d-05', [ '1500:400:1.0', 600 ],
	    'iris-d-06', [ '1500:400:1.0', 700 ],
	    );

    foreach my $d (keys %hash) {
	my $aref = $hash{$d};
	my $bw  = shift @$aref;
	my @sbws = @$aref;
	
	$OUTPUT_REDIR = "/home/mercury/msr/data/$d.progress";
	rsystem_opts(0, 1, $USER, $d, \&RunSeedsBw, "$PROG $common_args -bw $bw", "smartseed", @sbws);
    }
}

