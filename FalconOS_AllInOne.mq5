//+------------------------------------------------------------------+
//|                                            FalconOS_AllInOne.mq5 |
//|   FALCON OS — Unified Trading Intelligence Platform               |
//|   SINGLE-FILE BUILD (all kernel + engines concatenated)          |
//|   Risk: PYRO thermal + TALON curve-convergent structural grip.   |
//+------------------------------------------------------------------+
#property copyright "FALCON OS"
#property version   "5.19"
#property strict

#include <Trade\Trade.mqh>


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
   // ---- F72 RECURSIVE CURVE TREE (event-driven CurveNode array summary) ----
   int    treeNodeCount;  // total living nodes in the recursive tree
   int    treeDepth;      // deepest living recursion depth
   int    budgetDepth;    // compression-derived recursion budget (1..4)
   bool   recursionComplete; // treeDepth >= budgetDepth (recursion spent)
   int    ownerNodeDir;   // direction of the OWNING node (shallowest alive w/ energy)
   double ownerNodeEnergy;// energy of the owning node (0..100)
   int    ownerNodeDepth; // recursion depth of the owning node
   double ownerNodeOrigin;
   double ownerNodeExtreme;
   string ownerNodeState; // emergent phase label the owning node emits
   double compForce;      // F72 Principle 10 — compression persistence force (0..100)
   string compState;      // PERSISTING / NEUTRAL / LEAKING
   double migration50;    // 0.5 retrace of owner leg (migrated S/R band)
   double migration618;   // 0.618 retrace of owner leg
   double narrative;      // narrative-lineage strength (0..100, >50 strengthening)
   int    supportVotes;   // converging (support) pullback votes
   int    degradeVotes;   // diverging (degrade) pullback votes
};

//==================================================================
// SUB-STATE : TIME INTELLIGENCE (TIE — F16 Engine 8.0)
//   The temporal layer. Markets behave differently by SESSION, hour,
//   day, and weekly position. TIE models a 5-cycle temporal stack and
//   synthesises a continuous timeQuality + path probability + a soft
//   temporal permission. It NEVER hard-blocks on its own (hard session
//   limits remain the separate session filter) — it is an informational
//   probability layer the decision/fact layers can weigh.
//==================================================================
enum FALCON_SESSION
{
   SES_CLOSED  = 0,
   SES_ASIA    = 1,
   SES_LONDON  = 2,
   SES_NY      = 3,
   SES_OVERLAP = 4   // London/NY overlap (the high-liquidity window)
};

