//+------------------------------------------------------------------+
//| Part1_CoreInfrastructure.mqh                                      |
//| MASTER ALGO - Core Infrastructure                                 |
//| Series buffers, inputs, enums, structs, helper functions          |
//| Base: Symphony entry/stop precision                               |
//| Added: Letra multi-TF + F16 intelligence framework               |
//+------------------------------------------------------------------+
#property strict

#include <Trade\Trade.mqh>

//==================================================================
// 0. SERIES BUFFERS - EMULATE MT4 Time[], Open[], High[], Low[], Close[]
//==================================================================
double   gCloseSeries[];
double   gHighSeries[];
double   gLowSeries[];
double   gOpenSeries[];
datetime gTimeSeries[];

#define Close gCloseSeries
#define High  gHighSeries
#define Low   gLowSeries
#define Open  gOpenSeries
#define Time  gTimeSeries

bool RefreshSeries(int barsNeeded = 5000)
{
   int need = barsNeeded;
   if(need < 500) need = 500;

   ArraySetAsSeries(gCloseSeries, true);
   ArraySetAsSeries(gHighSeries, true);
   ArraySetAsSeries(gLowSeries, true);
   ArraySetAsSeries(gOpenSeries, true);
   ArraySetAsSeries(gTimeSeries, true);

   int c1 = CopyClose(_Symbol, _Period, 0, need, gCloseSeries);
   int c2 = CopyHigh(_Symbol, _Period, 0, need, gHighSeries);
   int c3 = CopyLow(_Symbol, _Period, 0, need, gLowSeries);
   int c4 = CopyOpen(_Symbol, _Period, 0, need, gOpenSeries);
   int c5 = CopyTime(_Symbol, _Period, 0, need, gTimeSeries);

   if(c1 <= 0 || c2 <= 0 || c3 <= 0 || c4 <= 0 || c5 <= 0)
   {
      Print("RefreshSeries failed: ", c1, " ", c2, " ", c3, " ", c4, " ", c5);
      return(false);
   }
   return(true);
}

//==================================================================
// 1. ENUMERATIONS
//==================================================================

// Wave lifecycle phases (14 canonical phases from Letra)
enum ENUM_WAVE_PHASE
{
   PHASE_POINT4_ORIGIN = 0,        // Point 4 Origin
   PHASE_EXPANSION = 1,            // Expansion
   PHASE_EXP_PRECONVEXITY = 2,     // Expansion Pre-Convexity
   PHASE_EXP_INDUCTION = 3,        // Expansion Induction
   PHASE_EXP_LIQUIDITY = 4,        // Expansion Liquidity
   PHASE_NEW_HIGH = 5,             // New High
   PHASE_NEW_LOW = 6,              // New Low
   PHASE_ABSORPTION = 7,           // Absorption
   PHASE_RETRACEMENT = 8,          // Retracement
   PHASE_RETR_PRECONVEXITY = 9,    // Retracement Pre-Convexity
   PHASE_RETR_INDUCTION = 10,      // Retracement Induction
   PHASE_RETR_LIQUIDITY = 11,      // Retracement Liquidity
   PHASE_DEMAND_RETURN = 12,       // Demand Return
   PHASE_SUPPLY_RETURN = 13        // Supply Return
};

// Energy Dissipation Engine states
enum ENUM_EDE_STATE
{
   EDE_ACCUMULATING = 1,
   EDE_RELEASE_INITIAL = 2,
   EDE_RELEASE_SECONDARY = 3,
   EDE_PURGE = 4,
   EDE_DELIVERING = 5,
   EDE_RESOLVING = 6
};

// Resolution states
enum ENUM_RESOLUTION
{
   RES_UNRESOLVED = 0,
   RES_PARTIALLY_RESOLVED = 1,
   RES_RESOLVED = 2
};

// Senseei action states (from F16)
enum ENUM_SENSEEI_ACTION
{
   ACTION_WAIT = 0,
   ACTION_PREPARE = 1,
   ACTION_ATTACK = 2,
   ACTION_MANAGE_EXIT = 3
};

