using System;
using System.Collections;
using System.Diagnostics;

namespace Simulator
{
    /// <summary>
    ///  Ashwin [07/20/2004]
    ///  
    /// There's a lot of funky activity going on here (mostly, about how to perform optimistic 
    /// unchoking). The code is somewhat tricky so beware!
    /// </summary>
    public class Choker
    {
	private Node      m_Node = null;             // My controller
	private ArrayList m_Connections = null;      // This is a special connection array; needed in order to do some funky things
	// like "rotate" the optimistic unchoke fellow, etc.
	private Sim       m_Simulator = null;
	private int       m_Invocations = 0;
	private bool      m_Done = false;

	public Choker(Node n, Sim s)
	{
	    m_Connections = new ArrayList();
	    m_Node        = n;
	    m_Simulator   = s;
	}

	public void Done() { m_Done = true; }

	class PCEvent : TimerEvent
	{
	    Choker m_Choker = null;
	    public PCEvent(Choker choker)
	    {
		m_Choker = choker;
	    }
	    public void process(long timeNow)
	    {
		m_Choker.PerformChoking();
	    }
	}

	public void AddConnection(Connection conn) 
	{
	    // Insert at a "random" place; why do we do this? So that the new connection gets some random "priority" 
	    // when we decide to a optimistic unchoke. Otherwise, we might have defaulted to "append" and wouldn't explore 
	    // new connections for optimistic unchoking early on...
	    m_Connections.Insert(Math.Max(0, Sim.rng.Next(-2, m_Connections.Count + 1)), conn); 
	    m_Simulator.RaiseSimulationEvent(0, new PCEvent(this));
	    // PerformChoking();
	}

	public void RemoveConnection(Connection conn) {
	    m_Connections.Remove(conn);         // I hope, "Remove" would do the right thing, here.
	    if (conn.IsChoking() && conn.Peer.IsInterested(m_Node))
	    {
		m_Simulator.RaiseSimulationEvent(0, new PCEvent(this));
		// PerformChoking();
	    }
	}

	//////////////////////////////////////////////////////////////////////////
	/// OU = Optimisitic Unchoke
	public void ChokeUnchoke() 
	{
	    if (m_Done)
		return;

	    m_Simulator.RaiseSimulationEvent(SimParameters.chokerInterval, new ChokerEvent(this));

	    m_Node.CheckTooManyPeers();

#if DEBUG
	    m_Node.SanityCheck();
#endif

	    m_Invocations++;
	    if (m_Invocations % 3 == 0) 
	    {
		RotateOUGuy();
	    }

	    PerformChoking();

#if UNDEF
	    Logger.ulog("chokerstats {0} ", m_Node.ID);
	    foreach (Connection conn in m_Connections)
	    {
		if (conn.IsChoking())
		    continue;
		Logger.ulog("{0}:{1:f3}:{2:f3} ", conn.Peer.ID, conn.GetUploadRate(), conn.GetDownloadRate());
	    }
	    Logger.log("");
#endif
	}

	private float bw(ArrayList list, int i)
	{
	    if (m_Node.IsSeed)
		return ((Connection) list[i]).GetUploadRate();
	    else 
		return ((Connection) list[i]).GetDownloadRate();
	}

	private bool isbweq(float a, float b)
	{
	    if (Math.Abs(a - b) < 0.0001) 
		return true;
	    else
		return false;
	}

	private void DeltaPerturb(ArrayList list)
	{
	    int n = list.Count;
	    int prev = 0;

	    for (int i = 1; i < n; i++) 
	    {
		if ( isbweq( bw(list, prev), bw(list, i) ) ) 
		    continue;

		if (prev < (i - 1)) 
		    m_Simulator.Shuffle(list, prev, (i - prev));

		prev = i;
	    }
	    if (prev < n - 1)
		m_Simulator.Shuffle(list, prev, n - prev);
	}

