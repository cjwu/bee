using System;
using System.IO;
using System.Collections;
using System.Diagnostics;

namespace Simulator
{
    public class Stats 
    {
    }

    public class UtilDumpEvent : TimerEvent
    {	
	Sim    m_Simulator = null;

	public UtilDumpEvent(Sim s) {
	    m_Simulator = s;
	}
	public void process(long timeNow)
	{
	    m_Simulator.RaiseSimulationEvent(SimParameters.utilDumpInterval, this);

	    if (m_Simulator.NumNodes() == SimParameters.nInitialSeeds)
		return;
	    if (SimParameters.originServerLoad < 0)
		ComputeDistances();

	    FixInterests();

	    Logger.timed_stream.WriteLine("time {0}", m_Simulator.TimeNow());
	    foreach (Node n in m_Simulator)
	    {
		n.Dump(Logger.timed_stream);
	    }
	}

	// Find a.IsChoking(b) QUICKLY.
	// is conn.Peer choking a?

	bool FastIsChoking(Node a, Connection conn)
	{
	    return conn.OtherEndConnection.IsChoking();
	    // return Node.s_GlobalChokingArray[a.ID,  b.ID];
	}

	void FixInterests()
	{
	    int npieces = (int) ((SimParameters.fileSize / SimParameters.blockSize) * SimParameters.FEC);

	    foreach (Node n in m_Simulator)
	    {
		foreach (Connection conn in n.GetConnections())
		{
		    Node peer = conn.Peer;
		    for (int i = 0; i < npieces; i++) 
		    {
			conn.Interested = false;
			if (!n.HasPiece(i) && !n.IsDownloading(i) && peer.HasPiece(i))
			{
			    conn.Interested = true;
			    break;
			}

			// CHECK if our thing is correct!
			Debug.Assert(peer.IsChoking(n) == FastIsChoking(n, conn));

			// CHECK if our new stuff is correct!
			Debug.Assert(peer.CanTransferTo(n) == peer.FastCanTransferTo(conn.OtherEndConnection));

			if ((!SimParameters.DoingBlockTFT() && !FastIsChoking(n, conn))
				|| (SimParameters.DoingBlockTFT() && peer.FastCanTransferTo(conn.OtherEndConnection)))
			{
			    if (conn.Interested && !conn.IsDownloading)
				m_Simulator.RaiseSimulationEvent(0, new TryDownloadEvent(n, conn));
			}
		    }
		}
	    }
	}
	void ComputeDistances() {
	    Node start = null;
	    foreach (Node n in m_Simulator) 
	    {
		n.m_Distance = -1;
		if (n.ID == 1) 
		    start = n;
	    }

	    Queue list = new Queue();
	    list.Enqueue(start);
	    start.m_Distance = 0;

	    while (list.Count > 0) {
		start = (Node) list.Dequeue();

		foreach (Connection conn in start.GetConnections()) {
		    if (conn.Peer.m_Distance < 0) {
			conn.Peer.m_Distance = start.m_Distance + 1;
			list.Enqueue(conn.Peer);
		    }
		}
	    }

	    foreach (Node n in m_Simulator)
	    {
		if (n.m_Distance == -1)
		    m_Simulator.RaiseSimulationEvent(0, new MorePeersEvent(n, false /* trackerMatchesBws */));
	    }
	}
    }

    public class GraphDumpEvent : TimerEvent
    {	
	Sim    m_Simulator = null;

	public GraphDumpEvent(Sim s) 
	{
	    m_Simulator = s;
	}

	public void process(long timeNow)
	{
	    StreamWriter os = Logger.graph_stream;

	    //m_Simulator.RaiseSimulationEvent(SimParameters.graphPrintInterval, this);

	    os.WriteLine("time {0}", m_Simulator.TimeNow());
	    foreach (Node n in m_Simulator)
	    {
		os.Write("{0} -> ", n.ID);
		foreach (Connection conn in n.GetConnections()) {
		    os.Write("{0} ", conn.Peer.ID);
		}
		os.WriteLine();
	    }
	}
    }

}
