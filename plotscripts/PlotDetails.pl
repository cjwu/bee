require "inc.pl";
require "$path/plotscripts/plotlib.pl";

($file = shift) or  die " no file given to process";
# $nod_ref = read_nds_file("$file.nds");
chomp (@uniques = `perl -ne \"print unless /id 1 /\" $file.stt | awk '{ print \$32 }' | sort | uniq`);

begin_plot(xlabel => "Nodes (sorted by increasing download times)", ylabel => "Download time",
	title => "CDF of download times", yrange => "[0:]");
funky_plot(data => "$file.stt", using => "1:(\$5/1000)", title => "notitle");
commit_plot("$file.dnldcdf");

chomp ($seed_served = `grep 'id 1 ' $file.stt | awk '{ print \$9 }'`);
begin_plot(xlabel => "Nodes (sorted by increasing download times)", ylabel => "#Blocks served",
	title => "#Blocks served by various nodes; seed served $seed_served", xrange => "[1:]", 
	yrange => "[0:]");
funky_plot(data => "< perl -ne \"print unless /id 1 /\" $file.stt", 
	using => "1:9", title => "notitle");
commit_plot("$file.served");

begin_plot(xlabel => "Node IDs (in other words, sorted according to arrival times)", ylabel => "Download time",
	title => "Variation of download time against arrival time", yrange => "[0:]"
	);
funky_plot(data => "$file.stt", using => "((\$7-\$5)/1000):(\$5/1000)", title => "notitle");
commit_plot("$file.dnldvsarrival");

begin_plot(xlabel => "Nodes (sorted by increasing download times)", ylabel => "Upload utilization",
	title => "Variation of upload utilization");
funky_plot(data => "$file.stt", using => "1:20", title => "notitle");
commit_plot("$file.uutil");

begin_plot(xlabel => "Nodes (sorted by increasing download times)", ylabel => "Download utilization",
	title => "Variation of download utilization");
funky_plot(data => "$file.stt", using => "1:17", title => "notitle");
commit_plot("$file.dutil");

begin_plot(xlabel => "Nodes (sorted by increasing download times)", ylabel => "#Outgoing transfers (avg. over time)",
	title => "Variation of 'Outdegree'", yrange => "[0:]");
funky_plot(data => "$file.stt", using => "1:11", title => "notitle", with => "points");
commit_plot("$file.outdeg");

begin_plot(xlabel => "Nodes (sorted by increasing download times)", ylabel => "#Incoming transfers (avg. over time)",
	title => "Variation of 'Indegree'", yrange => "[0:]");
funky_plot(data => "$file.stt", using => "1:14", title => "notitle", with => "points");
commit_plot("$file.indeg");

begin_plot(xlabel => "Nodes (sorted by increasing download times)", ylabel => "#Peers (avg. over time)",
	title => "Variation of #connections", yrange => "[0:]");
funky_plot(data => "$file.stt", using => "1:23", title => "notitle", with => "points");
commit_plot("$file.conn");

begin_plot(xlabel => "Nodes", ylabel => "#Peers (avg. over time)",
	title => "CDF of #connections ('skew')", yrange => "[0:]");
funky_plot(data => "< sort -n +22 $file.stt", using => "1:23", title => "notitle", with => "points");
commit_plot("$file.conncdf");

begin_plot(xlabel => "Distance from seed", ylabel => "#blocks served",
	title => "Who serves too many blocks?", xrange => "[0:]");
funky_plot(data => "< perl -ne \"print unless /id 1 /\" $file.stt", 
	using => "26:9",
	title => "notitle", with => "points");
commit_plot("$file.dist");


sub funky_plot {
    my %plot_opts = @_;

    foreach my $key (@uniques) { 
	my %tmp_opts = %plot_opts;
	if ($tmp_opts{data} =~ /< /) {
	    $tmp_opts{data} .= " | grep -- \"$key\" ";
	}
	else {
	    $tmp_opts{data} = "< grep -- \"$key\" " . $tmp_opts{data};
	}
	$tmp_opts{title} = "$key";
	plot(%tmp_opts);
    }
}

sub read_nds_file {
    my $file = shift;
    my %hash = ();
   
    open F, $f or die " could not open file $f for reading ";
    print STDERR "reading NDS file...\n";
    while (defined ($_ = <F>)) 
    {       
        chomp;
	next if (/^#/);
        
        if (/^(\d+) (\d+) join (\w+) B d (\d+) u (\d+)/) {
            my $id = $2;
	    my $down = $4;
	    my $up = $5;

	    $hash{$id} = "d$down-u$up";
	}
    }
    close F;
    print STDERR "done!\n";
    return \%hash;
}
