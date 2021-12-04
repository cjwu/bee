#!/usr/bin/perl
use strict;

my $file = shift;
defined $file or die "no file given to process!";

my $nodes_ref = read_bwdata("$file.nds");
foreach my $hash (@$nodes_ref) {
    if (not $hash->{seed}) {
	print $hash->{id}, " ", $hash->{jointime}, " ";

	if (exists $hash->{finishtime}) {
	    print $hash->{finishtime}, " ", ($hash->{finishtime} - $hash->{jointime}), "\n";
	}
	else {
	    print "-1 -1", "\n";
	}
    }
}

sub read_bwdata {
	my $f = shift;
	my @nodes = ();

	open F, $f or die " could not open file $f for reading ";
	while (defined ($_ = <F>)) 
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
	}		
	close F;
	return \@nodes;
}
		
