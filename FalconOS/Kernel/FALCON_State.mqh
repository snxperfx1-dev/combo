//+------------------------------------------------------------------+
//| FALCON_State.mqh                                                  |
//| FALCON OS - Kernel: Master Shared State (Single Source of Truth)  |
//|                                                                   |
//| ONE MarketState object referenced by every subsystem. No module  |
//| holds its own copy of any value. Every calculation writes here    |
//| exactly once; every consumer reads from here.                     |
//+------------------------------------------------------------------+
#property strict

//==================================================================
// GLOBAL ENUMS (shared vocabulary across all modules)
//==================================================================
enum FALCON_WavePhase
{
   WP_POINT4_ORIGIN = 0,
   WP_EXPANSION = 1,
   WP_EXP_PRECONVEXITY = 2,
   WP_EXP_INDUCTION = 3,
   WP_EXP_LIQUIDITY = 4,
   WP_NEW_HIGH = 5,
   WP_NEW_LOW = 6,
   WP_ABSORPTION = 7,
   WP_RETRACEMENT = 8,
   WP_RETR_PRECONVEXITY = 9,
   WP_RETR_INDUCTION = 10,
   WP_RETR_LIQUIDITY = 11,
   WP_DEMAND_RETURN = 12,
   WP_SUPPLY_RETURN = 13
};

enum FALCON_Resolution { FR_UNRESOLVED=0, FR_PARTIAL=1, FR_RESOLVED=2 };
enum FALCON_EDEState   { EDE_ACCUM=1, EDE_REL1=2, EDE_REL2=3, EDE_PURGE=4, EDE_DELIVER=5, EDE_RESOLVE=6 };

// Master Decision verdicts (the ONLY outputs of the Decision Engine)
enum FALCON_Decision
{
   DEC_NO_TRADE = 0,
   DEC_WAIT = 1,
   DEC_BUY = 2,
   DEC_SELL = 3,
   DEC_ATTACK = 4,
   DEC_DEFEND = 5,
   DEC_EXIT = 6,
   DEC_SCALE = 7
};

enum FALCON_TFLayer { L_M1=0, L_M3=1, L_M5=2, L_M15=3, L_H1=4, L_H4=5, L_TFCOUNT=6 };
enum FALCON_Profile { PROFILE_BACKTEST=0, PROFILE_LIVE=1, PROFILE_RESEARCH=2 };


//==================================================================
// PHYSICS SUB-STATE
//==================================================================
struct FALCON_Physics
{
   double atr;
   double velocity;
   double acceleration;
   double convexity;
   double convSmoothed;      // smoothed convexity
   double efficiency;
   double displacement;
   double momentum;
   double volatility;        // volatility ratio
   double energy;            // expansion energy proxy
   double compression;       // 0-100 (high = tight)
   double expansion;         // expansion score 0-100
   // physics behaviour flags
   bool   bullImpulse;
   bool   bearImpulse;
   bool   bullMomDecay;
   bool   bearMomDecay;
   bool   bullConvShift;
   bool   bearConvShift;
   bool   velDecay70;
   bool   velDecay50;
};

//==================================================================
// STRUCTURE SUB-STATE
//==================================================================
struct FALCON_Structure
{
   int    trend;             // 1=up, -1=down, 0=range
   bool   isHH;
   bool   isHL;
   bool   isLH;
   bool   isLL;
   double swingHigh;
   double swingLow;
   double prevSwingHigh;
   double prevSwingLow;
   int    bos;               // 1=bull BOS, -1=bear BOS
   int    choch;             // 1=bull CHoCH, -1=bear CHoCH
   double breakStrength;     // ATR multiple of the break
   int    internalStructure; // LTF structure bias
   int    externalStructure; // HTF structure bias
};


//==================================================================
// LIQUIDITY SUB-STATE
//==================================================================
struct FALCON_Liquidity
{
   double pools[64];         // recent liquidity pool prices
   int    poolCount;
   bool   sweepBull;
   bool   sweepBear;
   double clusterDensity;    // weighted density near price
   double sweepProbability;  // 0-100
   double pressure;          // liquidity pressure -100..+100
   double score;             // overall liquidity score 0-100
   double inducementPrice;
   bool   falseChoch;
   bool   acceptance;        // price accepted inside zone
   bool   sweepOK;           // sweep validated for entry
   double heat;              // 0-100 heatmap
};

