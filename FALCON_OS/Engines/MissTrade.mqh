//+------------------------------------------------------------------+
//|  FALCON OS — Intelligence : MissTrade.mqh                       |
//|                                                                  |
//|  LEARN FROM MISSED TRADES (counterfactual / regret learning).   |
//|                                                                  |
//|  When a valid phase-edge signal is BLOCKED by a soft filter, the |
//|  OS opens a SHADOW (paper) trade with the same composed stop and |
//|  target. It then watches what that trade WOULD have done:        |
//|    • hit target first  -> the filter cost us a winner (+R)        |
//|    • hit stop first     -> the filter saved us a loser  (-1R)     |
//|  The realised shadow R is attributed to the VETO REASON. If a     |
//|  reason's shadow expectancy turns firmly POSITIVE over a sample,  |
//|  that filter is over-blocking -> the OS starts OVERRIDING it and  |
//|  TAKES the trades it used to miss.                                |
//|                                                                  |
//|  SAFETY: only SOFT filters are override-eligible (timing/quality  |
//|  — late-on-curve, no-zone, no-room, exhausted, network/participant|
//|  counter). HARD filters (owner/HTF opposes, CHoCH against, self   |
//|  stand-down, learned-avoid) are NEVER overridden. Bounded sample  |
//|  + EWMA + persisted. Reads ComposeTradePlan; include AFTER        |
//|  TradePlan, BEFORE SymphonyEngine.                                |
//+------------------------------------------------------------------+
#ifndef FALCON_MISS_TRADE_MQH
#define FALCON_MISS_TRADE_MQH

#include "../Kernel/FalconState.mqh"
#include "../Kernel/FalconConfig.mqh"
#include "../Kernel/FalconSeries.mqh"
#include "../Kernel/FalconLog.mqh"

// veto reason codes (shared with the fact gate)
#define VR_NONE        0
#define VR_HTF         1   // hard
#define VR_OWNER       2   // hard
#define VR_NOZONE      3   // soft (override-eligible)
#define VR_CHOCH       4   // hard
#define VR_NOROOM      5   // soft
#define VR_EXHAUST     6   // soft
#define VR_LATE        7   // soft
#define VR_NETWORK     8   // soft
#define VR_PARTICIPANT 9   // soft
#define VR_LEARNED     10  // hard (already learned)
#define VR_SELF        11  // hard (health)
#define VR_NREASONS    12

double mt_R[VR_NREASONS];     // EWMA shadow expectancy per reason
int    mt_n[VR_NREASONS];     // resolved shadow sample
int    mt_win[VR_NREASONS];

#define MT_MAXSHADOW 128
struct MTShadow { bool open; int dir; double entry, stop, target; int reason; int age; };
MTShadow mt_sh[MT_MAXSHADOW];
string   mt_fileName="";
int      mt_saveTick=0;

bool MT_Eligible(const int code)
{
   return(code==VR_NOZONE || code==VR_NOROOM || code==VR_EXHAUST
       || code==VR_LATE   || code==VR_NETWORK|| code==VR_PARTICIPANT);
}

//------------------------------------------------------------------
// Persistence
//------------------------------------------------------------------
void MT_Load()
{
   for(int i=0;i<VR_NREASONS;i++){ mt_R[i]=0.0; mt_n[i]=0; mt_win[i]=0; }
   if(!g_cfg.useMissLearn) return;
   mt_fileName = StringFormat("FALCON_Miss_%s_%s_%d.csv",
                              IntegerToString(g_cfg.magic), _Symbol, (int)g_cfg.operatingTF);
   int fh=FileOpen(mt_fileName, FILE_READ|FILE_CSV|FILE_ANSI|FILE_COMMON, ',');
   if(fh==INVALID_HANDLE) return;
   while(!FileIsEnding(fh))
   {
      int r=(int)FileReadNumber(fh); if(r<0||r>=VR_NREASONS){ if(FileIsLineEnding(fh))continue; else break; }
      mt_n[r]  =(int)FileReadNumber(fh);
      mt_win[r]=(int)FileReadNumber(fh);
      mt_R[r]  =     FileReadNumber(fh);
   }
   FileClose(fh);
   FalconLog("INFO","MissTrade","loaded counterfactual table "+mt_fileName);
}

