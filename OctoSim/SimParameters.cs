using System;
using System.Collections;
using System.IO;

namespace Simulator
{
    // we dont use the staytime model really since 
    // node lifetimes are determined by download 
    // performance and altruistic behavior
    public enum StayTimeModel 
    {
	UNIFORM_STAYTIME,
	PARETO_STAYTIME,
	FROMTRACE_STAYTIME 
    }

    public enum FairnessMechanism
    {
	BITTORRENT_TFT,                      // normal bit-torrent fairness mechanism
	OVERALL_BLOCK_TFT,                   // just keep a count of the total #bytes across all connections
	PAIRWISE_BLOCK_TFT,                  // keep track of #bytes with each peer
    }

    public enum ChoosingPolicy
    {
	LR,

	// random permutation fixes the random order of elements 
	// to pick when a node starts. this ensures that several
	// "unfinished" blocks are not created. (otherwise, a node
	// A can request block 1, get half of it, have its connection 
	// choke, request another random block 'k', get half of it
	// and so on.)
	
	RAND_PERMUTATION
    }

    public class SimParameters
    {
	public static float EPSILON = 0.000001f;
	//////////////////////////////////////////////////////////////////////////
	/// "Generic" simulation parameters
	/// 
	public static bool useDeterministicPseudoRandomness = false;
	public static long printInterval = 2000;              // milliseconds; print statistics every so often in the trace
	public static long graphPrintInterval = 100000;       // milliseconds; print the connectivity graph every so often
	public static string outputFile = "default.out";      // the file where simulation output is sent

	//////////////////////////////////////////////////////////////////////////
	/// "Parameters" to the simulation model, independent of the file
	/// delivery network or protocol used.
	/// 
	public static double lossRate = 0.01;                // we use the TCP throughput equation to 
	                                                     // model transfer time on a 
	                                                     // link with this loss rate. Except
							     // that we dont use the TCP equation or
							     // model loss rate in any way at all!!:)

	public static long   simulationTime = 700 * 1000;    // the time (milliseconds) for which the simulation continues
	public static long   joinTime = 700 * 1000;          // the time (milliseconds) for which nodes continue coming into the 
	                                                     // system (not used by current simulator, IIRC) 

	public static SortedList bwProbabilities = new SortedList(new LinkCapComparer());
	                                                     // this list contains the relative
							     // proportions of different "classes"
							     // of nodes (DSL, cable, etc.)

	public static float joinRate = 2;                    // joins per second; in a flash-crowd, this would be much larger
	public static bool  forceKills = false;              // if true, we make nodes leave according to the staytime model or trace 
	public static StayTimeModel stayTimeModel = StayTimeModel.UNIFORM_STAYTIME;  // NOT USED
	public static string stayTimeParams = "uniform:200:400"; // this param string can change depending on the distribution
	public static long oracleInterval = 1000;            // NOT USED

	//////////////////////////////////////////////////////////////////////////
	/// BitTorrent specific parameters
	/// 
	public static int fileSize = 100 * 1024 * 8;               // size (kilo bits) of the file to be transferred
	public static int blockSize = 256 * 8;                     // size (kilo bits) of each block of the file
	public static long blockSizeInBits = blockSize << 10;      // size in bits... 
	public static int rarestFirstCutoff = 1;                   // how many pieces to get in "random" mode first. 
	                                                           // after these many pieces are
								   // received, mode changes to LR.

	public static double seedLeavingProbability = 0.2;         // this is an ill-defined parameter. usually, we set 
	                                                           // it to "zero" => all nodes
								   // leave immediately after
								   // completing downloads.

	public static int stayForBlocks = 0;                       // if used, this would say "stay as a seed until you serve"
	                                                           // these many blocks 
								   
	public static int maxUploads = 5;                          // max# of concurrent uploads that can be going on. 
	                                                           // min=1 (optimistic unchoke)
								   
	public static int chokerInterval = 10000;                  // invoke the bittorrent choker every these many milliseconds
	public static int nInitialPeers = 40;                      // number of peers to return when the node first asks; 
	                                                           // in the paper, (d =~ 1.5 * nInitialPeers)

	public static int minPeersThreshold;                       // re-request when #peers falls below this
	public static int maxPeersThreshold;                       // re-request when #peers falls below this
	public static int nRefreshPeers;                           // number of peers to return when a node re-requests

	                  // (the above parameters are generated from nInitialPeers)
			
	// the following have to do with estimating the upload/download rates of peers you are
	// transferring data to/from
	public static int nRateSamples = 30;                       // estimate the upload/download rate of peers using last 'k' samples
	public static long rateWindow  = 20000;                    // window length (milliseconds)
	public static long rateFudge   = 5000;                     // when starting the measurement...

