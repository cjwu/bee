#undef OLD_CODE
using System;
using System.IO;
using System.Collections;
using System.Diagnostics;

// This file contains the MOST IMPORTANT part of the 
// entire simulator; viz. the modeling of each node 
// within the system. See class Node.

namespace Simulator 
{
    // Link capacities
    public class LinkCap
    {
	public float down_bw, up_bw;
	public LinkCap(float d, float u) 
	{
	    down_bw = d;
	    up_bw = u;
	}
    }

    public class LinkCapComparer : IComparer
    {
	public int Compare(Object x, Object y)
	{
	    LinkCap xl = (LinkCap) x;
	    LinkCap yl = (LinkCap) y;

	    float xr = xl.up_bw, yr = yl.up_bw;

	    return Sim.FloatCompare(xr, yr);
	}
    }

    // Just a struct which holds together information about pieces...
    class PieceInfo 
    {
	public bool is_downloading = false;
	public bool have           = false;
	public long downloaded_bits = 0;
	public int  availability   = 0;
    }

    public enum NodeStatus 
    {
	STATUS_SEED,
	STATUS_DOWNLOADER
    }

    public class Node 
    {
	// NOTE: the terms "piece" and "block" are used interchangeably. 
	// In real BitTorrent, they are different. So there is potential 
	// for confusion :)
	
	private LinkCap   m_LinkCap;                    // link capacities
	public float UpCap 
	{
	    get { return m_LinkCap.up_bw; }
	    set { m_LinkCap.up_bw = value; }
	}

	public float DownCap 
	{
	    get { return m_LinkCap.down_bw; }
	    set { m_LinkCap.down_bw = value; }
	}

	private  int       m_ID;                        // unique identifier of the node
	public   int ID 
	{
	    get { return m_ID; }
	    set { m_ID = value; }
	}
	public  long      m_JoinTime, m_LifeTime;       // mostly useless variables
	public  bool      Alive = true;                 // self-explanatory; sometimes references to nodes
	                                                // "hang-around" because of sloppy
							// programming (which in turn is due to the
							// garbage-collection niceties of C#)

	public  int       m_Distance;                   // distance from the seed in the connectivity graph

	private Hashtable m_Connections = null;         // hashtable of connections to peers
	private ArrayList m_Uploads = null;             // list of ongoing uploads
	private ArrayList m_Downloads = null;           // list of ongoing downloads

	private Oracle    m_Oracle      = null;         // ?
	private Sim       m_Simulator   = null;         
	private DemuxManager m_LinkDemux = null;        // see DemuxManager.cs for details
	private Choker    m_Choker      = null;         // bittorrent choker

	private PieceInfo[] m_PieceInfoArray = null;    // information about all the blocks of the file
	private int[]     m_ServeCount = null;          // how many times have i served each block? this could have been put in PieceInfo 
	private int       m_NPieces = 0, m_ToFinishPieces = 0;  // self-explanatory

	private int[] m_Plist = null;                   // utility arrays used for sorting pieces by their availability, etc.
	private ServeCountComparer m_ServeCountComparer = null;
	private PieceAvailComparer m_PieceAvailComparer = null;

	private int m_SentBlocksAfterSeedify = 0;       // how many blocks did i send after becoming a seed
	private bool m_BecameSeed = false;

	public int ToFinishPieces {
	    get { return m_ToFinishPieces; }
	}

	private int       m_FinishedPieces = 0;         // #finished blocks
	private bool      m_AmSeed      = false;        
	public  bool      IsSeed 
	{ 
	    get { return m_AmSeed; }		
	}

	public  int NUploads 
	{
	    get { return m_Uploads.Count; }
	}
	public  int NDownloads 
	{ 
	    get { return m_Downloads.Count; }
	}
	public int NFinishedPieces { get { return m_FinishedPieces; } }
	public int NPieces { get { return m_NPieces; } }

	// information about the block-level TFT thing
	private long      m_TotalReceived = 0;
	private long      m_TotalSent     = 0;
	public long TotalSent { get { return m_TotalSent; } }
	public long TotalReceived { get { return m_TotalReceived; } }
	
	private ArrayList m_WaitingQueue = null, m_OngoingQueue = null;  
	
	// the waiting queue contains people who are potentially waiting for an upload from you
	// the ongoing queue contains people who are actively downloading from you right now

	//////////////////////////////////////////////////////////////////////////
	public static int[] s_GlobalAvailArray = null;    // an array to keep track of true "global rarest" status of blocks

	/// <summary>
	/// MAJOR HACK TO SPEED THINGS UP
	/// </summary>
	public static bool[,] s_GlobalChokingArray = null; // avoids hash-table accesses by making a huge 2-d array. an entry in position (x,y) being TRUE indicates that peer "x" is choking peer "y"
	public static int     MAX_NODES = 1100;            // hard-coded limit for the above array. SADNESS.

	private int[] m_ChoosingOrder = null;              // fix on a choosing order -- see SimParameters.ChoosingPolicy documentation.

