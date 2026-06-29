//+------------------------------------------------------------------+
//|  FALCON OS — KERNEL                                              |
//|  Shared State · Event Bus · Scheduler · Config · Logger          |
//|                                                                  |
//|  The kernel is the single source of truth. Every module reads    |
//|  and writes the ONE global MarketState (g_state). No engine      |
//|  recomputes a value that another engine already produced.        |
//+------------------------------------------------------------------+
#ifndef FALCON_KERNEL_MQH
#define FALCON_KERNEL_MQH

//==================================================================
// 0. CANONICAL ENUMS / CONSTANTS
//==================================================================
// Direction convention used everywhere: +1 bull, -1 bear, 0 neutral.

// Fixed timeframe ladder (the six structural rungs the whole OS reasons on).
#define FAL_TF_COUNT 6
// index 0=M1, 1=M3, 2=M5(L0/exec), 3=M15, 4=H1, 5=H4
const ENUM_TIMEFRAMES FAL_TF[FAL_TF_COUNT] = { PERIOD_M1, PERIOD_M3, PERIOD_M5, PERIOD_M15, PERIOD_H1, PERIOD_H4 };
const string          FAL_TF_LBL[FAL_TF_COUNT] = { "M1", "M3", "M5", "M15", "H1", "H4" };
#define FAL_L0 2   // M5 is the execution / lifecycle-authority rung

// Canonical 14-phase lifecycle (phases are OUTPUTS of the engines, never inputs).
enum FAL_PHASE
  {
   PH_P4ORIGIN     = 0,  // Point 4 Origin
   PH_EXPANSION    = 1,
   PH_EXP_PRECVX   = 2,  // Expansion Pre-Convexity
   PH_EXP_INDUCT   = 3,  // Expansion Induction
   PH_EXP_LIQUID   = 4,  // Expansion Liquidity
   PH_NEW_HIGH     = 5,
   PH_NEW_LOW      = 6,
   PH_TRANSITION   = 7,
   PH_RETRACE      = 8,
   PH_HTF_FLIP     = 9,  // HTF Flip Zone
   PH_INDUCTION    = 10,
   PH_LIQUIDATION  = 11,
   PH_TERMINAL     = 12, // Terminal Curve
   PH_DEMAND_RTN   = 13, // Demand Return
   PH_SUPPLY_RTN   = 14  // Supply Return
  };

// Master decision vocabulary (the only outputs the Decision Engine may emit).
enum FAL_DECISION
  {
   DEC_NO_TRADE = 0,
   DEC_WAIT     = 1,
   DEC_BUY      = 2,
   DEC_SELL     = 3,
   DEC_ATTACK   = 4,
   DEC_DEFEND   = 5,
   DEC_EXIT     = 6,
   DEC_SCALE    = 7
  };

// Configuration profile (changes behaviour, not pipeline order).
enum FAL_PROFILE { PROFILE_LIVE = 0, PROFILE_BACKTEST = 1, PROFILE_RESEARCH = 2 };

string FAL_PhaseStr(int c)
  {
   switch(c)
     {
      case PH_EXPANSION:   return("Expansion");
      case PH_EXP_PRECVX:  return("Expansion Pre-Convexity");
      case PH_EXP_INDUCT:  return("Expansion Induction");
      case PH_EXP_LIQUID:  return("Expansion Liquidity");
      case PH_NEW_HIGH:    return("New High");
      case PH_NEW_LOW:     return("New Low");
      case PH_TRANSITION:  return("Transition");
      case PH_RETRACE:     return("Retracement");
      case PH_HTF_FLIP:    return("HTF Flip Zone");
      case PH_INDUCTION:   return("Induction");
      case PH_LIQUIDATION: return("Liquidation");
      case PH_TERMINAL:    return("Terminal Curve");
      case PH_DEMAND_RTN:  return("Demand Return");
      case PH_SUPPLY_RTN:  return("Supply Return");
     }
   return("Point 4 Origin");
  }

string FAL_DecisionStr(int d)
  {
   switch(d)
     {
      case DEC_WAIT:    return("WAIT");
      case DEC_BUY:     return("BUY");
      case DEC_SELL:    return("SELL");
      case DEC_ATTACK:  return("ATTACK");
      case DEC_DEFEND:  return("DEFEND");
      case DEC_EXIT:    return("EXIT");
      case DEC_SCALE:   return("SCALE");
     }
   return("NO TRADE");
  }

