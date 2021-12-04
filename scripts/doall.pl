use Getopt::Std;
use vars qw($opt_g $opt_z);

require "inc.pl";
getopts("gz");

our $GRAPH_ONLY = defined $opt_g ? 1 : 0;
our $GZIPPED_INPUT = defined $opt_z ? 1 : 0;

if ($ARGV[0] =~ /\.$/) {
    chop ($ARGV[0]);
}
$prefix = $ARGV[0];

$PRINT_ONLY = 0;

my $args = join " ", @ARGV;
print "ARGS = $args\n";
unless ($GRAPH_ONLY) {
    my $act_args = " -z $args" if $GZIPPED_INPUT;
    psystem("perl $path/scripts/caputil.pl $act_args");
    psystem("perl $path/scripts/nodestats.pl $act_args");
    psystem("perl $path/scripts/timeseries.pl $act_args");
}

psystem("perl $path/plotscripts/PlotDetails.pl $args");
psystem("perl $path/plotscripts/capplot.pl $args");
psystem("perl $path/plotscripts/plot_timeseries.pl $args");
make_all_graphs($prefix);

psystem("mkdir -p $prefix.graphs");
psystem("mv $prefix.*.$GRAPHTYPE $prefix.graphs");
psystem("mv all.ps $prefix.graphs");

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

sub make_all_graphs {
    my $prefix = shift;

    open F, "> tmp111.tex" or die "can't open tmpfile for TeXing...";
    print F <<EOT;    
\\documentclass[10pt]{article}
\\usepackage{fullpage}
\%\\usepackage[pdftex]{graphicx}
\%\\usepackage[pdftex,hypertexnames=false]{hyperref}
\\usepackage{graphicx}

\\newcommand{\\img}[2]{%
\\begin{figure}[h]
\\centering%
\%\\includegraphics[type=pdf,ext=pdf,read=pdf,width=0.9\\columnwidth]{#1}
\\includegraphics[type=$GRAPHTYPE,ext=$GRAPHTYPE,read=$GRAPHTYPE,height=4in]{#1}
\\caption{#2}
\\label{fig:#1}
\\end{figure}
}
\\def\\prefix#1{$prefix.#1.}

\\begin{document}
\\listoffigures

\\section*{Relevant experiment details}
\\begin{verbatim}
EOT

     my $gh = OpenFile("$prefix.prm") or die "can't open $file.prm";
     while (defined (my $line = <$gh>)) {
	 $line =~ s/\t/        /g;
	 print F $line;
     }
     close $gh;

     print F <<EOT;
\\end{verbatim}

\\img{\\prefix{cap}}{Capacity utilization}
\%\\img{\\prefix{eta}}{Variation of \$\\eta\$ across time}
\%\\img{\\prefix{uabseta}}{Variation of \$\\eta\$ (uploader) across time}
\\img{\\prefix{abseta}}{Variation of \$\\eta\$ (downloader) across time}
\\img{\\prefix{nod}}{\\#Nodes as a function of time}
\\img{\\prefix{dnldcdf}}{CDF of download times; notice the spread}
\\img{\\prefix{served}}{\\#Blocks served by various nodes throughout their
stay}
\\img{\\prefix{dnldvsarrival}}{Download time vs. arrival time}
\\img{\\prefix{dist}}{Blocks served vs. distance from seed}
\\img{\\prefix{outdeg}}{Mean outgoing degree of a node over time;
 Outgoing degree = \\#outgoing transfers}
\\img{\\prefix{indeg}}{Mean in-degree of a node over time; In-degree = 
    \\#incoming transfers}
\\img{\\prefix{conncdf}}{CDF of \\#peers of a node (averaged over time)}
\\end{document}
EOT

    close F;
    psystem("latex tmp111.tex && latex tmp111.tex && dvips -o tmp111.ps tmp111.dvi");
    psystem("mv tmp111.ps all.ps");
    psystem("rm -f tmp111.*");
}
