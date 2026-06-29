//+------------------------------------------------------------------+
//| FALCON_Persistence.mqh                                            |
//| FALCON OS - Kernel: Persistence Layer (optional storage)          |
//|                                                                   |
//| Stores network memory, campaign history, performance metrics and  |
//| learned parameters to the terminal's Files folder as CSV so the   |
//| OS retains memory across restarts. Disabled in backtest.          |
//+------------------------------------------------------------------+
#property strict

#define FALCON_MEM_FILE   "FalconOS_NetworkMemory.csv"
#define FALCON_PERF_FILE  "FalconOS_Performance.csv"

//==================================================================
// SAVE NETWORK MEMORY (node registry snapshot)
//==================================================================
void FALCON_SaveNetworkMemory()
{
   if(FALCON_IsBacktest()) return;   // no persistence in backtest
   int h = FileOpen(FALCON_MEM_FILE, FILE_WRITE|FILE_CSV|FILE_ANSI, ',');
   if(h == INVALID_HANDLE) return;
   FileWrite(h, "price", "dir", "score", "weight", "state", "age", "revisits");
   for(int i = 0; i < gState.network.nodeCount && i < 250; i++)
   {
      // node data is sourced from the memory module's registry (synced into state)
      FileWrite(h,
         DoubleToString(gFalconNodePrice[i], _Digits),
         IntegerToString(gFalconNodeDir[i]),
         DoubleToString(gFalconNodeScore[i], 1),
         IntegerToString(gFalconNodeWeight[i]),
         IntegerToString(gFalconNodeState[i]),
         IntegerToString(gFalconNodeAge[i]),
         IntegerToString(gFalconNodeRevisits[i]));
   }
   FileClose(h);
}

//==================================================================
// APPEND PERFORMANCE RECORD (per closed trade or per bar summary)
//==================================================================
void FALCON_LogPerformance(string ev, double pnl)
{
   if(FALCON_IsBacktest()) return;
   int h = FileOpen(FALCON_PERF_FILE, FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI, ',');
   if(h == INVALID_HANDLE) return;
   FileSeek(h, 0, SEEK_END);
   FileWrite(h, TimeToString(TimeCurrent()), ev,
             FALCON_DecisionStr(gState.intel.decision),
             DoubleToString(pnl, 2),
             DoubleToString(gState.exec.equity, 2));
   FileClose(h);
}

//+------------------------------------------------------------------+
