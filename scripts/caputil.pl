#!/usr/bin/perl
use strict;
use Getopt::Std;
use vars qw($opt_z);

getopts("z");
our $GZIPPED_INPUT = defined $opt_z ? 1 : 0;

my $file = shift;
defined $file or die "no file given to process!";

my $nodes_ref = read_bwdata("$file.nds");
open G, ">$file.cap" or die "could not open $file.cap for writing...";
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
	my ($hash, $interested, $allowed, $useful, $ui, $uu, $ua);

	while (defined ($_ = <$fh>))
	{
		chomp;
#my @fields = split;
		next if (/^#/);

		if (/time (\d+)/) {
			$i++;
			if ($i % 500== 0) { print STDERR "$i..\n"; }

			if ($time != -1) { 
				if ($hash->{unum} != 0 && $hash->{dnum} != 0) 
				{
					printf G "$time up %.3f down %.3f ", $hash->{'up-util'}/$hash->{unum}, $hash->{'down-util'}/$hash->{dnum} ;
					foreach ('int', 'allowed', 'useful', 'abs-int', 'abs-allowed', 'abs-useful', 'abs-conns', 
							'abs-uint', 'abs-uuseful', 'abs-uallowed') {
						$hash->{$_} /= $hash->{unum};
						$hash->{"$_.std"} /= $hash->{unum};
						$hash->{"$_.std"} -= $hash->{$_} * $hash->{$_};
						if ($hash->{"$_.std"} < 0) {
							$hash->{"$_.std"} = 0;
						}
						else {
							$hash->{"$_.std"} = sqrt($hash->{"$_.std"});
						}
					}
					printf G "int %.3f %.3f allowed %.3f %.3f useful %.3f %.3f ", 
					$hash->{"int"}, $hash->{"int.std"},
					$hash->{"allowed"}, $hash->{"allowed.std"},
					$hash->{"useful"}, $hash->{"useful.std"};

					printf G "absint %.3f %.3f absallowed %.3f %.3f absuseful %.3f %.3f absconns %.3f %.3f ", 
					$hash->{"abs-int"}, $hash->{"abs-int.std"},
					$hash->{"abs-allowed"}, $hash->{"abs-allowed.std"},
					$hash->{"abs-useful"}, $hash->{"abs-useful.std"},
					$hash->{"abs-conns"}, $hash->{"abs-conns.std"};

					printf G "uint %.3f %.3f uallowed %.3f %.3f uuseful %.3f %.3f ",
					$hash->{"abs-uint"}, $hash->{"abs-uint.std"},
					$hash->{"abs-uallowed"}, $hash->{"abs-uallowed.std"},
					$hash->{"abs-uuseful"}, $hash->{"abs-uuseful.std"};

					printf G "\n";

					foreach (keys %$hash) { 
						$hash->{$_} = 0;
					}
				}
			}
			$time = $1;
			next;
		}

		m/(\d+) #d (\d+) ([\w.]+) #u (\d+) ([\w.]+) p \d+ \d+ s [01] #p (\d+) (\d+) (\d+) (\d+) (\d+) (\d+) (\d+)/;
		my $id = $1;
		my $down_conn = $2;
		my $down_bw = $3;
		my $up_conn = $4;
		my $up_bw = $5;

		my $conn = $6;
		$interested = $7; $allowed = $8; $useful = $9;
		$ui = $10; $ua = $11; $uu = $12;

		if (defined $nref->[$id]) {

			unless ($nref->[$id]->{seed}) {
				if ($conn > 0) {
					update_stats($hash, 'int', ($interested/$conn));
					update_stats($hash, 'allowed', ($allowed/$conn));
					update_stats($hash, 'useful', ($useful/$conn));
				}

				update_stats($hash, 'abs-int', $interested);
				update_stats($hash, 'abs-allowed', $allowed);
				update_stats($hash, 'abs-useful', $useful);
				update_stats($hash, 'abs-conns', $conn);

				update_stats($hash, 'abs-uint', $ui);
				update_stats($hash, 'abs-uallowed', $ua);
				update_stats($hash, 'abs-uuseful', $uu);

				update_stats($hash, 'up-util', ($up_bw / $nref->[$id]->{'up'}));
				update_stats($hash, 'up-conn', $up_conn);
				$hash->{unum}++;

				update_stats($hash, 'down-util', ($down_bw / $nref->[$id]->{'down'}));
				update_stats($hash, 'down-conn', $down_conn);

				$hash->{dnum}++;
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