void MT_Save()
{
   if(!g_cfg.useMissLearn || !g_cfg.adaptPersist) return;
   int fh=FileOpen(mt_fileName, FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON, ',');
   if(fh==INVALID_HANDLE) return;
   for(int r=0;r<VR_NREASONS;r++) FileWrite(fh, r, mt_n[r], mt_win[r], DoubleToString(mt_R[r],4));
   FileClose(fh);
}

void MissTradeInit()
{
   for(int i=0;i<MT_MAXSHADOW;i++) mt_sh[i].open=false;
   mt_saveTick=0;
   MT_Load();
}

//------------------------------------------------------------------
// OVERRIDE — has the OS learned to TAKE trades it used to skip for
// this reason? (soft reason + robust sample + positive shadow edge)
//------------------------------------------------------------------
bool MT_Override(const int code)
{
   if(!g_cfg.useMissLearn || !MT_Eligible(code)) return(false);
   if(mt_n[code] < g_cfg.missMinN) return(false);
   // SAFETY: never relax a filter (pull more trades in) while the system is
   // actually net-losing. Shadow fills are optimistic; overriding into a losing
   // book just compounds losses. Only override when the real edge is non-negative.
   if(ad_globalN >= g_cfg.missMinN && ad_globalR < 0.0) return(false);
   return(mt_R[code] >= g_cfg.missOverrideR);
}

//------------------------------------------------------------------
// Record a missed signal as a shadow trade (composed stop/target).
//------------------------------------------------------------------
void MT_RecordMiss(const int dir,const double entry,const int reason)
{
   if(!g_cfg.useMissLearn || !MT_Eligible(reason)) return;
   double atr=FalconATR(1); if(atr<=0.0) return;
   FalconTradePlan pl = ComposeTradePlan(dir, entry, atr);
   if(!pl.valid) return;
   int slot=-1;
   for(int i=0;i<MT_MAXSHADOW;i++) if(!mt_sh[i].open){ slot=i; break; }
   if(slot<0) return;   // book full — skip
   mt_sh[slot].open=true; mt_sh[slot].dir=dir; mt_sh[slot].entry=entry;
   mt_sh[slot].stop=pl.stop; mt_sh[slot].target=pl.target; mt_sh[slot].reason=reason; mt_sh[slot].age=0;
}

void MT_Resolve(const int reason,const double R,const bool win)
{
   if(reason<0||reason>=VR_NREASONS) return;
   double a=g_cfg.adaptAlpha;
   if(mt_n[reason]==0) mt_R[reason]=R; else mt_R[reason]=mt_R[reason]+a*(R-mt_R[reason]);
   mt_n[reason]++; if(win) mt_win[reason]++;
}

//------------------------------------------------------------------
// Each bar: advance shadow trades; resolve those that hit target/stop.
//------------------------------------------------------------------
void MissTradeOnBar()
{
   if(!g_cfg.useMissLearn) return;
   double hi=gHigh[1], lo=gLow[1];
   for(int i=0;i<MT_MAXSHADOW;i++)
   {
      if(!mt_sh[i].open) continue;
      mt_sh[i].age++;
      double e=mt_sh[i].entry, st=mt_sh[i].stop, tg=mt_sh[i].target;
      double denom=MathAbs(e-st); if(denom<1e-9){ mt_sh[i].open=false; continue; }
      if(mt_sh[i].dir==DIR_LONG)
      {
         if(lo<=st){ MT_Resolve(mt_sh[i].reason,-1.0,false); mt_sh[i].open=false; }
         else if(hi>=tg){ MT_Resolve(mt_sh[i].reason, (tg-e)/denom, true); mt_sh[i].open=false; }
      }
      else
      {
         if(hi>=st){ MT_Resolve(mt_sh[i].reason,-1.0,false); mt_sh[i].open=false; }
         else if(lo<=tg){ MT_Resolve(mt_sh[i].reason, (e-tg)/denom, true); mt_sh[i].open=false; }
      }
      if(mt_sh[i].open && mt_sh[i].age>=g_cfg.missMaxBars) mt_sh[i].open=false;  // expire (neutral)
   }
   if(++mt_saveTick>=25){ mt_saveTick=0; MT_Save(); }
}

void MissTradeDeinit(){ MT_Save(); }

#endif // FALCON_MISS_TRADE_MQH
//+------------------------------------------------------------------+
