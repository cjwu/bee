require "inc.pl";
require "$path/plotscripts/plotlib.pl";

($file = shift) or  die " no file given to process";
$main_title = shift; 
defined $main_title or $main_title = "Variation of bw utilization";

begin_plot(xlabel => "Time (in seconds)", ylabel => "Bw utilization (kbps)", 
	title => "$main_title");

foreach $stuff ( "Upload:3", "Download:5") {
    ($title, $using) = split(/:/, $stuff);
    plot(data => "$file.cap", using => "(\$1/1000):$using", title => "$title utilization", 
	with => "lines lw 2");
}
commit_plot("$file.cap");

#begin_plot(xlabel => "Time (in seconds)", ylabel => "Percentage",
#	title => "Connection statistics", yrange => "[:120]");
#
#foreach $stuff ( "Interested:7", "Allowed:10", "Useful:13") {
#    ($title, $using) = split(/:/, $stuff);
#    plot(data => "$file.cap", using => "(\$1/1000):(\$$using * 100.0)", title => "$title conns",
#	with => "lines lw 2");
#}
#commit_plot("$file.eta");

begin_plot(xlabel => "Time (in seconds)", ylabel => "#Connections",
	title => "Connection statistics [downloader's perspective]");

foreach $stuff ( "Total:25", "Interested:16", "Allowed:19", "Useful:22") {
    ($title, $using) = split(/:/, $stuff);
    plot(data => "$file.cap", using => "(\$1/1000):(\$$using)", title => "$title conns",
	with => "lines lw 2");
}
commit_plot("$file.abseta");

#begin_plot(xlabel => "Time (in seconds)", ylabel => "#Connections",
#	title => "Connection statistics [Uploader's perspective]");
#
#foreach $stuff ( "Total:25", "Interested:28", "Allowed:31", "Useful:34") {
#    ($title, $using) = split(/:/, $stuff);
#    plot(data => "$file.cap", using => "(\$1/1000):(\$$using)", title => "$title conns",
#	with => "lines lw 2");
#}
#commit_plot("$file.uabseta");
