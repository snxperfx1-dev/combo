//+------------------------------------------------------------------+
//|  FALCON OS — Diagnostics : TradeJournal.mqh                      |
//|                                                                  |
//|  PURPOSE: produce the data needed to answer "which panel settings |
//|  give the best trades?". For EVERY trade it snapshots the full    |
//|  Decision/Intelligence panel state AT ENTRY (confidence, exec     |
//|  prob, threat, conflict, opportunity, master-chief, phase,        |
//|  completion, geometry, ownership, HTF alignment, verdict) and, on |
//|  close, the realised result (profit, R-multiple, MFE/MAE in R,    |
//|  bars held). One CSV row per closed trade.                        |
//|                                                                  |
//|  Run ONE backtest with InpJournal=true, then open the CSV from    |
//|  <DataFolder>/MQL5/Files/ (Common) and feed it to analyze_journal |
//|  .py to see win-rate + expectancy bucketed by each setting, so a  |
//|  threshold (e.g. confidence>=70 vs >=55) can be chosen on EVIDENCE.|
//|                                                                  |
//|  Read-only on state. Reuses FalconATR / shared series. Include    |
//|  BEFORE SymphonyEngine so its entries can call TJ_RecordEntry.    |
//+------------------------------------------------------------------+
#ifndef FALCON_TRADE_JOURNAL_MQH
#define FALCON_TRADE_JOURNAL_MQH

#include "../Kernel/FalconState.mqh"
#include "../Kernel/FalconConfig.mqh"
#include "../Kernel/FalconSeries.mqh"
#include "../Kernel/FalconLog.mqh"

//==================================================================
// One open-trade record (snapshot at entry + running MFE/MAE)
//==================================================================
struct TJRec
{
   ulong    ticket;
   bool     open;
   datetime tOpen;
   int      dir;          // +1 long / -1 short
   string   tag;          // "P3 Long" etc.
   double   entry, sl, lots, riskCash, riskDist;
   // --- panel snapshot AT ENTRY ---
   double   conf, execProb, threat, conflict, opp, mcScore;
   bool     mcConfirm;
   int      phase;
   double   completion, geomCap, ownerCtrl, htfAlign, validation, oppNum;
   int      action, owner;
   string   oppGrade, intent, timing;
   // --- running ---
   double   mfe, mae;     // price-distance favourable / adverse
};

TJRec  tj[];
int    tj_fileHandle = INVALID_HANDLE;
string tj_fileName   = "";

//==================================================================
// INIT — open the CSV (Common Files) and write the header row.
//==================================================================
void TradeJournalInit()
{
   ArrayResize(tj,0);
   tj_fileHandle = INVALID_HANDLE;
   if(!g_cfg.journal) return;

   tj_fileName = StringFormat("FALCON_Journal_%s_%d.csv", _Symbol, (int)Period());
   tj_fileHandle = FileOpen(tj_fileName,
                            FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON, ',');
   if(tj_fileHandle==INVALID_HANDLE)
   {
      FalconLog("WARN","TradeJournal","could not open "+tj_fileName);
      return;
   }
   FileWrite(tj_fileHandle,
      "ticket","openTime","closeTime","barsHeld","dir","tag",
      "entry","sl","lots","riskCash",
      "conf","execProb","threat","conflict","opp","oppGrade",
      "mcScore","mcConfirm","validation","action","owner",
      "phase","completion","geomCap","ownerCtrl","htfAlign","intent","timing",
      "profit","resultR","mfeR","maeR","win","source","planType");
   FileFlush(tj_fileHandle);
   FalconLog("INFO","TradeJournal","-> "+tj_fileName+" (Common\\Files)");
}

//==================================================================
// RECORD ENTRY — called by Symphony immediately after a successful send.
//   Captures the live Decision/Intelligence panel into a new record.
//==================================================================
void TJ_RecordEntry(const ulong ticket,const int dir,const string tag,
                    const double entry,const double sl,const double lots)
{
   if(!g_cfg.journal || tj_fileHandle==INVALID_HANDLE) return;

   FalconIntelligence x = g_state.intel;
   TJRec r;
   r.ticket   = ticket;  r.open = true;  r.tOpen = gTime[0];
   r.dir      = dir;     r.tag  = tag;
   r.entry    = entry;   r.sl   = sl;    r.lots = lots;
   r.riskCash = g_state.exec.riskCash;
   r.riskDist = MathAbs(entry - sl);
   r.conf       = x.confidence;
   r.execProb   = x.executionProbability;
   r.threat     = x.threat;
   r.conflict   = x.conflict;
   r.opp        = x.opportunity;
   r.oppNum     = x.opportunity;
   r.oppGrade   = x.opportunityGrade;
   r.mcScore    = x.masterChiefScore;
   r.mcConfirm  = x.masterChiefConfirm;
   r.validation = x.validationScore;
   r.intent     = x.intent;
   r.timing     = x.timing;
   r.action     = g_state.exec.action;
   r.owner      = g_state.campaign.owner;
   r.phase      = g_state.wave.phase;
   r.completion = g_state.wave.completion;
   r.geomCap    = g_state.convexity.geometryCapacity;
   r.ownerCtrl  = g_state.campaign.controlScore;
   r.htfAlign   = g_state.htf.alignment;
   r.mfe = 0.0;  r.mae = 0.0;

   int n = ArraySize(tj);
   ArrayResize(tj, n+1);
   tj[n] = r;
}