struct FalconTime
{
   int    session;            // FALCON_SESSION
   string sessionName;
   double sessionProgress;    // 0..1 progress through the active session
   int    hour;               // session-adjusted hour (0..23)
   int    minute;
   int    dayOfWeek;          // 0=Sun..6=Sat
   double volExpectation;     // 0..100 expected volatility for this hour (gold profile)
   double liquidityExpectation; // 0..100 expected participation
   bool   killzone;           // inside a high-probability killzone window
   string killzoneName;
   // 5-cycle temporal stack (each 0..100 favourability)
   double cycle[5];
   double timeQuality;        // 0..100 composite temporal quality (the master scalar)
   double pathProbability;    // 0..1 probability time-of-day favours continuation
   int    temporalBias;       // FALCON_DIR temporal lean (e.g. London expands Asia range)
   bool   permit;             // soft temporal permission (timeQuality >= floor)
   string label;              // PRIME / ACTIVE / QUIET / DEAD
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
// SUB-STATE : MULTI-ENGINE WAVE CYCLES (the comparative framework)
//   Don't replace the phase engine — run THREE wave-cycle engines on
//   the SAME shared observations and let the market decide which has
//   the highest predictive power:
//     ENG_LETRA    — the per-TF fixed-structure lifecycle FSM
//     ENG_F16      — the recursive curve-tree node ownership lens
//     ENG_SYMPHONY — the impulse + retracement-fraction phase model
//   Each emits a NORMALIZED forecast (phase · stage · direction ·
//   maturity · objective · invalidation · confidence · next event).
//   A Wave Intelligence referee then scores each engine's demonstrated
//   accuracy and forms a consensus / picks the best. Phases remain
//   OUTPUTS — the referee never branches on a label, only on evidence.
//==================================================================
enum FALCON_ENGINE
{
   ENG_LETRA     = 0,
   ENG_F16       = 1,
   ENG_SYMPHONY  = 2,
   ENG_CONSENSUS = 3,   // selector only (not a column)
   ENG_BEST      = 4    // selector only — follow the best demonstrated edge
};
#define FALCON_NCYCLES 3   // LETRA / F16 / SYMPHONY columns

// normalized lifecycle stage shared across all engines for comparison
#define CYC_NONE      0
#define CYC_EXPANSION 1
#define CYC_RETRACE   2
#define CYC_RETURN    3   // demand/supply return into zone  -> P3 entry analog
#define CYC_BREAKOUT  4   // new extreme / continuation       -> P4 entry analog

struct WaveCycle
{
   int    engineId;
   int    phase;          // canonical PH_ (label)
   string phaseLabel;
   int    stage;          // normalized CYC_* lifecycle stage
   int    prevStage;
   double maturity;       // 0..100 wave completion
   int    direction;      // DIR_*
   double objective;      // expected target price
   double invalidation;   // price that invalidates the read
   double confidence;     // 0..100 engine self-confidence
   string nextEvent;      // expected next event (human readable)
   // entry trigger (this engine's own P3/P4 analog)
   bool   entryArmed;     // stage is a return/breakout
   bool   entryEdge;      // transitioned INTO a return/breakout this bar
   int    entryKind;      // 3 (return) or 4 (breakout)
   int    entryDir;       // DIR_* of the armed entry
   // referee-filled demonstrated performance (rolling)
   double accuracy;       // directional accuracy %% (EWMA)
   double objAccuracy;    // objective-reach accuracy %%
   double avgLeadBars;    // mean early-detection lead vs the field
   int    samples;        // resolved predictions
   int    wins;
};

struct WaveReferee
{
   int    selectedEngine; // engine currently DRIVING (resolved from InpEntryEngine/BEST)
   string selectedName;
   int    consensusDir;   // DIR_* agreed by >=2 engines (else NONE)
   int    consensusStage;
   double consensusConf;
   double deviationStage; // disagreement in stage (0..4)
   double deviationObjATR;// disagreement in objective (ATR units)
   int    bestEngine;     // highest demonstrated directional accuracy
   double bestAccuracy;
   int    leader;         // engine that most often leads the others (early warning)
   string note;
};

string FalconEngineStr(const int e)
{
   switch(e)
   {
      case ENG_LETRA:     return("LETRA");
      case ENG_F16:       return("F16");
      case ENG_SYMPHONY:  return("SYMPHONY");
      case ENG_CONSENSUS: return("CONSENSUS");
      case ENG_BEST:      return("BEST");
      default:            return("?");
   }
}

string FalconStageStr(const int s)
{
   switch(s)
   {
      case CYC_EXPANSION: return("Expansion");
      case CYC_RETRACE:   return("Retracement");
      case CYC_RETURN:    return("Return");
      case CYC_BREAKOUT:  return("Breakout");
      default:            return("—");
   }
}

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
   FalconTime         timeIntel;
   WaveCycle          cycles[FALCON_NCYCLES];  // [0]LETRA [1]F16 [2]SYMPHONY
   WaveReferee        referee;
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

string FalconSessionStr(const int s)
{
   switch(s)
   {
      case SES_ASIA:    return("ASIA");
      case SES_LONDON:  return("LONDON");
      case SES_NY:      return("NEW YORK");
      case SES_OVERLAP: return("LDN/NY OVERLAP");
      default:          return("CLOSED");
   }
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

// QUICK PROFILE — one-click tuned presets that override the inputs below.
enum FALCON_PRESET
{
   PRESET_CUSTOM    = 0,   // use the inputs exactly as set
   PRESET_LETRA     = 1,   // LETRA free-run profile (minR 4 · max 2 pos · no-hedge · TALON+PYRO)
   PRESET_SYMPHONY  = 2    // SYMPHONY free-run profile (same risk frame, Symphony cycle)
};

//==================================================================
// INPUTS — the single declaration of every tunable in the OS
//==================================================================
input string  __sep_general    = "════════ FALCON OS — GENERAL ════════"; // ──
input FALCON_PROFILE InpProfile = PROFILE_LIVE;   // Run profile
input FALCON_PRESET  InpPreset  = PRESET_CUSTOM;  // QUICK PROFILE: LETRA/SYMPHONY tuned BASE. Change any input below to override it. CUSTOM = none.
input long    InpMagic          = 770077;         // EA magic number
input ENUM_TIMEFRAMES InpOperatingTF = PERIOD_CURRENT; // Operating TF for the trading CORE (PERIOD_CURRENT=use chart). Set explicitly (e.g. M5) to make the chart a pure viewport.
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

input string  __sep_curvetree   = "════════ RECURSIVE CURVE TREE (F72) ════════"; // ──
input bool    InpUseCurveTree    = true;  // Build the F72 event-driven recursive CurveNode tree (curves inside curves)
input double  InpCTOwnerMinE     = 12.0;  // Energy floor: a node owns price only while energy >= this (Principle 8)
input double  InpCTProgressGain  = 7.0;   // Energy gained per bar a node makes progress (continuation)
input double  InpCTStallDecay     = 2.0;  // Energy lost per bar a node stalls (no new extreme)
input int     InpCTMaxNodes       = 60;   // Max nodes retained in the tree (oldest shifted out)

input string  __sep_time        = "════════ TIME INTELLIGENCE (TIE — Engine 8.0) ════════"; // ──
input bool    InpUseTimeIntel    = true;  // Run the 5-cycle temporal stack (session/killzone/time-quality probabilities)
input double  InpTimeQualityFloor= 35.0;  // Soft temporal permit: timeQuality below this marks DEAD/QUIET hours
input bool    InpTimeGateEntries = false; // Let TIE cast a SOFT veto on entries in DEAD hours (off: informational only)

input string  __sep_decision    = "════════ DECISION (SENSEEI) ════════"; // ──
input int     InpMinConf        = 55;    // Min confidence to ATTACK
input double  InpMaxThreat      = 45.0;  // Max threat to ATTACK
input double  InpMaxConflict    = 60.0;  // Conflict above this => WAIT
input double  InpExecProbArm    = 0.50;  // Execution probability to arm (calibrated 0..1)
input bool    InpRequireConfluence = false; // Symphony entries require Decision-layer confirmation (default off: fact gate governs)
input string  __sep_factgate    = "════════ FACT GATE (subsystems do their jobs) ════════"; // ──
input bool    InpUseFactGate     = true;  // Each subsystem casts a concrete VETO (not a score): HTF/owner/zone/structure/room/threat
input double  InpFactPartThreat  = 70.0;  // Opposing participant dominance (%) that vetoes an entry
input double  InpFactNetPressure = 50.0;  // Opposing network authority-pressure that vetoes an entry
input bool    InpFactNeedZone    = true;  // Require price to be AT a real subsystem zone (flip/demand/supply/OB/FU/inducement)
input string  __sep_plan        = "════════ TRADE PLAN (subsystem-composed) ════════"; // ──
input bool    InpUseTradePlan    = true;  // Compose stop/target/size from subsystems (off: Symphony anchor+-ATR / ARC)
input double  InpMinRR           = 4.0;   // Min reward:risk (from subsystem stop+target) to take an entry
input double  InpStopBufATR      = 0.25;  // Buffer beyond the zone-invalidation level for the stop (ATR)
input bool    InpFractalZones    = true;  // Also consider the OWNER TF's zones (per-TF liquidity/OB/S&D) for entry location + stop
input double  InpMaxStopATR      = 10.0;  // Cap stop distance (ATR) so a far higher-TF zone can't create an absurd stop
input bool    InpUseCurveLocator = true;  // Always-on continuous multi-TF curve position ("you are here") + late-on-curve veto
input double  InpMaxOwnerLegPos  = 0.80;  // Block entries when price is already past this fraction of the OWNER leg (no curve left)
input string  __sep_adapt       = "════════ SELF-LEARNING (adaptive feedback) ════════"; // ──
input bool    InpUseAdaptive     = true;  // Learn per-context edge from own closed trades -> size/veto future trades
input int     InpAdaptMinTrades  = 8;     // Min trades in a context before it influences sizing (veto needs 2x)
input double  InpAdaptVetoR       = -0.30; // Veto a context whose learned expectancy (R/trade) falls to/below this
input double  InpAdaptSizeK       = 0.40; // Size sensitivity to learned edge (lots *= clamp(1 + K*expectancyR, .3, 1.6))
input double  InpAdaptAlpha       = 0.10; // EWMA weight on the newest trade (higher = adapts faster, noisier)
input bool    InpAdaptPersist     = true; // Persist the learning table to Common\Files (survives restarts)
input string  __sep_self        = "════════ SELF-AWARENESS (metacognition) ════════"; // ──
input bool    InpUseSelfAware     = false; // The OS watches its own form/calibration/health -> global risk throttle + stand-down
input double  InpSelfMinThrottle  = 0.25; // Lowest size multiplier when self-confidence is low (1.0 = full)
input double  InpSelfFullConf     = 50.0; // At/above this self-confidence, size is FULL (no throttle); below it ramps down
input int     InpSelfLossHalt     = 6;    // Consecutive losses that trigger a self stand-down (then auto-resumes after a cooldown)
input int     InpSelfHaltBars     = 24;   // Cooldown bars the stand-down lasts before resetting the streak and resuming
input string  __sep_miss       = "════════ MISSED-TRADE LEARNING (regret) ════════"; // ──
input bool    InpUseMissLearn    = true;  // Track blocked signals as shadow trades; override a soft filter that keeps missing winners
input int     InpMissMinN        = 8;     // Min resolved shadow trades per reason before override can activate
input double  InpMissOverrideR    = 0.30; // Override a soft veto whose shadow expectancy (R) reaches/exceeds this
input int     InpMissMaxBars      = 120;  // Bars a shadow trade waits for target/stop before expiring (neutral)

input string  __sep_execution   = "════════ EXECUTION / RISK ════════"; // ──
input bool    InpEnableTrading  = true;  // Allow live order sending
input double  InpRiskPercent    = 0.5;   // Risk % per trade
input double  InpMaxLots        = 1.0;   // Hard cap on lots per entry (safety)
input int     InpMaxOpenPositions = 2;   // Max concurrent open positions across ALL directions (0=off)
input bool    InpBlockIfBreach  = true;  // Block new entries after a risk breach (cooldown)
input bool    InpSessionFilter  = false; // Restrict to London/US windows (off for full backtests)
input double  InpContractValue  = 100.0; // Value per lot per price unit
input bool    InpTrailEnable    = false; // EE ATR trailing engine (OFF: TALON owns trailing)
input double  InpTrailStartATR  = 1.0;   // Start trailing after profit (ATR)
input double  InpTrailDistATR   = 1.5;   // Trailing distance (ATR)
input bool    InpDDProtect      = true;  // Enable drawdown protection
input bool    InpRiskAutoClose  = false; // Let the RISK layer CLOSE trades (DD-flatten + PYRO catastrophe). OFF = only TALON / money manager / SL-TP manage exits
input double  InpMaxDrawdownPct = 12.0;  // Block entries above this drawdown %
input double  InpDDFlattenPct   = 20.0;  // Flatten everything above this drawdown %
input double  InpMaxEntryComplete = 85.0;// Block NEW entries when wave completion >= this (no buying tops / selling bottoms)
input double  InpMinEntryRoomPct  = 25.0;// Block NEW entries when geometry room to target < this
input double  InpAttentionATR     = 1.0; // Entry attention: price must be within this many ATR of the active node (0=off)

input string  __sep_cycles      = "════════ MULTI-ENGINE WAVE CYCLES (A/B/C) ════════"; // ──
input bool    InpRunAllCycles    = true;       // Run LETRA + F16 + Symphony wave cycles simultaneously (comparative)
input FALCON_ENGINE InpEntryEngine = ENG_SYMPHONY; // Which engine's phase cycle DRIVES entries + the canonical phase
input bool    InpRefereeLearn    = true;       // Score each engine's demonstrated accuracy (Wave Intelligence referee)
input int     InpCycleEvalBars   = 20;         // Bars to resolve each engine's directional prediction
input double  InpCycleEvalATR    = 1.2;        // Favorable move (ATR) that scores a prediction a WIN
input int     InpBestMinSamples  = 12;         // Min resolved predictions before BEST/learned selection trusts an engine
input bool    InpCycleRawEntries  = true;       // Selected non-Symphony engine enters on its raw P3/P4 edge (bypass fact gate + zone R:R) — clean A/B/C
input bool    InpCycleFreeRun      = true;       // FREE RUN: authority engine enters on EVERY fresh in-direction phase edge (expansion/return/breakout) — let an accurate engine trade freely
input double  InpCycleRawStopATR   = 1.0;       // FALLBACK stop (ATR) only if no structure found — primary stop is structural (swing/anchor)
input double  InpCycleRawTgtATR    = 4.5;       // (legacy) raw ATR target — superseded: target now = MinRR x structural risk

input string  __sep_money      = "════════ MONEY MANAGER (Symphony v3.0) ════════"; // ──
input bool    InpUseProfitLadder= false; // Use v3.0 live-PnL profit ladder (DISABLED — raw cycle comparison)
input bool    InpCounterDirBlock= false; // Block new entries against a net-profitable opposite book (DISABLED)
input bool    InpNoHedge        = true;  // NO HEDGE: never hold both directions — block a new entry while ANY opposite position is open
input double  InpMaxBasketRiskPct= 0.0;  // Max per-direction basket dollar-risk-at-SL (% equity); 0=off (DISABLED)
input double  InpLadderR1        = 0.7;  // Rung 1 trigger (PnL >= R1 x basket risk) -> bank + breakeven
input double  InpLadderR2        = 1.5;  // Rung 2 trigger -> bank + trail
input double  InpLadderR3        = 2.5;  // Rung 3 trigger -> bank + trail runner
input double  InpLadderFrac1     = 0.20; // Fraction of each leg banked at R1
input double  InpLadderFrac2     = 0.25; // Fraction banked at R2
input double  InpLadderFrac3     = 0.25; // Fraction banked at R3
input double  InpTrailLockPct    = 50.0; // %% of price move locked when trailing (after R2)
input double  InpLadderBEbufATR  = 0.20; // R1 moves stop to BE minus this ATR buffer (room so normal pullbacks don't scratch the runner)
input bool    InpTargetTP        = true; // Set the composed trade-plan target as the position take-profit (bank the runner at destination)

input string  __sep_thermal     = "════════ CAMPAIGN THERMAL RISK (PYRO) ════════"; // ──
input bool    InpUseThermalRisk  = false; // Use PYRO campaign-thermodynamics risk engine (off: basket ceiling governs)
input int     InpMaxStacks       = 12;    // Max stacked entries per directional campaign
input double  InpMaxCampaignLots = 8.0;   // Max total lots per directional campaign
input double  InpHeatThrottle    = 0.55;  // Heat above this shrinks new stack size
input double  InpHeatFreeze      = 0.80;  // Heat above this freezes new stacks
input double  InpHeatCritical    = 1.10;  // Heat above this flattens the campaign (catastrophe stop)
input int     InpMaxAvgDownStacks= 3;     // Max stacks allowed while basket is underwater (anti-martingale)
input double  InpHeatAdverseSpan = 4.0;   // Adverse excursion (ATR) that equals full adverse heat
input double  InpAcctHeatDDPct   = 15.0;  // Account heat: equity drawdown %% that fully freezes admissions

input string  __sep_talon       = "════════ TALON GRIP — breakeven + trail ════════"; // ──
input bool    InpUseTalon        = false; // TALON trailing grip (OFF: no trail — hold to TP / capture-at-done instead)
input bool    InpCaptureAtDone   = true;  // CAPTURE-AT-DONE: bank a profitable trade when the curve reaches its destination (no trailing)
input double  InpCaptureCurvePos = 0.90;  // Curve position (0..1 of the owner leg) that counts the move as "done"
input int     InpTalonStructLen  = 6;     // Structural pivot length for the grip anchor
input double  InpTalonBufATR      = 0.35; // Buffer beyond the structural pivot (ATR)
input double  InpTalonBaseATR     = 3.5;  // Base trail distance far from target (ATR) — loose so winners run to TP
input double  InpTalonConvSpanATR = 6.0;  // Distance-to-target (ATR) over which the trail converges
input double  InpTalonMinTighten  = 0.30; // Tightest trail fraction near target / terminal (0..1)
input double  InpTalonBeATR        = 2.5; // Favorable excursion (ATR) before breakeven locks — LATE, so normal trades aren't scratched at entry
input double  InpTalonGiveback     = 0.45;// PROFIT LOCK: max fraction of PEAK campaign profit TALON will give back (0=lock all, 1=off)
input double  InpTalonLockArmATR   = 2.5; // Peak favorable excursion (ATR) before the profit-lock engages — only protects big runners
input double  InpArcPartialFrac    = 0.33;// Fraction banked when price REACHES the curve destination (0 = let it all run)
input double  InpArcPartialMinATR  = 1.5; // Min favorable excursion (ATR) before any ARC partial is allowed

input string  __sep_viz         = "════════ VISUALIZATION ════════"; // ──
input bool    InpShowDashboard  = true;  // Show unified dashboard
input bool    InpShowHUD        = true;  // Plot Flight HUD levels on chart
input int     InpDashboardTab   = 0;     // 0=Overview 1=Physics 2=Structure 3=Network 4=Curve 5=Campaign 6=Wave 7=HTF 8=Risk 9=Execution 10=Performance 11=Diagnostics 12=Learning
input bool    InpVerboseLog     = false; // Verbose diagnostics logging
input bool    InpJournal        = true;  // Write per-trade CSV journal (panel snapshot @ entry + result) to Common\Files

//==================================================================
// RESOLVED CONFIG STRUCT (snapshots inputs + profile overrides)
//==================================================================
struct FalconConfig
{
   int    profile;
   long   magic;
   int    targetGMT;
   int    seriesBars;
   ENUM_TIMEFRAMES operatingTF;   // the absolute TF the trading core runs on (chart = viewport)
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
   // recursive curve tree (F72)
   bool   useCurveTree;
   double ctOwnerMinE, ctProgressGain, ctStallDecay;
   int    ctMaxNodes;
   // time intelligence (TIE — Engine 8.0)
   bool   useTimeIntel, timeGateEntries;
   double timeQualityFloor;
   // multi-engine wave cycles (comparative A/B/C)
   bool   runAllCycles, refereeLearn, cycleRawEntries, cycleFreeRun;
   int    entryEngine, cycleEvalBars, bestMinSamples;
   double cycleEvalATR, cycleRawStopATR, cycleRawTgtATR;
   // decision
   int    minConf;  double maxThreat, maxConflict, execProbArm;
   bool   requireConfluence;
   bool   useFactGate, factNeedZone;
   double factPartThreat, factNetPressure;
   bool   useTradePlan;
   double minRR, stopBufATR;
   bool   fractalZones;  double maxStopATR;
   bool   useCurveLocator;  double maxOwnerLegPos;
   bool   useAdaptive;  int adaptMinTrades;
   double adaptVetoR, adaptSizeK, adaptAlpha;  bool adaptPersist;
   bool   useSelfAware;  double selfMinThrottle;  int selfLossHalt;
   double selfFullConf;  int selfHaltBars;
   bool   useMissLearn;  int missMinN, missMaxBars;  double missOverrideR;
   // execution
   bool   enableTrading, blockIfBreach, sessionFilter;
   double riskPercent, contractValue;
   double maxLots;
   int    maxOpenPositions;
   bool   trailEnable, ddProtect;
   bool   riskAutoClose;
   double trailStartATR, trailDistATR, maxDrawdownPct, ddFlattenPct;
   double maxEntryComplete, minEntryRoomPct;
   double attentionATR;
   // thermal risk (PYRO)
   bool   useThermalRisk;  int maxStacks;  double maxCampaignLots;
   double heatThrottle, heatFreeze, heatCritical;
   int    maxAvgDownStacks;
   double heatAdverseSpan, acctHeatDDPct;
   // money manager (Symphony v3.0)
   bool   useProfitLadder, counterDirBlock, noHedge;
   double maxBasketRiskPct;
   double ladderR1, ladderR2, ladderR3, ladderFrac1, ladderFrac2, ladderFrac3, trailLockPct;
   double ladderBEbufATR;  bool targetTP;
   // TALON grip (breakeven + trail)
   bool   useTalon;  int talonStructLen;
   bool   captureAtDone;  double captureCurvePos;
   double talonBufATR, talonBaseATR, talonConvSpanATR, talonMinTighten, talonBeATR;
   double talonGiveback, talonLockArmATR;
   double arcPartialFrac, arcPartialMinATR;
   // viz
   bool   showDashboard, verboseLog;  int dashboardTab;
   bool   showHUD;
   bool   journal;
};

FalconConfig g_cfg;

//------------------------------------------------------------------
// QUICK PROFILE — overlay a tuned LETRA / SYMPHONY preset over the
// resolved config. It is a BASE you can modify: each managed value is
// applied ONLY if you left that input at its compiled default — change
// any input and YOUR value wins. The engine identity (and the cycle
// plumbing it needs) is always set by the preset. CUSTOM = no overlay.
//------------------------------------------------------------------
// QUICK PROFILE — the corrected risk/exit FRAME is now the DEFAULT
// config (minR 4 · max 2 pos · no-hedge · riskAutoClose off · TALON on
// with LATE breakeven/profit-lock so trades hold toward TP). So a preset
// only needs to select the ENGINE and, for LETRA, a slightly wider
// stop/target (LETRA overshoots). Overridable: change the input to win.
//------------------------------------------------------------------
void FalconApplyPreset(const int preset)
{
   if(preset==PRESET_CUSTOM) return;

   g_cfg.entryEngine  = (preset==PRESET_LETRA ? ENG_LETRA : ENG_SYMPHONY);
   g_cfg.useSymphony  = true;     // execution host
   g_cfg.runAllCycles = true;     // cycles must run for the engine + referee
   if(InpDashboardTab==0) g_cfg.dashboardTab = 14;   // COMMAND tab

   if(preset==PRESET_LETRA)
   {
      if(InpCycleRawStopATR==1.0) g_cfg.cycleRawStopATR = 1.2;   // a touch more room
      if(InpCycleRawTgtATR ==4.5) g_cfg.cycleRawTgtATR  = 5.5;   // ~4.6R (LETRA overshoots)
   }
   // SYMPHONY uses the (corrected) defaults as-is
}

//------------------------------------------------------------------
// Build resolved config from inputs and apply per-profile overrides.
//------------------------------------------------------------------
void FalconConfigInit()
{
   g_cfg.profile          = InpProfile;
   g_cfg.magic            = InpMagic;
   g_cfg.targetGMT        = InpTargetGMT;
   g_cfg.seriesBars       = InpSeriesBars;
   g_cfg.operatingTF      = (InpOperatingTF==PERIOD_CURRENT ? (ENUM_TIMEFRAMES)_Period : InpOperatingTF);

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

   g_cfg.useCurveTree     = InpUseCurveTree;
   g_cfg.ctOwnerMinE      = InpCTOwnerMinE;
   g_cfg.ctProgressGain   = InpCTProgressGain;
   g_cfg.ctStallDecay     = InpCTStallDecay;
   g_cfg.ctMaxNodes       = InpCTMaxNodes;

   g_cfg.useTimeIntel     = InpUseTimeIntel;
   g_cfg.timeGateEntries  = InpTimeGateEntries;
   g_cfg.timeQualityFloor = InpTimeQualityFloor;

   g_cfg.runAllCycles     = InpRunAllCycles;
   g_cfg.entryEngine      = (int)InpEntryEngine;
   g_cfg.refereeLearn     = InpRefereeLearn;
   g_cfg.cycleEvalBars    = InpCycleEvalBars;
   g_cfg.cycleEvalATR     = InpCycleEvalATR;
   g_cfg.bestMinSamples   = InpBestMinSamples;
   g_cfg.cycleRawEntries  = InpCycleRawEntries;
   g_cfg.cycleFreeRun     = InpCycleFreeRun;
   g_cfg.cycleRawStopATR  = InpCycleRawStopATR;
   g_cfg.cycleRawTgtATR   = InpCycleRawTgtATR;

   g_cfg.minConf          = InpMinConf;
   g_cfg.maxThreat        = InpMaxThreat;
   g_cfg.maxConflict      = InpMaxConflict;
   g_cfg.execProbArm      = InpExecProbArm;
   g_cfg.requireConfluence= InpRequireConfluence;
   g_cfg.useFactGate      = InpUseFactGate;
   g_cfg.factNeedZone     = InpFactNeedZone;
   g_cfg.factPartThreat   = InpFactPartThreat;
   g_cfg.factNetPressure  = InpFactNetPressure;
   g_cfg.useTradePlan     = InpUseTradePlan;
   g_cfg.minRR            = InpMinRR;
   g_cfg.stopBufATR       = InpStopBufATR;
   g_cfg.fractalZones     = InpFractalZones;
   g_cfg.maxStopATR       = InpMaxStopATR;
   g_cfg.useCurveLocator  = InpUseCurveLocator;
   g_cfg.maxOwnerLegPos   = InpMaxOwnerLegPos;
   g_cfg.useAdaptive      = InpUseAdaptive;
   g_cfg.adaptMinTrades   = InpAdaptMinTrades;
   g_cfg.adaptVetoR       = InpAdaptVetoR;
   g_cfg.adaptSizeK       = InpAdaptSizeK;
   g_cfg.adaptAlpha       = InpAdaptAlpha;
   g_cfg.adaptPersist     = InpAdaptPersist;
   g_cfg.useSelfAware     = InpUseSelfAware;
   g_cfg.selfMinThrottle  = InpSelfMinThrottle;
   g_cfg.selfFullConf     = InpSelfFullConf;
   g_cfg.selfLossHalt     = InpSelfLossHalt;
   g_cfg.selfHaltBars     = InpSelfHaltBars;
   g_cfg.useMissLearn     = InpUseMissLearn;
   g_cfg.missMinN         = InpMissMinN;
   g_cfg.missOverrideR    = InpMissOverrideR;
   g_cfg.missMaxBars      = InpMissMaxBars;

   g_cfg.enableTrading    = InpEnableTrading;
   g_cfg.blockIfBreach    = InpBlockIfBreach;
   g_cfg.sessionFilter    = InpSessionFilter;
   g_cfg.riskPercent      = InpRiskPercent;
   g_cfg.maxLots          = InpMaxLots;
   g_cfg.maxOpenPositions = InpMaxOpenPositions;
   g_cfg.contractValue    = InpContractValue;
   g_cfg.trailEnable      = InpTrailEnable;
   g_cfg.trailStartATR    = InpTrailStartATR;
   g_cfg.trailDistATR     = InpTrailDistATR;
   g_cfg.ddProtect        = InpDDProtect;
   g_cfg.riskAutoClose    = InpRiskAutoClose;
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

   g_cfg.useProfitLadder  = InpUseProfitLadder;
   g_cfg.counterDirBlock  = InpCounterDirBlock;
   g_cfg.noHedge          = InpNoHedge;
   g_cfg.maxBasketRiskPct = InpMaxBasketRiskPct;
   g_cfg.ladderR1         = InpLadderR1;
   g_cfg.ladderR2         = InpLadderR2;
   g_cfg.ladderR3         = InpLadderR3;
   g_cfg.ladderFrac1      = InpLadderFrac1;
   g_cfg.ladderFrac2      = InpLadderFrac2;
   g_cfg.ladderFrac3      = InpLadderFrac3;
   g_cfg.trailLockPct     = InpTrailLockPct;
   g_cfg.ladderBEbufATR   = InpLadderBEbufATR;
   g_cfg.targetTP         = InpTargetTP;

   g_cfg.useTalon         = InpUseTalon;
   g_cfg.captureAtDone    = InpCaptureAtDone;
   g_cfg.captureCurvePos  = InpCaptureCurvePos;
   g_cfg.talonStructLen   = InpTalonStructLen;
   g_cfg.talonBufATR      = InpTalonBufATR;
   g_cfg.talonBaseATR     = InpTalonBaseATR;
   g_cfg.talonConvSpanATR = InpTalonConvSpanATR;
   g_cfg.talonMinTighten  = InpTalonMinTighten;
   g_cfg.talonBeATR       = InpTalonBeATR;
   g_cfg.talonGiveback    = InpTalonGiveback;
   g_cfg.talonLockArmATR  = InpTalonLockArmATR;
   g_cfg.arcPartialFrac   = InpArcPartialFrac;
   g_cfg.arcPartialMinATR = InpArcPartialMinATR;

   g_cfg.showDashboard    = InpShowDashboard;
   g_cfg.showHUD          = InpShowHUD;
   g_cfg.verboseLog       = InpVerboseLog;
   g_cfg.dashboardTab     = InpDashboardTab;
   g_cfg.journal          = InpJournal;

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

   // QUICK PROFILE overlay — applied LAST so a chosen preset overrides the
   // individual inputs above (CUSTOM leaves everything as set).
   FalconApplyPreset(InpPreset);
}

#endif // FALCON_CONFIG_MQH
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

   ENUM_TIMEFRAMES tf = g_cfg.operatingTF;
   int c1 = CopyClose(_Symbol,tf,0,need,gClose);
   int c2 = CopyHigh (_Symbol,tf,0,need,gHigh);
   int c3 = CopyLow  (_Symbol,tf,0,need,gLow);
   int c4 = CopyOpen (_Symbol,tf,0,need,gOpen);
   int c5 = CopyTime (_Symbol,tf,0,need,gTime);

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
      if(g_atrHandle==INVALID_HANDLE) g_atrHandle = iATR(_Symbol,g_cfg.operatingTF,g_cfg.atrLen);
      handle = g_atrHandle;
   }
   else if(variant==1)
   {
      if(g_atrFastHandle==INVALID_HANDLE) g_atrFastHandle = iATR(_Symbol,g_cfg.operatingTF,15);
      handle = g_atrFastHandle;
   }
   else
   {
      if(g_atrSlowHandle==INVALID_HANDLE) g_atrSlowHandle = iATR(_Symbol,g_cfg.operatingTF,30);
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

// Absolute HTF rung ladder: [0]M1 [1]M5 [2]M15 [3]H1 [4]H4 [5]D1 [6]W1
// (index 0 = lowest TF, index 6 = highest). Fixed/absolute so the fractal
// model is chart-invariant: the chart is only a viewport.
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

//==================================================================
// PER-TIMEFRAME ZONES — liquidity pools/sweeps, order blocks and
// supply/demand computed on EACH absolute rung (W1..M1), so the zone
// engines are genuinely fractal, not just run on the operating TF.
// Mirrors the operating-TF definitions (OB = last opposing candle
// before an impulse; S/D = OB / flip band +- inducZoneWidth).
//==================================================================
struct FalconTFZones
{
   bool   valid;
   double atr;
   double obTop, obBot;  int obDir;
   double demTop, demBot, supTop, supBot;
   double swingHi, swingLo;
   double poolHi, poolLo;
   bool   sweptHi, sweptLo;
   bool   inDemand, inSupply;
};
FalconTFZones g_tfZones[7];
int           me_opTFIdx = -1;   // ladder index of the operating TF (-1 if not a rung)

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
   me_htfTF[3]=PERIOD_H1;  me_htfTF[4]=PERIOD_H4;  me_htfTF[5]=PERIOD_D1;
   me_htfTF[6]=PERIOD_W1;
   me_opTFIdx = -1;
   for(int i=0;i<7;i++){ if(me_htfTF[i]==g_cfg.operatingTF){ me_opTFIdx=i; break; } }
   for(int i=0;i<7;i++) ZeroMemory(g_tfZones[i]);
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
      if(me_htfTF[i]==g_cfg.operatingTF)
      {
         // UNIFY (single source of truth): the rung that equals the OPERATING TF
         // REUSES the primary wave FSM (g_state.wave) instead of running a second
         // FSM. The chart TF no longer matters — the core runs on operatingTF and
         // this rung mirrors it, so the operating-scale phase exists exactly once.
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
// PER-TF ZONES — compute liquidity pools/sweeps, order block and
// supply/demand for ONE absolute rung from that TF's own bars.
//==================================================================
void ME_TFZones(const ENUM_TIMEFRAMES tf, const int idx)
{
   int pv   = g_cfg.structLen;
   int look = g_cfg.liqSweepLookbk;
   int need = pv*2 + g_cfg.atrLen + MathMax(look,10) + 20;
   double h[],l[],c[],o[];
   ArraySetAsSeries(h,true); ArraySetAsSeries(l,true);
   ArraySetAsSeries(c,true); ArraySetAsSeries(o,true);
   if(CopyHigh(_Symbol,tf,0,need,h)<need) { g_tfZones[idx].valid=false; return; }
   if(CopyLow (_Symbol,tf,0,need,l)<need) { g_tfZones[idx].valid=false; return; }
   if(CopyClose(_Symbol,tf,0,need,c)<need){ g_tfZones[idx].valid=false; return; }
   if(CopyOpen (_Symbol,tf,0,need,o)<need){ g_tfZones[idx].valid=false; return; }

   FalconTFZones z; ZeroMemory(z);
   double atr=0; for(int i=1;i<=g_cfg.atrLen;i++) atr+=(h[i]-l[i]); atr/=MathMax(g_cfg.atrLen,1);
   if(atr<=0) atr=1e-9;
   z.atr=atr;
   double close1=c[1];

   // swing hi/lo (pivot at center) — persist last known when no new pivot
   int center=pv+1; bool isH=true,isL=true;
   for(int k=1;k<=pv;k++){ if(h[center]<=h[center+k]||h[center]<=h[center-k]) isH=false;
                           if(l[center]>=l[center+k]||l[center]>=l[center-k]) isL=false; }
   z.swingHi=(isH? h[center] : g_tfZones[idx].swingHi);
   z.swingLo=(isL? l[center] : g_tfZones[idx].swingLo);

   // liquidity pools = recent extremes; sweep = pierced then closed back inside
   double poolHi=-DBL_MAX, poolLo=DBL_MAX;
   for(int i=2;i<2+look && i<need;i++){ if(h[i]>poolHi) poolHi=h[i]; if(l[i]<poolLo) poolLo=l[i]; }
   z.poolHi=(poolHi==-DBL_MAX?0:poolHi); z.poolLo=(poolLo==DBL_MAX?0:poolLo);
   z.sweptHi=(z.poolHi>0 && h[1]>z.poolHi && close1<z.poolHi);
   z.sweptLo=(z.poolLo>0 && l[1]<z.poolLo && close1>z.poolLo);

   // order block = last opposing candle before a displacement impulse
   double mv=MathAbs(c[1]-c[1+g_cfg.effLen]);
   bool bullImp=(c[1]>o[1] && mv>atr*g_cfg.impulseAtrMult);
   bool bearImp=(c[1]<o[1] && mv>atr*g_cfg.impulseAtrMult);
   z.obDir=DIR_NONE; z.obTop=0; z.obBot=0;
   if(bullImp){ for(int i=2;i<=8 && i<need;i++) if(c[i]<o[i]){ z.obTop=h[i]; z.obBot=l[i]; z.obDir=DIR_LONG; break; } }
   else if(bearImp){ for(int i=2;i<=8 && i<need;i++) if(c[i]>o[i]){ z.obTop=h[i]; z.obBot=l[i]; z.obDir=DIR_SHORT; break; } }

   // supply/demand = OB band, else the per-TF curve flip band, +- inducZoneWidth
   double fb=g_tfCurve[idx].fb, ft=g_tfCurve[idx].ft;
   double demMid=(z.obDir==DIR_LONG && z.obTop!=0)? (z.obTop+z.obBot)*0.5 : (fb!=0? fb : z.swingLo);
   double supMid=(z.obDir==DIR_SHORT&& z.obTop!=0)? (z.obTop+z.obBot)*0.5 : (ft!=0? ft : z.swingHi);
   double w=atr*g_cfg.inducZoneWidth;
   z.demTop=(demMid!=0? demMid+w:0); z.demBot=(demMid!=0? demMid-w:0);
   z.supTop=(supMid!=0? supMid+w:0); z.supBot=(supMid!=0? supMid-w:0);
   z.inDemand=(demMid!=0 && close1<=z.demTop && close1>=z.demBot);
   z.inSupply=(supMid!=0 && close1<=z.supTop && close1>=z.supBot);
   z.valid=true;
   g_tfZones[idx]=z;
}

//==================================================================
// Update per-TF zones for all 7 absolute rungs. The operating-TF rung
// mirrors the already-computed g_state zones (single source of truth).
//==================================================================
void ME_UpdateTFZones()
{
   for(int i=0;i<7;i++)
   {
      if(i==me_opTFIdx)
      {
         FalconTFZones z; ZeroMemory(z);
         z.atr=g_state.physics.atr;
         z.obTop=g_state.orderBlocks.activeTop; z.obBot=g_state.orderBlocks.activeBot; z.obDir=g_state.orderBlocks.activeDir;
         z.demTop=g_state.supplyDemand.demandTop; z.demBot=g_state.supplyDemand.demandBot;
         z.supTop=g_state.supplyDemand.supplyTop; z.supBot=g_state.supplyDemand.supplyBot;
         z.inDemand=g_state.supplyDemand.inDemand; z.inSupply=g_state.supplyDemand.inSupply;
         z.swingHi=g_state.structure.swingHigh;   z.swingLo=g_state.structure.swingLow;
         z.sweptHi=g_state.liquidity.sweepBear;    z.sweptLo=g_state.liquidity.sweepBull;
         z.valid=true;
         g_tfZones[i]=z;
      }
      else ME_TFZones(me_htfTF[i], i);
   }
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
   ME_UpdateTFZones();   // per-TF liquidity/OB/S&D across the W1..M1 ladder
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

   // OWNERSHIP CASCADE — the owner is the HIGHEST absolute TF in control
   // (h.ownerTF, from the W1->M1 ladder). Direction, origin (invalidation) and
   // extreme are INHERITED from that owning TF's curve, not the operating-TF
   // wave. When a higher TF takes control, ownerTF rises and the whole frame
   // (direction + destination) escalates with it — a true fractal cascade.
   int ownTF = (h.ownerTF>=0 && h.ownerTF<7)? h.ownerTF : 4;
   int ownTFDir = g_tfCurve[ownTF].oDir;
   c.ownerDir    = (ownTFDir!=DIR_NONE ? ownTFDir : (h.stackDir!=DIR_NONE ? h.stackDir : w.direction));
   c.ownerOrigin = (g_tfCurve[ownTF].oOrigin!=0.0 ? g_tfCurve[ownTF].oOrigin : w.origin);
   c.ownerExtreme= (g_tfCurve[ownTF].oExtreme!=0.0 ? g_tfCurve[ownTF].oExtreme : w.extreme);
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

//  ===== Engines/CurveTree.mqh =====
//+------------------------------------------------------------------+
//|  FALCON OS — Intelligence : CurveTree.mqh                       |
//|  Source: F16 Raptor — F72 RECURSIVE CURVE TREE                  |
//|                                                                  |
//|  CURVES INSIDE CURVES. Recursion is EVENT-generated, not          |
//|  timeframe-generated: a Phase-2 CHoCH against the OWNING node     |
//|  spawns a CHILD curve (same lifecycle, opposite orientation).     |
//|  Ownership = the shallowest living node that still holds energy    |
//|  (Principle 8). A child that keeps making progress GAINS energy    |
//|  and eventually owns (→ transfer); one that stalls decays and dies |
//|  (→ merge back into the parent). COMPRESSION sets the recursion     |
//|  BUDGET: a wide curve makes ~1 deep recursion, a failure-swing     |
//|  (high compression) up to 4 tiny ones.                            |
//|                                                                   |
//|  This is the genuine event-driven CurveNode array the PORT_AUDIT   |
//|  flagged as missing (the previous build only derived a per-rung    |
//|  tree). It runs AFTER MemoryEngine (owner TF resolved) and ENRICHES |
//|  g_state.curve with the recursive-tree summary. Additive: it does  |
//|  NOT change the authoritative direction/ownership (phases stay      |
//|  OUTPUTS) — it is the curve-tree the spec's Intelligence Layer asks |
//|  for, observable on the Curve tab.                                  |
//+------------------------------------------------------------------+
#ifndef FALCON_CURVE_TREE_MQH
#define FALCON_CURVE_TREE_MQH


//==================================================================
// EVENT-DRIVEN CURVE NODE (port of F16 type CurveNode)
//==================================================================
struct CTNode
{
   int    id;
   int    parent;
   int    dir;
   double origin;
   double extreme;
   double energy;
   bool   alive;
   int    depth;
   string state;     // emergent phase the node owns (Principle 1: curve -> phase)
   int    bar;       // bar_index at birth
   double comp;      // this curve's own compression
   double mat;       // this curve's own maturity
   int    srcTf;     // ladder index of the source timeframe (depth-0 root only)
};

#define CT_CAP 96
CTNode ct_tree[CT_CAP];
int    ct_count = 0;
int    ct_seq   = 0;

// compression history ring (for the "tightening vs broadening" read)
double ct_compHist[6];
int    ct_compIdx = 0;
bool   ct_compFull = false;

// narrative lineage state (persists across bars)
int    ct_narrDir   = 0;
int    ct_supVotes  = 0;
int    ct_degVotes  = 0;
double ct_narrative = 50.0;

void CurveTreeInit()
{
   ct_count=0; ct_seq=0; ct_compIdx=0; ct_compFull=false;
   ct_narrDir=0; ct_supVotes=0; ct_degVotes=0; ct_narrative=50.0;
   for(int i=0;i<6;i++) ct_compHist[i]=0.0;
   for(int i=0;i<CT_CAP;i++){ ZeroMemory(ct_tree[i]); ct_tree[i].alive=false; ct_tree[i].parent=-1; }
}

//------------------------------------------------------------------
// f_nodeState — phases EMERGE from the node (Principle 1: curve -> phase)
// (faithful port of F16 f_nodeState)
//------------------------------------------------------------------
string CT_NodeState(const int d,const double e,const int dep,const double cmp,const double mat)
{
   if(dep>0)
      return(e>=70.0 ? "Transition · recursive expansion"
           : e>=40.0 ? "Transition · recursive induction"
                     : "Transition · recursive liquidation");
   if(mat<12.0) return("Point 4 Origin");
   if(e>=78.0 && mat>=70.0) return(d==1 ? "New High" : d==-1 ? "New Low" : "Climax");
   if(mat<35.0) return("Expansion");
   if(mat<55.0) return("Expansion Pre-Convexity");
   if(e>=55.0)  return("Expansion Induction");
   if(e>=35.0)  return("Expansion Liquidity");
   if(cmp>=60.0)return("Retracement Pre-Convexity");
   if(e>=18.0)  return("Retracement Induction");
   return("Retracement");
}

//------------------------------------------------------------------
// shift the oldest node out (keep the array bounded)
//------------------------------------------------------------------
void CT_Shift()
{
   for(int i=1;i<ct_count;i++) ct_tree[i-1]=ct_tree[i];
   if(ct_count>0) ct_count--;
}

//------------------------------------------------------------------
// MASTER ENTRY — Recursive Curve Tree pipeline step
//------------------------------------------------------------------
void CurveTreeRun()
{
   if(!g_cfg.useCurveTree) return;

   FalconHTF  h = g_state.htf;
   double atr   = g_state.physics.atr;
   double close1= gClose[1];
   double hi1   = gHigh[1];
   double lo1   = gLow[1];
   double expE  = g_state.physics.energy;          // expansion-energy proxy (0..100)
   double comp  = g_state.physics.compression;     // chart/operating compression
   double residual = g_state.intel.residualEnergy; // back-filled by Intelligence

   int ot = (h.ownerTF>=0 && h.ownerTF<7) ? h.ownerTF : 4;

   // CHoCH against the owner — the event that nests a child curve
   bool bullCHoCH = (g_state.structure.choch==DIR_LONG);
   bool bearCHoCH = (g_state.structure.choch==DIR_SHORT);

   double ownMinE = g_cfg.ctOwnerMinE;

   //--------------------------------------------------------------
   // PRE-OWNER (Principle 8) — shallowest living node still holding
   // energy; drives the child-spawn direction.
   //--------------------------------------------------------------
   int    preOwn=-1; double preE=-1.0; int preDepth=999;
   for(int i=0;i<ct_count;i++)
   {
      if(ct_tree[i].alive && ct_tree[i].energy>=ownMinE &&
         (ct_tree[i].depth<preDepth || (ct_tree[i].depth==preDepth && ct_tree[i].energy>preE)))
      { preDepth=ct_tree[i].depth; preE=ct_tree[i].energy; preOwn=i; }
   }
   if(preOwn<0)
      for(int i=0;i<ct_count;i++)
         if(ct_tree[i].alive && ct_tree[i].energy>preE){ preE=ct_tree[i].energy; preOwn=i; }

   //--------------------------------------------------------------
   // CONTEXT ANCHOR — the root curve is born from the timeframe-stable
   // OWNER curve, so its origin does not shift with the chart.
   //--------------------------------------------------------------
   int    ctxDir = g_tfCurve[ot].oDir;
   double ctxOrig= g_tfCurve[ot].oOrigin;
   double ctxExt = g_tfCurve[ot].oExtreme;
   if(ctxDir==DIR_NONE){ ctxDir=h.stackDir; }

   // seed / RE-SEED the root whenever no living node owns price
   if(preOwn<0 && ctxDir!=DIR_NONE && ctxOrig!=0.0)
   {
      if(ct_count>=CT_CAP) CT_Shift();
      ct_seq++;
      CTNode root; ZeroMemory(root);
      root.id=ct_seq; root.parent=-1; root.dir=ctxDir;
      root.origin=ctxOrig; root.extreme=(ctxExt!=0.0?ctxExt:close1);
      root.energy=MathMax(40.0, expE>0?expE:60.0);
      root.alive=true; root.depth=0; root.bar=g_barCounter; root.srcTf=ot;
      root.comp=comp; root.mat=g_tfCurve[ot].oCompletion;
      root.state=CT_NodeState(root.dir,root.energy,0,root.comp,root.mat);
      ct_tree[ct_count++]=root;
      FalconPublish(EVT_NODE_BORN, root.origin);
   }

   //--------------------------------------------------------------
   // COMPRESSION BUDGET (Principle 3/4) — how many curves can form.
   //--------------------------------------------------------------
   int budgetDepth = (int)MathMax(1.0, MathMin(4.0, 1.0 + MathRound(comp/33.0)));

   //--------------------------------------------------------------
   // EVENT-GENERATED CHILD — a CHoCH against the owner spawns an
   // inverse curve, while the recursion budget still has room.
   //--------------------------------------------------------------
   bool spawnedChild=false;
   if(preOwn>=0)
   {
      int pdir=ct_tree[preOwn].dir;
      bool against = (pdir==DIR_LONG && bearCHoCH) || (pdir==DIR_SHORT && bullCHoCH);
      if(against && (ct_tree[preOwn].depth+1<=budgetDepth))
      {
         if(ct_count>=CT_CAP) CT_Shift();
         ct_seq++;
         CTNode ch; ZeroMemory(ch);
         ch.id=ct_seq; ch.parent=ct_tree[preOwn].id; ch.dir=-pdir;
         ch.origin=close1; ch.extreme=close1;
         ch.energy=MathMax(25.0, (expE>0?expE:50.0)*0.85);
         ch.alive=true; ch.depth=ct_tree[preOwn].depth+1; ch.bar=g_barCounter; ch.srcTf=0;
         ch.comp=comp; ch.mat=0.0;
         ch.state=CT_NodeState(ch.dir,ch.energy,ch.depth,ch.comp,ch.mat);
         ct_tree[ct_count++]=ch;
         spawnedChild=true;
         FalconPublish(EVT_NODE_BORN, ch.origin);
      }
   }

   //--------------------------------------------------------------
   // UPDATE LIVING NODES — energy rises on progress, decays on stall.
   //--------------------------------------------------------------
   for(int i=0;i<ct_count;i++)
   {
      if(!ct_tree[i].alive) continue;
      // depth-0 root mirrors its source TF's live curve (dir/origin/extreme)
      if(ct_tree[i].depth==0)
      {
         int st=ct_tree[i].srcTf; if(st<0||st>6) st=ot;
         ct_tree[i].dir    = (g_tfCurve[st].oDir!=DIR_NONE? g_tfCurve[st].oDir : ct_tree[i].dir);
         ct_tree[i].origin = (g_tfCurve[st].oOrigin!=0.0? g_tfCurve[st].oOrigin : ct_tree[i].origin);
         ct_tree[i].extreme= (g_tfCurve[st].oExtreme!=0.0? g_tfCurve[st].oExtreme : ct_tree[i].extreme);
         ct_tree[i].mat    = g_tfCurve[st].oCompletion;
      }
      bool prog = (ct_tree[i].dir==DIR_LONG ? hi1>ct_tree[i].extreme : lo1<ct_tree[i].extreme);
      if(ct_tree[i].depth>0)
         ct_tree[i].extreme = (ct_tree[i].dir==DIR_LONG ? MathMax(ct_tree[i].extreme,hi1)
                                                        : MathMin(ct_tree[i].extreme,lo1));
      ct_tree[i].energy = prog ? MathMin(100.0, ct_tree[i].energy + g_cfg.ctProgressGain)
                               : MathMax(0.0,   ct_tree[i].energy - g_cfg.ctStallDecay);
      ct_tree[i].comp   = comp;
      ct_tree[i].state  = CT_NodeState(ct_tree[i].dir, ct_tree[i].energy, ct_tree[i].depth, ct_tree[i].comp, ct_tree[i].mat);
      if(ct_tree[i].energy<=2.0) ct_tree[i].alive=false;
   }

   // trim dead/old beyond budget
   while(ct_count > g_cfg.ctMaxNodes) CT_Shift();

   //--------------------------------------------------------------
   // FINAL OWNER (Principle 8) + tree summary
   //--------------------------------------------------------------
   int    alive=0, treeDepth=0;
   int    ownF=-1; double ownFE=-1.0; int ownDepth=999;
   for(int i=0;i<ct_count;i++)
   {
      if(!ct_tree[i].alive) continue;
      alive++;
      if(ct_tree[i].depth>treeDepth) treeDepth=ct_tree[i].depth;
      if(ct_tree[i].energy>=ownMinE &&
         (ct_tree[i].depth<ownDepth || (ct_tree[i].depth==ownDepth && ct_tree[i].energy>ownFE)))
      { ownDepth=ct_tree[i].depth; ownFE=ct_tree[i].energy; ownF=i; }
   }
   if(ownF<0)
      for(int i=0;i<ct_count;i++)
         if(ct_tree[i].alive && ct_tree[i].energy>ownFE){ ownFE=ct_tree[i].energy; ownF=i; }

   //--------------------------------------------------------------
   // COMPRESSION PERSISTENCE (Principle 10) — can the COUNTER side even
   // generate room to build? Tightening + concentrated energy + few
   // recursions ⇒ the opposite side suffocates (PERSISTING).
   //--------------------------------------------------------------
   double comp5 = (ct_compFull ? ct_compHist[(ct_compIdx)%6] : comp); // value ~5 bars ago
   double cmpTighten = comp - comp5;
   double compForce = FalconClamp(comp*0.50 + residual*0.20 - treeDepth*12.0
                                  + MathMax(0.0,cmpTighten)*0.8 + 8.0, 0, 100);
   string compState = compForce>=60.0 ? "PERSISTING" : compForce<=35.0 ? "LEAKING" : "NEUTRAL";
   // push current compression into the ring
   ct_compHist[ct_compIdx]=comp; ct_compIdx=(ct_compIdx+1)%6; if(ct_compIdx==0) ct_compFull=true;

   bool recursionComplete = (budgetDepth>0 && treeDepth>=budgetDepth);

   //--------------------------------------------------------------
   // NARRATIVE LINEAGE — each completed child (pullback) votes SUPPORT
   // (shallow retrace + tightening) or DEGRADE (deep retrace + broadening).
   // A converging sequence ⇒ strengthening; diverging ⇒ ownership about
   // to transfer.
   //--------------------------------------------------------------
   int ownDirT = (ownF>=0 ? ct_tree[ownF].dir : DIR_NONE);
   double ownOrig = (ownF>=0 ? ct_tree[ownF].origin : 0.0);
   double ownExt  = (ownF>=0 ? ct_tree[ownF].extreme: 0.0);
   if(ownDirT!=ct_narrDir){ ct_narrDir=ownDirT; ct_supVotes=0; ct_degVotes=0; ct_narrative=50.0; }
   if(spawnedChild)
   {
      double retrX = (ownExt==ownOrig) ? 50.0
                     : FalconClamp(MathAbs(ownExt-close1)/MathMax(MathAbs(ownExt-ownOrig),1e-10)*100.0,0,100);
      bool support = (retrX<45.0 && cmpTighten>0.0);
      bool degrade = (retrX>60.0 && cmpTighten<0.0);
      if(support) ct_supVotes++;
      else if(degrade) ct_degVotes++;
      ct_narrative = FalconClamp(50.0 + (ct_supVotes-ct_degVotes)*10.0, 0, 100);
   }

   // migrated ownership band — 0.5 / 0.618 retrace of the owner curve leg
   double mig50  = (ownOrig==0.0||ownExt==0.0) ? 0.0 : ownExt + 0.5  *(ownOrig-ownExt);
   double mig618 = (ownOrig==0.0||ownExt==0.0) ? 0.0 : ownExt + 0.618*(ownOrig-ownExt);

   //--------------------------------------------------------------
   // ENRICH SHARED STATE (additive — does NOT change ownerDir/phase)
   //--------------------------------------------------------------
   g_state.curve.treeNodeCount   = alive;
   g_state.curve.treeDepth       = treeDepth;
   g_state.curve.budgetDepth     = budgetDepth;
   g_state.curve.recursionComplete = recursionComplete;
   g_state.curve.ownerNodeDir    = ownDirT;
   g_state.curve.ownerNodeEnergy = (ownF>=0 ? ct_tree[ownF].energy : 0.0);
   g_state.curve.ownerNodeDepth  = (ownF>=0 ? ct_tree[ownF].depth  : 0);
   g_state.curve.ownerNodeOrigin = ownOrig;
   g_state.curve.ownerNodeExtreme= ownExt;
   g_state.curve.ownerNodeState  = (ownF>=0 ? ct_tree[ownF].state : "—");
   g_state.curve.compForce       = compForce;
   g_state.curve.compState       = compState;
   g_state.curve.migration50     = mig50;
   g_state.curve.migration618    = mig618;
   g_state.curve.narrative       = ct_narrative;
   g_state.curve.supportVotes    = ct_supVotes;
   g_state.curve.degradeVotes    = ct_degVotes;
   // emergent-node count = living recursion children (depth>0)
   int kids=0; for(int i=0;i<ct_count;i++) if(ct_tree[i].alive && ct_tree[i].depth>0) kids++;
   g_state.curve.emergentNodes   = kids;
   g_state.curve.childCount      = kids;
}

#endif // FALCON_CURVE_TREE_MQH
//+------------------------------------------------------------------+

//  ===== Engines/TimeEngine.mqh =====
//+------------------------------------------------------------------+
//|  FALCON OS — Intelligence : TimeEngine.mqh                      |
//|  Source: F16 Raptor — ENGINE 8.0 (Time Intelligence Engine)     |
//|                                                                  |
//|  THE TEMPORAL LAYER. Markets do not behave uniformly across the  |
//|  clock: a London-open expansion is not a dead Asian-lunch range. |
//|  TIE models a 5-CYCLE TEMPORAL STACK and synthesises one          |
//|  continuous timeQuality + a path probability + a SOFT temporal    |
//|  permission. It is informational by default — the HARD session    |
//|  window stays in the separate session filter. (Design law:        |
//|  hard risk/time limits are kept separate from probability layers.)|
//|                                                                  |
//|  The 5 cycles (each 0..100 favourability):                       |
//|    1. SESSION cycle   — Asia / London / NY / overlap structure    |
//|    2. HOUR cycle      — gold's intraday volatility profile        |
//|    3. KILLZONE cycle  — London-open & NY-open high-prob windows   |
//|    4. WEEKDAY cycle   — Mon ramp · mid-week peak · Fri fade        |
//|    5. WEEKPOS cycle   — early/mid/late-week momentum bias          |
//|                                                                  |
//|  Writes g_state.timeIntel. Reads only the clock (TimeGMT) + the    |
//|  GMT offset already used by the session filter — no market recompute|
//+------------------------------------------------------------------+
#ifndef FALCON_TIME_ENGINE_MQH
#define FALCON_TIME_ENGINE_MQH


void TimeEngineInit() { ZeroMemory(g_state.timeIntel); }

//------------------------------------------------------------------
// Gold's typical intraday volatility profile by session-adjusted hour
// (0..100). Two humps: the London open (~7-10) and the NY open + the
// London/NY overlap (~12-16). Asia (~0-6) and the post-NY lull (~17-23)
// are low. A smooth heuristic, not a fitted curve.
//------------------------------------------------------------------
double TIE_HourVol(const int hh)
{
   // hand-tuned 24-slot profile (relative expected range for XAUUSD)
   static double prof[24] =
   {
      28,24,22,20,22,30,45,68,  // 00-07  Asia -> London ramp
      82,88,80,66,72,90,95,88,  // 08-15  London peak -> NY open / overlap peak
      72,58,46,40,36,34,32,30   // 16-23  NY fade -> post-NY lull
   };
   int i = hh; if(i<0) i=0; if(i>23) i=23;
   return(prof[i]);
}

//------------------------------------------------------------------
// MASTER ENTRY — Time Intelligence Engine pipeline step
//------------------------------------------------------------------
void TimeEngineRun()
{
   FalconTime t;
   ZeroMemory(t);

   if(!g_cfg.useTimeIntel)
   {
      // neutral pass-through so downstream weighing is a no-op
      t.session=SES_CLOSED; t.sessionName="(off)";
      t.timeQuality=100.0; t.pathProbability=0.5; t.permit=true; t.label="—";
      for(int k=0;k<5;k++) t.cycle[k]=100.0;
      g_state.timeIntel=t;
      return;
   }

   MqlDateTime g; TimeGMT(g);
   int hh = g.hour + g_cfg.targetGMT;
   while(hh<0) hh+=24; while(hh>=24) hh-=24;
   int cur = hh*60 + g.min;

   t.hour      = hh;
   t.minute    = g.min;
   t.dayOfWeek = g.day_of_week;

   //--------------------------------------------------------------
   // CYCLE 1 — SESSION structure
   //   Asia 00:00-06:59 · London 07:00-15:59 · NY 12:00-20:59 ·
   //   Overlap 12:00-15:59 (London & NY both live = the prime window)
   //--------------------------------------------------------------
   int    ses=SES_CLOSED; double sesStart=0, sesLen=1; double sesFav=30;
   bool   ldn = (cur>=420 && cur<960);   // 07:00-15:59
   bool   ny  = (cur>=720 && cur<1260);  // 12:00-20:59
   bool   asia= (cur>=0   && cur<420);   // 00:00-06:59
   if(ldn && ny) { ses=SES_OVERLAP; sesStart=720; sesLen=240; sesFav=95; }
   else if(ldn)  { ses=SES_LONDON;  sesStart=420; sesLen=300; sesFav=82; }
   else if(ny)   { ses=SES_NY;      sesStart=960; sesLen=300; sesFav=78; } // NY-only portion (after overlap)
   else if(asia) { ses=SES_ASIA;    sesStart=0;   sesLen=420; sesFav=42; }
   else          { ses=SES_CLOSED;  sesStart=1260;sesLen=180; sesFav=24; } // 21:00-23:59 lull

   t.session     = ses;
   t.sessionName = FalconSessionStr(ses);
   t.sessionProgress = FalconClamp((cur - sesStart)/MathMax(sesLen,1.0), 0.0, 1.0);
   t.cycle[0]    = sesFav;

   //--------------------------------------------------------------
   // CYCLE 2 — HOUR volatility profile
   //--------------------------------------------------------------
   t.volExpectation       = TIE_HourVol(hh);
   t.liquidityExpectation = FalconClamp(t.volExpectation*0.7 + sesFav*0.3, 0, 100);
   t.cycle[1]             = t.volExpectation;

   //--------------------------------------------------------------
   // CYCLE 3 — KILLZONE windows (high-probability institutional times)
   //   London open 07:00-10:00 · NY open 12:00-15:00 (GMT-adjusted)
   //--------------------------------------------------------------
   bool kzLondon = (cur>=420 && cur<600);
   bool kzNY     = (cur>=720 && cur<900);
   t.killzone = (kzLondon || kzNY);
   t.killzoneName = kzLondon ? "LONDON OPEN" : kzNY ? "NY OPEN" : "—";
   t.cycle[2] = t.killzone ? 92.0 : (asia ? 35.0 : 55.0);

   //--------------------------------------------------------------
   // CYCLE 4 — WEEKDAY cycle (Mon ramp, Tue-Thu peak, Fri fade,
   //   weekend dead). day_of_week: 0=Sun .. 6=Sat.
   //--------------------------------------------------------------
   double dayFav;
   switch(g.day_of_week)
   {
      case 1: dayFav=70; break;  // Mon
      case 2: dayFav=90; break;  // Tue
      case 3: dayFav=95; break;  // Wed
      case 4: dayFav=90; break;  // Thu
      case 5: dayFav=62; break;  // Fri (fade into close)
      default: dayFav=15; break; // Sat/Sun
   }
   t.cycle[3]=dayFav;

   //--------------------------------------------------------------
   // CYCLE 5 — WEEK-POSITION momentum bias. Early week tends to
   //   establish the move, late week mean-reverts / books profit.
   //--------------------------------------------------------------
   double weekPos = (g.day_of_week>=1 && g.day_of_week<=5) ? (g.day_of_week-1)/4.0 : 1.0; // 0=Mon..1=Fri
   t.cycle[4] = FalconClamp(100.0 - weekPos*45.0, 0, 100); // momentum strongest early

   //--------------------------------------------------------------
   // COMPOSITE timeQuality — weighted blend of the stack. Session and
   // killzone dominate (institutional participation drives gold).
   //--------------------------------------------------------------
   t.timeQuality = FalconClamp(
        t.cycle[0]*0.28      // session
      + t.cycle[1]*0.24      // hour vol
      + t.cycle[2]*0.22      // killzone
      + t.cycle[3]*0.16      // weekday
      + t.cycle[4]*0.10,     // week position
      0, 100);

   //--------------------------------------------------------------
   // PATH probability — likelihood the clock favours a CONTINUATION
   // (expansion) rather than chop. Higher in killzones / overlap.
   //--------------------------------------------------------------
   t.pathProbability = FalconClamp(t.timeQuality/100.0*0.7 + (t.killzone?0.2:0.0) + (ses==SES_OVERLAP?0.1:0.0), 0.0, 1.0);

   //--------------------------------------------------------------
   // TEMPORAL bias — London typically EXPANDS the Asian range (its
   // direction emerges from price, not the clock), so TIE stays
   // direction-agnostic and only flags the regime, not a side.
   //--------------------------------------------------------------
   t.temporalBias = DIR_NONE;

   t.permit = (t.timeQuality >= g_cfg.timeQualityFloor);
   t.label  = (t.timeQuality>=78 ? "PRIME" : t.timeQuality>=g_cfg.timeQualityFloor ? "ACTIVE" : t.timeQuality>=22 ? "QUIET" : "DEAD");

   g_state.timeIntel=t;
}

#endif // FALCON_TIME_ENGINE_MQH
//+------------------------------------------------------------------+

//  ===== Engines/CurveLocator.mqh =====
//+------------------------------------------------------------------+
//|  FALCON OS — Intelligence : CurveLocator.mqh                    |
//|                                                                  |
//|  "NEVER LOSE WHERE YOU ARE ON THE CURVE."                        |
//|                                                                  |
//|  A single always-on, continuous, multi-TF coordinate of where    |
//|  price sits between the OWNING curve's origin and destination.   |
//|  It is never undefined:                                          |
//|    • continuous (geometric interpolation, not a phase bucket),    |
//|    • anchored to the OWNER TF and cascading UP the ladder when a  |
//|      lower curve resets,                                          |
//|    • confidence DECAYS and the last good position PERSISTS on a   |
//|      reset instead of snapping to zero,                           |
//|    • velocity tells which way along the curve price is moving.    |
//|                                                                  |
//|  Reads the per-TF curves (g_tfCurve) the Market Engine already    |
//|  builds. Run after the Memory layer (ownership final). Writes     |
//|  g_state.curveLocator. Phases stay OUTPUTS — labels off `pos`.    |
//+------------------------------------------------------------------+
#ifndef FALCON_CURVE_LOCATOR_MQH
#define FALCON_CURVE_LOCATOR_MQH


double cl_prevPos     = -1.0;
double cl_vel         = 0.0;
double cl_conf        = 0.0;
double cl_lastGoodPos = 0.5;
int    cl_lastGoodDir = 0;

void CurveLocatorInit()
{
   cl_prevPos=-1.0; cl_vel=0.0; cl_conf=0.0; cl_lastGoodPos=0.5; cl_lastGoodDir=0;
}

// Continuous position on one TF's leg: 0 at origin, 1 at destination.
// The formula self-normalises for both long and short curves (dest-origin
// flips sign with direction). Returns -1 when the leg is undefined.
double CL_LegPos(const int idx, const double price)
{
   double o = g_tfCurve[idx].oOrigin;
   double d = g_tfCurve[idx].oObjective;
   if(o==0.0 || d==0.0 || MathAbs(d-o)<1e-9) return(-1.0);
   double p = (price - o) / (d - o);
   return(FalconClamp(p, 0.0, 1.2));   // small overshoot allowed past target
}

void CurveLocatorRun()
{
   if(!g_cfg.useCurveLocator) return;

   FalconCurveLocator cl; ZeroMemory(cl);
   double price = gClose[1];

   // per-TF positions (the fractal "you are here" on every rung)
   for(int i=0;i<7;i++) cl.legPos[i] = CL_LegPos(i, price);

   // master = OWNER TF; cascade UP the ladder if the owner leg is undefined,
   // then DOWN, so a location is essentially always found.
   int oi = g_state.htf.ownerTF; if(oi<0 || oi>6) oi=4;
   double pos=-1.0; int usedTF=oi;
   for(int i=oi;i<7;i++)   { if(cl.legPos[i]>=0.0){ pos=cl.legPos[i]; usedTF=i; break; } }
   if(pos<0.0) for(int i=oi-1;i>=0;i--){ if(cl.legPos[i]>=0.0){ pos=cl.legPos[i]; usedTF=i; break; } }

   double conf;
   if(pos>=0.0)
   {
      cl_lastGoodPos = pos;
      cl_lastGoodDir = g_tfCurve[usedTF].oDir;
      conf = FalconClamp(60.0 + g_state.htf.alignment*0.4, 0, 100);
   }
   else
   {
      // GRACEFUL DEGRADATION — keep the last known location, decay confidence.
      pos    = cl_lastGoodPos;
      usedTF = oi;
      conf   = cl_conf*0.85;
   }

   // velocity (EMA of position change) — advancing toward destination when >= 0
   if(cl_prevPos>=0.0) cl_vel = FalconEMA(cl_vel, pos-cl_prevPos, 3);
   cl_prevPos = pos;
   cl_conf    = conf;

   int usedDir = (g_tfCurve[usedTF].oDir!=0 ? g_tfCurve[usedTF].oDir : cl_lastGoodDir);
   cl.pos       = pos;
   cl.dir       = usedDir;
   cl.vel       = cl_vel;
   cl.conf      = conf;
   cl.ownerTF   = usedTF;
   cl.advancing = (cl_vel >= 0.0);
   cl.label     = (pos<0.20?"Early":pos<0.50?"Developing":pos<0.80?"Mid":pos<0.95?"Late":"Terminal");

   g_state.curveLocator = cl;
}

#endif // FALCON_CURVE_LOCATOR_MQH
//+------------------------------------------------------------------+

//  ===== Engines/WaveCycleIntel.mqh =====
//+------------------------------------------------------------------+
//|  FALCON OS — Intelligence : WaveCycleIntel.mqh                  |
//|                                                                  |
//|  THE COMPARATIVE WAVE FRAMEWORK (S12 Wave Intelligence becomes   |
//|  the REFEREE). Don't replace the phase engine — run THREE wave-  |
//|  cycle engines on the SAME shared observations and let the market |
//|  decide which has the highest predictive power:                  |
//|                                                                  |
//|        MARKET ENGINE  (shared observations once / bar)           |
//|              │                                                   |
//|     ┌────────┼────────┐                                          |
//|   LETRA    F16      SYMPHONY                                     |
//|   Eng 1A   Eng 8/F72 Phase Engine                               |
//|     └────────┼────────┘                                          |
//|        Wave Intelligence (referee: compare / validate / score)   |
//|              │                                                   |
//|        Decision & Execution                                      |
//|                                                                  |
//|  Each engine emits a NORMALIZED forecast (phase · stage · dir ·  |
//|  maturity · objective · invalidation · confidence · next event)  |
//|  into g_state.cycles[]. The referee (Part C, below) tracks each   |
//|  engine's demonstrated accuracy and forms a consensus / best.    |
//|                                                                  |
//|  THIS FILE reads g_state only (LETRA + F16 lenses + referee).    |
//|  The Symphony cycle is computed inside SymphonyEngine.mqh where   |
//|  the sym_* phase state lives. Include AFTER CurveLocator.mqh.     |
//+------------------------------------------------------------------+
#ifndef FALCON_WAVE_CYCLE_INTEL_MQH
#define FALCON_WAVE_CYCLE_INTEL_MQH


//==================================================================
// NORMALIZATION HELPERS — shared across all three engines so they are
// judged on the SAME yardstick.
//==================================================================
// Fill the entry-trigger fields from the just-computed stage + the
// previous bar's stage (edge detection). A return (CYC_RETURN) is the
// P3 analog; a breakout (CYC_BREAKOUT) is the P4 analog.
void Cycle_FillEntry(WaveCycle &cy,const int prevStage)
{
   cy.prevStage  = prevStage;
   cy.entryArmed = (cy.stage==CYC_RETURN || cy.stage==CYC_BREAKOUT) && cy.direction!=DIR_NONE;
   cy.entryEdge  = cy.entryArmed && (prevStage != cy.stage);
   cy.entryKind  = (cy.stage==CYC_BREAKOUT ? 4 : cy.stage==CYC_RETURN ? 3 : 0);
   cy.entryDir   = cy.entryArmed ? cy.direction : DIR_NONE;
}

// carry referee-learned performance forward (compute steps rebuild the
// descriptive fields each bar but must NOT wipe accumulated accuracy)
void Cycle_CarryPerf(WaveCycle &cy,const WaveCycle &prev)
{
   cy.accuracy    = prev.accuracy;
   cy.objAccuracy = prev.objAccuracy;
   cy.avgLeadBars = prev.avgLeadBars;
   cy.samples     = prev.samples;
   cy.wins        = prev.wins;
}

//==================================================================
// ENGINE 1 — LETRA wave cycle (the per-TF fixed-structure lifecycle).
//   Reads the NATIVE LETRA wave FSM (g_state.wave) BEFORE any phase
//   authority overwrites it. me_pst lifecycle 0..14 -> normalized
//   stage + canonical phase.
//==================================================================
void CycleLetra_Compute()
{
   WaveCycle cy; ZeroMemory(cy);
   Cycle_CarryPerf(cy, g_state.cycles[ENG_LETRA]);
   int prevStage = g_state.cycles[ENG_LETRA].stage;

   FalconWave w = g_state.wave;   // native LETRA at this point in the pipeline
   int pst = w.phase;             // 0..14 lifecycle
   int dir = w.direction;

   cy.engineId  = ENG_LETRA;
   cy.direction = dir;
   cy.maturity  = w.completion;
   cy.objective = w.objective;
   cy.invalidation = w.origin;
   cy.confidence = FalconClamp(w.confidence*0.6 + w.strength*0.4, 0, 100);

   int stage, ph; string nxt;
   switch(pst)
   {
      case 1:  stage=CYC_EXPANSION; ph=PH_EXPANSION;    nxt="decay -> retrace"; break;
      case 2:  stage=CYC_RETRACE;   ph=PH_RETRACEMENT;  nxt="counter-impulse / transfer"; break;
      case 3:  stage=CYC_RETURN;    ph=(dir==DIR_LONG?PH_DEMAND_RETURN:PH_SUPPLY_RETURN); nxt="confirm BOS continuation"; break;
      case 4:  stage=CYC_BREAKOUT;  ph=(dir==DIR_LONG?PH_NEW_HIGH:PH_NEW_LOW);  nxt="extend to objective"; break;
      case 5:  case 6: stage=CYC_BREAKOUT; ph=(dir==DIR_LONG?PH_NEW_HIGH:PH_NEW_LOW); nxt="post-extreme recursion"; break;
      case 7:  stage=CYC_RETRACE;   ph=PH_RETRACEMENT;  nxt="transfer of ownership"; break;
      case 8:  stage=CYC_RETRACE;   ph=PH_TRANSITION;   nxt="return to flip zone"; break;
      case 9:  stage=CYC_RETURN;    ph=(dir==DIR_LONG?PH_DEMAND_RETURN:PH_SUPPLY_RETURN); nxt="impulse from flip"; break;
      case 10: stage=CYC_BREAKOUT;  ph=(dir==DIR_LONG?PH_NEW_HIGH:PH_NEW_LOW);  nxt="continuation to target"; break;
      case 11: stage=CYC_RETRACE;   ph=PH_LIQUIDATION;  nxt="opposing BOS / reversal risk"; break;
      case 12: stage=CYC_RETRACE;   ph=PH_LIQUIDATION;  nxt="liquidity sweep"; break;
      case 13: case 14: stage=CYC_RETURN; ph=(dir==DIR_LONG?PH_DEMAND_RETURN:PH_SUPPLY_RETURN); nxt="terminal reversal confirm"; break;
      default: stage=CYC_NONE;      ph=PH_TRANSITION;   nxt="awaiting impulse"; break;
   }
   cy.stage      = stage;
   cy.phase      = ph;
   cy.phaseLabel = FalconPhaseStr(ph);
   cy.nextEvent  = nxt;
   Cycle_FillEntry(cy, prevStage);

   g_state.cycles[ENG_LETRA] = cy;
}

//==================================================================
// ENGINE 2 — F16 wave cycle (the recursive curve-tree node lens).
//   Phases EMERGE from the owning node (Principle 1). Reads the F72
//   tree summary in g_state.curve (populated by CurveTree.mqh).
//==================================================================
bool CY_Contains(const string s,const string sub){ return(StringFind(s,sub)>=0); }

void CycleF16_Compute()
{
   WaveCycle cy; ZeroMemory(cy);
   Cycle_CarryPerf(cy, g_state.cycles[ENG_F16]);
   int prevStage = g_state.cycles[ENG_F16].stage;

   FalconCurve cu = g_state.curve;
   int dir   = cu.ownerNodeDir!=DIR_NONE ? cu.ownerNodeDir : cu.ownerDir;
   string st = cu.ownerNodeState;
   double org= cu.ownerNodeOrigin;
   double ext= cu.ownerNodeExtreme;

   cy.engineId  = ENG_F16;
   cy.direction = dir;
   cy.maturity  = FalconClamp(cu.ownerNodeEnergy, 0, 100);
   cy.invalidation = org;
   // owner-curve destination: project the leg beyond its extreme
   double leg = (org!=0.0 && ext!=0.0) ? MathAbs(ext-org) : 0.0;
   cy.objective = (ext!=0.0 && leg>0.0) ? (dir==DIR_LONG ? ext+leg*0.5 : ext-leg*0.5)
                                        : g_state.wave.objective;
   cy.confidence= FalconClamp(cu.ownerNodeEnergy*0.55 + cu.narrative*0.30 + (cu.recursionComplete?0:15.0), 0, 100);

   int stage, ph; string nxt;
   if(CY_Contains(st,"New High"))      { stage=CYC_BREAKOUT; ph=PH_NEW_HIGH;  nxt="extend / recursion budget"; }
   else if(CY_Contains(st,"New Low"))  { stage=CYC_BREAKOUT; ph=PH_NEW_LOW;   nxt="extend / recursion budget"; }
   else if(CY_Contains(st,"Climax"))   { stage=CYC_BREAKOUT; ph=(dir==DIR_LONG?PH_NEW_HIGH:PH_NEW_LOW); nxt="exhaustion / transfer"; }
   else if(CY_Contains(st,"Origin"))   { stage=CYC_RETURN;   ph=(dir==DIR_LONG?PH_DEMAND_RETURN:PH_SUPPLY_RETURN); nxt="impulse off node origin"; }
   else if(CY_Contains(st,"recursive")){ stage=CYC_RETURN;   ph=(dir==DIR_LONG?PH_DEMAND_RETURN:PH_SUPPLY_RETURN); nxt="child curve resolves"; }
   else if(CY_Contains(st,"Retracement")){ stage=CYC_RETRACE; ph=PH_RETRACEMENT; nxt="return to demand/supply"; }
   else if(CY_Contains(st,"Induction")){ stage=CYC_EXPANSION; ph=PH_EXP_INDUCTION; nxt="liquidity engineered"; }
   else if(CY_Contains(st,"Liquidity")){ stage=CYC_EXPANSION; ph=PH_EXP_LIQUIDITY; nxt="sweep then continue"; }
   else if(CY_Contains(st,"Expansion")){ stage=CYC_EXPANSION; ph=PH_EXPANSION;  nxt="convexity develops"; }
   else                                { stage=CYC_NONE;     ph=PH_TRANSITION;  nxt="awaiting owner node"; }

   cy.stage      = stage;
   cy.phase      = ph;
   cy.phaseLabel = (st!="" && st!="—") ? st : FalconPhaseStr(ph);
   cy.nextEvent  = nxt;
   Cycle_FillEntry(cy, prevStage);

   g_state.cycles[ENG_F16] = cy;
}

//==================================================================
// ════════ S12J — WAVE INTELLIGENCE REFEREE (Engine Comparison) ════
//   Rather than ONE truth, the referee asks "who has been right
//   recently?" It opens a SHADOW PREDICTION whenever an engine casts a
//   directional entry edge, resolves it after cycleEvalBars (or when a
//   +/- cycleEvalATR excursion settles it), and rolls each engine's
//   demonstrated directional + objective accuracy (EWMA). It also forms
//   the consensus, measures disagreement (wave deviation), and flags
//   the best / leading engine — turning FALCON into a self-evaluating
//   research platform. Phases stay OUTPUTS: the referee scores evidence.
//==================================================================
struct CyclePrediction
{
   bool   active;
   int    engineId;
   int    dir;
   double entryPx;
   double objective;
   double atr;
   int    openBar;
   double mfe;     // best favorable excursion (price units)
   double mae;     // worst adverse excursion
};
#define CY_MAX_PRED 48
CyclePrediction cy_pred[CY_MAX_PRED];
int             cy_predCount = 0;

// per-engine running stats (live; mirrored into g_state.cycles each bar)
double cy_acc[FALCON_NCYCLES];      // EWMA directional accuracy %%
double cy_objAcc[FALCON_NCYCLES];   // EWMA objective-reach %%
double cy_lead[FALCON_NCYCLES];     // EWMA early-detection lead (bars)
int    cy_samples[FALCON_NCYCLES];
int    cy_wins[FALCON_NCYCLES];
int    cy_lastDirBar[FALCON_NCYCLES]; // bar each engine last FLIPPED direction
int    cy_lastDir[FALCON_NCYCLES];
int    cy_leadCount[FALCON_NCYCLES];  // times this engine led a shared flip

void WaveRefereeInit()
{
   cy_predCount=0;
   for(int i=0;i<CY_MAX_PRED;i++){ ZeroMemory(cy_pred[i]); cy_pred[i].active=false; }
   for(int i=0;i<FALCON_NCYCLES;i++)
   {
      cy_acc[i]=50.0; cy_objAcc[i]=50.0; cy_lead[i]=0.0;
      cy_samples[i]=0; cy_wins[i]=0;
      cy_lastDirBar[i]=0; cy_lastDir[i]=DIR_NONE; cy_leadCount[i]=0;
   }
   ZeroMemory(g_state.referee);
}

//------------------------------------------------------------------
// open a shadow prediction for an engine's directional entry edge
//------------------------------------------------------------------
void CY_OpenPrediction(const int eng,const int dir,const double objective)
{
   if(dir==DIR_NONE) return;
   double atr = g_state.physics.atr; if(atr<=0.0) atr=FalconATR(1); if(atr<=0.0) return;
   // dedupe: one active prediction per engine+direction
   for(int i=0;i<cy_predCount;i++)
      if(cy_pred[i].active && cy_pred[i].engineId==eng && cy_pred[i].dir==dir) return;

   if(cy_predCount>=CY_MAX_PRED)
   {
      // shift oldest out
      for(int i=1;i<cy_predCount;i++) cy_pred[i-1]=cy_pred[i];
      cy_predCount--;
   }
   CyclePrediction p; ZeroMemory(p);
   p.active=true; p.engineId=eng; p.dir=dir; p.entryPx=gClose[1];
   p.objective=objective; p.atr=atr; p.openBar=g_barCounter; p.mfe=0.0; p.mae=0.0;
   cy_pred[cy_predCount++]=p;
}

//------------------------------------------------------------------
// resolve a prediction: WIN if it ran +cycleEvalATR favorably (or hit
// objective) before -cycleEvalATR adverse; LOSS otherwise. Updates EWMA.
//------------------------------------------------------------------
void CY_ScorePrediction(const int idx,const bool win,const bool objHit)
{
   int e = cy_pred[idx].engineId;
   if(e<0||e>=FALCON_NCYCLES) return;
   double a = g_cfg.refereeLearn ? 0.12 : 0.0;   // EWMA weight
   cy_acc[e]    = cy_acc[e]*(1.0-a)    + (win?100.0:0.0)*a;
   cy_objAcc[e] = cy_objAcc[e]*(1.0-a) + (objHit?100.0:0.0)*a;
   cy_samples[e]++;
   if(win) cy_wins[e]++;
   cy_pred[idx].active=false;
}

//------------------------------------------------------------------
// advance + resolve all open predictions on the new bar
//------------------------------------------------------------------
void CY_AdvancePredictions()
{
   double hi=gHigh[1], lo=gLow[1];
   for(int i=0;i<cy_predCount;i++)
   {
      if(!cy_pred[i].active) continue;
      double favTarget = cy_pred[i].atr*g_cfg.cycleEvalATR;
      double fav = (cy_pred[i].dir==DIR_LONG ? hi-cy_pred[i].entryPx : cy_pred[i].entryPx-lo);
      double adv = (cy_pred[i].dir==DIR_LONG ? cy_pred[i].entryPx-lo : hi-cy_pred[i].entryPx);
      if(fav>cy_pred[i].mfe) cy_pred[i].mfe=fav;
      if(adv>cy_pred[i].mae) cy_pred[i].mae=adv;

      bool objHit = (cy_pred[i].objective!=0.0 &&
                     (cy_pred[i].dir==DIR_LONG ? hi>=cy_pred[i].objective : lo<=cy_pred[i].objective));
      // settle: favorable target reached -> win; adverse target first -> loss
      if(cy_pred[i].mfe>=favTarget || objHit){ CY_ScorePrediction(i,true,objHit); continue; }
      if(cy_pred[i].mae>=favTarget){ CY_ScorePrediction(i,false,false); continue; }
      // timeout: judge on net excursion at the horizon
      if(g_barCounter-cy_pred[i].openBar >= g_cfg.cycleEvalBars)
      { CY_ScorePrediction(i, cy_pred[i].mfe>cy_pred[i].mae, false); }
   }
   // compact resolved
   int w=0;
   for(int i=0;i<cy_predCount;i++) if(cy_pred[i].active) cy_pred[w++]=cy_pred[i];
   cy_predCount=w;
}

//------------------------------------------------------------------
// early-detection lead: when engines agree on a NEW direction, the one
// that flipped first earns lead bars over the laggards.
//------------------------------------------------------------------
void CY_TrackLead()
{
   for(int e=0;e<FALCON_NCYCLES;e++)
   {
      int d=g_state.cycles[e].direction;
      if(d!=DIR_NONE && d!=cy_lastDir[e]){ cy_lastDir[e]=d; cy_lastDirBar[e]=g_barCounter; }
   }
   // find the consensus direction and who reached it earliest
   for(int e=0;e<FALCON_NCYCLES;e++)
   {
      int d=cy_lastDir[e]; if(d==DIR_NONE) continue;
      int agree=0, earliest=g_barCounter+1, leadEng=e;
      for(int k=0;k<FALCON_NCYCLES;k++)
         if(cy_lastDir[k]==d){ agree++; if(cy_lastDirBar[k]<earliest){ earliest=cy_lastDirBar[k]; leadEng=k; } }
      if(agree>=2 && leadEng==e)
      {
         // lead = how many bars ahead of the latest agreeing engine
         int latest=0;
         for(int k=0;k<FALCON_NCYCLES;k++) if(cy_lastDir[k]==d && cy_lastDirBar[k]>latest) latest=cy_lastDirBar[k];
         double lb=(double)(latest-cy_lastDirBar[e]);
         if(lb>0){ cy_lead[e]=cy_lead[e]*0.8+lb*0.2; cy_leadCount[e]++; }
      }
   }
}

//==================================================================
// MASTER ENTRY — the referee. Runs AFTER all three cycles are computed.
//==================================================================
void WaveRefereeRun()
{
   // 1) score open predictions on this freshly-closed bar
   CY_AdvancePredictions();

   // 2) open new shadow predictions for any engine casting an entry edge
   for(int e=0;e<FALCON_NCYCLES;e++)
      if(g_state.cycles[e].entryEdge && g_state.cycles[e].entryDir!=DIR_NONE)
         CY_OpenPrediction(e, g_state.cycles[e].entryDir, g_state.cycles[e].objective);

   // 3) early-detection lead tracking
   CY_TrackLead();

   // 4) publish per-engine stats back into the cycle structs
   for(int e=0;e<FALCON_NCYCLES;e++)
   {
      g_state.cycles[e].accuracy    = cy_acc[e];
      g_state.cycles[e].objAccuracy = cy_objAcc[e];
      g_state.cycles[e].avgLeadBars = cy_lead[e];
      g_state.cycles[e].samples     = cy_samples[e];
      g_state.cycles[e].wins        = cy_wins[e];
   }

   // 5) CONSENSUS — direction agreed by >=2 engines (weight by demonstrated
   //    accuracy so a proven engine breaks ties).
   WaveReferee r; ZeroMemory(r);
   double bull=0.0, bear=0.0;
   for(int e=0;e<FALCON_NCYCLES;e++)
   {
      double wgt = FalconClamp(g_state.cycles[e].accuracy/100.0,0.1,1.0);
      if(g_state.cycles[e].direction==DIR_LONG)  bull+=wgt;
      if(g_state.cycles[e].direction==DIR_SHORT) bear+=wgt;
   }
   int agreeL=0, agreeS=0;
   for(int e=0;e<FALCON_NCYCLES;e++)
   {
      if(g_state.cycles[e].direction==DIR_LONG)  agreeL++;
      if(g_state.cycles[e].direction==DIR_SHORT) agreeS++;
   }
   if(agreeL>=2 && bull>bear)      r.consensusDir=DIR_LONG;
   else if(agreeS>=2 && bear>bull) r.consensusDir=DIR_SHORT;
   else                            r.consensusDir=DIR_NONE;

   // consensus stage + confidence = average over engines that match consensus
   int    cnt=0; double confSum=0.0, stageSum=0.0;
   for(int e=0;e<FALCON_NCYCLES;e++)
      if(r.consensusDir!=DIR_NONE && g_state.cycles[e].direction==r.consensusDir)
      { confSum+=g_state.cycles[e].confidence; stageSum+=g_state.cycles[e].stage; cnt++; }
   r.consensusConf  = (cnt>0?confSum/cnt:0.0);
   r.consensusStage = (cnt>0?(int)MathRound(stageSum/cnt):CYC_NONE);

   // 6) WAVE DEVIATION — disagreement across engines (stage + objective).
   int sMin=9, sMax=-1; double oMin=DBL_MAX, oMax=-DBL_MAX; int oCnt=0;
   for(int e=0;e<FALCON_NCYCLES;e++)
   {
      int s=g_state.cycles[e].stage;
      if(s<sMin) sMin=s; if(s>sMax) sMax=s;
      double o=g_state.cycles[e].objective;
      if(o!=0.0){ if(o<oMin) oMin=o; if(o>oMax) oMax=o; oCnt++; }
   }
   r.deviationStage  = (sMax>=0? (double)(sMax-sMin):0.0);
   double atr=g_state.physics.atr; if(atr<=0.0) atr=FalconATR(1); if(atr<=0.0) atr=1.0;
   r.deviationObjATR = (oCnt>=2? (oMax-oMin)/atr : 0.0);

   // 7) BEST + LEADER engines (need a minimum sample before trusting).
   r.bestEngine=ENG_SYMPHONY; r.bestAccuracy=-1.0; r.leader=ENG_SYMPHONY;
   int bestLead=-1;
   for(int e=0;e<FALCON_NCYCLES;e++)
   {
      if(cy_samples[e]>=g_cfg.bestMinSamples && cy_acc[e]>r.bestAccuracy)
      { r.bestAccuracy=cy_acc[e]; r.bestEngine=e; }
      if(cy_leadCount[e]>bestLead){ bestLead=cy_leadCount[e]; r.leader=e; }
   }
   if(r.bestAccuracy<0.0){ r.bestEngine=ENG_SYMPHONY; r.bestAccuracy=cy_acc[ENG_SYMPHONY]; }

   // 8) RESOLVE the engine that DRIVES this bar (selector).
   int sel;
   if(g_cfg.entryEngine==ENG_BEST)           sel=r.bestEngine;
   else if(g_cfg.entryEngine==ENG_CONSENSUS) sel=ENG_CONSENSUS;   // handled specially downstream
   else                                      sel=g_cfg.entryEngine;
   r.selectedEngine=sel;
   r.selectedName  =FalconEngineStr(g_cfg.entryEngine==ENG_BEST?r.bestEngine:g_cfg.entryEngine);
   r.note = StringFormat("L%.0f%% F%.0f%% S%.0f%%  dev:st%.0f obj%.1fATR",
              cy_acc[ENG_LETRA], cy_acc[ENG_F16], cy_acc[ENG_SYMPHONY],
              r.deviationStage, r.deviationObjATR);

   g_state.referee=r;
}

#endif // FALCON_WAVE_CYCLE_INTEL_MQH
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
//==================================================================
// REASONING SYSTEMS REMOVED — Belief · Hypothesis · Prediction ·
// Validation · Threat · Opportunity · Intent · Story · Energy
// Resolution are GONE. Reasoning is now the concrete engines only
// (phases · curve tree · campaign ownership · curve locator ·
// structure · true multi-TF) — see IE_ConcreteReason below.
//==================================================================

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
// CONCRETE REASONING — the reasoning is the DEEP STRUCTURAL ENGINES,
// not belief/probability blends. confidence / threat / opportunity /
// executionProbability are derived ONLY from: phases, curve tree,
// campaign ownership, curve locator, structure, and true multi-TF.
// The belief / energy-resolution / forecast / hypothesis / prediction
// / validation engines are REMOVED from the decision path (per design
// law: phases are outputs, structure is the reasoning).
//==================================================================
void IE_ConcreteReason(FalconIntelligence &x)
{
   FalconWave         w  = g_state.wave;
   FalconHTF          h  = g_state.htf;
   FalconCurve        c  = g_state.curve;
   FalconCampaign     cm = g_state.campaign;
   FalconStructure    st = g_state.structure;
   FalconConvexity    cv = g_state.convexity;
   FalconCurveLocator cl = g_state.curveLocator;

   int    owner = (cm.owner!=DIR_NONE ? cm.owner : c.ownerDir);   // campaign / curve ownership
   double mtf   = h.alignment;                                    // true multi-TF agreement
   double ctrl  = MathMax(cm.controlScore, c.life);               // ownership control / curve life
   double room  = cv.geometryCapacity;                            // remaining geometry (concrete)
   bool   structAgree = (st.trend==owner && owner!=DIR_NONE);     // structure
   bool   chochAgainst= (owner!=DIR_NONE && st.choch==-owner);
   bool   htfOpposes  = (h.stackDir!=DIR_NONE && owner!=DIR_NONE && h.stackDir!=owner);
   bool   advancing   = (!g_cfg.useCurveLocator) || cl.advancing; // curve locator
   double locPos      = (g_cfg.useCurveLocator ? cl.pos : 0.5);

   // --- belief / energy / forecast fields REMOVED (zeroed; no longer reasoned on) ---
   x.beliefExpansion=0; x.beliefConvexity=0; x.beliefCreation=0;
   x.beliefAbsorption=0; x.beliefRetracement=0; x.beliefReturn=0;
   x.expansionEnergy=0; x.dissipatedEnergy=0; x.dissipationProgress=0;
   x.attractorPrice=0; x.attractorScore=0;

   // residual / resolution derived CONCRETELY from curve geometry + locator
   x.residualEnergy  = FalconClamp(room,0,100);
   x.resolutionState = (locPos>=0.92 ? RES_RESOLVED : locPos>=0.60 ? RES_PARTIALLY_RESOLVED : RES_UNRESOLVED);
   x.failureSwingProb= FalconClamp(((chochAgainst?40.0:0.0)+(htfOpposes?30.0:0.0)
                       +(!advancing?20.0:0.0)+(locPos>=0.85?20.0:0.0))/100.0,0,1);
   x.immediateExecutionProb = FalconClamp((locPos<0.5 && advancing?0.55:0.20)+(structAgree?0.20:0.0),0,1);

   // CONFIDENCE — concrete structural conviction (multi-TF · ownership · structure · locator)
   x.confidence = FalconClamp(0.40*mtf + 0.22*ctrl + (structAgree?14.0:0.0) + (advancing?8.0:0.0)
                  + (h.fractalAgreement?10.0:0.0) - (chochAgainst?25.0:0.0) - (htfOpposes?15.0:0.0),0,100);

   // EXECUTION PROBABILITY — concrete: ownership · multi-TF · room · locator · structure
   double ep = 0.35*(mtf/100.0) + 0.22*(ctrl/100.0) + 0.18*(room/100.0)
             + 0.13*(advancing?1.0:0.0) + 0.12*(structAgree?1.0:0.0);
   ep *= (chochAgainst?0.35:1.0);
   ep *= (locPos>=0.85?0.45:1.0);
   x.executionProbability = FalconClamp(ep,0,1);

   // THREAT / OPPORTUNITY / HYPOTHESIS / PREDICTION / VALIDATION / INTENT / STORY
   // are REMOVED reasoning systems — kept as inert fields only (never reasoned on).
   x.threat=0; x.opportunity=0; x.opportunityGrade="";
   x.hypothesis=""; x.hypothesisDir=DIR_NONE; x.hypothesisProb=0;
   x.prediction=""; x.predictionPrice=0; x.predictionProb=0;
   x.validated=false; x.validationScore=0;
   x.intent=""; x.timing=""; x.story="";
}

//==================================================================
// MASTER ENTRY — Intelligence Engine pipeline step
//==================================================================
void IntelligenceEngineRun()
{
   FalconIntelligence x=g_state.intel;
   IE_ConcreteReason(x);   // reasoning = phases · curve tree · ownership · locator · structure · multi-TF
   g_state.intel=x;
   IE_EntryCycle(x);       // concrete build-vs-execute brain (ownership / terminal / zones)
   g_state.campaign.remainingEnergy = x.residualEnergy;   // = remaining curve geometry
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
   int    resCode      = x.resolutionState;

   //-- CONVICTION IS NOW CONCRETE — confidence / threat / opportunity are
   //   computed by the Intelligence Engine from the DEEP STRUCTURAL ENGINES
   //   (phases · curve tree · ownership · curve locator · structure · multi-TF),
   //   NOT from belief/energy blends. The Decision Engine consumes them as-is.
   double threat     = x.threat;
   double confidence = x.confidence;
   double oppScore   = x.opportunity;
   string oppGrade   = (x.opportunityGrade!="" ? x.opportunityGrade : DE_OppGrade(master,conflict,oppScore));

   //-- WRITE meta into intel + execution snapshot ------------------
   x.alignment       = alignment;
   x.conflict        = conflict;
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
ulong ee_lastTicket = 0;   // POSITION ticket of the most recent successful entry
bool EE_SendMarketOrder(const int direction,const double lots,const double sl,const string comment,const double tp=0.0)
{
   if(lots<=0.0) return(false);
   if(!g_cfg.enableTrading) { FalconInfo("ExecutionEngine","trading disabled - skipped order"); return(false); }
   MqlTradeRequest req; MqlTradeResult res; ZeroMemory(req); ZeroMemory(res);
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   req.action=TRADE_ACTION_DEAL; req.symbol=_Symbol; req.magic=g_cfg.magic;
   req.volume=lots; req.sl=sl; req.tp=(tp>0.0?tp:0.0); req.deviation=20;
   req.type_filling=ORDER_FILLING_IOC; req.type_time=ORDER_TIME_GTC; req.comment=comment;
   if(direction>0){ req.type=ORDER_TYPE_BUY; req.price=ask; }
   else           { req.type=ORDER_TYPE_SELL;req.price=bid; }
   if(!OrderSend(req,res) || (res.retcode!=TRADE_RETCODE_DONE && res.retcode!=TRADE_RETCODE_DONE_PARTIAL))
   {
      FalconPublish(EVT_ORDER_FAILED,direction,comment);
      FalconError("ExecutionEngine",StringFormat("order failed dir=%d ret=%d",direction,res.retcode));
      return(false);
   }
   // expose the resulting POSITION ticket (for the trade journal / diagnostics)
   ee_lastTicket = 0;
   if(res.deal>0 && HistoryDealSelect(res.deal))
      ee_lastTicket = (ulong)HistoryDealGetInteger(res.deal, DEAL_POSITION_ID);
   if(ee_lastTicket==0) ee_lastTicket = (ulong)res.order;
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
      // hard protection: flatten everything — UNLESS the risk layer is set to
      // not auto-close (then TALON / money manager / SL-TP own all exits; we
      // still block new entries below).
      if(g_cfg.riskAutoClose)
      {
         int total=PositionsTotal();
         for(int i=total-1;i>=0;i--)
         {
            ulong ticket=PositionGetTicket(i);
            if(!PositionSelectByTicket(ticket)) continue;
            if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
            if(PositionGetInteger(POSITION_MAGIC)!=g_cfg.magic) continue;
            EE_CloseFull(ticket);
         }
         g_state.exec.exitState=XS_DD_FLATTEN;
      }
      FalconPublish(EVT_RISK_BREACH, worst, "drawdown flatten");
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
      // EE's own ATR trail + partial yield to TALON or the money-manager ladder
      // whenever either owns exits — never run two trailing managers at once.
      if(!g_cfg.useTalon && !g_cfg.useProfitLadder)
      {
         EE_Trailing();
         EE_ManagePartialTP();
      }

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
   if(c.admission==ADM_DERISK && g_cfg.riskAutoClose)
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

//  ===== Engines/MoneyManager.mqh =====
//+------------------------------------------------------------------+
//|  FALCON OS — Execution Layer : MoneyManager.mqh                 |
//|  Source: SYMPHONY v3.0 (the profitable standalone)               |
//|                                                                  |
//|  The three money-management mechanisms that made the standalone  |
//|  Symphony profitable — ported verbatim in behaviour, adapted to  |
//|  FALCON's shared config + EE order helpers:                      |
//|                                                                  |
//|   1. COUNTER-DIRECTION PROFITABILITY LOCK                        |
//|        Never open longs while the short book is net profitable,  |
//|        and vice-versa. A counter-trend bounce inside a running   |
//|        profitable campaign is noise, not a new campaign. This is |
//|        the single biggest reason v3.0 doesn't chop.              |
//|                                                                  |
//|   2. PRE-ENTRY BASKET RISK CEILING                               |
//|        Size lots DOWN at entry so per-direction dollar-risk-at-SL |
//|        stays under InpMaxBasketRiskPct of equity. Deterministic, |
//|        correct at entry — no trim-after-entry. Lets the book     |
//|        pyramid into a trend while total risk stays bounded.      |
//|                                                                  |
//|   3. LIVE-PnL PROFIT LADDER                                      |
//|        Banks on the realised reward:risk RATIO of the live book  |
//|        (not on phase geometry): R1 @0.7x -> bank+breakeven,      |
//|        R2 @1.5x -> bank+trail 50%, R3 @2.5x -> bank+trail runner. |
//|        Anchored to broker positions; survives phase resets.      |
//|                                                                  |
//|  Reuses EE_ClosePartial / EE_ModifySL. Include AFTER             |
//|  ExecutionEngine, BEFORE SymphonyEngine (which calls these).     |
//+------------------------------------------------------------------+
#ifndef FALCON_MONEY_MANAGER_MQH
#define FALCON_MONEY_MANAGER_MQH


//==================================================================
// LADDER STATE — keyed to the LIVE position book (per direction).
// Rungs reset only when a direction's position count reaches zero
// (campaign fully closed), so they survive phase-engine resets.
//==================================================================
int  mm_longRungs        = 0;
int  mm_shortRungs       = 0;
bool mm_longBEActive     = false;
bool mm_shortBEActive    = false;
bool mm_longTrailActive  = false;
bool mm_shortTrailActive = false;

struct MMPos { ulong ticket; datetime openTime; double lots; };

void MoneyManagerInit()
{
   mm_longRungs=0; mm_shortRungs=0;
   mm_longBEActive=false; mm_shortBEActive=false;
   mm_longTrailActive=false; mm_shortTrailActive=false;
}

//==================================================================
// EXPOSURE / RISK HELPERS
//==================================================================
// Total dollar-risk-at-SL for all open positions in one direction:
//   sum( lots * |entry-sl| * contractValue ).  No VaR, no netting.
double MM_BasketDollarRisk(const int direction)
{
   double totalRisk=0.0;
   double atrFB=FalconATR(1); if(atrFB<=0.0) atrFB=10.0;
   int total=PositionsTotal();
   for(int i=0;i<total;i++)
   {
      ulong ticket=PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol)  continue;
      if(PositionGetInteger(POSITION_MAGIC)!=g_cfg.magic) continue;
      int dir=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?1:-1;
      if(dir!=direction) continue;
      double lots =PositionGetDouble(POSITION_VOLUME);
      double entry=PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   =PositionGetDouble(POSITION_SL);
      double distSL=(sl>0.0)?MathAbs(entry-sl):(2.0*atrFB);
      totalRisk += lots*distSL*g_cfg.contractValue;
   }
   return(totalRisk);
}

// Floating PnL (profit+swap only; MT5 deprecated POSITION_COMMISSION) for a dir.
double MM_DirectionFloatingPnL(const int direction)
{
   double total=0.0;
   int cnt=PositionsTotal();
   for(int i=0;i<cnt;i++)
   {
      ulong ticket=PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol)  continue;
      if(PositionGetInteger(POSITION_MAGIC)!=g_cfg.magic) continue;
      int dir=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?1:-1;
      if(dir!=direction) continue;
      total += PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
   }
   return(total);
}

// COUNTER-DIRECTION LOCK: block a new entry in `dir` while the OPPOSITE
// book is net profitable. (The heart of v3.0's no-chop behaviour.)
bool MM_CounterDirBlocked(const int dir)
{
   if(!g_cfg.counterDirBlock) return(false);
   int opp=-dir;
   return(MM_DirectionFloatingPnL(opp) > 0.0);
}

// PRE-ENTRY BASKET CEILING: scale computedLots down so adding this entry
// keeps the direction's basket dollar-risk under InpMaxBasketRiskPct of
// equity. Returns 0 if even one min-lot would breach. No trim-after-entry.
double MM_AdjustLotsForBasketCeiling(const int direction,const double entry,
                                     const double sl,const double computedLots)
{
   if(computedLots<=0.0) return(0.0);
   if(g_cfg.maxBasketRiskPct<=0.0) return(computedLots);   // ceiling disabled

   double equity        = AccountInfoDouble(ACCOUNT_EQUITY);
   double maxBasketRisk = equity*g_cfg.maxBasketRiskPct/100.0;
   double currentRisk   = MM_BasketDollarRisk(direction);
   double available     = maxBasketRisk-currentRisk;
   if(available<=0.0) return(0.0);                          // ceiling reached

   double distSL=MathAbs(entry-sl);
   if(distSL<=0.0) return(0.0);

   if(computedLots*distSL*g_cfg.contractValue <= available)
      return(computedLots);                                 // fits as-is

   double maxLots = available/(distSL*g_cfg.contractValue);
   double minLot  = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double lotStep = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(lotStep<=0) lotStep=0.01; if(minLot<=0) minLot=0.01;
   maxLots=MathFloor(maxLots/lotStep)*lotStep;
   if(maxLots<minLot) return(0.0);
   return(NormalizeDouble(maxLots,2));
}

//==================================================================
// STOP PROTECTION (after ladder rungs)
//==================================================================
// Move all remaining stops in a direction to BE minus a small ATR buffer.
// Exact-breakeven scratches medium winners (a normal pullback to entry stops
// the remainder flat); the buffer leaves room so only a real reversal stops it,
// while still cutting most of the risk after R1.
void MM_MoveStopsToBreakeven(const int direction)
{
   double buf = FalconATR(1)*g_cfg.ladderBEbufATR; if(buf<0) buf=0;
   int cnt=PositionsTotal();
   for(int i=0;i<cnt;i++)
   {
      ulong ticket=PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol)  continue;
      if(PositionGetInteger(POSITION_MAGIC)!=g_cfg.magic) continue;
      int dir=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?1:-1;
      if(dir!=direction) continue;
      double entry=PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   =PositionGetDouble(POSITION_SL);
      double beSL =(direction>0 ? entry-buf : entry+buf);   // BE with tolerance room
      bool   move=false;
      if(direction>0 && (sl==0.0 || sl<beSL)) move=true;    // ratchet up only
      if(direction<0 && (sl==0.0 || sl>beSL)) move=true;    // ratchet down only
      if(move) EE_ModifySL(ticket,beSL);
   }
}

// Trail stops to lock InpTrailLockPct of the move from entry (after R2).
void MM_TrailStops(const int direction)
{
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   int cnt=PositionsTotal();
   for(int i=0;i<cnt;i++)
   {
      ulong ticket=PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol)  continue;
      if(PositionGetInteger(POSITION_MAGIC)!=g_cfg.magic) continue;
      int dir=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?1:-1;
      if(dir!=direction) continue;
      double entry=PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   =PositionGetDouble(POSITION_SL);
      if(direction>0)
      {
         double locked=entry+(bid-entry)*g_cfg.trailLockPct/100.0;
         if(locked>sl && locked>entry) EE_ModifySL(ticket,locked);
      }
      else
      {
         double locked=entry-(entry-ask)*g_cfg.trailLockPct/100.0;
         if((sl==0.0 || locked<sl) && locked<entry) EE_ModifySL(ticket,locked);
      }
   }
}

void MM_RunStopProtection()
{
   if(mm_longBEActive  && !mm_longTrailActive)  MM_MoveStopsToBreakeven(1);
   if(mm_shortBEActive && !mm_shortTrailActive) MM_MoveStopsToBreakeven(-1);
   if(mm_longTrailActive)  MM_TrailStops(1);
   if(mm_shortTrailActive) MM_TrailStops(-1);
}

//==================================================================
// PROFIT LADDER
//==================================================================
// Close `fractionPerPos` of EVERY open position in a direction (proportional),
// so every leg banks at each rung — not just the oldest.
void MM_CloseProportionalAll(const int direction,const double fractionPerPos,const string tag)
{
   if(fractionPerPos<=0.0) return;
   double minLot =SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double lotStep=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(lotStep<=0) lotStep=0.01; if(minLot<=0) minLot=0.01;
   int total=PositionsTotal();
   for(int i=0;i<total;i++)
   {
      ulong ticket=PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol)  continue;
      if(PositionGetInteger(POSITION_MAGIC)!=g_cfg.magic) continue;
      int dir=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?1:-1;
      if(dir!=direction) continue;
      double lots=PositionGetDouble(POSITION_VOLUME);
      double closeThis=MathFloor((lots*fractionPerPos)/lotStep)*lotStep;
      if(closeThis<minLot) continue;
      EE_ClosePartial(ticket,closeThis);
   }
}

// One direction's ladder: read live book, compute realised reward:risk ratio,
// fire at most one rung per bar. Reset when the direction is flat.
void MM_RunLadderDirection(const int direction,int &rungs)
{
   double totalLots=0.0,totalRisk=0.0,totalPnL=0.0;
   int    posCount=0;
   double atrFB=FalconATR(1); if(atrFB<=0.0) atrFB=10.0;

   int total=PositionsTotal();
   for(int i=0;i<total;i++)
   {
      ulong ticket=PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol)  continue;
      if(PositionGetInteger(POSITION_MAGIC)!=g_cfg.magic) continue;
      int dir=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?1:-1;
      if(dir!=direction) continue;
      double lots =PositionGetDouble(POSITION_VOLUME);
      double entry=PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   =PositionGetDouble(POSITION_SL);
      double pnl  =PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
      double distSL=(sl>0.0)?MathAbs(entry-sl):0.0;
      // Once SL is at/past breakeven distSL->0 would kill the denominator;
      // floor it at 1 ATR so rungs 2/3 can still evaluate.
      if(distSL<1.0) distSL=atrFB;
      totalLots+=lots; totalRisk+=lots*distSL*g_cfg.contractValue; totalPnL+=pnl;
      posCount++;
   }