//==================================================================
// WAVE SUB-STATE
//==================================================================
struct FALCON_Wave
{
   FALCON_WavePhase phase;
   int    direction;         // 1=bull, -1=bear
   double strength;          // 0-100
   double energy;            // 0-100
   int    age;               // bars since wave birth
   double completion;        // wave progress 0-100
   double confidence;        // 0-100
   // phase-component scores
   double expansion;
   double retracement;
   double induction;
   double liquidation;
   double preConvexity;
   double convexity;
   double absorption;
   double origin;            // wave origin / invalidation price
   double flipTop;
   double flipBot;
   double target;
   double point4High;
   double point4Low;
   double cycleHigh;
   double cycleLow;
   int    entryCycle;
   int    waveDepth;
   bool   isRecursive;
   bool   recursiveComplete;
};


//==================================================================
// PER-TIMEFRAME STRUCTURE (the 6-TF fractal stack)
//==================================================================
struct FALCON_TFStructure
{
   int    direction;
   FALCON_WavePhase phase;
   double swingHigh;
   double swingLow;
   double prevSwingHigh;
   double prevSwingLow;
   int    bos;
   int    choch;
   double point4High;
   double point4Low;
   double invalidation;
   double target;
   double flipTop;
   double flipBot;
   double waveProgress;
   double convexityMaturity;
   double modelFit;
   double compression;
   int    recursiveBreaks;
   double recursiveDominance;
};

//==================================================================
// HTF SUB-STATE
//==================================================================
struct FALCON_HTF
{
   int    direction;         // dominant HTF direction
   double beliefBull;        // HTF bull belief 0-100
   double beliefBear;        // HTF bear belief 0-100
   double alignment;         // fractal alignment 0-100
   double conflict;          // 0-100
   double dominance;         // who dominates 0-100
   double fractalAgreement;  // 0-100
   int    fractalDir;        // fractal stack direction
   double fractalScore;      // fractal stack score
   double contextScore;      // weighted context score
};

//==================================================================
// FU SUB-STATE
//==================================================================
struct FALCON_FU
{
   bool   candleActive;
   double zoneTop;
   double zoneBot;
   double confidence;        // 0-100
   int    lifecycle;         // 0=Fresh,1=Active,2=Interacting,3=Exhausted,4=Invalidated
   double strength;          // 0-100
   int    activeZoneCount;
   double recursiveAlign;    // multi-TF FU alignment %
   double winTarget;         // highest-TF FU pool magnet
   double wickTip;
   double wickMid;
   double inductionBandHi;
   double inductionBandLo;
   double leftPoolMagnet;
   int    wickDirection;
   bool   wickValidated;
};


//==================================================================
// NETWORK SUB-STATE (Invisible Network)
//==================================================================
struct FALCON_NetworkNode
{
   double price;
   double mid;
   int    direction;
   double score;
   int    weight;            // TF weight
   int    state;             // 0=Active,1=Dormant,2=Consumed,3=Historical
   int    age;
   int    revisits;          // conversation weight
   double authority;
};

struct FALCON_Network
{
   int    nodeCount;
   int    eligibleCount;
   int    bias;              // network directional bias
   double pressure;          // -100..+100
   // FEZ corridor
   double fezHigh;
   double fezLow;
   int    fezHighWeight;
   int    fezLowWeight;
   // dominant attractor
   int    attractorIdx;
   double attractorAuthority;
   double attractorPrice;
   string attractorDesc;
   bool   insideFEZ;
};

//==================================================================
// CURVE SUB-STATE (Curve Tree)
//==================================================================
struct FALCON_Curve
{
   int    direction;
   double origin;            // root
   double extreme;
   double dispATR;
   double energyIn;
   double energyDissipated;
   double energyResidual;
   double convexity;
   double compression;
   double maturity;
   // tree
   int    treeNodeCount;
   int    treeMaxDepth;
   int    ownerDir;
   double ownerEnergy;
   double life;              // hold-vs-abandon score 0-100
   double force;             // compression persistence force
   string forceState;        // PERSISTING/LEAKING/NEUTRAL
   string aliveStatus;
   double budgetTarget;      // ODDE destination
   string budgetSource;
   double budgetATR;
};


