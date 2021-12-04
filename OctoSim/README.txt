OCTOSIM: A BitTorrent Simulator
-------------------------------

This release contains the code for the simulator which forms the 
basis of our paper:

  Ashwin Bharambe, Cormac Herley and Venkat Padmanabhan: 
  
    "Analyzing and Improving a BitTorrent Network's Performance Mechanisms"  
      IEEE INFOCOM 2006, Apr 23 - Apr 29, Barcelona, Spain.

Getting Started
---------------
Installation: 

 + On Linux, you must have mono (the CLR runtime) and mcs (mono C# compiler)
   installed. Visit http://www.mono-project.com/ to obtain that. For new
   distributions, it is also possible that pre-built binary packages will be
   available.
   
   To compile, just type "make" 
   
 + On Windows, open the .sln file in Visual Studio and build!

How to run:

Take a look at the perl scripts in ../scripts/ and ../cmu_scripts/, as well as 
workload files in ../workloads/.

Simulator Model
---------------
The simulator models the data plane of BitTorrent. Some details about
the model follow:

 - We model a file breaking down into a configurable number of pieces
   (blocks). Sub-pieces are not modeled. I suspect modeling those is
   akin to increasing the total number of pieces, however this may not
   be entirely true. 
 
 - BitTorrent's choking algorithm is implemented. Upload and download
   rate of nodes is measured exactly as in BitTorrent (running average). 
 
 - We do not model the end-game mode of BitTorrent. This mode is used
   for speculative downloading towards the end of the torrent so as to
   finish up the last few pieces even quicker. We believe it does not
   impact the overall performance characteristics of the protocol.

 - Only bandwidth modeling in the underlying topology is supported.
   In other words, it models queueing delays on links but does not model
   propagation delays. This is okay under some scenarios. We do not
   model bottlenecks inside the core network - only last-mile
   bottlenecks are modeled. Lastly, TCP dynamics are not modeled. It is
   assumed that flows use their fair-share (independent of the RTTs) of 
   the link bandwidth and that they do so instantenously after the
   addition or removal of flows.

 - We also model our enhancements to the BitTorrent protocol. These
   include FEC'ing seeded blocks, "smart seed" policy (see paper),
   block-level fairness algorithms (see paper), etc. Looking at
   SimParameters.cs can give a reasonable introduction to the parameters
   (and the corresponding features). 
   
Code Organization
------------------
A very brief description of the simulator code. Please refer to the code
directly for all the details. I will just try to give an overview of the
control flow here.

1) Main.cs: processes command line arguments, stores into array.

2) WorkloadProcessor.cs: reads workload file, interprets commands,
creates a simulator instance and starts the simulator "loop".

3) Sim.cs: simulator class; implements an event-queue and bandwidth
sensitive "fluid" flows.

4) ProtocolMain.cs: contains utility events and functions which drive
the simulation by injecting appropriate events at proper times.

5) Node.cs: this is the CORE of the entire system. See
Node.JoinNetwork(). This is where each node starts its life in the
system. All protocol operations start from JoinNetwork(). 

6) SimParameters.cs: list of most of the parameters accepted by the
simulator.

Why OCTOSIM?
------------
At some point, Octopus was chosen as a name for our new improved system. We
gave up on that name quickly but the simulator name stuck. :)

Support
-------
This is research quality code. Please do not expect it to have great
structure, comments, etc. despite our attempts to have them. That said,
please do let us know about any bugs that you may find (they exist, of
course!). Thanks, and we hope this is useful.

Authors
-------
 Ashwin R. Bharambe
 Cormac Herley
 Venkat Padmanabhan
