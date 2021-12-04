#!/usr/bin/perl
use strict;
use Getopt::Std;
use vars qw($opt_z);

getopts("z");
our $GZIPPED_INPUT = defined $opt_z ? 1 : 1;

my $nodes_ref = read_bwdata("default.out.nds");
while (<STDIN>) {
	chomp;
	m/(\d+)/;
	my $n = $1;
	
	print sprintf("up:%4d dn:%4d join:%3d $_\n", 
			$nodes_ref->[$n]->{up}, $nodes_ref->[$n]->{down},
			int($nodes_ref->[$n]->{jointime}/1000));
}

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
