using System;
using System.Collections;

///<summary>
/// This is a crazy collection of utility events and functions.
/// The purpose of most of them is in scheduling events and 
/// actions at particular times during the simulation. Mostly 
/// driven from the WorkloadProcessor
///</summary>

namespace Simulator
{
    public class CreateNodeEvent : TimerEvent
    {
        public void process(long timeNow)
        {
            ProtocolSim.CreateNode();
        }
    }

    public class KillNodeEvent : TimerEvent 
    {
        private Node n = null;

        public KillNodeEvent(Node node) 
        {
            n = node;
        }
        public void process(long timeNow)
        {
            ProtocolSim.KillNode(n);
        }
    }

    public class ScheduleSomeJoinsEvent : TimerEvent 
    {
        public void process(long timeNow) 
        {
            ProtocolSim.ScheduleSomeJoins();
        }
    }

    // this is a stupid class as you can very well 
    // see. think of it as nothing more than a wrapper
    // around Sim.GetRandomNodes
    
    public class Oracle 
    {
        Sim  m_Simulator = null;

        public Oracle(Sim s)  
        {
            m_Simulator = s;
        }

        public ArrayList GetInitialPeerList(Node n)
        {
            return m_Simulator.GetRandomNodes(SimParameters.nInitialPeers, n);
        }

        public ArrayList GetMorePeers(Node n)
        {
            return m_Simulator.GetRandomNodes(SimParameters.nRefreshPeers, n);
        }
    }

    public class ProtocolSim 
    {
        public static Sim sim = null;

        public static void CreateNode()
        {
            CreateNode(0);
        }

	// This is where a node is created into the system
	// and begins its life.
	
        public static void CreateNode(long ttl)
        {
            Node n = sim.CreateNode();    // this assigns bandwidth; sad that fields are initialized at various places...
            n.m_JoinTime = sim.TimeNow();
            if (ttl > 0) {
                n.m_LifeTime = ttl;

                if (SimParameters.forceKills) 
                {
                    KillNodeEvent ev = new KillNodeEvent(n);
                    sim.RaiseSimulationEvent(ttl, ev);
                }
            }
            else {
                n.m_LifeTime = long.MaxValue;
            }

            n.JoinNetwork();
        }

        public static void CreateNode(LinkCap lc) 
        {
            Node n = sim.CreateNode();  
            n.m_JoinTime = sim.TimeNow();
            n.m_LifeTime = long.MaxValue;

            n.DownCap = lc.down_bw; 
            n.UpCap   = lc.up_bw;
            n.JoinNetwork();
        }
        public static void KillNode(Node n)
        {
            sim.KillNode(n);
            n.Alive = false;

            ArrayList conns = new ArrayList(n.GetConnections());
            foreach (Connection conn in conns)
            {
                conn.Peer.RemovePeer(n);
            }

            Logger.node_log(n, LogEvent.LEAVE);
        }

        class CreateNWBEvent : TimerEvent 
        {
            Sim m_Simulator = null;
            public CreateNWBEvent(Sim s) 
            {
                m_Simulator = s;
            }
            public void process(long timeNow)
            {
                // Don't create these stupid nodes if nobody is around
                if (m_Simulator.NumNodes() < SimParameters.nInitialSeeds + 10) 
                    return;

                
                Node n = m_Simulator.CreateNode();    // this assigns bandwidth; sad that fields are initialized at various places...
                n.DownCap = SimParameters.nwbLinkCap.down_bw;
                n.UpCap = SimParameters.nwbLinkCap.up_bw;

                Console.WriteLine("Adding a NWB node[{0}] at time={1}", n.ID, timeNow);
                n.AssignBlocks((int) ((float) SimParameters.nwbBlocksPercentage * n.ToFinishPieces / (float) 100.0 ));
                n.JoinNetwork();
            }
        }
        