	public ICollection GetConnections() 
	{
	    return m_Connections.Values;
	}
	public Node(Sim s, Oracle ora, int n_pieces)
	{
	    if (s_GlobalChokingArray == null)
	    {
		s_GlobalChokingArray = new bool[Node.MAX_NODES, Node.MAX_NODES];
		for (int i = 0; i < Node.MAX_NODES; i++)
		    for (int j = 0; j < Node.MAX_NODES; j++)
			s_GlobalChokingArray[i, j] = true;
	    }
	    m_Simulator      = s;
	    m_Oracle         = ora;
	    m_LinkCap        = new LinkCap(0, 0);
	    m_Connections    = new Hashtable();

	    m_NPieces        = (int) (n_pieces * SimParameters.FEC);
	    m_ToFinishPieces = n_pieces;
	    m_PieceInfoArray = new PieceInfo[m_NPieces];
	    for (int i = 0; i < m_NPieces; i++) 
		m_PieceInfoArray[i] = new PieceInfo();

	    m_ServeCount = new int[m_NPieces];
	    for (int i = 0; i < m_NPieces; i++) 
		m_ServeCount[i] = 0;


	    m_Plist = new int[m_NPieces];
	    for (int i = 0; i < m_NPieces; i++) 
		m_Plist[i] = 0;
	    m_ServeCountComparer = new ServeCountComparer();
	    m_PieceAvailComparer = new PieceAvailComparer(this);

	    m_Uploads        = new ArrayList();
	    m_Downloads      = new ArrayList();

	    m_LinkDemux      = new DemuxManager(this);
	    m_Choker         = new Choker(this, m_Simulator);

	    if (SimParameters.DoingBlockTFT()) 
	    {
		m_WaitingQueue = new ArrayList();
		m_OngoingQueue = new ArrayList();
	    }
	}

	public bool HasPiece(int piece) { return m_PieceInfoArray[piece].have; }
	public bool IsDownloading(int piece) { return m_PieceInfoArray[piece].is_downloading; }
	public int  GetAvailability(int piece) { return m_PieceInfoArray[piece].availability; }
	public bool UnFinished(int piece) { return m_PieceInfoArray[piece].downloaded_bits > 0; }
	public bool IsPeer(int id) { return m_Connections.ContainsKey(id); }
	public int  GetServeCount(int piece) { return m_ServeCount[piece]; }

	public void BecomeSeed() 
	{
	    m_AmSeed = true;
	    for (int i = 0; i < m_NPieces; i++) 
	    {
		m_PieceInfoArray[i].have = true;
		m_PieceInfoArray[i].is_downloading = false;
	    }
	    m_FinishedPieces = m_ToFinishPieces;
	}


	public void SanityCheck()
	{
	    if (!Alive)
		return;

	    foreach (Connection conn in m_Connections.Values)
	    {
		if (!conn.Peer.IsPeer(ID))
		{
		    throw new Exception("1-way connection?");
		}
	    }
	    foreach (Connection conn in m_Connections.Values)
	    {
		if (!conn.Peer.Alive) {
		    throw new Exception("peer dead?");
		}
	    }

	    Hashtable b = new Hashtable();
	    foreach (Connection conn in m_Connections.Values)
	    {
		if (b.ContainsKey(conn.Peer.ID)) {
		    Console.WriteLine("WHAT ON EARTH? {0} repeated...", conn.Peer.ID);
		}
		else
		    b[conn.Peer.ID] = 1;
	    }
	    b.Clear();

	    foreach (Transfer t in m_Uploads)
	    {
		if (b.ContainsKey(t.To.ID)) 
		{
		    Console.Write("Hellooo--- repeated upload from me: {0} peer: {1} ", ID, t.To.ID);
		    foreach (Transfer tm in m_Uploads) {
			Console.Write(" {0};", tm.To.ID);
		    }
		    Console.WriteLine("");
		}
		else
		    b[t.To.ID] = 1;
	    }
	    b.Clear();
	    foreach (Transfer t in m_Downloads)
	    {
		if (b.ContainsKey(t.From.ID)) 
		{
		    Console.Write("Hellooo--- repeated download to me: {0} peer: {1}", ID, t.From.ID);
		    foreach (Transfer tm in m_Downloads) {
			Console.Write(" {0};", tm.From.ID);
		    }
		    Console.WriteLine("");
		}
		else
		    b[t.From.ID] = 1;
	    }

	}

	public bool TransferringFrom(Node peer)
	{
	    foreach (Transfer t in m_Downloads)
	    {
		if (t.From.ID == peer.ID)
		    return true;
	    }
	    return false;
	}

	public bool TransferringTo(Node peer)
	{
	    foreach (Transfer t in m_Uploads)
	    {
		if (t.To.ID == peer.ID)
		    return true;
	    }
	    return false;
	}

	public bool IsChoking(Node peer) 
	{
	    Connection conn = (Connection) m_Connections[peer.ID];
	    if (conn == null) 
	    { // weird! return 'choked' so that this connection is basically "cut-off" for the other end, anyways
		return true;  
	    }
	    return conn.IsChoking();
	}

	public bool IsInterested(Node peer) 
	{
	    Connection conn = (Connection) m_Connections[peer.ID];
	    if (conn == null) 
	    { // weird! return 'not interested' so that this connection is basically "cut-off" for the other end, anyways
		return false;  
	    }
	    return conn.IsInterested();
	}

	public void UpdateDownloadRate(Node peer, float amount  /* in kilobits */ )
	{
	    Connection conn = (Connection) m_Connections[peer.ID];
	    if (conn != null) 
		conn.UpdateDownloadRate(amount);
	}

	public void UpdateUploadRate(Node peer, float amount /* in kilobits */) 
	{
	    Connection conn = (Connection) m_Connections[peer.ID];
	    if (conn != null) 
		conn.UpdateUploadRate(amount);
	}

