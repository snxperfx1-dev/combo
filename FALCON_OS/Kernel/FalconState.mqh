//+------------------------------------------------------------------+
//|  FALCON OS — Kernel : FalconState.mqh                            |
//|  THE SINGLE SOURCE OF TRUTH                                      |
//|                                                                  |
//|  Every subsystem references exactly one master object. No        |
//|  calculation exists twice. Market Engine WRITES the market       |
//|  fields, Memory Engine WRITES the network/campaign fields,       |
//|  Intelligence Engine WRITES the reasoning fields, Decision       |
//|  Engine WRITES the verdict, Execution Engine WRITES the trade    |
//|  fields. Everything else READS.                                  |
//+------------------------------------------------------------------+
#ifndef FALCON_STATE_MQH
#define FALCON_STATE_MQH

//==================================================================
// ENUMERATIONS — shared vocabulary
//==================================================================
enum FALCON_DIR
{
   DIR_SHORT = -1,
   DIR_NONE  =  0,
   DIR_LONG  =  1
};

// Canonical wave-lifecycle phase (ported from LETRA f_se state machine 0..14)
enum FALCON_PHASE
{
   PH_P4_ORIGIN        = 0,
   PH_EXPANSION        = 1,
   PH_EXP_PRECONVEXITY = 2,
   PH_EXP_INDUCTION    = 3,
   PH_EXP_LIQUIDITY    = 4,
   PH_NEW_HIGH         = 5,
   PH_NEW_LOW          = 6,
   PH_TRANSITION       = 7,
   PH_RETRACEMENT      = 8,
   PH_HTF_FLIP_ZONE    = 9,
   PH_INDUCTION        = 10,
   PH_LIQUIDATION      = 11,
   PH_TERMINAL_CURVE   = 12,
   PH_DEMAND_RETURN    = 13,
   PH_SUPPLY_RETURN    = 14
};

// Resolution state (Energy Resolution Framework)
enum FALCON_RESOLUTION
{
   RES_UNRESOLVED         = 0,
   RES_PARTIALLY_RESOLVED = 1,
   RES_RESOLVED           = 2
};

// The Decision Engine produces EXACTLY one of these actions.
enum FALCON_ACTION
{
   ACT_NO_TRADE = 0,
   ACT_WAIT     = 1,
   ACT_PREPARE  = 2,   // building, not yet armed
   ACT_BUY      = 3,
   ACT_SELL     = 4,
   ACT_ATTACK   = 5,   // armed, take the shot in master direction
   ACT_SCALE    = 6,   // add to a winning campaign
   ACT_DEFEND   = 7,   // protect open exposure
   ACT_EXIT     = 8    // bank / close
};

//==================================================================
// SUB-STATE : PHYSICS
//==================================================================
struct FalconPhysics
{
   double atr;
   double atrFast;        // ATR(15) for vol scaling
   double atrSlow;        // ATR(30) for vol scaling
   double velocity;
   double acceleration;
   double convexity;
   double convexitySmooth;
   double efficiency;
   double displacement;
   double momentum;
   double volatility;     // atrFast/atrSlow
   double energy;         // expansion energy proxy
   double compression;    // 0..100 (tight curves high)
   double expansion;      // 0..100
   bool   bullImpulse;
   bool   bearImpulse;
   bool   bullDecay;
   bool   bearDecay;
   bool   bullConvShift;
   bool   bearConvShift;
};

//==================================================================
// SUB-STATE : STRUCTURE
//==================================================================
struct FalconStructure
{
   int    trend;          // FALCON_DIR
   double swingHigh;
   double swingLow;
   double prevSwingHigh;
   double prevSwingLow;
   bool   hh, hl, lh, ll;
   int    bos;            // FALCON_DIR (break of structure)
   int    choch;          // FALCON_DIR (change of character)
   double breakStrength;  // ATR multiples of break
   int    internalStruct; // FALCON_DIR
   int    externalStruct; // FALCON_DIR
};

//==================================================================
// SUB-STATE : LIQUIDITY
//==================================================================
struct FalconLiquidity
{
   double pools[64];
   int    poolCount;
   bool   sweepBull;
   bool   sweepBear;
   double clusterDensity;
   double sweepProbability;
   double pressure;       // -100..100
   double score;          // 0..100 (heat)
   bool   inducement;
   bool   falseChoch;
   bool   acceptance;
   bool   vacuum;
};

