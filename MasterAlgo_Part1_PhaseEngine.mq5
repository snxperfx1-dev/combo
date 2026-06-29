//+------------------------------------------------------------------+
//| MasterAlgo_Part1_PhaseEngine.mq5                                 |
//| Part 1: Core Infrastructure and Phase Engine                     |
//| Contains: Series buffers, inputs, global state, helpers,         |
//|           4-phase curvature engine, ARC v2 convexity             |
//| This file is #included by Part 6 (main EA file)                  |
//+------------------------------------------------------------------+
#property strict

#include <Trade\Trade.mqh>

//------------------------------------------------------------------
// 0. SERIES BUFFERS - EMULATE MT4 Time[], Open[], High[], Low[], Close[]
//------------------------------------------------------------------
double   gCloseSeries[];
double   gHighSeries[];
double   gLowSeries[];
datetime gTimeSeries[];

#define Close gCloseSeries
#define High  gHighSeries
#define Low   gLowSeries
#define Time  gTimeSeries

bool RefreshSeries(int barsNeeded = 5000)
{
   int need = barsNeeded;
   if(need < 500) need = 500;

   ArraySetAsSeries(gCloseSeries,true);
   ArraySetAsSeries(gHighSeries,true);
   ArraySetAsSeries(gLowSeries,true);
   ArraySetAsSeries(gTimeSeries,true);

   int c1 = CopyClose(_Symbol,_Period,0,need,gCloseSeries);
   int c2 = CopyHigh(_Symbol,_Period,0,need,gHighSeries);
   int c3 = CopyLow(_Symbol,_Period,0,need,gLowSeries);
   int c4 = CopyTime(_Symbol,_Period,0,need,gTimeSeries);

   if(c1 <= 0 || c2 <= 0 || c3 <= 0 || c4 <= 0)
   {
      Print("RefreshSeries failed: ",c1," ",c2," ",c3," ",c4);
      return(false);
   }
   return(true);
}

//==================================================================
// 1. INPUTS - CORE ENGINE
//==================================================================
input int    InpPivotLen          = 5;      // Pivot length
input int    InpATRLen            = 14;     // ATR length
input double InpImpulseAtrMult   = 1.5;    // Impulse ATR multiple
input double InpRetrMin          = 0.30;   // Min retracement (fraction)
input double InpRetrMax          = 0.80;   // Max retracement (fraction)
input int    InpInducLookbackBars= 80;     // Flipzone lookback (bars)
input double InpInducZoneATRWidth= 0.25;   // Flipzone half-width (ATR)

//==================================================================
// 1B. ARC v2 INPUTS (CONVEXITY ARC)
//==================================================================
input int    InpArcHorizonBars   = 80;     // Arc horizon (bars)
input double InpConvPower        = 1.5;    // Arc convexity power
input double InpArcExtMult       = 1.5;    // Arc extension (imp multiple)

//==================================================================
// 1C. ARC + INSTITUTIONAL EXIT CONTROLS
//==================================================================
input double InpOuterBandAtrMult = 0.75;   // distance from induc/anchor to outer band (ATR)
input double InpArcToleranceAtr  = 0.20;   // how close to ARC counts as "exhaust" (ATR)

//==================================================================
// 2. INPUTS - TRADING LAYER
//==================================================================
input double InpRiskPercent      = 0.5;    // Risk % per trade
input int    InpMagic            = 240220; // EA magic number

// Timing - target session timezone (GMT baseline)
input int    InpTargetGMT        = 0;      // Target session timezone (GMT offset)

//==================================================================
// 3. GLOBAL STATE - PHASE ENGINE
//==================================================================

// Pivot history
double g_lastPivotPrice = 0.0;
int    g_lastPivotShift = -1;
int    g_lastPivotDir   = 0;   // 1 = high, -1 = low, 0 = none