//------------------------------------------------------------------
// Realised P/L for a closed position (profit + swap only; MT5 has
// deprecated POSITION_COMMISSION). Also returns close price/time.
//------------------------------------------------------------------
double TJ_RealizedProfit(const ulong posId,double &closePrice,datetime &closeTime)
{
   double pl=0.0; closePrice=0.0; closeTime=0;
   if(!HistorySelectByPosition(posId)) return(0.0);
   int dts = HistoryDealsTotal();
   for(int i=0;i<dts;i++)
   {
      ulong dt = HistoryDealGetTicket(i);
      if(dt==0) continue;
      pl += HistoryDealGetDouble(dt,DEAL_PROFIT) + HistoryDealGetDouble(dt,DEAL_SWAP);
      long e = HistoryDealGetInteger(dt,DEAL_ENTRY);
      if(e==DEAL_ENTRY_OUT || e==DEAL_ENTRY_OUT_BY || e==DEAL_ENTRY_INOUT)
      {
         closePrice = HistoryDealGetDouble(dt,DEAL_PRICE);
         closeTime  = (datetime)HistoryDealGetInteger(dt,DEAL_TIME);
      }
   }
   return(pl);
}

//------------------------------------------------------------------
// Write one finalised row and mark the record closed.
//------------------------------------------------------------------
void TJ_Finalize(const int idx)
{
   double closePrice=0.0; datetime closeTime=0;
   double profit = TJ_RealizedProfit(tj[idx].ticket, closePrice, closeTime);
   if(closeTime==0) closeTime = gTime[0];

   double rd   = (tj[idx].riskDist>0.0 ? tj[idx].riskDist : 1e-9);
   double rcsh = (tj[idx].riskCash>0.0 ? tj[idx].riskCash : 1e-9);
   double resultR = profit / rcsh;
   double mfeR    = tj[idx].mfe / rd;
   double maeR    = tj[idx].mae / rd;
   int    bars    = (int)((closeTime - tj[idx].tOpen) / MathMax(1,PeriodSeconds()));
   int    win     = (profit>0.0 ? 1 : 0);

   if(tj_fileHandle!=INVALID_HANDLE)
   {
      FileWrite(tj_fileHandle,
         (string)tj[idx].ticket,
         TimeToString(tj[idx].tOpen,TIME_DATE|TIME_MINUTES),
         TimeToString(closeTime,TIME_DATE|TIME_MINUTES),
         (string)bars,
         (tj[idx].dir>0?"LONG":"SHORT"),
         tj[idx].tag,
         DoubleToString(tj[idx].entry,_Digits),
         DoubleToString(tj[idx].sl,_Digits),
         DoubleToString(tj[idx].lots,2),
         DoubleToString(tj[idx].riskCash,2),
         DoubleToString(tj[idx].conf,1),
         DoubleToString(tj[idx].execProb,3),
         DoubleToString(tj[idx].threat,1),
         DoubleToString(tj[idx].conflict,1),
         DoubleToString(tj[idx].opp,1),
         tj[idx].oppGrade,
         DoubleToString(tj[idx].mcScore,1),
         (tj[idx].mcConfirm?"1":"0"),
         DoubleToString(tj[idx].validation,1),
         (string)tj[idx].action,
         (string)tj[idx].owner,
         (string)tj[idx].phase,
         DoubleToString(tj[idx].completion,1),
         DoubleToString(tj[idx].geomCap,1),
         DoubleToString(tj[idx].ownerCtrl,1),
         DoubleToString(tj[idx].htfAlign,1),
         tj[idx].intent,
         tj[idx].timing,
         DoubleToString(profit,2),
         DoubleToString(resultR,3),
         DoubleToString(mfeR,3),
         DoubleToString(maeR,3),
         (string)win,
         (StringFind(tj[idx].tag,"PLAN")>=0?"PLANNER":"SYMPHONY"),
         (StringFind(tj[idx].tag,"CONTINUATION")>=0?"CONTINUATION":
          StringFind(tj[idx].tag,"REVERSAL")>=0?"REVERSAL":
          StringFind(tj[idx].tag,"RETURN")>=0?"RETURN":
          StringFind(tj[idx].tag,"P3")>=0?"P3":
          StringFind(tj[idx].tag,"P4")>=0?"P4":"OTHER"));
      FileFlush(tj_fileHandle);
   }
   tj[idx].open = false;
}

//==================================================================
// ON BAR — update MFE/MAE for open records and finalise any that
// have left the book (closed by trail-stop, exit, or SL).
//==================================================================
void TradeJournalOnBar()
{
   if(!g_cfg.journal || tj_fileHandle==INVALID_HANDLE) return;
   int n = ArraySize(tj);
   if(n<=0) return;

   double hi = gHigh[1], lo = gLow[1];

   for(int i=0;i<n;i++)
   {
      if(!tj[i].open) continue;

      // update running MFE/MAE off the last closed bar's extremes
      if(tj[i].dir>0)
      {
         tj[i].mfe = MathMax(tj[i].mfe, hi - tj[i].entry);
         tj[i].mae = MathMax(tj[i].mae, tj[i].entry - lo);
      }
      else
      {
         tj[i].mfe = MathMax(tj[i].mfe, tj[i].entry - lo);
         tj[i].mae = MathMax(tj[i].mae, hi - tj[i].entry);
      }

      // still open on the book?
      if(!PositionSelectByTicket(tj[i].ticket))
         TJ_Finalize(i);
   }
}

//==================================================================
// DEINIT — finalise any trades still open at end of run, close file.
//==================================================================
void TradeJournalDeinit()
{
   int n = ArraySize(tj);
   for(int i=0;i<n;i++)
      if(tj[i].open) TJ_Finalize(i);
   if(tj_fileHandle!=INVALID_HANDLE){ FileClose(tj_fileHandle); tj_fileHandle=INVALID_HANDLE; }
}

#endif // FALCON_TRADE_JOURNAL_MQH
//+------------------------------------------------------------------+