	public void GotUnchoke(Node peer)
	{
	    Connection conn = (Connection) m_Connections[peer.ID];
	    if (conn != null)
		DownloadIfPossible(conn);
	}
	public void AssignBlocks(int nblocks)
	{
	    int[] a = new int[m_NPieces];
	    for (int i = 0; i < m_NPieces; i++) 
		a[i] = i;
	    m_Simulator.Shuffle(a);

	    for (int i = 0; i < nblocks; i++) 
	    {
		int piece = a[i];

		m_PieceInfoArray[piece].downloaded_bits = SimParameters.blockSize << 10;
		m_PieceInfoArray[piece].have = true;
		m_PieceInfoArray[piece].is_downloading = false;
		m_PieceInfoArray[piece].availability = 1;

		m_FinishedPieces++;
	    }
	}

	/// <summary>
	/// This is where each node starts its life. Gets the initial list of peers,
	/// Schedules the choker and each connection...
	/// </summary>
	public void JoinNetwork() 
	{
	    // Console.WriteLine("node {0} starting to join network", m_ID);
	    Logger.node_log(this, LogEvent.JOIN, m_AmSeed);
	    if (!m_AmSeed)
	    {
		if (SimParameters.nInitialBlocks > 0) 
		{
		    AssignBlocks(SimParameters.nInitialBlocks);
		}
		if (SimParameters.choosingPolicy == ChoosingPolicy.RAND_PERMUTATION)
		{
		    m_ChoosingOrder = new int[m_NPieces];
		    for (int i = 0; i < m_NPieces; i++) 
			m_ChoosingOrder[i] = i;
		    m_Simulator.Shuffle(m_ChoosingOrder);
		}

		ArrayList peers = m_Oracle.GetInitialPeerList(this);    // the oracle will decide how many nodes I should be getting, etc.

		foreach (Node p in peers)
		    ConnectToPeer(p);
	    }

	    if (SimParameters.DoingBlockTFT()) 
	    {
		OnUploadAvailable();
	    }
	    else 
	    {
		m_Simulator.RaiseSimulationEvent(0, new ChokerEvent(m_Choker));
	    }
	}

	public Connection GetConnection(int id)	{return (Connection) m_Connections[id];}

	// I am trying to connect to somebody...
	private bool ConnectToPeer(Node peer)
	{
	    if (!peer.HandlePeerConnect(this))
		return false;

	    if (!AddPeer(peer))
		return true;

	    // ok - let's associate these "connection instances" with each other
	    Connection conn = (Connection) m_Connections[peer.ID];
	    Connection oconn = peer.GetConnection(this.ID);

	    conn.OtherEndConnection = oconn;
	    oconn.OtherEndConnection = conn;

	    // Update Piece availability
	    for (int i = 0; i < m_NPieces; i++) 
	    {
		if (peer.HasPiece(i))
		    UpdatePieceAvail(peer, i, false);
	    }
	    return true;
	}

	// Somebody is trying to connect to us... this is almost completely the same as the above
	// routine...
	public bool HandlePeerConnect(Node peer)
	{
	    //if (m_Connections.Count >= SimParameters.maxPeersThreshold)
	    //	return false;

	    if (!AddPeer(peer))
		return true;

	    for (int i = 0; i < m_NPieces; i++) 
		if (peer.HasPiece(i))
		    UpdatePieceAvail(peer, i, false);

	    if (SimParameters.DoingBlockTFT())
		m_Simulator.RaiseSimulationEvent(0, new AnEvent(this));

	    m_Simulator.RaiseSimulationEvent(0, new TooManyPeersEvent(this));

	    return true;
	}

	public bool AddPeer(Node peer)
	{
	    if (m_Connections[peer.ID] != null) 
	    {
		Debug.WriteLine("WARNING: The peer was already added?? Hmm...");
		return false;
	    }

	    Connection conn = new Connection(this, peer, m_Simulator, m_NPieces);


	    m_Connections[peer.ID] = conn;
	    if (SimParameters.DoingBlockTFT()) 
		m_WaitingQueue.Add(conn);
	    else
		m_Choker.AddConnection(conn);

	    return true;
	}

	public float GetNewDownloadRate() 
	{
	    return m_LinkDemux.GetNewTransferRate(m_Downloads, DownCap);
	}

	public float GetNewUploadRate() 
	{
	    return m_LinkDemux.GetNewTransferRate(m_Uploads, UpCap);
	}

	// Try to ramp up a transfer to a higher rate. This may affect other ongoing transfers!
	// 
	public float TryRampUp(Transfer tran, float newRate)
	{
	    ArrayList transfers;
	    float     total;

	    if (tran.IsDownload(this)) 
	    {
		transfers = m_Downloads;
		total = DownCap;
	    }
	    else
	    {
		transfers = m_Uploads;
		total = UpCap;
	    }

	    return m_LinkDemux.TryRampUp(tran, transfers, total, newRate);
	}

	public void AdjustUploadRates()
	{
	    m_LinkDemux.AdjustTransferRates(m_Uploads, UpCap);
	}

	public void AdjustDownloadRates()
	{
	    m_LinkDemux.AdjustTransferRates(m_Downloads, DownCap);
	}

	public void AddUpload(Transfer tran) 
	{
	    m_Uploads.Add(tran);
	}

	public void AddDownload(Transfer tran)
	{
	    m_Downloads.Add(tran);
	}

