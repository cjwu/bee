using System;
using System.Collections;


namespace Simulator
{
    /// <summary>
    /// Models a queue of events for the simulator. The implementation currently 
    /// is that of a splay-tree. Change it to a calendar queue if need be.
    /// </summary>
    class EventQueue
    {
	private TreeNode root = null;
	private long timeNow = 0L;

	public void InsertObject(long point, TimerEvent obj)
	{
	    root = InsertNode(point, root, obj);
	}

	public long GetTime
	{
	    get { return timeNow; }
	}

	public long GetNextTime()
	{
	    if (root != null)
	    {
		root = Splay(0,root);
		return root.Position;
	    }
	    else
		return -1;
	}

	public ListElement GetNextEvents()
	{
	    ListElement t = null;
	    if (root != null)
	    {
		root = Splay(0,root);
		t = root.Elements;
		timeNow = root.Position;
		root = DeleteNode(root.Position, root, false);
	    }
	    return t;
	}

	public bool IsEmpty
	{
	    get { return root == null; }
	}

	/*
	   Splay tree implementation
	 */

	private TreeNode N = new TreeNode();

	private TreeNode Splay(long i, TreeNode t) 
	{
	    TreeNode l, r, y;

	    if (t == null) 
		return t;

	    N.Left = N.Right = null;
	    l = r = N;

	    for (;;) 
	    {
		if (i < t.Position) 
		{
		    if (t.Left == null) 
			break;
		    if (i < t.Left.Position) 
		    {
			y = t.Left;                           /* rotate right */
			t.Left = y.Right;
			y.Right = t;
			t = y;
			if (t.Left == null) 
			    break;
		    }
		    r.Left = t;                               /* link right */
		    r = t;
		    t = t.Left;
		} 
		else if (i > t.Position) 
		{
		    if (t.Right == null) break;
		    if (i > t.Right.Position) 
		    {
			y = t.Right;                          /* rotate left */
			t.Right = y.Left;
			y.Left = t;
			t = y;
			if (t.Right == null) break;
		    }
		    l.Right = t;                              /* link left */
		    l = t;
		    t = t.Right;
		} 
		else 
		{
		    break;
		}
	    }
	    l.Right = t.Left;                                /* assemble */
	    r.Left = t.Right;
	    t.Left = N.Right;
	    t.Right = N.Left;
	    return t;
	}

	private TreeNode InsertNode(long i, TreeNode t, TimerEvent obj) 
	{
	    if (t == null) 
	    {
		TreeNode n = new TreeNode(i, obj);
		n.Left = n.Right = null;
		return n;
	    }
	    t = Splay(i,t);
	    if (i < t.Position) 
	    {
		TreeNode n = new TreeNode(i, obj);
		n.Left = t.Left;
		n.Right = t;
		t.Left = null;
		return n;
	    } 
	    else if (i > t.Position) 
	    {
		TreeNode n = new TreeNode(i, obj);
		n.Right = t.Right;
		n.Left = t;
		t.Right = null;
		return n;
	    } 
	    else 
	    { 
		t.AddElement(obj);
		return t;
	    }
	}

	private TreeNode DeleteNode(long i, TreeNode t, bool DoSplay) 
	{
	    TreeNode x;
	    if (t==null) 
		return null;
	    if (DoSplay)
		t = Splay(i,t);
	    if (i == t.Position) 
	    {               /* found it */
		if (t.Left == null) 
		{
		    x = t.Right;
		}
		else 
		{
		    x = Splay(i, t.Left);
		    x.Right = t.Right;
		}
		return x;
	    }
	    return t;                         /* It wasn't there */
	}
    }

    /// <summary>
    /// TreeNode class used in the Splay tree implementation
    /// </summary>
    class TreeNode
    {
	TreeNode left, right;
	long position;
	ListElement head;
	ListElement tail;

	public TreeNode Left
	{
	    get { return left; }
	    set { left = value; }
	}	

	public TreeNode Right
	{
	    get { return right; }
	    set { right = value; }
	}	

	public long Position
	{
	    get { return position; }
	}	

	public ListElement Elements
	{
	    get { return head; }
	}

	public void AddElement(TimerEvent element)
	{
	    if (head == null)
	    {
		head = new ListElement(element);
		tail = head;
	    }
	    else
	    {
		tail.next = new ListElement(element);
		tail = tail.next;
	    }
	}

	public void ResetTreeNode(long position, TimerEvent element)
	{
	    left = null;
	    right = null;
	    this.position = position;
	    head = null;
	    tail = null;
	    AddElement(element);
	}

	public TreeNode(long position, TimerEvent element)
	{
	    left = null;
	    right = null;
	    this.position = position;
	    head = null;
	    tail = null;
	    AddElement(element);
	}

	public TreeNode()
	{
	    left = null;
	    right = null;
	    this.position = -1;
	    head = null;
	    tail = null;
	}
    }

}
