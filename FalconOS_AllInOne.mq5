//+------------------------------------------------------------------+
//|                                              FalconOS_AllInOne.mq5 |
//|   FALCON OS — Unified Trading Intelligence Platform               |
//|   SINGLE-FILE BUILD (kernel + 6 engines + EA, auto-combined).     |
//+------------------------------------------------------------------+
#property copyright "FALCON OS"
#property version   "1.04"
#property strict

#include <Trade\Trade.mqh>


//  ===== Kernel/FalconConfig.mqh =====
//+------------------------------------------------------------------+
//|  FALCON OS — Kernel : FalconConfig.mqh                           |
//|  Centralized configuration service with profile support.        |
//|  ALL tunable parameters live here exactly once. Every module     |
//|  reads from g_cfg — no module declares its own duplicate input.  |
//+------------------------------------------------------------------+
#ifndef FALCON_CONFIG_MQH
#define FALCON_CONFIG_MQH

//==================================================================
// RUN PROFILE
//==================================================================
enum FALCON_PROFILE
{
   PROFILE_LIVE     = 0,
   PROFILE_BACKTEST = 1,
   PROFILE_RESEARCH = 2
};

//==================================================================
// INPUTS — the single declaration of every tunable in the OS
//==================================================================
input string  __sep_general    = "════════ FALCON OS — GENERAL ════════"; // ──
input FALCON_PROFILE InpProfile = PROFILE_LIVE;   // Run profile
input long    InpMagic          = 770077;         // EA magic number
input int     InpTargetGMT      = 0;              // Session timezone (GMT offset)
input int     InpSeriesBars     = 5000;           // Bars copied per refresh

input string  __sep_physics     = "════════ CORE MARKET ENGINE ════════"; // ──
input int     InpPivotLen       = 5;     // Pivot length
input int     InpStructLen      = 10;    // Structure pivot length
input int     InpATRLen         = 14;    // ATR length
input int     InpEffLen         = 10;    // Efficiency lookback
input double  InpImpulseAtrMult = 1.5;   // Impulse ATR multiple
input double  InpEffThresh      = 0.65;  // Efficiency threshold
input double  InpDispThresh     = 1.5;   // Displacement ATR threshold
input double  InpConvMult       = 0.01;  // Convexity ATR multiplier
input double  InpChochBufferATR = 0.75;  // CHoCH buffer (ATR)
input int     InpInducLookback  = 80;    // Inducement lookback bars
input double  InpInducZoneWidth = 0.25;  // Inducement zone half-width (ATR)
input int     InpLiqSweepLookbk = 10;    // Liquidity sweep lookback
input double  InpLiqRadius      = 0.25;  // Liquidity radius (x ATR)
input double  InpLiqAgeDecay    = 0.95;  // Liquidity age decay
input int     InpBeliefSmooth   = 3;     // Belief EMA smoothing

input string  __sep_convexity   = "════════ CONVEXITY / ARC ════════"; // ──
input int     InpArcHorizonBars = 80;    // ARC horizon (bars)
input double  InpConvPower       = 1.5;  // ARC convexity power
input double  InpArcExtMult      = 1.5;  // ARC extension (impulse multiple)
input double  InpOuterBandAtrMult= 0.75; // Outer band distance (ATR)
input double  InpArcToleranceAtr = 0.20; // ARC exhaust tolerance (ATR)

input string  __sep_memory      = "════════ MEMORY / NETWORK ════════"; // ──
input double  InpWickFrac       = 0.30;  // FU spike min wick/range
input int     InpFuLookback     = 3;     // FU structure lookback
input int     InpAuthMin        = 45;    // Min node authority
input int     InpDormantBars    = 120;   // Bars until dormant
input int     InpHistoryBars    = 600;   // Bars until historical

input string  __sep_decision    = "════════ DECISION (SENSEEI) ════════"; // ──
input int     InpMinConf        = 55;    // Min confidence to ATTACK
input double  InpMaxThreat      = 45.0;  // Max threat to ATTACK
input double  InpMaxConflict    = 60.0;  // Conflict above this => WAIT
input double  InpExecProbArm    = 0.50;  // Execution probability to arm (calibrated 0..1)

input string  __sep_execution   = "════════ EXECUTION / RISK ════════"; // ──
input bool    InpEnableTrading  = true;  // Allow live order sending
input double  InpRiskPercent    = 0.5;   // Risk % per trade
input bool    InpEnableRiskEng  = true;  // Enable DRDWCT risk engine
input bool    InpBlockIfBreach  = true;  // Block new entries if VaR breached
input bool    InpSessionFilter  = false; // Restrict to London/US windows (off for full backtests)
input double  InpRdLimit        = 0.0095;// Micro-bomb RD limit
input double  InpContractValue  = 100.0; // Value per lot per price unit
input bool    InpTrailEnable    = true;  // Enable trailing stop engine
input double  InpTrailStartATR  = 1.0;   // Start trailing after profit (ATR)
input double  InpTrailDistATR   = 1.5;   // Trailing distance (ATR)
input bool    InpDDProtect      = true;  // Enable drawdown protection
input double  InpMaxDrawdownPct = 12.0;  // Block entries above this drawdown %
input double  InpDDFlattenPct   = 20.0;  // Flatten everything above this drawdown %

input string  __sep_viz         = "════════ VISUALIZATION ════════"; // ──
input bool    InpShowDashboard  = true;  // Show unified dashboard
input bool    InpShowHUD        = true;  // Plot Flight HUD levels on chart
input int     InpDashboardTab   = 0;     // 0=Overview 1=Physics 2=Structure 3=Network 4=Curve 5=Campaign 6=Wave 7=HTF 8=Risk 9=Execution 10=Performance 11=Diagnostics
input bool    InpVerboseLog     = false; // Verbose diagnostics logging

//==================================================================
// RESOLVED CONFIG STRUCT (snapshots inputs + profile overrides)
//==================================================================
struct FalconConfig
{
   int    profile;
   long   magic;
   int    targetGMT;
   int    seriesBars;
   // market
   int    pivotLen, structLen, atrLen, effLen;
   double impulseAtrMult, effThresh, dispThresh, convMult, chochBufferATR;
   int    inducLookback;  double inducZoneWidth;
   int    liqSweepLookbk;  double liqRadius, liqAgeDecay;
   int    beliefSmooth;
   // convexity
   int    arcHorizonBars;  double convPower, arcExtMult, outerBandAtrMult, arcToleranceAtr;
   // memory
   double wickFrac;  int fuLookback, authMin, dormantBars, historyBars;
   // decision
   int    minConf;  double maxThreat, maxConflict, execProbArm;
   // execution
   bool   enableTrading, enableRiskEng, blockIfBreach, sessionFilter;
   double riskPercent, rdLimit, contractValue;
   bool   trailEnable, ddProtect;
   double trailStartATR, trailDistATR, maxDrawdownPct, ddFlattenPct;
   // viz
   bool   showDashboard, verboseLog;  int dashboardTab;
   bool   showHUD;
};

FalconConfig g_cfg;

//------------------------------------------------------------------
// Build resolved config from inputs and apply per-profile overrides.
//------------------------------------------------------------------
void FalconConfigInit()
{
   g_cfg.profile          = InpProfile;
   g_cfg.magic            = InpMagic;
   g_cfg.targetGMT        = InpTargetGMT;
   g_cfg.seriesBars       = InpSeriesBars;

   g_cfg.pivotLen         = InpPivotLen;
   g_cfg.structLen        = InpStructLen;
   g_cfg.atrLen           = InpATRLen;
   g_cfg.effLen           = InpEffLen;
   g_cfg.impulseAtrMult   = InpImpulseAtrMult;
   g_cfg.effThresh        = InpEffThresh;
   g_cfg.dispThresh       = InpDispThresh;
   g_cfg.convMult         = InpConvMult;
   g_cfg.chochBufferATR   = InpChochBufferATR;
   g_cfg.inducLookback    = InpInducLookback;
   g_cfg.inducZoneWidth   = InpInducZoneWidth;
   g_cfg.liqSweepLookbk   = InpLiqSweepLookbk;
   g_cfg.liqRadius        = InpLiqRadius;
   g_cfg.liqAgeDecay      = InpLiqAgeDecay;
   g_cfg.beliefSmooth     = InpBeliefSmooth;

   g_cfg.arcHorizonBars   = InpArcHorizonBars;
   g_cfg.convPower        = InpConvPower;
   g_cfg.arcExtMult       = InpArcExtMult;
   g_cfg.outerBandAtrMult = InpOuterBandAtrMult;
   g_cfg.arcToleranceAtr  = InpArcToleranceAtr;

   g_cfg.wickFrac         = InpWickFrac;
   g_cfg.fuLookback       = InpFuLookback;
   g_cfg.authMin          = InpAuthMin;
   g_cfg.dormantBars      = InpDormantBars;
   g_cfg.historyBars      = InpHistoryBars;

   g_cfg.minConf          = InpMinConf;
   g_cfg.maxThreat        = InpMaxThreat;
   g_cfg.maxConflict      = InpMaxConflict;
   g_cfg.execProbArm      = InpExecProbArm;

   g_cfg.enableTrading    = InpEnableTrading;
   g_cfg.enableRiskEng    = InpEnableRiskEng;
   g_cfg.blockIfBreach    = InpBlockIfBreach;
   g_cfg.sessionFilter    = InpSessionFilter;
   g_cfg.riskPercent      = InpRiskPercent;
   g_cfg.rdLimit          = InpRdLimit;
   g_cfg.contractValue    = InpContractValue;
   g_cfg.trailEnable      = InpTrailEnable;
   g_cfg.trailStartATR    = InpTrailStartATR;
   g_cfg.trailDistATR     = InpTrailDistATR;
   g_cfg.ddProtect        = InpDDProtect;
   g_cfg.maxDrawdownPct   = InpMaxDrawdownPct;
   g_cfg.ddFlattenPct     = InpDDFlattenPct;

   g_cfg.showDashboard    = InpShowDashboard;
   g_cfg.showHUD          = InpShowHUD;
   g_cfg.verboseLog       = InpVerboseLog;
   g_cfg.dashboardTab     = InpDashboardTab;

   // Profile overrides
   if(g_cfg.profile == PROFILE_BACKTEST)
   {
      // deterministic, no live order side-effects suppressed by caller
   }
   else if(g_cfg.profile == PROFILE_RESEARCH)
   {
      g_cfg.enableTrading = false;   // research never sends orders
      g_cfg.verboseLog    = true;
   }
}

#endif // FALCON_CONFIG_MQH
//+------------------------------------------------------------------+

//  ===== Kernel/FalconState.mqh =====
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

// Live position posture (Execution.TradeState)
enum FALCON_TRADE_STATE
{
   TS_FLAT        = 0,
   TS_LONG_OPEN   = 1,
   TS_SHORT_OPEN  = 2,
   TS_HEDGED      = 3,   // both directions open (multi-campaign)
   TS_SCALING     = 4,
   TS_DEFENDING   = 5
};

// Reason the last exit fired (Execution.ExitState)
enum FALCON_EXIT_STATE
{
   XS_NONE          = 0,
   XS_ARC_EXHAUST   = 1,
   XS_RESOLUTION    = 2,
   XS_DECISION_EXIT = 3,
   XS_DEFEND        = 4,
   XS_TRAIL_STOP    = 5,
   XS_DD_FLATTEN    = 6
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
   // explicit Inducement Engine (LETRA) outputs
   double inducePrice;    // the lure level inside the working range
   double induceTop;      // inducement zone band
   double induceBot;
   bool   induceActive;
   bool   induceSwept;    // price has taken the inducement level
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
   // discrete sub-state scores (0..100) — spec MarketState.Wave members
   double expansionScore;
   double retracementScore;
   double inductionScore;
   double liquidationScore;
   double preConvexityScore;
   double convexityScore;
   double absorptionScore;
};

//==================================================================
// SUB-STATE : HTF (higher timeframe stack)
//==================================================================
struct FalconHTF
{
   int    dir[7];         // M1 M3 M5 M15 H1 H4 (+chart) direction per rung
   double prog[7];        // wave progress per rung
   int    beliefs[7];     // per-rung HTF belief (FALCON_DIR)
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
   double candle;         // FU Candle reference price (the rejection close)
   double tip;
   double mid;
   double zoneTop;        // FU Zone band
   double zoneBot;
   int    dir;            // FALCON_DIR
   double confidence;     // wick score
   int    lifecycle;      // bars since formed
   double strength;
};

//==================================================================
// SUB-STATE : ORDER BLOCKS (Market Layer — explicit engine)
//==================================================================
#define FALCON_MAX_OB 16
struct FalconOrderBlocks
{
   double top[FALCON_MAX_OB];
   double bot[FALCON_MAX_OB];
   int    dir[FALCON_MAX_OB];     // FALCON_DIR
   int    birthBar[FALCON_MAX_OB];
   bool   valid[FALCON_MAX_OB];
   double strength[FALCON_MAX_OB];
   int    count;
   // nearest active OB to price (the working order block)
   double activeTop;
   double activeBot;
   int    activeDir;
   double activeStrength;
};

//==================================================================
// SUB-STATE : SUPPLY / DEMAND (Market Layer — explicit engine)
//==================================================================
struct FalconSupplyDemand
{
   double supplyTop;
   double supplyBot;
   double demandTop;
   double demandBot;
   double supplyStrength;   // 0..100
   double demandStrength;   // 0..100
   int    activeZone;       // FALCON_DIR: in demand(+1)/supply(-1)/none
   bool   inSupply;
   bool   inDemand;
};

//==================================================================
// SUB-STATE : NETWORK (Invisible Network nodes)
//==================================================================
#define FALCON_MAX_NODES 250
#define FALCON_MAX_EDGES 120
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
   // conversation graph (edges between nearby authoritative nodes)
   int    edgeFrom[FALCON_MAX_EDGES];
   int    edgeTo[FALCON_MAX_EDGES];
   double edgeWeight[FALCON_MAX_EDGES];
   int    edgeCount;
   double conversationWeight;   // aggregate dialogue intensity 0..100
   int    connections;          // total active connections
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
   // explicit curve tree (root → parent → children)
   double rootOrigin;
   double rootExtreme;
   int    parentDir;
   double parentOrigin;
   double parentExtreme;
   int    emergentNodes;  // count of emergent child nodes
   int    ownerTF;        // owning timeframe index
};

//==================================================================
// SUB-STATE : WAVE MATRIX (per-timeframe wave grid)
//==================================================================
struct FalconWaveMatrix
{
   int    dir[7];         // direction per TF rung
   int    phase[7];       // FALCON_PHASE per rung
   double progress[7];    // wave progress per rung
   int    dominantTF;     // rung index with highest authority
   int    dominantDir;
   double agreement;      // 0..100 cross-TF agreement
   double matrixEnergy;   // aggregate energy
};

//==================================================================
// SUB-STATE : FUTURE ENGAGEMENT ZONE (FEZ corridor — where price
// is being pulled to NEXT to engage liquidity / continue)
//==================================================================
struct FalconFEZ
{
   double top;
   double bot;
   int    dir;            // FALCON_DIR engagement direction
   bool   active;
   double confidence;     // 0..100
   double distanceATR;    // distance from price in ATR
};