   if(posCount==0)
   {
      rungs=0;
      if(direction>0){ mm_longBEActive=false;  mm_longTrailActive=false; }
      else           { mm_shortBEActive=false; mm_shortTrailActive=false; }
      return;
   }
   if(totalRisk<=0.0) return;

   double ratio=totalPnL/totalRisk;

   if(rungs==0 && ratio>=g_cfg.ladderR1)
   {
      MM_CloseProportionalAll(direction,g_cfg.ladderFrac1,"FALCON LADDER R1");
      rungs=1;
      if(direction>0) mm_longBEActive=true;  else mm_shortBEActive=true;
      MM_MoveStopsToBreakeven(direction);
   }
   else if(rungs==1 && ratio>=g_cfg.ladderR2)
   {
      MM_CloseProportionalAll(direction,g_cfg.ladderFrac2,"FALCON LADDER R2");
      rungs=2;
      if(direction>0){ mm_longBEActive=false;  mm_longTrailActive=true; }
      else           { mm_shortBEActive=false; mm_shortTrailActive=true; }
   }
   else if(rungs==2 && ratio>=g_cfg.ladderR3)
   {
      MM_CloseProportionalAll(direction,g_cfg.ladderFrac3,"FALCON LADDER R3");
      rungs=3;
   }
}