double g_prevPivotPrice = 0.0;
int    g_prevPivotShift = -1;
int    g_prevPivotDir   = 0;

// Impulse / mode
int    g_mode           = 0;   // -1 short, 1 long, 0 none
double g_anchorHigh     = 0.0;
double g_anchorLow      = 0.0;
int    g_anchorHighShift= -1;
int    g_anchorLowShift = -1;

// Phases
int    g_phaseShort     = 0;
int    g_phaseLong      = 0;
int    g_prevPhaseShort = 0;
int    g_prevPhaseLong  = 0;

// Flipzone / inducement
double g_shortInducPrice = 0.0;
double g_shortInducLow   = 0.0;
double g_shortInducHigh  = 0.0;
double g_longInducPrice  = 0.0;
double g_longInducLow    = 0.0;
double g_longInducHigh   = 0.0;

// Pre-Conv seen flags (per impulse)
bool   g_shortPreConvSeen = false;
bool   g_longPreConvSeen  = false;

// ARC v2 state
double g_arcLong  = 0.0;
double g_arcShort = 0.0;

// Institutional outer-band sweep flags
bool   g_longOuterBreachSeen  = false;
bool   g_shortOuterBreachSeen = false;

// New bar detection + one trade per direction per bar
datetime g_lastBarTime        = 0;
datetime g_lastLongTradeTime  = 0;
datetime g_lastShortTradeTime = 0;

//==================================================================
// 5. BASIC HELPERS
//==================================================================
bool IsNewBar()
{
   datetime t = Time[0];
   if(t != g_lastBarTime)
   {
      g_lastBarTime = t;
      return(true);
   }
   return(false);
}

double GetATR(int shift)
{
   static int handleATR = INVALID_HANDLE;
   if(handleATR == INVALID_HANDLE)
   {
      handleATR = iATR(_Symbol,_Period,InpATRLen);
      if(handleATR == INVALID_HANDLE)
      {
         Print("iATR handle failed");
         return(0.0);
      }
   }
   double buffer[];
   ArraySetAsSeries(buffer,true);
   if(CopyBuffer(handleATR,0,shift+1,1,buffer) < 1)
      return(0.0);
   return(buffer[0]);
}

double GetATRSmooth(int shift, int len)
{
   double sum = 0.0;
   int    c   = 0;
   int    maxBars = (int)ArraySize(Close);
   for(int i = shift; i < shift + len; i++)
   {
      if(i >= maxBars) break;
      sum += GetATR(i);
      c++;
   }
   if(c <= 0) return(GetATR(shift));
   return(sum / c);
}

bool IsPivotHigh(int c)
{
   int maxBars = (int)ArraySize(High);
   if(c <= 0 || c >= maxBars) return(false);
   double h = High[c];
   for(int k = 1; k <= InpPivotLen; k++)
   {
      if(c + k >= maxBars || c - k < 0) return(false);
      if(h <= High[c + k]) return(false);
      if(h <= High[c - k]) return(false);
   }
   return(true);
}

bool IsPivotLow(int c)
{
   int maxBars = (int)ArraySize(Low);
   if(c <= 0 || c >= maxBars) return(false);
   double l = Low[c];
   for(int k = 1; k <= InpPivotLen; k++)
   {
      if(c + k >= maxBars || c - k < 0) return(false);
      if(l >= Low[c + k]) return(false);
      if(l >= Low[c - k]) return(false);
   }
   return(true);
}