//==================================================================
// SUB-STATE : FUTURE RETURN ZONE (FRZ — owner-driven destination
// price returns to, inherited from the owner curve hierarchy)
//==================================================================
struct FalconFRZ
{
   double top;
   double bot;
   int    dir;            // return direction
   int    ownerTF;        // owning timeframe that defines the destination
   bool   active;
   double targetPrice;
   double confidence;     // 0..100
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
   // explicit reasoning engines (spec MarketState.Intelligence members)
   string hypothesis;        // current leading hypothesis (human readable)
   int    hypothesisDir;     // FALCON_DIR the hypothesis favours
   double hypothesisProb;    // 0..1 confidence in the hypothesis
   string prediction;        // what the engine expects next
   double predictionPrice;   // predicted destination price
   double predictionProb;    // 0..1
   bool   validated;         // did reality confirm the prior prediction?
   double validationScore;   // 0..100 rolling hit rate
   string finalDecision;     // mirrors the Decision Engine verdict label
   // Master Chief — holistic final confirmation above Senseei
   bool   masterChiefConfirm; // true when all layers agree to commit
   double masterChiefScore;   // 0..100 holistic conviction
   string masterChiefNote;
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
   double reward;         // reward:risk ratio of the working setup
   int    tradeState;     // FALCON_TRADE_STATE
   int    exitState;      // FALCON_EXIT_STATE (reason of last exit)
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
   FalconOrderBlocks  orderBlocks;
   FalconSupplyDemand supplyDemand;
   FalconNetwork      network;
   FalconCurve        curve;
   FalconWaveMatrix   waveMatrix;
   FalconFEZ          fez;
   FalconFRZ          frz;
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

string FalconTradeStateStr(const int t)
{
   switch(t)
   {
      case TS_LONG_OPEN:  return("LONG");
      case TS_SHORT_OPEN: return("SHORT");
      case TS_HEDGED:     return("HEDGED");
      case TS_SCALING:    return("SCALING");
      case TS_DEFENDING:  return("DEFENDING");
      default:            return("FLAT");
   }
}

string FalconExitStateStr(const int x)
{
   switch(x)
   {
      case XS_ARC_EXHAUST:   return("ARC exhaust");
      case XS_RESOLUTION:    return("resolution");
      case XS_DECISION_EXIT: return("decision exit");
      case XS_DEFEND:        return("defend");
      case XS_TRAIL_STOP:    return("trail stop");
      case XS_DD_FLATTEN:    return("drawdown flatten");
      default:               return("none");
   }
}

string FalconResStr(const int r)
{
   return(r==RES_RESOLVED ? "RESOLVED" : r==RES_PARTIALLY_RESOLVED ? "PARTIAL" : "UNRESOLVED");
}

#endif // FALCON_STATE_MQH
//+------------------------------------------------------------------+

//  ===== Kernel/FalconSeries.mqh =====
//+------------------------------------------------------------------+
//|  FALCON OS — Kernel : FalconSeries.mqh                          |
//|  Single source of truth for price series + primitive math.      |
//|                                                                  |
//|  ATR, pivots, OHLC access exist EXACTLY ONCE here. LETRA, F16    |
//|  and Symphony each re-implemented these; FALCON OS does not.     |
//+------------------------------------------------------------------+
#ifndef FALCON_SERIES_MQH
#define FALCON_SERIES_MQH


//==================================================================
// SHARED SERIES BUFFERS (series-indexed: [0] = newest)
//==================================================================
double   gClose[];
double   gHigh[];
double   gLow[];
double   gOpen[];
datetime gTime[];

int      g_atrHandle      = INVALID_HANDLE;
int      g_atrFastHandle  = INVALID_HANDLE;
int      g_atrSlowHandle  = INVALID_HANDLE;
datetime g_lastBarTime    = 0;
int      g_barCounter     = 0;   // synthetic monotonic bar index

//------------------------------------------------------------------
bool FalconRefreshSeries()
{
   int need = g_cfg.seriesBars;
   if(need < 500) need = 500;

   ArraySetAsSeries(gClose,true);
   ArraySetAsSeries(gHigh,true);
   ArraySetAsSeries(gLow,true);
   ArraySetAsSeries(gOpen,true);
   ArraySetAsSeries(gTime,true);

   int c1 = CopyClose(_Symbol,_Period,0,need,gClose);
   int c2 = CopyHigh (_Symbol,_Period,0,need,gHigh);
   int c3 = CopyLow  (_Symbol,_Period,0,need,gLow);
   int c4 = CopyOpen (_Symbol,_Period,0,need,gOpen);
   int c5 = CopyTime (_Symbol,_Period,0,need,gTime);

   if(c1<=0 || c2<=0 || c3<=0 || c4<=0 || c5<=0)
      return(false);
   return(true);
}

int FalconBars() { return((int)ArraySize(gClose)); }

bool FalconIsNewBar()
{
   datetime t = gTime[0];
   if(t != g_lastBarTime)
   {
      g_lastBarTime = t;
      g_barCounter++;
      return(true);
   }
   return(false);
}

//------------------------------------------------------------------
// ATR — single implementation. variant 0=main 1=fast(15) 2=slow(30)
//------------------------------------------------------------------
double FalconATR(const int shift, const int variant=0)
{
   int handle = INVALID_HANDLE;
   if(variant==0)
   {
      if(g_atrHandle==INVALID_HANDLE) g_atrHandle = iATR(_Symbol,_Period,g_cfg.atrLen);
      handle = g_atrHandle;
   }
   else if(variant==1)
   {
      if(g_atrFastHandle==INVALID_HANDLE) g_atrFastHandle = iATR(_Symbol,_Period,15);
      handle = g_atrFastHandle;
   }
   else
   {
      if(g_atrSlowHandle==INVALID_HANDLE) g_atrSlowHandle = iATR(_Symbol,_Period,30);
      handle = g_atrSlowHandle;
   }
   if(handle==INVALID_HANDLE) return(0.0);

   double buf[];
   ArraySetAsSeries(buf,true);
   if(CopyBuffer(handle,0,shift,1,buf) < 1) return(0.0);
   return(buf[0]);
}

//------------------------------------------------------------------
// Pivot detection — single implementation.
//------------------------------------------------------------------
bool FalconIsPivotHigh(const int c, const int len)
{
   int maxBars = FalconBars();
   if(c<=0 || c>=maxBars) return(false);
   double h = gHigh[c];
   for(int k=1;k<=len;k++)
   {
      if(c+k>=maxBars || c-k<0) return(false);
      if(h<=gHigh[c+k]) return(false);
      if(h<=gHigh[c-k]) return(false);
   }
   return(true);
}

bool FalconIsPivotLow(const int c, const int len)
{
   int maxBars = FalconBars();
   if(c<=0 || c>=maxBars) return(false);
   double l = gLow[c];
   for(int k=1;k<=len;k++)
   {
      if(c+k>=maxBars || c-k<0) return(false);
      if(l>=gLow[c+k]) return(false);
      if(l>=gLow[c-k]) return(false);
   }
   return(true);
}

//------------------------------------------------------------------
// Simple math helpers (single source).
//------------------------------------------------------------------
double FalconEMA(const double prev, const double value, const int period)
{
   double alpha = 2.0/(period+1.0);
   return(prev + alpha*(value-prev));
}

double FalconClamp(const double v, const double lo, const double hi)
{
   if(v<lo) return(lo);
   if(v>hi) return(hi);
   return(v);
}

double FalconHighest(const int from, const int len)
{
   int maxBars = FalconBars();
   double m = -DBL_MAX;
   for(int i=from;i<from+len && i<maxBars;i++)
      if(gHigh[i]>m) m=gHigh[i];
   return(m==-DBL_MAX ? 0.0 : m);
}

double FalconLowest(const int from, const int len)
{
   int maxBars = FalconBars();
   double m = DBL_MAX;
   for(int i=from;i<from+len && i<maxBars;i++)
      if(gLow[i]<m) m=gLow[i];
   return(m==DBL_MAX ? 0.0 : m);
}

void FalconReleaseHandles()
{
   if(g_atrHandle!=INVALID_HANDLE)     { IndicatorRelease(g_atrHandle);     g_atrHandle=INVALID_HANDLE; }
   if(g_atrFastHandle!=INVALID_HANDLE) { IndicatorRelease(g_atrFastHandle); g_atrFastHandle=INVALID_HANDLE; }
   if(g_atrSlowHandle!=INVALID_HANDLE) { IndicatorRelease(g_atrSlowHandle); g_atrSlowHandle=INVALID_HANDLE; }
}

#endif // FALCON_SERIES_MQH
//+------------------------------------------------------------------+

//  ===== Kernel/FalconEventBus.mqh =====
//+------------------------------------------------------------------+
//|  FALCON OS — Kernel : FalconEventBus.mqh                         |
//|  Lightweight publish/subscribe event bus.                       |
//|                                                                  |
//|  Modules emit events instead of calling each other directly.    |
//|  The pipeline (Scheduler) runs deterministically, but engines    |
//|  raise semantic events (impulse fired, node born, verdict        |
//|  changed, order sent...) that any module can react to without    |
//|  a hard dependency. New engines plug in by subscribing.          |
//+------------------------------------------------------------------+
#ifndef FALCON_EVENTBUS_MQH
#define FALCON_EVENTBUS_MQH

//==================================================================
// EVENT TYPES
//==================================================================
enum FALCON_EVENT
{
   EVT_NONE = 0,
   EVT_NEW_BAR,
   EVT_IMPULSE_BULL,
   EVT_IMPULSE_BEAR,
   EVT_BOS,
   EVT_CHOCH,
   EVT_WAVE_SPAWN,
   EVT_PHASE_CHANGE,
   EVT_NODE_BORN,
   EVT_NODE_BROKEN,
   EVT_LIQ_SWEEP,
   EVT_RESOLUTION_CHANGE,
   EVT_VERDICT_CHANGE,
   EVT_ORDER_SENT,
   EVT_ORDER_FAILED,
   EVT_EXIT_FIRED,
   EVT_RISK_BREACH,
   EVT_TRIM
};

struct FalconEvent
{
   int      type;
   datetime time;
   double   value;     // generic numeric payload (price, score, dir...)
   string   note;
};

//==================================================================
// RING BUFFER of recent events (diagnostics + late subscribers)
//==================================================================
#define FALCON_EVT_RING 128

struct FalconEventBus
{
   FalconEvent ring[FALCON_EVT_RING];
   int         head;
   int         total;
   // per-type counters for diagnostics
   int         counts[32];
};

FalconEventBus g_bus;

void FalconBusInit()
{
   g_bus.head  = 0;
   g_bus.total = 0;
   for(int i=0;i<32;i++) g_bus.counts[i]=0;
   for(int i=0;i<FALCON_EVT_RING;i++)
   {
      g_bus.ring[i].type = EVT_NONE;
      g_bus.ring[i].note = "";
      g_bus.ring[i].value= 0.0;
      g_bus.ring[i].time = 0;
   }
}

//------------------------------------------------------------------
// Publish an event. Stored in the ring and counted. Subscribers
// poll the bus inside the pipeline (deterministic, no callbacks in
// MQL5), keeping the OS single-threaded and reproducible.
//------------------------------------------------------------------
void FalconPublish(const int type, const double value=0.0, const string note="")
{
   FalconEvent e;
   e.type  = type;
   e.time  = TimeCurrent();
   e.value = value;
   e.note  = note;

   g_bus.ring[g_bus.head] = e;
   g_bus.head = (g_bus.head + 1) % FALCON_EVT_RING;
   g_bus.total++;
   if(type>=0 && type<32) g_bus.counts[type]++;
}

//------------------------------------------------------------------
// Did an event of this type fire since the given total marker?
// Engines snapshot g_bus.total at pipeline start, then query.
//------------------------------------------------------------------
bool FalconEventFiredSince(const int type, const int sinceTotal)
{
   int n = MathMin(g_bus.total - sinceTotal, FALCON_EVT_RING);
   for(int k=1;k<=n;k++)
   {
      int idx = (g_bus.head - k + FALCON_EVT_RING) % FALCON_EVT_RING;
      if(g_bus.ring[idx].type == type) return(true);
   }
   return(false);
}

int FalconEventCount(const int type)
{
   if(type>=0 && type<32) return(g_bus.counts[type]);
   return(0);
}

#endif // FALCON_EVENTBUS_MQH
//+------------------------------------------------------------------+

//  ===== Kernel/FalconLog.mqh =====
//+------------------------------------------------------------------+
//|  FALCON OS — Kernel : FalconLog.mqh                             |
//|  Structured logging, timing metrics, module health checks.      |
//+------------------------------------------------------------------+
#ifndef FALCON_LOG_MQH
#define FALCON_LOG_MQH


//==================================================================
// MODULE REGISTRY — for health checks + timing
//==================================================================
enum FALCON_MODULE
{
   MOD_MARKET = 0,
   MOD_MEMORY,
   MOD_INTEL,
   MOD_DECISION,
   MOD_EXEC,
   MOD_VIZ,
   MOD_COUNT
};

struct FalconModuleHealth
{
   bool   ok;
   ulong  lastMicros;     // last run duration (microseconds)
   ulong  totalMicros;
   int    runs;
   string lastError;
};

struct FalconDiagnostics
{
   FalconModuleHealth health[MOD_COUNT];
   ulong  pipelineMicros;
   int    pipelineRuns;
   datetime bootTime;
};

FalconDiagnostics g_diag;

string FalconModuleName(const int m)
{
   switch(m)
   {
      case MOD_MARKET:   return("MarketEngine");
      case MOD_MEMORY:   return("MemoryEngine");
      case MOD_INTEL:    return("IntelligenceEngine");
      case MOD_DECISION: return("DecisionEngine");
      case MOD_EXEC:     return("ExecutionEngine");
      case MOD_VIZ:      return("VisualizationEngine");
      default:           return("Unknown");
   }
}

void FalconLogInit()
{
   for(int i=0;i<MOD_COUNT;i++)
   {
      g_diag.health[i].ok          = true;
      g_diag.health[i].lastMicros  = 0;
      g_diag.health[i].totalMicros = 0;
      g_diag.health[i].runs        = 0;
      g_diag.health[i].lastError   = "";
   }
   g_diag.pipelineMicros = 0;
   g_diag.pipelineRuns   = 0;
   g_diag.bootTime       = TimeCurrent();
}

//------------------------------------------------------------------
// Record a module run timing + health.
//------------------------------------------------------------------
void FalconModuleStart(const int m, ulong &t0)
{
   t0 = GetMicrosecondCount();
}

void FalconModuleEnd(const int m, const ulong t0, const bool ok=true, const string err="")
{
   if(m<0 || m>=MOD_COUNT) return;
   ulong dt = GetMicrosecondCount() - t0;
   g_diag.health[m].lastMicros   = dt;
   g_diag.health[m].totalMicros += dt;
   g_diag.health[m].runs++;
   g_diag.health[m].ok           = ok;
   if(!ok) g_diag.health[m].lastError = err;
}

//------------------------------------------------------------------
// Structured log line. Honors verbose flag for INFO.
//------------------------------------------------------------------
void FalconLog(const string level, const string module, const string msg)
{
   if(level=="INFO" && !g_cfg.verboseLog) return;
   PrintFormat("[FALCON][%s][%s] %s", level, module, msg);
}

void FalconInfo (const string module, const string msg) { FalconLog("INFO", module, msg); }
void FalconWarn (const string module, const string msg) { FalconLog("WARN", module, msg); }
void FalconError(const string module, const string msg) { FalconLog("ERROR",module, msg); }

double FalconAvgMicros(const int m)
{
   if(m<0 || m>=MOD_COUNT || g_diag.health[m].runs<=0) return(0.0);
   return((double)g_diag.health[m].totalMicros / (double)g_diag.health[m].runs);
}

#endif // FALCON_LOG_MQH
//+------------------------------------------------------------------+

//  ===== Kernel/FalconPersistence.mqh =====
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

//  ===== Engines/MarketEngine.mqh =====
//+------------------------------------------------------------------+
//|  FALCON OS — Market Layer : MarketEngine.mqh                     |
//|  Source: LETRA (Core Market Intelligence)                       |
//|                                                                  |
//|  PURE MARKET MODEL. No dashboards. No execution. It observes     |
//|  reality and writes it into g_state.{physics,structure,          |
//|  liquidity,convexity,wave,fu,htf}. Phases are OUTPUTS computed    |
//|  from the engines — never inputs to any decision.                |
//|                                                                  |
//|  Consolidates (de-duplicates) physics, structure, liquidity,     |
//|  wave, FU, HTF that previously existed 3x across the codebases.  |
//+------------------------------------------------------------------+
#ifndef FALCON_MARKET_ENGINE_MQH
#define FALCON_MARKET_ENGINE_MQH


//==================================================================
// PERSISTENT PHYSICS STATE (per-bar EMA chain, matches f_phys)
//==================================================================
double me_vel=0, me_velPrev=0, me_velPrev2=0;
double me_acc=0, me_accPrev=0;
double me_conv=0, me_csm=0, me_csmPrev=0;
bool   me_physInit=false;

//==================================================================
// PERSISTENT WAVE / STRUCTURE STATE (matches f_se var-state)
//==================================================================
int    me_dir          = 0;     // engine spawn direction
double me_curSH=0, me_curSL=0, me_prSH=0, me_prSL=0;
double me_lastP=0, me_prevP=0;
int    me_lastD=0,  me_prevD=0;
double me_ft=0, me_fb=0, me_p4h=0, me_p4l=0, me_inv=0, me_tgt=0;
double me_cycH=0, me_cycL=0;
int    me_pst=0, me_lastDirSeen=0;
bool   me_bos1=false, me_bos2=false;
double me_protSw=0, me_protSw2=0, me_indOrig=0, me_indExt=0;
bool   me_indBrk=false;
int    me_recBrk=0;  bool me_recArm=true;
int    me_waveSpawnBar=0;

// HTF rung labels (M1 M3 M5 M15 H1 H4 chart) and periods
ENUM_TIMEFRAMES me_htfTF[7];
int             me_htfDirState[7];
double          me_htfOrigin[7];
double          me_htfExtreme[7];

void MarketEngineInit()
{
   me_physInit=false;
   me_vel=0; me_velPrev=0; me_velPrev2=0; me_acc=0; me_accPrev=0;
   me_conv=0; me_csm=0; me_csmPrev=0;
   me_dir=0; me_pst=0; me_lastDirSeen=0;
   me_ft=0; me_fb=0; me_p4h=0; me_p4l=0; me_inv=0; me_tgt=0;
   me_cycH=0; me_cycL=0;
   me_curSH=0; me_curSL=0; me_prSH=0; me_prSL=0;
   me_lastP=0; me_prevP=0; me_lastD=0; me_prevD=0;
   me_bos1=false; me_bos2=false; me_protSw=0; me_protSw2=0;
   me_indOrig=0; me_indExt=0; me_indBrk=false;
   me_recBrk=0; me_recArm=true;

   me_obCount=0;

   me_htfTF[0]=PERIOD_M1;  me_htfTF[1]=PERIOD_M5;  me_htfTF[2]=PERIOD_M15;
   me_htfTF[3]=PERIOD_M30; me_htfTF[4]=PERIOD_H1;  me_htfTF[5]=PERIOD_H4;
   me_htfTF[6]=_Period;
   for(int i=0;i<7;i++){ me_htfDirState[i]=0; me_htfOrigin[i]=0; me_htfExtreme[i]=0; }
}

//==================================================================
// 1. PHYSICS  (verbatim port of f_phys, per confirmed bar)
//==================================================================
void ME_UpdatePhysics()
{
   FalconPhysics p;
   double atr   = FalconATR(1,0);
   p.atr        = atr;
   p.atrFast    = FalconATR(1,1);
   p.atrSlow    = FalconATR(1,2);
   p.volatility = (p.atrSlow>0 ? p.atrFast/p.atrSlow : 1.0);

   // EMA velocity chain on last closed bar delta
   double d = gClose[1]-gClose[2];
   if(!me_physInit)
   {
      me_vel=d; me_velPrev=d; me_velPrev2=d; me_acc=0; me_accPrev=0;
      me_conv=0; me_csm=0; me_csmPrev=0; me_physInit=true;
   }
   else
   {
      me_velPrev2 = me_velPrev;
      me_velPrev  = me_vel;
      me_vel      = FalconEMA(me_vel, d, 3);
      me_accPrev  = me_acc;
      me_acc      = me_vel - me_velPrev;
      double convNow = me_acc - me_accPrev;
      me_conv     = convNow;
      me_csmPrev  = me_csm;
      me_csm      = FalconEMA(me_csm, convNow, 3);
   }

   p.velocity        = me_vel;
   p.acceleration    = me_acc;
   p.convexity       = me_conv;
   p.convexitySmooth = me_csm;

   // efficiency over effLen window ending at last closed bar
   int eff = g_cfg.effLen;
   double mv = MathAbs(gClose[1]-gClose[1+eff]);
   double ps = 0.0;
   for(int i=1;i<=eff;i++) ps += MathAbs(gClose[i]-gClose[i+1]);
   p.efficiency   = (ps>0 ? mv/ps : 0.0);
   p.displacement = (gHigh[1]-gLow[1])/MathMax(atr,1e-10);
   p.momentum     = MathAbs(me_vel);

   double cth = atr*g_cfg.convMult;
   bool open_gt = (gClose[1]>gOpen[1]);
   bool open_lt = (gClose[1]<gOpen[1]);
   p.bullImpulse = (p.efficiency>g_cfg.effThresh && me_vel>me_velPrev && me_acc>0 && open_gt && p.displacement>g_cfg.dispThresh);
   p.bearImpulse = (p.efficiency>g_cfg.effThresh && me_vel<me_velPrev && me_acc<0 && open_lt && p.displacement>g_cfg.dispThresh);
   p.bullDecay   = (MathAbs(me_acc)<MathAbs(me_accPrev)*0.8 && me_vel>0);
   p.bearDecay   = (MathAbs(me_acc)<MathAbs(me_accPrev)*0.8 && me_vel<0);
   p.bullConvShift = (me_csm> cth && me_csmPrev<= cth);
   p.bearConvShift = (me_csm<-cth && me_csmPrev>=-cth);

   // energy / compression / expansion (LETRA scoring distilled)
   double expScore = FalconClamp((p.efficiency>g_cfg.effThresh ? p.efficiency*60.0 : p.efficiency*30.0)
                     + (p.displacement>g_cfg.dispThresh ? (p.displacement/MathMax(g_cfg.dispThresh,1e-10)-1.0)*20.0 : 0.0),0,100);
   p.expansion   = expScore;
   p.energy      = FalconClamp(expScore*0.5 + ((p.bullImpulse||p.bearImpulse)?30.0:0.0) + p.efficiency*20.0,0,100);
   p.compression = FalconClamp((1.0-MathMin(p.displacement/MathMax(g_cfg.dispThresh,1e-10),1.0))*60.0
                     + (1.0-MathMin(p.efficiency/MathMax(g_cfg.effThresh,1e-10),1.0))*40.0,0,100);
   p.volatility  = (p.atrSlow>0 ? p.atrFast/p.atrSlow : 1.0);

   g_state.physics = p;

   if(p.bullImpulse) FalconPublish(EVT_IMPULSE_BULL, gClose[1]);
   if(p.bearImpulse) FalconPublish(EVT_IMPULSE_BEAR, gClose[1]);
}

//==================================================================
// 2. STRUCTURE  (pivots, swings, HH/HL/LH/LL, BOS, CHoCH, trend)
//==================================================================
void ME_UpdateStructure()
{
   FalconStructure s;
   double atr = g_state.physics.atr;
   int pv = g_cfg.structLen;
   int center = pv+1;

   // detect a freshly-confirmed pivot at the center
   double eP=0; int eD=0;
   if(FalconIsPivotHigh(center,pv)) { eP=gHigh[center]; eD=1; }
   else if(FalconIsPivotLow(center,pv)) { eP=gLow[center]; eD=-1; }

   if(eD==1)
   {
      me_prSH = (me_curSH==0 ? gHigh[center] : me_curSH);
      me_curSH = gHigh[center];
   }
   else if(eD==-1)
   {
      me_prSL = (me_curSL==0 ? gLow[center] : me_curSL);
      me_curSL = gLow[center];
   }
   if(eD!=0)
   {
      me_prevP=me_lastP; me_prevD=me_lastD;
      me_lastP=eP;       me_lastD=eD;
   }

   double close1 = gClose[1];
   bool bullBOS = (me_prSH!=0 && close1>me_prSH);
   bool bearBOS = (me_prSL!=0 && close1<me_prSL);
   bool bullCH  = (me_prSH!=0 && close1>me_prSH + atr*g_cfg.chochBufferATR);
   bool bearCH  = (me_prSL!=0 && close1<me_prSL - atr*g_cfg.chochBufferATR);

   s.swingHigh     = me_curSH;
   s.swingLow      = me_curSL;
   s.prevSwingHigh = me_prSH;
   s.prevSwingLow  = me_prSL;
   s.hh = (me_curSH!=0 && me_prSH!=0 && me_curSH>me_prSH);
   s.lh = (me_curSH!=0 && me_prSH!=0 && me_curSH<me_prSH);
   s.hl = (me_curSL!=0 && me_prSL!=0 && me_curSL>me_prSL);
   s.ll = (me_curSL!=0 && me_prSL!=0 && me_curSL<me_prSL);
   s.bos   = bullBOS ? DIR_LONG : bearBOS ? DIR_SHORT : DIR_NONE;
   s.choch = bullCH  ? DIR_LONG : bearCH  ? DIR_SHORT : DIR_NONE;
   s.breakStrength = (atr>0 ? MathAbs(close1-(s.bos==DIR_LONG?me_prSH:me_prSL))/atr : 0.0);

   if(s.hh && s.hl) s.trend = DIR_LONG;
   else if(s.lh && s.ll) s.trend = DIR_SHORT;
   else if(bullBOS) s.trend = DIR_LONG;
   else if(bearBOS) s.trend = DIR_SHORT;
   else s.trend = g_state.structure.trend; // persist

   s.internalStruct = (close1>me_curSL && close1<me_curSH) ? s.trend : DIR_NONE;
   s.externalStruct = s.trend;

   g_state.structure = s;

   if(s.bos!=DIR_NONE)   FalconPublish(EVT_BOS, s.bos);
   if(s.choch!=DIR_NONE) FalconPublish(EVT_CHOCH, s.choch);
}

//==================================================================
// 3. LIQUIDITY  (pools from pivots, sweeps, density, heat, pressure)
//==================================================================
double me_liqLvl[256];
double me_liqWt[256];
int    me_liqAge[256];
int    me_liqCount=0;

void ME_UpdateLiquidity()
{
   FalconLiquidity lq;
   double atr = g_state.physics.atr;
   int pv = g_cfg.pivotLen;

   // push a new liquidity level when a pivot confirms
   bool ph = FalconIsPivotHigh(pv+1,pv);
   bool pl = FalconIsPivotLow(pv+1,pv);
   if(ph || pl)
   {
      double lvl = ph ? gHigh[pv+1] : gLow[pv+1];
      double swRng = (gHigh[pv+1]-gLow[pv+1])/MathMax(atr,1e-10);
      if(me_liqCount<256)
      {
         me_liqLvl[me_liqCount]=lvl;
         me_liqWt[me_liqCount]=MathMax(swRng,0.1);
         me_liqAge[me_liqCount]=g_barCounter;
         me_liqCount++;
      }
      else
      {
         for(int i=1;i<256;i++){ me_liqLvl[i-1]=me_liqLvl[i]; me_liqWt[i-1]=me_liqWt[i]; me_liqAge[i-1]=me_liqAge[i]; }
         me_liqLvl[255]=lvl; me_liqWt[255]=MathMax(swRng,0.1); me_liqAge[255]=g_barCounter;
      }
   }

   double close1=gClose[1];
   double radius = atr*g_cfg.liqRadius;
   double wide   = radius*3.0;
   double dens=0, densAbove=0, densBelow=0;
   for(int i=0;i<me_liqCount;i++)
   {
      int age = g_barCounter - me_liqAge[i];
      double dcy = MathPow(g_cfg.liqAgeDecay, age);
      double dist= MathAbs(close1-me_liqLvl[i]);
      if(dist<radius) dens += me_liqWt[i]*dcy;
      if(dist<wide)
      {
         if(me_liqLvl[i]>close1) densAbove += me_liqWt[i]*dcy*(1.0-dist/wide);
         else                    densBelow += me_liqWt[i]*dcy*(1.0-dist/wide);
      }
   }
   lq.clusterDensity = dens;
   lq.score          = FalconClamp(MathMin((densAbove+densBelow)/2.0,5.0)/5.0*100.0,0,100);
   lq.vacuum         = (dens<0.5);
   lq.pressure       = FalconClamp((densBelow-densAbove)/MathMax(densAbove+densBelow,1e-9)*100.0,-100,100);

   // sweeps relative to wave flip levels
   double swH = FalconHighest(1,g_cfg.liqSweepLookbk);
   double swL = FalconLowest(1,g_cfg.liqSweepLookbk);
   lq.sweepBull = (me_ft!=0 && swH>me_ft);
   lq.sweepBear = (me_fb!=0 && swL<me_fb);
   lq.sweepProbability = FalconClamp(lq.score*0.5 + (lq.vacuum?40.0:0.0),0,100);

   // copy active pools (most recent, capped)
   lq.poolCount=0;
   for(int i=me_liqCount-1;i>=0 && lq.poolCount<64;i--)
      lq.pools[lq.poolCount++]=me_liqLvl[i];

   lq.inducement  = (me_indOrig!=0);
   lq.falseChoch  = (me_recBrk>=2);
   lq.acceptance  = (close1>me_fb && close1<me_ft && me_ft!=0);

   g_state.liquidity = lq;

   if(lq.sweepBull || lq.sweepBear) FalconPublish(EVT_LIQ_SWEEP, lq.sweepBull?1:-1);
}

//==================================================================
// 3B. INDUCEMENT ENGINE  (LETRA f_findInducPrice — the lure level
//     inside the working range that price is induced to take before
//     the real move). Explicit engine writing the inducement zone.
//==================================================================
void ME_UpdateInducement()
{
   FalconLiquidity lq = g_state.liquidity;
   double atr   = g_state.physics.atr;
   double top   = me_ft, bot = me_fb;
   double close1= gClose[1];

   lq.inducePrice=0; lq.induceTop=0; lq.induceBot=0; lq.induceActive=false; lq.induceSwept=false;

   if(top!=0 && bot!=0 && top>bot)
   {
      // nearest interior bar fully inside the flip range -> its midpoint is the lure
      double best=0; int bestDist=-1;
      int lookback=g_cfg.inducLookback;
      int maxBars=FalconBars();
      for(int s=2;s<2+lookback && s<maxBars;s++)
      {
         if(gHigh[s]<top && gLow[s]>bot)
         {
            int dist=s;
            if(bestDist<0 || dist<bestDist){ bestDist=dist; best=(gHigh[s]+gLow[s])*0.5; }
         }
      }
      if(bestDist>=0)
      {
         lq.inducePrice=best;
         lq.induceTop=best+atr*g_cfg.inducZoneWidth;
         lq.induceBot=best-atr*g_cfg.inducZoneWidth;
         lq.induceActive=true;
         // swept when price has traded through the lure in the wave direction
         lq.induceSwept = (me_dir==1 ? gLow[1]<=lq.induceBot : me_dir==-1 ? gHigh[1]>=lq.induceTop : false);
      }
   }
   g_state.liquidity=lq;
}

//==================================================================
// 4. WAVE MACHINE  (verbatim port of f_se spawn + 0..14 phase FSM)
//==================================================================
void ME_UpdateWave()
{
   FalconWave w = g_state.wave;
   double atr = g_state.physics.atr;
   double close1=gClose[1];
   int prevPhase = me_pst;

   bool bullBOS=(g_state.structure.bos==DIR_LONG);
   bool bearBOS=(g_state.structure.bos==DIR_SHORT);
   bool bullCH =(g_state.structure.choch==DIR_LONG);
   bool bearCH =(g_state.structure.choch==DIR_SHORT);

   // impulse-driven reversal detection (pivot legs)
   bool pH = FalconIsPivotHigh(g_cfg.structLen+1,g_cfg.structLen);
   bool pL = FalconIsPivotLow (g_cfg.structLen+1,g_cfg.structLen);
   bool eLong  = (pH && me_prevD==-1 && (me_lastP-me_prevP)>atr*g_cfg.impulseAtrMult);
   bool eShort = (pL && me_prevD== 1 && (me_prevP-me_lastP)>atr*g_cfg.impulseAtrMult);

   bool hasCtx = (me_dir!=0 && me_ft!=0);
   bool flipDn = (me_dir==1  && bearCH);
   bool flipUp = (me_dir==-1 && bullCH);
   bool isRev  = (eLong && me_dir==-1) || (eShort && me_dir==1) || flipUp || flipDn;
   bool spawn  = (eLong || eShort || flipUp || flipDn) && (!hasCtx || isRev);

   if(spawn)
   {
      int nd = eLong?1: eShort?-1: flipUp?1:-1;
      double hi = MathMax(me_lastP,me_prevP);
      double lo = MathMin(me_lastP,me_prevP);
      me_dir = nd;
      me_ft  = hi;  me_fb = lo;
      me_p4h = hi;  me_p4l = lo;
      me_cycH= gHigh[1]; me_cycL=gLow[1];
      me_inv = (nd==1 ? lo : hi);
      double rng = (me_prSH!=0 && me_prSL!=0) ? MathAbs(me_prSH-me_prSL) : atr*5.0;
      me_tgt = (nd==1 ? hi+rng : lo-rng);
      me_waveSpawnBar = g_barCounter;
      FalconPublish(EVT_WAVE_SPAWN, nd);
   }
   if(me_dir==1)  me_cycH = (me_cycH==0?gHigh[1]:MathMax(me_cycH,gHigh[1]));
   if(me_dir==-1) me_cycL = (me_cycL==0?gLow[1]:MathMin(me_cycL,gLow[1]));

   // reset block on direction change
   bool reset = (me_dir!=me_lastDirSeen);
   me_lastDirSeen = me_dir;
   if(reset)
   {
      me_bos1=false; me_bos2=false; me_protSw=0; me_protSw2=0;
      me_indOrig=0; me_indExt=0; me_indBrk=false;
   }
   if(me_dir==1 && pL){ me_protSw2=me_protSw; me_protSw=gLow[g_cfg.structLen+1]; }
   if(me_dir==-1&& pH){ me_protSw2=me_protSw; me_protSw=gHigh[g_cfg.structLen+1]; }

   bool oppBOS = (me_dir==1 && me_protSw!=0 && close1<me_protSw) || (me_dir==-1 && me_protSw!=0 && close1>me_protSw);
   if(!me_bos1 && oppBOS){ me_bos1=true; me_indOrig=(me_dir==1?me_cycH:me_cycL); }
   if(me_bos1 && !me_bos2 && oppBOS && me_protSw2!=0 && (me_dir==1?close1<me_protSw2:close1>me_protSw2)) me_bos2=true;
   if(me_bos1 && me_dir==1)  me_indExt=(me_indExt==0?close1:MathMin(me_indExt,close1));
   if(me_bos1 && me_dir==-1) me_indExt=(me_indExt==0?close1:MathMax(me_indExt,close1));
   if(me_bos2 && me_indOrig!=0)
   {
      if(me_dir==1 && close1>me_indOrig)  me_indBrk=true;
      if(me_dir==-1&& close1<me_indOrig)  me_indBrk=true;
   }

   // physics-derived gating
   FalconPhysics ph2 = g_state.physics;
   double convScore = MathMin(MathAbs(me_csm)/MathMax(atr*g_cfg.convMult,1e-10)*50.0,100.0);
   double expScore  = MathMin(ph2.efficiency/MathMax(g_cfg.effThresh,1e-10)*50.0 + ph2.displacement/MathMax(g_cfg.dispThresh,1e-10)*50.0,100.0);
   double absScore  = (ph2.efficiency<g_cfg.effThresh*0.7 && MathAbs(me_vel)<MathAbs(me_velPrev)*0.6) ? 60.0+convScore*0.4 : convScore*0.3;
   bool momExpStrong= ph2.efficiency>g_cfg.effThresh*0.75 && (me_dir==1?me_vel>0:me_vel<0);
   bool momDecaying = (me_dir==1?ph2.bullDecay:ph2.bearDecay);
   bool momCounter  = (me_dir==1?ph2.bearImpulse:ph2.bullImpulse);
   bool momExhaust  = ph2.efficiency<g_cfg.effThresh*0.65 && absScore>40.0;
   bool physConvDev = convScore>35.0;
   bool physTransfer= convScore>48.0 || absScore>40.0;
   bool physCapLow  = absScore>45.0 || ph2.efficiency<g_cfg.effThresh*0.6;

   int wdir = (me_inv!=0 ? (close1>me_inv?1:close1<me_inv?-1:me_dir) : me_dir);
   bool atFlip   = (me_ft!=0 && me_fb!=0 && close1<=me_ft && close1>=me_fb);
   bool expanding= momExpStrong || eLong || eShort || (wdir==1?ph2.bullImpulse:ph2.bearImpulse);
   bool atExtreme= (wdir==1 ? gHigh[1]>=(me_cycH==0?gHigh[1]:me_cycH) : wdir==-1 ? gLow[1]<=(me_cycL==0?gLow[1]:me_cycL) : false);
   double extr   = (wdir==1?(me_cycH==0?close1:me_cycH):(me_cycL==0?close1:me_cycL));
   bool extended = (me_inv!=0 && MathAbs(extr-me_inv)>atr*1.5);
   double fzMid  = (me_ft!=0 && me_fb!=0)?(me_ft+me_fb)/2.0:0.0;
   double retrFrac=(fzMid!=0 && MathAbs(extr-fzMid)>1e-10)?MathAbs(extr-close1)/MathAbs(extr-fzMid):0.0;

   double compIdx = ph2.compression;

   // recursive transition counting
   bool phase2CH = (me_dir==1 && bearCH)||(me_dir==-1 && bullCH);
   if(reset || (atExtreme && extended)){ me_recBrk=0; me_recArm=true; }
   if((me_dir==1 && pH)||(me_dir==-1 && pL)) me_recArm=true;
   if((phase2CH||oppBOS) && me_recArm && !atExtreme){ me_recBrk++; me_recArm=false; }
   double recDom = MathMin(MathMax(me_recBrk*(30.0-compIdx*0.15), retrFrac*80.0),100.0);
   bool transferDone = recDom>=50.0;

   // single-latch phase FSM
   if(reset) me_pst=0;
   if(me_dir!=0 && !reset)
   {
      if(me_pst==0 && expanding) me_pst=1;
      if(me_pst==1 && !atExtreme && momDecaying && physConvDev) me_pst=2;
      if(me_pst==2 && !atExtreme && momCounter && physTransfer) me_pst=3;
      if(me_pst==3 && !atExtreme && (me_bos1||me_bos2||me_indBrk) && physTransfer) me_pst=4;
      if(me_pst>=1 && me_pst<=7 && atExtreme && extended) me_pst=5;
      if(me_pst==5 && !atExtreme && (me_recBrk>=1 || momExhaust)) me_pst=7;
      if(me_pst==7 && transferDone) me_pst=8;
      if(me_pst==8 && atFlip) me_pst=9;
      if(me_pst==9 && ((me_dir==1 && ph2.bullImpulse)||(me_dir==-1 && ph2.bearImpulse))) me_pst=10;
      if(me_pst==10 && (oppBOS || physCapLow)) me_pst=11;
      if(me_pst==11 && ((me_dir==1 && gLow[1]<me_fb)||(me_dir==-1 && gHigh[1]>me_ft))) me_pst=12;
      if(me_pst==12 && ((me_dir==1 && bullCH)||(me_dir==-1 && bearCH))) me_pst=13;
   }
   int phase = me_pst;
   if(phase==5 && me_dir==-1) phase=6;
   if(phase==13 && me_dir==-1) phase=14;

   // wave progress mapping
   double wp = (me_pst==0?5.0:me_pst==1?15.0:me_pst==2?25.0:me_pst==3?33.0:me_pst==4?42.0:
                me_pst==5?55.0:me_pst==7?65.0:me_pst==8?75.0:me_pst==9?85.0:me_pst==10?90.0:
                me_pst==11?94.0:me_pst==12?97.0:100.0);
   double mf = MathMin(MathMax(expScore,MathMax(absScore,convScore))*0.70 + (me_dir!=0?30.0:0.0),100.0);

   w.phase            = phase;
   w.prevPhase        = prevPhase;
   w.direction        = wdir;
   w.strength         = mf;
   w.energy           = ph2.energy;
   w.age              = g_barCounter - me_waveSpawnBar;
   w.completion       = wp;
   w.confidence       = mf;
   w.origin           = me_inv;
   w.extreme          = extr;
   w.objective        = me_tgt;
   w.flipTop          = me_ft;
   w.flipBot          = me_fb;
   w.point4High       = me_p4h;
   w.point4Low        = me_p4l;
   w.cycleHigh        = me_cycH;
   w.cycleLow         = me_cycL;
   w.recursionBreaks  = me_recBrk;
   w.dominanceTransfer= recDom;
   w.recursiveComplete= (phase==PH_DEMAND_RETURN || phase==PH_SUPPLY_RETURN);

   // discrete sub-state scores (spec MarketState.Wave members) — derived from
   // the physics/geometry, peaking in their respective lifecycle windows.
   w.expansionScore    = FalconClamp(expScore,0,100);
   w.preConvexityScore = FalconClamp((ph2.bullDecay||ph2.bearDecay?50.0:0.0)+convScore*0.5,0,100);
   w.convexityScore    = FalconClamp(convScore,0,100);
   w.inductionScore    = FalconClamp((momCounter?45.0:0.0)+convScore*0.35,0,100);
   w.liquidationScore  = FalconClamp((physCapLow?40.0:0.0)+(oppBOS?30.0:0.0)+absScore*0.3,0,100);
   w.absorptionScore   = FalconClamp(absScore,0,100);
   w.retracementScore  = FalconClamp(retrFrac*100.0,0,100);

   g_state.wave = w;

   if(phase != prevPhase) FalconPublish(EVT_PHASE_CHANGE, phase, FalconPhaseStr(phase));
}

//==================================================================
// 5. CONVEXITY / ARC  (Symphony ARC v2 + geometry capacity)
//==================================================================
void ME_UpdateConvexity()
{
   FalconConvexity c;
   double atr = g_state.physics.atr;
   c.arcLong=0; c.arcShort=0;

   if(me_dir==1 && me_inv!=0)
   {
      double impL = (me_p4h-me_p4l);
      if(impL>0)
      {
         double targetL = me_p4l + impL*g_cfg.arcExtMult;
         double t = FalconClamp((double)(g_barCounter-me_waveSpawnBar)/(double)g_cfg.arcHorizonBars,0,1);
         c.arcLong = me_p4l + (targetL-me_p4l)*MathPow(t,g_cfg.convPower);
      }
   }
   if(me_dir==-1 && me_inv!=0)
   {
      double impS = (me_p4h-me_p4l);
      if(impS>0)
      {
         double targetS = me_p4h - impS*g_cfg.arcExtMult;
         double t = FalconClamp((double)(g_barCounter-me_waveSpawnBar)/(double)g_cfg.arcHorizonBars,0,1);
         c.arcShort = me_p4h + (targetS-me_p4h)*MathPow(t,g_cfg.convPower);
      }
   }

   c.convexityWidth  = (me_ft!=0 && me_fb!=0)? (me_ft-me_fb):0.0;
   c.curvatureRadius = (MathAbs(me_csm)>1e-10)? 1.0/MathAbs(me_csm):0.0;
   double distToTarget = (me_tgt!=0)? MathAbs(me_tgt-gClose[1])/MathMax(atr,1e-10):0.0;
   c.geometryCapacity= FalconClamp(distToTarget/4.0*100.0,0,100);
   c.maturity        = FalconClamp(g_state.physics.compression*0.4 + g_state.wave.completion*0.6,0,100);

   g_state.convexity = c;
}

//==================================================================
// 6. FU CANDLE  (rejection / flip detector — port of f_fuPool)
//==================================================================
void ME_UpdateFU()
{
   FalconFU fu = g_state.fu;
   double atr = g_state.physics.atr;
   int lb = g_cfg.fuLookback;

   double rng = MathMax(gHigh[1]-gLow[1],1e-10);
   double pHi = FalconHighest(2,lb);
   double pLo = FalconLowest(2,lb);
   double uw  = (gHigh[1]-MathMax(gOpen[1],gClose[1]))/rng;
   double lw  = (MathMin(gOpen[1],gClose[1])-gLow[1])/rng;
   bool localTop = gHigh[1]>=FalconHighest(1,lb);
   bool localBot = gLow[1] <=FalconLowest(1,lb);
   bool bear = uw>=g_cfg.wickFrac && ((pHi!=0 && gHigh[1]>=pHi && gClose[1]<pHi)||(localTop && gClose[1]<gOpen[1]));
   bool bull = lw>=g_cfg.wickFrac && ((pLo!=0 && gLow[1] <=pLo && gClose[1]>pLo)||(localBot && gClose[1]>gOpen[1]));

   if(bear)
   {
      fu.dir=-1; fu.tip=gHigh[1];
      double bH=MathMax(gOpen[1],gClose[1]);
      fu.mid=bH+(fu.tip-bH)*0.5; fu.active=true; fu.lifecycle=0;
      fu.candle=gClose[1];
      fu.zoneTop=fu.tip; fu.zoneBot=bH;          // rejection band: body-top -> wick-tip
   }
   else if(bull)
   {
      fu.dir=1; fu.tip=gLow[1];
      double bL=MathMin(gOpen[1],gClose[1]);
      fu.mid=fu.tip+(bL-fu.tip)*0.5; fu.active=true; fu.lifecycle=0;
      fu.candle=gClose[1];
      fu.zoneTop=bL; fu.zoneBot=fu.tip;          // rejection band: wick-tip -> body-bottom
   }
   else if(fu.active) fu.lifecycle++;

   double wk = (fu.dir==-1 && fu.active)?(fu.tip-MathMax(gOpen[1],gClose[1]))/MathMax(atr,1e-10):
               (fu.dir== 1 && fu.active)?(MathMin(gOpen[1],gClose[1])-fu.tip)/MathMax(atr,1e-10):0.0;
   fu.confidence = FalconClamp(20.0+MathMin(25.0,wk*15.0)+(wk>1.0?15.0:0.0)+(wk>1.5?10.0:0.0),0,100);
   fu.strength   = FalconClamp(wk*40.0,0,100);

   g_state.fu = fu;
}

//==================================================================
// 7B. ORDER BLOCKS  (last opposing candle before an impulse leg)
//==================================================================
double me_obTop[FALCON_MAX_OB];
double me_obBot[FALCON_MAX_OB];
int    me_obDir[FALCON_MAX_OB];
int    me_obBirth[FALCON_MAX_OB];
double me_obStr[FALCON_MAX_OB];
int    me_obCount=0;

void ME_PushOB(const double top,const double bot,const int dir,const double strength)
{
   if(me_obCount>=FALCON_MAX_OB)
   {
      for(int i=1;i<FALCON_MAX_OB;i++)
      { me_obTop[i-1]=me_obTop[i]; me_obBot[i-1]=me_obBot[i]; me_obDir[i-1]=me_obDir[i];
        me_obBirth[i-1]=me_obBirth[i]; me_obStr[i-1]=me_obStr[i]; }
      me_obCount=FALCON_MAX_OB-1;
   }
   me_obTop[me_obCount]=top; me_obBot[me_obCount]=bot; me_obDir[me_obCount]=dir;
   me_obBirth[me_obCount]=g_barCounter; me_obStr[me_obCount]=strength; me_obCount++;
}

void ME_UpdateOrderBlocks()
{
   FalconOrderBlocks ob;
   double atr=g_state.physics.atr;
   FalconPhysics p=g_state.physics;

   // a new OB forms on the candle that flips into an impulse: the last
   // opposing-color candle body before the displacement leg.
   if(p.bullImpulse)
   {
      // last down candle before this up impulse
      for(int i=2;i<=8;i++){ if(gClose[i]<gOpen[i]){ ME_PushOB(gHigh[i],gLow[i],DIR_LONG, p.displacement*20.0); break; } }
   }
   if(p.bearImpulse)
   {
      for(int i=2;i<=8;i++){ if(gClose[i]>gOpen[i]){ ME_PushOB(gHigh[i],gLow[i],DIR_SHORT,p.displacement*20.0); break; } }
   }

   double close1=gClose[1];
   ob.count=0;
   double bestDist=DBL_MAX;
   ob.activeTop=0; ob.activeBot=0; ob.activeDir=DIR_NONE; ob.activeStrength=0;
   for(int i=0;i<me_obCount && ob.count<FALCON_MAX_OB;i++)
   {
      // invalidation: price closing fully through the block kills it
      bool valid=(me_obDir[i]==DIR_LONG ? close1>me_obBot[i] : close1<me_obTop[i]);
      ob.top[ob.count]=me_obTop[i]; ob.bot[ob.count]=me_obBot[i]; ob.dir[ob.count]=me_obDir[i];
      ob.birthBar[ob.count]=me_obBirth[i]; ob.valid[ob.count]=valid;
      ob.strength[ob.count]=FalconClamp(me_obStr[i] - (g_barCounter-me_obBirth[i])*0.2,0,100);
      if(valid)
      {
         double mid=(me_obTop[i]+me_obBot[i])*0.5;
         double d=MathAbs(close1-mid);
         if(d<bestDist){ bestDist=d; ob.activeTop=me_obTop[i]; ob.activeBot=me_obBot[i];
                         ob.activeDir=me_obDir[i]; ob.activeStrength=ob.strength[ob.count]; }
      }
      ob.count++;
   }
   g_state.orderBlocks=ob;
}

//==================================================================
// 7C. SUPPLY / DEMAND  (institutional zones from wave flip + OB)
//==================================================================
void ME_UpdateSupplyDemand()
{
   FalconSupplyDemand sd;
   double atr=g_state.physics.atr;
   double close1=gClose[1];
   FalconWave w=g_state.wave;
   FalconOrderBlocks ob=g_state.orderBlocks;

   // demand = working bullish OB or wave flip-bottom band; supply = bearish OB / flip-top band
   double demandMid = (ob.activeDir==DIR_LONG && ob.activeTop!=0) ? (ob.activeTop+ob.activeBot)*0.5
                      : (w.flipBot!=0 ? w.flipBot : 0.0);
   double supplyMid = (ob.activeDir==DIR_SHORT && ob.activeTop!=0)? (ob.activeTop+ob.activeBot)*0.5
                      : (w.flipTop!=0 ? w.flipTop : 0.0);

   sd.demandTop = (demandMid!=0? demandMid+atr*g_cfg.inducZoneWidth:0.0);
   sd.demandBot = (demandMid!=0? demandMid-atr*g_cfg.inducZoneWidth:0.0);
   sd.supplyTop = (supplyMid!=0? supplyMid+atr*g_cfg.inducZoneWidth:0.0);
   sd.supplyBot = (supplyMid!=0? supplyMid-atr*g_cfg.inducZoneWidth:0.0);

   sd.demandStrength = FalconClamp((ob.activeDir==DIR_LONG?ob.activeStrength:0.0)
                       + (g_state.liquidity.pressure>0?g_state.liquidity.pressure*0.5:0.0),0,100);
   sd.supplyStrength = FalconClamp((ob.activeDir==DIR_SHORT?ob.activeStrength:0.0)
                       + (g_state.liquidity.pressure<0?-g_state.liquidity.pressure*0.5:0.0),0,100);

   sd.inDemand = (demandMid!=0 && close1<=sd.demandTop && close1>=sd.demandBot);
   sd.inSupply = (supplyMid!=0 && close1<=sd.supplyTop && close1>=sd.supplyBot);
   sd.activeZone = sd.inDemand?DIR_LONG : sd.inSupply?DIR_SHORT : DIR_NONE;

   g_state.supplyDemand=sd;
}

//==================================================================
// 7. HTF STACK  (fixed M1·M5·M15·M30·H1·H4 + chart; fractal align)
//==================================================================
int ME_TfDir(const ENUM_TIMEFRAMES tf, const int idx)
{
   int pv = g_cfg.pivotLen;
   double h[],l[],c[];
   ArraySetAsSeries(h,true); ArraySetAsSeries(l,true); ArraySetAsSeries(c,true);
   int need = pv*2+50;
   if(CopyHigh(_Symbol,tf,0,need,h)<need) return(me_htfDirState[idx]);
   if(CopyLow (_Symbol,tf,0,need,l)<need) return(me_htfDirState[idx]);
   if(CopyClose(_Symbol,tf,0,need,c)<need) return(me_htfDirState[idx]);

   // most recent confirmed pivot
   double sh=0,sl=0;
   for(int i=pv+1;i<need-pv;i++)
   {
      bool isH=true,isL=true;
      for(int k=1;k<=pv;k++)
      {
         if(h[i]<=h[i+k]||h[i]<=h[i-k]) isH=false;
         if(l[i]>=l[i+k]||l[i]>=l[i-k]) isL=false;
      }
      if(isH && sh==0) sh=h[i];
      if(isL && sl==0) sl=l[i];
      if(sh!=0 && sl!=0) break;
   }
   int dir = me_htfDirState[idx];
   double origin = me_htfOrigin[idx];
   if(sh!=0 && c[1]>sh && dir!=1){ dir=1; origin=(sl!=0?sl:l[1]); }
   if(sl!=0 && c[1]<sl && dir!=-1){ dir=-1; origin=(sh!=0?sh:h[1]); }
   me_htfDirState[idx]=dir; me_htfOrigin[idx]=origin;
   return(origin!=0 ? (c[1]>origin?1:c[1]<origin?-1:dir) : dir);
}

void ME_UpdateHTF()
{
   FalconHTF h;
   int bull=0, bear=0;
   for(int i=0;i<7;i++)
   {
      int d = ME_TfDir(me_htfTF[i], i);
      h.dir[i]=d;
      h.beliefs[i]=d;     // per-rung HTF belief mirrors the rung's directional read
      h.prog[i]=0.0;
      if(d==1) bull++; else if(d==-1) bear++;
   }
   h.stackDir  = (bull>bear?DIR_LONG:bear>bull?DIR_SHORT:DIR_NONE);
   h.alignment = MathMax(bull,bear)/7.0*100.0;
   h.conflict  = 100.0 - h.alignment;
   h.fractalAgreement = (h.alignment>=66.0);
   // dominance: highest timeframe agreeing with stack
   h.dominance = 4; h.ownerTF=4;
   for(int i=6;i>=0;i--){ if(h.dir[i]==h.stackDir && h.stackDir!=0){ h.dominance=i; h.ownerTF=i; break; } }

   g_state.htf = h;
}

//==================================================================
// MASTER ENTRY — Market Engine pipeline step
//==================================================================
void MarketEngineRun()
{
   if(FalconBars() < (2*g_cfg.structLen + 10)) return;
   ME_UpdatePhysics();
   ME_UpdateStructure();
   ME_UpdateLiquidity();
   ME_UpdateWave();
   ME_UpdateInducement();
   ME_UpdateConvexity();
   ME_UpdateFU();
   ME_UpdateOrderBlocks();
   ME_UpdateSupplyDemand();
   ME_UpdateHTF();
}

#endif // FALCON_MARKET_ENGINE_MQH
//+------------------------------------------------------------------+

//  ===== Engines/MemoryEngine.mqh =====
//+------------------------------------------------------------------+
//|  FALCON OS — Intelligence Layer : MemoryEngine.mqh              |
//|  Source: F16 Raptor (Invisible Network)                         |
//|                                                                  |
//|  The OS REMEMBERS. It maintains the node registry across         |
//|  timeframes, scores authority, ages nodes into dormancy/history, |
//|  tracks revisits (conversation weight), measures campaign         |
//|  ownership + participant pressure, and resolves curve-tree        |
//|  ownership. Writes g_state.{network,curve,campaign,participants}. |
//+------------------------------------------------------------------+
#ifndef FALCON_MEMORY_ENGINE_MQH
#define FALCON_MEMORY_ENGINE_MQH


//==================================================================
// PERSISTENT NODE REGISTRY (mirrors F16 nPx/nMid/nDir/... arrays)
//==================================================================
double mem_px[FALCON_MAX_NODES];
double mem_mid[FALCON_MAX_NODES];
int    mem_dir[FALCON_MAX_NODES];
double mem_score[FALCON_MAX_NODES];
int    mem_weight[FALCON_MAX_NODES];
int    mem_state[FALCON_MAX_NODES];   // 0 active,1 dormant,2 broken,3 historical
int    mem_birth[FALCON_MAX_NODES];
int    mem_rev[FALCON_MAX_NODES];
int    mem_count=0;

// last seen FU tip per timeframe rung (dedup)
double mem_lastTip[7];

void MemoryEngineInit()
{
   mem_count=0;
   for(int i=0;i<7;i++) mem_lastTip[i]=0.0;
}

//------------------------------------------------------------------
// Node authority = base score + timeframe weight + revisit memory
//------------------------------------------------------------------
double MEM_Auth(const int i)
{
   return(mem_score[i] + mem_weight[i]*4.0 + mem_rev[i]*3.0);
}

void MEM_AddNode(const double tip, const double mid, const int dir, const double sc, const int wt)
{
   if(mem_count>=FALCON_MAX_NODES)
   {
      for(int i=1;i<FALCON_MAX_NODES;i++)
      {
         mem_px[i-1]=mem_px[i]; mem_mid[i-1]=mem_mid[i]; mem_dir[i-1]=mem_dir[i];
         mem_score[i-1]=mem_score[i]; mem_weight[i-1]=mem_weight[i];
         mem_state[i-1]=mem_state[i]; mem_birth[i-1]=mem_birth[i]; mem_rev[i-1]=mem_rev[i];
      }
      mem_count=FALCON_MAX_NODES-1;
   }
   mem_px[mem_count]=tip; mem_mid[mem_count]=mid; mem_dir[mem_count]=dir;
   mem_score[mem_count]=sc; mem_weight[mem_count]=wt; mem_state[mem_count]=0;
   mem_birth[mem_count]=g_barCounter; mem_rev[mem_count]=0;
   mem_count++;
   FalconPublish(EVT_NODE_BORN, tip);
}

//------------------------------------------------------------------
// Scan each fixed timeframe for a fresh FU node and register it.
// weights: M1=3 M5=4 M15=5 M30=6(approx H1) H1=5... we follow F16's
// MN..M1 weighting scaled to our 7 rungs (higher TF => higher wt).
//------------------------------------------------------------------
void MEM_ScanTF(const ENUM_TIMEFRAMES tf, const int rung, const int wt)
{
   int lb = g_cfg.fuLookback;
   int need = lb*2+20;
   double h[],l[],o[],c[];
   ArraySetAsSeries(h,true); ArraySetAsSeries(l,true);
   ArraySetAsSeries(o,true); ArraySetAsSeries(c,true);
   if(CopyHigh(_Symbol,tf,0,need,h)<need) return;
   if(CopyLow (_Symbol,tf,0,need,l)<need) return;
   if(CopyOpen(_Symbol,tf,0,need,o)<need) return;
   if(CopyClose(_Symbol,tf,0,need,c)<need) return;

   double rng=MathMax(h[1]-l[1],1e-10);
   double pHi=-DBL_MAX,pLo=DBL_MAX;
   for(int i=2;i<2+lb;i++){ if(h[i]>pHi)pHi=h[i]; if(l[i]<pLo)pLo=l[i]; }
   double locHi=-DBL_MAX,locLo=DBL_MAX;
   for(int i=1;i<1+lb;i++){ if(h[i]>locHi)locHi=h[i]; if(l[i]<locLo)locLo=l[i]; }

   double uw=(h[1]-MathMax(o[1],c[1]))/rng;
   double lw=(MathMin(o[1],c[1])-l[1])/rng;
   bool bear = uw>=g_cfg.wickFrac && ((h[1]>=pHi && c[1]<pHi)||(h[1]>=locHi && c[1]<o[1]));
   bool bull = lw>=g_cfg.wickFrac && ((l[1]<=pLo && c[1]>pLo)||(l[1]<=locLo && c[1]>o[1]));

   double tip=0,mid=0; int dir=0;
   if(bear){ dir=-1; tip=h[1]; double bH=MathMax(o[1],c[1]); mid=bH+(tip-bH)*0.5; }
   else if(bull){ dir=1; tip=l[1]; double bL=MathMin(o[1],c[1]); mid=tip+(bL-tip)*0.5; }

   if(dir!=0 && tip!=mem_lastTip[rung])
   {
      double wk = (dir==-1)?(tip-MathMax(o[1],c[1]))/MathMax(h[1]-l[1],1e-10):
                            (MathMin(o[1],c[1])-tip)/MathMax(h[1]-l[1],1e-10);
      double sc = FalconClamp(20.0+MathMin(25.0,wk*15.0)+(wk>1.0?15.0:0.0)+(wk>1.5?10.0:0.0),0,100);
      MEM_AddNode(tip,mid,dir,sc,wt);
      mem_lastTip[rung]=tip;
   }
}

//------------------------------------------------------------------
// Age every node: break/dormant/historical + revisit counting.
//------------------------------------------------------------------
void MEM_AgeNodes()
{
   double atr = g_state.physics.atr;
   double close1=gClose[1];
   for(int i=0;i<mem_count;i++)
   {
      if(mem_state[i]==2) continue;
      double np=mem_px[i];
      int    nd=mem_dir[i];
      int    age=g_barCounter-mem_birth[i];
      bool broken=(nd==-1 ? close1>np : close1<np);
      if(broken){ mem_state[i]=2; FalconPublish(EVT_NODE_BROKEN,np); continue; }
      if(MathAbs(close1-np)<atr*0.25) mem_rev[i]++;
      int wt=mem_weight[i];
      mem_state[i] = (age>g_cfg.historyBars*wt ? 3 : age>g_cfg.dormantBars*wt ? 1 : 0);
   }
}

//------------------------------------------------------------------
// Network bias / pressure / authority + nearest attractor.
//------------------------------------------------------------------
void MEM_ComputeNetwork()
{
   FalconNetwork n;
   double close1=gClose[1];
   double bullAuth=0, bearAuth=0;
   int live=0;
   double nearestDist=DBL_MAX; int nearestIdx=-1;

   // export capped active node set into state arrays
   n.count=0;
   for(int i=0;i<mem_count && n.count<FALCON_MAX_NODES;i++)
   {
      n.px[n.count]=mem_px[i]; n.mid[n.count]=mem_mid[i]; n.dir[n.count]=mem_dir[i];
      n.score[n.count]=mem_score[i]; n.weight[n.count]=mem_weight[i];
      n.nstate[n.count]=mem_state[i]; n.birthBar[n.count]=mem_birth[i]; n.revisits[n.count]=mem_rev[i];
      n.count++;

      if(mem_state[i]!=2 && MEM_Auth(i)>=g_cfg.authMin)
      {
         live++;
         if(mem_dir[i]==1) bullAuth+=MEM_Auth(i); else if(mem_dir[i]==-1) bearAuth+=MEM_Auth(i);
         double d=MathAbs(close1-mem_px[i]);
         if(d<nearestDist){ nearestDist=d; nearestIdx=i; }
      }
   }

   double pressure = (bullAuth+bearAuth>0)?(bullAuth-bearAuth)/(bullAuth+bearAuth)*100.0:0.0;
   n.bullAuthority=bullAuth; n.bearAuthority=bearAuth;
   n.pressure=pressure;
   n.pressureDir=(pressure>12?DIR_LONG:pressure<-12?DIR_SHORT:DIR_NONE);
   n.liveCount=live;
   n.nearestAttractorIdx=nearestIdx;

   // network bias: highest-weight unbroken node's direction (HTF priority)
   int bias=DIR_NONE, bestWt=-1;
   for(int i=0;i<mem_count;i++)
      if(mem_state[i]!=2 && mem_weight[i]>bestWt){ bestWt=mem_weight[i]; bias=mem_dir[i]; }
   if(bias==DIR_NONE) bias=n.pressureDir;
   n.bias=bias;

   // ---- CONVERSATION GRAPH: edges between nearby authoritative nodes ----
   double atr=g_state.physics.atr;
   n.edgeCount=0;
   double convWeight=0;
   int connections=0;
   for(int i=0;i<mem_count && n.edgeCount<FALCON_MAX_EDGES;i++)
   {
      if(mem_state[i]==2 || MEM_Auth(i)<g_cfg.authMin) continue;
      for(int j=i+1;j<mem_count && n.edgeCount<FALCON_MAX_EDGES;j++)
      {
         if(mem_state[j]==2 || MEM_Auth(j)<g_cfg.authMin) continue;
         double gap=MathAbs(mem_px[i]-mem_px[j]);
         if(gap < atr*1.5)   // nodes "in conversation" when within ~1.5 ATR
         {
            double w=(MEM_Auth(i)+MEM_Auth(j))*0.5 * (1.0 - gap/MathMax(atr*1.5,1e-10));
            n.edgeFrom[n.edgeCount]=i; n.edgeTo[n.edgeCount]=j; n.edgeWeight[n.edgeCount]=w;
            n.edgeCount++; connections++; convWeight+=w;
         }
      }
   }
   n.connections=connections;
   n.conversationWeight=FalconClamp(convWeight/MathMax(1.0,(double)mem_count)*2.0,0,100);

   g_state.network=n;
}

//------------------------------------------------------------------
// Curve tree ownership (who owns price, life, energy, evolution).
//------------------------------------------------------------------
void MEM_ComputeCurve()
{
   FalconCurve c;
   FalconWave w=g_state.wave;
   FalconHTF  h=g_state.htf;

   c.ownerDir    = (h.stackDir!=DIR_NONE ? h.stackDir : w.direction);
   c.ownerOrigin = w.origin;
   c.ownerExtreme= w.extreme;
   c.rootDir     = h.stackDir;
   c.emergentPhase = w.phase;
   c.childCount  = w.entryCycle;
   c.evolution   = w.dominanceTransfer;
   // life: how much of the curve has been spent (progress) inverted by residual energy
   c.life        = FalconClamp(100.0 - w.completion*0.6 - g_state.physics.compression*0.4,0,100);
   c.energy      = w.energy;

   // ---- EXPLICIT CURVE TREE (root → parent → children) ----
   // root = the owning HTF curve (highest agreeing timeframe); parent = chart
   // wave; children = the recursive sub-waves spawned inside it.
   c.ownerTF       = h.ownerTF;
   c.rootOrigin    = (h.ownerTF>=0 && h.ownerTF<7 ? me_htfOrigin[h.ownerTF] : w.origin);
   c.rootExtreme   = w.extreme;
   c.parentDir     = w.direction;
   c.parentOrigin  = w.origin;
   c.parentExtreme = w.extreme;
   c.emergentNodes = w.recursionBreaks;   // each recursion break births an emergent node

   g_state.curve=c;
}

//------------------------------------------------------------------
// WAVE MATRIX — per-timeframe wave grid (dir/phase/progress) + the
// dominant rung and cross-TF agreement. Reads the HTF stack the
// Market Engine already computed (no recomputation = no duplication).
//------------------------------------------------------------------
void MEM_ComputeWaveMatrix()
{
   FalconWaveMatrix wm;
   FalconHTF h=g_state.htf;
   int bull=0,bear=0;
   double energy=0;
   for(int i=0;i<7;i++)
   {
      wm.dir[i]=h.dir[i];
      // only the chart rung has a true phase from the FSM; others approximate
      // their phase from direction + alignment (progress proxy).
      wm.phase[i]=(i==6 ? g_state.wave.phase : (h.dir[i]==DIR_NONE?PH_P4_ORIGIN:PH_EXPANSION));
      wm.progress[i]=h.prog[i];
      if(h.dir[i]==DIR_LONG) bull++; else if(h.dir[i]==DIR_SHORT) bear++;
      energy += (h.dir[i]!=DIR_NONE?1.0:0.0);
   }
   wm.dominantTF  = h.ownerTF;
   wm.dominantDir = h.stackDir;
   wm.agreement   = h.alignment;
   wm.matrixEnergy= energy/7.0*100.0;
   g_state.waveMatrix=wm;
}

//------------------------------------------------------------------
// FUTURE ENGAGEMENT ZONE (FEZ) — the corridor price is being pulled
// toward NEXT to engage liquidity / continue the owning curve. In an
// unresolved expansion the engagement target is the next liquidity
// pool / supply-demand boundary in the owner's direction.
//------------------------------------------------------------------
void MEM_ComputeFEZ()
{
   FalconFEZ fz;
   double atr=g_state.physics.atr;
   double close1=gClose[1];
   int dir=g_state.curve.ownerDir;
   FalconSupplyDemand sd=g_state.supplyDemand;

   double target=0;
   if(dir==DIR_LONG)  target=(sd.supplyTop!=0?sd.supplyTop:g_state.wave.objective);
   if(dir==DIR_SHORT) target=(sd.demandBot!=0?sd.demandBot:g_state.wave.objective);

   fz.dir=dir;
   fz.active=(target!=0 && dir!=DIR_NONE);
   fz.top = (target!=0? target+atr*0.5:0.0);
   fz.bot = (target!=0? target-atr*0.5:0.0);
   fz.distanceATR = (target!=0? MathAbs(target-close1)/MathMax(atr,1e-10):0.0);
   fz.confidence = FalconClamp(g_state.htf.alignment*0.5 + (g_state.intel.resolutionState==RES_UNRESOLVED?40.0:10.0),0,100);

   g_state.fez=fz;
}

//------------------------------------------------------------------
// FUTURE RETURN ZONE (FRZ) — OWNER-DRIVEN destination. The price will
// ultimately RETURN to the owner curve's origin zone. Per the design
// law (ODDE): the destination is inherited from the owner hierarchy,
// NOT the entry timeframe. If the owner breaks, it extends to the next
// higher timeframe.
//------------------------------------------------------------------
void MEM_ComputeFRZ()
{
   FalconFRZ fr;
   double atr=g_state.physics.atr;
   int ownerTF=g_state.htf.ownerTF;
   int ownerDir=g_state.curve.ownerDir;

   // the owner's origin is the return destination; return direction is opposite
   // to the owner's impulse (price returns to the owner demand for a bull owner).
   double ownerOrigin = (ownerTF>=0 && ownerTF<7 ? me_htfOrigin[ownerTF] : g_state.wave.origin);
   double target = ownerOrigin;

   fr.ownerTF=ownerTF;
   fr.dir = (ownerDir==DIR_LONG?DIR_LONG:ownerDir==DIR_SHORT?DIR_SHORT:DIR_NONE);
   fr.targetPrice=target;
   fr.active=(target!=0 && ownerDir!=DIR_NONE);
   fr.top=(target!=0? target+atr*0.75:0.0);
   fr.bot=(target!=0? target-atr*0.75:0.0);
   // confidence rises with resolution progress and owner alignment
   fr.confidence=FalconClamp(g_state.intel.dissipationProgress*0.5 + g_state.htf.alignment*0.4,0,100);

   g_state.frz=fr;
}

//------------------------------------------------------------------
// Campaign ownership (dominant institutional side + control score).
//------------------------------------------------------------------
int mem_campOwner=0; int mem_campStart=0;

void MEM_ComputeCampaign()
{
   FalconCampaign cm;
   FalconHTF h=g_state.htf;
   FalconNetwork n=g_state.network;

   // control derives from fractal alignment + network pressure agreement
   int side = h.stackDir;
   double control = h.alignment;
   if(n.pressureDir==side && side!=DIR_NONE) control = MathMin(100.0, control+15.0);

   if(side!=mem_campOwner && side!=DIR_NONE){ mem_campOwner=side; mem_campStart=g_barCounter; }

   cm.owner=mem_campOwner;
   cm.controlScore=FalconClamp(control,0,100);
   cm.objectiveDir=mem_campOwner;
   cm.remainingEnergy=g_state.intel.residualEnergy; // filled later by intel; safe default
   cm.age=g_barCounter-mem_campStart;
   cm.institution=(mem_campOwner==DIR_LONG?"Accumulation":mem_campOwner==DIR_SHORT?"Distribution":"Neutral");

   g_state.campaign=cm;
}

//------------------------------------------------------------------
// Participant engine (buyer/seller/passive/aggressive pressure).
//------------------------------------------------------------------
void MEM_ComputeParticipants()
{
   FalconParticipants p;
   FalconPhysics ph=g_state.physics;
   FalconLiquidity lq=g_state.liquidity;

   double bullForce = (ph.velocity>0? MathMin(MathAbs(ph.velocity)/MathMax(ph.atr*0.15,1e-10)*100.0,100.0):0.0);
   double bearForce = (ph.velocity<0? MathMin(MathAbs(ph.velocity)/MathMax(ph.atr*0.15,1e-10)*100.0,100.0):0.0);
   p.buyer  = FalconClamp(bullForce*0.6 + (lq.pressure>0?lq.pressure*0.4:0.0),0,100);
   p.seller = FalconClamp(bearForce*0.6 + (lq.pressure<0?-lq.pressure*0.4:0.0),0,100);
   p.aggressive = FalconClamp(ph.expansion,0,100);
   p.passive    = FalconClamp(100.0-ph.expansion,0,100);
   p.interference = FalconClamp(MathAbs(p.buyer-p.seller)<20?60.0:20.0,0,100);
   p.participationScore = FalconClamp((p.buyer+p.seller)/2.0,0,100);
   p.marketPressure = p.buyer - p.seller;

   g_state.participants=p;
}

//==================================================================
// MASTER ENTRY — Memory Engine pipeline step
//==================================================================
void MemoryEngineRun()
{
   // scan fixed timeframe ladder for fresh nodes (HTF heavier weight)
   MEM_ScanTF(PERIOD_H4, 5, 6);
   MEM_ScanTF(PERIOD_H1, 4, 5);
   MEM_ScanTF(PERIOD_M30,3, 5);
   MEM_ScanTF(PERIOD_M15,2, 4);
   MEM_ScanTF(PERIOD_M5, 1, 3);
   MEM_ScanTF(PERIOD_M1, 0, 3);

   MEM_AgeNodes();
   MEM_ComputeNetwork();
   MEM_ComputeCurve();
   MEM_ComputeWaveMatrix();
   MEM_ComputeFEZ();
   MEM_ComputeFRZ();
   MEM_ComputeCampaign();
   MEM_ComputeParticipants();
}

#endif // FALCON_MEMORY_ENGINE_MQH
//+------------------------------------------------------------------+

//  ===== Engines/IntelligenceEngine.mqh =====
//+------------------------------------------------------------------+
//|  FALCON OS — Intelligence Layer : IntelligenceEngine.mqh        |
//|  Source: LETRA + F16 (reasoning)                                |
//|                                                                  |
//|  The OS REASONS. Belief scores, the Energy Resolution Framework  |
//|  (EDE dissipation / RE recursion / EAE attractor), a PREDICTIVE  |
//|  recursion-forecast layer, and the continuous executionProbability|
//|  that drives decisions. Per the design law: phases are OUTPUTS,   |
//|  probabilities are the inputs. Writes g_state.intel.             |
//+------------------------------------------------------------------+
#ifndef FALCON_INTEL_ENGINE_MQH
#define FALCON_INTEL_ENGINE_MQH


// persistent smoothed beliefs
double ie_bExp=0, ie_bConv=0, ie_bCreate=0, ie_bAbs=0, ie_bRetr=0, ie_bRet=0;
int    ie_prevRes=RES_UNRESOLVED;
// persistent validation-loop state
double ie_prevPredPrice=0; int ie_prevPredDir=0; double ie_valScore=50.0;

void IntelligenceEngineInit()
{
   ie_bExp=0; ie_bConv=0; ie_bCreate=0; ie_bAbs=0; ie_bRetr=0; ie_bRet=0;
   ie_prevRes=RES_UNRESOLVED;
   ie_prevPredPrice=0; ie_prevPredDir=0; ie_valScore=50.0;
}

//------------------------------------------------------------------
// Observation scores from physics (LETRA Section 9).
//------------------------------------------------------------------
double IE_ExpansionScore()
{
   FalconPhysics p=g_state.physics;
   double velScore=MathMin(MathAbs(p.velocity)/MathMax(p.atr*0.1,1e-10)*50.0,100.0);
   return(FalconClamp((p.efficiency>g_cfg.effThresh?p.efficiency*60.0:p.efficiency*30.0)
          + (p.displacement>g_cfg.dispThresh?(p.displacement/MathMax(g_cfg.dispThresh,1e-10)-1.0)*20.0:0.0)
          + ((p.velocity>0&&p.acceleration>0)||(p.velocity<0&&p.acceleration<0)?velScore*0.2:0.0),0,100));
}
double IE_DecayScore()
{
   FalconPhysics p=g_state.physics;
   double convScore=MathMin(MathAbs(p.convexitySmooth)/MathMax(p.atr*g_cfg.convMult,1e-10)*25.0,100.0);
   return(FalconClamp((p.bullDecay||p.bearDecay?40.0:0.0)+(convScore>30?convScore*0.5:0.0),0,100));
}
double IE_CurvatureScore()
{
   FalconPhysics p=g_state.physics;
   return(MathMin(MathAbs(p.convexitySmooth)/MathMax(p.atr*g_cfg.convMult,1e-10)*25.0,100.0));
}
double IE_AbsorptionScore()
{
   FalconPhysics p=g_state.physics;
   return(FalconClamp((p.efficiency<g_cfg.effThresh*0.7?(1.0-p.efficiency/MathMax(g_cfg.effThresh,1e-10))*50.0:0.0)
          +(p.displacement<g_cfg.dispThresh*0.5?20.0:0.0),0,100));
}
double IE_LiquidityScore()
{
   double dec=IE_DecayScore(), cur=IE_CurvatureScore();
   FalconPhysics p=g_state.physics;
   return(FalconClamp(dec*0.4+cur*0.4+(p.displacement>g_cfg.dispThresh*1.2&&(p.bullDecay||p.bearDecay)?20.0:0.0),0,100));
}

//------------------------------------------------------------------
// ENERGY DISSIPATION ENGINE (EDE) — from the phase lifecycle.
//------------------------------------------------------------------
void IE_EnergyResolution(FalconIntelligence &x)
{
   FalconWave w=g_state.wave;
   FalconPhysics p=g_state.physics;
   int phase=w.phase;

   int edeState = (phase==PH_P4_ORIGIN||phase==PH_EXPANSION)?1:
                  (phase==PH_EXP_PRECONVEXITY)?2:
                  (phase==PH_EXP_INDUCTION)?3:
                  (phase==PH_EXP_LIQUIDITY)?4:
                  (phase==PH_NEW_HIGH||phase==PH_NEW_LOW)?5:6;

   double expEnergy = FalconClamp(IE_ExpansionScore()*0.50+((p.bullImpulse||p.bearImpulse)?30.0:0.0)+p.efficiency*20.0,0,100);
   double dissip    = FalconClamp((edeState>=2?IE_DecayScore()*0.40:0.0)
                      +(edeState>=3?IE_CurvatureScore()*0.30:0.0)
                      +(edeState>=4?IE_LiquidityScore()*0.30:0.0),0,100);
   double dissipProg= FalconClamp((edeState>=2?25.0:0.0)+(edeState>=3?25.0:0.0)+(edeState>=4?25.0:0.0)+(edeState>=5?25.0:0.0),0,100);

   x.expansionEnergy   = expEnergy;
   x.dissipatedEnergy  = dissip;
   x.dissipationProgress= dissipProg;
   x.residualEnergy    = FalconClamp(MathMax(0.0,expEnergy-dissip),0,100);

   // RESOLUTION ENGINE (RE)
   x.expectedCycles    = (int)MathMax(1,MathMin(w.waveDepth+2,4));
   x.completedCycles   = (int)MathMax(0,MathMin(w.entryCycle,x.expectedCycles));
   x.recursiveCompletion = (x.expectedCycles>0?MathMin((double)x.completedCycles/(double)x.expectedCycles*100.0,100.0):0.0);

   bool objectiveReached = (edeState>=5);
   bool fullDissipation  = (dissipProg>=75.0);
   bool absorbedReturned = (phase==PH_DEMAND_RETURN||phase==PH_SUPPLY_RETURN)&&w.recursiveComplete;

   if(absorbedReturned && fullDissipation && x.recursiveCompletion>=75.0) x.resolutionState=RES_RESOLVED;
   else if(objectiveReached && dissipProg>=50.0) x.resolutionState=RES_PARTIALLY_RESOLVED;
   else x.resolutionState=RES_UNRESOLVED;

   // ENERGY ATTRACTOR ENGINE (EAE)
   double attractorPx=0;
   if(w.direction!=DIR_NONE)
   {
      if(x.resolutionState==RES_UNRESOLVED)
         attractorPx = (w.direction==DIR_LONG? (w.flipBot!=0?w.flipBot:gClose[1]-p.atr*2.0) : (w.flipTop!=0?w.flipTop:gClose[1]+p.atr*2.0));
      else if(x.resolutionState==RES_PARTIALLY_RESOLVED)
         attractorPx = (w.direction==DIR_LONG? (w.point4Low!=0?w.point4Low:gClose[1]-p.atr) : (w.point4High!=0?w.point4High:gClose[1]+p.atr));
   }
   x.attractorPrice = attractorPx;
   x.attractorScore = FalconClamp(x.residualEnergy*0.40
                      + (x.resolutionState==RES_UNRESOLVED?30.0:x.resolutionState==RES_PARTIALLY_RESOLVED?20.0:5.0)
                      + (attractorPx!=0?MathMax(0.0,30.0-MathAbs(gClose[1]-attractorPx)/MathMax(p.atr,1e-10)*5.0):0.0),0,100);

   if(x.resolutionState!=ie_prevRes){ FalconPublish(EVT_RESOLUTION_CHANGE,x.resolutionState); ie_prevRes=x.resolutionState; }
}

//------------------------------------------------------------------
// BELIEF ENGINE — smoothed continuous beliefs (LETRA Section 12A).
//------------------------------------------------------------------
void IE_Beliefs(FalconIntelligence &x)
{
   FalconPhysics p=g_state.physics;
   FalconWave w=g_state.wave;
   FalconLiquidity lq=g_state.liquidity;
   double wp=w.completion;
   double expObs=IE_ExpansionScore(), decObs=IE_DecayScore(), curObs=IE_CurvatureScore(), absObs=IE_AbsorptionScore(), liqObs=IE_LiquidityScore();
   bool preConv = p.bullDecay||p.bearDecay;
   bool induct  = (w.direction==DIR_LONG && p.bearImpulse && g_state.structure.trend==DIR_LONG)||
                  (w.direction==DIR_SHORT&& p.bullImpulse && g_state.structure.trend==DIR_SHORT);
   bool liqEv   = liqObs>50.0 && decObs>40.0;

   double expMult = (wp<40.0?1.20:wp<60.0?0.80:0.50);
   double rawExp = FalconClamp((expObs*0.45+((p.bullImpulse||p.bearImpulse)?30.0:0.0)+(p.efficiency>g_cfg.effThresh*1.1?15.0:0.0))*expMult,0,100);
   double convMult=(wp>=30.0&&wp<=65.0?1.30:0.70);
   double rawConv=FalconClamp((decObs*0.30+curObs*0.25+(preConv?15.0:0.0)+(induct?10.0:0.0)+(liqEv?5.0:0.0)+g_state.convexity.maturity*0.08)*convMult,0,100);
   double creatMult=(wp>=45.0&&wp<=68.0?1.40:0.60);
   double rawCreate=FalconClamp(((g_state.convexity.maturity>50?g_state.convexity.maturity*0.12:0.0)+(decObs>60?decObs*0.20:0.0)+(liqObs>50?liqObs*0.20:0.0)+(absObs>20?absObs*0.15:0.0))*creatMult,0,100);
   double rawAbs=FalconClamp(absObs*0.50+(p.efficiency<g_cfg.effThresh*0.6?25.0:0.0)+(p.displacement<g_cfg.dispThresh*0.5?15.0:0.0),0,100);
   double rawRetr=FalconClamp(((w.direction==DIR_LONG&&p.bearImpulse)||(w.direction==DIR_SHORT&&p.bullImpulse)?45.0:0.0)+(rawAbs>50?rawAbs*0.30:0.0)+(curObs>40?15.0:0.0),0,100);
   double rawRet=FalconClamp((w.flipTop!=0&&gClose[1]<=w.flipTop&&gClose[1]>=w.flipBot?35.0:0.0)+(rawRetr>60?rawRetr*0.30:0.0)+(lq.score>50?lq.score*0.15:0.0)+((lq.sweepBull||lq.sweepBear)?20.0:0.0),0,100);

   int sm=g_cfg.beliefSmooth;
   ie_bExp   =FalconEMA(ie_bExp,rawExp,sm);
   ie_bConv  =FalconEMA(ie_bConv,rawConv,sm);
   ie_bCreate=FalconEMA(ie_bCreate,rawCreate,sm);
   ie_bAbs   =FalconEMA(ie_bAbs,rawAbs,sm);
   ie_bRetr  =FalconEMA(ie_bRetr,rawRetr,sm);
   ie_bRet   =FalconEMA(ie_bRet,rawRet,sm);

   x.beliefExpansion =ie_bExp;
   x.beliefConvexity =ie_bConv;
   x.beliefCreation  =ie_bCreate;
   x.beliefAbsorption=ie_bAbs;
   x.beliefRetracement=ie_bRetr;
   x.beliefReturn    =ie_bRet;
}

//------------------------------------------------------------------
// RECURSIVE FORECAST + GEOMETRY (RFE/FGE) — PREDICTIVE, not descriptive.
// Output: expected loops remaining, failure-swing prob, immediate-
// execution prob — derived from geometry (distance/compression/
// velocity/convexity/curvature). Per spec v10: predict what is
// physically possible from here.
//------------------------------------------------------------------
void IE_Forecast(FalconIntelligence &x)
{
   FalconPhysics p=g_state.physics;
   FalconWave w=g_state.wave;
   FalconConvexity cv=g_state.convexity;
   double atr=MathMax(p.atr,1e-10);

   double distToTarget = (w.objective!=0)? MathAbs(w.objective-gClose[1])/atr : 4.0;
   double compression  = p.compression/100.0;          // 0..1
   double velNorm      = MathMin(MathAbs(p.velocity)/MathMax(atr*0.15,1e-10),1.0);
   double convexNorm   = MathMin(MathAbs(p.convexitySmooth)/MathMax(atr*g_cfg.convMult*2.0,1e-10),1.0);

   // high compression -> many tiny recursive loops; low -> few large
   x.expectedLoopsRemaining = FalconClamp(distToTarget*(0.5+compression*2.5),0,12);

   // failure-swing probability: rises with residual energy against direction + low velocity into target
   x.failureSwingProb = FalconClamp((x.residualEnergy*0.5 + (1.0-velNorm)*40.0
                        + (g_state.network.pressureDir!=DIR_NONE && g_state.network.pressureDir!=w.direction?20.0:0.0))/100.0,0,1);

   // immediate-execution probability: close to attractor, energy spent into the zone, geometry capacity low
   double proximity = (x.attractorPrice!=0)? MathMax(0.0,1.0-MathAbs(gClose[1]-x.attractorPrice)/(atr*3.0)):0.0;
   x.immediateExecutionProb = FalconClamp(proximity*0.45 + (cv.geometryCapacity<30?0.30:0.0)
                              + (x.dissipationProgress>60?0.25:0.0),0,1);

   // CONTINUOUS EXECUTION PROBABILITY (the law: this drives decisions, not phase)
   // Combines ownership · maturity · geometry · destination · recursion.
   // NOTE: a raw 5-way product collapses toward zero (0.7^5 ~ 0.17) and can
   // essentially never exceed 0.90, so the engine would never arm. Instead we
   // use a calibrated WEIGHTED BLEND, and preserve the multiplicative SPIRIT
   // with a "weakest-link" veto: if ownership/geometry/recursion are weak, the
   // probability is capped (a single broken pillar still kills the shot).
   double ownership   = g_state.htf.alignment/100.0;
   double maturity     = FalconClamp(cv.maturity/100.0,0,1);
   double geometry     = FalconClamp(cv.geometryCapacity/100.0,0,1); // ROOM TO TARGET — entries need room, not exhaustion
   double destination  = FalconClamp(x.attractorScore/100.0,0,1);
   double recursion    = FalconClamp(1.0 - x.failureSwingProb,0,1);

   double blend   = 0.30*ownership + 0.20*maturity + 0.20*geometry + 0.15*destination + 0.15*recursion;
   double weakest = MathMin(ownership, MathMin(geometry, recursion));
   double veto    = FalconClamp(0.45 + 0.55*weakest, 0, 1); // weak core pillar caps conviction
   x.executionProbability = FalconClamp(blend*veto, 0, 1);
   // a clean immediate magnet can arm directly
   x.executionProbability = FalconClamp(MathMax(x.executionProbability, x.immediateExecutionProb*ownership),0,1);
}

//------------------------------------------------------------------
// INTENT / TIMING / OPPORTUNITY descriptors (human-readable OUTPUTS).
//------------------------------------------------------------------
void IE_Narrative(FalconIntelligence &x)
{
   FalconWave w=g_state.wave;
   int phase=w.phase;
   double wp=w.completion;

   x.timing = (phase==PH_DEMAND_RETURN||phase==PH_SUPPLY_RETURN||x.resolutionState==RES_RESOLVED)?"RESOLVED":
              wp<15?"VERY EARLY":wp<35?"EARLY":wp<55?"DEVELOPING":wp<80?"MID CYCLE":wp<96?"LATE":"TERMINAL";

   x.intent = (phase==PH_EXPANSION)?"EXPANSION":
              (phase==PH_EXP_PRECONVEXITY)?"CONTINUATION":
              (phase==PH_EXP_INDUCTION||phase==PH_INDUCTION)?"RESOLUTION":
              (phase==PH_EXP_LIQUIDITY||phase==PH_LIQUIDATION||phase==PH_NEW_HIGH||phase==PH_NEW_LOW)?"DELIVERY":
              (phase==PH_RETRACEMENT)?"RETRACEMENT":
              (phase==PH_DEMAND_RETURN||phase==PH_SUPPLY_RETURN)?"RETURN":"BALANCE";

   x.story = FalconDirStr(w.direction)+" wave "+DoubleToString(wp,0)+"% — "+FalconPhaseStr(phase)
             +" · "+FalconResStr(x.resolutionState)+" · intent "+x.intent;
}

//------------------------------------------------------------------
// HYPOTHESIS ENGINE — forms the current leading market hypothesis from
// the belief field + owner curve. "What is most likely happening?"
//------------------------------------------------------------------
void IE_Hypothesis(FalconIntelligence &x)
{
   FalconWave w=g_state.wave;
   int ownerDir=g_state.curve.ownerDir;

   // pick the dominant belief
   double bMax=x.beliefExpansion; string label="Expansion continuation"; int dir=w.direction;
   if(x.beliefRetracement>bMax){ bMax=x.beliefRetracement; label="Retracement into zone"; }
   if(x.beliefCreation>bMax){ bMax=x.beliefCreation; label="New cycle creation"; }
   if(x.beliefAbsorption>bMax){ bMax=x.beliefAbsorption; label="Absorption / stall"; }
   if(x.beliefReturn>bMax){ bMax=x.beliefReturn; label="Return from zone"; dir=-w.direction; }
   if(x.beliefConvexity>bMax){ bMax=x.beliefConvexity; label="Convexity transfer"; }

   x.hypothesis    = FalconDirStr(ownerDir!=DIR_NONE?ownerDir:dir)+" — "+label;
   x.hypothesisDir = (ownerDir!=DIR_NONE?ownerDir:dir);
   x.hypothesisProb= FalconClamp(bMax/100.0,0,1);
}

//------------------------------------------------------------------
// PREDICTION ENGINE — projects the next destination price + the
// probability of reaching it, using the owner-driven FEZ/FRZ and the
// predictive forecast (NOT a phase label).
//------------------------------------------------------------------
void IE_Prediction(FalconIntelligence &x)
{
   FalconFEZ fz=g_state.fez;
   FalconFRZ fr=g_state.frz;
   int hd=x.hypothesisDir;

   double dest=0; string what="";
   if(x.resolutionState==RES_UNRESOLVED && fz.active)
   {
      dest=(fz.top+fz.bot)*0.5; what="engage "+FalconDirStr(fz.dir)+" liquidity";
   }
   else if(fr.active)
   {
      dest=fr.targetPrice; what="return to owner "+FalconDirStr(fr.dir)+" origin";
   }
   else
   {
      dest=g_state.wave.objective; what="wave objective";
   }

   x.predictionPrice = dest;
   x.prediction      = what+(dest!=0?(" @ "+DoubleToString(dest,_Digits)):"");
   // probability blends immediate-execution proximity, exec prob and owner alignment
   x.predictionProb  = FalconClamp(0.45*x.immediateExecutionProb + 0.35*x.executionProbability
                       + 0.20*(g_state.htf.alignment/100.0),0,1);
}

//------------------------------------------------------------------
// VALIDATION ENGINE — checks whether the PRIOR bar's prediction is
// being confirmed by price, and rolls a hit-rate score. Closes the
// belief → hypothesis → prediction → validation loop.
//------------------------------------------------------------------
void IE_Validation(FalconIntelligence &x)
{
   double close1=gClose[1];
   bool confirmed=false;
   if(ie_prevPredPrice!=0 && ie_prevPredDir!=DIR_NONE)
   {
      // confirmed if price moved toward the predicted destination this bar
      double prevClose=gClose[2];
      double moved = close1-prevClose;
      confirmed = (ie_prevPredDir==DIR_LONG ? moved>0 : moved<0);
   }
   ie_valScore = FalconEMA(ie_valScore, confirmed?100.0:0.0, 10);
   x.validated       = confirmed;
   x.validationScore = FalconClamp(ie_valScore,0,100);

   // store this bar's prediction for next-bar validation
   ie_prevPredPrice = x.predictionPrice;
   ie_prevPredDir   = (x.predictionPrice!=0 ? (x.predictionPrice>close1?DIR_LONG:DIR_SHORT) : DIR_NONE);
}

//==================================================================
// MASTER ENTRY — Intelligence Engine pipeline step
//==================================================================
void IntelligenceEngineRun()
{
   FalconIntelligence x=g_state.intel;
   IE_EnergyResolution(x);
   IE_Beliefs(x);
   IE_Forecast(x);
   IE_Hypothesis(x);
   IE_Prediction(x);
   IE_Validation(x);
   IE_Narrative(x);
   g_state.intel=x;
   // back-fill campaign remaining energy now that residual is known
   g_state.campaign.remainingEnergy=x.residualEnergy;
}

#endif // FALCON_INTEL_ENGINE_MQH
//+------------------------------------------------------------------+

//  ===== Engines/DecisionEngine.mqh =====
//+------------------------------------------------------------------+
//|  FALCON OS — Decision Layer : DecisionEngine.mqh               |
//|  Source: F16 Senseei / Chief Strategist                         |
//|                                                                  |
//|  The OS DECIDES. It fuses the four independent voters into a     |
//|  master direction, computes alignment/conflict/confidence/threat |
//|  /opportunity, and emits EXACTLY ONE action:                     |
//|    BUY · SELL · WAIT · ATTACK · DEFEND · EXIT · SCALE · NO TRADE |
//|                                                                  |
//|  CRITICAL LAW: this engine NEVER branches on a phase label. It   |
//|  gates on continuous probabilities (executionProbability,        |
//|  confidence, threat, conflict). Phases are descriptive only.     |
//+------------------------------------------------------------------+
#ifndef FALCON_DECISION_ENGINE_MQH
#define FALCON_DECISION_ENGINE_MQH


int de_prevAction=ACT_NO_TRADE;

void DecisionEngineInit(){ de_prevAction=ACT_NO_TRADE; }

//------------------------------------------------------------------
// Opportunity grade label from the opportunity score.
//------------------------------------------------------------------
string DE_OppGrade(const int master, const double conflict, const double opp)
{
   if(master==DIR_NONE) return("NONE");
   if(conflict>60.0)    return("DEVELOPING");
   if(opp<20.0)         return("NONE");
   if(opp<40.0)         return("DEVELOPING");
   if(opp<62.0)         return("GOOD");
   if(opp<82.0)         return("STRONG");
   return("EXCEPTIONAL");
}

//------------------------------------------------------------------
// CHIEF STRATEGIST — maps the meta scores into the base verdict,
// gating ONLY on continuous probabilities (never on a phase label).
//------------------------------------------------------------------
int DE_ChiefStrategist(const int master,const double conflict,const double confidence,
                       const double threat,const string oppGrade,const double execProb,
                       const int resCode)
{
   bool strongOpp = (oppGrade=="STRONG" || oppGrade=="EXCEPTIONAL");
   bool goodOpp   = (oppGrade=="GOOD"   || oppGrade=="STRONG" || oppGrade=="EXCEPTIONAL");
   bool confOk    = (confidence>=g_cfg.minConf);
   bool threatOk  = (threat<g_cfg.maxThreat);
   bool probArmed = (execProb>=g_cfg.execProbArm);

   // A GOOD-or-better opportunity with healthy confidence and low threat is
   // tradeable. STRONG/EXCEPTIONAL simply arm faster. (Phases never gate this.)
   bool tradeable = (goodOpp && confOk && threatOk);

   if(master==DIR_NONE)                 return(ACT_WAIT);
   if(conflict>g_cfg.maxConflict)       return(ACT_WAIT);
   if(resCode==RES_RESOLVED)            return(ACT_EXIT);        // energy spent -> bank
   if(tradeable && probArmed)           return(master==DIR_LONG?ACT_BUY:ACT_SELL);
   if(tradeable)                        return(ACT_ATTACK);      // armed, probability building
   if(goodOpp || strongOpp)             return(ACT_PREPARE);
   return(ACT_WAIT);
}

//------------------------------------------------------------------
// CAMPAIGN AI — overlays multi-campaign management on the base verdict:
// DEFEND open exposure under rising failure risk, and SCALE a winning,
// aligned campaign that still has room to run. Operates per-campaign
// (direction-aware), consistent with the hedging multi-campaign model.
//------------------------------------------------------------------
int DE_CampaignAI(int action,const int master,const double threat)
{
   FalconIntelligence x=g_state.intel;
   bool haveExposure = (g_state.exec.openLongCount>0 || g_state.exec.openShortCount>0);

   // DEFEND: protect exposure when threat spikes or a failure swing looms
   if(haveExposure && (threat>=70.0 || x.failureSwingProb>=0.70) && action!=ACT_EXIT)
      action=ACT_DEFEND;

   // SCALE: add to a winning, aligned campaign with geometry room and unresolved energy
   bool campaignWinning = (g_state.campaign.owner==master && master!=DIR_NONE
                           && g_state.campaign.controlScore>=70.0);
   bool roomToRun = (g_state.convexity.geometryCapacity>40.0 && x.resolutionState==RES_UNRESOLVED);
   if(haveExposure && (action==ACT_BUY||action==ACT_SELL) && campaignWinning && roomToRun)
      action=ACT_SCALE;

   return(action);
}

//------------------------------------------------------------------
// MASTER CHIEF — the final holistic confirmation above Senseei. It
// does not re-derive direction; it CONFIRMS the committed shot by
// checking that the deep layers genuinely agree (curve owner + network
// + prediction validation + reward). If conviction is too low it
// downgrades a live BUY/SELL to ATTACK (armed, but hold fire).
//------------------------------------------------------------------
int DE_MasterChief(int action,const int master)
{
   FalconIntelligence x=g_state.intel;
   bool ownerAgree = (g_state.curve.ownerDir==master && master!=DIR_NONE);
   bool netAgree   = (g_state.network.bias==master);
   bool execOk     = (x.executionProbability>=g_cfg.execProbArm*0.9);

   double score = (ownerAgree?30.0:0.0)+(netAgree?20.0:0.0)
                 + x.confidence*0.25 + x.validationScore*0.15
                 + (100.0-x.threat)*0.10;
   g_state.intel.masterChiefScore = FalconClamp(score,0,100);

   // Commit on genuine agreement + reachable exec prob + holistic conviction.
   // Validation hit-rate is ADVISORY (it feeds the score above) — it is NOT a
   // hard gate, because the bar-to-bar direction check is too noisy in ranges
   // and would otherwise veto strong, well-aligned setups.
   bool commitOk = ((ownerAgree || netAgree) && execOk && score>=55.0);
   g_state.intel.masterChiefConfirm = commitOk;

   // Veto only NEW-ENTRY actions (BUY/SELL/ATTACK). If conviction is lacking,
   // downgrade to PREPARE (no fire). SCALE/DEFEND/EXIT are never vetoed.
   bool firing = (action==ACT_BUY || action==ACT_SELL || action==ACT_ATTACK);
   if(firing && !commitOk)
   {
      g_state.intel.masterChiefNote = "hold fire — "+((!ownerAgree && !netAgree)?"owner+net split":!execOk?"low exec prob":"low conviction");
      return(ACT_PREPARE);   // stand down, do not pull the trigger
   }
   g_state.intel.masterChiefNote = commitOk ? "cleared to engage" : "standby";
   return(action);
}

//==================================================================
// MASTER ENTRY — Senseei meta-intelligence + verdict
//==================================================================
void DecisionEngineRun()
{
   FalconIntelligence x=g_state.intel;
   FalconWave   w  = g_state.wave;
   FalconHTF    h  = g_state.htf;
   FalconNetwork n = g_state.network;

   //-- FOUR VOTERS -------------------------------------------------
   int vWave  = w.direction;          // LETRA wave
   int vStack = h.stackDir;           // fractal stack
   int vNet   = n.bias;               // invisible network bias
   int vPress = n.pressureDir;        // network authority pressure
   int sum    = vWave+vStack+vNet+vPress;
   int master = sum>0?DIR_LONG:sum<0?DIR_SHORT:DIR_NONE;

   int cast = (vWave!=0?1:0)+(vStack!=0?1:0)+(vNet!=0?1:0)+(vPress!=0?1:0);
   int forV = (vWave==master&&vWave!=0?1:0)+(vStack==master&&vStack!=0?1:0)
             +(vNet==master&&vNet!=0?1:0)+(vPress==master&&vPress!=0?1:0);

   double alignment = (cast>0?(double)forV/(double)cast*100.0:50.0);
   double conflict  = (cast>0?(double)(cast-forV)/(double)cast*100.0:0.0);

   //-- TIME / CYCLE conflict proxy (HTF stack disagreement) --------
   double timeAlign    = h.alignment;
   double timeConflict = h.conflict;

   double residual  = x.residualEnergy;
   double attractor = x.attractorScore;
   double stackPct  = h.alignment;
   int    eligN     = n.liveCount;
   int    resCode   = x.resolutionState;

   //-- THREAT (Senseei formula) -----------------------------------
   double threat = FalconClamp(conflict*0.40 + residual*0.28 + timeConflict*0.12
                   + ((vPress!=DIR_NONE && vPress!=master)?18.0:0.0)
                   + (resCode==RES_PARTIALLY_RESOLVED?10.0:0.0),0,100);

   //-- CONFIDENCE --------------------------------------------------
   double confidence = FalconClamp(alignment*0.40 + timeAlign*0.12 + stackPct*0.18
                       + attractor*0.15 + MathMin(15.0,eligN*1.2) - threat*0.20,0,100);

   //-- OPPORTUNITY -------------------------------------------------
   double oppScore = FalconClamp(alignment*0.40 + attractor*0.30 + stackPct*0.30 - threat*0.35,0,100);
   string oppGrade = DE_OppGrade(master,conflict,oppScore);

   //-- WRITE meta into intel + execution snapshot ------------------
   x.alignment       = alignment;
   x.conflict        = conflict;
   x.confidence      = confidence;
   x.threat          = threat;
   x.opportunity     = oppScore;
   x.opportunityGrade= oppGrade;

   //==============================================================
   // VERDICT — Chief Strategist (base) then Campaign AI (overlay).
   //==============================================================
   int action = DE_ChiefStrategist(master,conflict,confidence,threat,oppGrade,
                                    x.executionProbability,resCode);
   action     = DE_CampaignAI(action,master,threat);

   // commit the meta scores first so Master Chief reads/writes the shared intel
   g_state.intel = x;
   action        = DE_MasterChief(action,master);   // may downgrade BUY/SELL -> ATTACK
   g_state.intel.finalDecision = FalconActionStr(action);

   g_state.exec.action = action;
   g_state.exec.master = master;

   if(action!=de_prevAction)
   {
      FalconPublish(EVT_VERDICT_CHANGE, action, FalconActionStr(action));
      de_prevAction=action;
   }
}

#endif // FALCON_DECISION_ENGINE_MQH
//+------------------------------------------------------------------+

//  ===== Engines/ExecutionEngine.mqh =====
//+------------------------------------------------------------------+
//|  FALCON OS — Execution Layer : ExecutionEngine.mqh             |
//|  Source: Symphony (Execution & Risk)                            |
//|                                                                  |
//|  The OS EXECUTES — it never decides. It reads g_state.exec.action |
//|  (from the Decision Engine) and translates it into orders, sized  |
//|  by the lot engine, gated by the session filter, protected by the |
//|  DRDWCT risk engine (VaR / UDS / gamma / micro-bomb trimming) and |
//|  the ARC + institutional + phase-composite exit logic.            |
//|                                                                  |
//|  MULTI-CAMPAIGN: this account is HEDGING. Long and short          |
//|  campaigns coexist. Risk is evaluated PER DIRECTION on GROSS      |
//|  exposure (never netted), with a portfolio backstop on combined   |
//|  gross VaR. Opposite legs never mask each other's bleed.          |
//+------------------------------------------------------------------+
#ifndef FALCON_EXEC_ENGINE_MQH
#define FALCON_EXEC_ENGINE_MQH


//==================================================================
// DRDWCT STRUCTS (ported from Symphony, trimmed to essentials)
//==================================================================
struct EE_Position
{
   long   ticket; double lots; double entry; double sl; int direction; double pnl;
};
struct EE_Market { double spot; double atr15; double atr30; double equity; };
struct EE_Metrics
{
   long ticket; double lots; int direction; double entry; double sl;
   double distSL; double rd; double sag; double gammaRaw; double gammaVolScaled;
   double liqProx; double dVar2; double uds;
};
struct EE_VarResult { double var2; double var3; };

double ee_liqLevels[32]; int ee_liqCount=0;
double ee_w_rd=0.35, ee_w_dVar2=0.25, ee_w_gamma=0.20, ee_w_liq=0.10, ee_w_sag=0.10;
datetime ee_lastBarTime=0, ee_lastLongTrade=0, ee_lastShortTrade=0;
bool   ee_lastRiskOk=true;
// Institutional Exit Engine state (Symphony outer-band sweep tracking)
bool   ee_longOuterBreach=false, ee_shortOuterBreach=false;
double ee_lastWaveOrigin=0; int ee_lastWaveDir=0;

void ExecutionEngineInit()
{
   ee_lastBarTime=0; ee_lastLongTrade=0; ee_lastShortTrade=0; ee_lastRiskOk=true;
   ee_liqCount=0;
   ee_longOuterBreach=false; ee_shortOuterBreach=false; ee_lastWaveOrigin=0; ee_lastWaveDir=0;
}

//==================================================================
// LOT ENGINE (Symphony XAUUSD-style sizing, generalized)
//==================================================================
double EE_ComputeLots(const double riskCash,const double entry,const double sl)
{
   double dist=MathAbs(entry-sl);
   if(dist<=0.0) return(0.0);
   double riskPerLot = dist*g_cfg.contractValue;   // value per price unit per lot
   if(riskPerLot<=0.0) return(0.0);
   double lots=riskCash/riskPerLot;
   double minLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double lotStep=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(lotStep<=0) lotStep=0.01;
   lots=MathFloor(lots/lotStep)*lotStep;
   if(lots<minLot) lots=minLot;
   return(NormalizeDouble(lots,2));
}

//==================================================================
// SESSION FILTER (London + US windows, GMT baseline)
//==================================================================
bool EE_IsTradeTime()
{
   if(!g_cfg.sessionFilter) return(true);
   MqlDateTime g; TimeGMT(g);
   int hh=g.hour+g_cfg.targetGMT; if(hh<0)hh+=24; if(hh>=24)hh-=24;
   int cur=hh*60+g.min;
   bool w1=(cur>=480&&cur<=705);    // London AM
   bool w2=(cur>=705&&cur<=735);    // UK micro
   bool w3=(cur>=795&&cur<=825);    // 13:30 +-15
   bool w4=(cur>=870&&cur<=1080);   // US session
   bool k1=(cur>=480&&cur<=540);    // early London
   bool k2=(cur>=495&&cur<=525);    // 08:30 +-15
   bool k3=(cur>=885&&cur<=915);    // 15:00 +-15
   bool k4=(cur>=1005&&cur<=1035);  // 17:00 +-15
   return(w1||w2||w3||w4||k1||k2||k3||k4);
}

//==================================================================
// DRDWCT MATH
//==================================================================
double EE_LotValue(const double lots){ return(lots*g_cfg.contractValue); }
double EE_RD(const double lots,const double distSL){ return(distSL==0?1e10:lots/distSL); }
double EE_SAG(const double lots,const double distSL){ return(distSL==0?1e10:(lots*lots)/(distSL*distSL)); }
double EE_Gamma(const double entry,const double spot,const double lots){ double d=entry-spot; return(d*d*lots); }
double EE_GammaVol(const double g,const double a15,const double a30){ return(a30==0?g:g*(a15/a30)); }
double EE_LiqProx(const double sl)
{
   if(ee_liqCount<=0) return(0.0);
   double best=1e10;
   for(int i=0;i<ee_liqCount;i++){ double d=MathAbs(ee_liqLevels[i]-sl); if(d<best)best=d; }
   return(1.0/(1.0+best));
}

void EE_BuildLiquidity()
{
   // pull liquidity scenario levels from the shared liquidity pools
   ee_liqCount=0;
   FalconLiquidity lq=g_state.liquidity;
   for(int i=0;i<lq.poolCount && ee_liqCount<32;i++)
      ee_liqLevels[ee_liqCount++]=lq.pools[i];
}

//==================================================================
// VAR ENGINE (scenario based, per-position set)
//==================================================================
void EE_BuildScenarios(const EE_Market &m,double &scen[],int &sc)
{
   double sigma=m.atr30; double spot=m.spot;
   double tmp[64]; int c=0;
   tmp[c++]=spot-1*sigma; tmp[c++]=spot-2*sigma; tmp[c++]=spot-3*sigma;
   tmp[c++]=spot+1*sigma; tmp[c++]=spot+2*sigma; tmp[c++]=spot+3*sigma;
   for(int i=0;i<ee_liqCount&&c<64;i++) tmp[c++]=ee_liqLevels[i];
   sc=0;
   for(int i=0;i<c;i++)
   {
      bool ex=false;
      for(int j=0;j<sc;j++) if(MathAbs(tmp[i]-scen[j])<1e-5){ ex=true; break; }
      if(!ex){ scen[sc++]=tmp[i]; }
   }
}
double EE_ScenarioPnL(const EE_Position &pos[],const int n,const double price)
{
   double tot=0;
   for(int i=0;i<n;i++)
   {
      double move=price-pos[i].entry;
      double sm=(pos[i].direction<0?-move:move);
      tot+=sm*EE_LotValue(pos[i].lots);
   }
   return(tot);
}
void EE_ComputeVaR(const EE_Position &pos[],const int n,const EE_Market &m,EE_VarResult &out)
{
   out.var2=0; out.var3=0; if(n<=0) return;
   double scen[64]; int sc=0; EE_BuildScenarios(m,scen,sc); if(sc<=0) return;
   double sigma=m.atr30; double netLots=0;
   for(int i=0;i<n;i++){ int s=(pos[i].direction<0?-1:1); netLots+=s*pos[i].lots; }
   double target2=(netLots<0?m.spot+2*sigma:m.spot-2*sigma);
   bool wI=false,cI=false; double worst=0,closest=0,cd=0;
   for(int i=0;i<sc;i++)
   {
      double pnl=EE_ScenarioPnL(pos,n,scen[i]);
      if(!wI||pnl<worst){ worst=pnl; wI=true; }
      double d=MathAbs(scen[i]-target2);
      if(!cI||d<cd){ cd=d; closest=pnl; cI=true; }
   }
   out.var3=MathAbs(worst); out.var2=MathAbs(closest);
}

void EE_DynamicVarLimits(const double equity,double &v2,double &v3)
{
   // aggressive intraday band (Symphony profile)
   if(equity<=0){ v2=0.04; v3=0.08; return; }
   if(equity<1000){ v2=0.04; v3=0.08; }
   else if(equity<10000){ v2=0.035; v3=0.07; }
   else if(equity<100000){ v2=0.03; v3=0.06; }
   else if(equity<1000000){ v2=0.025; v3=0.05; }
   else if(equity<10000000){ v2=0.015; v3=0.03; }
   else { v2=0.01; v3=0.02; }
}

//==================================================================
// POSITION COLLECTION (grouped by direction = campaign)
//==================================================================
int EE_CollectPositions(EE_Position &out[],const int dirFilter)
{
   int c=0; int total=PositionsTotal();
   for(int i=0;i<total && c<64;i++)
   {
      ulong ticket=PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=g_cfg.magic) continue;
      long type=PositionGetInteger(POSITION_TYPE);
      int dir=(type==POSITION_TYPE_BUY?1:-1);
      if(dirFilter!=0 && dir!=dirFilter) continue;
      EE_Position p;
      p.ticket=(long)ticket;
      p.lots=PositionGetDouble(POSITION_VOLUME);
      p.entry=PositionGetDouble(POSITION_PRICE_OPEN);
      double sl=PositionGetDouble(POSITION_SL);
      p.sl=(sl>0?sl:0.0);
      p.direction=dir;
      p.pnl=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP)+PositionGetDouble(POSITION_COMMISSION);
      out[c++]=p;
   }
   return(c);
}

