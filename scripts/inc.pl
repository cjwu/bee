$apath = $ENV{PERL5LIB};
chop $apath if ($apath =~ /\/$/) ;
    
@array = split(/\//, $apath);
pop @array; 

$path = join "/", @array;
#$path = "/home/t-ashbha/sim";

our $PRINT_ONLY;
$PRINT_ONLY = 0;

sub psystem {
    my $cmd = shift;
    print STDERR "$cmd\n";
    return if ($PRINT_ONLY);

    return system($cmd);
}

our $GRAPHTYPE = "eps";

1;
