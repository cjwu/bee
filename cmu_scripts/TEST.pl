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
our $common_args = "-w Hetero.wl -t 10000 -rnd r -smartseed -nsu -maxu 5 -fsize 819200 -b 2048 -d 10 ";
$common_args .= " -bw '6000:3000:0.33 1500:400:0.33 784:128:0.34' ";

# our $common_args = "-w Homog.wl -t 10000 -rnd r -smartseed -nsu -maxu 5 -fec 1 -fsize 819200 -b 2048 -d 40 ";

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
    my ($cmd, $outdir) = @_;
    $outdir = "data/$outdir";
    
    chdir($TOPDIR);
    my $fodir = "$outdir";
    my $fcmd = "$cmd -o $fodir/default.out";

	doit($fodir, $fcmd);
}

{
    my %hash = (
	    'iris-d-02', [ '1500:400:1.0', 800 ],
	    );

	foreach my $d (keys %hash) {
		$OUTPUT_REDIR = "/home/mercury/msr/data/$d.progress";
		rsystem_opts(0, 0, $USER, $d, \&RunSeedsBw, 
				"$PROG $common_args -d 5 -t 10000 -jr 100 -j 2 -maxnodes 1200 -originload 1.02 -smartseed -nsu -sbw 800 -slp 0.0 -sfb 2 ", "test/test", );
	}
}
