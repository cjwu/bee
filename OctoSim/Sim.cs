using System;
using System.IO;
using System.Collections;
using System.Diagnostics;

namespace Simulator
{
    public interface TimerEvent 
    {
        void process(long timeNow);
    }

    /// <summary>
    /// This class generates workloads for b/w distribution of clients and their staytimes
    /// depending on the parameters provided (either on the command line or through a 
    /// workload file/trace.)
    /// </summary>
    public class WorkloadGenerator {
        public static LinkCap GenerateNodeBandwidths()
        {
            LinkCap c = new LinkCap(0, 0);

            double cur_prob = 0.0;
            double rand = Sim.rng.NextDouble();

            SortedList bwp = SimParameters.bwProbabilities;
            foreach (LinkCap lc in bwp.Keys) 
            {
                if (rand <= (cur_prob + (double) bwp[lc]))
                {
                    return lc;
                }
                cur_prob += (double) bwp[lc];
            }
            /* Ideally, should never come here... */
            return c;
        }

        public static float GenerateSeedBandwidth()
        {
            return SimParameters.seedBandwidth;
        }

        private static bool stayTimeParamsParsed = false;
        private static int stayTimeUniformMin = 0, stayTimeUniformMax = 0;
        private static double stayTimeParetoMin = 0, stayTimeParetoMax = 0;

	// Not really used since nodes leave when they 
	// are finished downloading
        public long GenerateNodeStayTime()	    
        {
            if (!stayTimeParamsParsed) 
            {
                string[] p = SimParameters.stayTimeParams.Split(":".ToCharArray());
                switch (p[0])
                {
                    case "uniform":
                        SimParameters.stayTimeModel = StayTimeModel.UNIFORM_STAYTIME;
                    stayTimeUniformMin = int.Parse(p[1]) * 1000;
                    stayTimeUniformMax = int.Parse(p[2]) * 1000;
                    break;
                    case "pareto":
                        SimParameters.stayTimeModel = StayTimeModel.PARETO_STAYTIME;
                    stayTimeParetoMin = 90;
                    stayTimeParetoMax = 928.10;
                    break;

                    default:
                    Console.WriteLine("Wrong parameter for stayTimeParams");
                    Environment.Exit(13);
                    break;
                }
                stayTimeParamsParsed = true;
            }

            switch (SimParameters.stayTimeModel) 
            {
                case StayTimeModel.UNIFORM_STAYTIME:
                    return Sim.rng.Next(stayTimeUniformMin, stayTimeUniformMax);
                case StayTimeModel.PARETO_STAYTIME:
                    return (long) GeneratePareto();
                default:
                    throw new Exception("Not implemented");
            }
        }

        private double GeneratePareto()
        {
            double temp = 0;
            while (temp == 0) 
                temp = Sim.rng.NextDouble();

            double var = stayTimeParetoMin/Math.Pow(temp, 1);
            if (var > stayTimeParetoMax)
                var = stayTimeParetoMax;

            return (var * 1000);
        }

    }

    /// <summary>
    /// This class represents the simulator. It provides support for an eventqueue, and routing 
    /// packets across nodes. Simulates packet losses and b/w limits but no topology support is 
    /// provided for now. i.e., All connections are application-level. No queueing support is 
    /// present, either. So, in effect, connections represent completely max-min fair fluid 
    /// flows.
    /// </summary>
    public class Sim 
    {
        private EventQueue triggers;                  // this is the main event-queue
        public  static Random rng, dtm_rng, rnd_rng;  // random number generators

        private long timenow;                         // current time according to the event-queue
        private long nevents;                         // #events processed (stats)
        private SortedList nodes;	              // nodes allocated in the simulator 

        private Oracle m_Oracle = null;               // oracle for some special purposes

        public Sim()
        {
            commonInit();
            m_Oracle = new Oracle(this);
        }

        private void commonInit() 
        {
            nodes = new SortedList(100000);
            rnd_rng = new Random();
            dtm_rng = new Random(1111);

	    // sometimes we want to use deterministic rng's
            if (SimParameters.useDeterministicPseudoRandomness) 
            {
                rng = dtm_rng;
            }
            else {
                rng = rnd_rng;
            }
            triggers = new EventQueue();
        }


        public int NumNodes() 
        {
            return nodes.Count;
        }

        public long TimeNow()
        {
            return timenow;
        }

        public void RaiseSimulationEvent(long ms, TimerEvent obj) 
        {
            long time = TimeNow() + ms;
            triggers.InsertObject(time, obj);
        }

        public static int nodenum_pool = 0;

        public void AssignBandwidth(Node node)
        {
            LinkCap c = WorkloadGenerator.GenerateNodeBandwidths();
            node.DownCap = c.down_bw;
            node.UpCap   = c.up_bw;
        }

        public static int FloatCompare(float xr, float yr)
        {
            if (xr == yr)
                return 0;
            if (xr < yr)
                return -1;
            return 1;
        }

        public Node CreateNode()
        {
            Node node = new Node(this, m_Oracle, SimParameters.fileSize/SimParameters.blockSize);
            node.ID = ++nodenum_pool;
            AssignBandwidth(node);

            // Console.WriteLine("adding a node [{0}] with bw- down/up = {1}/{2} @@ {3}", node.ID, node.DownCap, node.UpCap, timenow);
            nodes.Add(node.ID, node);
            return node;
        }

        public void KillNode(Node node) 
        {
            //Console.WriteLine("Kill " + node.NodeId.ToString());
            nodes.Remove(node.ID);
        }

        // Returns an enumerator for all the nodes in the system
        public IEnumerator GetEnumerator() 
        {
            return nodes.Values.GetEnumerator();
        }