//==================================================================
// CAMPAIGN SUB-STATE
//==================================================================
struct FALCON_Campaign
{
   string owner;             // EXPANSION / TERMINAL
   string institution;       // dominant side label
   int    dominantSide;      // 1=bull, -1=bear
   double objective;         // campaign target price
   double remainingEnergy;   // 0-100
   double controlScore;      // 0-100
   int    age;
   string location;          // BUILDING/TRANSITIONING/APPROACHING/INSIDE HTF
   string compRegime;        // WIDE/MEDIUM/COMPRESSED/FAILURE SWING
   int    expDepth;
   double curveBudget;       // % budget remaining to HTF
   string ownershipState;    // MERGED/TRANSFERRED/etc (Principle 9)
};

//==================================================================
// PARTICIPANTS SUB-STATE
//==================================================================
struct FALCON_Participants
{
   double buyer;             // buyer participation 0-100
   double seller;            // seller participation 0-100
   double passive;           // passive flow 0-100
   double aggressive;        // aggressive flow 0-100
   double interference;      // 0-100
   double participationScore;
   double marketPressure;    // -100..+100
   // Fib interference zones
   double fib618;
   double fib70;
   double fib786;
   double flipLevel;
   double retrAbs;           // current retrace fraction
   string zone;              // participant zone label
   string interferenceState;
   bool   displacing;
};

//==================================================================
// MTF CURVE MAP RUNG
//==================================================================
struct FALCON_MapRung
{
   int    direction;
   double origin;
   double extreme;
   double progress;
   double retrace;
   string phase;
   string relation;          // align/counter
};


//==================================================================
// ENERGY RESOLUTION FRAMEWORK SUB-STATE
//==================================================================
struct FALCON_ERF
{
   FALCON_EDEState edeState;
   double expansionEnergy;
   double dissipatedEnergy;
   double dissipationProgress;
   double residualEnergy;
   FALCON_Resolution resolutionState;
   double recursiveCompletion;
   double primaryAttractorPrice;
   double primaryAttractorScore;
   double tradeReadiness;
   bool   entryGateOpen;
   double confidence;
};

//==================================================================
// NARRATIVE LINEAGE SUB-STATE
//==================================================================
struct FALCON_Lineage
{
   int    ownerDir;
   double narrative;         // 0-100
   string state;             // STRENGTHENING/HOLDING/WEAKENING
   string lastVote;
   int    supportVotes;
   int    degradeVotes;
   bool   converging;
   double chainVitality;
   double wholeChainLife;
};

//==================================================================
// LIQUIDATION WAVE SUB-STATE (Engine 1A.7)
//==================================================================
struct FALCON_LiqWave
{
   bool   active;
   bool   isRetracement;
   int    direction;
   double target;
   double distPct;           // distance remaining 0-100
   bool   objArrival;
   bool   trueCHoCH;
   string subPhase;
   string title;
   bool   absorbUnlocked;
};


//==================================================================
// INTELLIGENCE SUB-STATE (reasoning + decision)
//==================================================================
struct FALCON_Intelligence
{
   // Beliefs (6 simultaneous, EMA smoothed)
   double beliefExpansion;
   double beliefConvexity;
   double beliefCreation;
   double beliefAbsorption;
   double beliefRetracement;
   double beliefDemandReturn;
   // Hypothesis
   string primaryHypothesis;
   double hypothesisConf;
   // Prediction
   string expectedNextPhase;
   double expectedNextProb;
   // Validation
   double predReliability;
   double modelConfidence;
   // Direction probability (Bayesian)
   double buyProb;
   double sellProb;
   double netEdge;
   string liveDirective;
   // Senseei strategic
   int    masterBias;
   double alignment;
   double conflict;
   double confidence;
   double threat;
   double opportunityScore;
   string intent;
   string timing;
   string opportunity;
   string story;             // narrative
   string actionNarrative;
   // FINAL DECISION (only the 8 verdicts)
   FALCON_Decision decision;
   // Execution probability outcomes
   double pContinuation;
   double pReversal;
   double pExpansion;
   double pCreation;
   double pAbsorption;
   double pStandDown;
   string execDirective;
};


//==================================================================
// EXECUTION SUB-STATE
//==================================================================
struct FALCON_Execution
{
   double entry;
   double stop;
   double target;
   double target2;
   double lotSize;
   int    positionCount;
   int    longCount;
   int    shortCount;
   double risk;              // risk per trade ($)
   double reward;            // R:R
   string tradeState;        // FLAT/LONG/SHORT/MIXED
   string exitState;
   double floatingPnl;
   bool   engineArmed;
   int    lockBars;
   // Risk engine (DRDWCT)
   double var2;
   double var3;
   double udsMax;
   bool   varBreach;
   bool   anyBomb;
   int    trimCount;
   double equity;
};

