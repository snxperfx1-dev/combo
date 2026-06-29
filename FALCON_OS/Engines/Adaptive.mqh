//+------------------------------------------------------------------+
//|  FALCON OS — Intelligence : Adaptive.mqh                        |
//|                                                                  |
//|  SELF-LEARNING / SELF-CORRECTION (bounded online feedback).      |
//|                                                                  |
//|  The OS learns from its OWN closed trades and corrects itself:   |
//|    1. Every entry is tagged with its CONTEXT bucket              |
//|       (direction x curve-locator band — where on the owner leg). |
//|    2. On close, the realised R-multiple (profit / risk-at-entry) |
//|       updates a recency-weighted edge estimate for that bucket.  |
//|    3. Future trades in a bucket are SIZED by its learned edge,   |
//|       and a persistently-losing bucket is VETOED ("learned       |
//|       avoidance" — it stops repeating its own mistakes).         |
//|                                                                  |
//|  SAFETY: a minimum sample is required before any adaptation;     |
//|  size multipliers are clamped; the estimate is an EWMA so it     |
//|  tracks regime change; it NEVER inverts direction or removes a   |
//|  risk control. The table persists to Common\Files so learning    |
//|  survives restarts. Interpretable: every number is visible.      |
//|                                                                  |
//|  Include BEFORE SymphonyEngine (entries call it). Reads the      |
//|  Curve Locator, so include AFTER CurveLocator.                   |
//+------------------------------------------------------------------+
#ifndef FALCON_ADAPTIVE_MQH
#define FALCON_ADAPTIVE_MQH

#include "../Kernel/FalconState.mqh"
#include "../Kernel/FalconConfig.mqh"
#include "../Kernel/FalconSeries.mqh"
#include "../Kernel/FalconLog.mqh"

//==================================================================
// CONTEXT BUCKETS — direction (L/S) x curve-locator band (5):
//   band 0:<20%  1:<40%  2:<60%  3:<80%  4:>=80% of the owner leg.
//   => 10 buckets. Low-dimensional on purpose so each gathers a
//   meaningful sample (over-bucketing = no learning).
//==================================================================
#define AD_NBUCKETS 10
double ad_ewmaR[AD_NBUCKETS];   // recency-weighted expectancy (R per trade)
int    ad_n[AD_NBUCKETS];       // sample count
int    ad_wins[AD_NBUCKETS];    // winning trades

// open-trade attribution records
struct ADRec { ulong ticket; bool open; int bucket; double risk; double predProb; };
ADRec  ad_rec[512];
int    ad_recCount = 0;
int    ad_saveTick = 0;
string ad_fileName = "";

// self-awareness accumulators (fed on each close; read by SelfAwareness)
int    ad_winStreak  = 0;
int    ad_lossStreak = 0;
double ad_calPredSum = 0.0;   // sum of entry executionProbability
double ad_calWinSum  = 0.0;   // sum of realised wins (0/1)
int    ad_calN       = 0;

int AD_BandIdx(const double pos)
{
   if(pos<0.20) return(0);
   if(pos<0.40) return(1);
   if(pos<0.60) return(2);
   if(pos<0.80) return(3);
   return(4);
}

int AD_Bucket(const int dir)
{
   int d = (dir==DIR_LONG?0:1);
   int b = AD_BandIdx(g_state.curveLocator.pos);
   return(d*5 + b);
}

//------------------------------------------------------------------
// Persistence (Common Files) — survive restarts.
//------------------------------------------------------------------
void AD_Load()
{
   for(int i=0;i<AD_NBUCKETS;i++){ ad_ewmaR[i]=0.0; ad_n[i]=0; ad_wins[i]=0; }
   if(!g_cfg.useAdaptive) return;
   ad_fileName = StringFormat("FALCON_Learn_%s_%s_%d.csv",
                              IntegerToString(g_cfg.magic), _Symbol, (int)g_cfg.operatingTF);
   int fh = FileOpen(ad_fileName, FILE_READ|FILE_CSV|FILE_ANSI|FILE_COMMON, ',');
   if(fh==INVALID_HANDLE) return;
   while(!FileIsEnding(fh))
   {
      int b=(int)FileReadNumber(fh); if(b<0||b>=AD_NBUCKETS){ if(FileIsLineEnding(fh))continue; else break; }
      ad_n[b]    =(int)FileReadNumber(fh);
      ad_wins[b] =(int)FileReadNumber(fh);
      ad_ewmaR[b]=     FileReadNumber(fh);
   }
   FileClose(fh);
   FalconLog("INFO","Adaptive","loaded learning table "+ad_fileName);
}