	/// node-with-block joins (incoming nodes already are seeded
	/// with random blocks)
        public static void ScheduleNWBJoins()
        {
            long offset = SimParameters.nwbPeriod;
            
            while (offset < SimParameters.simulationTime) {
                sim.RaiseSimulationEvent(offset, new CreateNWBEvent(sim));
                offset += SimParameters.nwbPeriod;
            }
        }

	/// post-flash-crowd joins (nodes are joining when people in 
	/// the initial flash-crowd have started leaving) 
        public static void SchedulePFCJoins()
        {
            long offset = SimParameters.pfcOffset;
            
            while (offset < SimParameters.pfcEndTime) {
                sim.RaiseSimulationEvent(offset, new CreatePFCBatchEvent());
                offset += SimParameters.pfcInterval;
            }
        }

        class CreatePFCBatchEvent : TimerEvent {
            public CreatePFCBatchEvent() {
            } 
            public void process(long timeNow) {
                for (int i = 0; i < SimParameters.pfcBatchSize; i++ ) {
                    ProtocolSim.CreateNode(SimParameters.pfcLinkCap);
                }
            }
        }

        public static void ScheduleSomeJoins(int howmany)
        {
            long offset = 0;
            long msec = (long) (1000 / SimParameters.joinRate);     // JoinRate is per sec

            for (int i = 0; i < howmany; i++)
            {
                CreateNodeEvent je = new CreateNodeEvent();
                sim.RaiseSimulationEvent(offset, je);
                offset += Sim.rng.Next((int) (-0.3 * msec), (int) (0.3 * msec)) + msec;
            }

            Console.WriteLine("Scheduled {0} joins...", howmany);
        }

        private static long timeScheduled = 0;
        public static void ScheduleSomeJoins()
        {		
            /* now we have to schedule all the join events into the simulator. 
             * this might get darn slow because we will be putting huge number of events 
             * into the priority queues... 
             * 
             * Smarter mechanism -->
             * 
             * try to schedule some number at a time; and schedule this routine to 
             * be called again after some time. By that time, all these events would be
             * mostly processed */

            long offset = 0;
            long msec = (long) (1000 / SimParameters.joinRate);     // JoinRate is per sec
            int toSchedule = 1000; // schedule 1000 joins.
            int act_scheduled = 0;

            for (int i = 0; i < toSchedule; i++)
            {
                if ((offset + timeScheduled) >= SimParameters.joinTime)
                    break;

                CreateNodeEvent je = new CreateNodeEvent();
                sim.RaiseSimulationEvent(offset, je);
                // Console.WriteLine("scheduled event at: {0}", sim.TimeNow() + offset);

                act_scheduled++;
                // Randomize a little bit...
                offset += Sim.rng.Next((int) (-0.3 * msec), (int) (0.3 * msec)) + msec;
            }

            timeScheduled += offset;
            Console.WriteLine("Scheduled {0} joins...", act_scheduled);
            if (timeScheduled < SimParameters.joinTime) 
            {
                Console.WriteLine("\n..................scheduling again...............\n");
                sim.RaiseSimulationEvent(offset, new ScheduleSomeJoinsEvent());
            }
        }

        private static void CreateSeeds(int n_seeds)
        {
            for (int i = 0; i < n_seeds; i++)
            {
                Node n = sim.CreateNode();
                n.m_JoinTime = sim.TimeNow();
                n.m_LifeTime = long.MaxValue;


                n.UpCap = WorkloadGenerator.GenerateSeedBandwidth();
                n.DownCap = 1000000L; // float.MaxValue;
                n.BecomeSeed();
                n.JoinNetwork();
            }

            int npieces = (int) (SimParameters.fileSize * SimParameters.FEC/SimParameters.blockSize);
            for (int i = 0 ; i < npieces; i++)
                Node.s_GlobalAvailArray[i] = n_seeds;
        }

        public static void Initialize()
        {
            int npieces = (int) (SimParameters.fileSize * SimParameters.FEC/SimParameters.blockSize);
            Node.s_GlobalAvailArray = new int[npieces];
            CreateSeeds(SimParameters.nInitialSeeds);
        }
    }
}