	private float GetTotalTransferRate(ArrayList transfers)
	{
	    float tot = 0.0F;
	    foreach (Transfer tran in transfers)
	    {
		tot += tran.Rate;
	    }
	    return tot;
	}
	public float GetTotalUploadRate() 
	{
	    return GetTotalTransferRate(m_Uploads);
	}
	public float GetTotalDownloadRate() 
	{
	    return GetTotalTransferRate(m_Downloads);
	}

	public void FinishDownload(Transfer tran)
	{
	    m_Downloads.Remove(tran);
	}

	public void FinishUpload(Transfer tran)
	{
	    Debug.Assert(m_Uploads.Contains(tran), " Stopping a non-existing upload? " );
#if DEBUG
	    if (Alive)
		SanityCheck();
#endif

	    tran.SenderConnection.FinishUpload();
	    m_Uploads.Remove(tran);

	    if (SimParameters.DoingBlockTFT()) 
	    {
		m_OngoingQueue.Remove(tran.SenderConnection);

		Connection conn = (Connection) m_Connections[tran.To.ID];
		if (conn != null) 
		{
		    conn.Choke();
		    m_WaitingQueue.Add(conn);
		}
	    }
	}

	// An upload has just finished => I have a slot available to give to people... 
	// I being a nice guy, will allow everybody an even chance to get a piece of 
	// the pie. So, pick the first k guys from my list of connections and give them 
	// a chance and then shove them at the back of the list...
	//
	// ONLY USED for block-level and group-TFTs. otherwise, the choker drives 
	// the decisions for giving upload slots.
	public void OnUploadAvailable()
	{
	    ArrayList tmp = new ArrayList(), new_uploads = new ArrayList();
	    int to_offer = SimParameters.maxUploads - NUploads;

#if DEBUG
	    SanityCheck();
#endif

	    while (to_offer > 0 && m_WaitingQueue.Count > 0)
	    {
		Connection conn = (Connection) m_WaitingQueue[0];
		m_WaitingQueue.RemoveAt(0);
		Debug.Assert(!conn.IsUploading());

		if (conn.Peer.IsInterested(this)) 
		{
		    new_uploads.Add(conn);
		    to_offer--;
		}
		else {
		    tmp.Add(conn);
		}
	    }

	    if (NUploads == 0 && m_Simulator.NumNodes() > 1) {
		// This is a critical case and OnUploadAvailable may not get called. Just make sure it does!
		m_Simulator.RaiseSimulationEvent(1000, new AnEvent(this));
	    }

	    m_WaitingQueue.AddRange(tmp);
	    m_WaitingQueue.AddRange(new_uploads);
	    foreach (Connection conn in new_uploads)
	    {
		conn.Unchoke();
	    }
	}

	public void SendPiece(Node peer, int piece, long amount)
	{
	    float rate;

	    Debug.Assert(HasPiece(piece), "I do not have the requested piece?");
	    Debug.Assert(!peer.IsSeed);
	    Debug.Assert(!peer.HasPiece(piece), " peer has it?");
	    Debug.Assert(peer.IsDownloading(piece), " peer aint downloading?");

#if DEBUG
	    SanityCheck();
#endif

	    rate = Math.Min(GetNewUploadRate(), peer.GetNewDownloadRate());

	    // Logger.node_log(this, LogEvent.SEND, piece, peer);
	    UpdateUploadRate(peer, (float) amount / 1024.0F);

	    Connection conn = (Connection) m_Connections[peer.ID];
	    if (SimParameters.DoingBlockTFT()) {
		m_WaitingQueue.Remove(conn);
		m_OngoingQueue.Add(conn);
	    }

	    m_ServeCount[piece]++;

	    Transfer ntran = conn.StartUpload(m_Simulator, piece, amount, rate);

	    AddUpload(ntran);
	    peer.AddDownload(ntran);

	    if (m_BecameSeed) {
		m_SentBlocksAfterSeedify++;
		if (m_SentBlocksAfterSeedify > SimParameters.stayForBlocks) 
		    DoRealFinish();
	    }
	}

	public static Hashtable root_unique = new Hashtable();
	public static bool printed = false;

	public void DoRealFinish() 
	{
	    m_Choker.Done();
	    m_Simulator.RaiseSimulationEvent(0, new KillNodeEvent(this));
	}

	public void DoFinish()
	{
	    Logger.node_log(this, LogEvent.FINISHED);
	    double prob = Sim.rng.NextDouble();
	    if (prob <= SimParameters.seedLeavingProbability) 
	    {
		m_Choker.Done();
		m_Simulator.RaiseSimulationEvent(0, new KillNodeEvent(this));   // DEATH TO ME! :)
		return;
	    }
	    Logger.node_log(this, LogEvent.SEEDIFY);
	    m_AmSeed = true;
	    m_BecameSeed = true;
	    m_SentBlocksAfterSeedify = 0;
	}

	// A transfer just finished or was aborted
	// Records the bytes that were sent to this particular peer
	public void UpdateSent(Node peer, int piece, long amount)
	{
	    m_TotalSent += amount;

	    Connection conn = (Connection) m_Connections[peer.ID];
	    if (conn == null)
		return;
	    conn.Uploaded += amount;
	}

	class DoFinishEvent : TimerEvent {
	    Node m_Node = null;
	    public DoFinishEvent(Node n) { 
		m_Node = n;
	    }

	    public void process(long timeNow) {
		m_Node.DoFinish();
	    }
	}

