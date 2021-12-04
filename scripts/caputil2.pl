#!/usr/bin/perl
# 
# Measure utilization in a different manner. 
# instead of  sigma_  (util/cap)  , 
# do          sigma_util / sigma_cap

use strict;
use Getopt::Std;
use vars qw($opt_z);

getopts("z");
our $GZIPPED_INPUT = defined $opt_z ? 1 : 0;

my $file = shift;
defined $file or die "no file given to process!";

my $nodes_ref = read_bwdata("$file.nds");
open G, ">$file.cap2" or die "could not open $file.cap for writing...";
find_caputil("$file.bw", $nodes_ref);
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

sub find_caputil {
	my $f = shift;
	my $nref= shift;

	my $fh = OpenFile($f) or die " could not open file $f for reading ";

	my $time = -1;
	my $i = 0;
	my ($tot_up, $tot_down, $util_up, $util_down) = (0, 0, 0, 0);

	while (defined ($_ = <$fh>))
	{
		chomp;
#my @fields = split;
		next if (/^#/);

		if (/time (\d+)/) {
			$i++;
			if ($i % 500== 0) { print STDERR "$i..\n"; }

			if ($time != -1) { 
				if ($tot_up > 0 and $tot_down > 0) 
				{
					printf G "$time up %.3f down %.3f ", $util_up/$tot_up, $util_down/$tot_down;
					printf G "\n";

					($tot_up, $tot_down, $util_up, $util_down) = (0, 0, 0, 0);
				}
			}
			$time = $1;
			next;
		}

		m/(\d+) #d (\d+) ([\w.]+) #u (\d+) ([\w.]+)/;
		my $id = $1;
		my $down_conn = $2;
		my $down_bw = $3;
		my $up_conn = $4;
		my $up_bw = $5;

		if (defined $nref->[$id]) {

			unless ($nref->[$id]->{seed}) {
				$util_up += $up_bw;
				$tot_up += $nref->[$id]->{'up'};

				$util_down += $down_bw;
				$tot_down += $nref->[$id]->{'down'};
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

