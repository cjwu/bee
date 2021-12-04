#
# inc.pl: use this file in all scripts 
# should define common routines, variables, etc.
#

use strict;
use Data::Dumper; 
use File::Temp qw/ :POSIX /;

$Data::Dumper::Deparse = 1;

# global scalars and funcs to export to remote node
our %GLOBAL_EXPORT = ( 'VERSION'       => $VERSION,
		       'TOPDIR'        => $TOPDIR,
		       'CVSROOT'       => $CVSROOT,
		       'PRINT_ONLY'    => $PRINT_ONLY,
		       'fancymsg'     => \&fancymsg,
		       'rerror'       => \&rerror,
			   'doit'         => \&doit,
		       'psystem'      => \&psystem );

#our %machines = (
#	"gs3078.sp.cs.cmu.edu", [ "jeffpang" ],
#	"gs203.sp.cs.cmu.edu",  [ "ashu" ] ,
#	"gs19.sp.cs.cmu.edu",   [    "manjhi" ],
#	"gs131.sp.cs.cmu.edu",  [    "mukesh" ],
#	"humpback.cmcl.cs.cmu.edu",  [ "ashu" ],
#	"great-white.cmcl.cs.cmu.edu", [ "ashu" ],
#	"iris-d-06.cmcl.cs.cmu.edu", [ "sknath" ],
#	"iris-d-07.cmcl.cs.cmu.edu", [ "sknath" ],
#	"iris-d-08.cmcl.cs.cmu.edu", [ "sknath" ],
#	"iris-d-10.cmcl.cs.cmu.edu", [ "sknath" ],
#	"gs3107.sp.cs.cmu.edu", [ "jweisz" ], 
#	);

sub doit {
	my ($fodir, $fcmd) = @_;
	psystem("mkdir -p $fodir");
	psystem("$fcmd");
	psystem("rm -f *.gz");
	psystem("gzip --force $fodir/default.out.*");
	psystem("perl /home/mercury/msr/data/DoallAll.pl \$PWD $fodir");
	psystem("rsync -az $TOPDIR/data/ /home/mercury/msr/data/");
}

sub psystem {
    print STDERR $_[0], "\n";
    return if ($PRINT_ONLY);
    return system($_[0]);
};

sub rerror {
    my $msg = shift;
    our $node;

    print STDERR "\n[31mERROR @ [35m$node[m: $msg\n";
    sleep(500);
    exit 4;
}

sub fancymsg {
    my $msg = shift;
    our $node;

    print STDERR "\n[34mMSG @ [35m$node[m: $msg\n";
    exit 4;
}

sub xtermexec {
    my $title = "";
    if ($#_ > 0) {
	$title = shift;
	$title = "-T \"$title\"";
    }

    # Hackery to force TTY allocation on remote shells
    $_[0] =~ s/ssh /ssh -t /;

    if ($SHOULD_SLEEP) {
	psystem("xterm $title -e sh -c \"$_[0]; sleep 1000 \" &");
    }
    else {
	psystem("xterm $title -e sh -c \"$_[0]; \" &");
    }
}

#
# rsystem with options of running in bg or using xterm
#
# usage: rsystem_opts($xterm, $run_in_bg, rsystem_options...)
#
sub rsystem_opts
{
    my $xterm     = shift;
    my $run_in_bg = shift;

    my $OLD_XTERM = $INVOKE_XTERM;
    my $OLD_RUNINBG = $RUN_IN_BG;

    $INVOKE_XTERM = $xterm;
    $RUN_IN_BG = $run_in_bg;

    rsystem(@_);

    $INVOKE_XTERM = $OLD_XTERM;
    $RUN_IN_BG = $OLD_RUNINBG;
}

#sub test_machines {
#    foreach my $mach (keys %machines) {
         # run ssh; see if it times out.. 
#    }
#}

## 
## instead of copying the file, one can do the following also:
##
##    open F, " | ssh node perl | ";
##    print F <serialized subroutine>;
##    @result = <F>;
##    close F;
##   
##   the script will send the output to a special channel... you can marshal that as well, i think
##   this basically becomes a SSH tunnel for a simplistic perl RPC! Nice :)  - Ashwin [05/19]
##   of course, there are many limitations since the serialization and deserialization is hooky...
##   but then you save the headaches of stubs at both ends, etc...
##
sub rsystem 
{
    my ($user, $node, $sub_ref, @args) = @_;
    if (!$user || !$node || !$sub_ref) {
	die "rsystem usage: rsystem(\$user, \$node, \$sub_ref, \@args)\n";
    }

    my @keys = keys %GLOBAL_EXPORT;
    my @vals = map { $GLOBAL_EXPORT{$_} } @keys;

    push @keys, 'node';
    push @keys, 'func';

    push @vals, $node;
    push @vals, $sub_ref;

    my $d = Data::Dumper->new(\@vals, \@keys);
    my $file =  tmpnam();
    open F, ">$file";
    print F $d->Dump;
    for (my $i=0; $i<@keys; $i++) {
	if (ref($vals[$i]) eq 'CODE') {
	    print F "sub $keys[$i] { \$main::$keys[$i]\->(\@_) }\n";
	}
    }

    if ($RUN_IN_BG) {
	my $pid = fork();
	if ($pid > 0) {
	    # return in the parent so we don't want for the ssh connection
	    return $pid;
	} elsif (!defined $pid) {
	    die "fork() failed!";
	}

	my $redirect_out = "/dev/null";
	if ($OUTPUT_REDIR ne '') {
	    $redirect_out = $OUTPUT_REDIR;
	}

	# close I/O and detach a child process to do the rest
	print F <<EOT;

use IO::Handle;
use IO::File;

# my \$pid = fork();
# if (\$pid > 0) { exit(0); } 
# elsif (!defined \$pid) { die "fork() failed: \$!"; }

\$SIG{HUP} = 'IGNORE';
	
my \$out = IO::File->new(">$redirect_out");
# close STDIN;
STDOUT->fdopen(\$out, 'w');
STDERR->fdopen(\$out, 'w');

EOT
    }
    
    my @argnames = (); 
    for (my $i = 0; $i <= $#args; $i++) {
	push @argnames, "arg_$i";
    }
    $d = Data::Dumper->new(\@args, \@argnames);
    print F $d->Dump;
    print F 'my $value = &$func(';
    foreach my $name (@argnames) { $name = "\$$name"; }
    print F join(", ", @argnames);
    print F ");\n";
    #print F "unlink '$file.pl';\n"; # delete myself
    print F "print \" ----------- done ------------\n\";";
    print F "exit \$value\n";
    close F;

     -f $file or warn " BAD BAD BAD ::: File $file not there?? \n";
    select(undef, undef, undef, 0.25);
		     
    
    my $cmd;
    if (!$RUN_IN_BG) {
	psystem("scp $file $user\@$node:$file.pl") and 
	    die "scp to $node failed";
	$cmd = "ssh -oStrictHostKeyChecking=no -oForwardX11=no $user\@$node perl $file.pl";
    } else {
	$cmd = "cat $file | ssh -oStrictHostKeyChecking=no -oForwardX11=no $user\@$node perl";
    }
    
    if ($INVOKE_XTERM) {
	xtermexec($node, $cmd) and die ("error executing function \@ $node");
    }
    else {
	psystem($cmd) and die ("error executing function \@ $node");
    }

    #unlink $file;

    if ($RUN_IN_BG) {
	# already returned in parent
	exit(0);
    }
    
    return 0; # done running
}

1;
