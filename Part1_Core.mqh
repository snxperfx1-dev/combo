//+------------------------------------------------------------------+
//| Part1_Core.mqh - Core Infrastructure, Helpers, Series Buffers,  |
//|                  Input Parameters, and Global State Declarations |
//| Master MT5 EA: Symphony + Letra + F16 Combined System           |
//+------------------------------------------------------------------+
#property strict

#include <Trade\Trade.mqh>

//==================================================================
// 0. SERIES BUFFERS - EMULATE MT4 Time[], Open[], High[], Low[], Close[]
//==================================================================
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

   ArraySetAsSeries(gCloseSeries, true);
   ArraySetAsSeries(gHighSeries, true);
   ArraySetAsSeries(gLowSeries, true);
   ArraySetAsSeries(gTimeSeries, true);

   int c1 = CopyClose(_Symbol, _Period, 0, need, gCloseSeries);
   int c2 = CopyHigh(_Symbol, _Period, 0, need, gHighSeries);
   int c3 = CopyLow(_Symbol, _Period, 0, need, gLowSeries);
   int c4 = CopyTime(_Symbol, _Period, 0, need, gTimeSeries);

   if(c1 <= 0 || c2 <= 0 || c3 <= 0 || c4 <= 0)
   {
      Print("RefreshSeries failed: ", c1, " ", c2, " ", c3, " ", c4);
      return(false);
   }
   return(true);
}

//==================================================================
// 1. INPUTS - CORE ENGINE (from Symphony Phase Engine)
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
input double InpArcExtMult       = 1.5;    // Arc extension (impulse multiple)
input double InpArcToleranceAtr  = 0.20;   // How close to ARC counts as exhaust (ATR)
input double InpOuterBandAtrMult = 0.75;   // Distance from induc/anchor to outer band (ATR)

//==================================================================
// 2. INPUTS - TRADING LAYER
//==================================================================
input double InpRiskPercent      = 0.5;    // Risk % per trade
input int    InpMagic            = 240220; // EA magic number
input int    InpTargetGMT        = 0;      // Target session timezone (GMT offset)

//==================================================================
// 3. INPUTS - LETRA ENGINE (Multi-TF Structure)
//==================================================================
input int    InpEffLen           = 10;     // Efficiency length
input double InpEffThresh        = 0.65;   // Efficiency threshold
input double InpDispThresh       = 1.5;    // Dispersion threshold
input double InpConvMult         = 0.01;   // Convexity multiplier
input double InpChochBufferATR   = 0.75;   // CHoCH buffer (ATR fraction)
input int    InpStructLen        = 10;     // Structure detection length
input int    InpAcceptBars       = 2;      // Acceptance bars for confirmation
input int    InpObMaxBars        = 50;     // Order block max bars age
input double InpInducZoneWidth   = 0.25;   // Inducement zone width (ATR)
input int    InpLiqSweepLookback = 10;     // Liquidity sweep lookback bars
input double InpLiqRadius        = 0.25;   // Liquidity radius (ATR)
input double InpLiqAgDecay       = 0.95;   // Liquidity aging decay factor
input bool   InpRequireLiqSweep  = true;   // Require liquidity sweep for entry
input int    InpResetBars        = 20;     // Phase reset bars threshold
input int    InpBeliefSmooth     = 3;      // Belief smoothing period

//==================================================================
// 4. INPUTS - F16 NETWORK (Invisible Network + Curve Tree)
//==================================================================
input double InpWickFrac         = 0.3;    // Wick fraction threshold
input int    InpFULookback       = 3;      // Follow-up lookback bars
input int    InpAuthMin          = 45;     // Minimum authority score
input int    InpNodeMax          = 250;    // Maximum network nodes
input int    InpDormantBars      = 120;    // Bars until node goes dormant
input int    InpHistoryBars      = 600;    // History bars for node scanning



//==================================================================
// 5. INPUTS - SENSEEI (Meta-Intelligence)
//==================================================================
input int    InpMinConf          = 55;     // Minimum confidence for Senseei

//==================================================================
// 6. INPUTS - PROBABILISTIC ENTRY
//==================================================================
input double InpEntryProbThreshold = 90.0; // Minimum entry probability (%)

//==================================================================
// 10. GLOBAL STATE STRUCTS
//==================================================================

