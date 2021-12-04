using System;
using System.IO;  
using System.Collections;
using System.Diagnostics;

namespace Simulator
{
    /// <summary>
    /// This is the just a wrapper class around the 'Main' method for the project	
    /// </summary>
    public class MainWrapper 
    {
	// We collect all (most) parameters passed on cmd line 
	// into an arraylist which is processed at a later time
	// as instructed by the workload file. 
	//
	// The setup allows us to set most common arguments in 
	// the workload file and then override the mostly 
	// changing arguments by using command line options.

	public static ArrayList cmdline_arguments = new ArrayList();

        public static int Main(String[] args)
        {
            Console.WriteLine("-------------------------start of run-------------------------");
            string workload_file = "..\\..\\..\\Workloads\\Sample.wl";

            int index = 0;
            while (index < args.Length) 
            {
                switch (args[index]) 
                {
                    case "-w":
                        workload_file = args[++index];
                    break;
                    case "-o":
                        cmdline_arguments.Add("now setparam output " + args[++index] + " end");
                    break;
                    case "-t":
                        cmdline_arguments.Add("now setparam simulation_time " + (long.Parse(args[++index]) * 1000)  + " end");
                    break;
                    case "-j":
                        cmdline_arguments.Add("now setparam join_time " + (long.Parse(args[++index]) * 1000) + " end");
                    break;
                    case "-jr":
                        cmdline_arguments.Add("now setparam jl_model joinrate:" + float.Parse(args[++index]) + " staytime:uniform:100:300 end");
                    break;
                    case "-slp":
                        cmdline_arguments.Add("now setparam seed_leaving_prob " + args[++index] + " end");
                    break;
					case "-sfb":
					SimParameters.stayForBlocks = int.Parse(args[++index]);
					break;
                    case "-rnd":
                        if (args[++index].Equals("d")) 
                            SimParameters.useDeterministicPseudoRandomness = true;
                        else
                            SimParameters.useDeterministicPseudoRandomness = false;
                    break;
                    case "-maxu":
                        SimParameters.maxUploads = int.Parse(args[++index]);
                    break;
                    case "-b":
                        cmdline_arguments.Add("now setparam block_size " + args[++index] + " end");
                    break;
                    case "-c":
                        SimParameters.chokerInterval = int.Parse(args[++index]) * 1000;
                    break;
                    case "-r":
                        SimParameters.rarestFirstCutoff = int.Parse(args[++index]);
                    break;
                    case "-sbw":
                        cmdline_arguments.Add("now setparam seed_bw " + args[++index] + " end");
                    break;
                    case "-fec":
                        SimParameters.FEC = float.Parse(args[++index]);
                    break;
                    case "-fsize":
                        cmdline_arguments.Add("now setparam file_size " + args[++index] + " end");
                    break;
                    case "-d":
                        SimParameters.nInitialPeers = int.Parse(args[++index]);
                    break;
                    case "-bw":
                        cmdline_arguments.Add("now setparam bw_model " + args[++index] +  " end" );
                    break;
                    case "-ibw":
                        SimParameters.measureBWinstantenously = true;
                    break;
                    case "-nou":
                        SimParameters.doOptUnchoke = false;
                    break;
                    case "-pairtft":
                        SimParameters.fairness = FairnessMechanism.PAIRWISE_BLOCK_TFT;
                    break;
                    case "-grouptft":
                        SimParameters.fairness = FairnessMechanism.OVERALL_BLOCK_TFT;
                    break;
                    case "-fth":
                        SimParameters.fairnessThreshold = int.Parse(args[++index]);
                    break;
                    case "-nini":
                        SimParameters.nInitialBlocks = int.Parse(args[++index]);
                    break;
                    case "-pint":
                        SimParameters.printInterval = int.Parse(args[++index]);
                    break;
                    case "-seeds":
                        SimParameters.nInitialSeeds = int.Parse(args[++index]);
                    break;
                    case "-permutations":
                        SimParameters.choosingPolicy = ChoosingPolicy.RAND_PERMUTATION;
                    break;
                    case "-smartseed":
                        SimParameters.smartSeed = true;
                    break;
                    case "-nsu":
                        SimParameters.noSeedUnfinished = true;
                    break;
                    case "-nwb":  // node-with-block
                    {
			// format of argument is "period:percentage:downcap/upcap"
			
                        string arg = args[++index];
                        string[] a = arg.Split("/:".ToCharArray());

                        if (a.Length < 4) {
                            Console.WriteLine("Oops you did not give enough nwb arguments\n");
                            Environment.Exit(1);
                        }

                        SimParameters.nwbOn = true;
                        SimParameters.nwbPeriod = int.Parse(a[0]) * 1000;
                        SimParameters.nwbBlocksPercentage = float.Parse(a[1]);
                        SimParameters.nwbLinkCap = new LinkCap(float.Parse(a[2]), float.Parse(a[3]));
                    }
                    break;
                    case "-pfcbatches":   // post-flash-crowd workload in batches
                    {
			// format of argument is "offset:interval:endtime:batchsize:downcap/upcap" 
			
                        // need to schedule x joins every y seconds starting at
                        // OFFSET seconds
                        string[] a = args[++index].Split("/:".ToCharArray());
                        if (a.Length < 6) {
                            Console.WriteLine("Oops you did not give enough pfcbatches arguments\n");
                            Environment.Exit(1);
                        }

                        SimParameters.pfcOffset = int.Parse(a[0]) * 1000;
                        SimParameters.pfcInterval = int.Parse(a[1]) * 1000;
                        SimParameters.pfcEndTime = int.Parse(a[2]) * 1000;
                        SimParameters.pfcBatchSize = int.Parse(a[3]);
                        SimParameters.pfcLinkCap = new LinkCap(float.Parse(a[4]), float.Parse(a[5]));
                    }
                    break;
                    case "-sptft":   // special pairwise tft 
                        SimParameters.spPairwiseTFT = true;
                    break;
                    case "-maxnodes":
                        Node.MAX_NODES = int.Parse(args[++index]);
                    break;
                    case "-originload":
                        SimParameters.originServerLoad = float.Parse(args[++index]);
                    break;
                    case "-tmb":  // tracker matches bandwidths
                        SimParameters.trackerMatchesBws = true;
                    break;
                    default:
                    // if we don't understand something, we will just add it to the command line arguments
                    // to be processed by the ProcessJob function
                    cmdline_arguments.Add(args[index]);
                    break;
                }
                index++;
            }

            new WorkloadProcessor(workload_file);
            return 0;
        }
    }


}