//==================================================================
// DIAGNOSTICS SUB-STATE (kernel health + timing)
//==================================================================
struct FALCON_Diagnostics
{
   long   pipelineMicros;    // last pipeline duration
   long   moduleMicros[8];   // per-module timing
   int    eventsPublished;
   int    eventsHandled;
   int    barsProcessed;
   bool   marketHealthy;
   bool   memoryHealthy;
   bool   intelHealthy;
   bool   execHealthy;
   string lastError;
   datetime lastBarTime;
};


//==================================================================
// MASTER MARKET STATE — THE SINGLE SOURCE OF TRUTH
// Every module reads from and writes to this one object only.
//==================================================================
struct FALCON_MarketState
{
   // --- Market Layer ---
   FALCON_Physics      physics;
   FALCON_Structure    structure;
   FALCON_Liquidity    liquidity;
   FALCON_Wave         wave;
   FALCON_HTF          htf;
   FALCON_FU           fu;
   FALCON_TFStructure  tf[L_TFCOUNT];   // 6-TF fractal stack

   // --- Memory Layer ---
   FALCON_Network      network;
   FALCON_Curve        curve;
   FALCON_Campaign     campaign;
   FALCON_Participants participants;
   FALCON_MapRung      curveMap[7];     // MTF curve map (M1..H4)
   FALCON_Lineage      lineage;

   // --- Framework / Resolution ---
   FALCON_ERF          erf;
   FALCON_LiqWave      liqWave;

   // --- Intelligence / Decision ---
   FALCON_Intelligence intel;

   // --- Execution ---
   FALCON_Execution    exec;

   // --- Kernel / Diagnostics ---
   FALCON_Diagnostics  diag;

   // --- Bar context (shared OHLC snapshot for current closed bar) ---
   double   barOpen;
   double   barHigh;
   double   barLow;
   double   barClose;
   datetime barTime;
   int      barsAvailable;
};

// THE global shared state — referenced everywhere as gState
FALCON_MarketState gState;

//==================================================================
// STATE RESET (called on kernel boot)
//==================================================================
void FALCON_ResetState()
{
   ZeroMemory(gState);
   gState.wave.completion = 30.0;
   gState.intel.modelConfidence = 50.0;
   gState.intel.decision = DEC_NO_TRADE;
   gState.exec.engineArmed = true;
   gState.curve.life = 50.0;
   gState.curve.force = 50.0;
   gState.lineage.narrative = 50.0;
   gState.lineage.wholeChainLife = 50.0;
   gState.diag.marketHealthy = true;
   gState.diag.memoryHealthy = true;
   gState.diag.intelHealthy = true;
   gState.diag.execHealthy = true;
}

//--- Decision verdict to string
string FALCON_DecisionStr(FALCON_Decision d)
{
   switch(d)
   {
      case DEC_BUY:    return("BUY");
      case DEC_SELL:   return("SELL");
      case DEC_WAIT:   return("WAIT");
      case DEC_ATTACK: return("ATTACK");
      case DEC_DEFEND: return("DEFEND");
      case DEC_EXIT:   return("EXIT");
      case DEC_SCALE:  return("SCALE");
      default:         return("NO TRADE");
   }
}

//--- Phase to string
string FALCON_PhaseStr(FALCON_WavePhase p)
{
   switch(p)
   {
      case WP_POINT4_ORIGIN:     return("Point 4 Origin");
      case WP_EXPANSION:         return("Expansion");
      case WP_EXP_PRECONVEXITY:  return("Expansion Pre-Convexity");
      case WP_EXP_INDUCTION:     return("Expansion Induction");
      case WP_EXP_LIQUIDITY:     return("Expansion Liquidity");
      case WP_NEW_HIGH:          return("New High");
      case WP_NEW_LOW:           return("New Low");
      case WP_ABSORPTION:        return("Absorption");
      case WP_RETRACEMENT:       return("Retracement");
      case WP_RETR_PRECONVEXITY: return("Retracement Pre-Convexity");
      case WP_RETR_INDUCTION:    return("Retracement Induction");
      case WP_RETR_LIQUIDITY:    return("Retracement Liquidity");
      case WP_DEMAND_RETURN:     return("Demand Return");
      case WP_SUPPLY_RETURN:     return("Supply Return");
      default:                   return("Unknown");
   }
}

//+------------------------------------------------------------------+
