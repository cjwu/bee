#!/usr/bin/perl
use strict;
use Getopt::Std;
use vars qw($opt_z);

getopts("z");
our $GZIPPED_INPUT = defined $opt_z ? 1 : 0;

my $file = shift;
defined $file or die "no file given to process!";

my $nodes_ref = read_bwdata("$file.nds");
open G, ">$file.abw" or die "could not open $file.cap for writing...";
dump_aggbw("$file.bw", $nodes_ref);
close G;

sub OpenFile {
	my $path = shift;
	local  *FH;  # not my!;
	if ($GZIPPED_INPUT) {
		open(FH, "zcat $path | ")  or  return undef;
	}
	else {
		open (FH, $path) or return undef;
	}
	return *FH;
}


sub read_bwdata {
	my $f = shift;
	my @nodes = ();

	my $fh = OpenFile($f) or die " could not open file $f for reading ";
	while (defined ($_ = <$fh>)) 
	{
		chomp;

		if (/^(\d+) (\d+) join (\w+) B d (\d+) u (\d+)/) {
			my $id = $2;

			$nodes[$id]->{jointime} = $1;
			$nodes[$id]->{id}       = $id;
			$nodes[$id]->{up}       = $5;
			$nodes[$id]->{down}     = $4;
			$nodes[$id]->{seed}     = ($3 eq "seed") ? 1 : 0;
		}
		elsif (/^(\d+) (\d+) leave/) { 
			$nodes[$2]->{leavetime} = $1;
		}
		elsif (/^(\d+) (\d+) finished/) {
			$nodes[$2]->{finishtime} = $1;
		}
		elsif (/^(\d+) (\d+) seedified/) {
			$nodes[$2]->{seed} = 1;
		}
	}		
	close $fh;
	return \@nodes;
}

sub dump_aggbw {
	my $f = shift;
	my $nref= shift;

	my $fh = OpenFile($f) or die " could not open file $f for reading ";

	my $time = -1;
	my $i = 0;
	my (%hash, $tot_up);

	$tot_up = 0;

	while (defined ($_ = <$fh>))
	{
		chomp;
		next if (/^#/);

		if (/time (\d+)/) {
			$i++;
			if ($i % 500== 0) { print STDERR "$i..\n"; }

			if ($time != -1) { 
				if ($hash{dnum} > 0) {
					print G sprintf("$time aggup %.3f num %5d\n", $tot_up, $hash{dnum});
				}
				$tot_up = $hash{dnum} = 0;
			}
			$time = $1;
			next;
		}

		m/(\d+) #d/;
		my $id = $1;

		if (defined $nref->[$id]) {

			unless ($nref->[$id]->{seed}) {
				$tot_up += $nref->[$id]->{up};
				$hash{dnum}++;
			}
		}
		else {
			warn "blah! ID[$id] not defined in the nodes array??";
		}
	}
	close $fh;
}

sub update_stats {
	my ($nhash, $field, $val) = @_;
	$nhash->{$field} += $val;
	$nhash->{"$field.std"} += $val * $val;
}   

