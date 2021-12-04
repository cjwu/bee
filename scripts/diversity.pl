#!/usr/bin/perl
use strict;

my $file = shift;
defined $file or die "no file given to process!";

select STDERR; $| = 1; print STDERR "reading NDS file...";
open H, "> $file.div" or die "could not open $file.div for writing";
read_bwdata("$file.nds");
print STDERR "done.\n";

sub get_second {
    return int($_/1000);
}

=start
sub dump_data {
    my ($time, $nref) = @_;
    my @count;

    for (my $i = 0; $i < 400; $i++) {
	$count[$i] = 0;
    }
    for (my $i = 0; $i < 400; $i++) {
	foreach my $nh (@$nref) {
	    if ($nh->{recvd}->{$i} == 1) {
		$count[$i]++;
	    }
	}
    }

    my ($mean, $std, $min, $max, $p5, $p95);
    if (scalar @count <= 0) {
	return;
    }

    select STDOUT;
    ($mean, $std, $min, $max, $p5, $p95) = get_mean_std(\@count);
    printf H "$time %.3f %.3f $min $max $p5 $p95", $mean, $std;
#    foreach my $c(@count) {
#	print " $c";
#    }
    print H "\n";
}
=cut

sub dump_data {
    my ($time, $counts_ref) = @_;

    my ($mean, $std, $min, $max, $p5, $p95);
    if (scalar @$counts_ref <= 0) {
	return;
    }

    ($mean, $std, $min, $max, $p5, $p95) = get_mean_std($counts_ref);
    printf H "$time %.3f %.3f $min $max $p5 $p95", $mean, $std;
    print H "\n";
}

sub get_mean_std {
    my $aref = shift;
    my $mean = 0;
    my $std = 0;
    my $len = scalar @$aref;

    for (my $i = 0; $i < $len; $i++) {
	$mean += $aref->[$i];
	$std  += $aref->[$i] * $aref->[$i];
    }

    $mean /= $len;
    $std  /= $len;
    $std  -= $mean * $mean;
    $std = sqrt($std);
    
#    my @arr = sort { $a <=> $b } @$aref;
    my @arr = @$aref;
    
    return ($mean, $std, $arr[0], $arr[$len - 1], get_perc(\@arr, 5), get_perc(\@arr, 95));
}

sub get_perc {
    my ($aref, $perc) = @_;
    my ($index);

    $index = int ($perc * (scalar @$aref - 1) / 100.0);
    return $aref->[$index];
}
    

sub read_bwdata {
    my $f = shift;
    my @nodes = ();
    my $time;
    my $prevsec = -1;
    my @counts = ();

    for (my $i = 0; $i < 400; $i++) {
	$counts[$i] = 0;
    }

    open F, $f or die " could not open file $f for reading ";
    while (defined ($_ = <F>)) 
    {
	chomp;

	if (/^(\d+) (\d+) join (\w+) B d (\d+) u (\d+)/) {
	    my $id = $2;
	    $time = $1;

	    $nodes[$id]->{jointime} = $1;
	    $nodes[$id]->{id}       = $id;
	    $nodes[$id]->{up}       = $5;
	    $nodes[$id]->{down}     = $4;
	    $nodes[$id]->{seed}     = ($3 eq "seed") ? 1 : 0;
	    $nodes[$id]->{seedtime} = $1;
	    if ($nodes[$id]->{seed}) {
		$nodes[$id]->{downloadtime} = 0;
		$nodes[$id]->{finishtime} = 0;
	    }
	}
	elsif (/^(\d+) (\d+) leave/) { 
	    $time = $1;
	    $nodes[$2]->{leavetime} = $1;
	}
	elsif (/^(\d+) (\d+) finished/) {
	    $time = $1;
	    $nodes[$2]->{finishtime} = $1;
	    $nodes[$2]->{downloadtime} = $1 - $nodes[$2]->{jointime};
	}
	elsif (/^(\d+) (\d+) r p (\d+) n (\d+)/) {
	    $time = $1;
	    $nodes[$4]->{sentpieces} ++;
	    $nodes[$2]->{recvpieces} ++;

#	    $nodes[$2]->{recvd}->{$3} = 1;
	    $counts[$3]++;
	}
	elsif (/^(\d+) (\d+) seedified/) {
	    $time = $1;
	    $nodes[$2]->{seed} = 1;
	    $nodes[$2]->{seedtime} = $1;
	}
	 if ($prevsec == -1 or $prevsec != get_second($time)) {
	     dump_data(get_second($time), \@counts);
	      $prevsec = get_second($time);
	}
    }		
    close F;
    return \@nodes;
}