void MM_RunProfitLadder()
{
   MM_RunLadderDirection( 1, mm_longRungs);
   MM_RunLadderDirection(-1, mm_shortRungs);
}

#endif // FALCON_MONEY_MANAGER_MQH
//+------------------------------------------------------------------+

//  ===== Engines/TradePlan.mqh =====
//+------------------------------------------------------------------+
//|  FALCON OS — Decision/Execution : TradePlan.mqh                 |
//|                                                                  |
//|  SUBSYSTEMS DO THEIR JOBS. A trade is not a yes/no vote — it is a |
//|  PLAN, and each subsystem fills in the ONE field it owns:        |
//|                                                                  |
//|    DIRECTION   <- Ownership (Curve / Campaign)  — who owns price  |
//|    ENTRY ZONE  <- Liquidity / Order Block / Supply-Demand / FU    |
//|    STOP        <- the INVALIDATION level of that zone (where the  |
//|                   idea is wrong) — NOT a fixed anchor ± ATR        |
//|    TARGET      <- Convexity destination / FRZ owner-destination / |
//|                   Network next node — owner-driven & ESCALATING   |
//|                   with the owning timeframe                       |
//|    SIZE        <- Participant conviction × Campaign control        |
//|    R:R         <- computed from the subsystem stop + target        |
//|                                                                  |
//|  The composer READS each engine's concrete output and assembles  |
//|  the plan. Symphony then EXECUTES the plan (timing/trigger only). |
//|  Include AFTER the engines that write state, BEFORE SymphonyEngine|
//+------------------------------------------------------------------+
#ifndef FALCON_TRADE_PLAN_MQH
#define FALCON_TRADE_PLAN_MQH