// Timeframe layer identifiers
enum ENUM_TF_LAYER
{
   TF_M1 = 0,
   TF_M3 = 1,
   TF_M5 = 2,
   TF_M15 = 3,
   TF_H1 = 4,
   TF_H4 = 5,
   TF_COUNT = 6
};

// Volatility regime
enum ENUM_VOL_REGIME
{
   VOL_LOW = 0,
   VOL_NORMAL = 1,
   VOL_HIGH = 2
};

//==================================================================
// 2. CORE STRUCTS
//==================================================================

// Per-timeframe structure engine output (from Letra's f_se)
struct StructureEngineOutput
{
   int    direction;         // 1 = bullish, -1 = bearish, 0 = neutral
   int    phaseCode;         // raw phase state machine value
   ENUM_WAVE_PHASE phase;   // canonical phase enum
   double swingHigh;         // current swing high
   double swingLow;          // current swing low
   double prevSwingHigh;     // previous swing high
   double prevSwingLow;      // previous swing low
   int    bosSignal;         // 1 = bull BOS, -1 = bear BOS, 0 = none
   int    chochSignal;       // 1 = bull CHoCH, -1 = bear CHoCH, 0 = none
   double point4High;        // order block top
   double point4Low;         // order block bottom
   double invalidation;      // wave origin / invalidation price
   double target;            // wave target price
   double flipTop;           // flip zone top
   double flipBot;           // flip zone bottom
   double waveProgress;      // 0-100 lifecycle progress
   double convexityMaturity; // 0-100 convexity score
   double modelFit;          // 0-100 model fit
   double compression;       // 0-100 compression index
   int    recursiveBreaks;   // count of recursive CHoCH breaks
   double recursiveDominance;// 0-100 dominance transfer %
};

// Physics engine output
struct PhysicsOutput
{
   double atr;
   double velocity;
   double acceleration;
   double convexity;
   double convSmooth;
   double efficiency;
   double displacement;
   bool   bullImpulse;
   bool   bearImpulse;
   bool   bullMomDecay;
   bool   bearMomDecay;
   bool   bullConvShift;
   bool   bearConvShift;
   bool   velDecay70;
   bool   velDecay50;
};

// Observation layer scores
struct ObservationScores
{
   double expansionScore;
   double decayScore;
   double curvatureScore;
   double absorptionScore;
   double liquidityScore;
   double physicsConsensus;
};

// Belief engine output
struct BeliefScores
{
   double expansion;
   double convexity;
   double creation;
   double absorption;
   double retracement;
   double demandReturn;
};

// Energy Resolution Framework output
struct ERFOutput
{
   ENUM_EDE_STATE edeState;
   double expansionEnergy;
   double dissipatedEnergy;
   double dissipationProgress;
   double residualEnergy;
   ENUM_RESOLUTION resolutionState;
   double recursiveCompletion;
   double primaryAttractorPrice;
   double primaryAttractorScore;
   double tradeReadiness;
   bool   entryGateOpen;
};

// F72 Curve Object (from F16)
struct CurveObject
{
   int    direction;      // 1 = bull, -1 = bear
   double origin;         // birth price
   double extreme;        // peak/trough
   double dispATR;        // displacement in ATR units
   double energyIn;       // expansion energy 0-100
   double energyDissipated; // dissipated 0-100
   double energyResidual; // remaining 0-100
   double convexity;      // curvature 0-100
   double compression;    // compression 0-100
   double maturity;       // lifecycle progress 0-100
};

// Senseei intelligence output (from F16)
struct SenseeiOutput
{
   int    masterBias;       // 1 = bull, -1 = bear, 0 = neutral
   double alignment;        // 0-100
   double conflict;         // 0-100
   double confidence;       // 0-100
   double threat;           // 0-100
   double opportunityScore; // 0-100
   ENUM_SENSEEI_ACTION action;
   string intent;
   string timing;
   string opportunity;
};

// Fractal stack alignment
struct FractalStack
{
   int    direction;        // dominant direction
   double score;            // 0-100 alignment %
   double contextScore;     // weighted by TF importance
   int    bullCount;
   int    bearCount;
};

