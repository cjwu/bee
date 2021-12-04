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

sub RunPolicies
{
    my ($cmd, $outdir) = @_;
    $outdir = "data/$outdir";
    
    chdir($TOPDIR);
    foreach my $sbw (400, 800, 1500) {
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
	    'iris-d-02', [ 3, 'lr' ],
	    'iris-d-03', [ 3, 'permute' ],
	    'iris-d-04', [ 5, 'lr' ],
	    'iris-d-05', [ 5, 'permute' ],
	    'iris-d-06', [ 10, 'lr' ],
	    'iris-d-10', [ 10, 'permute' ]
	    );

    foreach my $mach (keys %expts) {
	my $aref = $expts{$mach};

	my $args = "$common_args -d " . $aref->[0];
	$args .= " -permutations " if $aref->[1] eq 'permute';
	$OUTPUT_REDIR = "/home/mercury/msr/data/$mach.progress";
		
	rsystem_opts(0, 1, $USER, $mach, \&RunPolicies, "$PROG $args", sprintf("newpolicy/d-%d/policy-%s", $aref->[0], $aref->[1]));
    }
}