void EE_BuildMarket(EE_Market &m)
{
   m.spot   = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   m.equity = AccountInfoDouble(ACCOUNT_EQUITY);
   m.atr15  = FalconATR(0,1);
   m.atr30  = FalconATR(0,2);
}

//==================================================================
// ORDER HELPERS (raw MqlTradeRequest, IOC)
//==================================================================
bool EE_SendMarketOrder(const int direction,const double lots,const double sl,const string comment)
{
   if(lots<=0.0) return(false);
   if(!g_cfg.enableTrading) { FalconInfo("ExecutionEngine","trading disabled - skipped order"); return(false); }
   MqlTradeRequest req; MqlTradeResult res; ZeroMemory(req); ZeroMemory(res);
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   req.action=TRADE_ACTION_DEAL; req.symbol=_Symbol; req.magic=g_cfg.magic;
   req.volume=lots; req.sl=sl; req.tp=0.0; req.deviation=20;
   req.type_filling=ORDER_FILLING_IOC; req.type_time=ORDER_TIME_GTC; req.comment=comment;
   if(direction>0){ req.type=ORDER_TYPE_BUY; req.price=ask; }
   else           { req.type=ORDER_TYPE_SELL;req.price=bid; }
   if(!OrderSend(req,res) || (res.retcode!=TRADE_RETCODE_DONE && res.retcode!=TRADE_RETCODE_DONE_PARTIAL))
   {
      FalconPublish(EVT_ORDER_FAILED,direction,comment);
      FalconError("ExecutionEngine",StringFormat("order failed dir=%d ret=%d",direction,res.retcode));
      return(false);
   }
   FalconPublish(EVT_ORDER_SENT,direction,comment);
   return(true);
}