        public Node RandomNode() 
        {
            Node node = null;
            if (nodes.Count > 0) 
            {
                int index = rng.Next(nodes.Count);
                node = (Node)nodes.GetByIndex(index);
            }

            return node;
        }

        public void Shuffle(Object[] array)
        {
            int len = array.Length;

            for (int j = len - 1; j > 0; j--)
            {
                int k = rng.Next(j + 1);
                Object tmp = array[k];
                array[k] = array[j];
                array[j] = tmp;
            }
        }

        public void Shuffle(ArrayList array, int start, int length)
        {
            int len = length;

            for (int j = len - 1; j > 0; j--)
            {
                int k = rng.Next(j + 1);
                Object tmp = array[start + k];
                array[start + k] = array[start + j];
                array[start + j] = tmp;
	    }
	}

	public void Shuffle(int[] array)
	{
	    int len = array.Length;

	    for (int j = len - 1; j > 0; j--)
	    {
		int k = rng.Next(j + 1);
		int tmp = array[k];
		array[k] = array[j];
		array[j] = tmp;
	    }
	}

	// if tmb (tracker-matches-bandwidth) is TRUE, 
	// we try to select nodes in the same "class" 
	// as 'node_to_avoid' preferentially. if no 
	// such nodes are available, we select randomly 
	// from the other class of nodes.
	//
	// if tmb is FALSE, node selection is random.
	public ArrayList GetBWAwareRandomNodes(int n_nodes, Node
		node_to_avoid, bool tmb) 
	{
	    ArrayList alist = new ArrayList();
	    ArrayList blist = new ArrayList();

	    int i;

	    foreach (Node n in nodes.Values) 
	    {
		if (n.ID == node_to_avoid.ID) // || n.GetConnections().Count >= SimParameters.maxPeersThreshold)
		    continue;

		if (tmb) {
		    if (n.UpCap == node_to_avoid.UpCap) 
			alist.Add(n);
		    else
			blist.Add(n);
		}
		else {
		    alist.Add(n);
		}
	    }


	    blist.Sort(new UpCapComparer());

	    ArrayList final_list = null;
	    ArrayList ret_alist = new ArrayList();

	    if (alist.Count >= n_nodes)  {
		final_list = alist;
	    }
	    else {
		// Console.WriteLine("node {0} ({1}) needed other guys...", node_to_avoid.ID, node_to_avoid.UpCap);
		ret_alist.AddRange(alist);
		final_list = blist;
		n_nodes -= alist.Count;
	    }

	    Node[] arr = new Node[final_list.Count];
	    i = 0;
	    foreach (Node n in final_list)
		arr[i++] = n;
	    Shuffle(arr);

	    for (i = 0; i < n_nodes; i++) 
	    {
		if (i >= arr.Length)
		    break;
		ret_alist.Add(arr[i]);
	    }
	    return ret_alist;
	}

	public ArrayList GetRandomNodes(int n_nodes, Node node_to_avoid) 
	{
	    // if tracker is bandwidth aware, we get half nodes 
	    // which are in the "correct" bandwidth group and 
	    // half which are random. such distribution ensures 
	    // that bad race conditions leading to disconnection 
	    // of the network do not happen.

	    if (SimParameters.trackerMatchesBws) {
		int h = (int) (n_nodes / 2);
		ArrayList fhalf = GetBWAwareRandomNodes(h,
			node_to_avoid, true);
		ArrayList shalf = GetBWAwareRandomNodes(n_nodes - h,
			node_to_avoid, false);
		fhalf.AddRange(shalf);
		return fhalf;
	    }
	    else {
		return GetBWAwareRandomNodes(n_nodes, node_to_avoid,
			false);
	    }
	}

	public void ProcessForTime(long ms) 
	{
	    long endTime = timenow + ms;
	    ProcessTill(endTime);
	}

	public bool ProcessTill(long abstime) 
	{
	    bool print = true;

	    while (!triggers.IsEmpty)
	    {
		if (triggers.GetNextTime() > abstime)
		    break;
		ListElement l = triggers.GetNextEvents();
		timenow = triggers.GetTime;

		// print every 100 seconds; make the boolean "print" true 
		// only the first time you hit this point...

		if ((timenow/1000) % 1000 == 0) {		    
		    if (print) 
		    {
			print = false;

			float fin = 0.0f;
			int   n = 0;
			foreach (Node node in this) {
			    n++;
			    fin += ((float) node.NFinishedPieces / (float) node.NPieces);
			}
			fin /= n;
			Console.WriteLine("processed {0} events ... curtime: {1} nodes: {2}     [{3}% done]", 
				nevents, TimeNow(), NumNodes(), 
				(int) (fin * 100.0));
		    }
		}
		else {
		    print = true;
		}

		if (timenow > SimParameters.simulationTime) 
		{
		    Console.WriteLine("...........\ntimeNow: {0} SimulTime: {1}",
			    timenow, SimParameters.simulationTime);
		    Console.WriteLine("Simulation Time crossed\n.............");
		    triggers = new EventQueue();
		    
		    return false;
		}
		while (l != null)
		{
		    l.store.process(timenow);
		    nevents++;
		    l = l.next;
		}
	    }
	    timenow = abstime; // Do we want to do this?
	    return true;
	}

	public class UpCapComparer : IComparer {
	    // reverse sort
	    public int Compare(Object x, Object y)
	    {
		Node nx = (Node) x, ny = (Node) y;
		float xr = nx.UpCap, yr = ny.UpCap;

		return -Sim.FloatCompare(xr, yr);
	    }
	}
    }
}
