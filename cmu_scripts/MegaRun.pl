#!/usr/bin/perl

use strict;
use conf;
use Net::hostent;
use Socket;
use Getopt::Std;
require "./inc.pl";

our $DATADIR = "/home/mercury/msr/data";
our $USER = "ashu";
our $PROG = "mono ./OctoSim/OctoSim.exe";
our $common_args = "-t 10000 -maxu 5 -fsize 819200 -b 2048 -rnd r -jr 100 -j 10 -d 5 -sbw 6000 "; # will be overridden by newer arguments
our $homog_args  = "-w Homog.wl $common_args -bw '1500:400:1.0'";
our $hetero_args = "-w Hetero.wl $common_args";
our $bw_hetero =  "-bw '6000:3000:0.33 1500:400:0.33 784:128:0.34' "; 

# varynodes; figures 1 and 2
sub RunNodes {
	my ($cmd, $outdir, @nodes) = @_;
	$outdir = "data/$outdir";

	chdir($TOPDIR);
	foreach my $n (@nodes) {
		my $fodir = "$outdir/nodes-$n";
		my $jointime = $n / 100;
		my $maxnodes = $n + 200;
		my $fcmd = "$cmd -j $jointime -maxnodes $maxnodes -o $fodir/default.out";

		doit($fodir, $fcmd);
	}
}

if (0) {
	my $args = "$homog_args -smartseed -nsu"; 
	my @nodes = (100, 200, 400, 1000, 2000, 3000, 4000, 5000, 8000);

	my $mach = 'iris-d-02';
	$OUTPUT_REDIR = "$DATADIR/$mach.progress";
	rsystem_opts(0, 1, $USER, $mach, \&RunNodes, "$PROG $args", "2001-rerun/varynodes", @nodes); 	
}

# seedbw; figures 3 and 4
sub RunSeedsBw {
    my ($cmd, $outdir, @seedbws) = @_;
    $outdir = "data/$outdir";
    
    chdir($TOPDIR);
    foreach my $sbw (@seedbws) {
		my $fodir = "$outdir/sbw-$sbw";
		my $fcmd = "$cmd -sbw $sbw -o $fodir/default.out";

		doit($fodir, $fcmd);
	}
}

if (0) {
	my %settings = ('iris-d-03', [ 'smartseed', '-smartseed -nsu' ], 
			'iris-d-04', [ 'nosmartseed', '']);

	my @sbws = (200, 400, 600, 800, 1000);
	
	foreach my $mach (keys %settings) {
		my $aref = $settings{$mach};
		my $args = $homog_args . " " . $aref->[1];
		my $dir = $aref->[0];
		
		$OUTPUT_REDIR = "$DATADIR/$mach.progress";
		rsystem_opts(0, 1, $USER, $mach, \&RunSeedsBw, "$PROG $args", "2001-rerun/varyseedbw/$dir", @sbws); 	
	}
}

# numseeds; figure 5
sub RunNSeeds {
    my ($cmd, $outdir, @nseeds) = @_;
    $outdir = "data/$outdir";
    
    chdir($TOPDIR);
    foreach my $n (@nseeds) {
		my $fodir = "$outdir/nseeds-$n";
		my $fcmd = "$cmd -seeds $n -o $fodir/default.out";
		doit($fodir, $fcmd);
	}
}		

if (0) {
	my $args = "$homog_args -sbw 200 -smartseed -nsu"; 
	my @nseeds = (1, 2, 3, 4, 5);

	my $mach = 'iris-d-05';
	$OUTPUT_REDIR = "$DATADIR/$mach.progress";
	rsystem_opts(0, 1, $USER, $mach, \&RunNSeeds, "$PROG $args", "2001-rerun/nseeds", @nseeds); 	
}

# vary maxu; figure 11; this does not make sense for d=7;
sub RunMaxU {
    my ($cmd, $outdir, @maxus) = @_;
    $outdir = "data/$outdir";

    chdir($TOPDIR);
	my %settings = ('smartseed', '-smartseed -nsu', 
			'nosmartseed', '');
	foreach my $type (keys %settings) {
		my $args = $settings{$type};
		foreach my $u (@maxus) {
			my $fodir = "$outdir/$type/u-$u";
			my $fcmd = "$cmd $args -maxu $u -o $fodir/default.out";

			doit($fodir, $fcmd);
		}
    }
}

if (0) {
	my %settings = ('iris-d-02', 400, 
			'iris-d-03', 1500);

	my @maxus = (3, 5, 10, 20);
	
	foreach my $mach (keys %settings) {
		my $sbw = $settings{$mach};
		my $args = "$homog_args -sbw $sbw";

		$OUTPUT_REDIR = "$DATADIR/$mach.progress";
		rsystem_opts(0, 1, $USER, $mach, \&RunMaxU, "$PROG $args", 
				"2001-rerun/maxu/sbw-$sbw", @maxus); 	
	}
}