//--- Phase Engine State (from Symphony)
struct PhaseEngineState
{
   double   lastPivotPrice;
   int      lastPivotShift;
   int      lastPivotDir;        // 1=high, -1=low, 0=none
   double   prevPivotPrice;
   int      prevPivotShift;
   int      prevPivotDir;
   int      mode;                // -1=short, 1=long, 0=none
   double   anchorHigh;
   double   anchorLow;
   int      anchorHighShift;
   int      anchorLowShift;
   int      phaseShort;
   int      phaseLong;
   int      prevPhaseShort;
   int      prevPhaseLong;
   double   shortInducPrice;
   double   shortInducLow;
   double   shortInducHigh;
   double   longInducPrice;
   double   longInducLow;
   double   longInducHigh;
   bool     shortPreConvSeen;
   bool     longPreConvSeen;
   double   arcLong;
   double   arcShort;
   bool     longOuterBreachSeen;
   bool     shortOuterBreachSeen;
   datetime lastBarTime;
   datetime lastLongTradeTime;
   datetime lastShortTradeTime;
};

//--- Letra Structure Result (per timeframe)
struct LetraStructureResult
{
   int      dir;                 // 1=bullish, -1=bearish, 0=neutral
   int      phase;               // Current structure phase
   double   swingHigh;
   double   swingLow;
   double   prevSwingHigh;
   double   prevSwingLow;
   bool     bos;                 // Break of structure
   bool     choch;               // Change of character
   double   p4h;                 // Point 4 high
   double   p4l;                 // Point 4 low
   double   inv;                 // Invalidation level
   double   tgt;                 // Target level
   double   ft;                  // Fair value top
   double   fb;                  // Fair value bottom
   double   frzScore;            // FRZ zone score
   double   waveProgress;        // Wave progress 0-1
   double   convexityMaturity;   // Convexity maturity 0-1
   double   modelFit;            // Model fit score
   double   compression;         // Compression score
   bool     recBrk;              // Recursive break flag
   int      recDom;              // Recursive dominance direction
};

//--- Energy Framework State (EDE + RE + EAE from Letra)
struct EnergyFrameworkState
{
   int      ede_state;                   // EDE phase state
   double   ede_expansionEnergy;         // Current expansion energy
   double   ede_dissipatedEnergy;        // Dissipated energy
   double   ede_dissipationProgress;     // 0-1 progress of dissipation
   int      re_resolutionState;          // 0=unresolved, 1=partial, 2=resolved
   double   re_residualEnergyScore;      // Residual energy score
   double   re_recursiveCompletionScore; // How complete the recursive pattern is
   double   eae_primaryAttractorPrice;   // Equilibrium attractor price
   double   eae_primaryAttractorScore;   // Attractor strength score
   double   waveProgress;                // Overall wave progress 0-1
   double   convexityMaturity;           // Overall convexity maturity 0-1
   double   beliefs[6];                  // Belief scores per timeframe
   double   hypotheses[6];               // Hypothesis scores per timeframe
   int      predictionNextPhase;         // Predicted next phase direction
   double   predictionProb;              // Prediction probability
   double   modelConfidence;             // Overall model confidence
};

//--- Curve Object (F72 from F16)
struct CurveObject
{
   int      dir;                 // 1=up, -1=down
   double   origin;              // Origin price
   double   extreme;             // Extreme price
   double   dispATR;             // Dispersion in ATR units
   double   eIn;                 // Input energy
   double   eDiss;               // Dissipated energy
   double   eRes;                // Residual energy
   double   convex;              // Convexity score
   double   compress;            // Compression score
   double   maturity;            // Maturity 0-1
};

//--- Curve Node (Recursive tree node from F16)
struct CurveNode
{
   int      id;
   int      parent;
   int      dir;                 // 1=up, -1=down
   double   origin;
   double   extreme;
   double   energy;
   bool     alive;
   int      depth;
   char     state[64];           // Phase string (char array)
   int      bar;                 // Bar index of creation
   double   comp;                // Compression
   double   mat;                 // Maturity
   int      srcTf;               // Source timeframe index
};

//--- Network Node (Invisible Network from F16)
struct NetworkNode
{
   double   px;                  // Price level
   double   mid;                 // Mid-level
   int      dir;                 // 1=buy, -1=sell, 0=neutral
   double   score;               // Authority score
   double   weight;              // Weight factor
   int      state;               // Node state (active/dormant/dead)
   int      bar;                 // Bar of last update
   int      revisits;            // Number of revisits
};

//--- Time Intelligence Cycle (from F16)
struct TimeIntelCycle
{
   double   open;
   double   high;
   double   low;
   double   prevHigh;
   double   prevLow;
   datetime time;
   int      bias;                // 1=bull, -1=bear, 0=neutral
   int      elapsed;             // Minutes elapsed in cycle
   bool     highTaken;
   bool     lowTaken;
};

