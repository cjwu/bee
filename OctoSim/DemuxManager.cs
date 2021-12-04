using System;
using System.Collections;
using System.Diagnostics;

namespace Simulator
{
    /// <summary>
    /// Gives fair share of the bandwidth to each ongoing 
    /// transfer at a node. 
    /// </summary>
    public class DemuxManager
    {
	Node         m_Node = null;         // the node I am associated with

	public DemuxManager(Node n)
	{
	    m_Node = n;
	}

	public float GetNewTransferRate(ArrayList transfers, float total)
	{
	    float fairShare;
	    transfers.Sort(new TransferRateComparer());
	    int n_connections = transfers.Count + 1;

	    foreach (Transfer tran in transfers)
	    {
		fairShare = total / n_connections;
		n_connections--;

		// the connection is limited by other bottlenecks!
		if (tran.Rate < fairShare) 
		{      
		    total -= tran.Rate;
		}
		// the new connection limits this ongoing transfer
		// so change the rate of the ongoing transfer
		else if (tran.Rate > fairShare)           
		{      
		    // Logger.node_log(this, LogEvent.CHGRATE, tran.From, tran.To, tran.Rate, fairShare);
		    tran.Reschedule(fairShare);
		    total -= fairShare;
		}
		else 
		{
		    total -= fairShare;
		}
	    }
	    return total;  // this is the residual capacity!
	}

	// This is slightly different from the GetNewTransferRate thingy...
	// All these routines are very subtly different from each other 

	public void AdjustTransferRates(ArrayList transfers, float total)
	{
	    float fairShare;
	    int   n_connections = transfers.Count;
	    transfers.Sort(new TransferRateComparer());

	    foreach (Transfer tran in transfers)
	    {
		fairShare = total / n_connections;
		n_connections--;

		if (tran.Rate < fairShare) 
		{
		    //////////////////////////////////////////////////////////////////////////
		    /// This is DIFFERENT for this routine...
		    /// 
		    // Try to ramp this connection UP to its fairshare... 
		    // depending on whether there's space up at the other end, this and other connections @ our
		    // end will be affected...
		    float rate_achieved = tran.GetOtherEnd(m_Node).TryRampUp(tran, fairShare);
		    total -= rate_achieved;
		}
		else if (tran.Rate > fairShare) 
		{      
		    // Logger.node_log(this, LogEvent.CHGRATE, tran.From, tran.To, tran.Rate, fairShare);
		    tran.Reschedule(fairShare);
		    total -= fairShare;
		}
		else 
		{
		    total -= fairShare;
		}
	    }
	}

	// Try to ramp up a transfer to a higher rate. This may affect other ongoing transfers!
	// 
	public float TryRampUp(Transfer tran, ArrayList transfers, float total, float newRate)
	{
	    float     fairShare;
	    int       n_connections = transfers.Count;
	    float     rate_achieved = -1;

	    foreach (Transfer ntran in transfers)
	    {
		fairShare = total/n_connections;
		n_connections--;

		//////////////////////////////////////////////////////////////////////////
		/// this is what's different about this routine
		/// 
		if (ntran == tran) 
		{
		    newRate = Math.Min(newRate, fairShare);
		    ntran.Reschedule(newRate);
		    rate_achieved = newRate;
		    total -= newRate;
		}
		else 
		{
		    // Treat other connections "normally"...
		    if (ntran.Rate < fairShare) 
		    {
			total -= ntran.Rate;
		    }
		    else if (ntran.Rate > fairShare)
		    {
			ntran.Reschedule(fairShare);
			total -= fairShare;
		    }
		    else 
		    {
			total -= fairShare;
		    }
		}
	    }
	    Debug.Assert(rate_achieved > 0, " Rate_achieved <= 0?? ");
	    return rate_achieved;
	}
    }

    public class TransferRateComparer : IComparer 
    {
	public int Compare(object x, object y)
	{
	    float xr = ((Transfer) x).Rate, yr = ((Transfer) y).Rate;
	    return Sim.FloatCompare(xr, yr);
	}
    }
}
