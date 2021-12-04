#!/usr/bin/perl

# find the number of unfinished nodes in a trace; 
# get number of blocks; get number of blocks received by each node;
# find out how many had less than wanted; how much

use strict;
use Getopt::Std;
use vars qw($opt_z);

getopts("z");
our $GZIPPED_INPUT = defined $opt_z ? 1 : 1;

my $nodes_ref = read_bwdata("default.out.nds.gz");
my $total_blocks = GetNumBlocks("default.out.prm.gz");

foreach my $node (@$nodes_ref) { 
	next if !defined $node->{id} or $node->{id} == 1;
	if ($node->{blocks} < $total_blocks) { 
		print sprintf("%5s unfinished; missed %5d blocks\n", 
				$node->{id},
				($total_blocks - $node->{blocks}));
	}
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

sub GetNumBlocks ($)
{
	my $f = shift;
	my ($filesize, $blocksize);

	my $fh = OpenFile($f) or die " could not open file $f for reading ";
	while (<$fh>)
	{
		chomp; 
		$filesize = $1 if /File size: (\d+) KB/;
		$blocksize = $1 if /Block size: (\d+) KB/;
	}
	close F;

	return "nan" if (not defined $blocksize or $blocksize == 0);
	return int($filesize/$blocksize);
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
			$nodes[$id]->{blocks}   = 0;
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
		elsif (/^\d+ (\d+) r p/) {
			$nodes[$1]->{blocks} ++;
		}
	}		
	close $fh;
	return \@nodes;
}