//==================================================================
// SUB-STATE : CONVEXITY (ARC)
//==================================================================
struct FalconConvexity
{
   double arcLong;
   double arcShort;
   double convexityWidth;
   double curvatureRadius;
   double geometryCapacity; // 0..100 remaining capacity
   double maturity;         // 0..100
};

//==================================================================
// SUB-STATE : WAVE
//==================================================================
struct FalconWave
{
   int    phase;          // FALCON_PHASE
   int    prevPhase;
   int    direction;      // FALCON_DIR (origin based)
   double strength;       // model fit 0..100
   double energy;
   int    age;            // bars since spawn
   double completion;     // wave progress 0..100
   double confidence;
   double origin;         // invalidation/origin price
   double extreme;        // running cycle extreme
   double objective;      // target price
   double flipTop;
   double flipBot;
   double point4High;
   double point4Low;
   double cycleHigh;
   double cycleLow;
   int    entryCycle;
   int    waveDepth;
   int    recursionBreaks;
   double dominanceTransfer; // 0..100
   bool   recursiveComplete;
};

//==================================================================
// SUB-STATE : HTF (higher timeframe stack)
//==================================================================
struct FalconHTF
{
   int    dir[7];         // M1 M3 M5 M15 H1 H4 (+chart) direction per rung
   double prog[7];        // wave progress per rung
   int    stackDir;       // fractal stack direction
   double alignment;      // fractal stack score 0..100
   double conflict;       // 100-alignment proxy
   int    dominance;      // owning timeframe index
   bool   fractalAgreement;
   int    ownerTF;        // index of curve-owning timeframe
};

//==================================================================
// SUB-STATE : FU (rejection / flip candle)
//==================================================================
struct FalconFU
{
   bool   active;
   double tip;
   double mid;
   int    dir;            // FALCON_DIR
   double confidence;     // wick score
   int    lifecycle;      // bars since formed
   double strength;
};

//==================================================================
// SUB-STATE : NETWORK (Invisible Network nodes)
//==================================================================
#define FALCON_MAX_NODES 250
struct FalconNetwork
{
   double px[FALCON_MAX_NODES];
   double mid[FALCON_MAX_NODES];
   int    dir[FALCON_MAX_NODES];
   double score[FALCON_MAX_NODES];
   int    weight[FALCON_MAX_NODES];  // timeframe weight 3..9
   int    nstate[FALCON_MAX_NODES];  // 0 active,1 dormant,2 broken,3 historical
   int    birthBar[FALCON_MAX_NODES];
   int    revisits[FALCON_MAX_NODES];
   int    count;
   int    bias;           // FALCON_DIR network bias
   double pressure;       // -100..100 authority pressure
   int    pressureDir;
   int    liveCount;
   double bullAuthority;
   double bearAuthority;
   int    nearestAttractorIdx;
};

//==================================================================
// SUB-STATE : CURVE TREE
//==================================================================
struct FalconCurve
{
   int    ownerDir;       // who owns price
   double ownerOrigin;
   double ownerExtreme;
   double life;           // curve life 0..100
   double energy;
   int    emergentPhase;
   int    rootDir;
   int    childCount;
   double evolution;      // transfer progress
};

//==================================================================
// SUB-STATE : CAMPAIGN
//==================================================================
struct FalconCampaign
{
   int    owner;          // FALCON_DIR dominant side
   double controlScore;   // 0..100
   int    objectiveDir;
   double remainingEnergy;
   int    age;
   string institution;    // descriptive
};

//==================================================================
// SUB-STATE : PARTICIPANTS
//==================================================================
struct FalconParticipants
{
   double buyer;          // 0..100
   double seller;         // 0..100
   double passive;
   double aggressive;
   double interference;
   double participationScore;
   double marketPressure;
};