// Time Intelligence (from F16)
struct TimeIntelligence
{
   int    timeDirection;    // 1 = bull, -1 = bear, 0 = neutral
   double timeAlignment;   // 0-100
   double timeConflict;    // 0-100
   bool   h1HighTaken;
   bool   h1LowTaken;
   string h1Timing;
   string cycleStack;
};

// Execution decision output
struct ExecutionDecision
{
   bool   longSignal;
   bool   shortSignal;
   double entryPrice;
   double stopLoss;
   double takeProfit1;
   double takeProfit2;
   double lots;
   double confidence;
   string grade;           // A+, A, B, C, D
   string narrative;
};

//==================================================================
// 3. INPUT PARAMETERS
//==================================================================

//--- Core Engine (from Symphony)
input int    InpPivotLen          = 5;      // Pivot length
input int    InpATRLen            = 14;     // ATR length
input double InpImpulseAtrMult   = 1.5;    // Impulse ATR multiple
input double InpRetrMin          = 0.30;   // Min retracement fraction
input double InpRetrMax          = 0.80;   // Max retracement fraction
input int    InpInducLookbackBars= 80;     // Flipzone lookback bars
input double InpInducZoneATRWidth= 0.25;   // Flipzone half-width (ATR)

//--- ARC v2 (from Symphony)
input int    InpArcHorizonBars   = 80;     // Arc horizon bars
input double InpConvPower        = 1.5;    // Arc convexity power
input double InpArcExtMult       = 1.5;    // Arc extension multiple
input double InpOuterBandAtrMult = 0.75;   // Outer band distance (ATR)
input double InpArcToleranceAtr  = 0.20;   // ARC exhaust tolerance (ATR)

//--- Physics (from Letra)
input int    InpEffLen            = 10;     // Efficiency lookback
input double InpEffThresh        = 0.65;   // Efficiency threshold
input double InpDispThresh       = 1.5;    // Displacement ATR threshold
input double InpConvMult         = 0.01;   // Convexity ATR multiplier
input double InpChochBufferATR   = 0.75;   // CHoCH buffer (ATR)

//--- Trading Layer
input double InpRiskPercent      = 0.5;    // Risk % per trade
input int    InpMagic            = 240220; // EA magic number

//--- Session Timing (from Symphony)
input int    InpTargetGMT        = 0;      // Target GMT offset

//--- Intelligence (from Letra)
input int    InpBeliefSmooth     = 3;      // Belief EMA smoothing
input int    InpResetBars        = 20;     // Min bars before reset

//--- ERF Gate (from Letra V72)
input double InpERFEntryThreshold= 45.0;   // ERF entry gate threshold
input bool   InpERFGateEnabled   = true;   // Enable ERF entry gate

//--- Senseei (from F16)
input int    InpMinConfAttack    = 55;     // Min confidence to ATTACK
input int    InpAuthMin          = 45;     // Min node authority

//--- Execution Controls
input int    InpBaseLockBars     = 10;     // Lock bars after entry
input double InpExecThreshold    = 5.0;    // Net edge threshold

//==================================================================
// 4. GLOBAL STATE VARIABLES
//==================================================================

// New bar detection
datetime g_lastBarTime = 0;

// Per-TF structure engine outputs
StructureEngineOutput g_structure[TF_COUNT];

// Physics (computed on M5 = execution TF)
PhysicsOutput g_physics;

// Observation scores
ObservationScores g_obs;

// Belief scores
BeliefScores g_beliefs;

// ERF output
ERFOutput g_erf;

// F72 Curve object
CurveObject g_curve;

// Senseei intelligence
SenseeiOutput g_senseei;

// Fractal stack
FractalStack g_fractalStack;

// Time intelligence
TimeIntelligence g_timeIntel;

// Wave context (from Symphony + Letra spawn engine)
int    g_direction = 0;          // active wave direction
double g_flipTop = 0.0;
double g_flipBot = 0.0;
double g_point4High = 0.0;
double g_point4Low = 0.0;
int    g_obBirthBar = -1;
double g_cycleHigh = 0.0;
double g_cycleLow = 0.0;
int    g_entryCycle = 0;
int    g_waveDepth = 0;
bool   g_isRecursive = false;
bool   g_recursiveComplete = false;
int    g_waveGeneration = 0;