# vary numblocks; figure 10;
sub RunBlocks {
    my ($cmd, $outdir, @blocks) = @_;
    $outdir = "data/$outdir";
    
    chdir($TOPDIR);
    foreach my $b (@blocks) {
        my $blocksize = 819200 / $b;
        
		my $fodir = "$outdir/blocks-$b";
		my $fcmd = "$cmd -b $blocksize -o $fodir/default.out";

		doit($fodir, $fcmd);
    }
}

if (0) {
	my %settings = ('iris-d-04', [ 200, 512, 400, 320, 200, 100, 50 ],
			'iris-d-05', [ 1000, 512, 400, 320, 200 ], 
			'iris-d-06', [ 1000, 100, 50 ]);

	foreach my $mach (keys %settings) {
		my $aref = $settings{$mach};
		my $nodes = shift @$aref;
		my $jointime = $nodes / 100;
		my $args = "$homog_args -j $jointime";

		$OUTPUT_REDIR = "$DATADIR/$mach.progress";
		rsystem_opts(0, 1, $USER, $mach, \&RunBlocks, "$PROG $args", 
				"2001-rerun/numblocks/nodes-$nodes", @$aref); 	
	}
}

# heterogeneity; figures 12, 13 and 14; 
# run for several values of 'd'. We already have data for d=5 and d=40.
# therefore, we now run for d=13 and d=27
if (0) {
	my %settings = ('iris-d-02', [ 'bt-heterog/d-20', ' -d 13 ' ],
			'iris-d-03', [ 'bt-ibw/d-20', '-ibw -d 13 ' ], 
			'iris-d-04', [ 'bt-heterog/d-40', ' -d 27 ' ], 
			'iris-d-05', [ 'bt-ibw/d-40', '-ibw -d 27 ' ], 
			);

	my @sbws = (6000, 3000, 1500, 800, 400);

	foreach my $mach (keys %settings) {
		my $aref = $settings{$mach};
		my $dir = $aref->[0];
		my $args = "$hetero_args -bw '6000:3000:0.33 1500:400:0.33 784:128:0.34' -smartseed -nsu " . $aref->[1];

		$OUTPUT_REDIR = "$DATADIR/$mach.progress";
		rsystem_opts(0, 1, $USER, $mach, \&RunSeedsBw, "$PROG $args ", "2001-rerun/$dir", @sbws);
	}
}

sub RunTFT
{
	my ($cmd, $outdir, @fths) = @_;
	$outdir = "data/$outdir";

	chdir($TOPDIR);
	my @sbws = (6000, 3000, 1500, 800, 400);
	foreach my $sbw (@sbws) 
	{
		foreach my $th (@fths) {
			my $fodir = "$outdir/sbw-$sbw/fth-$th";
			my $fcmd = "$cmd -sbw $sbw -fth $th -o $fodir/default.out";

			doit($fodir, $fcmd);
		}
	}
}

if (0) {
	my %settings = ('iris-d-02', [ 'pairtft/d-20', "-d 13", 1 ],
			'iris-d-03', [ 'pairtft/d-20', "-d 13", 2],
			'iris-d-04', [ 'pairtft/d-40', "-d 27", 1],
			'iris-d-05', [ 'pairtft/d-40', "-d 27", 2],
			
			);

	foreach my $mach (keys %settings) {
		my $dir = $settings{$mach}->[0];
		my $earg = $settings{$mach}->[1];
		my $fth = $settings{$mach}->[2];
		
		my $args = "$hetero_args -bw '6000:3000:0.33 1500:400:0.33 784:128:0.34' -smartseed -nsu $earg -pairtft ";

		$OUTPUT_REDIR = "$DATADIR/$mach.progress";
		rsystem_opts(0, 1, $USER, $mach, \&RunTFT, "$PROG $args ", "2001-rerun/$dir", $fth);
	}
}

# next to tracker-matches-bandwidth results
sub RunSeedsBwWithD {
    my ($cmd, $outdir, @seedbws) = @_;
    $outdir = "data/$outdir";
    
    chdir($TOPDIR);
	my %h = (5, 7, 13, 20, 27, 40, 40, 60);
	foreach my $d (keys %h) {
		my $od = $h{$d};
		foreach my $sbw (@seedbws) {
			my $fodir = "$outdir/d-$od/sbw-$sbw";
			my $fcmd = "$cmd -d $d -sbw $sbw -o $fodir/default.out";
			
			doit($fodir, $fcmd);
		}
	}
}

if (0) {
	my %settings = ('iris-d-02', [ 'bt-heterog', '', 6000, 3000, 1500 ],
			'iris-d-03', [ 'bt-heterog', '', 800, 400 ],
			'iris-d-04', [ 'bt-ibw', '-ibw', 6000, 3000, 1500 ], 
			'iris-d-05', [ 'bt-ibw', '-ibw', 800, 400 ], 
			);

	foreach my $mach (keys %settings) {
		my $aref = $settings{$mach};
		my $dir = shift @$aref;
		my $earg = shift @$aref;
		my @sbws = @$aref;
		my $args = "$hetero_args -tmb -bw '6000:3000:0.33 1500:400:0.33 784:128:0.34' -smartseed -nsu $earg";

		$OUTPUT_REDIR = "$DATADIR/$mach.progress";
		rsystem_opts(0, 1, $USER, $mach, \&RunSeedsBwWithD, "$PROG $args ", "2001-rerun/venkat-tmb/$dir", @sbws);
	}

}