bool EE_ClosePartial(const ulong ticket,double lots)
{
   if(lots<=0.0) return(false);
   if(!PositionSelectByTicket(ticket)) return(false);
   if(PositionGetString(POSITION_SYMBOL)!=_Symbol) return(false);
   if(PositionGetInteger(POSITION_MAGIC)!=g_cfg.magic) return(false);
   long type=PositionGetInteger(POSITION_TYPE);
   double posLots=PositionGetDouble(POSITION_VOLUME);
   lots=NormalizeDouble(MathMin(lots,posLots),2);
   if(lots<=0) return(false);
   MqlTradeRequest req; MqlTradeResult res; ZeroMemory(req); ZeroMemory(res);
   req.action=TRADE_ACTION_DEAL; req.symbol=_Symbol; req.magic=g_cfg.magic;
   req.position=ticket; req.volume=lots; req.deviation=20;
   req.type_filling=ORDER_FILLING_IOC; req.type_time=ORDER_TIME_GTC; req.comment="FALCON TRIM";
   if(type==POSITION_TYPE_BUY){ req.type=ORDER_TYPE_SELL; req.price=SymbolInfoDouble(_Symbol,SYMBOL_BID); }
   else                       { req.type=ORDER_TYPE_BUY;  req.price=SymbolInfoDouble(_Symbol,SYMBOL_ASK); }
   if(!OrderSend(req,res) || (res.retcode!=TRADE_RETCODE_DONE && res.retcode!=TRADE_RETCODE_DONE_PARTIAL))
      return(false);
   return(true);
}
bool EE_CloseFull(const ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return(false);
   return(EE_ClosePartial(ticket,PositionGetDouble(POSITION_VOLUME)));
}

