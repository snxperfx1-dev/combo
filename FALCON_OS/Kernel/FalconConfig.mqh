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
input double  InpBasketLockATR   = 1.5;   // Lock basket breakeven once favorable excursion >= this (ATR)
input double  InpAcctHeatDDPct   = 15.0;  // Account heat: equity drawdown %% that fully freezes admissions

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
   bool   enableTrading, enableRiskEng, blockIfBreach, sessionFilter;
   double riskPercent, rdLimit, contractValue;
   double maxLots;
   bool   trailEnable, ddProtect;
   double trailStartATR, trailDistATR, maxDrawdownPct, ddFlattenPct;
   double maxEntryComplete, minEntryRoomPct;
   double attentionATR;
   // thermal risk (PYRO)
   bool   useThermalRisk;  int maxStacks;  double maxCampaignLots;
   double heatThrottle, heatFreeze, heatCritical;
   int    maxAvgDownStacks;
   double heatAdverseSpan, basketLockATR, acctHeatDDPct;
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
   g_cfg.enableRiskEng    = InpEnableRiskEng;
   g_cfg.blockIfBreach    = InpBlockIfBreach;
   g_cfg.sessionFilter    = InpSessionFilter;
   g_cfg.riskPercent      = InpRiskPercent;
   g_cfg.maxLots          = InpMaxLots;
   g_cfg.rdLimit          = InpRdLimit;
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
   g_cfg.basketLockATR    = InpBasketLockATR;
   g_cfg.acctHeatDDPct    = InpAcctHeatDDPct;

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
