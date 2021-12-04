require "inc.pl";

local $graph;
local $replot;
local $useold;

sub begin_plot {
    my %params = @_;

    $graph = qq(
set style line 1 lw 1.4 ps 0.9
set xlabel "$params{xlabel}"
set ylabel "$params{ylabel}"
	    );

    if ($GRAPHTYPE eq 'eps') { 
        $graph .= "set terminal postscript color eps\n";
    }
    elsif ($GRAPHTYPE eq 'pdf') { 
        $graph .= "set terminal pdf fsize 7\n";
    }

    if (exists $params{xrange}) {
	$graph .= qq(set xrange $params{xrange}\n);
    }
    if (exists $params{yrange}) {
	$graph .= qq(set yrange $params{yrange}\n);
    }
    if (exists $params{title}) {
	$graph .= qq(set title "$params{title}"\n);
    }

    if (exists $params{dothis}) {
	$graph .= qq($params{dothis}\n);
    }
    if (exists $params{useold}) {
	$useold = 1;
    } else {
	$useold = 0;
    }
    $replot = 0;
}

sub plot {
    my %params = @_;
    my $data = $params{data};
    return unless (defined $data || $useold == 1);

    if (!$replot) {
	$graph .= "plot ";
    } 
    else {
	$graph .= ", ";
    }
    $replot++;

    my $prog_name = $0;
    $prog_name =~ s/\.pl//;
    my $tmp_file = "__${prog_name}_data_$replot";
    $data = $tmp_file if ($useold == 1);
    if (ref($data) eq "ARRAY") {
	$graph .= "'$tmp_file' ";
    }
    else {
	$graph .= "'$data' ";
    }
    if (exists $params{using}) { 
	$graph .= "using $params{using} ";
    }
    if (exists $params{title}) {
	if ($params{title} eq "notitle") {
	    $graph .= qq(notitle );
	} else {
	    $graph .= qq(title "$params{title}" );
	}
    }
    if (exists $params{with}) {
	$graph .= qq(with $params{with} );
    }
    if (ref($data) eq "ARRAY") {
	my $sub = $data->[0];
	my @args = ();
	for (my $i = 1; $i < scalar @$data; $i++) {
	    push @args, $data->[$i];
	}
	my $to_plot = &$sub(\@args);

         # make a unique filename for this plot
	open F, ">$tmp_file" or die "can't open file to write...";
	print F $to_plot;
	close F;
    }
}

sub commit_plot {
    my $ofile = shift;

    $ofile = "$ofile.eps" if ($GRAPHTYPE eq 'eps');
    $ofile = "$ofile.pdf" if ($GRAPHTYPE eq 'pdf');
    
    open F, " | gnuplot > $ofile";
    print F $graph;
    close F;
}

1;