sub RunTFTWithD {
	my ($cmd, $outdir, $fth, @sbws) = @_;
	$outdir = "data/$outdir";

	chdir($TOPDIR);
	my %h = (5, 7, 13, 20, 27, 40, 40, 60);
	foreach my $d (keys %h) {
		my $od = $h{$d};
		foreach my $sbw (@sbws) 
		{
			my $fodir = "$outdir/d-$od/sbw-$sbw/fth-$fth";
			my $fcmd = "$cmd -d $d -sbw $sbw -fth $fth -o $fodir/default.out";

			doit($fodir, $fcmd);
		}
	}
}

if (0) {
# 	my %settings = ('iris-d-02', [ 1, 6000, 3000, 1500 ],
# 			'iris-d-03', [ 1, 800, 400 ],
# 			'iris-d-04', [ 2, 6000, 3000, 1500 ], 
# 			'iris-d-05', [ 2, 800, 400 ], 
# 			);
# 
	my %settings = (
			'iris-d-06', [ 2, 6000, 3000, 1500 ], 
			'iris-d-07', [ 2, 800, 400 ], 
			);
	foreach my $mach (keys %settings) {
		my $aref = $settings{$mach};
		my $fth = shift @$aref;
		my @sbws = @$aref;
		my $args = "$hetero_args -tmb -pairtft -bw '6000:3000:0.33 1500:400:0.33 784:128:0.34' -smartseed -nsu ";

		$OUTPUT_REDIR = "$DATADIR/$mach.progress";
		rsystem_opts(0, 1, $USER, $mach, \&RunTFTWithD, "$PROG $args ", "2001-rerun/venkat-tmb/pairtft", $fth, @sbws);
	}

}

sub RunD
{
    my ($cmd, $outdir, %h) = @_;
    $outdir = "data/$outdir";
    
    chdir($TOPDIR);
	foreach my $d (keys %h) {
		my $od = $h{$d};
		my $fodir = "$outdir/d-$od";
		my $fcmd = "$cmd -d $d -o $fodir/default.out";

		doit($fodir, $fcmd);
	}
}

if (0) {
	my %settings = ('iris-d-05', [ 5, 7, 13, 20 ], 'iris-d-06', [ 27, 40, 40, 60 ]);
	foreach my $mach (keys %settings) {
		my $aref = $settings{$mach};
		$OUTPUT_REDIR = "/home/mercury/msr/data/$mach.progress";
		rsystem_opts(0, 1, $USER, $mach, \&RunD,  "$PROG $homog_args -sbw 6000 -nwb 200/85/1499:400 ",
				"2001-rerun/nwb-d/sbw-6000", @$aref);
	}

}

# premature seed departure
if (0) {
    my @machines = ('iris-d-02', 'iris-d-03', 'iris-d-04');
    my $run = 1;
    
	foreach my $mach (@machines) {
		$OUTPUT_REDIR = "/home/mercury/msr/data/$mach.progress";

		rsystem_opts(0, 1, $USER, $mach, \&RunSeedsBw, 	"$PROG $hetero_args $bw_hetero -smartseed -nsu -originload 1.02", 
				"2001-rerun/seed-leaves/heterog/run-$run", 
				1500, 800, 400);
		$run++;
	}
}

if (0) {
    my @machines = ('iris-d-05', 'iris-d-06', 'iris-d-07');
    my $run = 1;
    
	foreach my $mach (@machines) {
		$OUTPUT_REDIR = "/home/mercury/msr/data/$mach.progress";

		rsystem_opts(0, 1, $USER, $mach, \&RunSeedsBw, 	"$PROG $homog_args -smartseed -nsu -originload 1.02", 
				"2001-rerun/seed-leaves/homog/run-$run", 
				600, 400, 200);
		$run++;
	}
}

if (1) {
    my @machines = ('iris-d-02', 'iris-d-03', 'iris-d-04');
    my $run = 1;
    
	foreach my $mach (@machines) {
		$OUTPUT_REDIR = "/home/mercury/msr/data/$mach.progress";

		rsystem_opts(0, 1, $USER, $mach, \&RunSeedsBw, 	"$PROG $hetero_args $bw_hetero -slp 0.0 -sfb 2 -smartseed -nsu -originload 1.02", 
				"2001-rerun/seed-leaves-nodestay/heterog/run-$run", 
				1500, 800, 400);
		$run++;
	}
}

if (1) {
    my @machines = ('iris-d-05', 'iris-d-06', 'iris-d-07');
    my $run = 1;
    
	foreach my $mach (@machines) {
		$OUTPUT_REDIR = "/home/mercury/msr/data/$mach.progress";

		rsystem_opts(0, 1, $USER, $mach, \&RunSeedsBw, 	"$PROG $homog_args -slp 0.0 -sfb 2 -smartseed -nsu -originload 1.02", 
				"2001-rerun/seed-leaves-nodestay/homog/run-$run", 
				600, 400, 200);
		$run++;
	}
}