//==================================================================
// PER-CAMPAIGN RISK — evaluate one direction's GROSS book.
//   Returns true if the book is safe; trims micro-bombs in place.
//==================================================================
bool EE_RunCampaignRisk(const int dir,const EE_Market &m,double &grossLots,double &grossVaR,double &udsMax,bool &anyBomb)
{
   grossLots=0; grossVaR=0; udsMax=0; anyBomb=false;
   EE_Position pos[64];
   int n=EE_CollectPositions(pos,dir);
   if(n<=0) return(true);

   for(int i=0;i<n;i++) grossLots+=pos[i].lots;

   // metrics + micro-bomb detection
   double rdLimit=g_cfg.rdLimit;
   int worstIdx=-1; double worstUds=-1;
   for(int i=0;i<n;i++)
   {
      double sl=(pos[i].sl>0?pos[i].sl:(dir<0?m.spot+10.0:m.spot-10.0));
      double distSL=MathAbs(sl-pos[i].entry);
      double rd=EE_RD(pos[i].lots,distSL);
      double sag=EE_SAG(pos[i].lots,distSL);
      double gam=EE_GammaVol(EE_Gamma(pos[i].entry,m.spot,pos[i].lots),m.atr15,m.atr30);
      double liq=EE_LiqProx(sl);
      double uds=ee_w_rd*rd + ee_w_sag*sag*1e-4 + ee_w_gamma*gam*1e-6 + ee_w_liq*liq + ee_w_dVar2*0.0;
      if(uds>udsMax) udsMax=uds;
      if(uds>worstUds){ worstUds=uds; worstIdx=i; }
      if(rd>rdLimit) anyBomb=true;
   }

   EE_VarResult vr; EE_ComputeVaR(pos,n,m,vr);
   grossVaR=vr.var3;   // worst-case gross VaR for THIS direction

   double v2f,v3f; EE_DynamicVarLimits(m.equity,v2f,v3f);
   double v3Lim=v3f*m.equity;

   bool safe=(grossVaR<=v3Lim && !anyBomb);
   if(!safe && worstIdx>=0)
   {
      // trim the worst micro-bomb in this campaign (partial)
      double closeLots=pos[worstIdx].lots*0.4;
      if(closeLots<SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN)) closeLots=pos[worstIdx].lots;
      if(EE_ClosePartial((ulong)pos[worstIdx].ticket,closeLots))
         FalconPublish(EVT_TRIM,dir,"campaign micro-bomb trim");
   }
   return(safe);
}

