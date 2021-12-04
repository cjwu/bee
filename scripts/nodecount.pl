#!/usr/bin/perl
use strict;

my $file = shift;
defined $file or die "no file given to process!";

gather_timeseries_data("$file.nds");

sub gather_timeseries_data {
    my $f = shift;
    my @nodes = ();

    open F, $f or die " could not open file $f for reading ";
    while (defined ($_ = <F>)) 
    {
	chomp;
	next if /^#/;

	if (/^(\d+) (\d+) join (\w+) B d (\d+) u (\d+)/) {
	    $n_nodes ++ ;
	    $time = $1;
	    update_bws($5, $4);
	    $start_time{$2} = $time;
	    if ($3 eq "seed") {
		$is_seed{$2} = 1;
		$n_seeds ++;
	    } 
	    else {
		$n_leechers ++;
	    }
	}
	elsif (/^(\d+) (\d+) leave/) { 
	    $time = $1;
	    if (defined $is_seed{$2} and $is_seed{$2} eq "1") {
		$n_seeds -- ;
	    }
	    else {
		$n_leechers --;
	    }
	}
	elsif (/^(\d+) (\d+) finished/) {
	    $time = $1;

	    $tot_time = $1 - $start_time{$2};

	    $nodes[$2]->{finishtime} = $1;
	}
    }		
    close F;
    return \@nodes;
}