	public bool doneServing = false; 

	public void ReceivePiece(Node peer, int piece, long amount) 
	{
	    Debug.Assert(!HasPiece(piece), " Receiving piece already there!");
	    Debug.Assert(!m_AmSeed, " A seed receiving data, what on earth is wrong!");
#if DEBUG
	    SanityCheck();
#endif

	    m_PieceInfoArray[piece].is_downloading = false;
	    m_PieceInfoArray[piece].downloaded_bits += amount;

	    m_TotalReceived += amount;

	    if ( AlmostFinished(piece) )
	    {
		m_PieceInfoArray[piece].have = true;
		m_FinishedPieces++;
		Logger.node_log(this, LogEvent.RECV, piece, peer);

		if (peer.ID == 1) 
		{
		    if (!Node.printed) {
			if (!Node.root_unique.ContainsKey(piece))
			    Node.root_unique[piece] = 1;

			if (Node.root_unique.Count == m_NPieces) {
			    Console.WriteLine("");
			    Console.WriteLine("----- ROOT HAS SERVED ALL PIECES {0}", m_Simulator.TimeNow());
			    Console.WriteLine("");
			    Node.printed = true;
			}
		    }

		    if (SimParameters.originServerLoad > 0 &&
			    !peer.doneServing) {
			int totServed = 0;
			for (int i = 0; i < m_NPieces; i++) {
			    totServed += peer.GetServeCount(i);
			}
			if ((SimParameters.choosingPolicy == ChoosingPolicy.RAND_PERMUTATION && Node.printed) 
				|| (SimParameters.choosingPolicy == ChoosingPolicy.LR && 
				    totServed >= m_ToFinishPieces * SimParameters.originServerLoad)) {
			    Console.WriteLine("----- Seed has served its part ... departing AT {0}", m_Simulator.TimeNow());
			    m_Simulator.RaiseSimulationEvent(0, new DoFinishEvent(peer));
			    peer.doneServing = true;
			}
		    }

		}
	    }

	    UpdateDownloadRate(peer, (float) (amount / 1024.0) );   // the rate is always in kilobits

	    // The peer could have died while it was transferring this last piece.... 
	    Connection conn = (Connection) m_Connections[peer.ID];
	    if (conn != null) 
	    {
		conn.Downloaded += amount;
		conn.IsDownloading = false;
	    }

	    if (m_PieceInfoArray[piece].have) 
	    {
		if (conn != null)
		    conn.RecvdPiece(piece);

		// inform everybody I have the piece!
		foreach (Connection aconn in m_Connections.Values) {
		    aconn.Peer.UpdatePieceAvail(this, piece, true);

		    // WOAH! what a bug  didn't have this before... - Ashwin [9/15/2004]
		    aconn.RecvdPiece(piece);
		}
		Node.s_GlobalAvailArray[piece]++;

		if (m_FinishedPieces == m_ToFinishPieces)
		{
		    DoFinish();
		    return;	
		}
	    }


	    if (!m_AmSeed && !Finished() ) 
	    {
		bool started_download = false;

		if (conn != null)
		    started_download = DownloadIfPossible(conn);

		if (!started_download)          // There are "slots" @ my end and @ the sender's end; so adjust rates...
		{
		    AdjustDownloadRates();
		    peer.AdjustUploadRates();
		}
	    }
	}

	public void UpdatePieceAvail(Node peer, int piece, bool start_download)
	{
	    m_PieceInfoArray[piece].availability++;

	    Connection conn = (Connection) m_Connections[peer.ID];
	    if (conn == null)
		return;

	    conn.UpdatePieceInterest(piece);

	    if (start_download) {
		// Likely that we have a new-found interest in this peer, so get GOING!
		if (conn.IsInterested())
		    DownloadIfPossible(conn);
	    }
	}

	public void RemovePeer(Node peer)
	{
	    Connection conn = (Connection) m_Connections[peer.ID];
	    if (conn == null) 
	    {
		Debug.WriteLine("WARNING: handling death of a zombie??");
		return;
	    }

	    for (int i = 0; i < m_NPieces; i++)
	    {
		if (peer.HasPiece(i))
		    m_PieceInfoArray[i].availability--;
	    }

	    m_Connections.Remove(peer.ID);

	    if (SimParameters.DoingBlockTFT()) 
	    {
		m_WaitingQueue.Remove(conn);
		m_OngoingQueue.Remove(conn);
	    }
	    else
		m_Choker.RemoveConnection(conn);


	    m_Simulator.RaiseSimulationEvent(0, new ChokeConnectionEvent(conn));

	    // Check if we have gone below the threshold, in which case request more peers, hoohoo!
	    // for a seed, the threshold is a little higher. the seed should connect to more peers in general.
	    if (m_AmSeed && m_Connections.Count < SimParameters.nInitialPeers
		    || !m_AmSeed && m_Connections.Count < SimParameters.minPeersThreshold)
		m_Simulator.RaiseSimulationEvent(0, new MorePeersEvent(this)); 
	}

	public void GetMorePeers()
	{
	    ArrayList newPeers = m_Oracle.GetMorePeers(this);
	    foreach (Node np in newPeers) 
	    {
		if (m_Connections.ContainsKey(np.ID))
		    continue;

		ConnectToPeer(np);
		if (m_Connections.Count > SimParameters.maxPeersThreshold)
		    break;
	    }

	}