//==================================================================
// EXPOSURE SNAPSHOT into shared state (used by Decision DEFEND/SCALE)
//==================================================================
void EE_UpdateExposure(const EE_Market &m)
{
   EE_Position lp[64], sp[64];
   int nl=EE_CollectPositions(lp,1);
   int ns=EE_CollectPositions(sp,-1);
   double longLots=0,shortLots=0,pnl=0;
   for(int i=0;i<nl;i++){ longLots+=lp[i].lots; pnl+=lp[i].pnl; }
   for(int i=0;i<ns;i++){ shortLots+=sp[i].lots; pnl+=sp[i].pnl; }
   g_state.exec.openLongCount=nl;
   g_state.exec.openShortCount=ns;
   g_state.exec.longGrossLots=longLots;
   g_state.exec.shortGrossLots=shortLots;
   g_state.exec.openPnL=pnl;

   // ---- TRADE STATE ----
   int ts;
   if(nl>0 && ns>0)      ts=TS_HEDGED;
   else if(nl>0)         ts=TS_LONG_OPEN;
   else if(ns>0)         ts=TS_SHORT_OPEN;
   else                  ts=TS_FLAT;
   if(ts!=TS_FLAT && g_state.exec.action==ACT_SCALE)  ts=TS_SCALING;
   if(ts!=TS_FLAT && g_state.exec.action==ACT_DEFEND) ts=TS_DEFENDING;
   g_state.exec.tradeState=ts;
}