	public static int nInitialSeeds = 1;                       // #seeds to start with initially
	public static int seedBandwidth = 3000;                    // seed upload capacity (in kbps)
	public static bool smartSeed = false;                      // should the seed act smart? refer paper for 'smartseed' policy.
	public static bool noSeedUnfinished = false;               // should the seed NOT have unfinished transfers? normally, 'smartseed' implies this

	public static float FEC = 1.0f;                            // FEC = k ==> "make" k times as many unique packets
	public static bool trackerMatchesBws = false;              // should the tracker be bandwidth-aware in giving out nodes?

	public static bool measureBWinstantenously = false;                  // should we measure bandwidth instaneously? 
	public static FairnessMechanism fairness = FairnessMechanism.BITTORRENT_TFT;    // default BitTorrent Tit-for-tat
	public static bool spPairwiseTFT = false;                            // do pairwise tft within the choker... (unclear what this does :)
	public static bool doOptUnchoke = true;                    // disable/enable optimistic unchoke in BitTorrent.
	                                                           // careful: one must employ some
								   // other bootstrapping mechanism
								   // as well in this case.

	public static int  fairnessThreshold = 2;                  // number of blocks a connection can be off by (in pairwise/group TFT)
	public static int  nInitialBlocks = 0;                     // #blocks a node is "given" when joining the system
	public static ChoosingPolicy choosingPolicy = ChoosingPolicy.LR;     // block choosing policy

	//////////////////////////////////////////////////////////////////////////
	/// Funkier simulation parameters

	// this is for the situation when nodes which are "pre-seeded" with blocks
	// are injected into the system. Refer Section 5.5.1 (second subsection) of MSR-TR-2005-03.
	public static bool nwbOn     = false;                      // insert nodes with blocks 
	public static int  nwbPeriod = 300000;                     // how often to insert?
	public static float  nwbBlocksPercentage = 85;             // how many blocks should these nodes prepossess?
	public static LinkCap nwbLinkCap = null;                   // link capacity of these nodes

	/// Post-flash-crowd stuff. Refer Section 5.5.1 (first subsection) of MSR-TR-2005-03.
	public static long pfcOffset = -1;                         // start injecting nodes after these many milliseconds
	public static long pfcEndTime = -1;                        // no more nodes to inject after this time. 
	public static long pfcInterval = -1;                       // insert batch every these many milliseconds
	public static int  pfcBatchSize = -1;                      // size of each batch
	public static LinkCap pfcLinkCap = null;                   // link capacity of inserted nodes

	//////////////////////////////////////////////////////////////////////////
	/// When the seed leaves
	public static float originServerLoad = -1;                 // maximum #file copies to serve. After serving these many blocks, 
	                                                           // the seed will go offline.
	
	//////////////////////////////////////////////////////////////////////////
	/// Misc
	public static bool doHackyHashReplacement = false;         // HACK: to increase speed of the simulator at the cost of 
	                                                           // some increased memory utilization
								   // and hard-coded constraints on
								   // #nodes, etc. Refer to
								   // Connection.cs and Node.cs for details. 
								   // Basically, hashtables in C#
								   // are PAINFULLY SLOW. never ever
								   // depend on them for speed.

	//////////////////////////////////////////////////////////////////////////
	/// Logging parameters 
	public static long utilDumpInterval = printInterval;       // how often to print node utilization.


	/// <summary>
	/// computes dependent parameters from the parameters which might 
	/// have been provided...
	/// </summary>
	public static void GenerateDependents() 
	{
	    SimParameters.minPeersThreshold = (int) (SimParameters.nInitialPeers - 2);
	    SimParameters.nRefreshPeers = (int) 6/* (SimParameters.nInitialPeers / 1.5) */;
	    SimParameters.maxPeersThreshold = (int) (SimParameters.nInitialPeers * 2);

	    SimParameters.blockSizeInBits = SimParameters.blockSize << 10;
	    if (fairness == FairnessMechanism.BITTORRENT_TFT && !doOptUnchoke && nInitialBlocks == 0)
	    {
		Logger.warn("opt unchoke is FALSE and initial blocks is 0 -- fixing initial blocks to 5");
		nInitialBlocks = 5; 
	    }

	    utilDumpInterval = printInterval;
	}

	public static bool DoingBlockTFT() 
	{
	    return fairness != FairnessMechanism.BITTORRENT_TFT;
	}