	public void CheckTooManyPeers() 
	{
	    int nPeers = m_Connections.Count;
	    if (nPeers <= SimParameters.maxPeersThreshold)
		return;

	    int toDrop = nPeers - SimParameters.maxPeersThreshold;

	    {
		Connection[] arr = new Connection[nPeers];
		int   i = 0;
		foreach (Connection conn in m_Connections.Values) 
		{
		    arr[i] = conn;
		    i++;
		}
		m_Simulator.Shuffle(arr);
		for (i = 0; i < toDrop; i++) 
		{
		    RemovePeer(arr[i].Peer);
		    arr[i].Peer.RemovePeer(this);
		}
	    }
	}

	public bool FastCanTransferTo(Connection conn)
	{
	    if (m_AmSeed)
		return true;
	    if (conn == null) 
		return false;                              // defensive programming!

	    if (SimParameters.fairness == FairnessMechanism.OVERALL_BLOCK_TFT)
	    {
		if (m_TotalSent <= m_TotalReceived)
		    return true;
		long extra = m_TotalSent - m_TotalReceived;
		return (extra <= SimParameters.fairnessThreshold * SimParameters.blockSizeInBits);
	    }

	    if (SimParameters.fairness == FairnessMechanism.PAIRWISE_BLOCK_TFT)
	    {
		long extra = conn.Uploaded - conn.Downloaded;
		return (extra <= SimParameters.fairnessThreshold * SimParameters.blockSizeInBits);
	    }
	    else 
	    {
		throw new Exception("This should never be called");
	    }
	}

	public bool CanTransferTo(Node peer)
	{
	    Connection conn = (Connection) m_Connections[peer.ID];
	    return FastCanTransferTo(conn);
	}

	private bool CanTransferFrom(Connection conn)
	{
	    Node peer = conn.Peer;

	    if (!SimParameters.DoingBlockTFT()) {
		if (SimParameters.spPairwiseTFT && !peer.IsSeed) {
		    // Check if we have downloaded far too much :)
		    long extra = conn.Downloaded - conn.Uploaded;
		    if (extra > SimParameters.fairnessThreshold * SimParameters.blockSizeInBits) 
			return false;
		    // else fall down....
		}
		return !peer.IsChoking(this) && IsInterested(peer);
	    }

	    return peer.NUploads < SimParameters.maxUploads && 
		!peer.IsChoking(this) && IsInterested(peer) && 
		peer.CanTransferTo(this);
	}

	private bool Finished()
	{
	    if (m_AmSeed)
		return false;

	    if (m_FinishedPieces < m_ToFinishPieces)
		return false;

	    return true;
	}

	private int GetUnfinishedPieces() {
	    int tot = 0;

	    for (int i = 0; i < m_NPieces; i++) {
		PieceInfo info = m_PieceInfoArray[i];

		if (!info.have && info.downloaded_bits > 0)
		    tot++;
	    }
	    return tot;
	}

	public bool CheckReallyInterested(Node peer)
	{
	    if (!Alive)
		return false;

	    for (int i =0 ; i < m_NPieces; i++)
	    {
		if (!HasPiece(i) && peer.HasPiece(i) && !IsDownloading(i))
		    return true;
	    }
	    return false;
	    // throw new Exception("i am not really interested!!");
	}
	public void Dump(StreamWriter stream)
	{
	    int interested = 0, allowed = 0, useful = 0;
	    int uinterested = 0, uallowed = 0, uuseful = 0;

	    AdjustUploadRates();

	    // Logger.ulog("##### {0} d{1}/{2} u{3}/{4}  up: ", this.ID, GetTotalDownloadRate(), DownCap, GetTotalUploadRate(), UpCap);
	    Debug.Assert(m_FinishedPieces <= m_ToFinishPieces);

	    foreach (Connection conn in m_Connections.Values) 
	    {
		bool i = conn.IsInterested();
		//				bool i = CheckReallyInterested(conn.Peer);

		bool a = (SimParameters.DoingBlockTFT() && conn.Peer.CanTransferTo(this)) 
		    || (!SimParameters.DoingBlockTFT() && !conn.Peer.IsChoking(this));

		if (i) 
		{
		    //	CheckReallyInterested(conn.Peer);
		    interested++;
		}
		if (a)
		    allowed++;
		if (i && a)
		    useful++;

		bool ui = conn.Peer.IsInterested(this);
		// bool ui = conn.Peer.CheckReallyInterested(this);

		bool ua = (SimParameters.DoingBlockTFT() && CanTransferTo(conn.Peer))
		    || (!SimParameters.DoingBlockTFT() && !IsChoking(conn.Peer));

		if (ui)
		{
		    //	conn.Peer.CheckReallyInterested(this);
		    uinterested++;
		}
		if (ua)
		    uallowed++;
		if (ui && ua)
		    uuseful++;

		// if (uuseful > NUploads)
		//	throw new Exception("what a pathetic state of affairs");
	    }

	    stream.Write("{0} #d {1} {2} #u {3} {4} p {5} {6} s {7} #p {8} {9} {10} {11} {12} {13} {14} D {15}", this.ID, 
		    m_Downloads.Count, GetTotalDownloadRate(), 
		    m_Uploads.Count,   GetTotalUploadRate(),
		    m_FinishedPieces,  GetUnfinishedPieces(),
		    (m_AmSeed ? "1" : "0"), m_Connections.Count,
		    interested, allowed, useful, 
		    uinterested, uallowed, uuseful,
		    (m_Distance == -1 ? 999 : m_Distance));

#if UNDEF			
	    stream.Write(" -- ");
	    foreach (Connection conn in m_Connections.Values) {
		if (!conn.IsChoking())
		    stream.Write("{0} ", conn.Peer.ID);
		// stream.Write("{0}:{1}:", conn.Peer.ID, (conn.IsChoking() ? "chok" : "OPEN"));
	    }

	    /*
	       stream.Write("dn: ");
	       foreach (Transfer t in m_Downloads) 
	       {
	       stream.Write("{0}:p{1}:r{2} ", t.From.ID, t.Piece, (int) t.Rate);
	       }
	     */
	    stream.Write(" UP ");
	    foreach (Transfer t in m_Uploads) 
	    {
		stream.Write("{0}:p{1}:r{2} ", t.To.ID, t.Piece, (int) t.Rate);
	    }
#endif
	    stream.WriteLine("");
	}