string FAL_DirStr(int d){ return(d==1 ? "Bullish" : d==-1 ? "Bearish" : "Neutral"); }

//==================================================================
// 1. SHARED STATE  (the MASTER object — one instance: g_state)
//==================================================================
// Mirrors the spec's MASTER SHARED STATE, organised by layer. Every
// field is written exactly once per bar by its owning engine.

struct FAL_Physics
  {
   double atr;
   double velocity;
   double acceleration;
   double convexity;
   double convSmooth;
   double efficiency;
   double displacement;
   double momentum;
   double energy;          // expansion energy proxy
   double compression;     // 0..100 (high = tight curves)
   double expansion;       // expansion score
   double volRatio;        // atr / sma(atr)
   bool   bullImpulse;
   bool   bearImpulse;
   bool   bullDecay;
   bool   bearDecay;
   bool   bullConvShift;
   bool   bearConvShift;
   bool   velDecay70;
   bool   velDecay50;
   // physics observation layer
   double obsExpansion;
   double obsDecay;
   double obsCurvature;
   double obsAbsorption;
   double obsLiquidity;
   double physicsConsensus;
  };

// One structural read per fixed timeframe rung (the f_se output).
struct FAL_TFStruct
  {
   int    dir;          // origin-based wave direction
   int    phase;        // FAL_PHASE code
   double swingHigh;
   double swingLow;
   double prevSwingHigh;
   double prevSwingLow;
   int    bos;          // +1/-1/0
   int    choch;        // +1/-1/0
   double p4High;
   double p4Low;
   double invalidation; // wave origin
   double target;
   double flipTop;
   double flipBot;
   double frzScore;
   double waveProgress; // 0..100
   double convMaturity; // 0..100
   double modelFit;     // 0..100
   double compression;  // 0..100
   int    recBreaks;    // recursive phase-2 CHoCH count
   double dominance;    // dominance-transfer %
   datetime barTime;    // last processed bar time on this TF
  };

struct FAL_Structure
  {
   FAL_TFStruct tf[FAL_TF_COUNT];
   int    structBias;        // M5-derived strict-structure bias
   bool   isHH, isHL, isLH, isLL;
   bool   bullBOS, bearBOS, bullCHoCH, bearCHoCH;
   int    fractalStackDir;
   double fractalStackScore; // 0..100
   int    stackBull, stackBear;
  };

struct FAL_Liquidity
  {
   double liqHeat;       // 0..100
   double wDensity;
   bool   liqVacuum;
   bool   sweepBull;
   bool   sweepBear;
   bool   sweepOK;
   string zone;          // "Open space" / "Active" / "Congested"
  };

struct FAL_Wave
  {
   int    direction;     // active spawned wave direction (M5-governed)
   double flipTop;
   double flipBot;
   double point4High;
   double point4Low;
   datetime point4Bar;
   double cycleHigh;
   double cycleLow;
   double inducZoneLow;
   double inducZoneHigh;
   int    entryCycle;
   int    waveDepth;
   int    waveGeneration;
   bool   recursiveComplete;
   bool   recursiveJustFired;
   // wave intelligence beliefs (0..100)
   double beliefExpansion;
   double beliefConvexity;
   double beliefCreation;
   double beliefAbsorption;
   double beliefRetracement;
   double beliefDemandReturn;
   double convexityMaturity;
   double waveProgress;
   double waveModelFit;
   bool   nearFlipzone;
   bool   closeInside;
  };

struct FAL_HTF
  {
   int    biasH1;
   int    biasH4;
   int    align;         // H1+H4 consensus
   int    timeDir;       // time intelligence stack direction
   double timeAlign;
   double timeConflict;
   string h1Timing;
  };

struct FAL_FU
  {
   double winTarget;     // recursive winning FU left-pool magnet
   double winBand;
   int    activeCount;
   double recursiveAlign;
   // per-rung validated FU (tip,dir,score,valid)
   double tip[FAL_TF_COUNT];
   int    dir[FAL_TF_COUNT];
   double score[FAL_TF_COUNT];
   bool   valid[FAL_TF_COUNT];
  };

