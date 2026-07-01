//+------------------------------------------------------------------+
//|  FALCON OS — Kernel : FalconPersistence.mqh                     |
//|  Optional persistence layer.                                    |
//|                                                                  |
//|  Stores network memory, campaign history, performance metrics    |
//|  and learned parameters between sessions. Uses the MQL5 common    |
//|  files sandbox (MQL5/Files). Persistence is OPTIONAL — the OS     |
//|  runs identically if it is disabled or the files are absent.     |
//|                                                                  |
//|  Format: simple line-based CSV so the data is human-inspectable  |
//|  and trivially portable across the live/backtest/research        |
//|  profiles.                                                       |
//+------------------------------------------------------------------+
#ifndef FALCON_PERSISTENCE_MQH
#define FALCON_PERSISTENCE_MQH

#include "FalconConfig.mqh"
#include "FalconState.mqh"
#include "FalconSeries.mqh"
#include "FalconLog.mqh"

input string  __sep_persist     = "════════ PERSISTENCE ════════"; // ──
input bool    InpEnablePersist  = false;          // Enable persistence layer
input int     InpPersistEveryBars = 50;           // Autosave cadence (bars)

string FP_NetworkFile()  { return("FALCON_"+_Symbol+"_network.csv"); }
string FP_CampaignFile() { return("FALCON_"+_Symbol+"_campaign.csv"); }
string FP_PerfFile()     { return("FALCON_"+_Symbol+"_perf.csv"); }

//==================================================================
// PERSISTED PERFORMANCE METRICS (also kept live in memory)
//==================================================================
struct FalconPerf
{
   int    totalTrades;
   int    wins;
   int    losses;
   double grossProfit;
   double grossLoss;
   double peakEquity;
   double maxDrawdown;     // absolute
   double maxDrawdownPct;  // 0..100
   double learnedExecArm;  // adaptively tuned arm threshold (research)
};
FalconPerf g_perf;
int        g_persistLastBar = 0;

void FalconPerfInit()
{
   g_perf.totalTrades=0; g_perf.wins=0; g_perf.losses=0;
   g_perf.grossProfit=0; g_perf.grossLoss=0;
   g_perf.peakEquity=AccountInfoDouble(ACCOUNT_EQUITY);
   g_perf.maxDrawdown=0; g_perf.maxDrawdownPct=0;
   g_perf.learnedExecArm=g_cfg.execProbArm;
   g_persistLastBar=0;
}

//------------------------------------------------------------------
// Roll the running drawdown / equity-peak tracker. Called each bar.
//------------------------------------------------------------------
void FalconPerfTrackEquity()
{
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq>g_perf.peakEquity) g_perf.peakEquity=eq;
   double dd=g_perf.peakEquity-eq;
   if(dd>g_perf.maxDrawdown) g_perf.maxDrawdown=dd;
   double ddPct=(g_perf.peakEquity>0? dd/g_perf.peakEquity*100.0 : 0.0);
   if(ddPct>g_perf.maxDrawdownPct) g_perf.maxDrawdownPct=ddPct;
}

//==================================================================
// SAVE
//==================================================================
void FP_SaveNetwork()
{
   int h=FileOpen(FP_NetworkFile(),FILE_WRITE|FILE_CSV|FILE_ANSI,',');
   if(h==INVALID_HANDLE){ FalconWarn("Persistence","cannot write network file"); return; }
   FileWrite(h,"px","mid","dir","score","weight","state","birth","revisits");
   FalconNetwork n=g_state.network;
   for(int i=0;i<n.count;i++)
      FileWrite(h,
         DoubleToString(n.px[i],_Digits),
         DoubleToString(n.mid[i],_Digits),
         IntegerToString(n.dir[i]),
         DoubleToString(n.score[i],2),
         IntegerToString(n.weight[i]),
         IntegerToString(n.nstate[i]),
         IntegerToString(n.birthBar[i]),
         IntegerToString(n.revisits[i]));
   FileClose(h);
}

