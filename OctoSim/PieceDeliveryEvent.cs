using System;
using System.Diagnostics;
using System.Collections;

namespace Simulator {
    
    // this is the event marking a delivery of a piece or block
    // from one node to another. this event is funky because its
    // "firing" time keeps on changing due to varying bandwidth
    // availability at the source or destination.

    public class PieceDeliveryEvent : TimerEvent {
	long        m_FireTime;
	public long FireTime { 
	    get { return m_FireTime; }
	}
	Transfer    m_Transfer;
	bool        m_Fired;

#if XTRA_DEBUG
	//////////////////////////////////////////////////////////////////////////
	// for debug...
	ArrayList fired = new ArrayList();
	ArrayList scheduled = new ArrayList();
	ArrayList sc_times = new ArrayList();
#endif

	public PieceDeliveryEvent(Transfer tran, long fireAt, long timeNow) {
	    m_Transfer  = tran;
	    m_FireTime  = fireAt;
	    m_Fired     = false;
#if XTRA_DEBUG
	    scheduled.Add(-1);
	    scheduled.Add(fireAt);
	    sc_times.Add(timeNow);
#endif
	}

	public void Zombify() { 
	    m_Fired = true;
	}

	public void process(long timeNow) 
	{
	    // Check if I have been rescheduled?
	    if (timeNow != m_FireTime || m_Fired)
		return;

#if XTRA_DEBUG
	    fired.Add(timeNow);
#endif
	    m_Fired = true;
	    m_Transfer.Finish();
	}

	// ah, fun stuff! :) rescheduling an event from within the eventqueue.
	// i could have done a queue.remove (ev) and queue.insert (ev), but 
	// the remove would cost me log(n) operations. further more, it would
	// cause some garbage collection activity (perhaps). here, i trade it off 
	// with the queue-size (i dont get rid of the first event, just insert
	// it again into the queue and make sure the first "link" doesn't fire).
	
	public void ReSchedule(Sim simulator, long rescheduleAt)
	{
	    long timeNow = simulator.TimeNow();

	    Debug.Assert(!m_Fired, "I should never be rescheduling a finished download!");
	    Debug.Assert(rescheduleAt > timeNow, "going to reschedule at the SAME FRICKIN TIME!");
	    if (rescheduleAt == m_FireTime)
		return;

	    // Logger.log("transfer: {0}->{1} rescheduling from {2}---|>{3}", m_Transfer.From.ID, m_Transfer.To.ID, m_FireTime, rescheduleAt);
#if XTRA_DEBUG
	    scheduled.Add(m_FireTime);
	    scheduled.Add(rescheduleAt);
	    sc_times.Add(timeNow);
#endif
	    m_FireTime = rescheduleAt;
	    simulator.RaiseSimulationEvent(rescheduleAt - timeNow, this);
	}

	// DEFUNCT!
	private bool HasFired(long timeNow) {
	    return timeNow >= m_FireTime;
	}
    }

}