//==================================================================
// ENTRY — translate the decision action into a sized order.
//==================================================================
void EE_HandleEntries(const EE_Market &m)
{
   int action=g_state.exec.action;
   int master=g_state.exec.master;
   datetime barTime=gTime[0];

   // Firing actions: BUY / SELL / ATTACK / SCALE all enter in the master
   // direction. ATTACK is the Senseei "take the shot" verdict (the Master Chief
   // has already vetoed it down to PREPARE if conviction was lacking).
   // PREPARE / WAIT / NO_TRADE / DEFEND / EXIT do not open new positions here.
   bool wantBuy  = ((action==ACT_BUY||action==ACT_ATTACK||action==ACT_SCALE) && master==DIR_LONG);
   bool wantSell = ((action==ACT_SELL||action==ACT_ATTACK||action==ACT_SCALE) && master==DIR_SHORT);

   if(!wantBuy && !wantSell) return;
   if(!EE_IsTradeTime()) return;
   if(g_cfg.blockIfBreach && !ee_lastRiskOk) return;

   double atr=g_state.physics.atr;
   double close1=gClose[1];
   double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   double riskCash=equity*g_cfg.riskPercent*0.01;

   if(wantBuy && ee_lastLongTrade!=barTime)
   {
      double entry=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double sl=(g_state.wave.origin!=0? g_state.wave.origin-atr*0.25 : close1-atr*1.5);
      double lots=EE_ComputeLots(riskCash,entry,sl);
      if(sl>0 && entry>sl && lots>0 && EE_SendMarketOrder(+1,lots,sl,"FALCON "+FalconActionStr(action)+" L"))
      {
         ee_lastLongTrade=barTime;
         g_state.exec.entry=entry; g_state.exec.stop=sl;
         g_state.exec.target=g_state.wave.objective; g_state.exec.lots=lots; g_state.exec.riskCash=riskCash;
         double rr=(MathAbs(entry-sl)>1e-10 && g_state.wave.objective!=0)?MathAbs(g_state.wave.objective-entry)/MathAbs(entry-sl):0.0;
         g_state.exec.reward=rr;
      }
   }
   if(wantSell && ee_lastShortTrade!=barTime)
   {
      double entry=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double sl=(g_state.wave.origin!=0? g_state.wave.origin+atr*0.25 : close1+atr*1.5);
      double lots=EE_ComputeLots(riskCash,entry,sl);
      if(sl>0 && sl>entry && lots>0 && EE_SendMarketOrder(-1,lots,sl,"FALCON "+FalconActionStr(action)+" S"))
      {
         ee_lastShortTrade=barTime;
         g_state.exec.entry=entry; g_state.exec.stop=sl;
         g_state.exec.target=g_state.wave.objective; g_state.exec.lots=lots; g_state.exec.riskCash=riskCash;
         double rr=(MathAbs(entry-sl)>1e-10 && g_state.wave.objective!=0)?MathAbs(g_state.wave.objective-entry)/MathAbs(entry-sl):0.0;
         g_state.exec.reward=rr;
      }
   }
}

//==================================================================
// INSTITUTIONAL EXIT ENGINE — track per-wave outer-band sweeps so the
// composite exit can require the institutional pattern (Symphony):
//   ARC exhaust + outer-band sweep seen + close back inside inner band
//   + phase trend-end. Reset whenever a fresh wave spawns.
//==================================================================
void EE_UpdateInstitutional()
{
   FalconWave w=g_state.wave;
   double atr=g_state.physics.atr;
   double close1=gClose[1];

   // reset on a new wave (origin or direction changed)
   if(w.origin!=ee_lastWaveOrigin || w.direction!=ee_lastWaveDir)
   {
      ee_longOuterBreach=false; ee_shortOuterBreach=false;
      ee_lastWaveOrigin=w.origin; ee_lastWaveDir=w.direction;
   }

   // inner band = inducement zone (or flip band); outer band = inner ± outerBandAtrMult
   FalconLiquidity lq=g_state.liquidity;
   double innerTopL = (lq.induceTop!=0? lq.induceTop : (w.flipTop!=0? w.flipTop:0));
   double innerBotS = (lq.induceBot!=0? lq.induceBot : (w.flipBot!=0? w.flipBot:0));

   if(w.direction==DIR_LONG && innerTopL>0)
   {
      double outerTopL=innerTopL + g_cfg.outerBandAtrMult*atr;
      if(close1>outerTopL) ee_longOuterBreach=true;
   }
   if(w.direction==DIR_SHORT && innerBotS>0)
   {
      double outerBotS=innerBotS - g_cfg.outerBandAtrMult*atr;
      if(close1<outerBotS) ee_shortOuterBreach=true;
   }
}

//==================================================================
// EXITS — ARC + institutional + phase composite + decision EXIT/DEFEND
//==================================================================
void EE_HandleExits()
{
   int action=g_state.exec.action;
   FalconWave w=g_state.wave;
   FalconConvexity cv=g_state.convexity;
   double atr=g_state.physics.atr;
   double close1=gClose[1];

   bool exitLong=false, exitShort=false;
   int  exitReason=XS_NONE;

   // ARC exhaustion (Symphony)
   bool arcExhaustLong  = (w.direction==DIR_LONG  && cv.arcLong>0.0  && close1>=(cv.arcLong - g_cfg.arcToleranceAtr*atr));
   bool arcExhaustShort = (w.direction==DIR_SHORT && cv.arcShort>0.0 && close1<=(cv.arcShort+ g_cfg.arcToleranceAtr*atr));
   bool phaseEndLong  = (w.prevPhase>=PH_NEW_HIGH && w.phase<=PH_EXP_PRECONVEXITY && w.direction==DIR_LONG);
   bool phaseEndShort = (w.prevPhase>=PH_NEW_HIGH && w.phase<=PH_EXP_PRECONVEXITY && w.direction==DIR_SHORT);

   if(arcExhaustLong && phaseEndLong)  { exitLong=true;  exitReason=XS_ARC_EXHAUST; }
   if(arcExhaustShort&& phaseEndShort) { exitShort=true; exitReason=XS_ARC_EXHAUST; }

   // INSTITUTIONAL pattern gate: if an inner band exists, require the outer-band
   // sweep to have occurred AND price to have closed back inside it (Symphony).
   FalconLiquidity lq=g_state.liquidity;
   double innerTopL = (lq.induceTop!=0? lq.induceTop : w.flipTop);
   double innerBotS = (lq.induceBot!=0? lq.induceBot : w.flipBot);
   if(exitLong && innerTopL>0)
   {
      bool instOK = (ee_longOuterBreach && close1<innerTopL);
      if(!instOK) exitLong=false;   // not yet an institutional reversal
   }
   if(exitShort && innerBotS>0)
   {
      bool instOK = (ee_shortOuterBreach && close1>innerBotS);
      if(!instOK) exitShort=false;
   }

   // resolution complete -> exit the resolved side
   if(g_state.intel.resolutionState==RES_RESOLVED)
   {
      if(w.direction==DIR_LONG)  { exitLong=true;  exitReason=XS_RESOLUTION; }
      if(w.direction==DIR_SHORT) { exitShort=true; exitReason=XS_RESOLUTION; }
   }

   // explicit decision EXIT closes the master side; DEFEND closes the losing side
   if(action==ACT_EXIT)
   {
      if(g_state.exec.master==DIR_LONG)  { exitLong=true;  exitReason=XS_DECISION_EXIT; }
      if(g_state.exec.master==DIR_SHORT) { exitShort=true; exitReason=XS_DECISION_EXIT; }
   }
   if(action==ACT_DEFEND)
   {
      // defend = close the side fighting against the failure-swing risk
      if(g_state.intel.failureSwingProb>=0.70)
      {
         if(w.direction==DIR_LONG)  { exitLong=true;  exitReason=XS_DEFEND; }   // long wave failing -> protect longs
         if(w.direction==DIR_SHORT) { exitShort=true; exitReason=XS_DEFEND; }
      }
   }

   // CAMPAIGN INVALIDATION (direction-agnostic, per the multi-campaign rule):
   // a confirmed structural flip kills the opposite campaign's thesis. A bullish
   // CHoCH invalidates open SHORTS; a bearish CHoCH invalidates open LONGS. This
   // closes a bleeding book the moment the move that justified it is broken,
   // instead of orphaning it after the master direction flips.
   if(g_state.structure.choch==DIR_LONG  && g_state.exec.openShortCount>0){ exitShort=true; exitReason=XS_DEFEND; }
   if(g_state.structure.choch==DIR_SHORT && g_state.exec.openLongCount>0 ){ exitLong=true;  exitReason=XS_DEFEND; }

   if(!exitLong && !exitShort) return;
   g_state.exec.exitState=exitReason;

   int total=PositionsTotal();
   for(int i=total-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=g_cfg.magic) continue;
      long type=PositionGetInteger(POSITION_TYPE);
      if(exitLong && type==POSITION_TYPE_BUY)  { if(EE_CloseFull(ticket)) FalconPublish(EVT_EXIT_FIRED,1); }
      if(exitShort&& type==POSITION_TYPE_SELL) { if(EE_CloseFull(ticket)) FalconPublish(EVT_EXIT_FIRED,-1); }
   }
}

//==================================================================
// TRAILING ENGINE — once a position is in profit beyond trailStartATR,
// trail its stop at trailDistATR behind price (direction-aware).
//==================================================================
bool EE_ModifySL(const ulong ticket,const double newSL)
{
   if(!PositionSelectByTicket(ticket)) return(false);
   MqlTradeRequest req; MqlTradeResult res; ZeroMemory(req); ZeroMemory(res);
   req.action  = TRADE_ACTION_SLTP;
   req.symbol  = _Symbol;
   req.magic   = g_cfg.magic;
   req.position= ticket;
   req.sl      = NormalizeDouble(newSL,_Digits);
   req.tp      = PositionGetDouble(POSITION_TP);
   if(!OrderSend(req,res)) return(false);
   return(res.retcode==TRADE_RETCODE_DONE);
}

void EE_Trailing()
{
   if(!g_cfg.trailEnable) return;
   double atr=g_state.physics.atr;
   if(atr<=0) return;
   double startDist=atr*g_cfg.trailStartATR;
   double trailDist=atr*g_cfg.trailDistATR;
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);

   int total=PositionsTotal();
   for(int i=0;i<total;i++)
   {
      ulong ticket=PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=g_cfg.magic) continue;
      long type=PositionGetInteger(POSITION_TYPE);
      double entry=PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   =PositionGetDouble(POSITION_SL);

      if(type==POSITION_TYPE_BUY)
      {
         double profit=bid-entry;
         if(profit>startDist)
         {
            double newSL=bid-trailDist;
            if(newSL>entry && (sl==0 || newSL>sl)) { if(EE_ModifySL(ticket,newSL)) g_state.exec.exitState=XS_TRAIL_STOP; }
         }
      }
      else // SELL
      {
         double profit=entry-ask;
         if(profit>startDist)
         {
            double newSL=ask+trailDist;
            if(newSL<entry && (sl==0 || newSL<sl)) { if(EE_ModifySL(ticket,newSL)) g_state.exec.exitState=XS_TRAIL_STOP; }
         }
      }
   }
}

//==================================================================
// DRAWDOWN PROTECTION — uses the persistence layer's equity-peak /
// drawdown tracker. Blocks new entries above maxDrawdownPct and
// flattens ALL exposure above ddFlattenPct. Returns true if entries
// are allowed.
//==================================================================
bool EE_DrawdownProtection()
{
   if(!g_cfg.ddProtect) return(true);
   double ddPct = g_perf.maxDrawdownPct;          // rolling peak-to-trough %
   // live drawdown from current equity vs peak (more responsive than the max)
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   double liveDD=(g_perf.peakEquity>0 ? (g_perf.peakEquity-eq)/g_perf.peakEquity*100.0 : 0.0);
   double worst=MathMax(ddPct,liveDD);

   if(worst>=g_cfg.ddFlattenPct)
   {
      // hard protection: flatten everything
      int total=PositionsTotal();
      for(int i=total-1;i>=0;i--)
      {
         ulong ticket=PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
         if(PositionGetInteger(POSITION_MAGIC)!=g_cfg.magic) continue;
         EE_CloseFull(ticket);
      }
      FalconPublish(EVT_RISK_BREACH, worst, "drawdown flatten");
      g_state.exec.exitState=XS_DD_FLATTEN;
      return(false);
   }
   if(worst>=g_cfg.maxDrawdownPct)
   {
      FalconPublish(EVT_RISK_BREACH, worst, "drawdown block");
      return(false);   // block new entries, keep managing existing
   }
   return(true);
}

//==================================================================
// MASTER ENTRY — Execution Engine pipeline step
//==================================================================
void ExecutionEngineRun()
{
   EE_Market m; EE_BuildMarket(m);
   EE_BuildLiquidity();
   EE_UpdateExposure(m);

   // ---- PER-CAMPAIGN RISK (multi-direction, gross, never netted) ----
   bool longOk=true, shortOk=true;
   double lLots=0,sLots=0,lVaR=0,sVaR=0,lUds=0,sUds=0; bool lBomb=false,sBomb=false;
   if(g_cfg.enableRiskEng)
   {
      longOk  = EE_RunCampaignRisk( 1,m,lLots,lVaR,lUds,lBomb);
      shortOk = EE_RunCampaignRisk(-1,m,sLots,sVaR,sUds,sBomb);
   }
   g_state.exec.longGrossVaR=lVaR;
   g_state.exec.shortGrossVaR=sVaR;
   g_state.exec.udsMax=MathMax(lUds,sUds);
   g_state.exec.anyBomb=(lBomb||sBomb);

   // ---- PORTFOLIO BACKSTOP on COMBINED GROSS VaR ----
   double v2f,v3f; EE_DynamicVarLimits(m.equity,v2f,v3f);
   g_state.exec.var2Limit=v2f*m.equity;
   g_state.exec.var3Limit=v3f*m.equity;
   double combinedGrossVaR=lVaR+sVaR;   // GROSS sum, not net
   g_state.exec.var3=combinedGrossVaR;
   bool portfolioOk=(combinedGrossVaR <= g_state.exec.var3Limit*1.5);

   // ---- DRAWDOWN PROTECTION (may flatten / block) ----
   bool ddOk = EE_DrawdownProtection();

   ee_lastRiskOk=(longOk && shortOk && portfolioOk && ddOk);
   g_state.exec.riskOk=ee_lastRiskOk;
   g_state.exec.sessionOpen=EE_IsTradeTime();
   if(!ee_lastRiskOk) FalconPublish(EVT_RISK_BREACH,combinedGrossVaR);

   // ---- TRAILING (manage open winners) ----
   EE_Trailing();

   // ---- INSTITUTIONAL band tracking, then EXITS, then ENTRIES ----
   EE_UpdateInstitutional();
   EE_HandleExits();
   EE_HandleEntries(m);

   // refresh exposure snapshot after actions
   EE_UpdateExposure(m);
}

#endif // FALCON_EXEC_ENGINE_MQH
//+------------------------------------------------------------------+

//  ===== Engines/Visualization.mqh =====
//+------------------------------------------------------------------+
//|  FALCON OS — Visualization Layer : Visualization.mqh           |
//|                                                                  |
//|  ONE interface. Replaces every legacy dashboard (LETRA A/B/C/P3/ |
//|  FU, F16 Readout/Strategist/Copilot/Matrix/Campaign/Curve, ...). |
//|  A single chart panel with selectable tabs, all reading the one  |
//|  shared MarketState. No duplicated dashboards anywhere.          |
//|                                                                  |
//|  Tabs: Overview · Physics · Structure · Network · Curve ·        |
//|        Campaign · Wave · HTF · Risk · Execution · Performance ·  |
//|        Diagnostics                                               |
//+------------------------------------------------------------------+
#ifndef FALCON_VIZ_MQH
#define FALCON_VIZ_MQH


#define VIZ_OBJ "FALCON_DASH"

string VZ_Pct(const double v){ return(DoubleToString(v,0)+"%"); }
string VZ_Px(const double v){ return(v==0?"—":DoubleToString(v,_Digits)); }
string VZ_Dir(const int d){ return(d==DIR_LONG?"BULL":d==DIR_SHORT?"BEAR":"—"); }

string VZ_TabName(const int t)
{
   switch(t)
   {
      case 0: return("OVERVIEW");
      case 1: return("PHYSICS");
      case 2: return("STRUCTURE");
      case 3: return("NETWORK");
      case 4: return("CURVE");
      case 5: return("CAMPAIGN");
      case 6: return("WAVE");
      case 7: return("HTF");
      case 8: return("RISK");
      case 9: return("EXECUTION");
      case 10:return("PERFORMANCE");
      default:return("DIAGNOSTICS");
   }
}