	//////////////////////////////////////////////////////////////////////////
	// Ashwin [7/27/2004]
	// Ok, have a problem here. Basically, Unchoke() starts an upload (if the 
	// other side is interested), but the Choke() operation doesn't actually 
	// stop an ongoing transfer! So, a large #uploads get started -- especially
	// from seeds who have all the data. This is not "good" since a large number 
	// of small uploads can hurt "system operation".
	//
	// Proposed fix: suppose 'nu' is the current number of uploads going on...
	// Then, you are permitted to unchoke an additional (maxUploads - nu) 
	// connections ONLY. However, this can result in "unutilized upload capacity"
	// because the choker gets invoked only so often. To fix that, increase the 
	// frequency of the choker invocations to ~500 ms (granularity of the fastest
	// download) -- pending implementation; need to make sure i don't keep the 
	// upload link idle anytime...
	//
	// Ashwin [8/13/2004]
	// Fixed a few days back - just implemented unfinished transfers
	//
	// UH OH: unfinished transfers are bad for the seed node.
	//////////////////////////////////////////////////////////////////////////
	private void PerformChoking()
	{
	    if (SimParameters.DoingBlockTFT())
		return;

	    ArrayList preferred = new ArrayList();
	    foreach (Connection conn in m_Connections)
	    {
		/*                
				  if (SimParameters.spPairwiseTFT && !m_Node.IsSeed) {
				  long extra = conn.Uploaded - conn.Downloaded;
				  if (extra > SimParameters.fairnessThreshold * SimParameters.blockSizeInBits) {
		//                        Console.WriteLine("Coming here... extra = {0}blocks", (float) extra / (float) SimParameters.blockSizeInBits);
		conn.Choke();
		continue;
		}
		}
		 */                
		if (conn.Peer.IsInterested(m_Node))
		    preferred.Add(conn);
	    }

	    preferred.Sort(new PreferredComparer(m_Node));

#if PARANOID
	    DeltaPerturb(preferred);
#endif

	    int n_uploads = 0;
	    if (SimParameters.doOptUnchoke)
		n_uploads = SimParameters.maxUploads - 1;
	    else
		n_uploads = SimParameters.maxUploads;

	    if (preferred.Count > n_uploads) {
		preferred.RemoveRange(n_uploads, preferred.Count - n_uploads);
	    }

	    bool hit = false;
	    int  count = preferred.Count;

	    ArrayList unchoke = new ArrayList(), choke = new ArrayList();

	    foreach (Connection conn in m_Connections)
	    {
		// Always unchoke the "preferred" guys - i.e., the people with the highest "rates"
		if (preferred.Contains(conn)) {
		    unchoke.Add(conn);
#if XXTRA_DEBUG
		    Logger.log("{0} {1} pref unchoke {2} d {3:f3} u {4:f3} d/l:{5} int:{6}", m_Simulator.TimeNow(), m_Node.ID, conn.Peer.ID, 
			    conn.GetDownloadRate(), conn.GetUploadRate(), conn.IsDownloading, conn.IsInterested());
#endif
		}
		// Optimistic unchoke
		else {
		    if ( SimParameters.doOptUnchoke && (count < SimParameters.maxUploads || !hit) ) {
			unchoke.Add(conn);
			// THIS is the real unchoke (coz the other guy will start downloading immediately)
			//						if (conn.Peer.IsInterested(m_Node)) 
			{
#if XXTRA_DEBUG
			    Logger.log("{0} {1} opt unchoke {2} d {3:f3} u {4:f3} d/l:{5} int:{6}", m_Simulator.TimeNow(), m_Node.ID, conn.Peer.ID,
				    conn.GetDownloadRate(), conn.GetUploadRate(), conn.IsDownloading, conn.IsInterested());
#endif
			    hit = true; 
			    count++;
			}
		    }
		    else {
			choke.Add(conn);
		    }
		}
	    }

	    //////////////////////////////////////////////////////////////////////////
	    // Debug [8/20/2004]
#if XXTRA_DEBUG			
	    Connection lucky = null, unlucky = null;
	    foreach (Connection conn in unchoke) 
	    {
		if (conn.IsChoking()) 
		    lucky = conn;
	    }
	    foreach (Connection conn in choke) 
	    {
		if (!conn.IsChoking())
		    unlucky = conn;
	    }	
	    if (m_Simulator.TimeNow() > 1000000 && m_Node.NDownloads > 5) 
	    {
		Logger.timed_stream.Write("--{0} ", m_Node.ID );
		if (lucky != null)
		    Logger.timed_stream.Write("lucky {0} ", lucky.Peer.ID);
		if (unlucky != null)
		    Logger.timed_stream.Write("unluc {0} ", unlucky.Peer.ID);

		foreach (Connection conn in m_Connections)
		{
		    Logger.timed_stream.Write("{0}:{1}:{2}:{3:f3}:{4:f3} ", conn.Peer.ID, 
			    (conn.IsChoking() ? "c" : "u"),
			    (conn.Peer.IsChoking(m_Node) ? "C" : "U"),
			    conn.GetDownloadRate(),
			    conn.GetUploadRate());
		}
		Logger.timed_stream.WriteLine();
	    }
#endif

	    //////////////////////////////////////////////////////////////////////////

	    foreach (Connection conn in unchoke) 
		conn.Unchoke();
	    foreach (Connection conn in choke) 
		conn.Choke();
	    choke.Clear();  unchoke.Clear();
	}