//==================================================================
// 5A. TIME HELPERS - LONDON + US SESSIONS, NO ASIA (GMT baseline)
//==================================================================
bool IsTradeTime()
{
   // GMT baseline
   MqlDateTime g;
   TimeGMT(g);

   int h = g.hour + InpTargetGMT;
   int m = g.min;

   if(h < 0)   h += 24;
   if(h >= 24) h -= 24;

   int curMin = h * 60 + m;

   // London AM 08:00-11:45
   bool w1 = (curMin >= 480 && curMin <= 705);

   // UK micro 11:45-12:15
   bool w2 = (curMin >= 705 && curMin <= 735);

   // 13:15-13:45 (13:30 +/- 15 min)
   bool w3 = (curMin >= 795 && curMin <= 825);

   // US session 14:30-18:00
   bool w4 = (curMin >= 870 && curMin <= 1080);

   // early London window 08:00-09:00
   bool key_0800_0900 = (curMin >= 480 && curMin <= 540);

   // 08:30 +/- 15 -> 08:15-08:45
   bool key_0830 = (curMin >= 495 && curMin <= 525);

   // 15:00 +/- 15 -> 14:45-15:15
   bool key_1500 = (curMin >= 885 && curMin <= 915);

   // 17:00 +/- 15 -> 16:45-17:15
   bool key_1700 = (curMin >= 1005 && curMin <= 1035);

   return (
      w1 || w2 || w3 || w4 ||
      key_0800_0900 ||
      key_0830 ||
      key_1500 ||
      key_1700
   );
}