//------------------------------------------------------------------
// Compose the body text for the selected tab from shared state.
//------------------------------------------------------------------
string VZ_Body(const int tab)
{
   string s="";
   FalconPhysics  ph=g_state.physics;
   FalconStructure st=g_state.structure;
   FalconLiquidity lq=g_state.liquidity;
   FalconConvexity cv=g_state.convexity;
   FalconWave     w =g_state.wave;
   FalconHTF      h =g_state.htf;
   FalconNetwork  n =g_state.network;
   FalconCurve    cu=g_state.curve;
   FalconCampaign cm=g_state.campaign;
   FalconParticipants pa=g_state.participants;
   FalconIntelligence x=g_state.intel;
   FalconExecution e=g_state.exec;
   FalconOrderBlocks ob=g_state.orderBlocks;
   FalconSupplyDemand sd=g_state.supplyDemand;
   FalconWaveMatrix wmx=g_state.waveMatrix;
   FalconFEZ fez=g_state.fez;
   FalconFRZ frz=g_state.frz;
   FalconFU  fuv=g_state.fu;

   switch(tab)
   {
      case 0: // OVERVIEW
         s+="Action      : "+FalconActionStr(e.action)+"   ("+VZ_Dir(e.master)+")\n";
         s+="Phase       : "+FalconPhaseStr(w.phase)+"  "+VZ_Pct(w.completion)+"\n";
         s+="Intent      : "+x.intent+"   Timing "+x.timing+"\n";
         s+="Hypothesis  : "+x.hypothesis+"  ("+DoubleToString(x.hypothesisProb*100.0,0)+"%)\n";
         s+="Prediction  : "+x.prediction+"\n";
         s+="Validation  : "+(x.validated?"confirming":"pending")+"  ("+DoubleToString(x.validationScore,0)+"% hit)\n";
         s+="Confidence  : "+DoubleToString(x.confidence,0)+"   Threat "+DoubleToString(x.threat,0)+"\n";
         s+="Opportunity : "+x.opportunityGrade+"  ("+DoubleToString(x.opportunity,0)+")\n";
         s+="Exec Prob   : "+DoubleToString(x.executionProbability*100.0,0)+"%   Resolution "+FalconResStr(x.resolutionState)+"\n";
         s+="Master Chief: "+(x.masterChiefConfirm?"CLEARED":"HOLD")+"  ("+DoubleToString(x.masterChiefScore,0)+")  "+x.masterChiefNote+"\n";
         s+="Story       : "+x.story;
         break;
      case 1: // PHYSICS
         s+="ATR         : "+DoubleToString(ph.atr,_Digits)+"   Vol "+DoubleToString(ph.volatility,2)+"\n";
         s+="Velocity    : "+DoubleToString(ph.velocity,_Digits)+"\n";
         s+="Accel       : "+DoubleToString(ph.acceleration,_Digits)+"\n";
         s+="Convexity   : "+DoubleToString(ph.convexitySmooth,_Digits)+"\n";
         s+="Efficiency  : "+DoubleToString(ph.efficiency,2)+"   Disp "+DoubleToString(ph.displacement,2)+"\n";
         s+="Energy      : "+DoubleToString(ph.energy,0)+"   Compr "+DoubleToString(ph.compression,0)+"   Exp "+DoubleToString(ph.expansion,0)+"\n";
         s+="Impulse     : "+(ph.bullImpulse?"BULL":ph.bearImpulse?"BEAR":"—")+"   Decay "+(ph.bullDecay||ph.bearDecay?"yes":"no");
         break;
      case 2: // STRUCTURE
         s+="Trend       : "+VZ_Dir(st.trend)+"\n";
         s+="Swing Hi/Lo : "+VZ_Px(st.swingHigh)+" / "+VZ_Px(st.swingLow)+"\n";
         s+="HH/HL/LH/LL : "+(st.hh?"HH ":"")+(st.hl?"HL ":"")+(st.lh?"LH ":"")+(st.ll?"LL":"")+"\n";
         s+="BOS / CHoCH : "+VZ_Dir(st.bos)+" / "+VZ_Dir(st.choch)+"\n";
         s+="Break Str   : "+DoubleToString(st.breakStrength,2)+" ATR\n";
         s+="Order Block : "+(ob.activeDir!=DIR_NONE?VZ_Px(ob.activeBot)+"-"+VZ_Px(ob.activeTop)+" "+VZ_Dir(ob.activeDir)+" str "+DoubleToString(ob.activeStrength,0):"—")+"\n";
         s+="Supply/Dmd  : "+(sd.activeZone==DIR_LONG?"IN DEMAND":sd.activeZone==DIR_SHORT?"IN SUPPLY":"—")
            +"  D "+DoubleToString(sd.demandStrength,0)+" / S "+DoubleToString(sd.supplyStrength,0)+"\n";
         s+="Inducement  : "+(lq.induceActive?VZ_Px(lq.inducePrice)+(lq.induceSwept?" SWEPT":" armed"):"—")+"\n";
         s+="Liquidity   : heat "+DoubleToString(lq.score,0)+"  pressure "+DoubleToString(lq.pressure,0)+(lq.vacuum?"  VACUUM":"");
         break;
      case 3: // NETWORK
         s+="Nodes       : "+IntegerToString(n.count)+"  ("+IntegerToString(n.liveCount)+" live)\n";
         s+="Bias        : "+VZ_Dir(n.bias)+"\n";
         s+="Pressure    : "+DoubleToString(n.pressure,0)+"  ("+VZ_Dir(n.pressureDir)+")\n";
         s+="Bull Auth   : "+DoubleToString(n.bullAuthority,0)+"\n";
         s+="Bear Auth   : "+DoubleToString(n.bearAuthority,0)+"\n";
         s+="Conversation: "+IntegerToString(n.connections)+" edges  weight "+DoubleToString(n.conversationWeight,0)+"\n";
         if(n.nearestAttractorIdx>=0 && n.nearestAttractorIdx<n.count)
            s+="Attractor   : "+VZ_Px(n.px[n.nearestAttractorIdx])+"  "+VZ_Dir(n.dir[n.nearestAttractorIdx]);
         break;
      case 4: // CURVE
         s+="Owner Dir   : "+VZ_Dir(cu.ownerDir)+"   ownerTF idx "+IntegerToString(cu.ownerTF)+"\n";
         s+="Root        : "+VZ_Px(cu.rootOrigin)+" -> "+VZ_Px(cu.rootExtreme)+"  "+VZ_Dir(cu.rootDir)+"\n";
         s+="Parent      : "+VZ_Px(cu.parentOrigin)+" -> "+VZ_Px(cu.parentExtreme)+"  "+VZ_Dir(cu.parentDir)+"\n";
         s+="Life/Energy : "+DoubleToString(cu.life,0)+" / "+DoubleToString(cu.energy,0)+"\n";
         s+="Evolution   : "+DoubleToString(cu.evolution,0)+"%   emergent nodes "+IntegerToString(cu.emergentNodes)+"\n";
         s+="Wave Matrix : dom TF "+IntegerToString(wmx.dominantTF)+" "+VZ_Dir(wmx.dominantDir)
            +"  agree "+DoubleToString(wmx.agreement,0)+"%  E "+DoubleToString(wmx.matrixEnergy,0)+"\n";
         s+="Emergent    : "+FalconPhaseStr(cu.emergentPhase);
         break;
      case 5: // CAMPAIGN
         s+="Owner       : "+VZ_Dir(cm.owner)+"  ("+cm.institution+")\n";
         s+="Control     : "+DoubleToString(cm.controlScore,0)+"%\n";
         s+="Objective   : "+VZ_Dir(cm.objectiveDir)+"\n";
         s+="Remaining E : "+DoubleToString(cm.remainingEnergy,0)+"\n";
         s+="Age         : "+IntegerToString(cm.age)+" bars\n";
         s+="Participants: buy "+DoubleToString(pa.buyer,0)+"  sell "+DoubleToString(pa.seller,0)+"  press "+DoubleToString(pa.marketPressure,0);
         break;
      case 6: // WAVE
         s+="Direction   : "+VZ_Dir(w.direction)+"\n";
         s+="Phase       : "+FalconPhaseStr(w.phase)+"  ("+VZ_Pct(w.completion)+")\n";
         s+="Origin/Ext  : "+VZ_Px(w.origin)+" / "+VZ_Px(w.extreme)+"   Obj "+VZ_Px(w.objective)+"\n";
         s+="Flip Zone   : "+VZ_Px(w.flipBot)+" - "+VZ_Px(w.flipTop)+"\n";
         s+="Sub-scores  : Exp "+DoubleToString(w.expansionScore,0)+" PreCvx "+DoubleToString(w.preConvexityScore,0)
            +" Cvx "+DoubleToString(w.convexityScore,0)+" Ind "+DoubleToString(w.inductionScore,0)+"\n";
         s+="            : Liq "+DoubleToString(w.liquidationScore,0)+" Abs "+DoubleToString(w.absorptionScore,0)
            +" Retr "+DoubleToString(w.retracementScore,0)+"\n";
         s+="FEZ         : "+(fez.active?VZ_Px(fez.bot)+"-"+VZ_Px(fez.top)+" "+VZ_Dir(fez.dir)+" "+DoubleToString(fez.distanceATR,1)+"ATR":"—")+"\n";
         s+="FRZ (return): "+(frz.active?VZ_Px(frz.targetPrice)+" "+VZ_Dir(frz.dir)+" ownerTF "+IntegerToString(frz.ownerTF):"—")+"\n";
         s+="Recursion   : breaks "+IntegerToString(w.recursionBreaks)+"  transfer "+DoubleToString(w.dominanceTransfer,0)+"%";
         break;
      case 7: // HTF
         s+="M1  "+VZ_Dir(h.dir[0])+"   M5  "+VZ_Dir(h.dir[1])+"\n";
         s+="M15 "+VZ_Dir(h.dir[2])+"   M30 "+VZ_Dir(h.dir[3])+"\n";
         s+="H1  "+VZ_Dir(h.dir[4])+"   H4  "+VZ_Dir(h.dir[5])+"\n";
         s+="Stack Dir   : "+VZ_Dir(h.stackDir)+"\n";
         s+="Alignment   : "+DoubleToString(h.alignment,0)+"%   Conflict "+DoubleToString(h.conflict,0)+"%\n";
         s+="Owner TF idx: "+IntegerToString(h.ownerTF)+"   Fractal "+(h.fractalAgreement?"AGREE":"split")+"\n";
         s+="FU Candle   : "+(fuv.active?VZ_Dir(fuv.dir)+" zone "+VZ_Px(fuv.zoneBot)+"-"+VZ_Px(fuv.zoneTop)+"  conf "+DoubleToString(fuv.confidence,0)+"  life "+IntegerToString(fuv.lifecycle):"none");
         break;
      case 8: // RISK
         s+="Risk OK     : "+(e.riskOk?"YES":"NO")+"\n";
         s+="VaR3 / lim  : "+DoubleToString(e.var3,0)+" / "+DoubleToString(e.var3Limit,0)+"\n";
         s+="Long  gross : "+DoubleToString(e.longGrossLots,2)+" lots  VaR "+DoubleToString(e.longGrossVaR,0)+"\n";
         s+="Short gross : "+DoubleToString(e.shortGrossLots,2)+" lots  VaR "+DoubleToString(e.shortGrossVaR,0)+"\n";
         s+="UDS max     : "+DoubleToString(e.udsMax,2)+"   Bomb "+(e.anyBomb?"YES":"no")+"\n";
         s+="Failure swg : "+DoubleToString(x.failureSwingProb*100.0,0)+"%   Loops left "+DoubleToString(x.expectedLoopsRemaining,1);
         break;
      case 9: // EXECUTION
         s+="Action      : "+FalconActionStr(e.action)+"\n";
         s+="Trade State : "+FalconTradeStateStr(e.tradeState)+"   Last exit "+FalconExitStateStr(e.exitState)+"\n";
         s+="Entry/Stop  : "+VZ_Px(e.entry)+" / "+VZ_Px(e.stop)+"\n";
         s+="Target      : "+VZ_Px(e.target)+"   R:R "+DoubleToString(e.reward,2)+"\n";
         s+="Lots        : "+DoubleToString(e.lots,2)+"   Risk $ "+DoubleToString(e.riskCash,0)+"\n";
         s+="Open L/S    : "+IntegerToString(e.openLongCount)+" / "+IntegerToString(e.openShortCount)+"\n";
         s+="Open PnL    : "+DoubleToString(e.openPnL,2)+"\n";
         s+="Session     : "+(e.sessionOpen?"OPEN":"closed");
         break;
      case 10: // PERFORMANCE
         s+="Open PnL    : "+DoubleToString(e.openPnL,2)+"\n";
         s+="Equity      : "+DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY),2)+"\n";
         s+="Peak equity : "+DoubleToString(g_perf.peakEquity,2)+"\n";
         s+="Max DD      : "+DoubleToString(g_perf.maxDrawdown,2)+"  ("+DoubleToString(g_perf.maxDrawdownPct,1)+"%)\n";
         s+="Trades W/L  : "+IntegerToString(g_perf.wins)+" / "+IntegerToString(g_perf.losses)+"\n";
         s+="Margin free : "+DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_FREE),2)+"\n";
         s+="Pipeline    : "+IntegerToString((int)g_diag.pipelineRuns)+" runs  "+DoubleToString((double)g_diag.pipelineMicros,0)+"us last";
         break;
      default: // DIAGNOSTICS
         for(int m=0;m<MOD_COUNT;m++)
            s+=StringFormat("%-14s %s  avg %.0fus  runs %d\n",
               FalconModuleName(m), g_diag.health[m].ok?"OK ":"ERR",
               FalconAvgMicros(m), g_diag.health[m].runs);
         s+=StringFormat("Events: bar %d impulse %d/%d bos %d choch %d spawn %d verdict %d orders %d",
             FalconEventCount(EVT_NEW_BAR),FalconEventCount(EVT_IMPULSE_BULL),FalconEventCount(EVT_IMPULSE_BEAR),
             FalconEventCount(EVT_BOS),FalconEventCount(EVT_CHOCH),FalconEventCount(EVT_WAVE_SPAWN),
             FalconEventCount(EVT_VERDICT_CHANGE),FalconEventCount(EVT_ORDER_SENT));
         break;
   }
   return(s);
}

//------------------------------------------------------------------
// Render the panel as a single multiline chart label.
//------------------------------------------------------------------
//------------------------------------------------------------------
// FLIGHT HUD — plot the live flight plan as horizontal levels on the
// chart: entry · stop · target · flip-top · flip-bot · inducement.
// Replaces F16's HUD; reads only shared state.
//------------------------------------------------------------------
void VZ_HLine(const string tag,const double price,const color col,const int style)
{
   if(price<=0){ ObjectDelete(0,tag); return; }
   if(ObjectFind(0,tag)<0)
   {
      ObjectCreate(0,tag,OBJ_HLINE,0,0,price);
      ObjectSetInteger(0,tag,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,tag,OBJPROP_BACK,true);
      ObjectSetInteger(0,tag,OBJPROP_WIDTH,1);
   }
   ObjectSetInteger(0,tag,OBJPROP_COLOR,col);
   ObjectSetInteger(0,tag,OBJPROP_STYLE,style);
   ObjectSetDouble (0,tag,OBJPROP_PRICE,price);
}

void VZ_FlightHUD()
{
   if(!g_cfg.showHUD)
   {
      ObjectDelete(0,VIZ_OBJ+"_entry"); ObjectDelete(0,VIZ_OBJ+"_stop");
      ObjectDelete(0,VIZ_OBJ+"_tgt");   ObjectDelete(0,VIZ_OBJ+"_ftop");
      ObjectDelete(0,VIZ_OBJ+"_fbot");  ObjectDelete(0,VIZ_OBJ+"_induc");
      return;
   }
   FalconWave w=g_state.wave;
   FalconExecution e=g_state.exec;
   FalconLiquidity lq=g_state.liquidity;

   VZ_HLine(VIZ_OBJ+"_entry", e.entry,        clrDeepSkyBlue, STYLE_SOLID);
   VZ_HLine(VIZ_OBJ+"_stop",  e.stop,         clrTomato,      STYLE_DOT);
   VZ_HLine(VIZ_OBJ+"_tgt",   e.target,       clrLime,        STYLE_DASH);
   VZ_HLine(VIZ_OBJ+"_ftop",  w.flipTop,      clrDimGray,     STYLE_DOT);
   VZ_HLine(VIZ_OBJ+"_fbot",  w.flipBot,      clrDimGray,     STYLE_DOT);
   VZ_HLine(VIZ_OBJ+"_induc", lq.inducePrice, clrGold,        STYLE_DASHDOT);
}

void VisualizationRun()
{
   VZ_FlightHUD();   // self-cleans when disabled
   if(!g_cfg.showDashboard) return;

   int tab=g_cfg.dashboardTab;
   string header="◤ FALCON OS ▌ "+VZ_TabName(tab)
                 +"   "+FalconActionStr(g_state.exec.action)
                 +"  ["+VZ_Dir(g_state.exec.master)+"]";
   // Tabs hint so the user knows how to switch views via the input.
   string tabs="Tabs: 0 Ovr·1 Phys·2 Struct·3 Net·4 Curve·5 Camp·6 Wave·7 HTF·8 Risk·9 Exec·10 Perf·11 Diag";

   string txt=header+"\n"
              +"────────────────────────────\n"
              +VZ_Body(tab)+"\n"
              +"────────────────────────────\n"
              +tabs;

   // Comment() is the single, reliable multiline render surface in MT5.
   Comment(txt);
}

void VisualizationDeinit()
{
   Comment("");
   ObjectDelete(0,VIZ_OBJ);
   ObjectDelete(0,VIZ_OBJ+"_entry"); ObjectDelete(0,VIZ_OBJ+"_stop");
   ObjectDelete(0,VIZ_OBJ+"_tgt");   ObjectDelete(0,VIZ_OBJ+"_ftop");
   ObjectDelete(0,VIZ_OBJ+"_fbot");  ObjectDelete(0,VIZ_OBJ+"_induc");
}

#endif // FALCON_VIZ_MQH
//+------------------------------------------------------------------+

//  ===== FalconOS.mq5 =====
//+------------------------------------------------------------------+
//|                                                      FalconOS.mq5 |
//|   FALCON OS — Unified Trading Intelligence Platform              |
//|                                                                  |
//|   A single modular operating system merging:                    |
//|     • LETRA 37   — Market Intelligence  (Market Layer)          |
//|     • F16 Raptor — Strategic Intelligence (Memory + Decision)   |
//|     • Symphony   — Execution & Risk      (Execution Layer)      |
//|                                                                  |
//|   Architecture:  KERNEL (shared state · event bus · scheduler · |
//|   config · logging) drives six engines through ONE deterministic |
//|   pipeline. Every calculation exists exactly once. Every module  |
//|   consumes the single shared MarketState.                        |
//|                                                                  |
//|        Market observes → Memory remembers → Intelligence reasons |
//|        → Decision decides → Execution executes → Viz displays    |
//+------------------------------------------------------------------+

//==================================================================
// KERNEL
//==================================================================

//==================================================================
// ENGINES (layers)
//==================================================================

//==================================================================
// SCHEDULER — the single deterministic master pipeline.
//   Runs once per confirmed bar, in the exact spec order. Nothing
//   calculates twice; every step reads/writes the shared state.
//==================================================================
void FalconPipeline()
{
   ulong t0;
   FalconPublish(EVT_NEW_BAR, (double)g_barCounter);

   // refresh bar context in shared state
   g_state.barTime = gTime[0];
   g_state.barIndex= g_barCounter;
   g_state.close   = gClose[1];
   g_state.high    = gHigh[1];
   g_state.low     = gLow[1];
   g_state.open    = gOpen[1];
   g_state.bid     = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   g_state.ask     = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   g_state.spot    = g_state.bid;
   g_state.equity  = AccountInfoDouble(ACCOUNT_EQUITY);

   ulong pipeStart = GetMicrosecondCount();

   // ── MARKET LAYER ──────────────────────────────────────────────
   // Physics → Structure → Liquidity → Convexity → Wave → FU →
   // OrderBlocks → Supply/Demand → HTF   (observes reality)
   FalconModuleStart(MOD_MARKET,t0);
   MarketEngineRun();
   FalconModuleEnd(MOD_MARKET,t0);

   // ── MEMORY LAYER ──────────────────────────────────────────────
   // Network → Curve Tree → Wave Matrix → FEZ → FRZ → Campaign →
   // Participants   (remembers)
   FalconModuleStart(MOD_MEMORY,t0);
   MemoryEngineRun();
   FalconModuleEnd(MOD_MEMORY,t0);

   // ── INTELLIGENCE LAYER ────────────────────────────────────────
   // Energy Resolution → Belief → Forecast → Hypothesis →
   // Prediction → Validation → Opportunity/Threat/Intent → Story
   // (reasons)
   FalconModuleStart(MOD_INTEL,t0);
   IntelligenceEngineRun();
   FalconModuleEnd(MOD_INTEL,t0);

   // ── DECISION LAYER ────────────────────────────────────────────
   // Senseei → Chief Strategist → Campaign AI → single verdict
   FalconModuleStart(MOD_DECISION,t0);
   DecisionEngineRun();
   FalconModuleEnd(MOD_DECISION,t0);

   // ── EXECUTION LAYER ───────────────────────────────────────────
   // Risk (per-campaign VaR/UDS/gamma) → Drawdown Protection →
   // Trailing → Exits → Entries   (never decides, only executes)
   FalconModuleStart(MOD_EXEC,t0);
   ExecutionEngineRun();
   FalconModuleEnd(MOD_EXEC,t0);

   // ── PERSISTENCE ───────────────────────────────────────────────
   // Track equity/drawdown every bar; autosave network/campaign/perf
   FalconPersistenceTick();

   // ── VISUALIZATION LAYER ───────────────────────────────────────
   FalconModuleStart(MOD_VIZ,t0);
   VisualizationRun();
   FalconModuleEnd(MOD_VIZ,t0);

   g_diag.pipelineMicros = GetMicrosecondCount() - pipeStart;
   g_diag.pipelineRuns++;
}

//==================================================================
// LIFECYCLE
//==================================================================
int OnInit()
{
   // KERNEL boot
   FalconConfigInit();
   FalconBusInit();
   FalconLogInit();

   // zero the shared state
   ZeroMemory(g_state);

   // ENGINE boot
   MarketEngineInit();
   MemoryEngineInit();
   IntelligenceEngineInit();
   DecisionEngineInit();
   ExecutionEngineInit();
   FalconPersistenceInit();

   if(!FalconRefreshSeries())
   {
      FalconError("Kernel","initial series refresh failed");
      return(INIT_FAILED);
   }

   FalconLog("INFO","Kernel",
      StringFormat("FALCON OS booted — profile=%d magic=%d trading=%s riskEng=%s",
        g_cfg.profile, (int)g_cfg.magic,
        g_cfg.enableTrading?"on":"off", g_cfg.enableRiskEng?"on":"off"));
   PrintFormat("[FALCON] Unified Trading Intelligence Platform online. 6 engines · 1 shared state · deterministic pipeline.");
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   FalconPersistenceFlush();
   VisualizationDeinit();
   FalconReleaseHandles();
   PrintFormat("[FALCON] OS shutdown (reason %d). Pipeline runs: %d", reason, g_diag.pipelineRuns);
}

void OnTick()
{
   if(!FalconRefreshSeries()) return;
   if(!FalconIsNewBar())      return;   // pipeline is bar-deterministic
   if(FalconBars() < (2*g_cfg.structLen + 40)) return;

   FalconPipeline();
}
//+------------------------------------------------------------------+