//==================================================================
// SUB-STATE : INTELLIGENCE (reasoning outputs)
//==================================================================
struct FalconIntelligence
{
   // belief scores (0..100)
   double beliefExpansion;
   double beliefConvexity;
   double beliefCreation;
   double beliefAbsorption;
   double beliefRetracement;
   double beliefReturn;
   // energy resolution framework
   double expansionEnergy;
   double dissipatedEnergy;
   double dissipationProgress;
   double residualEnergy;
   int    resolutionState;   // FALCON_RESOLUTION
   double attractorPrice;
   double attractorScore;
   // recursion / forecast (predictive)
   int    expectedCycles;
   int    completedCycles;
   double recursiveCompletion;
   double failureSwingProb;
   double immediateExecutionProb;
   double expectedLoopsRemaining;
   // meta intelligence
   double alignment;
   double conflict;
   double confidence;
   double threat;
   double opportunity;       // score 0..100
   string opportunityGrade;
   string intent;
   string timing;
   string story;
   // continuous execution probability (phases are OUTPUTS, this drives decisions)
   double executionProbability; // 0..1
};

//==================================================================
// SUB-STATE : EXECUTION
//==================================================================
struct FalconExecution
{
   int    action;         // FALCON_ACTION (from Decision Engine)
   int    master;         // FALCON_DIR master direction
   double entry;
   double stop;
   double target;
   double target2;
   double target3;
   double lots;
   double riskCash;
   double reward;
   // risk engine snapshot
   double var2;
   double var3;
   double var2Limit;
   double var3Limit;
   double udsMax;
   bool   anyBomb;
   bool   riskOk;
   // per-campaign (multi-direction) gross exposure
   double longGrossLots;
   double shortGrossLots;
   double longGrossVaR;
   double shortGrossVaR;
   int    openLongCount;
   int    openShortCount;
   double openPnL;
   bool   sessionOpen;
};

//==================================================================
// MASTER STATE
//==================================================================
struct FalconMarketState
{
   // bar context
   datetime barTime;
   int      barIndex;     // synthetic running index
   double   close;
   double   high;
   double   low;
   double   open;
   double   bid;
   double   ask;
   double   spot;
   double   equity;

   FalconPhysics      physics;
   FalconStructure    structure;
   FalconLiquidity    liquidity;
   FalconConvexity    convexity;
   FalconWave         wave;
   FalconHTF          htf;
   FalconFU           fu;
   FalconNetwork      network;
   FalconCurve        curve;
   FalconCampaign     campaign;
   FalconParticipants participants;
   FalconIntelligence intel;
   FalconExecution    exec;
};

// The one and only shared-state instance for the whole OS.
FalconMarketState g_state;

//==================================================================
// HELPERS — human readable labels (phases are OUTPUTS only)
//==================================================================
string FalconPhaseStr(const int p)
{
   switch(p)
   {
      case PH_EXPANSION:        return("Expansion");
      case PH_EXP_PRECONVEXITY: return("Expansion Pre-Convexity");
      case PH_EXP_INDUCTION:    return("Expansion Induction");
      case PH_EXP_LIQUIDITY:    return("Expansion Liquidity");
      case PH_NEW_HIGH:         return("New High");
      case PH_NEW_LOW:          return("New Low");
      case PH_TRANSITION:       return("Transition");
      case PH_RETRACEMENT:      return("Retracement");
      case PH_HTF_FLIP_ZONE:    return("HTF Flip Zone");
      case PH_INDUCTION:        return("Induction");
      case PH_LIQUIDATION:      return("Liquidation");
      case PH_TERMINAL_CURVE:   return("Terminal Curve");
      case PH_DEMAND_RETURN:    return("Demand Return");
      case PH_SUPPLY_RETURN:    return("Supply Return");
      default:                  return("Point 4 Origin");
   }
}

string FalconActionStr(const int a)
{
   switch(a)
   {
      case ACT_WAIT:    return("WAIT");
      case ACT_PREPARE: return("PREPARE");
      case ACT_BUY:     return("BUY");
      case ACT_SELL:    return("SELL");
      case ACT_ATTACK:  return("ATTACK");
      case ACT_SCALE:   return("SCALE");
      case ACT_DEFEND:  return("DEFEND");
      case ACT_EXIT:    return("EXIT");
      default:          return("NO TRADE");
   }
}

string FalconDirStr(const int d)
{
   return(d==DIR_LONG ? "Bullish" : d==DIR_SHORT ? "Bearish" : "Neutral");
}

string FalconResStr(const int r)
{
   return(r==RES_RESOLVED ? "RESOLVED" : r==RES_PARTIALLY_RESOLVED ? "PARTIAL" : "UNRESOLVED");
}

#endif // FALCON_STATE_MQH
//+------------------------------------------------------------------+
