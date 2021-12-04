using System;
using System.Diagnostics;
using System.Collections;

namespace Simulator
{
    /// <summary>
    /// Contains description of a single download. Notes the size requested, downloaded 
    /// and the rate, the delivery "event" -- reschedules the delivery event if need be.
    /// </summary>
    public class Transfer
    {
	//////////////////////////////////////////////////////////////////////////
	Node               m_Sender, m_Recipient;
	public Node From {
	    get { return m_Sender; }
	}
	public Node To {
	    get { return m_Recipient; }
	}
	Connection         m_SenderConnection; 
	public Connection SenderConnection { 
	    get { return m_SenderConnection; }
	}

	//////////////////////////////////////////////////////////////////////////
	PieceDeliveryEvent m_Event;
	int                m_Piece;
	public int Piece {
	    get { return m_Piece; }
	}
	float              m_Rate;
	public float Rate { 
	    get { return m_Rate; }
	}
	long               m_Size, m_Downloaded;
	long               m_LastRateChangeTime;
	Sim                m_Simulator;

	//////////////////////////////////////////////////////////////////////////
	// This is for debug only...
#if XTRA_DEBUG
	ArrayList times = new ArrayList();
	ArrayList downl = new ArrayList();
	ArrayList rates = new ArrayList();
	ArrayList firetime = new ArrayList();
#endif

	public Transfer(Connection conn, Sim s, Node sndr, Node rcpt, int piece, long amount, float rate)
	{
	    m_SenderConnection = conn;
	    m_Simulator = s;
	    m_Sender = sndr;
	    m_Recipient = rcpt;
	    m_Rate  = rate;
	    m_Size  = amount; 
	    m_Piece = piece;

	    long timeNow = m_Simulator.TimeNow();
	    long transferTime = (long) ( amount / (rate * 1.024) );

	    m_Event = new PieceDeliveryEvent(this, timeNow + transferTime, timeNow);

	    // Schedule a delivery; The delivery succeeds even if I die in the meantime..
	    // Console.WriteLine(" {0}->{1} gonna schedule delivery of piece {2} after {3} ms @rate: {4}", 
	    //	sndr.ID, rcpt.ID, piece, transferTime, rate);
	    m_Simulator.RaiseSimulationEvent(transferTime, m_Event);

	    m_LastRateChangeTime = timeNow;
	    m_Downloaded = 0;

#if XTRA_DEBUG
	    times.Add(timeNow);
	    downl.Add(0);
	    rates.Add(m_Rate);
	    firetime.Add(m_Event.FireTime);
#endif
	}

	public void Reschedule(float newRate)
	{
	    long timeNow = m_Simulator.TimeNow();

	    //Console.WriteLine("=== transfer [{0}]->[{1}] from rate: {2} to {3}", m_Sender.ID, m_Recipient.ID, m_Rate, newRate);
	    if (m_Rate == newRate) 
		return;

	    // Slightly weird hack!
	    if (m_Event.FireTime == timeNow || m_Downloaded >= m_Size)
		return;

	    long timeElapsed = timeNow - m_LastRateChangeTime + 1; // little leeway; see comment elsewhere.
	    m_Downloaded += (long) (timeElapsed * m_Rate * 1.024);         // timeElapsed is in milliseconds; rate is in kilobits per second

#if XTRA_DEBUG
	    times.Add(timeNow);
	    downl.Add(m_Downloaded);
	    rates.Add(newRate);
#endif

	    Debug.Assert(m_Downloaded <= m_Size + 5000);
	    m_Rate = newRate;
	    m_LastRateChangeTime = timeNow;

	    long timeRemaining = (long) ((m_Size - m_Downloaded) / (newRate * 1.024));
	    if (timeRemaining <= 0) 
	    {
#if XTRA_DEBUG
		firetime.Add(-timeRemaining); // just a note...
#endif
		return;      // just going to finish the download...
	    }

#if XTRA_DEBUG
	    firetime.Add(timeNow + timeRemaining);
#endif
	    m_Event.ReSchedule(m_Simulator, timeNow + timeRemaining);
	}


	public void Finish()
	{
	    m_Event.Zombify();
	    m_Sender.FinishUpload(this);
	    m_Recipient.FinishDownload(this);

	    long timeNow = m_Simulator.TimeNow();
	    long timeElapsed = timeNow - m_LastRateChangeTime + 1 /* little leeway to account for rounding errors, DOH! - Ashwin [08/04/2004] */;
	    m_Downloaded += (long) (timeElapsed * m_Rate * 1.024);         // timeElapsed is in milliseconds; rate is in kilobits per second

	    m_Sender.UpdateSent(m_Recipient, m_Piece, m_Downloaded);
	    m_Recipient.ReceivePiece(m_Sender, m_Piece, m_Downloaded);

	    if (m_Sender.Alive) 
	    {
		if (SimParameters.DoingBlockTFT())
		    m_Sender.OnUploadAvailable();
	    }
	}

	public Node GetOtherEnd(Node me)
	{
	    if (m_Sender.ID == me.ID)
		return m_Recipient;
	    else
		return m_Sender;
	}

	// Is this transfer a download to me, or an upload from me?
	public bool IsDownload(Node me)
	{
	    if (m_Sender.ID == me.ID)
		return false;
	    else
		return true;
	}

#if XTRA_DEBUG
	public void DebugDump()
	{
	    Debug.WriteLine("=========");
	    for (int i = 0; i < times.Count; i++) 
	    {
		Debug.WriteLine(string.Format("time: {0} rate: {1} downl: {2}", times[i], rates[i], downl[i]));
	    }
	    Debug.WriteLine("=========");
	}
#endif
    }
}