//==================================================================
// THE PLAN — one composed object; each field is owned by a subsystem.
//==================================================================
struct FalconTradePlan
{
   int    dir;            // DIRECTION  — from ownership
   bool   valid;
   double entry;
   double stop;           // STOP       — zone invalidation (liquidity/structure)
   double target;         // TARGET     — owner destination (convexity/FRZ/network)
   double target2;        // runner target (next waypoint)
   int    targetTF;       // owning timeframe of the destination (escalation)
   double rr;             // reward:risk from the composed stop+target
   double convictionMult; // SIZE scale — participants × campaign control
   string stopSrc;        // which subsystem set the stop
   string targetSrc;      // which subsystem set the target
};

FalconTradePlan g_plan;

//------------------------------------------------------------------
// STOP — the invalidation of the zone price is reacting from.
//   LONG: the relevant zone's BOTTOM (demand/OB/flip/inducement/swing/
//   wave origin), minus a buffer. We choose the CLOSEST level below
//   entry that still gives at least a minimum stop distance, so the
//   stop is precise (tight to structure) without being noise-tight.
//------------------------------------------------------------------
double TP_StopLong(const double entry,const double atr,string &src)
{
   double buf  = atr*g_cfg.stopBufATR;
   double minD = MathMax(atr*0.6, buf*2.0);

   // candidate invalidation levels (price, label), each is a zone BOTTOM
   double cand[12]; string lbl[12]; int n=0;
   if(g_state.supplyDemand.inDemand && g_state.supplyDemand.demandBot>0){ cand[n]=g_state.supplyDemand.demandBot; lbl[n]="demand"; n++; }
   if(g_state.orderBlocks.activeDir==DIR_LONG && g_state.orderBlocks.activeBot>0){ cand[n]=g_state.orderBlocks.activeBot; lbl[n]="orderblock"; n++; }
   if(g_state.wave.flipBot>0){ cand[n]=g_state.wave.flipBot; lbl[n]="flip"; n++; }
   if(g_state.liquidity.induceBot>0){ cand[n]=g_state.liquidity.induceBot; lbl[n]="inducement"; n++; }
   if(g_state.structure.swingLow>0){ cand[n]=g_state.structure.swingLow; lbl[n]="swingLow"; n++; }
   if(g_state.wave.origin>0){ cand[n]=g_state.wave.origin; lbl[n]="origin"; n++; }
   // OWNER-TF zones (fractal): invalidation of the controlling higher-TF curve
   int oiL=g_state.htf.ownerTF;
   if(g_cfg.fractalZones && oiL>=0 && oiL<7 && g_tfZones[oiL].valid)
   {
      if(g_tfZones[oiL].demBot>0){ cand[n]=g_tfZones[oiL].demBot; lbl[n]="ownerDemand"; n++; }
      if(g_tfZones[oiL].obDir==DIR_LONG && g_tfZones[oiL].obBot>0){ cand[n]=g_tfZones[oiL].obBot; lbl[n]="ownerOB"; n++; }
      if(g_tfZones[oiL].swingLo>0){ cand[n]=g_tfZones[oiL].swingLo; lbl[n]="ownerSwing"; n++; }
   }

   // choose the HIGHEST candidate that is below entry by >= minD (tightest precise stop)
   double best=0.0; src="";
   for(int i=0;i<n;i++)
   {
      double lvl=cand[i];
      if(lvl < entry-minD)            // valid invalidation with room
         if(lvl>best){ best=lvl; src=lbl[i]; }
   }
   if(best<=0.0)
   {
      // fallback: deepest available zone bottom, else fixed structural stop
      for(int i=0;i<n;i++) if(cand[i]>0 && cand[i]<entry && (best==0.0||cand[i]<best)){ best=cand[i]; src=lbl[i]; }
      if(best<=0.0){ src="atr"; return(entry - 1.5*atr - buf); }
   }
   double stopL = best - buf;
   double capL  = entry - g_cfg.maxStopATR*atr;   // never wider than the cap
   if(stopL < capL){ stopL = capL; src=src+"(cap)"; }
   return(stopL);
}

double TP_StopShort(const double entry,const double atr,string &src)
{
   double buf  = atr*g_cfg.stopBufATR;
   double minD = MathMax(atr*0.6, buf*2.0);

   double cand[12]; string lbl[12]; int n=0;
   if(g_state.supplyDemand.inSupply && g_state.supplyDemand.supplyTop>0){ cand[n]=g_state.supplyDemand.supplyTop; lbl[n]="supply"; n++; }
   if(g_state.orderBlocks.activeDir==DIR_SHORT && g_state.orderBlocks.activeTop>0){ cand[n]=g_state.orderBlocks.activeTop; lbl[n]="orderblock"; n++; }
   if(g_state.wave.flipTop>0){ cand[n]=g_state.wave.flipTop; lbl[n]="flip"; n++; }
   if(g_state.liquidity.induceTop>0){ cand[n]=g_state.liquidity.induceTop; lbl[n]="inducement"; n++; }
   if(g_state.structure.swingHigh>0){ cand[n]=g_state.structure.swingHigh; lbl[n]="swingHigh"; n++; }
   if(g_state.wave.origin>0){ cand[n]=g_state.wave.origin; lbl[n]="origin"; n++; }
   int oiS=g_state.htf.ownerTF;
   if(g_cfg.fractalZones && oiS>=0 && oiS<7 && g_tfZones[oiS].valid)
   {
      if(g_tfZones[oiS].supTop>0){ cand[n]=g_tfZones[oiS].supTop; lbl[n]="ownerSupply"; n++; }
      if(g_tfZones[oiS].obDir==DIR_SHORT && g_tfZones[oiS].obTop>0){ cand[n]=g_tfZones[oiS].obTop; lbl[n]="ownerOB"; n++; }
      if(g_tfZones[oiS].swingHi>0){ cand[n]=g_tfZones[oiS].swingHi; lbl[n]="ownerSwing"; n++; }
   }

   // choose the LOWEST candidate that is above entry by >= minD
   double best=0.0; src="";
   for(int i=0;i<n;i++)
   {
      double lvl=cand[i];
      if(lvl > entry+minD)
         if(best==0.0 || lvl<best){ best=lvl; src=lbl[i]; }
   }
   if(best<=0.0)
   {
      for(int i=0;i<n;i++) if(cand[i]>0 && cand[i]>entry && cand[i]>best){ best=cand[i]; src=lbl[i]; }
      if(best<=0.0){ src="atr"; return(entry + 1.5*atr + buf); }
   }
   double stopS = best + buf;
   double capS  = entry + g_cfg.maxStopATR*atr;
   if(stopS > capS){ stopS = capS; src=src+"(cap)"; }
   return(stopS);
}

//------------------------------------------------------------------
// TARGET — owner-driven destination, ESCALATING with the owning TF.
//   Priority: FRZ owner-destination > convexity ARC > network next
//   authoritative node > wave objective > 2R fallback. Each is owned
//   by a different engine doing its job.
//------------------------------------------------------------------
double TP_TargetLong(const double entry,const double stop,int &tf,string &src,double &t2)
{
   double t=0.0; tf=g_state.curve.ownerTF; src=""; t2=0.0;
   if(g_state.frz.active && g_state.frz.targetPrice>entry)
   { t=g_state.frz.targetPrice; tf=g_state.frz.ownerTF; src="FRZ"; }
   else if(g_state.convexity.arcLong>entry)            { t=g_state.convexity.arcLong; src="convexity"; }
   else if(g_state.network.nextNodePrice>entry)        { t=g_state.network.nextNodePrice; src="network"; }
   else if(g_state.wave.objective>entry)               { t=g_state.wave.objective; src="wave"; }
   else                                                { t=entry+(entry-stop)*2.0; src="2R"; }

   // runner waypoint = the next distinct destination beyond t
   if(g_state.network.nextNodePrice>t)  t2=g_state.network.nextNodePrice;
   else if(g_state.wave.objective>t)    t2=g_state.wave.objective;
   else                                 t2=t+(t-entry)*0.6;
   return(t);
}

double TP_TargetShort(const double entry,const double stop,int &tf,string &src,double &t2)
{
   double t=0.0; tf=g_state.curve.ownerTF; src=""; t2=0.0;
   if(g_state.frz.active && g_state.frz.targetPrice>0 && g_state.frz.targetPrice<entry)
   { t=g_state.frz.targetPrice; tf=g_state.frz.ownerTF; src="FRZ"; }
   else if(g_state.convexity.arcShort>0 && g_state.convexity.arcShort<entry)   { t=g_state.convexity.arcShort; src="convexity"; }
   else if(g_state.network.nextNodePrice>0 && g_state.network.nextNodePrice<entry){ t=g_state.network.nextNodePrice; src="network"; }
   else if(g_state.wave.objective>0 && g_state.wave.objective<entry)           { t=g_state.wave.objective; src="wave"; }
   else                                                                        { t=entry-(stop-entry)*2.0; src="2R"; }

   if(g_state.network.nextNodePrice>0 && g_state.network.nextNodePrice<t)  t2=g_state.network.nextNodePrice;
   else if(g_state.wave.objective>0 && g_state.wave.objective<t)           t2=g_state.wave.objective;
   else                                                                    t2=t-(entry-t)*0.6;
   return(t);
}

//------------------------------------------------------------------
// SIZE conviction — Participant balance × Campaign control.
//   own-side participation strong + high campaign control => up to 1.5x;
//   weak / contested => down to 0.5x. The participant + campaign engines
//   doing their job (sizing), not gating.
//------------------------------------------------------------------
double TP_Conviction(const int dir)
{
   double own = (dir==DIR_LONG ? g_state.participants.buyer  : g_state.participants.seller);
   double opp = (dir==DIR_LONG ? g_state.participants.seller : g_state.participants.buyer);
   double ctrl= FalconClamp(g_state.campaign.controlScore,0,100);
   double partMult = FalconClamp(1.0 + 0.5*((own-opp)/100.0), 0.5, 1.5);
   double ctrlMult = FalconClamp(0.6 + 0.4*ctrl/100.0, 0.6, 1.0);
   return(FalconClamp(partMult*ctrlMult, 0.4, 1.5));
}

//==================================================================
// COMPOSE — assemble the full plan from the subsystems for `dir`.
//==================================================================
FalconTradePlan ComposeTradePlan(const int dir,const double entry,const double atr)
{
   FalconTradePlan p; p.valid=false; p.dir=dir; p.entry=entry;
   p.stop=0; p.target=0; p.target2=0; p.targetTF=0; p.rr=0; p.convictionMult=1.0;
   p.stopSrc=""; p.targetSrc="";
   if(atr<=0.0) return(p);

   if(dir==DIR_LONG)
   {
      p.stop   = TP_StopLong(entry,atr,p.stopSrc);
      p.target = TP_TargetLong(entry,p.stop,p.targetTF,p.targetSrc,p.target2);
      if(p.stop>0 && p.stop<entry && p.target>entry)
         p.rr = (p.target-entry)/(entry-p.stop);
   }
   else if(dir==DIR_SHORT)
   {
      p.stop   = TP_StopShort(entry,atr,p.stopSrc);
      p.target = TP_TargetShort(entry,p.stop,p.targetTF,p.targetSrc,p.target2);
      if(p.stop>entry && p.target>0 && p.target<entry)
         p.rr = (entry-p.target)/(p.stop-entry);
   }
   p.convictionMult = TP_Conviction(dir);
   p.valid = (p.stop>0.0 && p.target>0.0 && p.rr>0.0);
   g_plan = p;
   return(p);
}

#endif // FALCON_TRADE_PLAN_MQH
//+------------------------------------------------------------------+

