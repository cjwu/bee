#!/usr/bin/perl
use Getopt::Std;
use vars qw($opt_z);

getopts("z");
our $GZIPPED_INPUT = defined $opt_z ? 1 : 0;

my $file = shift;
defined $file or die "no file given to process!";

open G, ">$file.tav" or die "can't open $file.tav for writing";
gather_timeseries_data("$file.nds");
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

sub gather_timeseries_data {
    my $f = shift;

    my $fh = OpenFile($f) or die " could not open file $f for reading ";
    $n_leechers = $n_seeds = $n_nodes = $n_finished = 0;
    while (defined ($_ = <$fh>)) 
    {
	chomp;
	next if /^#/;

	if (/^(\d+) (\d+) join (\w+) B d (\d+) u (\d+)/) {
	    $n_nodes++ ;
	    $tot_up += $5;
	    $tot_down += $4;

	    $time = $1;

	    $info{$2}->{jointime} = $1;
	    $info{$2}->{seed} = ($3 eq "seed" ? "1" : "0");
	    $info{$2}->{up} = $5;
	    $info{$2}->{down} = $4;

	    if ($3 eq "seed") {
		$n_seeds++;
		$seed_up += $5;
		$seed_down += $4;
	    } 
	    else {
		$leecher_up += $5;
		$leecher_down += $4;
		$n_leechers++;
	    }
	}
	elsif (/^(\d+) (\d+) leave/) { 
	    $time = $1;
	    $n_nodes--;
	    $tot_up -= $info{$2}->{up};
	    $tot_down -= $info{$2}->{down};

	    if (defined $is_seed{$2} and $is_seed{$2} eq "1") {
		$n_seeds -- ;
		$seed_up -= $info{$2}->{up};
		$seed_down -= $info{$2}->{down};
	    }
	    else {
		$n_leechers --;
		$leecher_up -= $info{$2}->{up};
		$leecher_down -= $info{$2}->{down};
	    }
	}
	elsif (/^(\d+) (\d+) finished/) {
	    $time = $1;

	    $n_finished++;
	    $tot_finish += ($time - $info{$2}->{jointime});
	    $info{$2}->{finishtime} = $time;
	}
	elsif (/^(\d+) (\d+) seedified/) {
	    $time = $1;

	    $n_seeds++;
	    $n_leechers--;

	    $tot_up -= $info{$2}->{up};
	    $tot_down -= $info{$2}->{down};
	    $leecher_up -= $info{$2}->{up};
	    $leecher_down -= $info{$2}->{down};

	    $seed_up += $info{$2}->{up};
	    $seed_down += $info{$2}->{down};
	}
	else {
	    undef $time;
	}

	if (defined $time) {
	    printf G "%d", ($time/1000);
	    print G " present $n_nodes seeds $n_seeds leechers $n_leechers finished $n_finished ";
	    printf G "avg_dnldtime %.3f avg_downcap %.3f avg_upcap %.3f ", ($tot_finish/($n_finished + 0.001)), 
		   ($tot_up/($n_nodes + 0.001)), ($tot_down/($n_nodes + 0.0001));
	    printf G "avgseed_downcap %.3f avgseed_upcap %.3f avgleech_downcap %.3f avgleech_upcap %.3f\n",
		   ($seed_down/($n_seeds + 0.001)), ($seed_up/($n_seeds + 0.001)), 
		   ($leecher_down/($n_leechers + 0.001)), ($leecher_up/($n_leechers + 0.001));
	}		
    }
    close $fh;
}
