//+------------------------------------------------------------------+
//|                                            FalconOS_AllInOne.mq5 |
//|   FALCON OS — Unified Trading Intelligence Platform               |
//|   SINGLE-FILE BUILD (all kernel + engines concatenated)          |
//|   Risk: PYRO thermal + TALON curve-convergent structural grip.   |
//+------------------------------------------------------------------+
#property copyright "FALCON OS"
#property version   "3.30"
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
input double  InpRetrMin        = 0.30;  // Symphony: min retracement fraction (phase)
input double  InpRetrMax        = 0.80;  // Symphony: max retracement fraction (phase)
input bool    InpUseSymphony    = true;  // Use Symphony Phase 3/4 engine for entries+exits
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
input double  InpMaxLots        = 1.0;   // Hard cap on lots per entry (safety)
input bool    InpBlockIfBreach  = true;  // Block new entries after a risk breach (cooldown)
input bool    InpSessionFilter  = false; // Restrict to London/US windows (off for full backtests)
input double  InpContractValue  = 100.0; // Value per lot per price unit
input bool    InpTrailEnable    = true;  // Enable trailing stop engine
input double  InpTrailStartATR  = 1.0;   // Start trailing after profit (ATR)
input double  InpTrailDistATR   = 1.5;   // Trailing distance (ATR)
input bool    InpDDProtect      = true;  // Enable drawdown protection
input double  InpMaxDrawdownPct = 12.0;  // Block entries above this drawdown %
input double  InpDDFlattenPct   = 20.0;  // Flatten everything above this drawdown %
input double  InpMaxEntryComplete = 85.0;// Block NEW entries when wave completion >= this (no buying tops / selling bottoms)
input double  InpMinEntryRoomPct  = 25.0;// Block NEW entries when geometry room to target < this
input double  InpAttentionATR     = 1.0; // Entry attention: price must be within this many ATR of the active node (0=off)

input string  __sep_thermal     = "════════ CAMPAIGN THERMAL RISK (PYRO) ════════"; // ──
input bool    InpUseThermalRisk  = true;  // Use PYRO campaign-thermodynamics risk engine
input int     InpMaxStacks       = 12;    // Max stacked entries per directional campaign
input double  InpMaxCampaignLots = 8.0;   // Max total lots per directional campaign
input double  InpHeatThrottle    = 0.55;  // Heat above this shrinks new stack size
input double  InpHeatFreeze      = 0.80;  // Heat above this freezes new stacks
input double  InpHeatCritical    = 1.10;  // Heat above this flattens the campaign (catastrophe stop)
input int     InpMaxAvgDownStacks= 3;     // Max stacks allowed while basket is underwater (anti-martingale)
input double  InpHeatAdverseSpan = 4.0;   // Adverse excursion (ATR) that equals full adverse heat
input double  InpAcctHeatDDPct   = 15.0;  // Account heat: equity drawdown %% that fully freezes admissions

input string  __sep_talon       = "════════ TALON GRIP — breakeven + trail ════════"; // ──
input bool    InpUseTalon        = true;  // Use TALON curve-convergent structural grip (off = no trail)
input int     InpTalonStructLen  = 5;     // Structural pivot length for the grip anchor
input double  InpTalonBufATR      = 0.35; // Buffer beyond the structural pivot (ATR)
input double  InpTalonBaseATR     = 2.5;  // Base trail distance far from target (ATR)
input double  InpTalonConvSpanATR = 6.0;  // Distance-to-target (ATR) over which the trail converges
input double  InpTalonMinTighten  = 0.25; // Tightest trail fraction near target / terminal (0..1)
input double  InpTalonBeATR        = 1.6; // Favorable excursion (ATR) that earns the breakeven lock
input double  InpArcPartialFrac    = 0.33;// Fraction banked when price REACHES the curve destination (0 = let it all run)
input double  InpArcPartialMinATR  = 1.5; // Min favorable excursion (ATR) before any ARC partial is allowed

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
   double retrMin, retrMax; bool useSymphony;
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
   bool   enableTrading, blockIfBreach, sessionFilter;
   double riskPercent, contractValue;
   double maxLots;
   bool   trailEnable, ddProtect;
   double trailStartATR, trailDistATR, maxDrawdownPct, ddFlattenPct;
   double maxEntryComplete, minEntryRoomPct;
   double attentionATR;
   // thermal risk (PYRO)
   bool   useThermalRisk;  int maxStacks;  double maxCampaignLots;
   double heatThrottle, heatFreeze, heatCritical;
   int    maxAvgDownStacks;
   double heatAdverseSpan, acctHeatDDPct;
   // TALON grip (breakeven + trail)
   bool   useTalon;  int talonStructLen;
   double talonBufATR, talonBaseATR, talonConvSpanATR, talonMinTighten, talonBeATR;
   double arcPartialFrac, arcPartialMinATR;
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
   g_cfg.retrMin          = InpRetrMin;
   g_cfg.retrMax          = InpRetrMax;
   g_cfg.useSymphony      = InpUseSymphony;
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
   g_cfg.blockIfBreach    = InpBlockIfBreach;
   g_cfg.sessionFilter    = InpSessionFilter;
   g_cfg.riskPercent      = InpRiskPercent;
   g_cfg.maxLots          = InpMaxLots;
   g_cfg.contractValue    = InpContractValue;
   g_cfg.trailEnable      = InpTrailEnable;
   g_cfg.trailStartATR    = InpTrailStartATR;
   g_cfg.trailDistATR     = InpTrailDistATR;
   g_cfg.ddProtect        = InpDDProtect;
   g_cfg.maxDrawdownPct   = InpMaxDrawdownPct;
   g_cfg.ddFlattenPct     = InpDDFlattenPct;
   g_cfg.maxEntryComplete = InpMaxEntryComplete;
   g_cfg.minEntryRoomPct  = InpMinEntryRoomPct;
   g_cfg.attentionATR     = InpAttentionATR;

   g_cfg.useThermalRisk   = InpUseThermalRisk;
   g_cfg.maxStacks        = InpMaxStacks;
   g_cfg.maxCampaignLots  = InpMaxCampaignLots;
   g_cfg.heatThrottle     = InpHeatThrottle;
   g_cfg.heatFreeze       = InpHeatFreeze;
   g_cfg.heatCritical     = InpHeatCritical;
   g_cfg.maxAvgDownStacks = InpMaxAvgDownStacks;
   g_cfg.heatAdverseSpan  = InpHeatAdverseSpan;
   g_cfg.acctHeatDDPct    = InpAcctHeatDDPct;

   g_cfg.useTalon         = InpUseTalon;
   g_cfg.talonStructLen   = InpTalonStructLen;
   g_cfg.talonBufATR      = InpTalonBufATR;
   g_cfg.talonBaseATR     = InpTalonBaseATR;
   g_cfg.talonConvSpanATR = InpTalonConvSpanATR;
   g_cfg.talonMinTighten  = InpTalonMinTighten;
   g_cfg.talonBeATR       = InpTalonBeATR;
   g_cfg.arcPartialFrac   = InpArcPartialFrac;
   g_cfg.arcPartialMinATR = InpArcPartialMinATR;

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

// PYRO admission verdict — whether a directional campaign may accept a new
// stacked entry, and how aggressively (continuous lot scale alongside).
enum FALCON_ADMIT
{
   ADM_OPEN      = 0,   // cool campaign — full-size stack allowed
   ADM_THROTTLED = 1,   // warming — stack size shrinks with heat
   ADM_FROZEN    = 2,   // hot / maxed / underwater-limit — no new stacks
   ADM_DERISK    = 3    // critical heat — flatten the campaign (catastrophe stop)
};

// TALON grip stage — the life-stage of a campaign's protective stop.
enum FALCON_TALON
{
   TG_FORMING    = 0,   // young / no breakeven yet — sits on structural stop
   TG_BREAKEVEN  = 1,   // breakeven earned (structural confirm)
   TG_RIDING     = 2,   // trailing behind confirmed swing structure
   TG_CONVERGING = 3,   // approaching curve target — trail contracting
   TG_TERMINAL   = 4    // terminal phase / profit rolling over — trail tightest
};

// Compression regime — controls recursion size/count near terminals
enum FALCON_COMPRESSION
{
   COMP_LOW     = 0,
   COMP_MEDIUM  = 1,
   COMP_HIGH    = 2,
   COMP_EXTREME = 3
};

// Entry readiness — the build-vs-execute ladder (the core distinction)
enum FALCON_ENTRY_READINESS
{
   ER_NOT_READY    = 0,   // building, far from terminal
   ER_EARLY        = 1,   // building, approaching terminal
   ER_BUILDING     = 2,   // in terminal zone, sequence forming
   ER_PRE_ENTRY    = 3,   // induction/liquidation underway
   ER_ENTRY_ACTIVE = 4,   // entry cycle has begun -> EXECUTE
   ER_TERMINAL     = 5     // return confirmed / done
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
   // Symphony phase engine mirror (display/labels only; set by SymphonyEngine)
   int    symMode;        // -1 short, 1 long, 0 none
   int    symPhaseLong;   // 0..4
   int    symPhaseShort;  // 0..4
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
   // conversation route (pathfinding): ordered authoritative nodes ahead of
   // price in the network-bias direction — the path price is likely to travel.
   int    pathIdx[32];
   int    pathCount;
   int    nextNodeIdx;          // nearest authoritative node ahead
   double nextNodePrice;
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
   bool   riskOk;
   // per-campaign (multi-direction) gross exposure
   double longGrossLots;
   double shortGrossLots;
   int    openLongCount;
   int    openShortCount;
   double openPnL;
   bool   sessionOpen;
   // TALON grip (campaign-level protective stop) — display
   double gripLong;        // active long-campaign stop level (0=none)
   double gripShort;       // active short-campaign stop level (0=none)
   int    talonStageLong;  // FALCON_TALON
   int    talonStageShort; // FALCON_TALON
};

//==================================================================
// SUB-STATE : ENTRY CYCLE  (the build-vs-execute brain)
//   Answers the four questions that matter more than "what phase?":
//     1) Who owns price?  2) Building or terminal?
//     3) How much curve remains?  4) How many recursions are possible?
//==================================================================
struct FalconEntryCycle
{
   bool   building;            // still expansion/transition/retracement
   bool   terminal;            // in the terminal region (HTF flip / supply-demand)
   bool   transitionComplete;  // the HIGH transition (dominance transfer) finished
   int    compressionRegime;   // FALCON_COMPRESSION
   double remainingBudget;     // remaining curve capacity (geometry)
   double expectedDepth;       // recursions physically possible from here (0..4)
   int    recursionDepth;      // recursive CHoCH cycles seen so far
   int    readiness;           // FALCON_ENTRY_READINESS
   bool   entryCycleActive;    // THE GO — the entry cycle has begun
   int    entryDir;            // FALCON_DIR direction to enter (continuation/return)
   int    ownerTF;             // dominant timeframe index (who owns price)
   double ownerPct[7];         // ownership distribution across rungs
   double entryCycleProb;      // 0..1 continuous entry-cycle conviction
   // F16 Engine 1A.7 — pre-objective LIQUIDATION WAVE (native terminal sequence)
   bool   liqActive;
   double liqDistPct;          // % of initial distance to objective remaining
   bool   liqObjArrival;       // objective reached (structural + physical)
   bool   liqTrueChoch;        // confirmed terminal CHoCH (the reversal)
   string liqSubPhase;         // Push/Displacement/Induction/Terminal Liquidation/Objective Arrival
};

//==================================================================
// SUB-STATE : THERMAL RISK  (PYRO — Campaign Thermodynamics)
//   A directional campaign (a fleet of stacked precision entries) is
//   modelled as a physical body that carries HEAT. Heat = adverse
//   excursion of the BLENDED basket (in ATR) amplified by a fragility
//   that grows with stack count and total lots. A winning basket runs
//   near-zero heat regardless of size (house money); an underwater,
//   heavily-stacked basket overheats fast. Heat throttles new stacks,
//   then freezes them, then (only at criticality) flattens the campaign.
//==================================================================
struct FalconThermalCampaign
{
   int    dir;             // FALCON_DIR
   int    stackCount;      // number of open stacked entries
   double totalLots;       // gross lots in this campaign
   double blendedEntry;    // volume-weighted average entry
   double breakeven;       // basket breakeven (blended entry + swap drift)
   double unrealizedPnL;   // money
   double adverseATR;      // >0 = basket UNDERWATER (ATR from blended entry)
   double favorableATR;    // >0 = basket IN PROFIT (ATR from blended entry)
   double exposureLoad;    // totalLots / maxCampaignLots
   double stackLoad;       // stackCount / maxStacks
   double fragility;       // 1 + size/stack amplification
   double heat;            // 0..~2 thermal load (the master scalar)
   double heatVelocity;    // d(heat)/bar
   double coolingRate;     // d(PnL)/bar  (>0 profit growing)
   int    admission;       // FALCON_ADMIT
   double admitLotScale;   // 0..1 size multiplier for the next stack
   bool   breakevenLocked; // basket SLs pulled to breakeven
};

//==================================================================
// SUB-STATE : PORTFOLIO THERMOSTAT
//   Long-heat and short-heat are tracked SEPARATELY (never netted —
//   multi-campaign law). If BOTH sides overheat at once (a whipsaw
//   trap) all new admissions freeze. Account heat = equity drawdown.
//==================================================================
struct FalconThermostat
{
   double longHeat;
   double shortHeat;
   double combinedHeat;
   double accountHeat;     // 0..1 from equity drawdown vs peak
   double equityPeak;
   bool   whipsawLock;     // both campaigns hot simultaneously
};

