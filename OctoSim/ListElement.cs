using System;

namespace Simulator
{
    /// <summary>
    /// Summary description for ListElement.
    /// </summary>
    class ListElement
    {
	public ListElement next;
	public TimerEvent store;

	public ListElement(TimerEvent obj)
	{
	    store = obj;
	    next = null;
	}
    }
}