//--- Senseei State (Meta-Intelligence from F16)
struct SenseeiState
{
   int      master;              // Master direction 1/-1/0
   int      alignment;           // Alignment score
   int      conflict;            // Conflict level
   int      confidence;          // Confidence 0-100
   int      threat;              // Threat level 0-100
   double   oppScore;            // Opportunity score
   double   entryProb;           // Entry probability
   char     timing[32];          // Timing state string
   char     intent[32];          // Intent state string
   char     opportunity[32];     // Opportunity state string
   char     action[32];          // Action state string
};

//--- Wave Spawn State (Engine 1A lifecycle from Letra)
struct WaveSpawnState
{
   int      direction;           // 1=long, -1=short, 0=none
   double   flipTop;
   double   flipBot;
   int      obBirthBar;
   int      barsInZone;
   int      contBar;
   double   point4OriginHigh;
   double   point4OriginLow;
   int      point4OriginBar;
   double   flipzoneInducPrice;
   double   flipzoneInducLow;
   double   flipzoneInducHigh;
   double   inducExpOriginHigh;
   double   inducExpExtremeLow;
   double   inducExpOriginLow;
   double   inducExpExtremeHigh;
   double   inducRetrOriginHigh;
   double   inducRetrExtremeLow;
   double   inducRetrOriginLow;
   double   inducRetrExtremeHigh;
   double   inducZoneLow;
   double   inducZoneHigh;
   double   cycleHigh;
   double   cycleLow;
   int      waveGeneration;
   int      entryCycle;
   bool     isRecursiveWave;
   int      waveDepth;
   int      lastSpawnDir;
   bool     recursiveComplete;
};

//==================================================================
// 11. GLOBAL STATE INSTANCES
//==================================================================
PhaseEngineState     g_phase;
LetraStructureResult g_letra[6];           // M1, M3, M5, M15, H1, H4
EnergyFrameworkState g_energy;
CurveObject          g_curve;
CurveNode            g_curveTree[60];
int                  g_curveTreeCount = 0;
NetworkNode          g_nodes[250];
int                  g_nodeCount = 0;
TimeIntelCycle       g_timeCycles[5];      // MN, W, D, H4, H1
SenseeiState         g_senseei;
WaveSpawnState       g_spawn;
int                  g_fractalStackDir   = 0;
double               g_fractalStackScore = 0.0;

//==================================================================
// 12. MULTI-TIMEFRAME DATA ACCESS
//==================================================================

// Timeframe index mapping: 0=M1, 1=M3, 2=M5, 3=M15, 4=H1, 5=H4
ENUM_TIMEFRAMES GetLetraTF(int idx)
{
   switch(idx)
   {
      case 0: return(PERIOD_M1);
      case 1: return(PERIOD_M3);
      case 2: return(PERIOD_M5);
      case 3: return(PERIOD_M15);
      case 4: return(PERIOD_H1);
      case 5: return(PERIOD_H4);
      default: return(PERIOD_M5);
   }
}

// Copy OHLC from a specific timeframe
bool CopyTFData(int tfIdx, int count, double &closeArr[], double &highArr[], double &lowArr[])
{
   ENUM_TIMEFRAMES tf = GetLetraTF(tfIdx);

   ArraySetAsSeries(closeArr, true);
   ArraySetAsSeries(highArr, true);
   ArraySetAsSeries(lowArr, true);

   int c1 = CopyClose(_Symbol, tf, 0, count, closeArr);
   int c2 = CopyHigh(_Symbol, tf, 0, count, highArr);
   int c3 = CopyLow(_Symbol, tf, 0, count, lowArr);

   if(c1 <= 0 || c2 <= 0 || c3 <= 0)
   {
      Print("CopyTFData failed for tfIdx=", tfIdx, ": ", c1, " ", c2, " ", c3);
      return(false);
   }
   return(true);
}

// Copy time data from a specific timeframe
bool CopyTFTime(int tfIdx, int count, datetime &timeArr[])
{
   ENUM_TIMEFRAMES tf = GetLetraTF(tfIdx);
   ArraySetAsSeries(timeArr, true);
   int c = CopyTime(_Symbol, tf, 0, count, timeArr);
   if(c <= 0)
   {
      Print("CopyTFTime failed for tfIdx=", tfIdx);
      return(false);
   }
   return(true);
}

// Get ATR for a specific timeframe
double GetTFATR(int tfIdx, int period, int shift)
{
   static int tfHandles[];
   static bool tfHandlesInit = false;
   if(!tfHandlesInit)
   {
      ArrayResize(tfHandles, 6);
      for(int i = 0; i < 6; i++)
         tfHandles[i] = INVALID_HANDLE;
      tfHandlesInit = true;
   }

   if(tfIdx < 0 || tfIdx > 5) return(0.0);

   ENUM_TIMEFRAMES tf = GetLetraTF(tfIdx);

   if(tfHandles[tfIdx] == INVALID_HANDLE)
   {
      tfHandles[tfIdx] = iATR(_Symbol, tf, period);
      if(tfHandles[tfIdx] == INVALID_HANDLE)
      {
         Print("iATR handle failed for tfIdx=", tfIdx);
         return(0.0);
      }
   }

   double buffer[];
   ArraySetAsSeries(buffer, true);
   if(CopyBuffer(tfHandles[tfIdx], 0, shift, 1, buffer) < 1)
      return(0.0);
   return(buffer[0]);
}

