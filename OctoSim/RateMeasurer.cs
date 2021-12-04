using System;

namespace Simulator
{
    /// <summary>
    /// Keeps a running average of the rate of download or upload.
    /// The average is based on the last 'k' block-transfers (instead 
    /// of the last 't' seconds, which is the normal way of computing 
    /// the rate)
    /// </summary>
    public class RateMeasurer
    {
	private float[] m_Samples = null;
	private int m_LastUpdated = -1;

	public RateMeasurer(int n_samples)
	{
	    m_Samples = new float[n_samples];
	    for (int i = 0; i < n_samples; i++) 
		m_Samples[i] = -1;
	}

	public void Update(float rate)
	{
	    if (m_LastUpdated < 0) {
		m_LastUpdated = 0;
	    }
	    m_Samples[m_LastUpdated] = rate;
	    m_LastUpdated = (m_LastUpdated + 1) % m_Samples.Length;
	}

	public float GetAverageRate() 
	{
	    float avg = 0.0F;
	    int   pos = 0;
	    for (int i = 0; i < m_Samples.Length; i++) {
		if (m_Samples[i] > 0) 
		{ 
		    avg += m_Samples[i];
		    pos++;
		}
	    }
	    if (pos > 0)
		return avg/pos;
	    else
		return 0;
	}

    }

    /// <summary>
    /// Keeps a running average - but instead of "rate samples", it receives 
    /// amount sent as input and computes the running average over some time-window.
    /// </summary>
    public class NewRateMeasurer 
    {
	Sim    m_Simulator = null;
	float  m_Rate;
	long   m_WindowLength = 0;
	long   m_WindowStart = 0;
	long   m_LastUpdate  = 0;

	public NewRateMeasurer(Sim s, long window)
	{
	    m_Simulator = s;
	    m_WindowLength = window;
	    m_Rate = 0.0F;
	    m_WindowStart = s.TimeNow() - SimParameters.rateFudge;
	    m_LastUpdate  = m_WindowStart;
	}

	public void Update(float amount)
	{
	    long timeNow = m_Simulator.TimeNow();

	    if (m_LastUpdate == timeNow)
		return;

	    m_Rate = (m_Rate * (m_LastUpdate - m_WindowStart) + amount) / (timeNow - m_WindowStart);
	    m_LastUpdate = timeNow;
	    if (m_WindowStart < timeNow - m_WindowLength)
		m_WindowStart = timeNow - m_WindowLength;
	}

	public float GetAverageRate()
	{
	    Update(0);
	    return (m_Rate * 1000.0f);     // just to convert it to kbps.... (so that the numbers look saner)
	}
    }
}
