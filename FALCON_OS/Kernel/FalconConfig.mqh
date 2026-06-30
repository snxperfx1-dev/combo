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
input bool    InpEntryAtZone     = true;  // FREE-RUN too: only enter when price is AT a real zone (demand=buys / supply=sells) — stops random-location entries
input bool    InpEntryNeedRoom   = true;  // FREE-RUN too: require curve ROOM (capacity left, not late/exhausted on the owner leg) before entering
input bool    InpOneEntryPerDir   = true;  // Only ONE entry per direction at a time — no pyramiding the same move (stops the terrible follow-up after a good entry)
input int     InpReentryCooldown  = 4;     // Bars to wait after ANY entry before another can fire (anti rapid-fire follow-ups); 0=off
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

input string  __sep_bands      = "════════ TRADE COMPOSITION / RANGE BANDS ════════"; // ──
input int     InpStopPivotLen     = 3;    // Pivot length for the STRUCTURAL stop swing (small = tighter, recent structure)
input int     InpStopLookback     = 25;   // Max bars back to find the structural-stop swing (short = tight stops)
input double  InpMaxStructStopATR = 2.5;  // Skip entries whose structural stop is WIDER than this (ATR); 0=off
input double  InpBandWideATR       = 2.0; // Stop distance (ATR) at/above which a trade is WIDE-range (gets partial + BE management)
input double  InpBandPartialR      = 1.5; // WIDE trades: bank a partial and move stop to BE at this R
input double  InpBandPartialFrac   = 0.5; // Fraction of a WIDE trade banked at BandPartialR (0=just move to BE)

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
   bool   entryAtZone, entryNeedRoom;
   bool   oneEntryPerDir;  int reentryCooldown;
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
   double maxStructStopATR, bandWideATR, bandPartialR, bandPartialFrac;
   int    stopPivotLen, stopLookback;
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
   g_cfg.entryAtZone      = InpEntryAtZone;
   g_cfg.entryNeedRoom    = InpEntryNeedRoom;
   g_cfg.oneEntryPerDir   = InpOneEntryPerDir;
   g_cfg.reentryCooldown  = InpReentryCooldown;
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
   g_cfg.maxStructStopATR = InpMaxStructStopATR;
   g_cfg.stopPivotLen     = InpStopPivotLen;
   g_cfg.stopLookback     = InpStopLookback;
   g_cfg.bandWideATR      = InpBandWideATR;
   g_cfg.bandPartialR     = InpBandPartialR;
   g_cfg.bandPartialFrac  = InpBandPartialFrac;
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