	public static void PrintAll()
	{
	    TeeWriter stream = new TeeWriter(SimParameters.outputFile + ".prm");

	    stream.WriteLine("Simulation parameters are: ");
	    stream.WriteLine("-------------------------------------------------------");
	    stream.WriteLine("print interval: {0} milliseconds", printInterval);
	    // stream.WriteLine("Loss rate: " + lossRate);
	    stream.WriteLine("MAX_NODES: " + Node.MAX_NODES);
	    stream.WriteLine("Deterministically pseudo random: " + useDeterministicPseudoRandomness);
	    stream.WriteLine("Output file: " + outputFile);
	    stream.WriteLine("Simulation Time: {0} seconds", (int) (simulationTime/1000));
	    stream.WriteLine("-------------------------------------------------------");
	    stream.WriteLine("Join Time: {0} seconds",(int) (joinTime/1000));
	    stream.WriteLine("Join rate: " + joinRate + " per second");
	    stream.WriteLine("Seed leaving probability: " + seedLeavingProbability);
	    stream.WriteLine("Stay for blocks: " + stayForBlocks);
	    stream.WriteLine("#seeds: " + nInitialSeeds);
	    stream.WriteLine("Seed bandwidth: " + seedBandwidth);
	    stream.WriteLine("Smart seed: " + smartSeed);
	    stream.WriteLine("No unfinished blocks from seed: " + noSeedUnfinished);
	    stream.WriteLine("Node bandwidth distribution: ");
	    foreach (LinkCap lc in bwProbabilities.Keys) {
		stream.WriteLine("\tDown: {0}kbps, Up: {1}kbps\tProbability = {2}", lc.down_bw, lc.up_bw, (double) bwProbabilities[lc]);
	    }
	    //stream.WriteLine("Stay time model: " + stayTimeModel);
	    //stream.WriteLine("Stay time params: " + stayTimeParams);
	    //stream.WriteLine("Print interval: " + printInterval);
	    stream.WriteLine("=======================================================");
	    stream.WriteLine("File size: {0} KB", fileSize/8);
	    stream.WriteLine("Block size: {0} KB", blockSize/8);
	    stream.WriteLine("Max #uploads: " + maxUploads);
	    stream.WriteLine("#Initial peers: " + nInitialPeers);
	    stream.WriteLine("min #peers = {0}, max #peers = {1}", minPeersThreshold, maxPeersThreshold);
	    stream.WriteLine("Rate window: " + rateWindow + " milliseconds");
	    stream.WriteLine("Choker interval: " + chokerInterval + " milliseconds");
	    stream.WriteLine("FEC: " + FEC);
	    stream.WriteLine("Tracker matches bandwidths: " + trackerMatchesBws);
	    stream.WriteLine("-------------------------------------------------------");
	    stream.WriteLine("instantenous bandwidth measurement: " + measureBWinstantenously);
	    stream.WriteLine("fairness mechanism: " + fairness);
	    stream.WriteLine("special pairwise TFT: " + spPairwiseTFT);
	    stream.WriteLine("optimistic unchoke: " + doOptUnchoke);
	    stream.WriteLine("fairness threshold: " + fairnessThreshold + " blocks");
	    stream.WriteLine("#initial blocks at node: " + nInitialBlocks);
	    stream.WriteLine("Rarest first cutoff: " + rarestFirstCutoff);
	    stream.WriteLine("choosing policy: " + choosingPolicy);
	    stream.WriteLine("=======================================================");

	    stream.WriteLine("node-with-block: " + nwbOn);
	    if (nwbOn) {
		stream.WriteLine("nwbPeriod: " + (int) (nwbPeriod / 1000) + " seconds" ); 
		stream.WriteLine("nwb blocks percentage: " + nwbBlocksPercentage);
		stream.WriteLine("nwb link capacity: down: {0}kbps, Up: {1}kbps", nwbLinkCap.down_bw, nwbLinkCap.up_bw);
	    }
	    stream.WriteLine("=======================================================");

	    if (pfcOffset > 0) {
		stream.WriteLine("Post-flash-crowd offset: " + (pfcOffset/1000) + " seconds ");
		stream.WriteLine("Post-flash-crowd interval: " + (pfcInterval/1000) + " seconds" );
		stream.WriteLine("Post-flash-crowd endtime: " + (pfcEndTime/1000) + " seconds ");
		stream.WriteLine("Post-flash-crowd batch size: " + pfcBatchSize);
		stream.WriteLine("PFC link capacity: down: {0}kbps, Up: {1}kbps", pfcLinkCap.down_bw, pfcLinkCap.up_bw);
		stream.WriteLine("=======================================================");
	    }

	    stream.WriteLine("origin server load: " + originServerLoad);

	    stream.Flush();
	    stream.Close();
	}
    }

    public class TeeWriter : StreamWriter {
	public TeeWriter (string file) : base (file, false) {
	}

	public override void WriteLine (string value)
	{
	    base.WriteLine (value);
	    Console.WriteLine (value);
	}

	public override void WriteLine (string format, params object[] arg)
	{
	    base.WriteLine (format, arg);
	    Console.WriteLine (format, arg);
	}
    }
}
