require "inc.pl";
system "perl $path/scripts/timeseries.pl $args";
system "perl $path/plotscripts/plot_timeseries.pl $args";
