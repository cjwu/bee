require "inc.pl";

# the particular workload file (Homog.wl) in this case, doesn't really matter
# we override all the parameteres on the command line anyway! :-)

# Run a bunch of experiments for a heterogeneous flash-crowd setting.
#

$cmd = "../OctoSim.exe -w Homog.wl -t 10000 -rnd r -maxu 5";
$cmd = $cmd . " -sbw %s -fec 1 -bw '%s' -fsize 819200 -jr 100 -j %d -d 20 -o %s";

$basedir = "test-heterogeneity";
mkdir($basedir);

%mechanisms = ('bt-noibw', '',
	       'bt-ibw',   '-ibw',
	       'pairtft',  '-pairtft -fth 2',
	       'grouptft', '-grouptft -fth 40');

%compositions = ('cable-dsl', [3000, '1500:400:0.5 6000:3000:0.5' ],
	         'cable-slowdsl', [3000, '784:128:0.5 6000:3000:0.5' ],
		 'cable-slowdsl-superseed', [100000, '784:128:0.5 6000:3000:0.5' ],		 
	         'all', [100000, '784:128:0.45 1500:400:0.25 6000:3000:0.2 100000:100000:0.1'],
	);

chomp ($pwd = `pwd`);

$PRINT_ONLY = 0;

foreach $comp (keys %compositions)
{	    
    foreach $jointime (2, 6, 10)
    {
	foreach $mech (keys %mechanisms)
	{
	    $nnodes = 100 * $jointime;

	    $sbw = $compositions{$comp}->[0];
	    $bw = $compositions{$comp}->[1];

	    $odir = "$basedir/$comp/nodes-$nnodes";
	    $odir .= "/mechanism-$mech";
	    psystem("mkdir -p $odir");

	    $act_cmd = sprintf($cmd, $sbw, $bw, $jointime, "$odir/out");
	    $act_cmd .= " $mechanisms{$mech}";
	    psystem($act_cmd);
	    psystem("perl scripts/doall.pl $odir/out");
	}
    }
}
