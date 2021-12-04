using System;
using System.IO;

namespace Simulator
{
	public enum LogEvent 
	{
		JOIN,
		SEEDIFY,
		LEAVE,
		SEND,
		RECV,
		FINISHED,
		UTIL,
		CHGRATE,
	}
	
	/// <summary>
	/// Summary description for Logger.
	/// </summary>
	public class Logger
	{
		private static StreamWriter output_stream = null;
		private static Sim          simulator = null;
		public static  StreamWriter timed_stream = null;
		public static  StreamWriter graph_stream = null;

		public static void Initialize(Sim s)
		{
			simulator = s;
			output_stream = new StreamWriter(SimParameters.outputFile + ".nds", false);
			timed_stream = new StreamWriter(SimParameters.outputFile + ".bw", false);
			graph_stream = new StreamWriter(SimParameters.outputFile + ".gph", false);
			if (output_stream == null || timed_stream == null || graph_stream == null) 
			{
				Console.WriteLine("Could not open " + SimParameters.outputFile + ".nds/.bw/.gph for writing... Quitting!");
				Environment.Exit(13);
			}

			output_stream.WriteLine("# Format of the file: [time] [node] [event] <details>");
		}

		public static void log(string s, params object[] args) 
		{
			output_stream.WriteLine(s, args);
		}
		// Without the newline...
		public static void ulog(string s, params object[] args) 
		{
			output_stream.Write(s, args);
		}

		public static void node_log(Node node, params object[] args)
		{
			LogEvent ev = (LogEvent) args[0];
			long timeNow = simulator.TimeNow();
			
			switch (ev) {
				case LogEvent.JOIN:
					output_stream.WriteLine("{0} {1} join {2} B d {3} u {4}", 
							timeNow, node.ID, (node.IsSeed ? "seed" : "leech"), 
							node.DownCap, node.UpCap);
					break;
				case LogEvent.SEEDIFY:
					output_stream.WriteLine("{0} {1} seedified", timeNow, node.ID);
					break;
				case LogEvent.LEAVE:
					output_stream.WriteLine("{0} {1} leave", timeNow, node.ID);
					break;
				case LogEvent.RECV:
					output_stream.WriteLine("{0} {1} r p {2} n {3}", timeNow, 
							node.ID, (int) args[1], ((Node) args[2]).ID);
					break;
				case LogEvent.SEND:
					output_stream.WriteLine("{0} {1} s p {2} n {3}", timeNow, 
							node.ID, (int) args[1], ((Node) args[2]).ID);
					break;
				case LogEvent.FINISHED:
					output_stream.WriteLine("{0} {1} finished sent {2:f3} recv {3:f3}", timeNow,
						node.ID, (float) node.TotalSent / (float) SimParameters.blockSizeInBits, 
						(float) node.TotalReceived / (float) SimParameters.blockSizeInBits);
					break;
				case LogEvent.UTIL:
					output_stream.WriteLine("{0} {1} d {2} u {3}", timeNow, 
						node.ID, (float) args[1], (float) args[2]);
					break;
				case LogEvent.CHGRATE:
					output_stream.WriteLine("{0} {1} c {2}->{3} r1 {4} r2 {5}", timeNow,
						node.ID, ((Node) args[1]).ID, ((Node) args[2]).ID, 
						(float) args[3] /* oldrate */, (float) args[4] /* newrate */);
					break;
			}
			output_stream.Flush();
		}
		
		public static void warn(string s)
		{
			Console.Error.WriteLine("WARNING: " + s);
		}

		public static void Finish()
		{
			output_stream.Flush();
			output_stream.Close();
			timed_stream.Flush();
			timed_stream.Close();
			graph_stream.Flush();
			graph_stream.Close();
		}
	}
}