void FP_SaveCampaign()
{
   int h=FileOpen(FP_CampaignFile(),FILE_WRITE|FILE_CSV|FILE_ANSI,',');
   if(h==INVALID_HANDLE) return;
   FalconCampaign c=g_state.campaign;
   FileWrite(h,"owner","institution","control","objectiveDir","remainingEnergy","age");
   FileWrite(h,IntegerToString(c.owner),c.institution,DoubleToString(c.controlScore,1),
             IntegerToString(c.objectiveDir),DoubleToString(c.remainingEnergy,1),IntegerToString(c.age));
   FileClose(h);
}

void FP_SavePerf()
{
   int h=FileOpen(FP_PerfFile(),FILE_WRITE|FILE_CSV|FILE_ANSI,',');
   if(h==INVALID_HANDLE) return;
   FileWrite(h,"totalTrades","wins","losses","grossProfit","grossLoss","peakEquity","maxDD","maxDDpct","learnedExecArm");
   FileWrite(h,
      IntegerToString(g_perf.totalTrades),IntegerToString(g_perf.wins),IntegerToString(g_perf.losses),
      DoubleToString(g_perf.grossProfit,2),DoubleToString(g_perf.grossLoss,2),
      DoubleToString(g_perf.peakEquity,2),DoubleToString(g_perf.maxDrawdown,2),
      DoubleToString(g_perf.maxDrawdownPct,2),DoubleToString(g_perf.learnedExecArm,3));
   FileClose(h);
}

//==================================================================
// LOAD (best-effort; missing files are not an error)
//==================================================================
void FP_LoadPerf()
{
   if(!FileIsExist(FP_PerfFile())) return;
   int h=FileOpen(FP_PerfFile(),FILE_READ|FILE_CSV|FILE_ANSI,',');
   if(h==INVALID_HANDLE) return;
   // skip header
   for(int i=0;i<9 && !FileIsEnding(h);i++) FileReadString(h);
   if(!FileIsEnding(h))
   {
      g_perf.totalTrades=(int)StringToInteger(FileReadString(h));
      g_perf.wins       =(int)StringToInteger(FileReadString(h));
      g_perf.losses     =(int)StringToInteger(FileReadString(h));
      g_perf.grossProfit=StringToDouble(FileReadString(h));
      g_perf.grossLoss  =StringToDouble(FileReadString(h));
      g_perf.peakEquity =StringToDouble(FileReadString(h));
      g_perf.maxDrawdown=StringToDouble(FileReadString(h));
      g_perf.maxDrawdownPct=StringToDouble(FileReadString(h));
      double arm=StringToDouble(FileReadString(h));
      if(arm>0.0 && arm<=1.0) g_perf.learnedExecArm=arm;
   }
   FileClose(h);
   FalconInfo("Persistence","performance metrics restored");
}

//==================================================================
// PUBLIC API
//==================================================================
void FalconPersistenceInit()
{
   FalconPerfInit();
   if(!InpEnablePersist) return;
   FP_LoadPerf();
   // apply a learned execution-arm threshold (research/auto-tuning) to live config
   if(g_perf.learnedExecArm>0.0 && g_perf.learnedExecArm<=1.0)
      g_cfg.execProbArm = g_perf.learnedExecArm;
}

void FalconPersistenceTick()
{
   FalconPerfTrackEquity();
   if(!InpEnablePersist) return;
   if(g_barCounter - g_persistLastBar < InpPersistEveryBars) return;
   g_persistLastBar=g_barCounter;
   FP_SaveNetwork();
   FP_SaveCampaign();
   FP_SavePerf();
}

void FalconPersistenceFlush()
{
   if(!InpEnablePersist) return;
   FP_SaveNetwork();
   FP_SaveCampaign();
   FP_SavePerf();
   FalconInfo("Persistence","final state flushed");
}

#endif // FALCON_PERSISTENCE_MQH
//+------------------------------------------------------------------+
