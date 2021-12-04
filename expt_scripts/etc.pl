require "inc.pl";

### Max uploads effect

$cmd = "../OctoSim.exe -w Homog.wl -t 5000 -rnd r -maxu %d";
$cmd = $cmd . " -sbw 2000 -fec 1 -bw '1500:400:1.0' -fsize 819200 -jr 100 -j 5 -d 20 -o %s";

$basedir = "test-max-uploads-effect";
mkdir($basedir);

$PRINT_ONLY = 0;

foreach $maxu (2, 5, 8, 10)
{
    $odir = "$basedir/maxu-$maxu";
    psystem("mkdir -p $odir");

    $act_cmd = sprintf($cmd, $maxu, "$odir/out");
    psystem($act_cmd);
    psystem("perl scripts/doall.pl $odir/out");
}

### Number of seeds effect in cases when the seed is a blocking point 
### and when the nodes bws are symmetrical (pablo's point)

$cmd = "../OctoSim.exe -w Homog.wl -t 5000 -rnd r -maxu 5 -seeds %d";
$cmd = $cmd . " -sbw %s -fec 1 -bw '%s:400:1.0' -fsize 819200 -jr 100 -j 5 -d 20 -o %s";

$basedir = "test-nseeds";
mkdir($basedir);

%configs = ('slowseed', [400, 1500], 
	    'slownodes', [1500, 400],
	    'bothslow',  [400, 400]);

foreach $nseeds (1, 2, 3, 4, 5)
{
    foreach $conf (keys %configs)
    {
	$odir = "$basedir/$conf/nseeds-$nseeds";
	
	$sbw = $configs{$conf}->[0];
	$nbw = $configs{$conf}->[1];
	
	psystem("mkdir -p $odir");

	$act_cmd = sprintf($cmd, $nseeds, $sbw, $nbw, "$odir/out");
	psystem($act_cmd);
	psystem("perl scripts/doall.pl $odir/out");
    }
}