	// rotate the optimistic unchoke fellow; heh, i am sexist!

	public void RotateOUGuy()
	{
	    if (!SimParameters.doOptUnchoke)
		return;

	    if (SimParameters.measureBWinstantenously) 
	    {
		// Don't need to "rotate" people now...  just have the highest rate guy first.
		m_Connections.Sort(new OracleRateComparer(m_Node));
	    }
	    else 
	    {
		int index = 0;
		foreach (Connection conn in m_Connections) 
		{
		    if (conn.IsChoking() && conn.Peer.IsInterested(m_Node)) 
			break;
		    index++;
		}

		if (index == m_Connections.Count) 
		    return; 

		Connection c = (Connection) m_Connections[index];
		m_Connections.RemoveAt(index);
		m_Connections.Insert(0, c);
	    }
	}
    }

    public class PreferredComparer : IComparer 
    {
	Node m_Node = null;

	public PreferredComparer(Node n) 
	{
	    m_Node = n;
	}

	// Reverse sort -- i.e., the higher rate guys should be first...
	public int Compare(object x, object y) 
	{
	    Connection xc = (Connection) x, yc = (Connection) y;
	    float xr, yr;

	    if (m_Node.IsSeed) 
	    {
		xr = xc.GetUploadRate();
		yr = yc.GetUploadRate();
	    }
	    else 
	    {
		xr = xc.GetDownloadRate();
		yr = yc.GetDownloadRate();
	    }

	    return -Sim.FloatCompare(xr, yr);
	}
    }

    public class OracleRateComparer : IComparer
    {
	Node m_Node = null;

	public OracleRateComparer(Node n)
	{
	    m_Node = n;
	}

	private float GetRate(Connection c)
	{
	    Node peer = c.Peer;
	    float rate = 0;

	    if (m_Node.IsSeed)
	    {
		if (m_Node.TransferringTo(peer))
		    rate = peer.DownCap / peer.NDownloads;
		else
		    rate = peer.DownCap / (peer.NDownloads + 1);
	    }
	    else 
	    {
		if (m_Node.TransferringFrom(peer))
		    rate = peer.UpCap / peer.NUploads;
		else
		    rate = peer.UpCap / (peer.NUploads + 1);
	    }
	    return rate;
	}

	// Higher rate guys first!
	public int Compare(object x, object y)
	{
	    Connection xc = (Connection) x, yc = (Connection) y;
	    float xr, yr;

	    xr = GetRate(xc);
	    yr = GetRate(yc);

	    return -Sim.FloatCompare(xr, yr);
	}
    }

}