struct FalconRisk
{
   FalconThermalCampaign campaign[2];   // [0]=long  [1]=short
   FalconThermostat      thermostat;
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
   FalconEntryCycle   entryCycle;
   FalconExecution    exec;
   FalconRisk         risk;
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

string FalconReadinessStr(const int r)
{
   switch(r)
   {
      case ER_EARLY:        return("EARLY");
      case ER_BUILDING:     return("BUILDING");
      case ER_PRE_ENTRY:    return("PRE-ENTRY");
      case ER_ENTRY_ACTIVE: return("ENTRY ACTIVE");
      case ER_TERMINAL:     return("TERMINAL/DONE");
      default:              return("NOT READY");
   }
}

string FalconCompressionStr(const int c)
{
   switch(c)
   {
      case COMP_MEDIUM:  return("MEDIUM");
      case COMP_HIGH:    return("HIGH");
      case COMP_EXTREME: return("EXTREME");
      default:           return("LOW");
   }
}

string FalconResStr(const int r)
{
   return(r==RES_RESOLVED ? "RESOLVED" : r==RES_PARTIALLY_RESOLVED ? "PARTIAL" : "UNRESOLVED");
}

string FalconAdmitStr(const int a)
{
   switch(a)
   {
      case ADM_THROTTLED: return("THROTTLED");
      case ADM_FROZEN:    return("FROZEN");
      case ADM_DERISK:    return("DE-RISK!");
      default:            return("OPEN");
   }
}

string FalconTalonStr(const int t)
{
   switch(t)
   {
      case TG_BREAKEVEN:  return("BREAKEVEN");
      case TG_RIDING:     return("RIDING");
      case TG_CONVERGING: return("CONVERGING");
      case TG_TERMINAL:   return("TERMINAL");
      default:            return("FORMING");
   }
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

//==================================================================
// SUBSCRIBERS — real publish/subscribe. Modules register a handler
// for an event type (or EVT_NONE = all). FalconPublish dispatches
// synchronously so reactions are deterministic within the bar.
//==================================================================
typedef void (*FalconEventHandler)(const FalconEvent &e);
#define FALCON_MAX_SUBS 32
struct FalconSub { int type; FalconEventHandler handler; };
FalconSub g_subs[FALCON_MAX_SUBS];
int       g_subCount=0;

void FalconSubscribe(const int type, FalconEventHandler h)
{
   if(g_subCount<FALCON_MAX_SUBS){ g_subs[g_subCount].type=type; g_subs[g_subCount].handler=h; g_subCount++; }
}

void FalconBusInit()
{
   g_bus.head  = 0;
   g_bus.total = 0;
   g_subCount  = 0;
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
// Publish an event: store in the ring, count it, and DISPATCH to any
// registered subscribers (pub/sub). Modules react to events instead
// of polling; dispatch is synchronous to stay deterministic.
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

   for(int i=0;i<g_subCount;i++)
      if(g_subs[i].type==type || g_subs[i].type==EVT_NONE)
         g_subs[i].handler(e);
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
// entry-cycle recursion tracking (ported from F16 spawn engine)
int    me_entryCycle=0; int me_waveDepth=0; bool me_isRecursive=false;
bool   me_recursiveComplete=false; int me_recursiveFiredBar=-1; int me_prevPstForCycle=0;

// HTF rung labels (M1 M3 M5 M15 H1 H4 chart) and periods
ENUM_TIMEFRAMES me_htfTF[7];
int             me_htfDirState[7];
double          me_htfOrigin[7];
double          me_htfExtreme[7];

//==================================================================
// PER-TIMEFRAME CURVE FSM — a REAL wave engine run on each rung so the
// HTF stack / curve tree reflect genuine nested curves (dir + phase +
// completion + recursion per timeframe), not just a direction read.
//==================================================================
struct TFCurve
{
   bool   init;
   double vel, velPrev, acc, accPrev, csm, csmPrev;
   double curSH, curSL, prSH, prSL, lastP, prevP;
   int    lastD, prevD;
   int    dir;
   double ft, fb, p4h, p4l, inv, tgt, cycH, cycL;
   int    pst, lastDirSeen;
   bool   bos1, bos2;
   double protSw, protSw2;
   int    recBrk; bool recArm;
   int    spawnBar;
   // outputs
   int    oDir, oPhase, oRecBrk;
   double oCompletion, oOrigin, oExtreme, oObjective, oDom;
};
TFCurve g_tfCurve[7];

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
   me_entryCycle=0; me_waveDepth=0; me_isRecursive=false;
   me_recursiveComplete=false; me_recursiveFiredBar=-1; me_prevPstForCycle=0;

   me_obCount=0;

   me_htfTF[0]=PERIOD_M1;  me_htfTF[1]=PERIOD_M5;  me_htfTF[2]=PERIOD_M15;
   me_htfTF[3]=PERIOD_M30; me_htfTF[4]=PERIOD_H1;  me_htfTF[5]=PERIOD_H4;
   me_htfTF[6]=_Period;
   for(int i=0;i<7;i++){ me_htfDirState[i]=0; me_htfOrigin[i]=0; me_htfExtreme[i]=0; }
   for(int i=0;i<7;i++)
   {
      ZeroMemory(g_tfCurve[i]);
      g_tfCurve[i].init=false; g_tfCurve[i].lastD=0; g_tfCurve[i].prevD=0;
      g_tfCurve[i].dir=0; g_tfCurve[i].pst=0; g_tfCurve[i].lastDirSeen=0; g_tfCurve[i].recArm=true;
   }
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
      me_entryCycle=0; me_waveDepth=0; me_isRecursive=false; me_recursiveComplete=false;
      me_recursiveFiredBar=-1; me_prevPstForCycle=0;
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

   // --- ENTRY-CYCLE / RECURSION DEPTH (F16 spawn-engine port) ---
   // Each completed terminal recursion (the return confirming after an
   // induction-liquidation sequence) is one Wyckoff "shift". Count them,
   // capped at 4 (spring/test/LPS1/LPS2). A fresh return that holds advances
   // the entry-cycle generation; compression decides how fast they stack.
   bool enteredReturn = ((me_pst==13) && me_prevPstForCycle!=13);
   bool freshFire = enteredReturn &&
                    (me_recursiveFiredBar<0 || (g_barCounter-me_recursiveFiredBar) > g_cfg.structLen);
   if(freshFire)
   {
      me_entryCycle = MathMin(me_entryCycle+1, 4);
      me_waveDepth  = me_entryCycle;
      me_isRecursive= (me_entryCycle>0);
      me_recursiveComplete = true;
      me_recursiveFiredBar = g_barCounter;
   }
   me_prevPstForCycle = me_pst;

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
   w.recursiveComplete= me_recursiveComplete;
   w.entryCycle       = me_entryCycle;
   w.waveDepth        = me_waveDepth;

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
int ME_TFCurve(const ENUM_TIMEFRAMES tf, const int idx)
{
   int pv = g_cfg.structLen;
   int need = pv*2 + g_cfg.atrLen + 60;
   double h[],l[],c[],o[];
   ArraySetAsSeries(h,true); ArraySetAsSeries(l,true);
   ArraySetAsSeries(c,true); ArraySetAsSeries(o,true);
   if(CopyHigh(_Symbol,tf,0,need,h)<need) return(g_tfCurve[idx].oDir);
   if(CopyLow (_Symbol,tf,0,need,l)<need) return(g_tfCurve[idx].oDir);
   if(CopyClose(_Symbol,tf,0,need,c)<need) return(g_tfCurve[idx].oDir);
   if(CopyOpen (_Symbol,tf,0,need,o)<need) return(g_tfCurve[idx].oDir);

   // ATR proxy on this TF (mean true range over atrLen)
   double atr=0; for(int i=1;i<=g_cfg.atrLen;i++) atr+=(h[i]-l[i]); atr/=MathMax(g_cfg.atrLen,1); if(atr<=0) atr=1e-10;
   double close1=c[1];

   // physics EMA chain (advanced once per chart bar on this TF's last delta)
   double d = c[1]-c[2];
   if(!g_tfCurve[idx].init)
   { g_tfCurve[idx].vel=d; g_tfCurve[idx].velPrev=d; g_tfCurve[idx].acc=0; g_tfCurve[idx].accPrev=0; g_tfCurve[idx].csm=0; g_tfCurve[idx].csmPrev=0; g_tfCurve[idx].init=true; }
   else
   {
      g_tfCurve[idx].velPrev=g_tfCurve[idx].vel;
      g_tfCurve[idx].vel=FalconEMA(g_tfCurve[idx].vel,d,3);
      g_tfCurve[idx].accPrev=g_tfCurve[idx].acc;
      g_tfCurve[idx].acc=g_tfCurve[idx].vel-g_tfCurve[idx].velPrev;
      double cv=g_tfCurve[idx].acc-g_tfCurve[idx].accPrev;
      g_tfCurve[idx].csmPrev=g_tfCurve[idx].csm;
      g_tfCurve[idx].csm=FalconEMA(g_tfCurve[idx].csm,cv,3);
   }
   // efficiency / displacement on this TF
   int eff=g_cfg.effLen;
   double mv=MathAbs(c[1]-c[1+eff]); double ps=0; for(int i=1;i<=eff;i++) ps+=MathAbs(c[i]-c[i+1]);
   double efficiency=(ps>0?mv/ps:0.0);
   double disp=(h[1]-l[1])/atr;
   bool bullImp=(efficiency>g_cfg.effThresh && g_tfCurve[idx].vel>g_tfCurve[idx].velPrev && g_tfCurve[idx].acc>0 && c[1]>o[1] && disp>g_cfg.dispThresh);
   bool bearImp=(efficiency>g_cfg.effThresh && g_tfCurve[idx].vel<g_tfCurve[idx].velPrev && g_tfCurve[idx].acc<0 && c[1]<o[1] && disp>g_cfg.dispThresh);
   bool bullDec=(MathAbs(g_tfCurve[idx].acc)<MathAbs(g_tfCurve[idx].accPrev)*0.8 && g_tfCurve[idx].vel>0);
   bool bearDec=(MathAbs(g_tfCurve[idx].acc)<MathAbs(g_tfCurve[idx].accPrev)*0.8 && g_tfCurve[idx].vel<0);

   // pivots / structure at center
   int center=pv+1; double eP=0; int eD=0;
   bool isH=true,isL=true;
   for(int k=1;k<=pv;k++){ if(h[center]<=h[center+k]||h[center]<=h[center-k]) isH=false; if(l[center]>=l[center+k]||l[center]>=l[center-k]) isL=false; }
   if(isH){ eP=h[center]; eD=1; } else if(isL){ eP=l[center]; eD=-1; }
   if(eD==1){ g_tfCurve[idx].prSH=(g_tfCurve[idx].curSH==0?h[center]:g_tfCurve[idx].curSH); g_tfCurve[idx].curSH=h[center]; }
   else if(eD==-1){ g_tfCurve[idx].prSL=(g_tfCurve[idx].curSL==0?l[center]:g_tfCurve[idx].curSL); g_tfCurve[idx].curSL=l[center]; }
   if(eD!=0){ g_tfCurve[idx].prevP=g_tfCurve[idx].lastP; g_tfCurve[idx].prevD=g_tfCurve[idx].lastD; g_tfCurve[idx].lastP=eP; g_tfCurve[idx].lastD=eD; }

   bool bullCH=(g_tfCurve[idx].prSH!=0 && close1>g_tfCurve[idx].prSH+atr*g_cfg.chochBufferATR);
   bool bearCH=(g_tfCurve[idx].prSL!=0 && close1<g_tfCurve[idx].prSL-atr*g_cfg.chochBufferATR);
   bool eLong =(isH && g_tfCurve[idx].prevD==-1 && (g_tfCurve[idx].lastP-g_tfCurve[idx].prevP)>atr*g_cfg.impulseAtrMult);
   bool eShort=(isL && g_tfCurve[idx].prevD== 1 && (g_tfCurve[idx].prevP-g_tfCurve[idx].lastP)>atr*g_cfg.impulseAtrMult);

   bool hasCtx=(g_tfCurve[idx].dir!=0 && g_tfCurve[idx].ft!=0);
   bool flipUp=(g_tfCurve[idx].dir==-1 && bullCH);
   bool flipDn=(g_tfCurve[idx].dir==1  && bearCH);
   bool isRev =(eLong&&g_tfCurve[idx].dir==-1)||(eShort&&g_tfCurve[idx].dir==1)||flipUp||flipDn;
   bool spawn =(eLong||eShort||flipUp||flipDn)&&(!hasCtx||isRev);
   if(spawn)
   {
      int nd=eLong?1:eShort?-1:flipUp?1:-1;
      double hi=MathMax(g_tfCurve[idx].lastP,g_tfCurve[idx].prevP);
      double lo=MathMin(g_tfCurve[idx].lastP,g_tfCurve[idx].prevP);
      g_tfCurve[idx].dir=nd; g_tfCurve[idx].ft=hi; g_tfCurve[idx].fb=lo; g_tfCurve[idx].p4h=hi; g_tfCurve[idx].p4l=lo;
      g_tfCurve[idx].cycH=h[1]; g_tfCurve[idx].cycL=l[1]; g_tfCurve[idx].inv=(nd==1?lo:hi);
      double rng=(g_tfCurve[idx].prSH!=0&&g_tfCurve[idx].prSL!=0)?MathAbs(g_tfCurve[idx].prSH-g_tfCurve[idx].prSL):atr*5.0;
      g_tfCurve[idx].tgt=(nd==1?hi+rng:lo-rng); g_tfCurve[idx].spawnBar=g_barCounter;
   }
   if(g_tfCurve[idx].dir==1)  g_tfCurve[idx].cycH=(g_tfCurve[idx].cycH==0?h[1]:MathMax(g_tfCurve[idx].cycH,h[1]));
   if(g_tfCurve[idx].dir==-1) g_tfCurve[idx].cycL=(g_tfCurve[idx].cycL==0?l[1]:MathMin(g_tfCurve[idx].cycL,l[1]));

   bool reset=(g_tfCurve[idx].dir!=g_tfCurve[idx].lastDirSeen); g_tfCurve[idx].lastDirSeen=g_tfCurve[idx].dir;
   if(reset){ g_tfCurve[idx].bos1=false; g_tfCurve[idx].bos2=false; g_tfCurve[idx].protSw=0; g_tfCurve[idx].protSw2=0; }
   if(g_tfCurve[idx].dir==1 && isL){ g_tfCurve[idx].protSw2=g_tfCurve[idx].protSw; g_tfCurve[idx].protSw=l[center]; }
   if(g_tfCurve[idx].dir==-1&& isH){ g_tfCurve[idx].protSw2=g_tfCurve[idx].protSw; g_tfCurve[idx].protSw=h[center]; }
   bool oppBOS=(g_tfCurve[idx].dir==1 && g_tfCurve[idx].protSw!=0 && close1<g_tfCurve[idx].protSw)||(g_tfCurve[idx].dir==-1 && g_tfCurve[idx].protSw!=0 && close1>g_tfCurve[idx].protSw);
   if(!g_tfCurve[idx].bos1 && oppBOS) g_tfCurve[idx].bos1=true;

   int wdir=(g_tfCurve[idx].inv!=0?(close1>g_tfCurve[idx].inv?1:close1<g_tfCurve[idx].inv?-1:g_tfCurve[idx].dir):g_tfCurve[idx].dir);
   bool atFlip=(g_tfCurve[idx].ft!=0&&g_tfCurve[idx].fb!=0&&close1<=g_tfCurve[idx].ft&&close1>=g_tfCurve[idx].fb);
   bool atExtreme=(wdir==1?h[1]>=(g_tfCurve[idx].cycH==0?h[1]:g_tfCurve[idx].cycH):wdir==-1?l[1]<=(g_tfCurve[idx].cycL==0?l[1]:g_tfCurve[idx].cycL):false);
   double extr=(wdir==1?(g_tfCurve[idx].cycH==0?close1:g_tfCurve[idx].cycH):(g_tfCurve[idx].cycL==0?close1:g_tfCurve[idx].cycL));
   bool extended=(g_tfCurve[idx].inv!=0 && MathAbs(extr-g_tfCurve[idx].inv)>atr*1.5);
   bool expanding=eLong||eShort||(wdir==1?bullImp:bearImp);
   bool momDecaying=(g_tfCurve[idx].dir==1?bullDec:bearDec);
   bool momCounter =(g_tfCurve[idx].dir==1?bearImp:bullImp);
   double convScore=MathMin(MathAbs(g_tfCurve[idx].csm)/MathMax(atr*g_cfg.convMult,1e-10)*50.0,100.0);
   bool physConv=convScore>35.0, physTransfer=convScore>48.0;

   bool phase2CH=(g_tfCurve[idx].dir==1&&bearCH)||(g_tfCurve[idx].dir==-1&&bullCH);
   if(reset||(atExtreme&&extended)){ g_tfCurve[idx].recBrk=0; g_tfCurve[idx].recArm=true; }
   if((g_tfCurve[idx].dir==1&&isH)||(g_tfCurve[idx].dir==-1&&isL)) g_tfCurve[idx].recArm=true;
   if((phase2CH||oppBOS)&&g_tfCurve[idx].recArm&&!atExtreme){ g_tfCurve[idx].recBrk++; g_tfCurve[idx].recArm=false; }
   double compIdx=FalconClamp((1.0-MathMin(disp/MathMax(g_cfg.dispThresh,1e-10),1.0))*60.0+(1.0-MathMin(efficiency/MathMax(g_cfg.effThresh,1e-10),1.0))*40.0,0,100);
   double recDom=MathMin(MathMax(g_tfCurve[idx].recBrk*(30.0-compIdx*0.15),0.0),100.0);
   bool transferDone=recDom>=50.0;

   if(reset) g_tfCurve[idx].pst=0;
   if(g_tfCurve[idx].dir!=0 && !reset)
   {
      int pst=g_tfCurve[idx].pst;
      if(pst==0&&expanding) pst=1;
      if(pst==1&&!atExtreme&&momDecaying&&physConv) pst=2;
      if(pst==2&&!atExtreme&&momCounter&&physTransfer) pst=3;
      if(pst==3&&!atExtreme&&g_tfCurve[idx].bos1&&physTransfer) pst=4;
      if(pst>=1&&pst<=7&&atExtreme&&extended) pst=5;
      if(pst==5&&!atExtreme&&g_tfCurve[idx].recBrk>=1) pst=7;
      if(pst==7&&transferDone) pst=8;
      if(pst==8&&atFlip) pst=9;
      if(pst==9&&((g_tfCurve[idx].dir==1&&bullImp)||(g_tfCurve[idx].dir==-1&&bearImp))) pst=10;
      if(pst==10&&oppBOS) pst=11;
      if(pst==11&&((g_tfCurve[idx].dir==1&&l[1]<g_tfCurve[idx].fb)||(g_tfCurve[idx].dir==-1&&h[1]>g_tfCurve[idx].ft))) pst=12;
      if(pst==12&&((g_tfCurve[idx].dir==1&&bullCH)||(g_tfCurve[idx].dir==-1&&bearCH))) pst=13;
      g_tfCurve[idx].pst=pst;
   }
   int phase=g_tfCurve[idx].pst;
   if(phase==5 && g_tfCurve[idx].dir==-1) phase=6;
   if(phase==13&& g_tfCurve[idx].dir==-1) phase=14;
   double wp=(g_tfCurve[idx].pst==0?5.0:g_tfCurve[idx].pst==1?15.0:g_tfCurve[idx].pst==2?25.0:g_tfCurve[idx].pst==3?33.0:g_tfCurve[idx].pst==4?42.0:g_tfCurve[idx].pst==5?55.0:g_tfCurve[idx].pst==7?65.0:g_tfCurve[idx].pst==8?75.0:g_tfCurve[idx].pst==9?85.0:g_tfCurve[idx].pst==10?90.0:g_tfCurve[idx].pst==11?94.0:g_tfCurve[idx].pst==12?97.0:100.0);

   g_tfCurve[idx].oDir=wdir; g_tfCurve[idx].oPhase=phase; g_tfCurve[idx].oCompletion=wp;
   g_tfCurve[idx].oOrigin=g_tfCurve[idx].inv; g_tfCurve[idx].oExtreme=extr; g_tfCurve[idx].oObjective=g_tfCurve[idx].tgt;
   g_tfCurve[idx].oRecBrk=g_tfCurve[idx].recBrk; g_tfCurve[idx].oDom=recDom;
   me_htfDirState[idx]=wdir; me_htfOrigin[idx]=g_tfCurve[idx].inv;
   return(wdir);
}

void ME_UpdateHTF()
{
   FalconHTF h;
   int bull=0, bear=0;
   for(int i=0;i<7;i++)
   {
      int d;
      if(me_htfTF[i]==_Period)
      {
         // UNIFY (single source of truth): the chart rung REUSES the primary
         // wave FSM (g_state.wave) instead of running a second FSM. Removes the
         // one true duplication — chart phase now exists exactly once.
         d = g_state.wave.direction;
         g_tfCurve[i].oDir       = d;
         g_tfCurve[i].oPhase     = g_state.wave.phase;
         g_tfCurve[i].oCompletion= g_state.wave.completion;
         g_tfCurve[i].oOrigin    = g_state.wave.origin;
         g_tfCurve[i].oExtreme   = g_state.wave.extreme;
         g_tfCurve[i].oObjective = g_state.wave.objective;
         g_tfCurve[i].oRecBrk    = g_state.wave.recursionBreaks;
         g_tfCurve[i].oDom       = g_state.wave.dominanceTransfer;
         me_htfDirState[i]=d; me_htfOrigin[i]=g_state.wave.origin;
      }
      else d = ME_TFCurve(me_htfTF[i], i);   // REAL per-TF wave engine (other rungs)
      h.dir[i]=d;
      h.beliefs[i]=d;
      h.prog[i]=g_tfCurve[i].oCompletion;
      if(d==1) bull++; else if(d==-1) bear++;
   }
   h.stackDir  = (bull>bear?DIR_LONG:bear>bull?DIR_SHORT:DIR_NONE);
   h.alignment = MathMax(bull,bear)/7.0*100.0;
   h.conflict  = 100.0 - h.alignment;
   h.fractalAgreement = (h.alignment>=66.0);
   // dominance / owner = highest timeframe whose own curve agrees with the stack
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

   // ---- PERSISTENCE: reload remembered network nodes on boot ----
   if(InpEnablePersist && FileIsExist(FP_NetworkFile()))
   {
      int h=FileOpen(FP_NetworkFile(),FILE_READ|FILE_CSV|FILE_ANSI,',');
      if(h!=INVALID_HANDLE)
      {
         for(int k=0;k<8 && !FileIsEnding(h);k++) FileReadString(h);   // skip header row
         while(!FileIsEnding(h) && mem_count<FALCON_MAX_NODES)
         {
            double px =StringToDouble(FileReadString(h));
            double mid=StringToDouble(FileReadString(h));
            int    dir=(int)StringToInteger(FileReadString(h));
            double sc =StringToDouble(FileReadString(h));
            int    wt =(int)StringToInteger(FileReadString(h));
            int    st =(int)StringToInteger(FileReadString(h));
            int    bb =(int)StringToInteger(FileReadString(h));
            int    rv =(int)StringToInteger(FileReadString(h));
            if(px==0.0 && mid==0.0) continue;
            mem_px[mem_count]=px; mem_mid[mem_count]=mid; mem_dir[mem_count]=dir;
            mem_score[mem_count]=sc; mem_weight[mem_count]=wt; mem_state[mem_count]=st;
            mem_birth[mem_count]=bb; mem_rev[mem_count]=rv; mem_count++;
         }
         FileClose(h);
         FalconInfo("MemoryEngine",StringFormat("restored %d network nodes",mem_count));
      }
   }
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

   // ---- CONVERSATION ROUTE (pathfinding, port of F16 f_pathNodes) ----
   // Collect unbroken, authoritative nodes that lie AHEAD of price in the
   // network-bias direction, then sort by distance ascending = the route price
   // is likely to converse along. nextNode = the nearest one ahead.
   int pathTmp[32]; int pc=0;
   for(int i=0;i<mem_count && pc<32;i++)
   {
      if(mem_state[i]==2 || MEM_Auth(i)<g_cfg.authMin) continue;
      bool ahead = (bias==DIR_LONG ? mem_px[i]>close1 : bias==DIR_SHORT ? mem_px[i]<close1 : false);
      if(ahead) pathTmp[pc++]=i;
   }
   // insertion sort by distance to price (ascending)
   for(int a=1;a<pc;a++)
   {
      int key=pathTmp[a]; double kd=MathAbs(close1-mem_px[key]); int b=a-1;
      while(b>=0 && MathAbs(close1-mem_px[pathTmp[b]])>kd){ pathTmp[b+1]=pathTmp[b]; b--; }
      pathTmp[b+1]=key;
   }
   n.pathCount=pc;
   for(int i=0;i<pc;i++) n.pathIdx[i]=pathTmp[i];
   n.nextNodeIdx   = (pc>0? pathTmp[0] : -1);
   n.nextNodePrice = (pc>0? mem_px[pathTmp[0]] : 0.0);

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

   // ---- EXPLICIT CURVE TREE (root -> parent -> children) from REAL per-TF curves ----
   // root = the owning HTF curve; parent = the next lower agreeing TF; children
   // = the recursive sub-waves inside. Built from the genuine per-TF wave engine.
   c.ownerTF       = h.ownerTF;
   int ot = (h.ownerTF>=0 && h.ownerTF<7)? h.ownerTF : 4;
   c.rootOrigin    = g_tfCurve[ot].oOrigin;
   c.rootExtreme   = g_tfCurve[ot].oExtreme;
   c.rootDir       = g_tfCurve[ot].oDir;
   int parentTF    = (ot>0? ot-1 : ot);
   c.parentDir     = g_tfCurve[parentTF].oDir;
   c.parentOrigin  = g_tfCurve[parentTF].oOrigin;
   c.parentExtreme = g_tfCurve[parentTF].oExtreme;
   // emergent nodes = recursive breaks accumulated across the lower (child) TFs
   int emergent=0; for(int i=0;i<ot;i++) emergent+=g_tfCurve[i].oRecBrk;
   c.emergentNodes = emergent;
   c.emergentPhase = g_tfCurve[ot].oPhase;
   c.evolution     = g_tfCurve[ot].oDom;

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
      wm.phase[i]=g_tfCurve[i].oPhase;     // genuine per-TF wave phase
      wm.progress[i]=g_tfCurve[i].oCompletion;
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
   FalconWave w=g_state.wave;

   // OWNERSHIP AUTHORITY — the single source of WHO owns price, and therefore
   // the single source of DIRECTION. Ownership FLIPS only when a transition
   // completes: price confirms the return out of the terminal zone
   // (DEMAND/SUPPLY RETURN) or dominance has fully transferred (>=50%). Until a
   // flip confirms, the established owner PERSISTS — building counter-moves do
   // NOT change ownership. This flip is the event that drives direction; no vote.
   bool flip = (w.phase==PH_DEMAND_RETURN || w.phase==PH_SUPPLY_RETURN || w.dominanceTransfer>=50.0);
   if(flip && w.direction!=DIR_NONE && w.direction!=mem_campOwner)
   { mem_campOwner=w.direction; mem_campStart=g_barCounter; }
   // seed once at boot if there is no established owner yet
   if(mem_campOwner==DIR_NONE && h.stackDir!=DIR_NONE){ mem_campOwner=h.stackDir; mem_campStart=g_barCounter; }

   // control = how strongly the evidence agrees with the established owner
   double control = h.alignment;
   if(n.pressureDir==mem_campOwner && mem_campOwner!=DIR_NONE) control=MathMin(100.0,control+15.0);

   cm.owner=mem_campOwner;
   cm.controlScore=FalconClamp(control,0,100);
   cm.objectiveDir=mem_campOwner;
   cm.remainingEnergy=g_state.intel.residualEnergy; // back-filled by Intelligence
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
// multi-bar forward-test of predictions
int    ie_predPendDir=0; double ie_predPendClose=0; int ie_predBarsLeft=0; bool ie_predActive=false;
// F16 Engine 1A.7 — persistent liquidation-wave state
bool   ie_liqActive=false; bool ie_liqIsRetr=false; int ie_liqDir=0;
double ie_liqTarget=0; double ie_liqInitDist=0;

// SUBSCRIBER: a fresh wave spawn invalidates the prior terminal liquidation.
void IE_OnWaveSpawn(const FalconEvent &e){ ie_liqActive=false; ie_liqTarget=0; ie_liqInitDist=0; }

void IntelligenceEngineInit()
{
   ie_bExp=0; ie_bConv=0; ie_bCreate=0; ie_bAbs=0; ie_bRetr=0; ie_bRet=0;
   ie_prevRes=RES_UNRESOLVED;
   ie_prevPredPrice=0; ie_prevPredDir=0; ie_valScore=50.0;
   ie_predPendDir=0; ie_predPendClose=0; ie_predBarsLeft=0; ie_predActive=false;
   ie_liqActive=false; ie_liqIsRetr=false; ie_liqDir=0; ie_liqTarget=0; ie_liqInitDist=0;
   FalconSubscribe(EVT_WAVE_SPAWN, IE_OnWaveSpawn);   // event-driven reset
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
   double atr=MathMax(g_state.physics.atr,1e-10);

   // MULTI-BAR FORWARD TEST: a prediction is confirmed if price travels a
   // meaningful distance (>=0.5 ATR) in the predicted direction within a
   // horizon; it is a miss if the horizon elapses without that move. This
   // replaces the noisy single-bar check that pinned the score low in ranges.
   if(ie_predActive)
   {
      double move = close1 - ie_predPendClose;
      double favorable = (ie_predPendDir==DIR_LONG ? move : -move);
      bool resolved=false, hit=false;
      if(favorable >= atr*0.5){ resolved=true; hit=true; }
      else
      {
         ie_predBarsLeft--;
         if(ie_predBarsLeft<=0){ resolved=true; hit=(favorable>0.0); }
      }
      if(resolved)
      {
         ie_valScore = FalconEMA(ie_valScore, hit?100.0:0.0, 8);
         x.validated = hit;
         ie_predActive=false;
      }
   }
   // open a new forward-test when none is pending and we have a prediction
   if(!ie_predActive && x.predictionPrice!=0.0)
   {
      ie_predPendDir   = (x.predictionPrice>close1?DIR_LONG:DIR_SHORT);
      ie_predPendClose = close1;
      ie_predBarsLeft  = 6;          // horizon in bars
      ie_predActive    = true;
   }
   x.validationScore = FalconClamp(ie_valScore,0,100);
}

//------------------------------------------------------------------
// LIQUIDATION WAVE ENGINE — verbatim port of F16 Engine 1A.7. Tracks
// the pre-objective liquidation toward the owner target and classifies
// the terminal sub-sequence (Push -> Displacement -> Induction ->
// Terminal Liquidation -> Objective Arrival), plus the confirmed
// terminal CHoCH. This is F16's NATIVE entry-sequence mechanism — the
// entry cycle keys off it instead of a re-derived heuristic.
//------------------------------------------------------------------
void IE_LiquidationWave(FalconIntelligence &x, FalconEntryCycle &ec)
{
   FalconWave w=g_state.wave;
   FalconPhysics p=g_state.physics;
   double close1=gClose[1];
   double atr=MathMax(p.atr,1e-10);

   bool isRetr = (w.phase==PH_INDUCTION);                       // retracement-side induction
   bool arm    = (w.phase>=PH_HTF_FLIP_ZONE || w.phase==PH_EXP_INDUCTION);
   double obj  = w.objective;

   if(arm && !ie_liqActive && obj!=0)
   {
      ie_liqActive  = true;
      ie_liqIsRetr  = isRetr;
      ie_liqTarget  = obj;
      ie_liqDir     = (obj>close1?DIR_LONG:DIR_SHORT);
      ie_liqInitDist= MathMax(MathAbs(obj-close1), atr*0.5);
   }
   if(ie_liqActive && obj!=0) ie_liqTarget=obj;

   double remain = (ie_liqActive)? MathAbs(ie_liqTarget-close1) : 0.0;
   double distPct= (ie_liqActive && ie_liqInitDist>0)? MathMin(100.0, remain/ie_liqInitDist*100.0) : 100.0;

   bool capExh   = (x.dissipationProgress>60.0 || g_state.convexity.maturity>60.0);
   bool resolved = (x.resolutionState==RES_RESOLVED);
   bool energyLo = (p.efficiency < g_cfg.effThresh*0.7);
   bool magnet   = (ie_liqActive && distPct<20.0);
   bool arrStruct= (ie_liqActive && (ie_liqDir==DIR_LONG? close1>=ie_liqTarget : close1<=ie_liqTarget));
   bool arrPhys  = (capExh && (resolved || magnet));
   bool objArr   = (arrStruct && energyLo && arrPhys);
   bool counterBOS=(ie_liqDir==DIR_LONG? g_state.structure.bos==DIR_SHORT : g_state.structure.bos==DIR_LONG);
   bool trueChoch= (objArr && counterBOS && energyLo && resolved);

   string sub = (!ie_liqActive)?"" :
                objArr?"Objective Arrival" :
                (magnet && energyLo)?"Terminal Liquidation" :
                (g_state.convexity.maturity>40.0 || x.dissipationProgress>40.0)?"Induction" :
                (distPct<70.0)?"Displacement" :
                (distPct<95.0)?"Push":"Initialization";

   bool inWindow = (w.phase==PH_EXP_INDUCTION||w.phase==PH_EXP_LIQUIDITY||w.phase==PH_INDUCTION||w.phase==PH_LIQUIDATION||w.phase==PH_TERMINAL_CURVE);
   if(ie_liqActive && (!inWindow || (objArr && trueChoch))) ie_liqActive=false;

   ec.liqActive    = ie_liqActive;
   ec.liqDistPct   = distPct;
   ec.liqObjArrival= objArr;
   ec.liqTrueChoch = trueChoch;
   ec.liqSubPhase  = sub;
}

//------------------------------------------------------------------
// ENTRY CYCLE ENGINE — the build-vs-execute brain (F72 model).
//   Markets are recursive curves. The job is NOT "what phase?" but:
//   who owns price, are we BUILDING or TERMINAL, how much curve
//   remains, and HAS THE ENTRY CYCLE BEGUN. Entries only occur in the
//   terminal region (the wave's own HTF flip / supply-demand), after
//   the recursive transition matures — never during expansion. This
//   is what stops the engine chasing an expansion into the opposite
//   extreme (e.g. shorting the demand low).
//------------------------------------------------------------------
void IE_EntryCycle(FalconIntelligence &x)
{
   FalconEntryCycle ec;
   FalconWave  w  = g_state.wave;
   FalconPhysics p= g_state.physics;
   FalconConvexity cv=g_state.convexity;
   FalconSupplyDemand sd=g_state.supplyDemand;
   FalconHTF h=g_state.htf;
   double atr=MathMax(p.atr,1e-10);

   // --- COMPRESSION REGIME (matters most near terminals) ---
   double comp=p.compression;
   ec.compressionRegime = comp<25?COMP_LOW : comp<50?COMP_MEDIUM : comp<75?COMP_HIGH : COMP_EXTREME;

   // --- CURVE OWNERSHIP (who owns price) ---
   ec.ownerTF = h.ownerTF;
   for(int i=0;i<7;i++) ec.ownerPct[i]=0.0;
   int agree=0;
   for(int i=0;i<7;i++) if(h.dir[i]==h.stackDir && h.stackDir!=DIR_NONE) agree++;
   for(int i=0;i<7;i++)
      ec.ownerPct[i] = (agree>0 && h.dir[i]==h.stackDir)? (100.0/agree) : 0.0;

   // --- TRANSITION COMPLETE (the high transition / dominance transfer) ---
   ec.transitionComplete = (w.dominanceTransfer>=50.0);

   // --- BUILDING vs TERMINAL ---
   // Terminal = price has reached the wave's own terminal region: the HTF
   // flip-zone phase band (9..14) OR sitting inside the matching supply/demand.
   bool terminalPhase = (w.phase>=PH_HTF_FLIP_ZONE);
   bool inZone        = (sd.activeZone!=DIR_NONE);
   ec.terminal  = (terminalPhase || inZone);
   ec.building  = !ec.terminal;

   // --- REMAINING CURVE BUDGET + EXPECTED RECURSION DEPTH ---
   // budget = distance-to-target / convexity-width / compression. High
   // compression shrinks the budget -> fewer/smaller recursions (failure
   // swing + tiny cycles); low compression -> big loops.
   double dist = (w.objective!=0)? MathAbs(w.objective-gClose[1])/atr : MathMax(cv.geometryCapacity/25.0,0.1);
   double cw   = MathMax(cv.convexityWidth/atr, 0.25);
   double compFactor = 1.0 + comp/50.0;
   ec.remainingBudget = dist/(cw*compFactor);
   ec.expectedDepth   = FalconClamp(ec.remainingBudget, 0, 4);
   ec.recursionDepth  = w.recursionBreaks;

   // --- LIQUIDATION WAVE (F16 native terminal sequence) ---
   IE_LiquidationWave(x, ec);

   // --- READINESS LADDER ---
   int rd;
   if(ec.building && w.completion<60.0)              rd=ER_NOT_READY;
   else if(ec.building)                              rd=ER_EARLY;
   else if(w.phase==PH_HTF_FLIP_ZONE)                rd=ER_BUILDING;
   else if(w.phase==PH_INDUCTION||w.phase==PH_LIQUIDATION) rd=ER_PRE_ENTRY;
   else if(w.phase==PH_TERMINAL_CURVE||w.phase==PH_DEMAND_RETURN||w.phase==PH_SUPPLY_RETURN) rd=ER_ENTRY_ACTIVE;
   else                                              rd=ER_BUILDING;
   // F16 liquidation-wave overrides: terminal liquidation / objective arrival /
   // confirmed terminal CHoCH ARE the entry cycle. Use them directly.
   if(ec.liqSubPhase=="Terminal Liquidation" && rd<ER_PRE_ENTRY) rd=ER_PRE_ENTRY;
   if(ec.liqObjArrival || ec.liqTrueChoch) rd=ER_ENTRY_ACTIVE;
   // RECLAIM TRIGGER: a confirmed CHoCH in the owner/continuation direction while
   // in the terminal zone IS the entry cycle (the turn off supply/demand). This
   // is the reliable on-chart trigger — without it the strict FSM can sit at the
   // flip zone for hundreds of bars and never crawl to the RETURN phase, so no
   // entry ever fires.
   bool reclaim = (g_state.structure.choch==w.direction && w.direction!=DIR_NONE);
   if(ec.terminal && reclaim) rd=ER_ENTRY_ACTIVE;
   ec.readiness = rd;

   // entry cycle is active on a terminal reclaim, F16 liquidation arrival/CHoCH,
   // or once the terminal phase band confirms the return.
   bool cycleGo = (ec.liqObjArrival || ec.liqTrueChoch
                   || (ec.terminal && reclaim)
                   || w.phase==PH_DEMAND_RETURN || w.phase==PH_SUPPLY_RETURN
                   || (rd==ER_ENTRY_ACTIVE && ec.terminal));

   // ATTENTION MODEL (FOCUS): execution may only fire where the market is
   // actually negotiating — at the active node (conversation route) OR inside a
   // supply/demand zone. This narrows the search space from the whole terminal
   // band to the specific node/zone. If attention is disabled (InpAttentionATR<=0)
   // or no node exists, the supply/demand zone alone provides the focus.
   double node = g_state.network.nextNodePrice;
   bool nearNode = (g_cfg.attentionATR>0.0 && node!=0.0
                    && MathAbs(gClose[1]-node) <= atr*g_cfg.attentionATR);

   // ZONE-DIRECTION LAW (buy demand / sell supply, NEVER the opposite extreme):
   // an entry may only fire from the zone that matches its direction. A LONG
   // (buy) is only valid in DEMAND (activeZone==LONG); a SHORT (sell) only in
   // SUPPLY (activeZone==SHORT). Being in the OPPOSITE zone (e.g. selling at a
   // demand low) is hard-blocked — this stops the "sell the low / buy the high"
   // behaviour. With no active zone, a matching node is allowed.
   bool wrongZone = (sd.activeZone!=DIR_NONE && sd.activeZone!=w.direction);
   bool zoneOK    = (sd.activeZone!=DIR_NONE && sd.activeZone==w.direction);
   bool attentionOK = (!wrongZone) && (zoneOK || nearNode || g_cfg.attentionATR<=0.0);

   ec.entryCycleActive = (cycleGo && attentionOK);
   // entry direction = the wave's continuation/return direction (buy demand in
   // an up-wave, sell supply in a down-wave) — NOT the expansion direction.
   ec.entryDir = w.direction;

   ec.entryCycleProb = FalconClamp(
        (ec.terminal?0.35:0.0)
      + (ec.transitionComplete?0.15:0.0)
      + (ec.liqObjArrival||ec.liqTrueChoch?0.35: ec.liqSubPhase=="Terminal Liquidation"?0.20:0.0)
      + 0.15*x.executionProbability, 0, 1);

   g_state.entryCycle=ec;
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
   IE_EntryCycle(x);   // build-vs-execute brain (reads finalized intel)
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
                       const double threat,const string oppGrade,const int resCode)
{
   FalconEntryCycle ec = g_state.entryCycle;
   bool gatesOk = (conflict<=g_cfg.maxConflict && confidence>=g_cfg.minConf && threat<g_cfg.maxThreat);
   bool decentOpp = (oppGrade=="GOOD" || oppGrade=="STRONG" || oppGrade=="EXCEPTIONAL");

   if(resCode==RES_RESOLVED) return(ACT_EXIT);   // energy spent -> bank

   // EXECUTE only when the ENTRY CYCLE is active in the terminal zone AND the
   // entry direction agrees with the OWNER (ownership has flipped/confirmed to
   // this side). This is the flip-aware campaign gate: at a valid terminal the
   // owner has just flipped to the wave direction, so they match and it fires;
   // during a building counter-move ownership has NOT flipped, so entryDir !=
   // owner and the entry is blocked. No vote — direction is inherited from WHO.
   if(ec.entryCycleActive && ec.entryDir!=DIR_NONE && ec.entryDir==master && gatesOk)
      return(ec.entryDir==DIR_LONG ? ACT_BUY : ACT_SELL);

   // In the terminal zone but the entry cycle has not started yet -> armed/waiting.
   if(ec.terminal && (ec.readiness==ER_PRE_ENTRY || ec.readiness==ER_BUILDING))
      return(ACT_ATTACK);

   // Approaching the terminal, or a decent directional opportunity is forming.
   if(ec.terminal || ec.readiness==ER_EARLY || (master!=DIR_NONE && decentOpp))
      return(ACT_PREPARE);

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

   // Commit on genuine agreement + reachable exec prob + a SINGLE conviction
   // threshold (intel.confidence vs minConf) — the same threshold the Chief
   // Strategist uses. This collapses the previously-duplicate conviction gates
   // (confidence>=minConf AND a separate score>=55) into one. masterChiefScore
   // remains as a displayed composite only. Validation stays advisory.
   bool commitOk = ((ownerAgree || netAgree) && execOk && x.confidence>=g_cfg.minConf);
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

   //-- OWNERSHIP IS THE DIRECTION AUTHORITY (no voting) ------------
   // Direction EMERGES from who owns price (the flip-driven Campaign owner),
   // scaled by the curve. The four signals below are NOT voters that pick a
   // side — they are EVIDENCE measuring how strongly the market agrees with the
   // established owner. That agreement sets conviction (confidence/threat),
   // never direction.
   int ownerDir = g_state.campaign.owner;
   if(ownerDir==DIR_NONE) ownerDir = g_state.curve.ownerDir;   // fallback before first flip
   int master   = ownerDir;

   int vWave  = w.direction;          // LETRA wave        (evidence)
   int vStack = h.stackDir;           // fractal stack     (evidence)
   int vNet   = n.bias;               // network bias      (evidence)
   int vPress = n.pressureDir;        // network pressure  (evidence)

   int cast = (vWave!=0?1:0)+(vStack!=0?1:0)+(vNet!=0?1:0)+(vPress!=0?1:0);
   int forV = (vWave==master&&master!=0?1:0)+(vStack==master&&master!=0?1:0)
             +(vNet==master&&master!=0?1:0)+(vPress==master&&master!=0?1:0);

   double alignment = (cast>0?(double)forV/(double)cast*100.0:50.0); // agreement WITH owner
   double conflict  = (cast>0?(double)(cast-forV)/(double)cast*100.0:0.0);

   //-- TIME / CYCLE conflict proxy (HTF stack disagreement) --------
   double timeAlign    = h.alignment;
   double timeConflict = h.conflict;

   double residual  = x.residualEnergy;
   double attractor = x.attractorScore;
   double stackPct  = h.alignment;
   int    eligN     = n.liveCount;
   int    resCode   = x.resolutionState;

   //-- THREAT (Senseei formula + participant pressure) ------------
   double threat = FalconClamp(conflict*0.40 + residual*0.28 + timeConflict*0.12
                   + ((vPress!=DIR_NONE && vPress!=master)?18.0:0.0)
                   + (resCode==RES_PARTIALLY_RESOLVED?10.0:0.0)
                   + g_state.participants.interference*0.08
                   + ((master==DIR_LONG  && g_state.participants.seller>70.0)?12.0:0.0)
                   + ((master==DIR_SHORT && g_state.participants.buyer >70.0)?12.0:0.0),0,100);

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
   int action = DE_ChiefStrategist(master,conflict,confidence,threat,oppGrade,resCode);

   // execution direction = ownership (master). When the entry cycle fires, its
   // entryDir already equals the owner (enforced by the gate above).
   int execMaster = master;
   action     = DE_CampaignAI(action,execMaster,threat);

   // commit the meta scores first so Master Chief reads/writes the shared intel
   g_state.intel = x;
   action        = DE_MasterChief(action,execMaster); // may downgrade a fire -> PREPARE
   g_state.intel.finalDecision = FalconActionStr(action);

   g_state.exec.action = action;
   g_state.exec.master = execMaster;

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
//|  by the lot engine, gated by the session filter, protected by     |
//|  drawdown protection and the ARC + institutional + phase-composite |
//|  exit logic. (Campaign risk is owned by the PYRO Thermal Risk      |
//|  Engine; the old DRDWCT VaR/UDS trimmer has been fully removed.)   |
//|                                                                  |
//|  MULTI-CAMPAIGN: this account is HEDGING. Long and short          |
//|  campaigns coexist. Exposure is tracked PER DIRECTION on GROSS    |
//|  lots (never netted) so opposite legs never mask each other.      |
//+------------------------------------------------------------------+
#ifndef FALCON_EXEC_ENGINE_MQH
#define FALCON_EXEC_ENGINE_MQH


//==================================================================
// POSITION / MARKET STRUCTS
//==================================================================
struct EE_Position
{
   long   ticket; double lots; double entry; double sl; int direction; double pnl;
};
struct EE_Market { double spot; double atr15; double atr30; double equity; };

// event-driven: cooldown bars after a risk breach (set by subscriber)
int    ee_riskCooldown=0;
// partial take-profit per-ticket stage tracking
long   ee_tpTicket[256]; int ee_tpStage[256]; int ee_tpCount=0;

// SUBSCRIBER: react to a risk breach by blocking new entries for a few bars.
void EE_OnRiskBreach(const FalconEvent &e){ ee_riskCooldown=3; }
datetime ee_lastBarTime=0, ee_lastLongTrade=0, ee_lastShortTrade=0;
bool   ee_lastRiskOk=true;
// Institutional Exit Engine state (Symphony outer-band sweep tracking)
bool   ee_longOuterBreach=false, ee_shortOuterBreach=false;
double ee_lastWaveOrigin=0; int ee_lastWaveDir=0;

void ExecutionEngineInit()
{
   ee_lastBarTime=0; ee_lastLongTrade=0; ee_lastShortTrade=0; ee_lastRiskOk=true;
   ee_longOuterBreach=false; ee_shortOuterBreach=false; ee_lastWaveOrigin=0; ee_lastWaveDir=0;
   ee_riskCooldown=0; ee_tpCount=0;
   FalconSubscribe(EVT_RISK_BREACH, EE_OnRiskBreach);   // event-driven cooldown
}

//==================================================================
// LOT ENGINE — symbol-agnostic (uses broker tick value/size; falls
// back to the configured contract value if the symbol lacks them).
//==================================================================
double EE_ValuePerPoint()
{
   double tickVal=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double tickSz =SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(tickVal>0.0 && tickSz>0.0) return(tickVal/tickSz);   // money per 1.0 lot per price unit
   return(g_cfg.contractValue);                            // fallback (e.g. XAUUSD model)
}

double EE_ComputeLots(const double riskCash,const double entry,const double sl)
{
   double dist=MathAbs(entry-sl);
   if(dist<=0.0) return(0.0);
   double riskPerLot = dist*EE_ValuePerPoint();   // money risked per 1.0 lot at this SL distance
   if(riskPerLot<=0.0) return(0.0);
   double lots=riskCash/riskPerLot;
   double minLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double maxLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double lotStep=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(lotStep<=0) lotStep=0.01;
   if(minLot<=0)  minLot=0.01;
   lots=MathFloor(lots/lotStep)*lotStep;
   if(lots<minLot) lots=minLot;
   if(maxLot>0 && lots>maxLot) lots=maxLot;
   if(g_cfg.maxLots>0 && lots>g_cfg.maxLots) lots=g_cfg.maxLots;   // hard safety cap
   int volDigits=(lotStep>=1.0?0:lotStep>=0.1?1:2);
   return(NormalizeDouble(lots,volDigits));
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
      p.pnl=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP); // commission is per-deal in MT5
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
   req.type_filling=ORDER_FILLING_IOC; req.type_time=ORDER_TIME_GTC; req.comment="FALCON PARTIAL";
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
//==================================================================
// TERMINAL-AWARE STOP & OWNER-DRIVEN TARGET (ODDE)
//   Stop sits just beyond the swept terminal extreme (the supply/demand
//   that price liquidated into), capped so risk stays sane. Target is
//   inherited from the owner curve hierarchy (FRZ / wave objective),
//   with secondary/extended targets for partial scale-out.
//==================================================================
double EE_TerminalStop(const int dir,const double entry,const double atr)
{
   int win=g_cfg.structLen*2+g_cfg.pivotLen;
   double sl;
   if(dir==DIR_LONG)
   {
      double sweptLow = FalconLowest(1,win);
      double zoneLow  = (g_state.supplyDemand.demandBot!=0? g_state.supplyDemand.demandBot
                        : g_state.wave.flipBot!=0? g_state.wave.flipBot : sweptLow);
      sl = MathMin(sweptLow, zoneLow) - atr*0.5;
      if(entry-sl > atr*6.0) sl = entry - atr*3.0;   // cap risk if extreme is far
      if(sl>=entry) sl = entry - atr*1.5;
   }
   else
   {
      double sweptHigh= FalconHighest(1,win);
      double zoneHigh = (g_state.supplyDemand.supplyTop!=0? g_state.supplyDemand.supplyTop
                        : g_state.wave.flipTop!=0? g_state.wave.flipTop : sweptHigh);
      sl = MathMax(sweptHigh, zoneHigh) + atr*0.5;
      if(sl-entry > atr*6.0) sl = entry + atr*3.0;
      if(sl<=entry) sl = entry + atr*1.5;
   }
   return(sl);
}

void EE_OwnerTargets(const int dir,const double entry,const double atr,double &t1,double &t2,double &t3)
{
   // DESTINATION AUTHORITY (WHERE): the conversation route's next node is the
   // primary target when it sits ahead of price in the trade direction. T2/T3
   // extend via the owner-return target (FRZ) and the wave objective (ODDE). If
   // no valid node, fall back to wave objective.
   double obj  = g_state.wave.objective;
   double frz  = g_state.frz.targetPrice;
   double node = g_state.network.nextNodePrice;     // <- conversation route destination
   if(dir==DIR_LONG)
   {
      bool nodeAhead = (node>entry);
      t1 = nodeAhead ? node : (obj>entry ? obj : entry + atr*3.0);
      t2 = MathMax(t1, (obj>entry ? obj : (frz>entry?frz:entry+atr*5.0)));
      t3 = MathMax(t2, entry + atr*8.0);
   }
   else
   {
      bool nodeAhead = (node>0 && node<entry);
      t1 = nodeAhead ? node : (obj<entry && obj>0 ? obj : entry - atr*3.0);
      t2 = MathMin(t1, (obj<entry && obj>0 ? obj : (frz<entry && frz>0 ? frz : entry-atr*5.0)));
      t3 = MathMin(t2, entry - atr*8.0);
   }
}

void EE_HandleEntries(const EE_Market &m)
{
   int action=g_state.exec.action;
   int master=g_state.exec.master;
   datetime barTime=gTime[0];

   // Firing actions: BUY / SELL / SCALE enter in the (entry-cycle) master
   // direction. BUY/SELL are now emitted ONLY when the Entry Cycle Engine
   // reports the entry cycle is active in the terminal zone, so they are the
   // precise execution signals. ATTACK = in terminal, armed, waiting for the
   // cycle to begin -> does NOT fire. PREPARE/WAIT/NO_TRADE/DEFEND/EXIT fire nothing.
   bool wantBuy  = ((action==ACT_BUY||action==ACT_SCALE) && master==DIR_LONG);
   bool wantSell = ((action==ACT_SELL||action==ACT_SCALE) && master==DIR_SHORT);

   if(!wantBuy && !wantSell) return;
   if(!EE_IsTradeTime()) return;
   if(g_cfg.blockIfBreach && !ee_lastRiskOk) return;
   if(ee_riskCooldown>0) return;   // event-driven: cooling off after a risk breach

   // LATE / NO-ROOM GUARD (symmetric for both sides): never OPEN a fresh
   // campaign into exhaustion — no buying the top, no selling the bottom.
   // Blocked when the wave is near terminal or there is little room to the
   // owner target. SCALE (adding to a winner) is exempt.
   if(action!=ACT_SCALE)
   {
      bool tooLate = (g_state.wave.completion    >= g_cfg.maxEntryComplete);
      bool noRoom  = (g_state.convexity.geometryCapacity < g_cfg.minEntryRoomPct);
      if(tooLate || noRoom){ wantBuy=false; wantSell=false; }
   }
   if(!wantBuy && !wantSell) return;

   double atr=g_state.physics.atr;
   double close1=gClose[1];
   double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   double riskCash=equity*g_cfg.riskPercent*0.01;
   // CONVICTION SIZING: cross-TF agreement (Wave Matrix) scales the risk. Full
   // size on strong consensus, reduced size on cross-TF noise. (SCALE is exempt.)
   if(action!=ACT_SCALE)
   {
      double convFactor = FalconClamp(0.40 + 0.60*g_state.waveMatrix.agreement/100.0, 0.40, 1.0);
      riskCash *= convFactor;
   }

   if(wantBuy && ee_lastLongTrade!=barTime)
   {
      double entry=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double sl=EE_TerminalStop(DIR_LONG,entry,atr);
      double t1,t2,t3; EE_OwnerTargets(DIR_LONG,entry,atr,t1,t2,t3);
      double lots=EE_ComputeLots(riskCash,entry,sl);
      if(sl>0 && entry>sl && lots>0 && EE_SendMarketOrder(+1,lots,sl,"FALCON "+FalconActionStr(action)+" L"))
      {
         ee_lastLongTrade=barTime;
         g_state.exec.entry=entry; g_state.exec.stop=sl;
         g_state.exec.target=t1; g_state.exec.target2=t2; g_state.exec.target3=t3;
         g_state.exec.lots=lots; g_state.exec.riskCash=riskCash;
         g_state.exec.reward=(MathAbs(entry-sl)>1e-10)?MathAbs(t1-entry)/MathAbs(entry-sl):0.0;
      }
   }
   if(wantSell && ee_lastShortTrade!=barTime)
   {
      double entry=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double sl=EE_TerminalStop(DIR_SHORT,entry,atr);
      double t1,t2,t3; EE_OwnerTargets(DIR_SHORT,entry,atr,t1,t2,t3);
      double lots=EE_ComputeLots(riskCash,entry,sl);
      if(sl>0 && sl>entry && lots>0 && EE_SendMarketOrder(-1,lots,sl,"FALCON "+FalconActionStr(action)+" S"))
      {
         ee_lastShortTrade=barTime;
         g_state.exec.entry=entry; g_state.exec.stop=sl;
         g_state.exec.target=t1; g_state.exec.target2=t2; g_state.exec.target3=t3;
         g_state.exec.lots=lots; g_state.exec.riskCash=riskCash;
         g_state.exec.reward=(MathAbs(entry-sl)>1e-10)?MathAbs(t1-entry)/MathAbs(entry-sl):0.0;
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
// PARTIAL TAKE-PROFIT / SCALE-OUT — bank a third at T1, a third at T2,
// and the remainder at T3 (owner-driven targets). Per-ticket stage is
// tracked so each level fires once.  (state declared with the globals above)
//==================================================================
int EE_TPSlot(const long ticket)
{
   for(int i=0;i<ee_tpCount;i++) if(ee_tpTicket[i]==ticket) return(i);
   if(ee_tpCount<256){ ee_tpTicket[ee_tpCount]=ticket; ee_tpStage[ee_tpCount]=0; ee_tpCount++; return(ee_tpCount-1); }
   return(0);
}

void EE_ManagePartialTP()
{
   double t1=g_state.exec.target, t2=g_state.exec.target2, t3=g_state.exec.target3;
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID), ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   int total=PositionsTotal();
   for(int i=0;i<total;i++)
   {
      ulong ticket=PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=g_cfg.magic) continue;
      long type=PositionGetInteger(POSITION_TYPE);
      double vol=PositionGetDouble(POSITION_VOLUME);
      int slot=EE_TPSlot((long)ticket);
      int stage=ee_tpStage[slot];

      if(type==POSITION_TYPE_BUY)
      {
         if(stage<1 && t1>0 && bid>=t1){ if(EE_ClosePartial(ticket,vol*0.34)) ee_tpStage[slot]=1; }
         else if(stage<2 && t2>0 && bid>=t2){ if(EE_ClosePartial(ticket,vol*0.50)) ee_tpStage[slot]=2; }
         else if(stage<3 && t3>0 && bid>=t3){ if(EE_CloseFull(ticket)) ee_tpStage[slot]=3; }
      }
      else
      {
         if(stage<1 && t1>0 && ask<=t1){ if(EE_ClosePartial(ticket,vol*0.34)) ee_tpStage[slot]=1; }
         else if(stage<2 && t2>0 && ask<=t2){ if(EE_ClosePartial(ticket,vol*0.50)) ee_tpStage[slot]=2; }
         else if(stage<3 && t3>0 && ask<=t3){ if(EE_CloseFull(ticket)) ee_tpStage[slot]=3; }
      }
   }
}

//==================================================================
// MASTER ENTRY — Execution Engine pipeline step
//==================================================================
void ExecutionEngineRun()
{
   EE_Market m; EE_BuildMarket(m);
   EE_UpdateExposure(m);
   if(ee_riskCooldown>0) ee_riskCooldown--;

   // ---- DRDWCT RISK ENGINE FULLY REMOVED ----
   // The old VaR/UDS per-campaign trimmer (which closed open winners) is gone.
   // Campaign risk is now owned by the PYRO Thermal Risk Engine. This layer
   // only handles: per-trade stop sizing (lot engine), drawdown protection
   // (equity kill-switch), and decision-layer DEFEND/EXIT.
   bool ddOk = EE_DrawdownProtection();   // equity kill-switch only (no trimming)
   ee_lastRiskOk = ddOk;
   g_state.exec.riskOk = ee_lastRiskOk;
   g_state.exec.sessionOpen = EE_IsTradeTime();
   if(!ddOk) FalconPublish(EVT_RISK_BREACH,0.0);

   // ---- TRAILING + PARTIAL TAKE-PROFIT (manage open winners) ----
   // When Symphony is the active authority, it owns entries AND exits (ARC +
   // institutional + phase composite) with its own stop placement, so FALCON's
   // trailing/partial/exit/entry block is suppressed to avoid double-trading.
   // Drawdown protection + exposure snapshot always run.
   if(!g_cfg.useSymphony)
   {
      EE_Trailing();
      EE_ManagePartialTP();

      // ---- INSTITUTIONAL band tracking, then EXITS, then ENTRIES ----
      EE_UpdateInstitutional();
      EE_HandleExits();
      EE_HandleEntries(m);
   }

   // refresh exposure snapshot after actions
   EE_UpdateExposure(m);
}

#endif // FALCON_EXEC_ENGINE_MQH
//+------------------------------------------------------------------+

//  ===== Engines/ThermalRiskEngine.mqh =====
//+------------------------------------------------------------------+
//|  FALCON OS — Execution Layer : ThermalRiskEngine.mqh            |
//|  PYRO — Campaign Thermodynamics Risk Engine                     |
//|                                                                  |
//|  A risk model built specifically for how THIS algo trades:       |
//|  precision Phase 3/4 entries that STACK into a directional       |
//|  campaign (a fleet of correlated positions on one instrument).   |
//|                                                                  |
//|  The fleet is treated as a physical body that carries HEAT.      |
//|                                                                  |
//|    heat = adverseExcursion(blended basket, in ATR)               |
//|           x fragility(stackCount, totalLots)                     |
//|                                                                  |
//|  A WINNING basket runs near-zero heat regardless of size (house  |
//|  money). An UNDERWATER, heavily-stacked basket overheats fast.   |
//|  Heat is the single scalar that governs everything:              |
//|                                                                  |
//|    OPEN      cool        -> full-size stacks allowed             |
//|    THROTTLED warming     -> each new stack shrinks with heat     |
//|    FROZEN    hot/maxed    -> no new stacks (incl. anti-martingale |
//|                             freeze: no averaging-down past N)     |
//|    DE-RISK   critical     -> flatten the campaign (catastrophe)   |
//|                                                                  |
//|  Plus a basket-organism manager (breakeven-lock the whole fleet  |
//|  once it is BasketLockATR in profit) and a dual-campaign          |
//|  THERMOSTAT: long-heat and short-heat are tracked separately     |
//|  (never netted), and if BOTH overheat at once (whipsaw trap) all  |
//|  admissions freeze. Account heat = equity drawdown vs peak.       |
//|                                                                  |
//|  KEY DIFFERENCE vs the old DRDWCT engine: PYRO NEVER trims a      |
//|  winning campaign. Heat is ~0 while in profit, so the only forced |
//|  close is a TRUE runaway (deeply underwater + large) at critical  |
//|  heat — exactly when a stacking book must be cut.                 |
//|                                                                  |
//|  Included AFTER ExecutionEngine (reuses EE_CollectPositions /     |
//|  EE_ModifySL / EE_CloseFull) and BEFORE SymphonyEngine (which     |
//|  calls TR_AdmitLots before every entry).                         |
//+------------------------------------------------------------------+
#ifndef FALCON_THERMAL_RISK_ENGINE_MQH
#define FALCON_THERMAL_RISK_ENGINE_MQH


//==================================================================
// MODULE STATE — cross-bar memory for velocity / cooling / lock
//==================================================================
double tr_prevHeat[2]   = {0.0,0.0};
double tr_prevPnL[2]    = {0.0,0.0};
double tr_equityPeak    = 0.0;

void ThermalRiskInit()
{
   tr_prevHeat[0]=0.0; tr_prevHeat[1]=0.0;
   tr_prevPnL[0]=0.0;  tr_prevPnL[1]=0.0;
   tr_equityPeak = AccountInfoDouble(ACCOUNT_EQUITY);
}

//==================================================================
// 1) BUILD CAMPAIGN — aggregate the directional fleet into a basket.
//==================================================================
void TR_BuildCampaign(const int dir,FalconThermalCampaign &c)
{
   EE_Position pos[64];
   int n = EE_CollectPositions(pos, dir);

   double atr = MathMax(g_state.physics.atr, 1e-10);
   double lots=0.0, wEntrySum=0.0, pnl=0.0, swap=0.0;
   for(int i=0;i<n;i++)
   {
      lots      += pos[i].lots;
      wEntrySum += pos[i].entry*pos[i].lots;
      pnl       += pos[i].pnl;          // profit + swap (commission excluded — MT5 per-deal)
   }

   c.dir         = dir;
   c.stackCount  = n;
   c.totalLots   = lots;
   c.blendedEntry= (lots>0.0 ? wEntrySum/lots : 0.0);
   c.breakeven   = c.blendedEntry;       // swap drift folded into PnL valuation
   c.unrealizedPnL = pnl;

   // valuation price = the side we would CLOSE at
   double px = (dir==DIR_LONG ? SymbolInfoDouble(_Symbol,SYMBOL_BID)
                              : SymbolInfoDouble(_Symbol,SYMBOL_ASK));
   double excursion = 0.0;
   if(c.blendedEntry>0.0)
      excursion = (dir==DIR_LONG ? (px - c.blendedEntry) : (c.blendedEntry - px)) / atr;
   c.favorableATR = MathMax(0.0,  excursion);   // in profit
   c.adverseATR   = MathMax(0.0, -excursion);   // underwater

   c.exposureLoad = (g_cfg.maxCampaignLots>0.0 ? c.totalLots/g_cfg.maxCampaignLots : 0.0);
   c.stackLoad    = (g_cfg.maxStacks>0        ? (double)c.stackCount/(double)g_cfg.maxStacks : 0.0);
}

//==================================================================
// 2) HEAT — the master scalar. Adverse excursion amplified by the
//    basket's fragility. In profit, heat collapses to a small
//    exposure baseline (so a big WINNER is not treated as risky).
//==================================================================
void TR_ComputeHeat(const int idx,FalconThermalCampaign &c)
{
   double adverseLoad = (g_cfg.heatAdverseSpan>0.0 ? c.adverseATR/g_cfg.heatAdverseSpan : 0.0);
   c.fragility = 1.0 + 0.5*MathMin(c.exposureLoad,2.0) + 0.5*MathMin(c.stackLoad,2.0);

   double heat = FalconClamp(adverseLoad*c.fragility, 0.0, 2.0);
   // even a profitable book carries a soft exposure baseline (throttles further
   // stacking once it is large) — but never enough to force a de-risk.
   double baseHeat = 0.40*MathMax(c.exposureLoad, c.stackLoad);
   heat = MathMax(heat, MathMin(baseHeat, g_cfg.heatFreeze*0.9));
   if(c.stackCount==0) heat=0.0;

   c.heat         = heat;
   c.heatVelocity = heat - tr_prevHeat[idx];
   c.coolingRate  = c.unrealizedPnL - tr_prevPnL[idx];
   tr_prevHeat[idx]= heat;
   tr_prevPnL[idx] = c.unrealizedPnL;
}

//==================================================================
// 3) ADMISSION — may this campaign accept a new stack, and how big?
//    (continuous lot scale 0..1). Anti-martingale freeze on adding
//    into a deepening underwater basket past MaxAvgDownStacks.
//==================================================================
void TR_Admission(FalconThermalCampaign &c,const FalconThermostat &th)
{
   int    adm   = ADM_OPEN;
   double scale = 1.0;

   if(c.heat >= g_cfg.heatCritical)      { adm=ADM_DERISK;    scale=0.0; }
   else if(c.heat >= g_cfg.heatFreeze)   { adm=ADM_FROZEN;    scale=0.0; }
   else if(c.heat >= g_cfg.heatThrottle)
   {
      adm=ADM_THROTTLED;
      double span=MathMax(g_cfg.heatFreeze-g_cfg.heatThrottle,1e-6);
      scale=FalconClamp((g_cfg.heatFreeze-c.heat)/span,0.0,1.0);   // 1 -> 0 across the band
   }

   // ANTI-MARTINGALE: never deepen an underwater basket past the limit.
   if(c.adverseATR>0.10 && c.stackCount>=g_cfg.maxAvgDownStacks)
   { scale=0.0; if(adm<ADM_FROZEN) adm=ADM_FROZEN; }

   // hard ceilings
   if(c.stackCount>=g_cfg.maxStacks)          { scale=0.0; if(adm<ADM_FROZEN) adm=ADM_FROZEN; }
   if(c.totalLots >=g_cfg.maxCampaignLots)    { scale=0.0; if(adm<ADM_FROZEN) adm=ADM_FROZEN; }

   // PORTFOLIO THERMOSTAT: whipsaw lock or account-heat freeze all admissions.
   if(th.whipsawLock || th.accountHeat>=1.0)  { scale=0.0; if(adm<ADM_FROZEN) adm=ADM_FROZEN; }

   c.admission     = adm;
   c.admitLotScale = FalconClamp(scale,0.0,1.0);
}

//==================================================================
// 4) BASKET MANAGER — the ONLY forced close: a CRITICAL-heat catastrophe
//    flatten (deeply underwater + large). Winners are never trimmed.
//    Breakeven + trailing are owned by the TALON grip (Symphony layer).
//==================================================================
void TR_ManageBasket(const int idx,FalconThermalCampaign &c)
{
   int dir = c.dir;
   c.breakevenLocked = false;
   if(c.stackCount==0) return;

   // --- CATASTROPHE STOP: thermal runaway -> flatten this campaign ---
   if(c.admission==ADM_DERISK)
   {
      int total=PositionsTotal();
      for(int i=total-1;i>=0;i--)
      {
         ulong ticket=PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
         if(PositionGetInteger(POSITION_MAGIC)!=g_cfg.magic) continue;
         long type=PositionGetInteger(POSITION_TYPE);
         int  pdir=(type==POSITION_TYPE_BUY?DIR_LONG:DIR_SHORT);
         if(pdir==dir) EE_CloseFull(ticket);
      }
      FalconPublish(EVT_RISK_BREACH, c.heat, "PYRO thermal runaway flatten");
      g_state.exec.exitState=XS_DD_FLATTEN;
   }
}

//==================================================================
// MASTER — Thermal Risk pipeline step. Build both campaigns, compute
// the portfolio thermostat, set admissions, then manage the baskets.
//==================================================================
void ThermalRiskUpdate()
{
   FalconRisk r;

   // 1) build + heat for each direction
   TR_BuildCampaign(DIR_LONG,  r.campaign[0]);
   TR_BuildCampaign(DIR_SHORT, r.campaign[1]);
   TR_ComputeHeat(0, r.campaign[0]);
   TR_ComputeHeat(1, r.campaign[1]);

   // 2) PORTFOLIO THERMOSTAT (never nets opposite directions)
   FalconThermostat th;
   th.longHeat    = r.campaign[0].heat;
   th.shortHeat   = r.campaign[1].heat;
   th.combinedHeat= th.longHeat + th.shortHeat;
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq>tr_equityPeak) tr_equityPeak=eq;
   double ddPct=(tr_equityPeak>0.0 ? (tr_equityPeak-eq)/tr_equityPeak*100.0 : 0.0);
   th.equityPeak  = tr_equityPeak;
   th.accountHeat = FalconClamp(ddPct/MathMax(g_cfg.acctHeatDDPct,1e-6),0.0,1.0);
   // whipsaw trap: BOTH books warm at the same time
   th.whipsawLock = (th.longHeat>=g_cfg.heatThrottle && th.shortHeat>=g_cfg.heatThrottle);
   r.thermostat   = th;

   // 3) admission for each campaign (consults the thermostat)
   TR_Admission(r.campaign[0], th);
   TR_Admission(r.campaign[1], th);

   // commit shared state BEFORE managing (admissions drive the basket manager)
   g_state.risk = r;

   // 4) catastrophe-only basket management (TALON owns breakeven + trailing)
   TR_ManageBasket(0, g_state.risk.campaign[0]);
   TR_ManageBasket(1, g_state.risk.campaign[1]);
}

//==================================================================
// PUBLIC GATE — Symphony calls this before EVERY entry. Returns the
// admitted lot size (0 = entry denied). Scales the proposed size by
// the campaign's thermal admission and caps it to the remaining
// per-campaign lot budget.
//==================================================================
double TR_AdmitLots(const int dir,const double proposedLots)
{
   if(!g_cfg.useThermalRisk) return(proposedLots);
   if(proposedLots<=0.0)     return(0.0);

   int idx = (dir==DIR_LONG ? 0 : 1);
   FalconThermalCampaign c = g_state.risk.campaign[idx];

   if(c.admission==ADM_FROZEN || c.admission==ADM_DERISK) return(0.0);
   if(c.stackCount>=g_cfg.maxStacks)                      return(0.0);

   double scaled = proposedLots*c.admitLotScale;
   double remaining = g_cfg.maxCampaignLots - c.totalLots;
   if(remaining<=0.0) return(0.0);
   if(scaled>remaining) scaled=remaining;

   // normalise to broker volume step
   double lotStep=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double minLot =SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   if(lotStep<=0) lotStep=0.01;
   if(minLot<=0)  minLot=0.01;
   scaled = MathFloor(scaled/lotStep)*lotStep;
   if(scaled<minLot)
   {
      // only allow the floor lot if the campaign is OPEN/THROTTLED and has room
      if(c.admission==ADM_OPEN && remaining>=minLot) scaled=minLot;
      else return(0.0);
   }
   if(g_cfg.maxLots>0 && scaled>g_cfg.maxLots) scaled=g_cfg.maxLots;
   int volDigits=(lotStep>=1.0?0:lotStep>=0.1?1:2);
   return(NormalizeDouble(scaled,volDigits));
}

#endif // FALCON_THERMAL_RISK_ENGINE_MQH
//+------------------------------------------------------------------+

//  ===== Engines/SymphonyEngine.mqh =====
//+------------------------------------------------------------------+
//|  FALCON OS — Execution Layer : SymphonyEngine.mqh               |
//|  Source: Symphony (Phase Engine + Phase 3/4 Entries + ARC/Inst) |
//|                                                                  |
//|  This is the PRECISION ENTRY/EXIT AUTHORITY.                     |
//|                                                                  |
//|  The user's Symphony EA had the most precise entries and stop    |
//|  placement, so its proven curvature/retracement Phase Engine is  |
//|  ported here verbatim (adapted to FALCON's shared series + ATR + |
//|  pivot helpers) and made the primary order logic when            |
//|  g_cfg.useSymphony is true.                                      |
//|                                                                  |
//|    • Impulse + Phases 1..4 (retracement-fraction model)          |
//|    • Entries: Phase 3 + Phase 4 only (long & short)              |
//|    • Stops:  anchorLow/High ± atr*0.25  (Symphony placement)     |
//|    • Lots:   riskCash / (dist * contractValue), capped maxLots   |
//|    • Exits:  ARC exhaust + institutional outer-band sweep +      |
//|              phase-change composite                              |
//|                                                                  |
//|  This module REUSES the Execution Engine order helpers           |
//|  (EE_SendMarketOrder / EE_CloseFull / EE_IsTradeTime) so it must |
//|  be included AFTER ExecutionEngine.mqh. It does NOT port         |
//|  Symphony's DRDWCT risk engine (removed at user request).        |
//+------------------------------------------------------------------+
#ifndef FALCON_SYMPHONY_ENGINE_MQH
#define FALCON_SYMPHONY_ENGINE_MQH


//==================================================================
// MODULE STATE — Symphony phase engine (one instance, shared)
//==================================================================
// Pivot history
double   sym_lastPivotPrice = 0.0;
int      sym_lastPivotShift = -1;
int      sym_lastPivotDir   = 0;   // 1 = high, -1 = low, 0 = none
double   sym_prevPivotPrice = 0.0;
int      sym_prevPivotShift = -1;
int      sym_prevPivotDir   = 0;

// Impulse / mode
int      sym_mode           = 0;   // -1 short, 1 long, 0 none
double   sym_anchorHigh      = 0.0;
double   sym_anchorLow       = 0.0;
int      sym_anchorHighShift = -1;
int      sym_anchorLowShift  = -1;

// Phases
int      sym_phaseShort      = 0;
int      sym_phaseLong       = 0;
int      sym_prevPhaseShort  = 0;
int      sym_prevPhaseLong   = 0;

// Flipzone / inducement
double   sym_shortInducPrice = 0.0;
double   sym_shortInducLow   = 0.0;
double   sym_shortInducHigh  = 0.0;
double   sym_longInducPrice  = 0.0;
double   sym_longInducLow    = 0.0;
double   sym_longInducHigh   = 0.0;

// Pre-Conv seen flags (per impulse)
bool     sym_shortPreConvSeen = false;
bool     sym_longPreConvSeen  = false;

// ARC v2 state
double   sym_arcLong  = 0.0;
double   sym_arcShort = 0.0;

// Institutional outer-band sweep flags
bool     sym_longOuterBreachSeen  = false;
bool     sym_shortOuterBreachSeen = false;

// One trade per direction per bar
datetime sym_lastLongTradeTime  = 0;
datetime sym_lastShortTradeTime = 0;

// Bridge: previous canonical phase published into g_state.wave (for prevPhase)
int      sym_bridgePrevPhase    = PH_TRANSITION;

// TALON grip — campaign-level structural trailing anchors + breakeven flags
double   talon_anchorLong  = 0.0;   // ratcheting higher-low the long grip rides
double   talon_anchorShort = 0.0;   // ratcheting lower-high the short grip rides
bool     talon_beLong  = false;     // long campaign breakeven earned
bool     talon_beShort = false;     // short campaign breakeven earned

// Re-entry lockout — once a campaign for the CURRENT impulse has been closed
// (by trail-stop or composite exit), block re-entry in that direction until a
// FRESH impulse forms. Stops the "exit then immediately re-enter the same leg"
// churn. Reset to 0 whenever a new impulse is created (new anchor = new campaign).
double   sym_exitedLongAnchor  = 0.0;   // nonzero => long re-entry locked for this impulse
double   sym_exitedShortAnchor = 0.0;   // nonzero => short re-entry locked for this impulse
bool     sym_longCampaignOpen  = false; // a long  campaign is currently open
bool     sym_shortCampaignOpen = false; // a short campaign is currently open

//==================================================================
// INIT — reset all Symphony phase state
//==================================================================
void SymphonyInit()
{
   sym_lastPivotPrice = 0.0; sym_lastPivotShift = -1; sym_lastPivotDir = 0;
   sym_prevPivotPrice = 0.0; sym_prevPivotShift = -1; sym_prevPivotDir = 0;

   sym_mode = 0;
   sym_anchorHigh = 0.0; sym_anchorLow = 0.0;
   sym_anchorHighShift = -1; sym_anchorLowShift = -1;

   sym_phaseShort = 0; sym_phaseLong = 0;
   sym_prevPhaseShort = 0; sym_prevPhaseLong = 0;

   sym_shortInducPrice = 0.0; sym_shortInducLow = 0.0; sym_shortInducHigh = 0.0;
   sym_longInducPrice  = 0.0; sym_longInducLow  = 0.0; sym_longInducHigh  = 0.0;

   sym_shortPreConvSeen = false; sym_longPreConvSeen = false;

   sym_arcLong = 0.0; sym_arcShort = 0.0;
   sym_longOuterBreachSeen = false; sym_shortOuterBreachSeen = false;

   sym_lastLongTradeTime = 0; sym_lastShortTradeTime = 0;
   sym_bridgePrevPhase   = PH_TRANSITION;
   talon_anchorLong = 0.0; talon_anchorShort = 0.0;
   talon_beLong = false;   talon_beShort = false;
   sym_exitedLongAnchor = 0.0; sym_exitedShortAnchor = 0.0;
   sym_longCampaignOpen = false; sym_shortCampaignOpen = false;
}

//==================================================================
// LOT ENGINE — Symphony contract-value model
//   riskPerLot = dist * contractValue   (XAUUSD: dist*100 == $1850 for 18.5)
//   capped by broker limits + g_cfg.maxLots safety cap.
//==================================================================
double Sym_ComputeLots(const double riskCash,const double entry,const double sl)
{
   double dist = MathAbs(entry - sl);
   if(dist <= 0.0) return(0.0);

   double riskPerLot = dist * g_cfg.contractValue;
   if(riskPerLot <= 0.0) return(0.0);

   double lots = riskCash / riskPerLot;

   double minLot  = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(lotStep<=0) lotStep=0.01;
   if(minLot<=0)  minLot=0.01;

   lots = MathFloor(lots/lotStep)*lotStep;
   if(lots < minLot) lots = minLot;
   if(maxLot>0 && lots>maxLot) lots = maxLot;
   if(g_cfg.maxLots>0 && lots>g_cfg.maxLots) lots = g_cfg.maxLots;   // hard safety cap

   int volDigits=(lotStep>=1.0?0:lotStep>=0.1?1:2);
   return(NormalizeDouble(lots,volDigits));
}

//==================================================================
// BRIDGE — SYMPHONY IS THE SINGLE PHASE/DIRECTION SOURCE OF TRUTH
//------------------------------------------------------------------
// The Market Engine still OBSERVES geometry/physics (sub-scores, energy,
// recursion, cycle extremes) — those are descriptors, not a phase engine.
// But the PHASE ENGINE itself must exist exactly once. This bridge maps
// Symphony's impulse + Phase 1..4 model onto the canonical FalconWave schema
// (phase / direction / flip zone / origin / extreme / objective / completion /
// dominanceTransfer) so EVERY downstream subsystem reasons on the SAME engine
// Symphony trades:
//   • Memory     — campaign OWNERSHIP flips with Symphony (phase 3 = return).
//   • Intelligence — energy/belief/forecast/entry-cycle read Symphony phases.
//   • Decision   — master DIRECTION = Symphony mode (via campaign owner).
//   • Execution  — stops/targets/exit phase-logic read Symphony flip/origin.
//   • Visualization — every tab shows Symphony's phase truth.
// No second phase truth survives downstream.
//
// PHASE MAP (direction-aware):
//   mode 0 / phase 0 -> PH_TRANSITION
//   phase 1 (early impulse)        -> PH_EXPANSION
//   phase 2 (retracing)            -> PH_RETRACEMENT
//   phase 3 (return into zone)     -> PH_DEMAND_RETURN (long) / PH_SUPPLY_RETURN (short)
//   phase 4 (breakout/new extreme) -> PH_NEW_HIGH (long) / PH_NEW_LOW (short)
//==================================================================
void SymphonyBridgeToWave()
{
   FalconWave w = g_state.wave;   // preserve Market-Engine geometry descriptors

   int dir = (sym_mode==1 ? DIR_LONG : sym_mode==-1 ? DIR_SHORT : DIR_NONE);
   int p   = (dir==DIR_LONG ? sym_phaseLong : dir==DIR_SHORT ? sym_phaseShort : 0);

   int ph;
   if(dir==DIR_NONE || p<=0) ph = PH_TRANSITION;
   else if(p==1)             ph = PH_EXPANSION;
   else if(p==2)             ph = PH_RETRACEMENT;
   else if(p==3)             ph = (dir==DIR_LONG ? PH_DEMAND_RETURN : PH_SUPPLY_RETURN);
   else /* p==4 */           ph = (dir==DIR_LONG ? PH_NEW_HIGH      : PH_NEW_LOW);

   // completion derived from the phase ladder (single, consistent mapping)
   double comp = (p<=0?5.0 : p==1?25.0 : p==2?45.0 : p==3?70.0 : 92.0);

   // flip zone / anchors — inducement zone tightens the band when present
   double aHi = sym_anchorHigh, aLo = sym_anchorLow;
   double flipTop = (aHi!=0.0 ? aHi : w.flipTop);
   double flipBot = (aLo!=0.0 ? aLo : w.flipBot);
   if(dir==DIR_LONG && (sym_longInducLow!=0.0 || sym_longInducHigh!=0.0))
   { flipBot = sym_longInducLow; flipTop = sym_longInducHigh; }
   if(dir==DIR_SHORT && (sym_shortInducLow!=0.0 || sym_shortInducHigh!=0.0))
   { flipBot = sym_shortInducLow; flipTop = sym_shortInducHigh; }

   double origin   = (dir==DIR_LONG ? aLo : dir==DIR_SHORT ? aHi : w.origin);
   double extreme  = (dir==DIR_LONG ? aHi : dir==DIR_SHORT ? aLo : w.extreme);
   double objective= (dir==DIR_LONG  && sym_arcLong >0.0 ? sym_arcLong
                     : dir==DIR_SHORT && sym_arcShort>0.0 ? sym_arcShort : w.objective);

   // dominanceTransfer drives the campaign OWNERSHIP flip — keyed to Symphony so
   // ownership/direction flips exactly when Symphony enters the return (phase 3).
   double dom = (p>=3 ? 60.0 : p==2 ? 30.0 : 0.0);

   // ---- commit the canonical phase-engine fields (override ME FSM result) ----
   w.prevPhase         = sym_bridgePrevPhase;
   w.phase             = ph;
   w.direction         = dir;
   w.flipTop           = flipTop;
   w.flipBot           = flipBot;
   w.origin            = origin;
   w.extreme           = extreme;
   w.objective         = objective;
   w.completion        = comp;
   w.dominanceTransfer = dom;

   // display mirror
   w.symMode       = sym_mode;
   w.symPhaseLong  = sym_phaseLong;
   w.symPhaseShort = sym_phaseShort;

   g_state.wave = w;

   if(ph != sym_bridgePrevPhase) FalconPublish(EVT_PHASE_CHANGE, ph, FalconPhaseStr(ph));
   sym_bridgePrevPhase = ph;
}

//==================================================================
// PHASE ENGINE — IMPULSE + PHASES (1..4)   [ported from Symphony]
//   Uses FALCON shared series (gClose/gHigh/gLow, shift 1 = last
//   closed bar), FalconATR and FalconIsPivotHigh/Low. Config from
//   g_cfg (pivotLen / impulseAtrMult / retrMin / retrMax /
//   inducLookback / inducZoneWidth).
//==================================================================
void SymphonyUpdatePhases()
{
   int barsAvail = FalconBars();
   int pivotLen  = g_cfg.pivotLen;
   if(barsAvail <= (2*pivotLen + 5)) return;

   int    shiftNow = 1;
   double closeNow = gClose[shiftNow];
   double atrRef   = FalconATR(shiftNow);
   if(atrRef<=0.0) atrRef = FalconATR(0);

   int    centerShift = pivotLen + 1;
   int    pivotDir    = 0;
   double pivotPrice  = 0.0;
   int    pivotShift  = -1;

   if(centerShift < barsAvail - pivotLen)
   {
      if(FalconIsPivotHigh(centerShift,pivotLen))
      {
         pivotDir   = 1;
         pivotPrice = gHigh[centerShift];
         pivotShift = centerShift;
      }
      else if(FalconIsPivotLow(centerShift,pivotLen))
      {
         pivotDir   = -1;
         pivotPrice = gLow[centerShift];
         pivotShift = centerShift;
      }
   }

   // SHORT impulse: last high -> new low
   if(pivotDir == -1 && sym_lastPivotDir == 1)
   {
      double r = sym_lastPivotPrice - pivotPrice;
      if(r > atrRef * g_cfg.impulseAtrMult)
      {
         sym_mode            = -1;
         sym_anchorHigh      = sym_lastPivotPrice;
         sym_anchorHighShift = sym_lastPivotShift;
         sym_anchorLow       = pivotPrice;
         sym_anchorLowShift  = pivotShift;

         sym_phaseShort      = 1;
         sym_phaseLong       = 0;
         // fresh short impulse => new campaign allowed (clear short re-entry lock)
         sym_exitedShortAnchor = 0.0; sym_shortCampaignOpen = false;

         sym_shortPreConvSeen = false;
         sym_longPreConvSeen  = false;

         sym_shortInducPrice = 0.0; sym_shortInducLow = 0.0; sym_shortInducHigh = 0.0;
         sym_longInducPrice  = 0.0; sym_longInducLow  = 0.0; sym_longInducHigh  = 0.0;

         sym_longOuterBreachSeen  = false;
         sym_shortOuterBreachSeen = false;

         double lvlS = 0.0;
         int    bestDistS = -1;
         if(sym_anchorHighShift > 0)
         {
            for(int s = sym_anchorHighShift - 1;
                s >= 0 && s >= sym_anchorHighShift - g_cfg.inducLookback;
                s--)
            {
               bool inside = (gHigh[s] < sym_anchorHigh && gLow[s] > sym_anchorLow);
               if(inside)
               {
                  int dist = (int)MathAbs(sym_anchorHighShift - s);
                  if(bestDistS < 0 || dist < bestDistS)
                  {
                     bestDistS = dist;
                     lvlS      = (gHigh[s] + gLow[s]) * 0.5;
                  }
               }
            }
         }
         if(bestDistS >= 0)
         {
            sym_shortInducPrice = lvlS;
            sym_shortInducLow   = lvlS - atrRef * g_cfg.inducZoneWidth;
            sym_shortInducHigh  = lvlS + atrRef * g_cfg.inducZoneWidth;
         }
      }
   }
   // LONG impulse: last low -> new high
   else if(pivotDir == 1 && sym_lastPivotDir == -1)
   {
      double r = pivotPrice - sym_lastPivotPrice;
      if(r > atrRef * g_cfg.impulseAtrMult)
      {
         sym_mode            = 1;
         sym_anchorLow       = sym_lastPivotPrice;
         sym_anchorLowShift  = sym_lastPivotShift;
         sym_anchorHigh      = pivotPrice;
         sym_anchorHighShift = pivotShift;

         sym_phaseLong       = 1;
         sym_phaseShort      = 0;
         // fresh long impulse => new campaign allowed (clear long re-entry lock)
         sym_exitedLongAnchor = 0.0; sym_longCampaignOpen = false;

         sym_shortPreConvSeen = false;
         sym_longPreConvSeen  = false;

         sym_shortInducPrice = 0.0; sym_shortInducLow = 0.0; sym_shortInducHigh = 0.0;
         sym_longInducPrice  = 0.0; sym_longInducLow  = 0.0; sym_longInducHigh  = 0.0;

         sym_longOuterBreachSeen  = false;
         sym_shortOuterBreachSeen = false;

         double lvlL = 0.0;
         int    bestDistL = -1;
         if(sym_anchorLowShift > 0)
         {
            for(int s = sym_anchorLowShift - 1;
                s >= 0 && s >= sym_anchorLowShift - g_cfg.inducLookback;
                s--)
            {
               bool inside = (gHigh[s] < sym_anchorHigh && gLow[s] > sym_anchorLow);
               if(inside)
               {
                  int dist = (int)MathAbs(sym_anchorLowShift - s);
                  if(bestDistL < 0 || dist < bestDistL)
                  {
                     bestDistL = dist;
                     lvlL      = (gHigh[s] + gLow[s]) * 0.5;
                  }
               }
            }
         }
         if(bestDistL >= 0)
         {
            sym_longInducPrice = lvlL;
            sym_longInducLow   = lvlL - atrRef * g_cfg.inducZoneWidth;
            sym_longInducHigh  = lvlL + atrRef * g_cfg.inducZoneWidth;
         }
      }
   }

   // Persist pivot history
   if(pivotDir != 0)
   {
      sym_prevPivotPrice = sym_lastPivotPrice;
      sym_prevPivotShift = sym_lastPivotShift;
      sym_prevPivotDir   = sym_lastPivotDir;

      sym_lastPivotPrice = pivotPrice;
      sym_lastPivotShift = pivotShift;
      sym_lastPivotDir   = pivotDir;
   }

   // Impulse invalidation
   if(sym_mode == -1 && closeNow > sym_anchorHigh)
   {
      sym_mode = 0; sym_phaseShort = 0;
      sym_shortInducPrice = 0.0; sym_shortInducLow = 0.0; sym_shortInducHigh = 0.0;
      sym_shortPreConvSeen = false; sym_longPreConvSeen = false;
      sym_longOuterBreachSeen = false; sym_shortOuterBreachSeen = false;
   }
   if(sym_mode == 1 && closeNow < sym_anchorLow)
   {
      sym_mode = 0; sym_phaseLong = 0;
      sym_longInducPrice = 0.0; sym_longInducLow = 0.0; sym_longInducHigh = 0.0;
      sym_shortPreConvSeen = false; sym_longPreConvSeen = false;
      sym_longOuterBreachSeen = false; sym_shortOuterBreachSeen = false;
   }

   int oldPhaseShort = sym_phaseShort;
   int oldPhaseLong  = sym_phaseLong;

   // SHORT side
   if(sym_mode != -1) sym_phaseShort = 0;
   if(sym_mode == -1 && sym_anchorHighShift >= 0 && sym_anchorLowShift >= 0)
   {
      double impS  = sym_anchorHigh - sym_anchorLow;
      double retrS = (impS > 0.0) ? (closeNow - sym_anchorLow) / impS : 0.0;
      double dS    = gClose[shiftNow] - gClose[shiftNow+1];

      int phaseTmpS;
      // BREAKOUT FIRST: a close at/below the impulse low is a new low (phase 4),
      // NOT an invalidation. (Previously retrS<0 pre-empted this, so P4 never fired.)
      if(closeNow <= sym_anchorLow)
         phaseTmpS = 4;
      else if(retrS > g_cfg.retrMax)   // retraced too far back UP toward the high = failed short
         phaseTmpS = 0;
      else if(retrS >= g_cfg.retrMin)
         phaseTmpS = (dS > 0.0 ? 2 : 3);
      else
         phaseTmpS = 1;

      bool hasShortZone = (sym_shortInducLow != 0.0 || sym_shortInducHigh != 0.0);
      if(phaseTmpS == 3 && hasShortZone && closeNow <= sym_shortInducHigh)
         phaseTmpS = 2;
      else if(phaseTmpS == 3)
         sym_shortPreConvSeen = true;

      if(phaseTmpS == 4 && !sym_shortPreConvSeen)
         phaseTmpS = 2;

      sym_phaseShort = phaseTmpS;
   }

   // LONG side
   if(sym_mode != 1) sym_phaseLong = 0;
   if(sym_mode == 1 && sym_anchorHighShift >= 0 && sym_anchorLowShift >= 0)
   {
      double impL  = sym_anchorHigh - sym_anchorLow;
      double retrL = (impL > 0.0) ? (sym_anchorHigh - closeNow) / impL : 0.0;
      double dL    = gClose[shiftNow] - gClose[shiftNow+1];

      int phaseTmpL;
      // BREAKOUT FIRST: a close at/above the impulse high is a new high (phase 4),
      // NOT an invalidation. (Previously retrL<0 pre-empted this, so P4 never fired.)
      if(closeNow >= sym_anchorHigh)
         phaseTmpL = 4;
      else if(retrL > g_cfg.retrMax)   // retraced too far back DOWN toward the low = failed long
         phaseTmpL = 0;
      else if(retrL >= g_cfg.retrMin)
         phaseTmpL = (dL < 0.0 ? 2 : 3);
      else
         phaseTmpL = 1;

      bool hasLongZone = (sym_longInducLow != 0.0 || sym_longInducHigh != 0.0);
      if(phaseTmpL == 3 && hasLongZone && closeNow >= sym_longInducLow)
         phaseTmpL = 2;
      else if(phaseTmpL == 3)
         sym_longPreConvSeen = true;

      if(phaseTmpL == 4 && !sym_longPreConvSeen)
         phaseTmpL = 2;

      sym_phaseLong = phaseTmpL;
   }

   sym_prevPhaseShort = oldPhaseShort;
   sym_prevPhaseLong  = oldPhaseLong;

   // ---- ARC v2 (convexity arc) ----
   sym_arcLong  = 0.0;
   sym_arcShort = 0.0;
   if(barsAvail >= 10)
   {
      int shift = 1; // last closed bar
      // LONG ARC: from anchorLow -> projected high target
      if(sym_mode == 1 && sym_anchorLowShift >= 0 && sym_anchorHighShift >= 0)
      {
         double impL = sym_anchorHigh - sym_anchorLow;
         if(impL > 0)
         {
            double targetL = sym_anchorLow + impL * g_cfg.arcExtMult;
            double tL = (double)(sym_anchorLowShift - shift) / (double)g_cfg.arcHorizonBars;
            if(tL < 0.0) tL = 0.0; if(tL > 1.0) tL = 1.0;
            sym_arcLong = sym_anchorLow + (targetL - sym_anchorLow) * MathPow(tL, g_cfg.convPower);
         }
      }
      // SHORT ARC: from anchorHigh -> projected low target
      if(sym_mode == -1 && sym_anchorLowShift >= 0 && sym_anchorHighShift >= 0)
      {
         double impS = sym_anchorHigh - sym_anchorLow;
         if(impS > 0)
         {
            double targetS = sym_anchorHigh - impS * g_cfg.arcExtMult;
            double tS = (double)(sym_anchorHighShift - shift) / (double)g_cfg.arcHorizonBars;
            if(tS < 0.0) tS = 0.0; if(tS > 1.0) tS = 1.0;
            sym_arcShort = sym_anchorHigh + (targetS - sym_anchorHigh) * MathPow(tS, g_cfg.convPower);
         }
      }
   }

   // ---- Symphony is the SINGLE phase/direction source of truth: map its
   //      impulse+phase model onto the canonical FalconWave so the whole OS
   //      (memory/intel/decision/execution/viz) reads the SAME phase engine. ----
   SymphonyBridgeToWave();
}

//==================================================================
// ENTRIES — Phase 3 + Phase 4 only (long & short)   [Symphony]
//   Stop placement: anchorLow/High ± atr*0.25 (Symphony precision).
//   Reuses EE_SendMarketOrder / EE_IsTradeTime from ExecutionEngine.
//==================================================================
void SymphonyExecuteTrading()
{
   int barsAvail = FalconBars();
   if(barsAvail < 3) return;

   int      shiftNow = 1;
   double   closeNow = gClose[shiftNow];
   double   atrNow   = FalconATR(shiftNow);
   if(atrNow<=0.0) atrNow=FalconATR(0);
   datetime barTime  = gTime[0];

   double equity   = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskCash = equity * g_cfg.riskPercent * 0.01;

   // session + drawdown gating (FALCON-managed)
   if(!EE_IsTradeTime()) return;
   if(g_cfg.blockIfBreach && !ee_lastRiskOk) return;
   if(ee_riskCooldown>0) return;

   // Re-entry lockout: a campaign for THIS impulse was already closed -> wait for
   // a fresh impulse before re-engaging this direction (kills exit/re-enter churn).
   bool longLocked  = (sym_exitedLongAnchor  != 0.0);
   bool shortLocked = (sym_exitedShortAnchor != 0.0);

   // EDGE-TRIGGERED entries: fire only on the bar the phase TRANSITIONS into 3/4,
   // never on every bar it stays there. (Level-triggering re-opened a new stacked
   // position on every bar of a multi-bar retrace -> the dense entry clusters /
   // chop.) Controlled pyramiding still happens: each fresh retest cycles phase
   // back to 3 and arms one more stack.
   bool L3 = (sym_mode==1  && sym_phaseLong ==3 && sym_prevPhaseLong !=3 && !longLocked);
   bool L4 = (sym_mode==1  && sym_phaseLong ==4 && sym_prevPhaseLong !=4 && !longLocked);
   bool S3 = (sym_mode==-1 && sym_phaseShort==3 && sym_prevPhaseShort!=3 && !shortLocked);
   bool S4 = (sym_mode==-1 && sym_phaseShort==4 && sym_prevPhaseShort!=4 && !shortLocked);

   double impL = sym_anchorHigh - sym_anchorLow;
   double impS = sym_anchorHigh - sym_anchorLow;

   // LONG P3
   if(L3 && sym_lastLongTradeTime!=barTime)
   {
      double entry = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double sl    = sym_anchorLow - atrNow*0.25;
      double lots  = TR_AdmitLots(DIR_LONG, Sym_ComputeLots(riskCash,entry,sl));
      if(sl>0 && entry>sl && lots>0)
      {
         if(EE_SendMarketOrder(+1,lots,sl,"SYM P3 Long"))
         {
            sym_lastLongTradeTime=barTime; sym_longCampaignOpen=true;
            g_state.exec.entry=entry; g_state.exec.stop=sl; g_state.exec.lots=lots; g_state.exec.riskCash=riskCash;
         }
      }
   }

   // LONG P4
   if(L4 && sym_lastLongTradeTime!=barTime && impL>0)
   {
      bool breakout = (closeNow>sym_anchorHigh || closeNow>gHigh[shiftNow+1] + 0.20*atrNow);
      if(breakout)
      {
         double entry = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
         double sl    = sym_anchorLow - atrNow*0.25;
         double lots  = TR_AdmitLots(DIR_LONG, Sym_ComputeLots(riskCash,entry,sl));
         if(sl>0 && entry>sl && lots>0)
         {
            if(EE_SendMarketOrder(+1,lots,sl,"SYM P4 Long"))
            {
               sym_lastLongTradeTime=barTime; sym_longCampaignOpen=true;
               g_state.exec.entry=entry; g_state.exec.stop=sl; g_state.exec.lots=lots; g_state.exec.riskCash=riskCash;
            }
         }
      }
   }

   // SHORT P3
   if(S3 && sym_lastShortTradeTime!=barTime)
   {
      double entry = SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double sl    = sym_anchorHigh + atrNow*0.25;
      double lots  = TR_AdmitLots(DIR_SHORT, Sym_ComputeLots(riskCash,entry,sl));
      if(sl>0 && sl>entry && lots>0)
      {
         if(EE_SendMarketOrder(-1,lots,sl,"SYM P3 Short"))
         {
            sym_lastShortTradeTime=barTime; sym_shortCampaignOpen=true;
            g_state.exec.entry=entry; g_state.exec.stop=sl; g_state.exec.lots=lots; g_state.exec.riskCash=riskCash;
         }
      }
   }

   // SHORT P4
   if(S4 && sym_lastShortTradeTime!=barTime && impS>0)
   {
      bool breakout = (closeNow<sym_anchorLow || closeNow<gLow[shiftNow+1] - 0.20*atrNow);
      if(breakout)
      {
         double entry = SymbolInfoDouble(_Symbol,SYMBOL_BID);
         double sl    = sym_anchorHigh + atrNow*0.25;
         double lots  = TR_AdmitLots(DIR_SHORT, Sym_ComputeLots(riskCash,entry,sl));
         if(sl>0 && sl>entry && lots>0)
         {
            if(EE_SendMarketOrder(-1,lots,sl,"SYM P4 Short"))
            {
               sym_lastShortTradeTime=barTime; sym_shortCampaignOpen=true;
               g_state.exec.entry=entry; g_state.exec.stop=sl; g_state.exec.lots=lots; g_state.exec.riskCash=riskCash;
            }
         }
      }
   }
}

//==================================================================
// EXITS — ARC + institutional outer-band sweep + phase composite
//   [ported from Symphony ManageArcInstitutionalExits]
//   Reuses EE_CloseFull from ExecutionEngine.
//==================================================================
void SymphonyManageExits()
{
   int barsAvail = FalconBars();
   if(barsAvail <= (2*g_cfg.pivotLen + 5)) return;

   int    shiftNow = 1;
   double closeNow = gClose[shiftNow];
   double atrNow   = FalconATR(shiftNow);
   if(atrNow<=0.0) atrNow=FalconATR(0);

   // --- 1) ARC exhaustion flags (measured against the genuine curve DESTINATION,
   //         not the time-evolving arc that sits near the origin early) ---
   double destL = Sym_DestLong();
   double destS = Sym_DestShort();
   bool arcExhaustLong  = (sym_mode == 1  && destL > 0.0 && closeNow >= (destL - g_cfg.arcToleranceAtr * atrNow));
   bool arcExhaustShort = (sym_mode == -1 && destS > 0.0 && closeNow <= (destS + g_cfg.arcToleranceAtr * atrNow));

   // --- 2) INSTITUTIONAL BANDS ---
   double instLevelL = (sym_longInducPrice != 0.0 ? sym_longInducPrice : (sym_anchorHigh > 0.0 ? sym_anchorHigh : 0.0));
   double innerTopL  = (sym_longInducHigh > 0.0 ? sym_longInducHigh : instLevelL);
   double outerTopL  = innerTopL + g_cfg.outerBandAtrMult * atrNow;

   double instLevelS = (sym_shortInducPrice != 0.0 ? sym_shortInducPrice : (sym_anchorLow > 0.0 ? sym_anchorLow : 0.0));
   double innerBotS  = (sym_shortInducLow != 0.0 ? sym_shortInducLow : instLevelS);
   double outerBotS  = innerBotS - g_cfg.outerBandAtrMult * atrNow;

   // --- 3) TRACK OUTER-BAND SWEEPS PER IMPULSE ---
   if(sym_mode == 1 && instLevelL > 0.0 && closeNow > outerTopL)
      sym_longOuterBreachSeen = true;
   if(sym_mode == -1 && instLevelS > 0.0 && closeNow < outerBotS)
      sym_shortOuterBreachSeen = true;

   // --- 4) PHASE-CHANGE AT EXTREME ---
   bool phaseTrendEndLong =
      (sym_mode == 1 && (sym_prevPhaseLong == 3 || sym_prevPhaseLong == 4) && (sym_phaseLong <= 1));
   bool phaseTrendEndShort =
      (sym_mode == -1 && (sym_prevPhaseShort == 3 || sym_prevPhaseShort == 4) && (sym_phaseShort <= 1));

   // --- 5) FULL EXIT CONDITIONS ---
   bool exitLong = false;
   bool exitShort = false;

   if(sym_mode == 1 && arcExhaustLong && phaseTrendEndLong)
   {
      bool hasInstL = (instLevelL > 0.0);
      bool instPatternOK = !hasInstL || (sym_longOuterBreachSeen && closeNow < innerTopL);
      if(instPatternOK) exitLong = true;
   }
   if(sym_mode == -1 && arcExhaustShort && phaseTrendEndShort)
   {
      bool hasInstS = (instLevelS > 0.0);
      bool instPatternOK = !hasInstS || (sym_shortOuterBreachSeen && closeNow > innerBotS);
      if(instPatternOK) exitShort = true;
   }

   if(!exitLong && !exitShort) return;

   // --- 6) EXECUTE EXITS ON MATCHING POSITIONS ---
   int total = PositionsTotal();
   for(int i=total-1;i>=0;i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != g_cfg.magic) continue;
      long type = PositionGetInteger(POSITION_TYPE);

      if(exitLong && type == POSITION_TYPE_BUY)
      {
         if(EE_CloseFull(ticket)) FalconPublish(EVT_EXIT_FIRED,1,"SYM ARC/INST exit");
      }
      if(exitShort && type == POSITION_TYPE_SELL)
      {
         if(EE_CloseFull(ticket)) FalconPublish(EVT_EXIT_FIRED,-1,"SYM ARC/INST exit");
      }
   }

   // Lock re-entry for THIS impulse so we don't immediately re-open the same leg.
   if(exitLong)  { sym_exitedLongAnchor  = (sym_anchorLow >0.0?sym_anchorLow :1.0); sym_longCampaignOpen=false;  }
   if(exitShort) { sym_exitedShortAnchor = (sym_anchorHigh>0.0?sym_anchorHigh:1.0); sym_shortCampaignOpen=false; }
}

//==================================================================
// CURVE DESTINATION — the genuine FIXED projected target of the impulse.
//   destLong  = anchorLow  + impulse * arcExtMult   (the curve's high target)
//   destShort = anchorHigh - impulse * arcExtMult   (the curve's low target)
//
//   NOTE: this is NOT sym_arcLong/sym_arcShort. Those are the TIME-EVOLVING
//   arc curve, which sits near the impulse ORIGIN early in a move (t→0) and
//   would sit BELOW price — using it as a harvest/convergence trigger banks
//   winners the instant they open. The grip and the partial must converge on
//   the real destination, so winners are allowed to travel to the target.
//==================================================================
double Sym_DestLong()
{
   double imp = sym_anchorHigh - sym_anchorLow;
   if(sym_mode!=1 || imp<=0.0) return(0.0);
   return(sym_anchorLow + imp*g_cfg.arcExtMult);
}
double Sym_DestShort()
{
   double imp = sym_anchorHigh - sym_anchorLow;
   if(sym_mode!=-1 || imp<=0.0) return(0.0);
   return(sym_anchorHigh - imp*g_cfg.arcExtMult);
}

//==================================================================
// TALON GRIP — curve-convergent STRUCTURAL trailing + earned breakeven
//   Replaces basic ATR trailing. Operates at the CAMPAIGN (basket) level:
//   one grip for the whole directional fleet, off blended cost. The stop is
//   driven by the same intelligence that drives entries:
//     1) STRUCTURE  — rides behind confirmed swing pivots (higher-lows for
//        longs / lower-highs for shorts), ratcheting only.
//     2) BREAKEVEN  — EARNED, not arbitrary: locks once a BOS confirms in the
//        campaign direction OR the fleet is TalonBeATR in favor. (No more
//        getting tagged on a healthy phase-2 retrace.)
//     3) CONVERGENCE — the trail distance CONTRACTS as price nears the curve
//        destination (ARC target / wave objective) and as geometryCapacity
//        drains. Far = wide (let it run); near = tight (bank before reversal).
//     4) PHASE/THERMAL — hard-tightens at terminal phase (NEW_HIGH/NEW_LOW) or
//        when the campaign's profit velocity (coolingRate) rolls over.
//   Reuses EE_ModifySL. Applies one ratcheting stop to every leg of the side.
//==================================================================
void TalonManageSide(const int dir,const FalconThermalCampaign &c,
                     const double atr,const double bid,const double ask,
                     const double pivot)
{
   double E = c.blendedEntry;
   if(E<=0.0) return;
   double price = (dir==DIR_LONG ? bid : ask);
   double buf   = atr*g_cfg.talonBufATR;

   // 1) STRUCTURAL ANCHOR — ratchet to confirmed swings in the trade direction
   if(dir==DIR_LONG)
   {
      if(talon_anchorLong<=0.0)
         talon_anchorLong = MathMax(g_state.structure.swingLow, E - atr*g_cfg.talonBaseATR);
      if(pivot>0.0 && pivot>talon_anchorLong && pivot<price) talon_anchorLong = pivot;
   }
   else
   {
      if(talon_anchorShort<=0.0)
         talon_anchorShort = (g_state.structure.swingHigh>0.0 ? g_state.structure.swingHigh
                                                              : E + atr*g_cfg.talonBaseATR);
      if(pivot>0.0 && pivot<talon_anchorShort && pivot>price) talon_anchorShort = pivot;
   }
   double anchor = (dir==DIR_LONG ? talon_anchorLong : talon_anchorShort);
   double structuralSL = (dir==DIR_LONG ? anchor-buf : anchor+buf);

   // 2) EARNED BREAKEVEN — structural confirm (BOS in dir) OR favor >= TalonBeATR
   bool earned = (g_state.structure.bos==dir) || (c.favorableATR>=g_cfg.talonBeATR);
   if(earned){ if(dir==DIR_LONG) talon_beLong=true; else talon_beShort=true; }
   bool   beLocked = (dir==DIR_LONG ? talon_beLong : talon_beShort);
   double beFloor  = (dir==DIR_LONG ? E+atr*0.05 : E-atr*0.05);

   // 3) CURVE CONVERGENCE — wide far from the destination (let winners run),
   //    contracts ONLY on the final approach. The destination is the FIXED
   //    curve target (Sym_Dest*), never the time-evolving arc that sits near
   //    the origin early in the move.
   double target = (dir==DIR_LONG ? Sym_DestLong() : Sym_DestShort());
   if(target<=0.0) target = g_state.wave.objective;
   double distATR = (target>0.0 ? MathAbs(target-price)/atr : 999.0);
   double geom    = FalconClamp(g_state.convexity.geometryCapacity/100.0,0.0,1.0);

   // base: far => convFrac→1 (full base trail); near => convFrac→minTighten.
   double convFrac = FalconClamp(distATR/MathMax(g_cfg.talonConvSpanATR,1e-6),
                                 g_cfg.talonMinTighten, 1.0);
   bool approaching = (distATR < g_cfg.talonConvSpanATR);
   // geometry can ONLY tighten further once we are genuinely approaching the
   // destination — never strangle a young winner that is still far from target.
   if(approaching)
      convFrac = FalconClamp(MathMin(convFrac, MathMax(geom, g_cfg.talonMinTighten)),
                             g_cfg.talonMinTighten, 1.0);

   // 4) TERMINAL hard-tighten — only at the true terminal phase AND in the final
   //    approach. (Removed the single-bar coolingRate<0 trigger: one pullback bar
   //    was slamming the trail and stopping out healthy winners on noise.)
   bool terminal = ((dir==DIR_LONG  && g_state.wave.phase==PH_NEW_HIGH)
                  || (dir==DIR_SHORT && g_state.wave.phase==PH_NEW_LOW))
                  && distATR < g_cfg.talonConvSpanATR*0.5;
   if(terminal) convFrac = g_cfg.talonMinTighten;
   double trailDist = atr*g_cfg.talonBaseATR*convFrac;
   double convSL    = (dir==DIR_LONG ? price-trailDist : price+trailDist);

   // 5) COMPOSE — RIDE vs BANK.
   //    Far from the destination: use the LOOSER of (structural ratchet, ATR
   //    trail) so a healthy winner is given full room and is NOT noise-stopped
   //    on a normal pullback to the prior swing. On the final approach / terminal:
   //    use the TIGHTER of the two to bank before the reversal. Floor at earned
   //    breakeven; ratchet only (handled by the apply step).
   double cand;
   if(approaching || terminal)
      cand = (dir==DIR_LONG ? MathMax(structuralSL,convSL) : MathMin(structuralSL,convSL)); // tighter => bank
   else
      cand = (dir==DIR_LONG ? MathMin(structuralSL,convSL) : MathMax(structuralSL,convSL)); // looser => ride
   if(beLocked)
      cand = (dir==DIR_LONG ? MathMax(cand,beFloor) : MathMin(cand,beFloor));

   // stage (display)
   int stage;
   if(!beLocked)        stage=TG_FORMING;
   else if(terminal)    stage=TG_TERMINAL;
   else if(approaching) stage=TG_CONVERGING;
   else if(g_state.structure.bos==dir) stage=TG_RIDING;
   else                 stage=TG_BREAKEVEN;

   if(dir==DIR_LONG){ g_state.exec.gripLong=cand;  g_state.exec.talonStageLong=stage; }
   else             { g_state.exec.gripShort=cand; g_state.exec.talonStageShort=stage; }

   // 6) APPLY one ratcheting grip to every leg of this campaign
   int total=PositionsTotal();
   for(int i=0;i<total;i++)
   {
      ulong ticket=PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=g_cfg.magic) continue;
      long type=PositionGetInteger(POSITION_TYPE);
      double sl=PositionGetDouble(POSITION_SL);
      if(dir==DIR_LONG && type==POSITION_TYPE_BUY && cand<bid && (sl==0.0||cand>sl))
      { if(EE_ModifySL(ticket,cand)) g_state.exec.exitState=XS_TRAIL_STOP; }
      if(dir==DIR_SHORT&& type==POSITION_TYPE_SELL&& cand>ask && (sl==0.0||cand<sl))
      { if(EE_ModifySL(ticket,cand)) g_state.exec.exitState=XS_TRAIL_STOP; }
   }
}

void TalonGrip()
{
   if(!g_cfg.useTalon) return;
   double atr=FalconATR(1); if(atr<=0.0) atr=FalconATR(0);
   if(atr<=0.0) return;
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);

   // confirmed structural pivots for the grip anchor
   int cl = g_cfg.talonStructLen+1;
   double pLow  = FalconIsPivotLow (cl,g_cfg.talonStructLen) ? gLow[cl]  : 0.0;
   double pHigh = FalconIsPivotHigh(cl,g_cfg.talonStructLen) ? gHigh[cl] : 0.0;

   FalconThermalCampaign cL = g_state.risk.campaign[0];
   FalconThermalCampaign cS = g_state.risk.campaign[1];

   if(cL.stackCount>0) TalonManageSide(DIR_LONG, cL, atr, bid, ask, pLow);
   else { talon_anchorLong=0.0;  talon_beLong=false;  g_state.exec.gripLong=0.0;  g_state.exec.talonStageLong=TG_FORMING; }

   if(cS.stackCount>0) TalonManageSide(DIR_SHORT, cS, atr, bid, ask, pHigh);
   else { talon_anchorShort=0.0; talon_beShort=false; g_state.exec.gripShort=0.0; g_state.exec.talonStageShort=TG_FORMING; }
}

//==================================================================
// ARC PARTIAL — bank a fraction of each leg ONLY when price actually REACHES
// the genuine curve destination (Sym_Dest*), and only after a minimum
// favorable excursion. This no longer fires off the time-evolving arc (which
// sits near the origin early and used to half-close every winner instantly).
// Set InpArcPartialFrac=0 to let the whole position run to the trail.
//==================================================================
void SymphonyArcPartial()
{
   double frac = g_cfg.arcPartialFrac;
   if(frac<=0.0) return;                       // disabled => let it all run

   double atr = FalconATR(1); if(atr<=0.0) atr=FalconATR(0);
   if(atr<=0.0) return;
   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double destL = Sym_DestLong();
   double destS = Sym_DestShort();
   double minMove = atr*g_cfg.arcPartialMinATR;

   int total=PositionsTotal();
   for(int i=0;i<total;i++)
   {
      ulong ticket=PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=g_cfg.magic) continue;
      long   type=PositionGetInteger(POSITION_TYPE);
      double vol =PositionGetDouble(POSITION_VOLUME);
      double open=PositionGetDouble(POSITION_PRICE_OPEN);
      int    slot=EE_TPSlot((long)ticket);
      if(ee_tpStage[slot]>=1) continue;        // already banked this leg
      if(type==POSITION_TYPE_BUY  && destL>0.0 && bid>=destL && (bid-open)>=minMove)
      { if(EE_ClosePartial(ticket,vol*frac)) ee_tpStage[slot]=1; }
      if(type==POSITION_TYPE_SELL && destS>0.0 && ask<=destS && (open-ask)>=minMove)
      { if(EE_ClosePartial(ticket,vol*frac)) ee_tpStage[slot]=1; }
   }
}

//==================================================================
// CAMPAIGN LOCKOUT DETECTOR — if a campaign was open and now has zero open
// legs, it was closed by the trail-stop / SL (server-side) or the composite
// exit. Engage the re-entry lock for the CURRENT impulse so we don't churn
// straight back into the same leg. Cleared when a fresh impulse forms.
//==================================================================
void SymphonyUpdateCampaignLockout()
{
   int openL=0, openS=0;
   int total=PositionsTotal();
   for(int i=0;i<total;i++)
   {
      ulong ticket=PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=g_cfg.magic) continue;
      if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY) openL++; else openS++;
   }
   if(sym_longCampaignOpen && openL==0)
   { sym_exitedLongAnchor  = (sym_anchorLow >0.0?sym_anchorLow :1.0); sym_longCampaignOpen=false;  }
   if(sym_shortCampaignOpen && openS==0)
   { sym_exitedShortAnchor = (sym_anchorHigh>0.0?sym_anchorHigh:1.0); sym_shortCampaignOpen=false; }
}