//  ===== Engines/TradeJournal.mqh =====
//+------------------------------------------------------------------+
//|  FALCON OS — Diagnostics : TradeJournal.mqh                      |
//|                                                                  |
//|  PURPOSE: produce the data needed to answer "which panel settings |
//|  give the best trades?". For EVERY trade it snapshots the full    |
//|  Decision/Intelligence panel state AT ENTRY (confidence, exec     |
//|  prob, threat, conflict, opportunity, master-chief, phase,        |
//|  completion, geometry, ownership, HTF alignment, verdict) and, on |
//|  close, the realised result (profit, R-multiple, MFE/MAE in R,    |
//|  bars held). One CSV row per closed trade.                        |
//|                                                                  |
//|  Run ONE backtest with InpJournal=true, then open the CSV from    |
//|  <DataFolder>/MQL5/Files/ (Common) and feed it to analyze_journal |
//|  .py to see win-rate + expectancy bucketed by each setting, so a  |
//|  threshold (e.g. confidence>=70 vs >=55) can be chosen on EVIDENCE.|
//|                                                                  |
//|  Read-only on state. Reuses FalconATR / shared series. Include    |
//|  BEFORE SymphonyEngine so its entries can call TJ_RecordEntry.    |
//+------------------------------------------------------------------+
#ifndef FALCON_TRADE_JOURNAL_MQH
#define FALCON_TRADE_JOURNAL_MQH


//==================================================================
// One open-trade record (snapshot at entry + running MFE/MAE)
//==================================================================
struct TJRec
{
   ulong    ticket;
   bool     open;
   datetime tOpen;
   int      dir;          // +1 long / -1 short
   string   tag;          // "P3 Long" etc.
   double   entry, sl, lots, riskCash, riskDist;
   // --- panel snapshot AT ENTRY ---
   double   conf, execProb, threat, conflict, opp, mcScore;
   bool     mcConfirm;
   int      phase;
   double   completion, geomCap, ownerCtrl, htfAlign, validation, oppNum;
   int      action, owner;
   string   oppGrade, intent, timing;
   // --- running ---
   double   mfe, mae;     // price-distance favourable / adverse
};

TJRec  tj[];
int    tj_fileHandle = INVALID_HANDLE;
string tj_fileName   = "";

//==================================================================
// INIT — open the CSV (Common Files) and write the header row.
//==================================================================
void TradeJournalInit()
{
   ArrayResize(tj,0);
   tj_fileHandle = INVALID_HANDLE;
   if(!g_cfg.journal) return;

   tj_fileName = StringFormat("FALCON_Journal_%s_%d.csv", _Symbol, (int)Period());
   tj_fileHandle = FileOpen(tj_fileName,
                            FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON, ',');
   if(tj_fileHandle==INVALID_HANDLE)
   {
      FalconLog("WARN","TradeJournal","could not open "+tj_fileName);
      return;
   }
   FileWrite(tj_fileHandle,
      "ticket","openTime","closeTime","barsHeld","dir","tag",
      "entry","sl","lots","riskCash",
      "conf","execProb","threat","conflict","opp","oppGrade",
      "mcScore","mcConfirm","validation","action","owner",
      "phase","completion","geomCap","ownerCtrl","htfAlign","intent","timing",
      "profit","resultR","mfeR","maeR","win");
   FileFlush(tj_fileHandle);
   FalconLog("INFO","TradeJournal","-> "+tj_fileName+" (Common\\Files)");
}

//==================================================================
// RECORD ENTRY — called by Symphony immediately after a successful send.
//   Captures the live Decision/Intelligence panel into a new record.
//==================================================================
void TJ_RecordEntry(const ulong ticket,const int dir,const string tag,
                    const double entry,const double sl,const double lots)
{
   if(!g_cfg.journal || tj_fileHandle==INVALID_HANDLE) return;

   FalconIntelligence x = g_state.intel;
   TJRec r;
   r.ticket   = ticket;  r.open = true;  r.tOpen = gTime[0];
   r.dir      = dir;     r.tag  = tag;
   r.entry    = entry;   r.sl   = sl;    r.lots = lots;
   r.riskCash = g_state.exec.riskCash;
   r.riskDist = MathAbs(entry - sl);
   r.conf       = x.confidence;
   r.execProb   = x.executionProbability;
   r.threat     = x.threat;
   r.conflict   = x.conflict;
   r.opp        = x.opportunity;
   r.oppNum     = x.opportunity;
   r.oppGrade   = x.opportunityGrade;
   r.mcScore    = x.masterChiefScore;
   r.mcConfirm  = x.masterChiefConfirm;
   r.validation = x.validationScore;
   r.intent     = x.intent;
   r.timing     = x.timing;
   r.action     = g_state.exec.action;
   r.owner      = g_state.campaign.owner;
   r.phase      = g_state.wave.phase;
   r.completion = g_state.wave.completion;
   r.geomCap    = g_state.convexity.geometryCapacity;
   r.ownerCtrl  = g_state.campaign.controlScore;
   r.htfAlign   = g_state.htf.alignment;
   r.mfe = 0.0;  r.mae = 0.0;

   int n = ArraySize(tj);
   ArrayResize(tj, n+1);
   tj[n] = r;
}

//------------------------------------------------------------------
// Realised P/L for a closed position (profit + swap only; MT5 has
// deprecated POSITION_COMMISSION). Also returns close price/time.
//------------------------------------------------------------------
double TJ_RealizedProfit(const ulong posId,double &closePrice,datetime &closeTime)
{
   double pl=0.0; closePrice=0.0; closeTime=0;
   if(!HistorySelectByPosition(posId)) return(0.0);
   int dts = HistoryDealsTotal();
   for(int i=0;i<dts;i++)
   {
      ulong dt = HistoryDealGetTicket(i);
      if(dt==0) continue;
      pl += HistoryDealGetDouble(dt,DEAL_PROFIT) + HistoryDealGetDouble(dt,DEAL_SWAP);
      long e = HistoryDealGetInteger(dt,DEAL_ENTRY);
      if(e==DEAL_ENTRY_OUT || e==DEAL_ENTRY_OUT_BY || e==DEAL_ENTRY_INOUT)
      {
         closePrice = HistoryDealGetDouble(dt,DEAL_PRICE);
         closeTime  = (datetime)HistoryDealGetInteger(dt,DEAL_TIME);
      }
   }
   return(pl);
}

//------------------------------------------------------------------
// Write one finalised row and mark the record closed.
//------------------------------------------------------------------
void TJ_Finalize(const int idx)
{
   double closePrice=0.0; datetime closeTime=0;
   double profit = TJ_RealizedProfit(tj[idx].ticket, closePrice, closeTime);
   if(closeTime==0) closeTime = gTime[0];

   double rd   = (tj[idx].riskDist>0.0 ? tj[idx].riskDist : 1e-9);
   double rcsh = (tj[idx].riskCash>0.0 ? tj[idx].riskCash : 1e-9);
   double resultR = profit / rcsh;
   double mfeR    = tj[idx].mfe / rd;
   double maeR    = tj[idx].mae / rd;
   int    bars    = (int)((closeTime - tj[idx].tOpen) / MathMax(1,PeriodSeconds()));
   int    win     = (profit>0.0 ? 1 : 0);

   if(tj_fileHandle!=INVALID_HANDLE)
   {
      FileWrite(tj_fileHandle,
         (string)tj[idx].ticket,
         TimeToString(tj[idx].tOpen,TIME_DATE|TIME_MINUTES),
         TimeToString(closeTime,TIME_DATE|TIME_MINUTES),
         (string)bars,
         (tj[idx].dir>0?"LONG":"SHORT"),
         tj[idx].tag,
         DoubleToString(tj[idx].entry,_Digits),
         DoubleToString(tj[idx].sl,_Digits),
         DoubleToString(tj[idx].lots,2),
         DoubleToString(tj[idx].riskCash,2),
         DoubleToString(tj[idx].conf,1),
         DoubleToString(tj[idx].execProb,3),
         DoubleToString(tj[idx].threat,1),
         DoubleToString(tj[idx].conflict,1),
         DoubleToString(tj[idx].opp,1),
         tj[idx].oppGrade,
         DoubleToString(tj[idx].mcScore,1),
         (tj[idx].mcConfirm?"1":"0"),
         DoubleToString(tj[idx].validation,1),
         (string)tj[idx].action,
         (string)tj[idx].owner,
         (string)tj[idx].phase,
         DoubleToString(tj[idx].completion,1),
         DoubleToString(tj[idx].geomCap,1),
         DoubleToString(tj[idx].ownerCtrl,1),
         DoubleToString(tj[idx].htfAlign,1),
         tj[idx].intent,
         tj[idx].timing,
         DoubleToString(profit,2),
         DoubleToString(resultR,3),
         DoubleToString(mfeR,3),
         DoubleToString(maeR,3),
         (string)win);
      FileFlush(tj_fileHandle);
   }
   tj[idx].open = false;
}

//==================================================================
// ON BAR — update MFE/MAE for open records and finalise any that
// have left the book (closed by trail-stop, exit, or SL).
//==================================================================
void TradeJournalOnBar()
{
   if(!g_cfg.journal || tj_fileHandle==INVALID_HANDLE) return;
   int n = ArraySize(tj);
   if(n<=0) return;

   double hi = gHigh[1], lo = gLow[1];

   for(int i=0;i<n;i++)
   {
      if(!tj[i].open) continue;

      // update running MFE/MAE off the last closed bar's extremes
      if(tj[i].dir>0)
      {
         tj[i].mfe = MathMax(tj[i].mfe, hi - tj[i].entry);
         tj[i].mae = MathMax(tj[i].mae, tj[i].entry - lo);
      }
      else
      {
         tj[i].mfe = MathMax(tj[i].mfe, tj[i].entry - lo);
         tj[i].mae = MathMax(tj[i].mae, hi - tj[i].entry);
      }

      // still open on the book?
      if(!PositionSelectByTicket(tj[i].ticket))
         TJ_Finalize(i);
   }
}

//==================================================================
// DEINIT — finalise any trades still open at end of run, close file.
//==================================================================
void TradeJournalDeinit()
{
   int n = ArraySize(tj);
   for(int i=0;i<n;i++)
      if(tj[i].open) TJ_Finalize(i);
   if(tj_fileHandle!=INVALID_HANDLE){ FileClose(tj_fileHandle); tj_fileHandle=INVALID_HANDLE; }
}

#endif // FALCON_TRADE_JOURNAL_MQH
//+------------------------------------------------------------------+

//  ===== Engines/Adaptive.mqh =====
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
double ad_globalR    = 0.0;   // EWMA of EVERY closed trade's R (overall realised edge)
int    ad_globalN    = 0;

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
      // overall realised edge (for the regret-override safety gate)
      if(ad_globalN==0) ad_globalR=R; else ad_globalR=ad_globalR+0.05*(R-ad_globalR);
      ad_globalN++;
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

//  ===== Engines/SelfAwareness.mqh =====
//+------------------------------------------------------------------+
//|  FALCON OS — Intelligence : SelfAwareness.mqh                   |
//|                                                                  |
//|  METACOGNITION — the OS watching ITSELF, not the market.        |
//|                                                                  |
//|  It maintains a live model of its own reliability and form, and  |
//|  modulates how much it trusts itself right now:                  |
//|    • CALIBRATION — do my stated probabilities match my realised  |
//|      win-rate? (am I over/under-confident)                       |
//|    • FORM        — win/loss streak, equity slope, drawdown        |
//|    • REGIME FIT  — am I in conditions I perform in (learned)      |
//|    • HEALTH      — are my own inputs sane (ATR, locator conf, DD, |
//|      loss cluster)? if not, STAND DOWN.                          |
//|                                                                  |
//|  Output: selfConfidence (0..100) and a global risk THROTTLE that |
//|  scales size; a hard stand-down veto when health fails. Reads the |
//|  adaptive accumulators (ad_*), so include AFTER Adaptive and      |
//|  BEFORE SymphonyEngine. Writes g_state.self.                      |
//+------------------------------------------------------------------+
#ifndef FALCON_SELF_AWARENESS_MQH
#define FALCON_SELF_AWARENESS_MQH


double sa_equityPeak = 0.0;
double sa_equityPrev = 0.0;
double sa_slope      = 0.0;
int    sa_cooldown   = 0;   // loss-cluster cooldown bars remaining

void SelfAwarenessInit()
{
   sa_equityPeak = AccountInfoDouble(ACCOUNT_EQUITY);
   sa_equityPrev = sa_equityPeak;
   sa_slope      = 0.0;
   sa_cooldown   = 0;
}

void SelfAwarenessRun()
{
   if(!g_cfg.useSelfAware) return;
   FalconSelfAwareness s; ZeroMemory(s);

   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(sa_equityPeak<=0.0) sa_equityPeak=eq;
   if(eq>sa_equityPeak) sa_equityPeak=eq;
   double ddPct = (sa_equityPeak>0.0 ? (sa_equityPeak-eq)/sa_equityPeak*100.0 : 0.0);
   sa_slope = FalconEMA(sa_slope, eq-sa_equityPrev, 10);
   sa_equityPrev = eq;

   s.winStreak     = ad_winStreak;
   s.lossStreak    = ad_lossStreak;
   s.ddFromPeakPct = ddPct;
   s.equitySlope   = sa_slope;

   // 1) CALIBRATION — |avg predicted prob - actual win rate| (lower = better)
   if(ad_calN>=5)
   {
      double avgPred = ad_calPredSum/ad_calN;
      double actWin  = ad_calWinSum /ad_calN;
      s.calibration  = FalconClamp(100.0 - MathAbs(avgPred-actWin)*100.0, 0, 100);
   }
   else s.calibration = 60.0;   // neutral until enough samples

   // 2) FORM — streak + equity slope, penalised by drawdown
   double streakF = FalconClamp(55.0 + s.winStreak*8.0 - s.lossStreak*12.0, 0, 100);
   double slopeF  = (sa_slope>0?60.0:sa_slope<0?40.0:50.0);
   s.form = FalconClamp(0.6*streakF + 0.2*slopeF + 0.2*FalconClamp(100.0-ddPct*5.0,0,100), 0, 100);

   // 3) REGIME FIT — am I in conditions I perform in? best learned bucket edge at
   //    the current curve band, blended with HTF fractal agreement.
   int bL=AD_Bucket(DIR_LONG), bS=AD_Bucket(DIR_SHORT);
   double edge = MathMax(ad_ewmaR[bL], ad_ewmaR[bS]);          // best available edge here
   double edgeF = FalconClamp(50.0 + edge*40.0, 0, 100);
   s.regimeFit = FalconClamp(0.5*edgeF + 0.5*g_state.htf.alignment, 0, 100);

   // 4) HEALTH — own-input integrity. If broken, do not trust self.
   double atr = FalconATR(1);
   s.health = true; s.healthNote = "ok";
   if(atr<=0.0)                                   { s.health=false; s.healthNote="no ATR/data"; }
   else if(g_cfg.useCurveLocator && g_state.curveLocator.conf < 20.0) { s.health=false; s.healthNote="lost on curve"; }
   else if(ddPct >= g_cfg.maxDrawdownPct)         { s.health=false; s.healthNote="drawdown halt"; }

   // LOSS-CLUSTER -> TIMED COOLDOWN (not a permanent halt). A hard block would
   // deadlock: no trades -> no win -> the streak never resets. So we pause for
   // selfHaltBars bars, then RESET the streak and resume (cautious via `form`).
   if(ad_lossStreak >= g_cfg.selfLossHalt && sa_cooldown==0)
      sa_cooldown = g_cfg.selfHaltBars;
   if(sa_cooldown>0)
   {
      sa_cooldown--;
      s.health=false; s.healthNote="cooldown "+IntegerToString(sa_cooldown);
      if(sa_cooldown<=0) ad_lossStreak=0;   // expire -> fresh start, resume next bar
   }

   // SYNTHESIS — one self-confidence, then a bounded throttle.
   s.selfConfidence = FalconClamp(0.30*s.calibration + 0.35*s.form + 0.20*s.regimeFit
                                  + 0.15*(s.health?100.0:0.0), 0, 100);
   // THROTTLE — full size in normal conditions; only ramp DOWN when confidence
   //   drops below selfFullConf. (Previously a linear conf/100 map haircut size
   //   even at middling confidence and slowed the whole system down.)
   if(!s.health)                          s.throttle = 0.0;                 // stand down
   else if(s.selfConfidence >= g_cfg.selfFullConf) s.throttle = 1.0;        // full size
   else s.throttle = FalconClamp(g_cfg.selfMinThrottle
                     + (1.0-g_cfg.selfMinThrottle)*(s.selfConfidence/MathMax(g_cfg.selfFullConf,1.0)),
                     g_cfg.selfMinThrottle, 1.0);

   s.label = (!s.health ? "STANDDOWN"
              : s.selfConfidence>70 ? "CONFIDENT"
              : s.selfConfidence>45 ? "CAUTIOUS" : "DEFENSIVE");

   g_state.self = s;
}

// helpers for the entry path
double SA_Throttle(){ return(g_cfg.useSelfAware ? g_state.self.throttle : 1.0); }
bool   SA_StandDown(){ return(g_cfg.useSelfAware && !g_state.self.health); }

#endif // FALCON_SELF_AWARENESS_MQH
//+------------------------------------------------------------------+

//  ===== Engines/MissTrade.mqh =====
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
double   talon_peakLong  = 0.0;     // peak favorable excursion (ATR) — long campaign
double   talon_peakShort = 0.0;     // peak favorable excursion (ATR) — short campaign

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
// LOT SIZING PIPELINE — base risk%% size, optional PYRO thermal admission,
// then the v3.0 pre-entry basket ceiling (hard per-direction risk cap).
//==================================================================
double Sym_SizeLots(const int dir,const double riskCash,const double entry,const double sl)
{
   double lots = Sym_ComputeLots(riskCash,entry,sl);
   if(g_cfg.useThermalRisk) lots = TR_AdmitLots(dir, lots);
   lots = MM_AdjustLotsForBasketCeiling(dir, entry, sl, lots);
   return(lots);
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
void SymphonyComputePhases()
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
}

//==================================================================
// ENGINE 3 — SYMPHONY wave cycle (the impulse + retracement-fraction
//   phase model). Normalizes sym_* into the shared WaveCycle so the
//   referee can score it against LETRA and F16 on the same yardstick.
//   Lives here because it reads the sym_* phase state. Reuses the
//   normalization helpers from WaveCycleIntel.mqh (included earlier).
//==================================================================
void CycleSymphony_Compute()
{
   WaveCycle cy; ZeroMemory(cy);
   Cycle_CarryPerf(cy, g_state.cycles[ENG_SYMPHONY]);
   int prevStage = g_state.cycles[ENG_SYMPHONY].stage;

   int dir = (sym_mode==1 ? DIR_LONG : sym_mode==-1 ? DIR_SHORT : DIR_NONE);
   int p   = (dir==DIR_LONG ? sym_phaseLong : dir==DIR_SHORT ? sym_phaseShort : 0);

   cy.engineId  = ENG_SYMPHONY;
   cy.direction = dir;
   cy.maturity  = (p<=0?5.0 : p==1?25.0 : p==2?45.0 : p==3?70.0 : 92.0);
   cy.objective = (dir==DIR_LONG  && sym_arcLong >0.0 ? sym_arcLong
                  : dir==DIR_SHORT && sym_arcShort>0.0 ? sym_arcShort
                  : dir==DIR_LONG ? Sym_DestLong() : dir==DIR_SHORT ? Sym_DestShort() : 0.0);
   cy.invalidation = (dir==DIR_LONG ? sym_anchorLow : dir==DIR_SHORT ? sym_anchorHigh : 0.0);
   bool hasZone = (dir==DIR_LONG ? (sym_longInducLow!=0.0||sym_longInducHigh!=0.0)
                                 : (sym_shortInducLow!=0.0||sym_shortInducHigh!=0.0));
   cy.confidence = FalconClamp(50.0 + (hasZone?15.0:0.0) + (p==4?15.0:p==3?10.0:0.0), 0, 100);

   int stage, ph; string nxt;
   if(dir==DIR_NONE || p<=0){ stage=CYC_NONE; ph=PH_TRANSITION; nxt="awaiting impulse"; }
   else if(p==1){ stage=CYC_EXPANSION; ph=PH_EXPANSION;   nxt="retrace into zone"; }
   else if(p==2){ stage=CYC_RETRACE;   ph=PH_RETRACEMENT; nxt="return to flip / inducement"; }
   else if(p==3){ stage=CYC_RETURN;    ph=(dir==DIR_LONG?PH_DEMAND_RETURN:PH_SUPPLY_RETURN); nxt="breakout to new extreme"; }
   else        { stage=CYC_BREAKOUT;   ph=(dir==DIR_LONG?PH_NEW_HIGH:PH_NEW_LOW); nxt="extend to ARC target"; }

   cy.stage      = stage;
   cy.phase      = ph;
   cy.phaseLabel = FalconPhaseStr(ph);
   cy.nextEvent  = nxt;
   Cycle_FillEntry(cy, prevStage);

   g_state.cycles[ENG_SYMPHONY] = cy;
}

//==================================================================
// GENERIC CYCLE → WAVE BRIDGE — write any engine's normalized cycle
//   into the canonical g_state.wave (the phase the rest of the OS
//   reads). Preserves the Market Engine geometry sub-scores; overrides
//   only the phase-engine fields. Used for the F16 / consensus / best
//   authority paths (the Symphony path keeps its richer dedicated bridge).
//==================================================================
void Cycle_BridgeToWave(const WaveCycle &cy)
{
   FalconWave w = g_state.wave;   // keep geometry descriptors
   w.prevPhase = w.phase;
   w.phase     = cy.phase;
   w.direction = cy.direction;
   if(cy.objective!=0.0)    w.objective  = cy.objective;
   if(cy.invalidation!=0.0) w.origin     = cy.invalidation;
   w.completion= cy.maturity;
   w.confidence= cy.confidence;
   // ownership transfer proxy keyed to the engine's lifecycle stage
   w.dominanceTransfer = (cy.stage>=CYC_RETURN ? 60.0 : cy.stage==CYC_RETRACE ? 30.0 : 0.0);
   g_state.wave = w;
   if(w.phase != w.prevPhase) FalconPublish(EVT_PHASE_CHANGE, w.phase, FalconPhaseStr(w.phase));
}

//==================================================================
// PHASE AUTHORITY — write the SELECTED engine's interpretation into the
//   canonical wave. This is the configurable replacement for the old
//   "Symphony is always the truth" bridge. Don't replace the phase
//   engine — pick which one DRIVES, and let the referee compare them.
//     • ENG_SYMPHONY : the dedicated Symphony bridge (default, unchanged)
//     • ENG_LETRA    : keep the native LETRA wave (no-op)
//     • ENG_F16      : bridge the F16 curve-tree cycle
//     • ENG_CONSENSUS: bridge the consensus (engine matching consensusDir)
//     • ENG_BEST     : bridge whichever engine the referee ranks best
//==================================================================
void PhaseAuthorityApply()
{
   int eng = g_cfg.entryEngine;

   // safety: if the comparative cycles are not being computed, the only valid
   // authority is Symphony's dedicated bridge (its phases are still computed).
   if(!g_cfg.runAllCycles){ if(g_cfg.useSymphony) SymphonyBridgeToWave(); return; }

   if(eng==ENG_SYMPHONY){ if(g_cfg.useSymphony) SymphonyBridgeToWave(); return; }
   if(eng==ENG_LETRA)   { return; }   // native LETRA wave already in g_state.wave
   if(eng==ENG_F16)     { Cycle_BridgeToWave(g_state.cycles[ENG_F16]); return; }

   if(eng==ENG_BEST)
   {
      int b = g_state.referee.bestEngine;
      if(b==ENG_SYMPHONY){ if(g_cfg.useSymphony) SymphonyBridgeToWave(); }
      else if(b>=0 && b<FALCON_NCYCLES) Cycle_BridgeToWave(g_state.cycles[b]);
      return;
   }

   if(eng==ENG_CONSENSUS)
   {
      int cd = g_state.referee.consensusDir;
      if(cd==DIR_NONE) return;   // no agreement -> leave native LETRA wave
      // bridge the consensus-aligned engine with the highest demonstrated edge
      int pick=-1; double best=-1.0;
      for(int e=0;e<FALCON_NCYCLES;e++)
         if(g_state.cycles[e].direction==cd && g_state.cycles[e].accuracy>best)
         { best=g_state.cycles[e].accuracy; pick=e; }
      if(pick==ENG_SYMPHONY){ if(g_cfg.useSymphony) SymphonyBridgeToWave(); }
      else if(pick>=0) Cycle_BridgeToWave(g_state.cycles[pick]);
      return;
   }
}

//==================================================================
// EFFECTIVE ENTRY ENGINE — resolve the engine that drives ENTRIES this
// bar (BEST -> referee.bestEngine). CONSENSUS is handled separately.
//==================================================================
int Sym_EffectiveEngine()
{
   if(g_cfg.entryEngine==ENG_BEST) return(g_state.referee.bestEngine);
   return(g_cfg.entryEngine);
}

//==================================================================
// Is the EA in RAW/FREE entry mode? (non-Symphony engine, or Symphony in
// FREE RUN). In this mode trades are owned by TALON + the position TP/SL +
// PYRO catastrophe stop — Symphony's discretionary ARC/phase exits and the
// ARC partial are SUPPRESSED, because they are keyed to sym_mode/sym_phase
// and would close trades the authority engine (e.g. LETRA) wants to hold
// (and Symphony's phase rotates constantly in free-run -> premature kills).
//==================================================================
bool SymRawActive()
{
   bool symAuth  = (g_cfg.entryEngine!=ENG_CONSENSUS && Sym_EffectiveEngine()==ENG_SYMPHONY);
   bool freeMode = (g_cfg.cycleFreeRun && g_cfg.runAllCycles);
   bool rawLike  = (!symAuth || freeMode);
   return(g_cfg.cycleRawEntries && rawLike);
}