//==================================================================
// 6. PHASE ENGINE - IMPULSE + PHASES (1-4)
//==================================================================
void UpdatePhaseEngine()
{
   int barsAvail = (int)ArraySize(Close);
   if(barsAvail <= (2 * InpPivotLen + 5)) return;

   int    shiftNow   = 1;
   double closeNow   = Close[shiftNow];
   double atrNow     = GetATR(shiftNow);
   double atrRef     = atrNow;

   int    centerShift = InpPivotLen + 1;
   int    pivotDir    = 0;
   double pivotPrice  = 0.0;
   int    pivotShift  = -1;

   if(centerShift < barsAvail - InpPivotLen)
   {
      if(IsPivotHigh(centerShift))
      {
         pivotDir   = 1;
         pivotPrice = High[centerShift];
         pivotShift = centerShift;
      }
      else if(IsPivotLow(centerShift))
      {
         pivotDir   = -1;
         pivotPrice = Low[centerShift];
         pivotShift = centerShift;
      }
   }

   // SHORT impulse: last high -> new low
   if(pivotDir == -1 && g_lastPivotDir == 1)
   {
      double r = g_lastPivotPrice - pivotPrice;
      if(r > atrRef * InpImpulseAtrMult)
      {
         g_mode            = -1;
         g_anchorHigh      = g_lastPivotPrice;
         g_anchorHighShift = g_lastPivotShift;
         g_anchorLow       = pivotPrice;
         g_anchorLowShift  = pivotShift;

         g_phaseShort      = 1;
         g_phaseLong       = 0;

         g_shortPreConvSeen = false;
         g_longPreConvSeen  = false;

         g_shortInducPrice = 0.0;
         g_shortInducLow   = 0.0;
         g_shortInducHigh  = 0.0;
         g_longInducPrice  = 0.0;
         g_longInducLow    = 0.0;
         g_longInducHigh   = 0.0;

         g_longOuterBreachSeen  = false;
         g_shortOuterBreachSeen = false;

         double lvlS = 0.0;
         int    bestDistS = -1;
         if(g_anchorHighShift > 0)
         {
            for(int s = g_anchorHighShift - 1;
                s >= 0 && s >= g_anchorHighShift - InpInducLookbackBars;
                s--)
            {
               bool inside = (High[s] < g_anchorHigh && Low[s] > g_anchorLow);
               if(inside)
               {
                  int dist = MathAbs(g_anchorHighShift - s);
                  if(bestDistS < 0 || dist < bestDistS)
                  {
                     bestDistS = dist;
                     lvlS      = (High[s] + Low[s]) * 0.5;
                  }
               }
            }
         }
         if(bestDistS >= 0)
         {
            g_shortInducPrice = lvlS;
            g_shortInducLow   = lvlS - atrRef * InpInducZoneATRWidth;
            g_shortInducHigh  = lvlS + atrRef * InpInducZoneATRWidth;
         }
      }
   }
   // LONG impulse: last low -> new high
   else if(pivotDir == 1 && g_lastPivotDir == -1)
   {
      double r = pivotPrice - g_lastPivotPrice;
      if(r > atrRef * InpImpulseAtrMult)
      {
         g_mode            = 1;
         g_anchorLow       = g_lastPivotPrice;
         g_anchorLowShift  = g_lastPivotShift;
         g_anchorHigh      = pivotPrice;
         g_anchorHighShift = pivotShift;

         g_phaseLong       = 1;
         g_phaseShort      = 0;

         g_shortPreConvSeen = false;
         g_longPreConvSeen  = false;

         g_shortInducPrice = 0.0;
         g_shortInducLow   = 0.0;
         g_shortInducHigh  = 0.0;
         g_longInducPrice  = 0.0;
         g_longInducLow    = 0.0;
         g_longInducHigh   = 0.0;

         g_longOuterBreachSeen  = false;
         g_shortOuterBreachSeen = false;

         double lvlL = 0.0;
         int    bestDistL = -1;
         if(g_anchorLowShift > 0)
         {
            for(int s = g_anchorLowShift - 1;
                s >= 0 && s >= g_anchorLowShift - InpInducLookbackBars;
                s--)
            {
               bool inside = (High[s] < g_anchorHigh && Low[s] > g_anchorLow);
               if(inside)
               {
                  int dist = MathAbs(g_anchorLowShift - s);
                  if(bestDistL < 0 || dist < bestDistL)
                  {
                     bestDistL = dist;
                     lvlL      = (High[s] + Low[s]) * 0.5;
                  }
               }
            }
         }
         if(bestDistL >= 0)
         {
            g_longInducPrice = lvlL;
            g_longInducLow   = lvlL - atrRef * InpInducZoneATRWidth;
            g_longInducHigh  = lvlL + atrRef * InpInducZoneATRWidth;
         }
      }
   }

   // Persist pivot history
   if(pivotDir != 0)
   {
      g_prevPivotPrice = g_lastPivotPrice;
      g_prevPivotShift = g_lastPivotShift;
      g_prevPivotDir   = g_lastPivotDir;

      g_lastPivotPrice = pivotPrice;
      g_lastPivotShift = pivotShift;
      g_lastPivotDir   = pivotDir;
   }

   // Impulse invalidation
   if(g_mode == -1 && closeNow > g_anchorHigh)
   {
      g_mode             = 0;
      g_phaseShort       = 0;
      g_shortInducPrice  = 0.0;
      g_shortInducLow    = 0.0;
      g_shortInducHigh   = 0.0;
      g_shortPreConvSeen = false;
      g_longPreConvSeen  = false;
      g_longOuterBreachSeen  = false;
      g_shortOuterBreachSeen = false;
   }
   if(g_mode == 1 && closeNow < g_anchorLow)
   {
      g_mode             = 0;
      g_phaseLong        = 0;
      g_longInducPrice   = 0.0;
      g_longInducLow     = 0.0;
      g_longInducHigh    = 0.0;
      g_shortPreConvSeen = false;
      g_longPreConvSeen  = false;
      g_longOuterBreachSeen  = false;
      g_shortOuterBreachSeen = false;
   }

   int oldPhaseShort = g_phaseShort;
   int oldPhaseLong  = g_phaseLong;

   // SHORT side phase calculation
   if(g_mode != -1) g_phaseShort = 0;
   if(g_mode == -1 && g_anchorHighShift >= 0 && g_anchorLowShift >= 0)
   {
      double impS  = g_anchorHigh - g_anchorLow;
      double retrS = (impS > 0.0) ? (closeNow - g_anchorLow) / impS : 0.0;
      double dS    = Close[shiftNow] - Close[shiftNow+1];

      int phaseTmpS;
      if(retrS > InpRetrMax || retrS < 0.0)
         phaseTmpS = 0;
      else if(closeNow <= g_anchorLow)
         phaseTmpS = 4;
      else if(retrS >= InpRetrMin)
         phaseTmpS = (dS > 0.0 ? 2 : 3);
      else
         phaseTmpS = 1;

      bool hasShortZone = (g_shortInducLow != 0.0 || g_shortInducHigh != 0.0);
      if(phaseTmpS == 3 && hasShortZone && closeNow <= g_shortInducHigh)
         phaseTmpS = 2;
      else if(phaseTmpS == 3)
         g_shortPreConvSeen = true;

      if(phaseTmpS == 4 && !g_shortPreConvSeen)
         phaseTmpS = 2;

      g_phaseShort = phaseTmpS;
   }

   // LONG side phase calculation
   if(g_mode != 1) g_phaseLong = 0;
   if(g_mode == 1 && g_anchorHighShift >= 0 && g_anchorLowShift >= 0)
   {
      double impL  = g_anchorHigh - g_anchorLow;
      double retrL = (impL > 0.0) ? (g_anchorHigh - closeNow) / impL : 0.0;
      double dL    = Close[shiftNow] - Close[shiftNow+1];

      int phaseTmpL;
      if(retrL > InpRetrMax || retrL < 0.0)
         phaseTmpL = 0;
      else if(closeNow >= g_anchorHigh)
         phaseTmpL = 4;
      else if(retrL >= InpRetrMin)
         phaseTmpL = (dL < 0.0 ? 2 : 3);
      else
         phaseTmpL = 1;

      bool hasLongZone = (g_longInducLow != 0.0 || g_longInducHigh != 0.0);
      if(phaseTmpL == 3 && hasLongZone && closeNow >= g_longInducLow)
         phaseTmpL = 2;
      else if(phaseTmpL == 3)
         g_longPreConvSeen = true;

      if(phaseTmpL == 4 && !g_longPreConvSeen)
         phaseTmpL = 2;

      g_phaseLong = phaseTmpL;
   }

   g_prevPhaseShort = oldPhaseShort;
   g_prevPhaseLong  = oldPhaseLong;
}