// Invisible Network node registry (Module 2).
#define FAL_NODE_MAX 250
struct FAL_Network
  {
   double px[FAL_NODE_MAX];
   double mid[FAL_NODE_MAX];
   int    dir[FAL_NODE_MAX];
   double score[FAL_NODE_MAX];
   int    wt[FAL_NODE_MAX];     // tf weight 3..9
   int    state[FAL_NODE_MAX];  // 0 active,1 dormant,2 consumed,3 historical
   datetime bar[FAL_NODE_MAX];
   int    revisits[FAL_NODE_MAX];
   int    count;
   int    bias;                  // network bias
   double pressure;              // (bullAuth-bearAuth)/sum*100
   int    eligible;              // live nodes above authority floor
   double fezHi, fezLo;          // FEZ corridor
   int    attractorIdx;          // dominant forward node
   double attractorScore;
  };

// F72 Curve Object + Curve Tree (Module 2).
struct FAL_Curve
  {
   int    dir;
   double origin;
   double extreme;
   double dispATR;
   double eIn;
   double eDiss;
   double eRes;
   double convex;
   double compress;
   double maturity;
   // curve tree
   int    treeAlive;
   int    treeDepth;
   int    budgetDepth;
   int    ownerDir;
   double ownerEnergy;
   double ownerOrigin;
   double ownerExtreme;
   double life;             // hold-vs-flip judgement 0..100
   string cpState;          // PERSISTING/LEAKING/NEUTRAL
   double cpForce;
   double narrative;        // lineage strength
   string narrState;        // STRENGTHENING/HOLDING/WEAKENING
   double budgetTarget;
  };

// Energy Resolution Framework (Module 3 source: ERF).
struct FAL_ERF
  {
   int    edeState;             // 1..6
   double dissipationProgress;  // 0..100
   double expansionEnergy;
   double dissipatedEnergy;
   double residualEnergy;
   string resolutionState;      // RESOLVED/PARTIALLY RESOLVED/UNRESOLVED
   int    resCode;              // 2/1/0
   double recursiveCompletion;
   double attractorPrice;
   double attractorScore;
   string attractorLabel;
   double tradeReadiness;
   bool   entryGate;
  };

// Campaign + Participants (Module 2/3).
struct FAL_Campaign
  {
   string state;        // EXPANSION / TERMINAL
   int    ownerDir;
   double htfZone;
   string location;     // BUILDING / APPROACHING / INSIDE HTF ZONE / TRANSITIONING
   string compRegime;   // WIDE / MEDIUM / COMPRESSED / FAILURE SWING
   double curveBudget;
   int    expDepth;
   // participant engine
   double f618, f70, f786, flipLvl;
   string partZone;     // 0.618 / 0.70 / 0.786 / FLIP
   string interference; // DOMINANT / active / absorbed
  };

// Intelligence / Decision (Module 3).
struct FAL_Intelligence
  {
   int    waveDir;            // M5 live wave direction
   int    stackDir;
   double stackPct;
   int    netBias;
   int    pdir;               // network pressure direction
   int    phaseCode;          // ie1a current phase (M5 canonical)
   string phase;
   double phaseConfidence;
   double phaseIntegrity;
   double phaseProgress;
   // Senseei meta-intelligence
   int    master;             // -1/0/+1 unified bias
   double alignment;
   double conflict;
   double threat;
   double confidence;
   string timing;
   string intent;
   double oppScore;
   string opportunity;
   string story;
   // probabilistic scores
   double finalProb;          // bayesian directional prob
   double contProb;           // continuation / setup quality
   string grade;              // A+..D
   double buyProb, sellProb, netEdge;
   // decision
   int    decision;           // FAL_DECISION
   double decisionConfidence;
   string decisionReason;
   // target / invalidation
   double entryPrice;
   double stopPrice;
   double targetT1, targetT2, targetT3;
   double rr;
  };

// Execution snapshot (Module 4).
struct FAL_Execution
  {
   bool   riskOk;
   double var2, var3;
   double var2Limit, var3Limit;
   double udsMax;
   bool   anyBomb;
   int    longPositions;
   int    shortPositions;
   double longLots;
   double shortLots;
   double longPnL;
   double shortPnL;
   int    trimsThisBar;
   bool   sessionOpen;
   double equity;
   double riskCash;
   string lastAction;
  };

struct FAL_MarketState
  {
   datetime      barTime;     // chart bar time (new-bar pivot)
   double        spot;
   FAL_Physics      physics;
   FAL_Structure    structure;
   FAL_Liquidity    liquidity;
   FAL_Wave         wave;
   FAL_HTF          htf;
   FAL_FU           fu;
   FAL_Network      network;
   FAL_Curve        curve;
   FAL_ERF          erf;
   FAL_Campaign     campaign;
   FAL_Intelligence intel;
   FAL_Execution    exec;
  };

