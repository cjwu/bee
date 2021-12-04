#!/usr/bin/perl
use strict;
use Getopt::Std;
use vars qw($opt_z);

getopts("z");
our $GZIPPED_INPUT = defined $opt_z ? 1 : 0;

#########################################################
my $file = shift;
defined $file or die "no file given to process!";

select STDERR; $| = 1; print STDERR "reading NDS file...";
my $nodes_ref = read_bwdata("$file.nds");
print STDERR "done.\n";

# be careful about the "seed" node when you are plotting various things...

select STDERR; $| = 1; print STDERR "gathering node statistics...\n";
gather_nodestats("$file.bw", $nodes_ref);
print STDERR "done.\n";
foreach my $nhash (@$nodes_ref) {
    next if (not defined $nhash->{id});        # ID's begin with "1"; doh! ;
    next if (not defined $nhash->{nsamples} or $nhash->{nsamples} == 0);
    foreach my $field ('utrans', 'dtrans', 'dutil', 'uutil', 'conns', 'dist', 'int', 'allowed', 'useful') {
	$nhash->{$field} /= $nhash->{nsamples};
	$nhash->{"$field.std"} /= $nhash->{nsamples};
	$nhash->{"$field.std"} -= $nhash->{$field} * $nhash->{$field};
	if ($nhash->{"$field.std"} < 0) { 
	    $nhash->{"$field.std"} = 0;
	}
	else {
	    $nhash->{"$field.std"} = sqrt($nhash->{"$field.std"});
	}
    }
    if (not defined $nhash->{downloadtime}) {
	 $nhash->{downloadtime} = -1;
	 $nhash->{finishtime} = -1;
    }
}

=start
# process the graph;;
my $sptr = read_graph("$file.gph");
foreach my $n (sort { $a <=> $b } keys %$sptr) {
    my $nhash = $sptr->{$n};
    foreach my $field ('dist') {
	$nhash->{$field} /= $nhash->{nsamples};
	$nhash->{"$field.std"} /= $nhash->{nsamples};
	$nhash->{"$field.std"} -= $nhash->{$field} * $nhash->{$field};
	$nhash->{"$field.std"} = sqrt($nhash->{"$field.std"});
    }   

    $nodes_ref->[$n]->{'dist'} = $nhash->{'dist'};
    $nodes_ref->[$n]->{'dist.std'} = $nhash->{'dist.std'};
    
     #printf "$n %.3f %.3f\n", $nhash->{'dist'}, $nhash->{'dist.std'};
}
=cut

open G, ">$file.stt";
my $i = 0;
foreach my $nh (sort { return $a->{downloadtime} <=> $b->{downloadtime} } @$nodes_ref)
{
    next if (not defined $nh->{id});        # ID's begin with "1"; doh! ;
    next if (not defined $nh->{nsamples} or $nh->{nsamples} == 0);
    printf G "$i id $nh->{id} dnldtime $nh->{downloadtime} finish $nh->{finishtime} served $nh->{sentpieces} ";
    foreach my $field ('utrans', 'dtrans', 'dutil', 'uutil', 'conns', 'dist') {
	printf G "$field %.3f %.3f ", $nh->{$field}, $nh->{"$field.std"};
    }
    printf G "int-allowed-useful %.2f %.2f %.2f ", $nh->{'int'}, $nh->{'allowed'}, $nh->{'useful'};
    printf G "d$nh->{down}:u$nh->{up}";
    printf G "\n";
    $i++;
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

sub gather_nodestats {
    my $f = shift;
    my $nref = shift;

    my $fh = OpenFile($f) or die "could not open $f for reading ";

    my $time = -1;
    my $i = 0;
    my ($id, $dt, $ut, $db, $ub, $p, $conn, $interested, $allowed, $useful, $dist);
    
    while (defined ($_ = <$fh>))
    {
	chomp;
	next if (/^#/);

	if (/time (\d+)/) {
	    $i++;
	    if ($i % 500== 0) { print STDERR "$i..\n"; }
	    next;
	}

	m/(\d+) #d (\d+) ([\w.]+) #u (\d+) ([\w.]+) p \d+ \d+ s [01] #p (\d+) (\d+) (\d+) (\d+) \d+ \d+ \d+ D (\d+)/;
	$id = $1;
	$dt = $2;        # down transfers;
	$db = $3;
	$ut = $4;        # up transfers;
	$ub = $5;
	$conn = $6;

	$interested = $7; $allowed = $8; $useful = $9;
	$dist = $10;
	if ($dist == 999) {
	    if ($nref->[$id]->{nsamples} != 0) {
		$dist = $nref->[$id]->{'dist'} / $nref->[$id]->{nsamples};  # keep current average; 
	    }
	    else {
		$dist = 0;
	    }
	}

	$nref->[$id]->{nsamples}++;

	update_stats($nref->[$id], 'dtrans', $dt);
	update_stats($nref->[$id], 'utrans', $ut);
	update_stats($nref->[$id], 'dist', $dist);
	update_stats($nref->[$id], 'int', $interested);
	update_stats($nref->[$id], 'allowed', $allowed);
	update_stats($nref->[$id], 'useful', $useful);

	if (not $nref->[$id]->{seed} or $nref->[$id]->{seedtime} > $time) {
	    if (not defined $nref->[$id]->{down} or 
		    $nref->[$id]->{down} eq "" or 
		    $nref->[$id]->{down} == 0) {
		print STDERR "hulla!!! id = $id, down = $nref->[$id]->{down}\n";
	    }
	    update_stats($nref->[$id], 'dutil', $db / $nref->[$id]->{down});
	}
	update_stats($nref->[$id], 'uutil', $ub / $nref->[$id]->{up});
	update_stats($nref->[$id], 'conns', $conn );

	$nref->[$id]->{p} ++;
    }
    close $fh;
}

sub update_stats {
    my ($nhash, $field, $val) = @_;
    $nhash->{$field} += $val;
    $nhash->{"$field.std"} += $val * $val;
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
	    $nodes[$id]->{seedtime} = $1;
	    if ($nodes[$id]->{seed}) {
		$nodes[$id]->{downloadtime} = 0;
		$nodes[$id]->{finishtime} = 0;
	    }
	}
	elsif (/^(\d+) (\d+) leave/) { 
	    $nodes[$2]->{leavetime} = $1;
	}
	elsif (/^(\d+) (\d+) finished sent ([\d\.]+) recv ([\d\.]+)/) {
	    $nodes[$2]->{finishtime} = $1;
	    $nodes[$2]->{downloadtime} = $1 - $nodes[$2]->{jointime};
	    $nodes[$2]->{sentpieces} = $3;
	    $nodes[$2]->{recvpieces} = $4;
	}
	elsif (/^(\d+) (\d+) r p (\d+) n (\d+)/) {
	    $nodes[$4]->{sentpieces} ++;
	    $nodes[$2]->{recvpieces} ++;
	}
	elsif (/^(\d+) (\d+) seedified/) {
	    $nodes[$2]->{seed} = 1;
	    $nodes[$2]->{seedtime} = $1;
	}
    }		
    close $fh;
    return \@nodes;
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

    my $fh = OpenFile($file) or die "cannot open file $file for reading...";
    while (defined ($_ = <$fh>)) {
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
    close $fh;
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

