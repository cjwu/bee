#  Usage: CapUtil_all.pl  <file prefix> [title of capacity utilization graph]
#
foreach (@ARGV) { 
    $_ = "\"$_\"";
}
$args = join " ", @ARGV;
$path = "/home/t-ashbha/sim";
system "perl $path/scripts/caputil.pl $args";
system "perl $path/plotscripts/capplot.pl $args";
