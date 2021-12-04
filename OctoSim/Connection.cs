using System;
using System.Collections;
using System.Diagnostics;

namespace Simulator
{
    // this class maintains a connection from peer A to peer B.
    // performs book-keeping mainly (what pieces are present 
    // at other peer, whether we are downloading on this connection, etc.)

    public class Connection 
    {
        Node          m_Local, m_Remote;
        NewRateMeasurer m_UpMeasurer = null, m_DownMeasurer = null;

        Transfer      m_Upload = null;
        bool          m_Choking, m_Interested;
        bool[]        m_PieceInterests = null;
        int           m_NumPiecesWanted = 0;
        bool          m_IsDownloading = false;
        long          m_Downloaded = 0, m_Uploaded = 0;

        public Connection OtherEndConnection = null;

        public bool Interested {
            get { return m_Interested; }
            set { m_Interested = value; }
        }
        public long Downloaded {
            get { return m_Downloaded; }
            set { m_Downloaded = value; }
        }
        public long Uploaded 
        {
            get { return m_Uploaded; }
            set { m_Uploaded = value; }
        }

        public bool   IsDownloading {
            get { return m_IsDownloading; }
            set { m_IsDownloading = value; }
        }

        public Node Peer 
        { 
            get { return m_Remote; }
        }

        public Connection(Node me, Node remote, Sim s, int n_pieces)
        {
            m_Local = me;
            m_Remote = remote;

            m_DownMeasurer = new NewRateMeasurer(s, SimParameters.rateWindow);
            m_UpMeasurer   = new NewRateMeasurer(s, SimParameters.rateWindow);

            m_Choking = true;       // when i start, i don't want to transfer to this peer. 

            // HACK
            if (SimParameters.doHackyHashReplacement) {
                Node.s_GlobalChokingArray[me.ID, remote.ID] = true;
            }

            m_PieceInterests = new bool[n_pieces];

            for (int i = 0; i < n_pieces; i++) 
            {
                if (remote.HasPiece(i) && !me.HasPiece(i) && !me.IsDownloading(i)) 
                {
                    m_PieceInterests[i] = true; 
                    m_NumPiecesWanted++;
                }
                else 
                {
                    m_PieceInterests[i] = false;
                }
            }
            if (m_NumPiecesWanted > 0) 
                m_Interested = true;    // I am interested in this peer.
            else 
                m_Interested = false;
        }

        public void Choke() { 
            // If this connection had an ongoing transfer....
            // stop the transfer
            if (!m_Choking && m_Upload != null) {
                m_Choking = true;                // essential that this is here...

                if (SimParameters.doHackyHashReplacement) {
                    Node.s_GlobalChokingArray[m_Local.ID, m_Remote.ID] = true;
                }

                if (m_Local.IsSeed && SimParameters.noSeedUnfinished) {
                    // do nothing.... dont interrupt the ongoing transfer.
                }
                else {
                    m_Upload.Finish();
                    m_Upload = null;
                }
            }

            m_Choking = true;
            if (SimParameters.doHackyHashReplacement) {
                Node.s_GlobalChokingArray[m_Local.ID, m_Remote.ID] = true;
            }
        }

        public void FinishUpload() { 
            m_Upload = null;
        }

        public Transfer StartUpload(Sim s, int piece, long amount, float rate)
        {
            Debug.Assert(m_Upload == null);
            m_Upload = new Transfer(this, s, m_Local, m_Remote, piece, amount, rate);
            return m_Upload;
        }

        public bool IsUploading() {
            return (m_Upload != null);
        }

        // Unchoking can result in a new data transfer being possible...
        public void Unchoke() { 
            m_Choking = false; 
            if (SimParameters.doHackyHashReplacement) {
                Node.s_GlobalChokingArray[m_Local.ID, m_Remote.ID] = false;
            }

            m_Remote.GotUnchoke(m_Local);
        }

        public bool IsChoking() { return m_Choking; }
        public bool IsInterested() { return m_Interested; }

        public float GetUploadRate() { return m_UpMeasurer.GetAverageRate(); }
        public float GetDownloadRate() { return m_DownMeasurer.GetAverageRate(); }

        public void UpdateUploadRate(float amount) { m_UpMeasurer.Update(amount); }
        public void UpdateDownloadRate(float amount) { m_DownMeasurer.Update(amount); }

        public void RecvdPiece(int piece) 
        { 
            if (m_PieceInterests[piece]) 
            {
                m_PieceInterests[piece] = false;
                m_NumPiecesWanted--;
                Debug.Assert(m_NumPiecesWanted >= 0, "num pieces wanted is negative?");
                if (m_NumPiecesWanted == 0) 
                    m_Interested = false;
            }
        }

        public void UpdatePieceInterest(int piece)
        {
            bool newInterest = false;
            if (m_Remote.HasPiece(piece) && !m_Local.HasPiece(piece) && !m_Local.IsDownloading(piece))
                newInterest = true;

            if (m_PieceInterests[piece] && !newInterest) 
            {
                m_NumPiecesWanted--;
                Debug.Assert(m_NumPiecesWanted >= 0, "num pieces wanted is negative?");
                if (m_NumPiecesWanted == 0) 
                    m_Interested = false;
            }
            if (!m_PieceInterests[piece] && newInterest) 
            {
                m_NumPiecesWanted++;
                Debug.Assert(m_NumPiecesWanted <= m_PieceInterests.Length, "num pieces wanted is more than #pieces?");
                if (m_NumPiecesWanted > 0)
                    m_Interested = true;
            }

            m_PieceInterests[piece] = newInterest;
        }
    }
}
