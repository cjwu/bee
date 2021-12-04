require "inc.pl";

$cmd = "../OctoSim.exe -w Homog.wl -t 5000 -rnd r -maxu 5";
$cmd = $cmd . " -sbw 2000 -fec %s -bw '1500:400:1.0' -fsize %s -jr 100 -j %d -d 20 -o %s";

$basedir = "test-BT-oufixed-diversity";
mkdir($basedir);

%policies = ('lr', '',
	     'random', '-r 1000',
	     'permute', '-permutations');

%filesizes = ('307200', '150blocks',
	      '819200', '400blocks', 
	      '102400', '50blocks');

chomp ($pwd = `pwd`);

$PRINT_ONLY = 0;

foreach $fec (1, 2)
{
    foreach $jointime (2, 6, 10)
    {
	foreach $filesize (keys %filesizes)
	{
	    foreach $policy (keys %policies)
	    {
		$nnodes = 100 * $jointime;
		$odir = "$basedir/fec-$fec/nodes-$nnodes";
		$odir .= "/filesize-$filesizes{$filesize}/policy-$policy";
		psystem("mkdir -p $odir");

		$act_cmd = sprintf($cmd, $fec, $filesize, $jointime, "$odir/out");
		$act_cmd .= " $policies{$policy}";
		psystem($act_cmd);
		psystem("perl scripts/doall.pl $odir/out");
	    }
	}
    }
}