//==================================================================
// RAW ENTRY EDGES — the SELECTED engine's P3 (return) / P4 (breakout)
// edges this bar, BEFORE the shared gates. Lets the entry engine run
// off LETRA, F16, Symphony, CONSENSUS or BEST identically.
//==================================================================
void Sym_RawEntryEdges(bool &eL3,bool &eL4,bool &eS3,bool &eS4)
{
   eL3=false; eL4=false; eS3=false; eS4=false;

   // CONSENSUS — any consensus-aligned engine casting an entry edge.
   if(g_cfg.entryEngine==ENG_CONSENSUS)
   {
      int cd=g_state.referee.consensusDir;
      if(cd==DIR_NONE) return;
      for(int e=0;e<FALCON_NCYCLES;e++)
      {
         if(!g_state.cycles[e].entryEdge || g_state.cycles[e].entryDir!=cd) continue;
         int k=g_state.cycles[e].entryKind;
         if(cd==DIR_LONG){ if(k==3) eL3=true; else if(k==4) eL4=true; }
         else            { if(k==3) eS3=true; else if(k==4) eS4=true; }
      }
      return;
   }

   int eff=Sym_EffectiveEngine();
   WaveCycle cy=g_state.cycles[eff];

   // FREE RUN — let the AUTHORITY engine (LETRA, F16, OR Symphony) trade on
   // EVERY fresh in-direction phase transition, not just its return/breakout
   // analogs. Edge-triggered (one shot per transition). Uses the engine's own
   // normalized cycle, so it works identically for Symphony as for LETRA.
   if(g_cfg.cycleFreeRun && g_cfg.runAllCycles)
   {
      // don't enter on reversal/sweep phases (liquidation) — those are
      // "reversal risk", a common source of incorrect counter-trend entries.
      bool freshEdge = (cy.stage!=cy.prevStage) && cy.stage>=CYC_EXPANSION
                       && cy.direction!=DIR_NONE && cy.phase!=PH_LIQUIDATION;
      if(freshEdge && cy.direction==DIR_LONG)       { if(cy.stage==CYC_BREAKOUT) eL4=true; else eL3=true; }
      else if(freshEdge && cy.direction==DIR_SHORT) { if(cy.stage==CYC_BREAKOUT) eS4=true; else eS3=true; }
      return;
   }

   // SYMPHONY authority (non-free) — native impulse phase 3/4 edges.
   if(eff==ENG_SYMPHONY)
   {
      eL3=(sym_mode==1  && sym_phaseLong ==3 && sym_prevPhaseLong !=3);
      eL4=(sym_mode==1  && sym_phaseLong ==4 && sym_prevPhaseLong !=4);
      eS3=(sym_mode==-1 && sym_phaseShort==3 && sym_prevPhaseShort!=3);
      eS4=(sym_mode==-1 && sym_phaseShort==4 && sym_prevPhaseShort!=4);
      return;
   }

   // LETRA / F16 (non-free) — normalized return/breakout edges only.
   if(cy.entryEdge)
   {
      if(cy.entryDir==DIR_LONG)      { if(cy.entryKind==3) eL3=true; else if(cy.entryKind==4) eL4=true; }
      else if(cy.entryDir==DIR_SHORT){ if(cy.entryKind==3) eS3=true; else if(cy.entryKind==4) eS4=true; }
   }
}

//==================================================================
// FACT-BASED DECISION CONTRACT — subsystems DO THEIR JOBS.
//   Each subsystem owns a concrete VETO in its own domain — no scores,
//   no weighted averages. An entry in `dir` survives only if EVERY
//   subsystem clears it. The first failing subsystem records WHY (so the
//   block is explainable / journalable), and direction is INHERITED from
//   ownership, never voted.
//
//   1. HTF        — PERMISSION: the higher-TF stack must not oppose dir.
//   2. CURVE/CAMP — OWNERSHIP : the owner of price must be dir (authority).
//   3. ZONES      — LOCATION  : price must be AT a real engagement zone
//                   (wave flip / supply-demand / order block / FU /
//                   swept inducement) — never fire in no-man's-land.
//   4. STRUCTURE  — CONFIRM   : no change-of-character against dir.
//   5. CONVEXITY  — ROOM      : curve capacity left + wave not exhausted
//                   (don't buy tops / sell bottoms).
//   6. NETWORK/PART — THREAT  : no dominant opposing authority/participant.
//==================================================================
string sym_factVeto = "";   // last veto reason (diagnostics)

bool Sym_PriceInBand(const double px,const double a,const double b)
{
   if(a==0.0 && b==0.0) return(false);
   double lo=MathMin(a,b), hi=MathMax(a,b);
   return(px>=lo && px<=hi);
}

// LOCATION fact — is price AT a real subsystem zone supporting `dir`?
bool Sym_AtRealZone(const int dir,const double px)
{
   FalconWave        w  = g_state.wave;
   FalconSupplyDemand sd= g_state.supplyDemand;
   FalconOrderBlocks  ob= g_state.orderBlocks;
   FalconFU           fu= g_state.fu;
   FalconLiquidity    lq= g_state.liquidity;

   bool flip   = Sym_PriceInBand(px, w.flipBot, w.flipTop);             // wave flip zone
   bool sweptL = lq.induceSwept;                                        // liquidity grabbed
   // owner-TF zone (fractal): price reacting at the controlling higher-TF zone
   int oiZ=g_state.htf.ownerTF;
   bool ownerZone=false;
   if(g_cfg.fractalZones && oiZ>=0 && oiZ<7 && g_tfZones[oiZ].valid)
      ownerZone = (dir==DIR_LONG ? (g_tfZones[oiZ].inDemand || (g_tfZones[oiZ].obDir==DIR_LONG && Sym_PriceInBand(px,g_tfZones[oiZ].obBot,g_tfZones[oiZ].obTop)))
                                 : (g_tfZones[oiZ].inSupply || (g_tfZones[oiZ].obDir==DIR_SHORT && Sym_PriceInBand(px,g_tfZones[oiZ].obBot,g_tfZones[oiZ].obTop))));
   if(dir==DIR_LONG)
   {
      bool dz  = sd.inDemand;                                           // supply/demand engine
      bool obz = (ob.activeDir==DIR_LONG && Sym_PriceInBand(px,ob.activeBot,ob.activeTop));
      bool fuz = (fu.active && fu.dir==DIR_LONG && Sym_PriceInBand(px,fu.zoneBot,fu.zoneTop));
      return(flip || dz || obz || fuz || sweptL || ownerZone);
   }
   else
   {
      bool sz  = sd.inSupply;
      bool obz = (ob.activeDir==DIR_SHORT && Sym_PriceInBand(px,ob.activeBot,ob.activeTop));
      bool fuz = (fu.active && fu.dir==DIR_SHORT && Sym_PriceInBand(px,fu.zoneBot,fu.zoneTop));
      return(flip || sz || obz || fuz || sweptL || ownerZone);
   }
}

// Soft-filter veto with regret learning: if the OS has LEARNED (from shadow
// trades) that this filter keeps missing winners, OVERRIDE it and take the
// trade; otherwise record the miss (keep learning) and veto.
bool SymVeto(const int code,const string reason,const int dir,const double px)
{
   if(MT_Override(code)) return(false);   // learned to take it -> allow
   MT_RecordMiss(dir, px, code);          // count the miss (keeps learning)
   sym_factVeto = reason;
   return(true);
}

bool SymphonyFactsConfirm(const int dir)
{
   sym_factVeto = "";
   if(!g_cfg.useFactGate) return(true);

   double px = gClose[1];

   // 1) HTF PERMISSION — higher-TF stack must not oppose.  [HARD]
   int htfDir = g_state.htf.stackDir;
   if(htfDir!=DIR_NONE && htfDir!=dir){ sym_factVeto="HTF opposes"; return(false); }

   // 2) OWNERSHIP — the owner of price must be this direction.  [HARD]
   int owner = g_state.campaign.owner;
   if(owner==DIR_NONE) owner = g_state.curve.ownerDir;
   if(owner!=DIR_NONE && owner!=dir){ sym_factVeto="owner opposes"; return(false); }

   // 3) LOCATION — price must be AT a real zone.  [SOFT: regret-learnable]
   if(g_cfg.factNeedZone && !Sym_AtRealZone(dir,px)){ if(SymVeto(VR_NOZONE,"no zone",dir,px)) return(false); }

   // 4) STRUCTURE — no change-of-character against the trade.  [HARD]
   if(g_state.structure.choch == -dir){ sym_factVeto="CHoCH against"; return(false); }

   // 5) CONVEXITY ROOM — capacity left + wave not exhausted.  [SOFT]
   if(g_state.convexity.geometryCapacity < g_cfg.minEntryRoomPct){ if(SymVeto(VR_NOROOM,"no room",dir,px)) return(false); }
   if(g_state.wave.completion >= g_cfg.maxEntryComplete){ if(SymVeto(VR_EXHAUST,"wave exhausted",dir,px)) return(false); }

   // 5b) CURVE LOCATOR — never enter LATE on the OWNER leg.  [SOFT]
   if(g_cfg.useCurveLocator && g_state.curveLocator.pos >= g_cfg.maxOwnerLegPos)
   { if(SymVeto(VR_LATE,"late on curve",dir,px)) return(false); }

   // 6) THREAT — dominant opposing network authority OR participant.  [SOFT]
   if(g_state.network.pressureDir == -dir
      && MathAbs(g_state.network.pressure) >= g_cfg.factNetPressure){ if(SymVeto(VR_NETWORK,"network counter",dir,px)) return(false); }
   double oppPart = (dir==DIR_LONG ? g_state.participants.seller : g_state.participants.buyer);
   double ownPart = (dir==DIR_LONG ? g_state.participants.buyer  : g_state.participants.seller);
   if(oppPart>=g_cfg.factPartThreat && oppPart>ownPart){ if(SymVeto(VR_PARTICIPANT,"participant counter",dir,px)) return(false); }

   // 7) LEARNED AVOIDANCE — refuse to repeat its own losing context.  [HARD]
   if(AD_Veto(AD_Bucket(dir))){ sym_factVeto="learned avoid"; return(false); }

   // 7b) TIME INTELLIGENCE (TIE) — optional soft temporal permit. Off by
   //     default (informational). When enabled, a DEAD-hour timeQuality
   //     vetoes new entries (the hard session window stays separate).
   if(g_cfg.useTimeIntel && g_cfg.timeGateEntries && !g_state.timeIntel.permit)
   { sym_factVeto="time dead"; return(false); }

   // 8) SELF-AWARENESS — stood itself down (health / loss cluster / DD).  [HARD]
   if(SA_StandDown()){ sym_factVeto="self standdown"; return(false); }

   return(true);
}

//==================================================================
// CONFLUENCE GATE — Symphony provides precise TIMING; the Decision layer
// owns the GO / NO-GO. An entry only fires when the brain has not stood the
// shot down and conviction clears the SAME thresholds the Decision layer uses:
//   • direction agrees with the established owner/master (no shorting a long book)
//   • the verdict is not a stand-down action (WAIT / NO_TRADE / EXIT / DEFEND)
//   • executionProbability >= execProbArm
//   • confidence       >= minConf
// (This is what would have vetoed the low-conviction short: WAIT, exec 29%,
//  confidence 36, threat 64.) Toggle off with InpRequireConfluence=false to run
// Symphony stand-alone.
//==================================================================
bool SymphonyBrainConfirms(const int dir)
{
   if(!g_cfg.requireConfluence) return(true);
   FalconIntelligence x = g_state.intel;

   // wrong side relative to the owner/master direction
   if(g_state.exec.master!=DIR_NONE && g_state.exec.master!=dir) return(false);

   // brain is actively telling us to stand down / protect / bank
   int a = g_state.exec.action;
   if(a==ACT_WAIT || a==ACT_NO_TRADE || a==ACT_EXIT || a==ACT_DEFEND) return(false);

   // continuous-probability conviction gates (phases are outputs, these decide)
   if(x.executionProbability < g_cfg.execProbArm) return(false);
   if(x.confidence           < g_cfg.minConf)     return(false);

   return(true);
}

//==================================================================
// PLACE ENTRY — compose the subsystem trade plan, then execute it.
//   When useTradePlan: stop = subsystem zone-invalidation, target =
//   owner-driven destination, lots scaled by participant/campaign
//   conviction, and the entry must clear the subsystem reward:risk gate.
//   Otherwise falls back to Symphony's anchor ± 0.25 ATR stop.
//==================================================================
//==================================================================
// STRUCTURAL STOP — Symphony-style: place the stop just BEYOND the
// structure (impulse anchor / swing), not a fixed ATR off entry.
//   LONG  : structural swing LOW  - 0.25 ATR
//   SHORT : structural swing HIGH + 0.25 ATR
// Priority: the current Symphony impulse anchor (its structural origin),
// else the nearest recent pivot on the correct side, else ATR fallback.
//==================================================================
double Sym_StructuralStop(const int dir,const double entry,const double atr)
{
   double buf = atr*0.25;

   // 1) Symphony impulse anchor — the structural origin of the live impulse
   if(dir==DIR_LONG  && sym_anchorLow >0.0 && sym_anchorLow <entry) return(sym_anchorLow  - buf);
   if(dir==DIR_SHORT && sym_anchorHigh>0.0 && sym_anchorHigh>entry) return(sym_anchorHigh + buf);

   // 2) nearest recent structural swing on the correct side
   int len = g_cfg.pivotLen;
   if(dir==DIR_LONG)
   {
      for(int c=len+1;c<80;c++)
         if(FalconIsPivotLow(c,len) && gLow[c]<entry) return(gLow[c]-buf);
   }
   else
   {
      for(int c=len+1;c<80;c++)
         if(FalconIsPivotHigh(c,len) && gHigh[c]>entry) return(gHigh[c]+buf);
   }

   // 3) fallback: ATR stop
   return(dir==DIR_LONG ? entry-g_cfg.cycleRawStopATR*atr : entry+g_cfg.cycleRawStopATR*atr);
}

void Sym_PlaceEntry(const int dir,const string tag,const double riskCash,const double atrNow,const bool raw=false)
{
   double entry = (dir==DIR_LONG ? SymbolInfoDouble(_Symbol,SYMBOL_ASK)
                                 : SymbolInfoDouble(_Symbol,SYMBOL_BID));
   double sl, target=0.0, t2=0.0, rr=0.0;
   double lots;
   int    adBucket = AD_Bucket(dir);            // self-learning context
   double adMult   = AD_SizeMult(adBucket);     // size by learned edge
   double saMult   = SA_Throttle();             // global self-awareness throttle

   if(raw)
   {
      // RAW / FREE mode: STRUCTURAL stop (Symphony-style — just beyond the
      // swing/anchor), with the target placed at minRR x the structural risk so
      // every entry is a real structural setup at the required R:R. (The
      // capture-at-done exit banks profit at the curve destination; this TP is
      // the backstop.)
      sl = Sym_StructuralStop(dir, entry, atrNow);
      double stopDist = MathAbs(entry - sl);
      if(stopDist <= 0.0) return;
      if(g_cfg.maxStopATR>0.0 && stopDist > g_cfg.maxStopATR*atrNow) return;  // structure too far -> skip
      double t = stopDist * g_cfg.minRR;
      target = (dir==DIR_LONG ? entry + t : entry - t);
      t2     = target;
      rr     = g_cfg.minRR;
      lots   = Sym_SizeLots(dir, riskCash*adMult*saMult, entry, sl);
   }
   else if(g_cfg.useTradePlan)
   {
      FalconTradePlan pl = ComposeTradePlan(dir, entry, atrNow);
      if(!pl.valid)          return;
      if(pl.rr < g_cfg.minRR) return;                 // subsystem-derived R:R gate
      sl     = pl.stop; target = pl.target; t2 = pl.target2; rr = pl.rr;
      lots   = Sym_SizeLots(dir, riskCash*pl.convictionMult*adMult*saMult, entry, sl);  // conviction x learned edge x self-throttle
   }
   else
   {
      sl   = (dir==DIR_LONG ? sym_anchorLow - atrNow*0.25 : sym_anchorHigh + atrNow*0.25);
      lots = Sym_SizeLots(dir, riskCash*adMult*saMult, entry, sl);
   }

   bool slOk = (dir==DIR_LONG ? (sl>0 && entry>sl) : (sl>0 && sl>entry));
   if(!slOk || lots<=0.0) return;

   // bank the runner at the destination: composed (or raw) target -> position TP
   double tpOrder = (target>0.0 && (raw || (g_cfg.useTradePlan && g_cfg.targetTP))) ? target : 0.0;
   if(EE_SendMarketOrder(dir>0?+1:-1, lots, sl, "SYM "+tag, tpOrder))
   {
      if(dir==DIR_LONG){ sym_lastLongTradeTime=gTime[0]; sym_longCampaignOpen=true; }
      else             { sym_lastShortTradeTime=gTime[0]; sym_shortCampaignOpen=true; }
      TJ_RecordEntry(ee_lastTicket,dir,tag,entry,sl,lots);
      AD_RecordEntry(ee_lastTicket, adBucket, lots*MathAbs(entry-sl)*g_cfg.contractValue, g_state.intel.executionProbability);
      g_state.exec.entry=entry; g_state.exec.stop=sl; g_state.exec.lots=lots; g_state.exec.riskCash=riskCash;
      g_state.exec.target=target; g_state.exec.target2=t2; g_state.exec.reward=rr;
   }
}

//==================================================================
// ENTRIES — Phase 3 + Phase 4 only (long & short)   [Symphony]
//   Trigger/timing = Symphony phase edge; stop/target/size = composed
//   from the subsystems (TradePlan). Reuses EE_IsTradeTime.
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

   // The Symphony per-impulse lockout only makes sense under Symphony authority
   // (it is keyed to sym anchors). Other engines — and Symphony itself in FREE
   // RUN — rely on edge-triggering + per-bar dedupe to avoid churn.
   bool symAuth  = (g_cfg.entryEngine!=ENG_CONSENSUS && Sym_EffectiveEngine()==ENG_SYMPHONY);
   bool freeMode = (g_cfg.cycleFreeRun && g_cfg.runAllCycles);   // any authority engine trades ALL phases
   bool rawLike  = (!symAuth || freeMode);                       // free/raw entry behaviour (no lockout / no anchor confirm)
   if(rawLike){ longLocked=false; shortLocked=false; }

   // EDGE-TRIGGERED entries from the SELECTED engine's wave cycle (LETRA / F16 /
   // Symphony / Consensus / Best). Each fires only on the bar the engine
   // TRANSITIONS into a return (P3) or breakout (P4), then clears the SAME
   // subsystem gates (facts / brain / counter-dir).
   bool eL3,eL4,eS3,eS4;
   Sym_RawEntryEdges(eL3,eL4,eS3,eS4);

   // RAW mode: an engine entering on its own edge (non-Symphony, or Symphony in
   // FREE RUN) bypasses the Symphony fact/brain gate (which is tuned to
   // Symphony's "price-back-at-zone" phase-3 and would veto raw phase edges)
   // and uses a clean ATR stop/target. This is what makes the A/B/C test fair
   // and lets any engine "trade freely like LETRA".
   bool rawMode = (g_cfg.cycleRawEntries && rawLike);
   bool gateL = rawMode || (SymphonyFactsConfirm(DIR_LONG)  && SymphonyBrainConfirms(DIR_LONG));
   bool gateS = rawMode || (SymphonyFactsConfirm(DIR_SHORT) && SymphonyBrainConfirms(DIR_SHORT));

   bool L3 = (eL3 && !longLocked  && !MM_CounterDirBlocked(DIR_LONG)  && gateL);
   bool L4 = (eL4 && !longLocked  && !MM_CounterDirBlocked(DIR_LONG)  && gateL);
   bool S3 = (eS3 && !shortLocked && !MM_CounterDirBlocked(DIR_SHORT) && gateS);
   bool S4 = (eS4 && !shortLocked && !MM_CounterDirBlocked(DIR_SHORT) && gateS);

   string engTag = FalconEngineStr(g_cfg.entryEngine==ENG_BEST?g_state.referee.bestEngine:g_cfg.entryEngine);

   // NO HEDGE — never hold both directions. Block a new entry while ANY
   // opposite-direction position is open (regardless of its PnL). This is the
   // hard "one direction at a time" rule, distinct from the counter-dir lock
   // (which only blocks against a *net-profitable* opposite book).
   if(g_cfg.noHedge)
   {
      if(g_state.exec.openShortCount>0){ L3=false; L4=false; }
      if(g_state.exec.openLongCount >0){ S3=false; S4=false; }
   }

   // MAX CONCURRENT POSITIONS — hard cap across all directions. Once the cap is
   // reached, no new entries fire (existing positions still manage their exits).
   if(g_cfg.maxOpenPositions>0 &&
      (g_state.exec.openLongCount+g_state.exec.openShortCount) >= g_cfg.maxOpenPositions)
   { L3=false; L4=false; S3=false; S4=false; }

   double impL = sym_anchorHigh - sym_anchorLow;
   double impS = sym_anchorHigh - sym_anchorLow;

   // LONG P3
   if(L3 && sym_lastLongTradeTime!=barTime)
      Sym_PlaceEntry(DIR_LONG,engTag+" P3 Long",riskCash,atrNow,rawMode);

   // LONG P4
   if(L4 && sym_lastLongTradeTime!=barTime && (rawLike || impL>0))
   {
      bool breakout = rawLike || (closeNow>sym_anchorHigh || closeNow>gHigh[shiftNow+1] + 0.20*atrNow);
      if(breakout) Sym_PlaceEntry(DIR_LONG,engTag+" P4 Long",riskCash,atrNow,rawMode);
   }

   // SHORT P3
   if(S3 && sym_lastShortTradeTime!=barTime)
      Sym_PlaceEntry(DIR_SHORT,engTag+" P3 Short",riskCash,atrNow,rawMode);

   // SHORT P4
   if(S4 && sym_lastShortTradeTime!=barTime && (rawLike || impS>0))
   {
      bool breakout = rawLike || (closeNow<sym_anchorLow || closeNow<gLow[shiftNow+1] - 0.20*atrNow);
      if(breakout) Sym_PlaceEntry(DIR_SHORT,engTag+" P4 Short",riskCash,atrNow,rawMode);
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

   // RAW/FREE mode: TALON + position TP/SL + PYRO own the exit. Symphony's
   // ARC/phase exit is keyed to sym_mode/sym_phase and would kill the authority
   // engine's trades early (and fire constantly in free-run). Skip it.
   if(SymRawActive()) return;

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

   // 4b) PROFIT GIVE-BACK LOCK — the give-back killer. The structural/convergence
   //    trail only tightens NEAR the target; a stacked campaign can run deep in
   //    profit while the destination is still far, and hand a chunk back before
   //    the wide trail catches. So track PEAK favorable excursion (ATR, ratchet
   //    only) and, once it clears talonLockArmATR, never give back more than
   //    talonGiveback of that peak. This caps "up heavy then gives it back"
   //    regardless of distance to target. talonGiveback=1 disables it.
   double favATR = (dir==DIR_LONG ? (price-E) : (E-price))/atr;
   if(dir==DIR_LONG){ if(favATR>talon_peakLong)  talon_peakLong =favATR; }
   else             { if(favATR>talon_peakShort) talon_peakShort=favATR; }
   double peakATR = (dir==DIR_LONG ? talon_peakLong : talon_peakShort);
   bool   lockOn  = false; double lockSL = 0.0;
   if(g_cfg.talonGiveback < 1.0 && peakATR >= g_cfg.talonLockArmATR)
   {
      double keep = (1.0 - g_cfg.talonGiveback) * peakATR * atr;   // profit (price) to protect
      lockSL = (dir==DIR_LONG ? E + keep : E - keep);
      lockOn = true;
   }

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
   // profit give-back lock ratchets the stop up to protect banked peak profit
   if(lockOn)
      cand = (dir==DIR_LONG ? MathMax(cand,lockSL) : MathMin(cand,lockSL));

   // stage (display)
   int stage;
   if(!beLocked)        stage=TG_FORMING;
   else if(terminal)    stage=TG_TERMINAL;
   else if(lockOn && ((dir==DIR_LONG && lockSL>=convSL) || (dir==DIR_SHORT && lockSL<=convSL))) stage=TG_CONVERGING;
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

   // TALON needs the campaign baskets (blended entry / stack count / favorable
   // excursion). PYRO builds them when it runs — but if PYRO is OFF, TALON must
   // build them itself, otherwise the grip is inert (stackCount stays 0) and
   // trades give profit back with no trailing at all.
   if(!g_cfg.useThermalRisk)
   {
      TR_BuildCampaign(DIR_LONG,  g_state.risk.campaign[0]);
      TR_BuildCampaign(DIR_SHORT, g_state.risk.campaign[1]);
   }

   // confirmed structural pivots for the grip anchor
   int cl = g_cfg.talonStructLen+1;
   double pLow  = FalconIsPivotLow (cl,g_cfg.talonStructLen) ? gLow[cl]  : 0.0;
   double pHigh = FalconIsPivotHigh(cl,g_cfg.talonStructLen) ? gHigh[cl] : 0.0;

   FalconThermalCampaign cL = g_state.risk.campaign[0];
   FalconThermalCampaign cS = g_state.risk.campaign[1];

   if(cL.stackCount>0) TalonManageSide(DIR_LONG, cL, atr, bid, ask, pLow);
   else { talon_anchorLong=0.0;  talon_beLong=false;  talon_peakLong=0.0;  g_state.exec.gripLong=0.0;  g_state.exec.talonStageLong=TG_FORMING; }

   if(cS.stackCount>0) TalonManageSide(DIR_SHORT, cS, atr, bid, ask, pHigh);
   else { talon_anchorShort=0.0; talon_beShort=false; talon_peakShort=0.0; g_state.exec.gripShort=0.0; g_state.exec.talonStageShort=TG_FORMING; }
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

   // RAW/FREE mode: the ARC destination (Sym_DestLong/Short) is Symphony's
   // impulse target, not the authority engine's — banking against it would
   // clip a LETRA/free trade at the wrong level. The raw position TP banks at
   // target instead, and TALON trails the rest. Skip the ARC partial here.
   if(SymRawActive()) return;

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
// CAPTURE-AT-DONE — the "no trail, just bank it when the move is finished"
// exit. When the OWNER curve has travelled to its destination (curve
// locator pos >= captureCurvePos) and a position in that direction is in
// profit, close it. No trailing, no breakeven scratch — the trade rides
// the full squeeze and the profit is taken when the curve completes.
// (Losers are still cut by the position SL; runaway TP still backstops.)
//==================================================================
void SymphonyCaptureExit()
{
   if(!g_cfg.captureAtDone) return;
   if(g_state.curveLocator.pos < g_cfg.captureCurvePos) return;   // move not done yet
   int odir = g_state.curveLocator.dir;
   if(odir==DIR_NONE) return;

   int total=PositionsTotal();
   for(int i=total-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=g_cfg.magic) continue;
      double pnl=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
      if(pnl<=0.0) continue;                                       // only CAPTURE profit
      long type=PositionGetInteger(POSITION_TYPE);
      if(type==POSITION_TYPE_BUY  && odir==DIR_LONG)  { if(EE_CloseFull(ticket)) FalconPublish(EVT_EXIT_FIRED, 1); }
      if(type==POSITION_TYPE_SELL && odir==DIR_SHORT) { if(EE_CloseFull(ticket)) FalconPublish(EVT_EXIT_FIRED,-1); }
   }
}

