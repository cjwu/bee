using System;
using System.IO;  
using System.Collections;
using System.Diagnostics;

namespace Simulator
{
    /// <summary>
    /// Process workloads using the rest of the simulator infrastructure
    /// </summary>
    public class WorkloadProcessor
    {
	private static Random rnd = new Random(123);
	private StreamReader workloadReader;
	public static Sim s = null;
	private static long timemark = 0;

	public WorkloadProcessor(string workloadfile)
	{
	    long start = DateTime.Now.Ticks;
	    s = new Sim();
	    ProtocolSim.sim = s;

	    long time = s.TimeNow();
	    Console.WriteLine("Processing workload from file: " + workloadfile);
	    ProcessWorkload(workloadfile);
	}

	void ProcessWorkload(string workloadfile)
	{
	    long start = DateTime.Now.Ticks;
	    workloadReader = new StreamReader(workloadfile);

	    String str = workloadReader.ReadLine();
	    while (str!=null) 
	    {
		if (str.StartsWith("#"))
		{
		    str = workloadReader.ReadLine();
		    continue;
		}

		long jobtime = GetTimeOfJob(str);
		if (jobtime < s.TimeNow())
		    throw new Exception("time of job already past: " + str + " currtime = " + s.TimeNow() + "\n");

		if (!s.ProcessTill(jobtime))
		    break;
		//                Console.WriteLine("str:{0}:", str);
		try {
		    ProcessJob(str);
		}
		catch (Exception e) {
		    Console.Write("str:{0}:", str);
		    throw e;
		}

		str = workloadReader.ReadLine();
	    }

	    Logger.Finish();
	    Console.WriteLine("-------------------------end of run-------------------------");
	    Console.WriteLine("Completed in " + ((double)(DateTime.Now.Ticks-start)/10000000.0) + " seconds.");

	}

	int node_births = 0;

	public void ProcessJob(string jobstring) 
	{
	    string[] tokens = jobstring.Split();
	    switch (tokens[1]) 
	    {
		/// "initialize" IS WHERE EVERYTHING "STARTS" 
		case "initialize":
		{
		    Logger.Initialize(s);
		    ProtocolSim.Initialize();
		    SimParameters.GenerateDependents();

		    s.RaiseSimulationEvent(1000, new UtilDumpEvent(s));
		    s.RaiseSimulationEvent(1000, new GraphDumpEvent(s));

		    if (SimParameters.stayTimeModel != StayTimeModel.FROMTRACE_STAYTIME) {
			ProtocolSim.ScheduleSomeJoins();
		    }

		    if (SimParameters.nwbOn) {
			ProtocolSim.ScheduleNWBJoins();
		    }
		    if (SimParameters.pfcOffset > 0) {
			ProtocolSim.SchedulePFCJoins();
		    }
		}
		break;

		case "process_cmdline_args":
		    foreach (string str in MainWrapper.cmdline_arguments) 
		    {
			long jobtime = GetTimeOfJob(str);
			if (jobtime < s.TimeNow())
			    throw new Exception("time of job already past: " + str + " currtime = " + s.TimeNow() + "\n");

			s.ProcessTill(jobtime);
			ProcessJob(str);
		    }
		break;

		case "node_birth":
		{
		    node_births++;
		    if (node_births % 200 == 0) {
			Console.WriteLine("nodes processed: {0} current job: {1}",
				node_births, jobstring);
		    }

		    if (tokens[2].Equals("end")) {
			ProtocolSim.CreateNode();
		    }
		    else 
		    {
			/// This is not really used since nodes leave when they 
			/// are done downloading.
			switch (tokens[2]) 
			{
			    case "live_for":
				ProtocolSim.CreateNode(long.Parse(tokens[3]));
			    break;

			default: 
			    throw new Exception("unknown option - "+tokens[2]+"\n");
			}
		    }
		}
		break;

		case "schedule_some_joins":
		    ProtocolSim.ScheduleSomeJoins(int.Parse(tokens[2]));
		break;
		case "process":
		{
		    if (tokens[2].Equals("for")) 
			s.ProcessForTime(long.Parse(tokens[3]));
		    else if (tokens[2].Equals("till")) 
			s.ProcessTill(long.Parse(tokens[3]));
		    else 
			throw new Exception("unknown process command "+jobstring+"\n");
		}
		break;

		case "timemark":
		    timemark = s.TimeNow();
		break;


		case "setparam":
		    switch (tokens[2]) 
		    {
			case "simulation_time":
			    SimParameters.simulationTime = long.Parse(tokens[3]);
			SimParameters.joinTime       = SimParameters.simulationTime - 2000;  // the default value
			break;

			case "join_time":
			    SimParameters.joinTime = long.Parse(tokens[3]);
			break;

			case "bw_model":
			{
			    SimParameters.bwProbabilities.Clear();
			    for (int i = 3; i < tokens.Length; i++) 
			    {
				if (tokens[i].Equals("end"))
				    break;
				string[] dps = tokens[i].Split(":".ToCharArray());
				SimParameters.bwProbabilities.Add(new LinkCap(float.Parse(dps[0]), float.Parse(dps[1])), 
					double.Parse(dps[2]));
			    }
			}
			break;

			case "output":
			    SimParameters.outputFile = tokens[3];
			break;

			case "jl_model":
			    if (tokens[3].Equals("trace")) 
			    { // we expect join and leaves in the trace
				SimParameters.stayTimeModel = StayTimeModel.FROMTRACE_STAYTIME;
			    }
			    else 
			    {
				// should be: [time] setparam jl_model joinrate:[rate] staytime:uniform:100:300 
				//System.Diagnostics.Debug.Assert(tokens.Length >= 5);
				string[] tmp = tokens[3].Split(":".ToCharArray());
				SimParameters.joinRate = float.Parse(tmp[1]);
				SimParameters.stayTimeParams = tokens[4];
			    }
			break;

			case "block_size": 
			{
			    SimParameters.blockSize = int.Parse(tokens[3]);
			    SimParameters.blockSizeInBits = SimParameters.blockSize << 10;
			}
			break;

			case "file_size":  
			    SimParameters.fileSize = int.Parse(tokens[3]);
			break;

			case "seed_leaving_prob":
			    SimParameters.seedLeavingProbability = double.Parse(tokens[3]);
			break;

			case "seed_bw":
			    SimParameters.seedBandwidth = int.Parse(tokens[3]);
			break;

		    default:
			throw new Exception("unknown parameter "+tokens[2]);
		    }
		break;

		case "print_param":
		    SimParameters.PrintAll();
		break;

	    default: 
		throw new Exception("unknown job type "+tokens[1]);
	    }
	}

	private long GetTimeOfJob(string job) 
	{
	    string[] tokens = job.Split();
	    string timestring = tokens[0];

	    if (timestring.Equals("now")) 
	    {
		return s.TimeNow();
	    }
	    else if (timestring.StartsWith("+"))
	    {
		return timemark + long.Parse(timestring);
	    }
	    else 
	    {
		return long.Parse(timestring);
	    }
	}
    }
}