// Inducement zones
double g_flipzoneInducPrice = 0.0;
double g_flipzoneInducLow = 0.0;
double g_flipzoneInducHigh = 0.0;
double g_inducZoneLow = 0.0;
double g_inducZoneHigh = 0.0;

// Symphony legacy phase engine (kept for P3/P4 entry compatibility)
int    g_mode = 0;               // -1 short, 1 long, 0 none
double g_anchorHigh = 0.0;
double g_anchorLow = 0.0;
int    g_anchorHighShift = -1;
int    g_anchorLowShift = -1;
int    g_phaseShort = 0;
int    g_phaseLong = 0;
int    g_prevPhaseShort = 0;
int    g_prevPhaseLong = 0;
bool   g_shortPreConvSeen = false;
bool   g_longPreConvSeen = false;

// ARC state
double g_arcLong = 0.0;
double g_arcShort = 0.0;
bool   g_longOuterBreachSeen = false;
bool   g_shortOuterBreachSeen = false;

// Pivot memory
double g_lastPivotPrice = 0.0;
int    g_lastPivotShift = -1;
int    g_lastPivotDir = 0;
double g_prevPivotPrice = 0.0;
int    g_prevPivotShift = -1;
int    g_prevPivotDir = 0;

// Trade tracking
datetime g_lastLongTradeTime = 0;
datetime g_lastShortTradeTime = 0;
int    g_lastSignalBar = -1;
int    g_lastLongBar = -1;
int    g_lastShortBar = -1;

// Liquidity heatmap
double g_liqHeat = 0.0;
bool   g_liqSweepOK = false;

// Display phase authority (single source - from Letra Engine 1A)
ENUM_WAVE_PHASE g_currentPhase = PHASE_POINT4_ORIGIN;
string g_currentDisplayPhase = "Point 4 Origin";
double g_phaseConfidence = 0.0;
double g_phaseIntegrity = 0.0;
double g_waveProgress = 30.0;

//==================================================================
// 5. ATR HANDLE (GLOBAL)
//==================================================================
int g_handleATR = INVALID_HANDLE;

//==================================================================
// 6. HELPER FUNCTIONS
//==================================================================

//--- New Bar Detection
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

//--- ATR Getter
double GetATR(int shift)
{
   if(g_handleATR == INVALID_HANDLE)
   {
      g_handleATR = iATR(_Symbol, _Period, InpATRLen);
      if(g_handleATR == INVALID_HANDLE)
      {
         Print("iATR handle failed");
         return(0.0);
      }
   }
   double buffer[];
   ArraySetAsSeries(buffer, true);
   if(CopyBuffer(g_handleATR, 0, shift, 1, buffer) < 1)
      return(0.0);
   return(buffer[0]);
}

//--- Smoothed ATR
double GetATRSmooth(int shift, int len)
{
   double sum = 0.0;
   int c = 0;
   int maxBars = ArraySize(Close);
   for(int i = shift; i < shift + len; i++)
   {
      if(i >= maxBars) break;
      sum += GetATR(i);
      c++;
   }
   if(c <= 0) return(GetATR(shift));
   return(sum / c);
}

