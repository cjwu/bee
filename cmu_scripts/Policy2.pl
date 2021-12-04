#!/usr/bin/perl

use strict;
use conf;
use Net::hostent;
use Socket;
use Getopt::Std;
require "inc.pl";

our $USER = "ashu";
our $PROG = "mono ./OctoSim/OctoSim.exe";

sub RunPolicies 
{
    my ($cmd, $outdir) = @_;
    $outdir = "data/$outdir";
    
    chdir($TOPDIR);
    my %policies = ('lr', '', 
	    'random', '-r 400',
	    'permute', '-permutations');

    $OUTPUT_REDIR = "data/OUTPUT-Policy2.log";
    foreach my $policy (keys %policies) {	 
	psystem("mkdir -p $outdir/policy-$policy");
	psystem("$cmd $policies{$policy} -o $outdir/policy-$policy/default.out");
	psystem("gzip --force $outdir/policy-$policy/default.out.*");
    }
}

## Run the LR, Random, Permute expts with Homogeneous things
{
    our $common_args = "-w Homog.wl -t 10000 -maxu 5 -sbw 6000 -fsize 819200 -b 2048 -jr 100 -j 10";
    my $args_fmt = "-bw '1500:400:1.0' -fec 1 -d %d ";
    my %hash = ('3', 'iris-d-06', 
	        '5', 'iris-d-07', 
		'10', 'iris-d-08');

    foreach my $d (keys %hash) {
	rsystem_opts(0, 1, $USER, $hash{$d}, \&RunPolicies, "$PROG $common_args " . sprintf($args_fmt, $d), "homog-sbw-6000/d-$d");
    }
}

# wait for these set of people to finish!
while (wait() >= 0) {
    # reaping...
}

print STDERR "ARGH!!!! Finally moving on to the next set\n";

## Run the LR, Random, Permute expts with Homogeneous things
{
    our $common_args = "-w Homog.wl -t 10000 -maxu 5 -sbw 400 -fsize 819200 -b 2048 -jr 100 -j 10";
    my $args_fmt = "-bw '1500:400:1.0' -fec 1 -d %d ";
    my %hash = ('3', 'iris-d-06', 
	        '5', 'iris-d-07', 
		'10', 'iris-d-08');

    foreach my $d (keys %hash) {
	rsystem_opts(0, 1, $USER, $hash{$d}, \&RunPolicies, "$PROG $common_args " . sprintf($args_fmt, $d), "homog-sbw-400/d-$d");
    }
}

