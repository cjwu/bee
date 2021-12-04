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

sub RunNSeeds
{
    my ($cmd, $outdir, @nseeds) = @_;
    $outdir = "data/$outdir";
    
    chdir($TOPDIR);
    foreach my $n (@nseeds) {
	my $fodir = "$outdir/nseeds-$n";
	my $fcmd = "$cmd -seeds $n -o $fodir/default.out";

	psystem("mkdir -p $fodir");
	psystem("$fcmd");
	psystem("gzip --force $fodir/default.out.*");
	psystem("perl /home/mercury/msr/data/DoallAll.pl \$PWD $fodir");
	psystem("rsync -az $TOPDIR/data/ /home/mercury/msr/data/");
    }
}

sub RunPolicies 
{
    my ($cmd, $outdir) = @_;
    $outdir = "data/$outdir";
    
    chdir($TOPDIR);
    my %policies = ('lr', '', 
	    'random', ' -permutations');
    my @dlist = (10, 5, 3);

    foreach my $d (@dlist) {
	foreach my $policy (keys %policies) {	 
	    my $fodir = "$outdir/d-$d/policy-$policy";
	    my $fcmd = "$cmd -d $d $policies{$policy} -o $fodir/default.out";
	
	    psystem("mkdir -p $fodir");
	    psystem("$fcmd");
	    psystem("gzip --force $fodir/default.out.*");
	    psystem("perl /home/mercury/msr/data/DoallAll.pl \$PWD $fodir");
	    psystem("rsync -az $TOPDIR/data/ /home/mercury/msr/data/");
	}
    }
}

our $common_args = "-t 10000 -maxu 5 -fsize 819200 -b 2048 -rnd r -jr 100 -j 10 -d 40";
our $hetero_args = "-w Hetero.wl $common_args";
our $homog_args  = "-w Homog.wl $common_args -bw '1500:400:1.0'";

# first, low-seed bw
{    
    my $args = "$homog_args";
    $OUTPUT_REDIR = "/home/mercury/msr/data/iris-d-02.progress";
    rsystem_opts(0, 1, $USER, 'iris-d-02', \&RunSeedsBw, "$PROG $args ", "2510-morning/seedbw-nosmartseed", 
	    200, 400, 600, 800, 1000);
    
    $args = "$homog_args -smartseed -nsu";
    $OUTPUT_REDIR = "/home/mercury/msr/data/iris-d-03.progress";
    rsystem_opts(0, 1, $USER, 'iris-d-03', \&RunSeedsBw, "$PROG $args ", "2510-morning/seedbw-smartseed", 
	    200, 400, 600, 800, 1000);
}

# run nseeds
{
    my $args = "$homog_args -bw '1500:400:1.0' -sbw 200 -smartseed -nsu ";
    $OUTPUT_REDIR = "/home/mercury/msr/data/iris-d-04.progress";
    rsystem_opts(0, 1, $USER, 'iris-d-04', \&RunNSeeds, "$PROG $args ", "2510-morning/nseeds",
	    2, 3, 4, 5);
}

# run policies
{
    my $args = "$homog_args -bw '1500:400:1.0' -sbw 400 -smartseed -nsu";
    $OUTPUT_REDIR = "/home/mercury/msr/data/iris-d-05.progress";
    rsystem_opts(0, 1, $USER, 'iris-d-05', \&RunPolicies, "$PROG $args ", "2510-morning/policy/sbw-400");
    $args = "$homog_args -bw '1500:400:1.0' -sbw 1000 -smartseed -nsu";
    $OUTPUT_REDIR = "/home/mercury/msr/data/iris-d-06.progress";
    rsystem_opts(0, 1, $USER, 'iris-d-06', \&RunPolicies, "$PROG $args ", "2510-morning/policy/sbw-1000");
}

# run basic BT under heterogeneous circumstances with varying seed bandwidths
{
    my $args = "$hetero_args -bw '6000:3000:0.33 1500:400:0.33 784:128:0.34' -smartseed -nsu ";
    $OUTPUT_REDIR = "/home/mercury/msr/data/iris-d-10.progress";
    rsystem_opts(0, 1, $USER, 'iris-d-10', \&RunSeedsBw, "$PROG $args ", "2510-morning/bt-heterog",
	    800, 1500, 3000, 6000);
}
