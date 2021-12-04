require "inc.pl";
require "$path/plotscripts/plotlib.pl";

($file = shift) or  die " no file given to process";

begin_plot(xlabel => "Time (in seconds)", ylabel => "#Nodes", title => "Variation of the node population with time");
foreach $stuff ( "NODES:3", "SEEDS:5", "LEECHERS:7", "FINISHED:9") {
    ($title, $using) = split(/:/, $stuff);
    plot(data => "$file.tav", using => "1:$using", title => "#$title", with => "lines");
}
commit_plot("$file.nod");

begin_plot(xlabel => "Time (in seconds)", 
	ylabel => "Upload capacity (kbps)", title => "Variation of average upload capacity of system");
foreach $stuff ( "SEEDS:19", "LEECHERS:23") {
    ($title, $using) = split(/:/, $stuff);
    plot(data => "$file.tav", using => "1:$using", title => "$title", with => "lines");
}
commit_plot("$file.upc");

begin_plot(xlabel => "Time (in seconds)", 
	ylabel => "Download capacity (kbps)", title => "Variation of average download capacity of system");
foreach $stuff ( "LEECHERS:21") {
    ($title, $using) = split(/:/, $stuff);
    plot(data => "$file.tav", using => "1:$using", title => "$title", with => "lines");
}
commit_plot("$file.dnc");