//==================================================================
// MASTER — Symphony manage step (manage open trades, then exits, then entries)
//   Called from the pipeline's execution stage when g_cfg.useSymphony.
//==================================================================
void SymphonyTradeManage()
{
   SymphonyUpdateCampaignLockout(); // detect closed campaigns -> lock the impulse (no churn)
   TalonGrip();             // TALON curve-convergent structural grip (breakeven + trail)
   SymphonyArcPartial();    // bank a fraction at the projected ARC destination
   SymphonyManageExits();   // composite ARC + institutional + phase reversal exit
   SymphonyExecuteTrading();// Phase 3/4 entries
}

#endif // FALCON_SYMPHONY_ENGINE_MQH
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
   FalconEntryCycle ecv=g_state.entryCycle;

   switch(tab)
   {
      case 0: // OVERVIEW
         s+="Action      : "+FalconActionStr(e.action)+"   ("+VZ_Dir(e.master)+")\n";
         s+="Cycle       : "+(ecv.terminal?"TERMINAL":"BUILDING")+"  "+FalconReadinessStr(ecv.readiness)
            +(ecv.entryCycleActive?"  <<ENTRY>>":"")+"\n";
         s+="Compression : "+FalconCompressionStr(ecv.compressionRegime)+"   recursions "+IntegerToString(ecv.recursionDepth)
            +"/"+DoubleToString(ecv.expectedDepth,1)+"  transfer "+(ecv.transitionComplete?"done":"building")+"\n";
         s+="Liq Wave    : "+(ecv.liqSubPhase==""?"—":ecv.liqSubPhase)+(ecv.liqActive?"  dist "+DoubleToString(ecv.liqDistPct,0)+"%":"")
            +(ecv.liqTrueChoch?"  CHoCH":"")+"\n";
         s+="Phase       : "+FalconPhaseStr(w.phase)+"  "+VZ_Pct(w.completion)+"\n";
         s+="Symphony    : "+(w.symMode==1?"LONG":w.symMode==-1?"SHORT":"—")
            +"  Pl="+IntegerToString(w.symPhaseLong)+" Ps="+IntegerToString(w.symPhaseShort)
            +(g_cfg.useSymphony?"  [AUTHORITY]":"")+"\n";
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
      case 8: // RISK — PYRO Campaign Thermodynamics
      {
         FalconThermalCampaign cl=g_state.risk.campaign[0];
         FalconThermalCampaign cs=g_state.risk.campaign[1];
         FalconThermostat th=g_state.risk.thermostat;
         s+="Engine      : "+(g_cfg.useThermalRisk?"PYRO thermal ON":"OFF")+"   Risk OK "+(e.riskOk?"YES":"NO")+"\n";
         s+="LONG  camp  : "+IntegerToString(cl.stackCount)+" stacks  "+DoubleToString(cl.totalLots,2)+" lots\n";
         s+="  heat "+DoubleToString(cl.heat,2)+"  "+FalconAdmitStr(cl.admission)+"  x"+DoubleToString(cl.admitLotScale,2)
            +(cl.adverseATR>0.0?"  -"+DoubleToString(cl.adverseATR,1)+"ATR":"  +"+DoubleToString(cl.favorableATR,1)+"ATR")
            +(cl.breakevenLocked?"  BE-LOCK":"")+"\n";
         s+="SHORT camp  : "+IntegerToString(cs.stackCount)+" stacks  "+DoubleToString(cs.totalLots,2)+" lots\n";
         s+="  heat "+DoubleToString(cs.heat,2)+"  "+FalconAdmitStr(cs.admission)+"  x"+DoubleToString(cs.admitLotScale,2)
            +(cs.adverseATR>0.0?"  -"+DoubleToString(cs.adverseATR,1)+"ATR":"  +"+DoubleToString(cs.favorableATR,1)+"ATR")
            +(cs.breakevenLocked?"  BE-LOCK":"")+"\n";
         s+="Thermostat  : combined "+DoubleToString(th.combinedHeat,2)+"  acct "+DoubleToString(th.accountHeat*100.0,0)+"%"
            +(th.whipsawLock?"  WHIPSAW-LOCK":"")+"\n";
         s+="Blended E   : L "+VZ_Px(cl.blendedEntry)+"  S "+VZ_Px(cs.blendedEntry)+"\n";
         s+="Failure swg : "+DoubleToString(x.failureSwingProb*100.0,0)+"%   Loops left "+DoubleToString(x.expectedLoopsRemaining,1);
         break;
      }
      case 9: // EXECUTION
         s+="Action      : "+FalconActionStr(e.action)+"\n";
         s+="Trade State : "+FalconTradeStateStr(e.tradeState)+"   Last exit "+FalconExitStateStr(e.exitState)+"\n";
         s+="Entry/Stop  : "+VZ_Px(e.entry)+" / "+VZ_Px(e.stop)+"\n";
         s+="Target      : "+VZ_Px(e.target)+"   R:R "+DoubleToString(e.reward,2)+"\n";
         s+="TALON grip  : L "+(e.gripLong>0?VZ_Px(e.gripLong)+" "+FalconTalonStr(e.talonStageLong):"—")
            +"   S "+(e.gripShort>0?VZ_Px(e.gripShort)+" "+FalconTalonStr(e.talonStageShort):"—")+"\n";
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

//------------------------------------------------------------------
// Tab switching. Press T (or RIGHT arrow) to advance tabs, SHIFT+T
// (or LEFT arrow) to go back. Wired from the EA's OnChartEvent.
//------------------------------------------------------------------
void FalconVizOnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   if(id!=CHARTEVENT_KEYDOWN) return;
   int prev=g_cfg.dashboardTab;
   if(lparam==84 || lparam==39)       g_cfg.dashboardTab = (g_cfg.dashboardTab+1)%12;  // 'T' / RIGHT
   else if(lparam==37)                g_cfg.dashboardTab = (g_cfg.dashboardTab+11)%12;  // LEFT
   if(g_cfg.dashboardTab!=prev) VisualizationRun();
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

   // Symphony phase engine = the SINGLE phase/direction SOURCE OF TRUTH.
   // Computed from the same shared series right after the Market Layer observes
   // geometry, it then BRIDGES its impulse + Phase 1..4 model onto the canonical
   // g_state.wave (phase/direction/flip/origin/objective/completion). Every
   // downstream layer (Memory ownership, Intelligence, Decision master,
   // Execution, Visualization) therefore reasons on ONE phase engine — Symphony.
   // The Market Engine still supplies raw geometry descriptors (sub-scores,
   // energy, recursion, cycle extremes); only the phase ENGINE is unified here.
   if(g_cfg.useSymphony)
      SymphonyUpdatePhases();

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
   // Exposure snapshot → Drawdown Protection → PYRO Thermal Risk
   // (heat / admissions / basket management) → Symphony entries+exits
   // (never decides, only executes)
   FalconModuleStart(MOD_EXEC,t0);
   ExecutionEngineRun();
   // PYRO campaign-thermodynamics risk: compute per-direction basket HEAT,
   // set stack admissions (OPEN/THROTTLED/FROZEN/DE-RISK), run the portfolio
   // thermostat, and manage baskets (breakeven-lock winners / catastrophe-
   // flatten a thermal runaway). Runs BEFORE Symphony so admission scales are
   // fresh when its entries consult TR_AdmitLots.
   if(g_cfg.useThermalRisk)
      ThermalRiskUpdate();
   // Symphony is the PRECISION entry/exit authority when enabled: it manages
   // its own Phase 3/4 entries + ARC/institutional exits using Symphony's own
   // stop placement. The FALCON entry/exit block in ExecutionEngineRun() is
   // suppressed in this mode (see g_cfg.useSymphony guard there) so the two
   // never double-trade. Risk = lot sizing + drawdown protection only.
   if(g_cfg.useSymphony)
      SymphonyTradeManage();
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
   if(g_cfg.useThermalRisk) ThermalRiskInit();
   if(g_cfg.useSymphony) SymphonyInit();

   if(!FalconRefreshSeries())
   {
      FalconError("Kernel","initial series refresh failed");
      return(INIT_FAILED);
   }

   FalconLog("INFO","Kernel",
      StringFormat("FALCON OS booted — profile=%d magic=%d trading=%s thermalRisk=%s",
        g_cfg.profile, (int)g_cfg.magic,
        g_cfg.enableTrading?"on":"off", g_cfg.useThermalRisk?"PYRO":"off"));
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

//==================================================================
// CHART EVENTS — dashboard tab switching (T / arrow keys)
//==================================================================
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   FalconVizOnChartEvent(id,lparam,dparam,sparam);
}
//+------------------------------------------------------------------+
