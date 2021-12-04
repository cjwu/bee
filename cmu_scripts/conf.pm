#
# Configuration
#

package conf;
require Exporter;
use strict;

our @ISA    = ("Exporter");
our @EXPORT = qw($VERSION $TOPDIR $CVSROOT
		 $PRINT_ONLY $INVOKE_XTERM $RUN_IN_BG $OUTPUT_REDIR
		 $SHOULD_SLEEP);

###############################################################################

our $CVSROOT = "$ENV{CVSUSER}\@humpback.cmcl.cs.cmu.edu:/usr0/backed_up/cvs";
our $VERSION = "1.0";
our $TOPDIR  = "/home/ashu/research/msr/simulator";
our $LOCAL_TOPDIR = 
    defined "$ENV{PUBSUB_DIR}" ? "$ENV{PUBSUB_DIR}" :
    "/home/ashu/research/pubsub";

our $PRINT_ONLY = 0;
our $INVOKE_XTERM = 1;
our $RUN_IN_BG    = 0;
our $OUTPUT_REDIR = "";
our $SHOULD_SLEEP = 1;

1;