	private bool AlmostFinished(int piece) 
	{
	    return m_PieceInfoArray[piece].downloaded_bits > SimParameters.blockSizeInBits ||
		Math.Abs(m_PieceInfoArray[piece].downloaded_bits - SimParameters.blockSizeInBits) < 100;
	}

	public bool DownloadIfPossible(Connection conn)
	{
	    if (m_AmSeed)
		return false;

	    if (conn.IsDownloading)
		return false;

	    if (CanTransferFrom(conn)) 
	    {
		int piece = FindPieceToDownload(conn);

		if (piece == -1) {
		    // Wrong assertion! :) [7/27/2004]
		    /*
		       for (int i = 0; i < m_Have.Length; i++)
		       Debug.Assert(m_Have[i] || m_Downloading[i], "there *IS* a piece to download!! and I didn't find it!!");
		     */
		    // m_Simulator.RaiseSimulationEvent(1000, new TryDownloadEvent(this, conn));
		    return false;
		}
		// Logger.log(this + " decides to download piece " + piece + " from peer " + conn.Peer);
		// Console.WriteLine("Node [" + this.ID + "] decides to download piece " + piece + " from peer node[" + conn.Peer.ID + "]");

		Debug.Assert(!HasPiece(piece), " why am i downloading? ");
		Debug.Assert(!AlmostFinished(piece), " Piece is almost finished downloading; why am I downloading??");

		m_PieceInfoArray[piece].is_downloading = true;

		// Console.WriteLine("{0}: to download [p{1}:{2}] from {3}", ID, piece, SimParameters.blockSizeInBits - m_PieceInfoArray[piece].downloaded_bits, conn.Peer.ID);

		conn.IsDownloading = true;

		// just so that "interest" gets reflected immediately... perhaps does something good
		// to local rarest estimates of my neighbors.

		conn.RecvdPiece(piece);
		conn.Peer.SendPiece(this, piece, SimParameters.blockSizeInBits - m_PieceInfoArray[piece].downloaded_bits);
		return true;
	    }
	    else 
	    {
		// Just to be safe...  - Ashwin [9/15/2004]
		// if (!conn.Peer.IsChoking(this)) 
		//    m_Simulator.RaiseSimulationEvent(1000, new TryDownloadEvent(this, conn));

		// when should we re-check? only when the choking and 'interest' status of the connection changes.
		// this is possible only when the other guy receives a piece OR he unchokes. 
		// so ReceivePiece and Choker.ChokeUnchoke should schedule "DownloadIfPossible" as and when needed.
		return false;
	    }
	}

	private int  FindPieceToDownload(Connection conn)
	{
	    // ArrayList plist = new ArrayList();
	    Node      peer  = conn.Peer;
	    int       alen  = 0;

	    for (int i = 0; i < m_NPieces; i++) {
		if (!m_PieceInfoArray[i].have && !m_PieceInfoArray[i].is_downloading && peer.HasPiece(i)) {
		    // plist.Add(i);
		    m_Plist[alen++] = i;
		}
	    }


	    // if (plist.Count <= 0)
	    if (alen <= 0)
		return -1;

	    if (SimParameters.choosingPolicy == ChoosingPolicy.LR)
	    {
		if (m_FinishedPieces < SimParameters.rarestFirstCutoff) 
		{
		    // return (int) plist[Sim.rng.Next(plist.Count)];
		    return (int) m_Plist[Sim.rng.Next(alen)];
		}
		else 
		{
		    if (SimParameters.smartSeed && peer.IsSeed) 
		    {
			// plist.Sort(new ServeCountComparer(peer));
			m_ServeCountComparer.SetSeed(peer);
			Array.Sort(m_Plist, 0, alen, m_ServeCountComparer);

			int max_same = 1;
			// int sc = peer.GetServeCount((int) plist[0]);
			int sc = peer.GetServeCount((int) m_Plist[0]);

			for (int i = 1; i < alen /* plist.Count */; i++) 
			{
			    // int sc2 = peer.GetServeCount((int) plist[i]);
			    int sc2 = peer.GetServeCount((int) m_Plist[i]);
			    if (sc == sc2) 
				max_same++;
			}
			// Console.WriteLine("max_same={0} sc={1}", max_same, sc);
			// return (int) plist[Sim.rng.Next(max_same)];
			return (int) m_Plist[Sim.rng.Next(max_same)];
		    }
		    else 
		    {
			Array.Sort(m_Plist, 0, alen, m_PieceAvailComparer);
			int max_same = 1;

			PieceInfo inf = m_PieceInfoArray[(int) m_Plist[0]];

			for (int i = 1; i < alen /* plist.Count */; i++) 
			{
			    PieceInfo inf2 = m_PieceInfoArray[(int) m_Plist[i]];
			    if (inf.availability == inf2.availability)
				max_same++;
			}
			return (int) m_Plist[Sim.rng.Next(max_same)];
		    }
		}
	    }
	    else 
	    {
		Debug.Assert(SimParameters.choosingPolicy == ChoosingPolicy.RAND_PERMUTATION);
		Array.Sort(m_Plist, 0, alen, new ChoosingOrderComparer(m_ChoosingOrder));
		return (int) m_Plist[0];
	    }
	}