//==================================================================
// 6B. ARC v2 CALCULATION (CONVEXITY ARC)
//==================================================================
void UpdateARC()
{
   g_arcLong  = 0.0;
   g_arcShort = 0.0;

   int bars = ArraySize(Close);
   if(bars < 10) return;

   int shift = 1; // last closed bar

   // LONG ARC: from anchorLow -> projected high target
   if(g_mode == 1 && g_anchorLowShift >= 0 && g_anchorHighShift >= 0)
   {
      double impL = g_anchorHigh - g_anchorLow;
      if(impL > 0)
      {
         double targetL = g_anchorLow + impL * InpArcExtMult;

         double tL = (double)(g_anchorLowShift - shift) / (double)InpArcHorizonBars;
         if(tL < 0.0) tL = 0.0;
         if(tL > 1.0) tL = 1.0;

         g_arcLong = g_anchorLow + (targetL - g_anchorLow) * MathPow(tL, InpConvPower);
      }
   }

   // SHORT ARC: from anchorHigh -> projected low target
   if(g_mode == -1 && g_anchorLowShift >= 0 && g_anchorHighShift >= 0)
   {
      double impS = g_anchorHigh - g_anchorLow;
      if(impS > 0)
      {
         double targetS = g_anchorHigh - impS * InpArcExtMult;

         double tS = (double)(g_anchorHighShift - shift) / (double)InpArcHorizonBars;
         if(tS < 0.0) tS = 0.0;
         if(tS > 1.0) tS = 1.0;

         g_arcShort = g_anchorHigh + (targetS - g_anchorHigh) * MathPow(tS, InpConvPower);
      }
   }
}
//+------------------------------------------------------------------+