//--- Pivot High Detection
bool IsPivotHigh(int c)
{
   int maxBars = ArraySize(High);
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

//--- Pivot Low Detection
bool IsPivotLow(int c)
{
   int maxBars = ArraySize(Low);
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

//--- Time Filter (London + US sessions, no Asia) from Symphony
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
   // 13:15-13:45
   bool w3 = (curMin >= 795 && curMin <= 825);
   // US session 14:30-18:00
   bool w4 = (curMin >= 870 && curMin <= 1080);
   // Key windows
   bool key_0830 = (curMin >= 495 && curMin <= 525);
   bool key_1500 = (curMin >= 885 && curMin <= 915);
   bool key_1700 = (curMin >= 1005 && curMin <= 1035);

   return(w1 || w2 || w3 || w4 || key_0830 || key_1500 || key_1700);
}

//--- Lot Calculator (Symphony's XAUUSD model)
double ComputeLots(double riskCash, double entry, double sl)
{
   double dist = MathAbs(entry - sl);
   if(dist <= 0.0) return(0.0);

   double distancePips = dist * 10.0;
   double pipValuePerLot = 10.0;
   double riskPerLot = distancePips * pipValuePerLot;
   if(riskPerLot <= 0.0) return(0.0);

   double lots = riskCash / riskPerLot;
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lots = MathFloor(lots / lotStep) * lotStep;
   if(lots < minLot) lots = minLot;
   return(NormalizeDouble(lots, 2));
}

//--- Phase to String
string PhaseToString(ENUM_WAVE_PHASE phase)
{
   switch(phase)
   {
      case PHASE_POINT4_ORIGIN:     return("Point 4 Origin");
      case PHASE_EXPANSION:         return("Expansion");
      case PHASE_EXP_PRECONVEXITY:  return("Expansion Pre-Convexity");
      case PHASE_EXP_INDUCTION:     return("Expansion Induction");
      case PHASE_EXP_LIQUIDITY:     return("Expansion Liquidity");
      case PHASE_NEW_HIGH:          return("New High");
      case PHASE_NEW_LOW:           return("New Low");
      case PHASE_ABSORPTION:        return("Absorption");
      case PHASE_RETRACEMENT:       return("Retracement");
      case PHASE_RETR_PRECONVEXITY: return("Retracement Pre-Convexity");
      case PHASE_RETR_INDUCTION:    return("Retracement Induction");
      case PHASE_RETR_LIQUIDITY:    return("Retracement Liquidity");
      case PHASE_DEMAND_RETURN:     return("Demand Return");
      case PHASE_SUPPLY_RETURN:     return("Supply Return");
      default:                      return("Unknown");
   }
}

//--- Clamp utility
double Clamp(double value, double minVal, double maxVal)
{
   if(value < minVal) return(minVal);
   if(value > maxVal) return(maxVal);
   return(value);
}

//--- EMA alpha from period
double EMAAlpha(int period)
{
   return(2.0 / (period + 1));
}

//--- Smoothed EMA update
double SmoothEMA(double prev, double raw, int period)
{
   double alpha = EMAAlpha(period);
   return(prev + alpha * (raw - prev));
}

//--- Direction from origin (Letra's origin-based wave direction)
int WaveDirByOrigin(double origin, double currentClose, int fallbackDir)
{
   if(origin == 0.0) return(fallbackDir);
   if(currentClose > origin) return(1);
   if(currentClose < origin) return(-1);
   return(fallbackDir);
}

//--- Find inducement price (from Letra Section 7)
double FindInducPrice(int anchorRefShift, double anchorTop, double anchorBot, int lookback)
{
   double best = 0.0;
   double bestDist = -1.0;
   int maxBars = ArraySize(High);
   int maxI = MathMin(lookback, anchorRefShift);

   for(int i = 1; i <= maxI; i++)
   {
      if(anchorRefShift - i < 0 || anchorRefShift - i >= maxBars) continue;
      int idx = anchorRefShift - i;
      if(High[idx] < anchorTop && Low[idx] > anchorBot)
      {
         double d = MathAbs(i);
         if(bestDist < 0 || d < bestDist)
         {
            bestDist = d;
            best = (High[idx] + Low[idx]) * 0.5;
         }
      }
   }
   return(best);
}

//--- Ideal similarity score (from Letra Section 12)
double IdealSimilarity(double eObs, double dObs, double vObs, double cObs,
                       double eIdeal, double dIdeal, double vIdeal, double cIdeal)
{
   double diff = MathPow(eObs - eIdeal, 2) +
                 MathPow(dObs - dIdeal, 2) +
                 MathPow(vObs - vIdeal, 2) +
                 MathPow(cObs - cIdeal, 2);
   return(MathMax(0.0, 100.0 * (1.0 - diff / 4.0)));
}

//--- Multi-TF data fetcher (helper for structure engine)
struct MTFBar
{
   double open;
   double high;
   double low;
   double close;
   datetime time;
};

bool GetMTFBar(ENUM_TIMEFRAMES tf, int shift, MTFBar &bar)
{
   double o[], h[], l[], c[];
   datetime t[];
   ArraySetAsSeries(o, true);
   ArraySetAsSeries(h, true);
   ArraySetAsSeries(l, true);
   ArraySetAsSeries(c, true);
   ArraySetAsSeries(t, true);

   if(CopyOpen(_Symbol, tf, shift, 1, o) < 1) return(false);
   if(CopyHigh(_Symbol, tf, shift, 1, h) < 1) return(false);
   if(CopyLow(_Symbol, tf, shift, 1, l) < 1) return(false);
   if(CopyClose(_Symbol, tf, shift, 1, c) < 1) return(false);
   if(CopyTime(_Symbol, tf, shift, 1, t) < 1) return(false);

   bar.open = o[0];
   bar.high = h[0];
   bar.low = l[0];
   bar.close = c[0];
   bar.time = t[0];
   return(true);
}

//--- Get timeframe enum from layer index
ENUM_TIMEFRAMES LayerToTimeframe(ENUM_TF_LAYER layer)
{
   switch(layer)
   {
      case TF_M1:  return(PERIOD_M1);
      case TF_M3:  return(PERIOD_M3);
      case TF_M5:  return(PERIOD_M5);
      case TF_M15: return(PERIOD_M15);
      case TF_H1:  return(PERIOD_H1);
      case TF_H4:  return(PERIOD_H4);
      default:     return(PERIOD_M5);
   }
}

//--- Layer name string
string LayerName(ENUM_TF_LAYER layer)
{
   switch(layer)
   {
      case TF_M1:  return("M1");
      case TF_M3:  return("M3");
      case TF_M5:  return("M5");
      case TF_M15: return("M15");
      case TF_H1:  return("H1");
      case TF_H4:  return("H4");
      default:     return("??");
   }
}

//==================================================================
// 7. ORDER EXECUTION HELPERS (from Symphony - RAW IOC)
//==================================================================

bool SendMarketOrder(int direction, double lots, double sl, const string comment)
{
   if(lots <= 0.0) return(false);

   MqlTradeRequest req;
   MqlTradeResult res;
   ZeroMemory(req);
   ZeroMemory(res);

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   req.action = TRADE_ACTION_DEAL;
   req.symbol = _Symbol;
   req.magic = InpMagic;
   req.volume = lots;
   req.sl = sl;
   req.tp = 0.0;
   req.deviation = 20;
   req.type_filling = ORDER_FILLING_IOC;
   req.type_time = ORDER_TIME_GTC;
   req.comment = comment;

   if(direction > 0)
   {
      req.type = ORDER_TYPE_BUY;
      req.price = ask;
   }
   else
   {
      req.type = ORDER_TYPE_SELL;
      req.price = bid;
   }

   if(!OrderSend(req, res))
   {
      Print("OrderSend failed dir=", direction, " lots=", lots, " retcode=", res.retcode);
      return(false);
   }
   if(res.retcode != TRADE_RETCODE_DONE && res.retcode != TRADE_RETCODE_DONE_PARTIAL)
   {
      Print("OrderSend not DONE, retcode=", res.retcode);
      return(false);
   }
   return(true);
}

bool ClosePositionPartial(ulong ticket, double lotsToClose)
{
   if(lotsToClose <= 0.0) return(false);
   if(!PositionSelectByTicket(ticket)) return(false);

   string sym = PositionGetString(POSITION_SYMBOL);
   long mgc = PositionGetInteger(POSITION_MAGIC);
   long type = PositionGetInteger(POSITION_TYPE);
   double posLots = PositionGetDouble(POSITION_VOLUME);

   if(sym != _Symbol || mgc != InpMagic) return(false);

   lotsToClose = NormalizeDouble(lotsToClose, 2);
   if(lotsToClose > posLots) lotsToClose = posLots;
   if(lotsToClose <= 0) return(false);

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   MqlTradeRequest req;
   MqlTradeResult res;
   ZeroMemory(req);
   ZeroMemory(res);

   req.action = TRADE_ACTION_DEAL;
   req.symbol = _Symbol;
   req.magic = InpMagic;
   req.position = ticket;
   req.volume = lotsToClose;
   req.deviation = 20;
   req.type_filling = ORDER_FILLING_IOC;
   req.type_time = ORDER_TIME_GTC;
   req.comment = "MASTER TRIM";

   if(type == POSITION_TYPE_BUY)
   {
      req.type = ORDER_TYPE_SELL;
      req.price = bid;
   }
   else
   {
      req.type = ORDER_TYPE_BUY;
      req.price = ask;
   }

   if(!OrderSend(req, res))
   {
      Print("ClosePartial failed ticket=", ticket, " retcode=", res.retcode);
      return(false);
   }
   if(res.retcode != TRADE_RETCODE_DONE && res.retcode != TRADE_RETCODE_DONE_PARTIAL)
   {
      Print("ClosePartial not DONE ticket=", ticket, " retcode=", res.retcode);
      return(false);
   }
   return(true);
}

bool ClosePositionFull(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return(false);
   double lots = PositionGetDouble(POSITION_VOLUME);
   return(ClosePositionPartial(ticket, lots));
}

//--- Count our open positions
int CountOurPositions(int dir = 0)
{
   int count = 0;
   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;

      if(dir == 0) { count++; continue; }
      long type = PositionGetInteger(POSITION_TYPE);
      if(dir > 0 && type == POSITION_TYPE_BUY) count++;
      if(dir < 0 && type == POSITION_TYPE_SELL) count++;
   }
   return(count);
}