	class ServeCountComparer : IComparer
	{
	    Node m_Seed = null;

	    public ServeCountComparer() {
		m_Seed = null;
	    }

	    public ServeCountComparer(Node s) { 
		m_Seed = s;
	    }

	    public void SetSeed(Node s) {
		m_Seed = s;
	    }

	    public int Compare(object x, object y)
	    {
		int ix = (int) x, iy = (int) y;
		int sx = m_Seed.GetServeCount(ix), sy = m_Seed.GetServeCount(iy);

		if (sx < sy)
		    return -1;
		if (sx > sy)
		    return 1;
		return 0;
	    }
	}

	class ChoosingOrderComparer : IComparer
	{
	    int[] m_Ordering;
	    public ChoosingOrderComparer(int[] ordering)
	    {
		m_Ordering = ordering;
	    }
	    public int Compare(object x, object y)
	    {
		int ix = (int) x, iy = (int) y;
		return m_Ordering[ix].CompareTo(m_Ordering[iy]);
	    }
	}

    }

    public class AnEvent : TimerEvent
    {
	Node m_Node = null;

	public AnEvent(Node n) {
	    m_Node = n;
	}
	public void process(long timeNow)
	{
	    if (m_Node.Alive)
		m_Node.OnUploadAvailable();
	}
    }

    public class MorePeersEvent : TimerEvent
    {
	Node m_Node = null;
	bool tmb = SimParameters.trackerMatchesBws; 

	public MorePeersEvent(Node n) 
	{
	    m_Node = n;
	}
	public MorePeersEvent(Node n, bool t)
	{
	    m_Node = n;
	    tmb = t;
	}

	public void process(long timeNow)
	{
	    // HACK: change tracker bandwidth behavior if requested

	    if (m_Node.Alive) {
		bool old = SimParameters.trackerMatchesBws;
		SimParameters.trackerMatchesBws = tmb;
		m_Node.GetMorePeers();
		SimParameters.trackerMatchesBws = old;
	    }
	}
    }

    public class TooManyPeersEvent : TimerEvent
    {
	Node m_Node = null;

	public TooManyPeersEvent(Node n) 
	{
	    m_Node = n;
	}
	public void process(long timeNow)
	{
	    if (m_Node.Alive)
		m_Node.CheckTooManyPeers();
	}
    }

    public class ChokeConnectionEvent : TimerEvent 
    {
	Connection m_Conn = null;

	public ChokeConnectionEvent(Connection c)
	{
	    m_Conn = c;
	}

	public void process(long timeNow) 
	{
	    m_Conn.Choke();
	}
    }

    public class ChokerEvent : TimerEvent 
    {
	Choker m_Choker = null;

	public ChokerEvent(Choker choker) 
	{
	    m_Choker = choker;
	}

	public void process(long timeNow) 
	{
	    m_Choker.ChokeUnchoke();
	}
    }

    public class PieceAvailComparer : IComparer
    {
	public Node m_Node = null;

	public PieceAvailComparer(Node n)
	{
	    m_Node = n;
	}

	public int Compare(object x, object y)
	{
	    int ix = (int) x, iy = (int) y;

	    int av_x = m_Node.GetAvailability(ix), av_y = m_Node.GetAvailability(iy);
	    //			int av_x = Node.s_GlobalAvailArray[ix], av_y = Node.s_GlobalAvailArray[iy];

	    bool un_x = m_Node.UnFinished(ix), un_y = m_Node.UnFinished(iy);

	    if (un_x && !un_y) 
		return -1;
	    if (un_y && !un_x)
		return 1;

	    return (av_x - av_y);

	}
    }

    public class DownloadRateComparer : IComparer 
    {
	// Reverse sort; want the highest rate guy first...
	public int Compare(object x, object y)
	{
	    Connection xc = (Connection) x, yc = (Connection) y;
	    float xr = xc.GetDownloadRate(), yr = yc.GetDownloadRate();

	    return -Sim.FloatCompare(xr, yr);
	}
    }

    public class JoinTimeComparer : IComparer
    {
	// Reverse sort; want the last guy first...
	public int Compare(object x, object y)
	{
	    Node nx = (Node) x;
	    Node ny = (Node) y;

	    return (int) (ny.m_JoinTime - nx.m_JoinTime);
	}
    }
    public class TryDownloadEvent : TimerEvent 
    {
	Node m_Node = null;
	Connection m_Connection = null;

	public TryDownloadEvent(Node n, Connection conn)
	{
	    m_Node = n;
	    m_Connection = conn;
	}
	public void process(long timeNow)
	{
	    if (m_Node.Alive)
		m_Node.DownloadIfPossible(m_Connection);
	}
    }

}
