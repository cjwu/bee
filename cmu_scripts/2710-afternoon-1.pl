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

sub RunMaxU
{
    my ($cmd, $outdir, @maxus) = @_;
    $outdir = "data/$outdir";

    chdir($TOPDIR);
    foreach my $u (@maxus) {
	my $fodir = "$outdir/u-$u";
	my $fcmd = "$cmd -maxu $u -o $fodir/default.out";

	psystem("mkdir -p $fodir");
	psystem("$fcmd");
	psystem("gzip --force $fodir/default.out.*");
	psystem("perl /home/mercury/msr/data/DoallAll.pl \$PWD $fodir");
	psystem("rsync -az $TOPDIR/data/ /home/mercury/msr/data/");
    }

}

our $common_args = "-t 10000 -maxu 5 -fsize 819200 -b 2048 -rnd r -jr 100 -j 10 -d 40";
our $hetero_args = "-w Hetero.wl $common_args";
our $homog_args  = "-w Homog.wl $common_args -bw '1500:400:1.0'";

# run with different values of $u$ 
{
    my $args = "$homog_args -smartseed -nsu -sbw 400";
    my @maxus = (2, 5, 10, 20);
    
    my $mach = "iris-d-05";
    $OUTPUT_REDIR = "/home/mercury/msr/data/$mach.progress";
    rsystem_opts(0, 1, $USER, $mach, \&RunMaxU, "$PROG $args",
		"2510-morning/maxu/sbw-400/smartseed",  @maxus);
}
# run with different values of $u$ 
{
    my $args = "$homog_args -sbw 400";
    my @maxus = (2, 5, 10, 20);
    
    my $mach = "iris-d-06";
    $OUTPUT_REDIR = "/home/mercury/msr/data/$mach.progress";
    rsystem_opts(0, 1, $USER, $mach, \&RunMaxU, "$PROG $args",
		"2510-morning/maxu/sbw-400/nosmartseed",  @maxus);
}
# run with different values of $u$ 
{
    my $args = "$homog_args -sbw 1500";
    my @maxus = (2, 5, 10, 20);
    
    my $mach = "iris-d-10";
    $OUTPUT_REDIR = "/home/mercury/msr/data/$mach.progress";
    rsystem_opts(0, 1, $USER, $mach, \&RunMaxU, "$PROG $args",
		"2510-morning/maxu/sbw-1500/nosmartseed",  @maxus);
}
