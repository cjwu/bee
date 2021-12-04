#!/usr/bin/perl
use strict;

my $file = shift;
defined $file or die "no file given to process!";

my $sptr = read_graph("$file.gph");
foreach my $n (sort { $a <=> $b } keys %$sptr) {
    my $nhash = $sptr->{$n};
    foreach my $field ('dist') {
	$nhash->{$field} /= $nhash->{nsamples};
	$nhash->{"$field.std"} /= $nhash->{nsamples};
	$nhash->{"$field.std"} -= $nhash->{$field} * $nhash->{$field};
	$nhash->{"$field.std"} = sqrt($nhash->{"$field.std"});
    }   

    printf "$n %.3f %.3f\n", $nhash->{'dist'}, $nhash->{'dist.std'};
}

sub read_graph {
    my $file = shift;
    my $cur_time = -1;
    my @arr = ();
    my $count = 0;
    my %graph = ();
    my %stats = ();

    for (my $i = 0; $i < 100; $i++) {
	$arr[$i] = "1234";
    }

    open F, $file or die "cannot open file $file for reading...";
    while (defined ($_ = <F>)) {
	my ($node, $edges);

	chomp;
	s/\r$//;
	if (/time (\d+)/) {
	    if ($cur_time != -1) {
		capture_graph_details(\%graph);
		foreach my $n (keys %graph) {
		    update_stats($stats{$n}, "dist", $graph{$n}->{dist});
		    $stats{$n}->{nsamples}++;
		}
		%graph = ();
	    }
	    $cur_time = $1;

	    $count++;
	    if ($count % 10 == 0) { 
		print "$cur_time...\n";
	    }
	}
	else {
	    ($node, undef, $edges) = split(/ /, $_, 3);
	    $graph{$node}->{edges} = "$edges";
	}
    }
    close F;
    return \%stats;
}

sub capture_graph_details {
    my $gptr = shift;
    my $cur = 1;     # start with node 1;
    my @queue = (1);
    my @links;
    my $cur_dist = 0;

    $gptr->{1}->{dist} = 0;
    while (scalar @queue > 0) {
	$cur = shift @queue;
	$cur_dist = $gptr->{$cur}->{dist};
	@links = split(/ /, $gptr->{$cur}->{edges});

	foreach my $l (@links) {
	    if (not defined $gptr->{$l}->{dist}) {
		$gptr->{$l}->{dist} = $cur_dist + 1;
		push @queue, $l;
	    }
	}
    }

=start    
	foreach my $n (keys %$gptr) {
	    print "node($n) --> $gptr->{$n}->{dist}\n";
	}
=cut
}

sub update_stats {
    my ($nhash, $field, $val) = @_;
    $nhash->{$field} += $val;
    $nhash->{"$field.std"} += $val * $val;
}