void AD_Save()
{
   if(!g_cfg.useAdaptive || !g_cfg.adaptPersist) return;
   int fh = FileOpen(ad_fileName, FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON, ',');
   if(fh==INVALID_HANDLE) return;
   for(int b=0;b<AD_NBUCKETS;b++)
      FileWrite(fh, b, ad_n[b], ad_wins[b], DoubleToString(ad_ewmaR[b],4));
   FileClose(fh);
}

void AdaptiveInit()
{
   ad_recCount=0; ad_saveTick=0;
   for(int i=0;i<512;i++){ ad_rec[i].open=false; ad_rec[i].ticket=0; }
   AD_Load();
}

//------------------------------------------------------------------
// SELF-CORRECTION FEEDBACK
//   SizeMult: winning bucket -> up to ceil, losing -> down to floor,
//   neutral / too-few-samples -> 1.0.
//   Veto: a bucket that loses >= |adaptVetoR| per trade over a robust
//   sample is blocked — the engine refuses to repeat its own mistake.
//------------------------------------------------------------------
double AD_SizeMult(const int bucket)
{
   if(!g_cfg.useAdaptive || bucket<0 || bucket>=AD_NBUCKETS) return(1.0);
   if(ad_n[bucket] < g_cfg.adaptMinTrades) return(1.0);
   double m = 1.0 + g_cfg.adaptSizeK*ad_ewmaR[bucket];
   return(FalconClamp(m, 0.30, 1.60));
}

bool AD_Veto(const int bucket)
{
   if(!g_cfg.useAdaptive || bucket<0 || bucket>=AD_NBUCKETS) return(false);
   if(ad_n[bucket] < g_cfg.adaptMinTrades*2) return(false);   // need a robust sample
   return(ad_ewmaR[bucket] <= g_cfg.adaptVetoR);
}

//------------------------------------------------------------------
// Record an entry's context for later attribution.
//------------------------------------------------------------------
void AD_RecordEntry(const ulong ticket,const int bucket,const double riskMoney,const double predProb=0.0)
{
   if(!g_cfg.useAdaptive || ticket==0 || riskMoney<=0.0) return;
   if(ad_recCount>=512) return;
   ad_rec[ad_recCount].ticket=ticket; ad_rec[ad_recCount].open=true;
   ad_rec[ad_recCount].bucket=bucket; ad_rec[ad_recCount].risk=riskMoney;
   ad_rec[ad_recCount].predProb=predProb;
   ad_recCount++;
}

double AD_RealizedProfit(const ulong posId)
{
   double pl=0.0;
   if(!HistorySelectByPosition(posId)) return(0.0);
   int dts=HistoryDealsTotal();
   for(int i=0;i<dts;i++)
   {
      ulong dt=HistoryDealGetTicket(i); if(dt==0) continue;
      pl += HistoryDealGetDouble(dt,DEAL_PROFIT)+HistoryDealGetDouble(dt,DEAL_SWAP);
   }
   return(pl);
}

void AD_Learn(const int bucket,const double R)
{
   if(bucket<0||bucket>=AD_NBUCKETS) return;
   double a = g_cfg.adaptAlpha;
   if(ad_n[bucket]==0) ad_ewmaR[bucket]=R; else ad_ewmaR[bucket]=ad_ewmaR[bucket]+a*(R-ad_ewmaR[bucket]);
   ad_n[bucket]++; if(R>0.0) ad_wins[bucket]++;
}

//------------------------------------------------------------------
// Each bar: attribute any closed trades, then periodically persist.
//------------------------------------------------------------------
void AdaptiveOnBar()
{
   if(!g_cfg.useAdaptive) return;
   for(int i=0;i<ad_recCount;i++)
   {
      if(!ad_rec[i].open) continue;
      if(PositionSelectByTicket(ad_rec[i].ticket)) continue;   // still open
      double profit = AD_RealizedProfit(ad_rec[i].ticket);
      double R = (ad_rec[i].risk>0.0 ? profit/ad_rec[i].risk : 0.0);
      bool   win = (profit>0.0);
      AD_Learn(ad_rec[i].bucket, R);
      // feed self-awareness: form (streaks) + calibration (predicted vs realised)
      if(win){ ad_winStreak++; ad_lossStreak=0; } else { ad_lossStreak++; ad_winStreak=0; }
      ad_calPredSum += ad_rec[i].predProb; ad_calWinSum += (win?1.0:0.0); ad_calN++;
      ad_rec[i].open=false;
   }
   if(++ad_saveTick >= 25){ ad_saveTick=0; AD_Save(); }
}

void AdaptiveDeinit(){ AD_Save(); }

#endif // FALCON_ADAPTIVE_MQH
//+------------------------------------------------------------------+