// THE single source of truth.
FAL_MarketState g_state;

//==================================================================
// 2. EVENT BUS  (publish/subscribe — modules react, never poll)
//==================================================================
// Lightweight named-event bus. Engines publish events; downstream
// engines can query whether an event fired this bar.
#define FAL_EVT_MAX 64
struct FAL_EventBus
  {
   string name[FAL_EVT_MAX];
   int    count;
  };
FAL_EventBus g_bus;

void FAL_BusReset()                 { g_bus.count = 0; }
void FAL_Publish(const string evt)
  {
   if(g_bus.count >= FAL_EVT_MAX) return;
   g_bus.name[g_bus.count] = evt;
   g_bus.count++;
  }
bool FAL_Fired(const string evt)
  {
   for(int i=0;i<g_bus.count;i++)
      if(g_bus.name[i] == evt) return(true);
   return(false);
  }

//==================================================================
// 3. CONFIGURATION SERVICE  (centralised settings + profiles)
//==================================================================
struct FAL_Config
  {
   FAL_PROFILE profile;
   // core engine
   int    pivotLen;
   int    structLen;
   int    atrLen;
   int    effLen;
   double effThresh;
   double dispThresh;
   double convMult;
   double impulseAtrMult;
   double chochBufferATR;
   bool   useStrictStructure;
   int    inducLookback;
   double inducZoneWidth;
   int    liqSweepLookback;
   double liqRadius;
   double liqAgDecay;
   bool   requireLiqSweep;
   int    resetBars;
   int    beliefSmooth;
   // network
   double fuWickFrac;
   int    fuLookback;
   int    nodeAuthMin;
   int    nodeMax;
   int    dormantBars;
   int    historyBars;
   // decision / risk
   int    minConfidence;
   double riskPercent;
   bool   enableRiskEngine;
   bool   blockNewIfBreach;
   double rrMinimum;
   long   magic;
   int    targetGMT;
   // toggles
   bool   showDashboard;
   bool   tradeEnabled;
  };
FAL_Config g_cfg;

//==================================================================
// 4. LOGGER & DIAGNOSTICS  (structured logs, timing, health)
//==================================================================
struct FAL_Diagnostics
  {
   ulong  pipelineMicros;     // last full-pipeline duration
   int    barsProcessed;
   datetime lastBar;
   string lastError;
   string moduleStatus[6];    // health per module
   bool   healthy;
  };
FAL_Diagnostics g_diag;

void FAL_Log(const string module, const string msg)
  {
   if(g_cfg.profile == PROFILE_RESEARCH)
      PrintFormat("[FALCON][%s] %s", module, msg);
  }
void FAL_LogAlways(const string module, const string msg)
  {
   PrintFormat("[FALCON][%s] %s", module, msg);
  }
void FAL_SetModuleStatus(int idx, const string st)
  {
   if(idx>=0 && idx<6) g_diag.moduleStatus[idx] = st;
  }

//==================================================================
// 5. SHARED MATH HELPERS  (computed once, reused everywhere)
//==================================================================
double FAL_Clamp(double v, double lo, double hi){ return(v<lo?lo:(v>hi?hi:v)); }
double FAL_NZ(double v, double alt=0.0){ return((!MathIsValidNumber(v) || v==EMPTY_VALUE) ? alt : v); }
int    FAL_Sign(double v){ return(v>0?1:(v<0?-1:0)); }

// EMA-step smoothing used by belief engines.
double FAL_EmaStep(double prev, double raw, int len)
  {
   double a = 2.0/(len+1.0);
   return(prev + a*(raw - prev));
  }

//==================================================================
// 6. KERNEL LIFECYCLE
//==================================================================
void FAL_KernelInit()
  {
   FAL_BusReset();
   g_diag.barsProcessed = 0;
   g_diag.healthy = true;
   g_diag.lastError = "";
   for(int i=0;i<6;i++) g_diag.moduleStatus[i] = "init";
   ZeroMemory(g_state);
   FAL_LogAlways("KERNEL", "FALCON OS kernel initialised. Shared state ready.");
  }

#endif // FALCON_KERNEL_MQH
