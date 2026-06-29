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
// SUB-STATE : CURVE LOCATOR  (always-on "you are here" on the curve)
//   A continuous, persistent, multi-TF coordinate of where price sits
//   between the owning curve's ORIGIN and DESTINATION. Never undefined:
//   anchored to the owner TF, cascades up the ladder, confidence decays
//   instead of hard-resetting. Phases are labels read off `pos`.
//==================================================================
struct FalconCurveLocator
{
   double pos;          // master position on the OWNER leg, 0..1 (origin->destination)
   int    dir;          // owner curve direction (FALCON_DIR)
   double vel;          // d(pos)/bar — advancing toward destination when > 0
   double conf;         // 0..100 confidence the location is currently valid
   int    ownerTF;      // ladder index the master location is read from
   double legPos[7];    // continuous position on each absolute TF's leg (-1 = undefined)
   bool   advancing;    // moving toward the destination (vel >= 0)
   string label;        // Early / Developing / Mid / Late / Terminal
};

//==================================================================
// SUB-STATE : SELF-AWARENESS  (metacognition — the OS watching itself)
//   Not market state — this is the system's model of ITSELF: how well
//   calibrated its own confidence is, its current form, whether it's in
//   a regime it performs in, and whether its own inputs are healthy. It
//   synthesises one selfConfidence and a risk THROTTLE, and can stand the
//   system down when it shouldn't trust itself.
//==================================================================
struct FalconSelfAwareness
{
   double selfConfidence;  // 0..100 how much the OS should trust itself now
   double calibration;     // 0..100 predicted-prob vs realised win-rate alignment
   double form;            // 0..100 streak + equity slope + drawdown
   double regimeFit;       // 0..100 current regime vs profitable regime
   int    winStreak;
   int    lossStreak;
   double ddFromPeakPct;
   double equitySlope;     // recency-weighted equity change
   double throttle;        // 0..1 global risk multiplier from self-confidence + health
   bool   health;          // are own inputs sane?
   string healthNote;
   string label;           // CONFIDENT / CAUTIOUS / DEFENSIVE / STANDDOWN
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
   FalconCurveLocator curveLocator;
   FalconSelfAwareness self;
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
