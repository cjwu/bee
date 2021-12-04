####################################################################
#
# This is a sample workload file. The format of each line is:
#  <time> <command> <command arguments> [end]
# The 'end' is sometimes optional (typically when the #args for 
# the command are apriori known to the simulator. 
#
#  'time' can be one of: 
#      "now" -- executes the command at the time the simulator reads it
#  +<offset> -- schedules the command after 'offset' milliseconds
#   <abstim> -- schedules the command at the absolute time in milliseconds
#
# <command>s are too far to comment here; please look at
# WorkloadProcessor.cs to see what all commands are permissible.
#
#####################################################################
# all times are in milliseconds
now setparam simulation_time 5000000 end 
now setparam join_time 500000 end
# format--  download:upload:probability, for each class. 
# Taken from Stefan Sariou's MMCN paper.
now setparam bw_model 56:56:0.2 784:128:0.25 1500:400:0.25 6000:3000:0.2 100000:100000:0.1 end
now setparam output default.out end
# now setparam jl_model trace end 
now setparam jl_model joinrate:2 staytime:uniform:100:200 end  # the staytime parameter is pretty much useless here...
# now setparam file_size 819200 end # in kilobits
now setparam file_size 819200 end # in kilobits
now setparam block_size 2048 end   # in kilobits; this is the default bittorrent block size
now setparam seed_leaving_prob 1.0 end
# let command line arguments override the defaults specified in this 
# file.. 
now process_cmdline_args end
now print_param end
now initialize end
# node join-leave trace...
#+421 node_birth live_for 3230823 end
#+700 node_birth live_for 2323434 end
#+10200 node_birth live_for 2323434 end
#+472 node_birth live_for 26654835 end
#+532 node_birth live_for 31905820 end
#+572 node_birth live_for 808165 end
#+652 node_birth live_for 18576910 end
#+692 node_birth live_for 6864875 end
#+732 node_birth live_for 14538170 end
#+892 node_birth live_for 31905820 end
now process till 90000000 end