//==================================================================
// MASTER — Symphony manage step (manage open trades, then exits, then entries)
//   Called from the pipeline's execution stage when g_cfg.useSymphony.
//==================================================================
void SymphonyTradeManage()
{
   SymphonyUpdateCampaignLockout(); // detect closed campaigns -> lock the impulse (no churn)
   if(g_cfg.useProfitLadder)        // v3.0 default: live-PnL ladder + BE/trail protection
   {
      MM_RunStopProtection();
      MM_RunProfitLadder();
   }
   if(g_cfg.useTalon)               // optional: TALON curve-convergent grip + ARC partial
   {
      TalonGrip();
      SymphonyArcPartial();
   }
   SymphonyCaptureExit();   // bank profit when the curve reaches its destination (no trailing)
   SymphonyManageExits();   // composite ARC + institutional + phase reversal exit (suppressed in raw/free)
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
      case 12:return("LEARNING");
      case 13:return("ENGINES");
      case 14:return("COMMAND");
      default:return("DIAGNOSTICS");
   }
}

string VZ_Band(const int b){ return(b==0?"Early":b==1?"Dev":b==2?"Mid":b==3?"Late":"Term"); }
string VZ_Reason(const int c)
{
   switch(c){ case VR_NOZONE:return("no-zone"); case VR_NOROOM:return("no-room");
              case VR_EXHAUST:return("exhausted"); case VR_LATE:return("late-curve");
              case VR_NETWORK:return("net-counter"); case VR_PARTICIPANT:return("part-counter"); }
   return("?");
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
         s+="Owner       : "+VZ_Dir(g_state.campaign.owner)+"  ctrl "+DoubleToString(g_state.campaign.controlScore,0)
            +"  HTF "+DoubleToString(g_state.htf.alignment,0)+"%"+(g_state.htf.fractalAgreement?" agree":"")+"\n";
         s+="Curve here  : "+DoubleToString(g_state.curveLocator.pos*100.0,0)+"% "+g_state.curveLocator.label
            +(g_state.curveLocator.advancing?" adv":" retr")+"  room "+DoubleToString(g_state.convexity.geometryCapacity,0)
            +"  "+FalconResStr(x.resolutionState)+"\n";
         s+="Conviction  : "+DoubleToString(x.confidence,0)+"   ExecProb "+DoubleToString(x.executionProbability*100.0,0)+"%\n";
         s+="Master Chief: "+(x.masterChiefConfirm?"CLEARED":"HOLD")+"  ("+DoubleToString(x.masterChiefScore,0)+")  "+x.masterChiefNote+"\n";
         s+="SELF        : "+(g_cfg.useSelfAware? (g_state.self.label+"  conf "+DoubleToString(g_state.self.selfConfidence,0)
            +"  throttle x"+DoubleToString(g_state.self.throttle,2)
            +"  (calib "+DoubleToString(g_state.self.calibration,0)
            +" form "+DoubleToString(g_state.self.form,0)+" streak "+IntegerToString(g_state.self.winStreak)+"/"+IntegerToString(g_state.self.lossStreak)+")") : "off (full size)")+"\n";
         s+="Reasoning   : concrete engines (phases / ownership / curve / structure / multi-TF)\n";
         s+="Active cfg  : "+FalconEngineStr(g_cfg.entryEngine)+"  minR "+DoubleToString(g_cfg.minRR,1)
            +"  maxPos "+IntegerToString(g_cfg.maxOpenPositions)+(g_cfg.noHedge?" 1-dir":"")
            +"  TALON "+(g_cfg.useTalon?"on":"off")+"  PYRO "+(g_cfg.useThermalRisk?"on":"off")
            +"  free "+((g_cfg.cycleFreeRun&&g_cfg.runAllCycles)?"on":"off")+"\n";
         s+="Time        : "+g_state.timeIntel.sessionName+"  Q "+DoubleToString(g_state.timeIntel.timeQuality,0)+" "+g_state.timeIntel.label
            +(g_state.timeIntel.killzone?("  KZ:"+g_state.timeIntel.killzoneName):"");
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
         s+="YOU ARE HERE: "+DoubleToString(g_state.curveLocator.pos*100.0,0)+"% of owner leg ("+g_state.curveLocator.label+")  "
            +(g_state.curveLocator.advancing?"advancing":"retracing")+"  conf "+DoubleToString(g_state.curveLocator.conf,0)+"\n";
         s+="Root        : "+VZ_Px(cu.rootOrigin)+" -> "+VZ_Px(cu.rootExtreme)+"  "+VZ_Dir(cu.rootDir)+"\n";
         s+="Parent      : "+VZ_Px(cu.parentOrigin)+" -> "+VZ_Px(cu.parentExtreme)+"  "+VZ_Dir(cu.parentDir)+"\n";
         s+="Life/Energy : "+DoubleToString(cu.life,0)+" / "+DoubleToString(cu.energy,0)+"\n";
         s+="Evolution   : "+DoubleToString(cu.evolution,0)+"%   emergent nodes "+IntegerToString(cu.emergentNodes)+"\n";
         s+="Wave Matrix : dom TF "+IntegerToString(wmx.dominantTF)+" "+VZ_Dir(wmx.dominantDir)
            +"  agree "+DoubleToString(wmx.agreement,0)+"%  E "+DoubleToString(wmx.matrixEnergy,0)+"\n";
         s+="Emergent    : "+FalconPhaseStr(cu.emergentPhase)+"\n";
         s+="── F72 TREE ─────────────────────────\n";
         s+="Nodes/Depth : "+IntegerToString(cu.treeNodeCount)+" alive  depth "+IntegerToString(cu.treeDepth)
            +"/"+IntegerToString(cu.budgetDepth)+(cu.recursionComplete?"  [RECURSION SPENT]":"")+"\n";
         s+="Owner Node  : "+VZ_Dir(cu.ownerNodeDir)+"  E "+DoubleToString(cu.ownerNodeEnergy,0)
            +"  d"+IntegerToString(cu.ownerNodeDepth)+"  "+cu.ownerNodeState+"\n";
         s+="Node leg    : "+VZ_Px(cu.ownerNodeOrigin)+" -> "+VZ_Px(cu.ownerNodeExtreme)+"\n";
         s+="Compression : "+cu.compState+"  force "+DoubleToString(cu.compForce,0)+"\n";
         s+="Migration   : 0.5 "+VZ_Px(cu.migration50)+"   0.618 "+VZ_Px(cu.migration618)+"\n";
         s+="Narrative   : "+DoubleToString(cu.narrative,0)+(cu.narrative>=55?" strengthening":cu.narrative<=45?" weakening":" balanced")
            +"  (sup "+IntegerToString(cu.supportVotes)+" / deg "+IntegerToString(cu.degradeVotes)+")\n";
         s+="── TIME (TIE) ───────────────────────\n";
         s+="Session     : "+g_state.timeIntel.sessionName+"  "+DoubleToString(g_state.timeIntel.sessionProgress*100.0,0)+"%"
            +(g_state.timeIntel.killzone?("  KZ:"+g_state.timeIntel.killzoneName):"")+"\n";
         s+="Time Quality: "+DoubleToString(g_state.timeIntel.timeQuality,0)+"  "+g_state.timeIntel.label
            +"  path "+DoubleToString(g_state.timeIntel.pathProbability*100.0,0)+"%"+(g_state.timeIntel.permit?"":"  [DEAD]");
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
      case 7: // HTF — absolute fractal ladder [0]M1 [1]M5 [2]M15 [3]H1 [4]H4 [5]D1 [6]W1
         s+="W1  "+VZ_Dir(h.dir[6])+"   D1  "+VZ_Dir(h.dir[5])+"\n";
         s+="H4  "+VZ_Dir(h.dir[4])+"   H1  "+VZ_Dir(h.dir[3])+"\n";
         s+="M15 "+VZ_Dir(h.dir[2])+"   M5  "+VZ_Dir(h.dir[1])+"   M1 "+VZ_Dir(h.dir[0])+"\n";
         s+="Operating TF: "+EnumToString(g_cfg.operatingTF)+"\n";
         s+="Stack Dir   : "+VZ_Dir(h.stackDir)+"\n";
         s+="Alignment   : "+DoubleToString(h.alignment,0)+"%   Conflict "+DoubleToString(h.conflict,0)+"%\n";
         s+="Owner TF idx: "+IntegerToString(h.ownerTF)+" ("+VZ_Dir(g_state.curve.ownerDir)+")   Fractal "+(h.fractalAgreement?"AGREE":"split")+"\n";
         s+="Owner zone  : "+((h.ownerTF>=0 && h.ownerTF<7 && g_tfZones[h.ownerTF].valid)?
              ("D "+VZ_Px(g_tfZones[h.ownerTF].demBot)+"-"+VZ_Px(g_tfZones[h.ownerTF].demTop)
              +"  S "+VZ_Px(g_tfZones[h.ownerTF].supBot)+"-"+VZ_Px(g_tfZones[h.ownerTF].supTop)) : "—")+"\n";
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
         s+="Plan        : stop<"+(g_plan.stopSrc==""?"—":g_plan.stopSrc)+"> target<"+(g_plan.targetSrc==""?"—":g_plan.targetSrc)+"> tf"+IntegerToString(g_plan.targetTF)+"  conv x"+DoubleToString(g_plan.convictionMult,2)+"\n";
         s+="TALON grip  : L "+(e.gripLong>0?VZ_Px(e.gripLong)+" "+FalconTalonStr(e.talonStageLong):"—")
            +"   S "+(e.gripShort>0?VZ_Px(e.gripShort)+" "+FalconTalonStr(e.talonStageShort):"—")+"\n";
         s+="Lots        : "+DoubleToString(e.lots,2)+"   Risk $ "+DoubleToString(e.riskCash,0)+"\n";
         s+="Fact gate   : "+(g_cfg.useFactGate?(sym_factVeto==""?"clear":"VETO — "+sym_factVeto):"off")+"\n";
         s+="Self-learn  : L x"+DoubleToString(AD_SizeMult(AD_Bucket(DIR_LONG)),2)+" (n"+IntegerToString(ad_n[AD_Bucket(DIR_LONG)])+")"
            +"  S x"+DoubleToString(AD_SizeMult(AD_Bucket(DIR_SHORT)),2)+" (n"+IntegerToString(ad_n[AD_Bucket(DIR_SHORT)])+")\n";
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
      case 12: // LEARNING — what the OS is learning about itself
      {
         FalconSelfAwareness sf=g_state.self;
         if(!g_cfg.useSelfAware)
            s+="SELF        : off (no throttle / no stand-down)\n";
         else {
         s+="SELF        : "+sf.label+"  conf "+DoubleToString(sf.selfConfidence,0)
            +"  throttle x"+DoubleToString(sf.throttle,2)+"\n";
         s+="            : calib "+DoubleToString(sf.calibration,0)+"  form "+DoubleToString(sf.form,0)
            +"  regime "+DoubleToString(sf.regimeFit,0)+"  streak "+IntegerToString(sf.winStreak)+"W/"+IntegerToString(sf.lossStreak)+"L\n";
         }
         s+="── ADAPTIVE — which setups pay (size/veto) ──\n";
         int shown=0;
         for(int b=0;b<AD_NBUCKETS;b++)
         {
            if(ad_n[b]==0) continue;
            double wr=100.0*ad_wins[b]/ad_n[b];
            string tag=(b<5?"L":"S")+("-"+VZ_Band(b%5));
            s+=StringFormat("  %-7s n%-3d wr%2.0f%%  R%+.2f  x%.2f%s\n",
                 tag, ad_n[b], wr, ad_ewmaR[b], AD_SizeMult(b),
                 (AD_Veto(b)?"  VETO":""));
            shown++;
         }
         if(shown==0) s+="  (no closed trades yet)\n";
         s+="── REGRET — misses it would've won (override) ──\n";
         int codes[6]={VR_NOZONE,VR_NOROOM,VR_EXHAUST,VR_LATE,VR_NETWORK,VR_PARTICIPANT};
         int rshown=0;
         for(int i=0;i<6;i++)
         {
            int c=codes[i]; if(mt_n[c]==0) continue;
            double wr=100.0*mt_win[c]/mt_n[c];
            s+=StringFormat("  %-12s n%-3d wr%2.0f%%  R%+.2f%s\n",
                 VZ_Reason(c), mt_n[c], wr, mt_R[c], (MT_Override(c)?"  TAKING":""));
            rshown++;
         }
         if(rshown==0) s+="  (no resolved shadow trades yet)";
         break;
      }
      case 13: // ENGINES — comparative multi-engine wave cycles (A/B/C)
      {
         WaveReferee rf=g_state.referee;
         WaveCycle L=g_state.cycles[ENG_LETRA];
         WaveCycle F=g_state.cycles[ENG_F16];
         WaveCycle Y=g_state.cycles[ENG_SYMPHONY];
         s+="AUTHORITY   : "+FalconEngineStr(g_cfg.entryEngine)+" -> drives "+rf.selectedName
            +(g_cfg.runAllCycles?"":"  (compare OFF)")+"\n";
         s+="                 LETRA       F16        SYMPHONY\n";
         s+=StringFormat("dir         : %-11s %-10s %-10s\n", VZ_Dir(L.direction),VZ_Dir(F.direction),VZ_Dir(Y.direction));
         s+=StringFormat("stage       : %-11s %-10s %-10s\n", FalconStageStr(L.stage),FalconStageStr(F.stage),FalconStageStr(Y.stage));
         s+=StringFormat("phase       : %-11s %-10s %-10s\n",
              StringSubstr(L.phaseLabel,0,10),StringSubstr(F.phaseLabel,0,10),StringSubstr(Y.phaseLabel,0,10));
         s+=StringFormat("maturity    : %-11.0f %-10.0f %-10.0f\n", L.maturity,F.maturity,Y.maturity);
         s+=StringFormat("confidence  : %-11.0f %-10.0f %-10.0f\n", L.confidence,F.confidence,Y.confidence);
         s+=StringFormat("objective   : %-11s %-10s %-10s\n", VZ_Px(L.objective),VZ_Px(F.objective),VZ_Px(Y.objective));
         s+=StringFormat("entry now   : %-11s %-10s %-10s\n",
              (L.entryEdge?("P"+IntegerToString(L.entryKind)+" "+VZ_Dir(L.entryDir)):"-"),
              (F.entryEdge?("P"+IntegerToString(F.entryKind)+" "+VZ_Dir(F.entryDir)):"-"),
              (Y.entryEdge?("P"+IntegerToString(Y.entryKind)+" "+VZ_Dir(Y.entryDir)):"-"));
         s+="── DEMONSTRATED EDGE (referee) ──────\n";
         s+=StringFormat("dir acc%%    : %-11s %-10s %-10s\n",
              StringFormat("%.0f(%d)",L.accuracy,L.samples),
              StringFormat("%.0f(%d)",F.accuracy,F.samples),
              StringFormat("%.0f(%d)",Y.accuracy,Y.samples));
         s+=StringFormat("obj acc%%    : %-11.0f %-10.0f %-10.0f\n", L.objAccuracy,F.objAccuracy,Y.objAccuracy);
         s+=StringFormat("lead (bars) : %-11.1f %-10.1f %-10.1f\n", L.avgLeadBars,F.avgLeadBars,Y.avgLeadBars);
         s+="── REFEREE VERDICT ──────────────────\n";
         s+="consensus   : "+VZ_Dir(rf.consensusDir)+"  "+FalconStageStr(rf.consensusStage)
            +"  conf "+DoubleToString(rf.consensusConf,0)+"\n";
         s+="deviation   : stage "+DoubleToString(rf.deviationStage,0)+"   objective "+DoubleToString(rf.deviationObjATR,1)+" ATR\n";
         s+="best engine : "+FalconEngineStr(rf.bestEngine)+"  acc "+DoubleToString(rf.bestAccuracy,0)
            +"%   leader "+FalconEngineStr(rf.leader)+"\n";
         s+="money mgr   : "+((g_cfg.useProfitLadder||g_cfg.counterDirBlock||g_cfg.maxBasketRiskPct>0)?"on":"DISABLED");
         break;
      }
      case 14: // COMMAND — execution + self-learning + engine comparison at a glance
      {
         WaveReferee rf=g_state.referee;
         WaveCycle L=g_state.cycles[ENG_LETRA];
         WaveCycle F=g_state.cycles[ENG_F16];
         WaveCycle Y=g_state.cycles[ENG_SYMPHONY];
         // ---- EXECUTION ----
         s+="── EXECUTION ─────────────────────────\n";
         s+="Act "+FalconActionStr(e.action)+"  "+FalconTradeStateStr(e.tradeState)+"  open L/S "+IntegerToString(e.openLongCount)+"/"+IntegerToString(e.openShortCount)+"\n";
         s+="E/SL/TP "+VZ_Px(e.entry)+" / "+VZ_Px(e.stop)+" / "+VZ_Px(e.target)+"  R:R "+DoubleToString(e.reward,2)+"\n";
         s+="TALON L "+(e.gripLong>0?VZ_Px(e.gripLong)+" "+FalconTalonStr(e.talonStageLong):"—")
            +"  S "+(e.gripShort>0?VZ_Px(e.gripShort)+" "+FalconTalonStr(e.talonStageShort):"—")+"\n";
         s+="Lots "+DoubleToString(e.lots,2)+"  Risk$ "+DoubleToString(e.riskCash,0)+"  PnL "+DoubleToString(e.openPnL,2)
            +"  "+(e.sessionOpen?"SES":"--")+"  gate "+(g_cfg.useFactGate?(sym_factVeto==""?"clear":sym_factVeto):"off")+"\n";
         // ---- SELF-LEARNING ----
         s+="── SELF-LEARNING ─────────────────────\n";
         if(g_cfg.useSelfAware)
            s+="SELF "+g_state.self.label+" x"+DoubleToString(g_state.self.throttle,2)
               +"  "+IntegerToString(g_state.self.winStreak)+"W/"+IntegerToString(g_state.self.lossStreak)+"L\n";
         else s+="SELF off\n";
         s+="Adaptive L x"+DoubleToString(AD_SizeMult(AD_Bucket(DIR_LONG)),2)+"(n"+IntegerToString(ad_n[AD_Bucket(DIR_LONG)])+")"
            +"  S x"+DoubleToString(AD_SizeMult(AD_Bucket(DIR_SHORT)),2)+"(n"+IntegerToString(ad_n[AD_Bucket(DIR_SHORT)])+")"
            +"  globR "+DoubleToString(ad_globalR,2)+"\n";
         int ccodes[6]={VR_NOZONE,VR_NOROOM,VR_EXHAUST,VR_LATE,VR_NETWORK,VR_PARTICIPANT};
         int taking=0; for(int i=0;i<6;i++) if(MT_Override(ccodes[i])) taking++;
         s+="Regret overrides active: "+IntegerToString(taking)+"\n";
         // ---- ENGINE COMPARISON ----
         s+="── ENGINES (dir · stage · acc%(n)) ───\n";
         s+=StringFormat("LETRA %-5s %-10s %.0f(%d)\n", VZ_Dir(L.direction),FalconStageStr(L.stage),L.accuracy,L.samples);
         s+=StringFormat("F16   %-5s %-10s %.0f(%d)\n", VZ_Dir(F.direction),FalconStageStr(F.stage),F.accuracy,F.samples);
         s+=StringFormat("SYMPH %-5s %-10s %.0f(%d)\n", VZ_Dir(Y.direction),FalconStageStr(Y.stage),Y.accuracy,Y.samples);
         s+="Consensus "+VZ_Dir(rf.consensusDir)+" "+FalconStageStr(rf.consensusStage)
            +"  dev st"+DoubleToString(rf.deviationStage,0)+"/"+DoubleToString(rf.deviationObjATR,1)+"ATR\n";
         s+="Best "+FalconEngineStr(rf.bestEngine)+" "+DoubleToString(rf.bestAccuracy,0)+"%"
            +"  Lead "+FalconEngineStr(rf.leader)+"  Auth "+FalconEngineStr(g_cfg.entryEngine);
         break;
      }
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
   if(lparam==84 || lparam==39)       g_cfg.dashboardTab = (g_cfg.dashboardTab+1)%15;  // 'T' / RIGHT
   else if(lparam==37)                g_cfg.dashboardTab = (g_cfg.dashboardTab+14)%15;  // LEFT
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

   // MULTI-ENGINE WAVE CYCLES — run THREE phase cycles on the SAME shared
   // observations and let the market decide which has the highest predictive
   // power (don't replace the phase engine — compare them). LETRA is captured
   // HERE from the still-native g_state.wave, before any authority overwrites it.
   if(g_cfg.runAllCycles) CycleLetra_Compute();   // ENG_LETRA — per-TF structural FSM lens
   if(g_cfg.useSymphony)
   {
      SymphonyComputePhases();                    // compute sym_* (NO bridge yet)
      if(g_cfg.runAllCycles) CycleSymphony_Compute(); // ENG_SYMPHONY — impulse/retracement lens
   }

   // PHASE AUTHORITY — write the SELECTED engine's read into the canonical
   // g_state.wave BEFORE the Memory layer consumes it, so ownership/intel/
   // decision all reason on the chosen engine (default Symphony = unchanged).
   // The F16 lens uses the curve tree built last bar (a 1-bar lag) because the
   // tree must rebuild AFTER Memory; entries (execution layer) use the fresh
   // F16 cycle computed below.
   PhaseAuthorityApply();

   // ── MEMORY LAYER ──────────────────────────────────────────────
   // Network → Curve Tree → Wave Matrix → FEZ → FRZ → Campaign →
   // Participants   (remembers)
   FalconModuleStart(MOD_MEMORY,t0);
   MemoryEngineRun();
   CurveTreeRun();      // F72 recursive curve tree — enrich ownership/recursion after memory resolves the owner TF
   if(g_cfg.runAllCycles) CycleF16_Compute();   // ENG_F16 — recursive curve-tree node lens (fresh, after the tree rebuilds)
   TimeEngineRun();     // TIE — 5-cycle temporal stack (session/killzone/time-quality)
   CurveLocatorRun();   // always-on "you are here" on the curve (multi-TF, persistent)
   WaveRefereeRun();    // S12J referee — score each engine, form consensus / best, measure deviation
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
   SelfAwarenessRun();   // metacognition: refresh self-confidence + throttle before entries
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
   TradeJournalOnBar();   // snapshot MFE/MAE + finalise closed trades to the CSV
   AdaptiveOnBar();       // learn from closed trades -> update per-context edge
   MissTradeOnBar();      // resolve shadow (missed) trades -> regret learning
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
   MoneyManagerInit();
   CurveTreeInit();
   TimeEngineInit();
   CurveLocatorInit();
   WaveRefereeInit();
   AdaptiveInit();
   SelfAwarenessInit();
   MissTradeInit();
   if(g_cfg.useSymphony) SymphonyInit();
   TradeJournalInit();

   if(!FalconRefreshSeries())
   {
      FalconError("Kernel","initial series refresh failed");
      return(INIT_FAILED);
   }

   FalconLog("INFO","Kernel",
      StringFormat("FALCON OS booted — profile=%d magic=%d trading=%s thermalRisk=%s",
        g_cfg.profile, (int)g_cfg.magic,
        g_cfg.enableTrading?"on":"off", g_cfg.useThermalRisk?"PYRO":"off"));
   // ACTIVE RESOLVED CONFIG — note: MetaTrader cannot change the Inputs grid from
   // code, so a selected preset is applied INTERNALLY (here) — the grid still
   // shows your typed values. This line is the source of truth for what is live.
   PrintFormat("[FALCON] PRESET=%s -> engine=%s  minRR=%.1f  maxPos=%d  noHedge=%s  rawStop/Tgt=%.1f/%.1f  TALON=%s(gb %.2f)  PYRO=%s(stacks %d)",
        (InpPreset==PRESET_LETRA?"LETRA":InpPreset==PRESET_SYMPHONY?"SYMPHONY":"CUSTOM"),
        FalconEngineStr(g_cfg.entryEngine), g_cfg.minRR, g_cfg.maxOpenPositions,
        g_cfg.noHedge?"on":"off", g_cfg.cycleRawStopATR, g_cfg.cycleRawTgtATR,
        g_cfg.useTalon?"on":"off", g_cfg.talonGiveback,
        g_cfg.useThermalRisk?"on":"off", g_cfg.maxStacks);
   PrintFormat("[FALCON] Unified Trading Intelligence Platform online. 6 engines · 1 shared state · deterministic pipeline.");
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   TradeJournalDeinit();
   AdaptiveDeinit();
   MissTradeDeinit();
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
