require "../plotlib.pl";

sub generate_mean_data {
    my $args_ref = shift;
    my $ret = '';
    my $file;

    print "\n";
    my $window = $args_ref->[0];
    my $map = $args_ref->[1];
    {
	$file = "../../diff_maps/$map-20-$window-z.out";
	print "$file..\n";
	open F, $file or die "can't open $file\n";

	my %deltas = ();
	my %sizes  = ();
	my %saved =  ();
	my $tot = 0;
	my $tot_size =0 ;
	while (defined ($_ = <F>)) {
	    chomp;
	    @array = split;
	    
	    pop @array;
	    pop @array;

	    (undef, $cur_frame, undef, $nents, @others) = @array;
	    for ($i = 0; $i < $nents; $i++) {
		my $ent = $others[$i * 3];
		my $size = $others[$i * 3 + 1];
		my $minf = $others[$i * 3 + 2];

		my $dist;
		if ($minf == -1) {
		    $dist = 0;
		}
		else {
		    $dist = ($cur_frame - $minf);
		}
		$deltas{$dist}++;
		$tot++;
		$sizes{$dist} += $size;
		$saved{$dist} += (208 - $size);
		$tot_size += $size;
	    }
	    if ($cur_frame % 500 == 0) {
		print STDERR "$cur_frame...\n";
	    }
	}

	foreach $dist (sort { $a <=> $b } keys %deltas) {
#$deltas{$dist} /= $cur_frame;
#	    $sizes{$dist} /= $cur_frame;
	    $ret .= "$dist $deltas{$dist} $sizes{$dist} $saved{$dist}\n";
	}
    }
    return $ret;
}

@maps = qw( q3tourney2 q3tourney6_ctf pro-q3dm13 pro-q3dm6 pro-q3tourney2);
foreach $map (@maps) {
    begin_plot(xlabel => 'Distance of min frame', ylabel => '#entities');

    foreach my $window (10, 20, 40) { #, 5, 10, 20, 40, 70, 100) ;
	plot(data => [ \&generate_mean_data, $window, $map  ],
		using => '1:2',
		with => 'linespoints lw 2 ps 1.2', title => "Window: $window");
    }
    commit_plot("mf-$map");

    begin_plot(xlabel => 'Distance of min frame', ylabel => 'saved entity bytes', 
	    useold => 1);
    foreach my $window (10, 20, 40) #, 5, 10, 20, 40, 70, 100) ;
    {
	plot(using => '1:4',
		with => 'linespoints lw 2 ps 1.2', title => "Window: $window");
    }
    commit_plot("wmf-$map");
}