//==================================================================
// 8. INITIALIZATION HELPER
//==================================================================
void InitGlobalState()
{
   g_lastBarTime = 0;
   g_direction = 0;
   g_flipTop = 0.0;
   g_flipBot = 0.0;
   g_point4High = 0.0;
   g_point4Low = 0.0;
   g_obBirthBar = -1;
   g_cycleHigh = 0.0;
   g_cycleLow = 0.0;
   g_entryCycle = 0;
   g_waveDepth = 0;
   g_isRecursive = false;
   g_recursiveComplete = false;
   g_waveGeneration = 0;

   g_mode = 0;
   g_anchorHigh = 0.0;
   g_anchorLow = 0.0;
   g_anchorHighShift = -1;
   g_anchorLowShift = -1;
   g_phaseShort = 0;
   g_phaseLong = 0;
   g_prevPhaseShort = 0;
   g_prevPhaseLong = 0;
   g_shortPreConvSeen = false;
   g_longPreConvSeen = false;

   g_arcLong = 0.0;
   g_arcShort = 0.0;
   g_longOuterBreachSeen = false;
   g_shortOuterBreachSeen = false;

   g_lastPivotPrice = 0.0;
   g_lastPivotShift = -1;
   g_lastPivotDir = 0;
   g_prevPivotPrice = 0.0;
   g_prevPivotShift = -1;
   g_prevPivotDir = 0;

   g_lastLongTradeTime = 0;
   g_lastShortTradeTime = 0;
   g_lastSignalBar = -1;
   g_lastLongBar = -1;
   g_lastShortBar = -1;

   g_liqHeat = 0.0;
   g_liqSweepOK = false;

   g_currentPhase = PHASE_POINT4_ORIGIN;
   g_currentDisplayPhase = "Point 4 Origin";
   g_phaseConfidence = 0.0;
   g_phaseIntegrity = 0.0;
   g_waveProgress = 30.0;

   // Zero all structure outputs
   for(int i = 0; i < TF_COUNT; i++)
   {
      ZeroMemory(g_structure[i]);
   }
   ZeroMemory(g_physics);
   ZeroMemory(g_obs);
   ZeroMemory(g_beliefs);
   ZeroMemory(g_erf);
   ZeroMemory(g_curve);
   ZeroMemory(g_senseei);
   ZeroMemory(g_fractalStack);
   ZeroMemory(g_timeIntel);
}

//+------------------------------------------------------------------+