//==================================================================
// 13. BASIC HELPERS (ported from Symphony)
//==================================================================

bool IsNewBar()
{
   datetime t = Time[0];
   if(t != g_phase.lastBarTime)
   {
      g_phase.lastBarTime = t;
      return(true);
   }
   return(false);
}

double GetATR(int shift)
{
   static int handleATR = INVALID_HANDLE;
   if(handleATR == INVALID_HANDLE)
   {
      handleATR = iATR(_Symbol, _Period, InpATRLen);
      if(handleATR == INVALID_HANDLE)
      {
         Print("iATR handle failed");
         return(0.0);
      }
   }
   double buffer[];
   ArraySetAsSeries(buffer, true);
   if(CopyBuffer(handleATR, 0, shift, 1, buffer) < 1)
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
// 14. LOT ENGINE - XAUUSD MODEL (from Symphony)
//==================================================================
double ComputeLots(double riskCash, double entry, double sl)
{
   // Absolute distance in price
   double dist = MathAbs(entry - sl);
   if(dist <= 0.0) return(0.0);

   // Distance in gold pips: $0.10 = 1 pip
   double distancePips = dist * 10.0;

   // Pip value per 1.00 lot: $10 per pip
   double pipValuePerLot = 10.0;

   // Total risk per full lot at this SL distance
   double riskPerLot = distancePips * pipValuePerLot;
   if(riskPerLot <= 0.0) return(0.0);

   // Raw lots from risk
   double lots = riskCash / riskPerLot;

   // Broker constraints
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   // Normalize to broker increment, floor
   lots = MathFloor(lots / lotStep) * lotStep;
   if(lots < minLot) lots = minLot;

   return(NormalizeDouble(lots, 2));
}

//==================================================================
// 15. TIME HELPERS - LONDON + US SESSIONS (GMT baseline, from Symphony)
//==================================================================
bool IsTradeTime()
{
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

   // Early London window 08:00-09:00
   bool key_0800_0900 = (curMin >= 480 && curMin <= 540);

   // 08:30 +/- 15 min
   bool key_0830 = (curMin >= 495 && curMin <= 525);

   // 15:00 +/- 15 min
   bool key_1500 = (curMin >= 885 && curMin <= 915);

   // 17:00 +/- 15 min
   bool key_1700 = (curMin >= 1005 && curMin <= 1035);

   return(w1 || w2 || w3 || w4 ||
          key_0800_0900 || key_0830 || key_1500 || key_1700);
}

//==================================================================
// 16. UTILITY / MATH FUNCTIONS
//==================================================================

// Min-max normalization of array
void NormalizeArray(double &src[], int n, double &dst[])
{
   if(n <= 0) return;
   ArrayResize(dst, n);

   double mn = src[0];
   double mx = src[0];
   for(int i = 1; i < n; i++)
   {
      if(src[i] < mn) mn = src[i];
      if(src[i] > mx) mx = src[i];
   }

   double range = mx - mn;
   if(range <= 0.0)
   {
      for(int i = 0; i < n; i++)
         dst[i] = 0.0;
      return;
   }

   for(int i = 0; i < n; i++)
      dst[i] = (src[i] - mn) / range;
}

// EMA smoothing: alpha = 2/(period+1)
double EmaSmooth(double prev, double raw, int period)
{
   if(period <= 0) return(raw);
   double alpha = 2.0 / (period + 1.0);
   return(alpha * raw + (1.0 - alpha) * prev);
}

// Clamp value between min and max
double Clamp(double val, double mn, double mx)
{
   if(val < mn) return(mn);
   if(val > mx) return(mx);
   return(val);
}

// Ideal similarity using Euclidean distance (4-dimensional)
// Returns similarity in [0,1] where 1 = perfect match
double IdealSimilarity(double e, double d, double v, double c,
                       double eI, double dI, double vI, double cI)
{
   double de = e - eI;
   double dd = d - dI;
   double dv = v - vI;
   double dc = c - cI;
   double dist = MathSqrt(de*de + dd*dd + dv*dv + dc*dc);
   // Normalize: max possible distance for [0,1] inputs is sqrt(4)=2
   return(1.0 - Clamp(dist / 2.0, 0.0, 1.0));
}

//+------------------------------------------------------------------+
