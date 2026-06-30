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
#property copyright "FALCON OS"
#property version   "1.00"
#property strict

//==================================================================
// KERNEL
//==================================================================
#include "Kernel/FalconState.mqh"
#include "Kernel/FalconConfig.mqh"
#include "Kernel/FalconSeries.mqh"
#include "Kernel/FalconEventBus.mqh"
#include "Kernel/FalconLog.mqh"
#include "Kernel/FalconPersistence.mqh"

//==================================================================
// ENGINES (layers)
//==================================================================
#include "Engines/MarketEngine.mqh"        // Market Layer
#include "Engines/MemoryEngine.mqh"        // Intelligence Layer — memory
#include "Engines/CurveTree.mqh"           // Intelligence Layer — F72 recursive event-driven curve tree (curves inside curves)
#include "Engines/TimeEngine.mqh"          // Intelligence Layer — TIE (Engine 8.0) 5-cycle temporal stack
#include "Engines/CurveLocator.mqh"        // Intelligence Layer — always-on multi-TF curve position
#include "Engines/WaveCycleIntel.mqh"      // Intelligence Layer — comparative multi-engine wave cycles (LETRA/F16) + referee
#include "Engines/IntelligenceEngine.mqh"  // Intelligence Layer — reasoning
#include "Engines/DecisionEngine.mqh"      // Decision Layer
#include "Engines/ExecutionEngine.mqh"     // Execution Layer
#include "Engines/ThermalRiskEngine.mqh"   // Execution Layer — PYRO campaign-thermodynamics risk (after EE, before Symphony)
#include "Engines/MoneyManager.mqh"        // Execution Layer — Symphony v3.0 money mgmt (counter-dir lock / ladder / basket ceiling)
#include "Engines/TradePlan.mqh"           // Decision/Execution — subsystem-composed trade plan (stop/target/size each owned by an engine)
#include "Engines/TradeJournal.mqh"        // Diagnostics — per-trade CSV journal (before Symphony so entries can record)
#include "Engines/Adaptive.mqh"            // Intelligence — self-learning feedback (size/veto from own results)
#include "Engines/SelfAwareness.mqh"       // Intelligence — metacognition (self form/calibration/health -> throttle)
#include "Engines/MissTrade.mqh"           // Intelligence — counterfactual / regret learning (take trades it used to miss)
#include "Engines/SymphonyEngine.mqh"      // Execution Layer — Symphony phase entries/exits (after EE helpers)
#include "Engines/Planner.mqh"             // Trade Planning Layer (FALCON OS 9.0) — assembles & executes TradePlan objects
#include "Engines/Visualization.mqh"       // Visualization Layer

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

   // TRADE PLANNING LAYER — assemble persistent plans from every engine, then
   // execute the highest-priority ready one (Symphony's own entries yield when
   // usePlanner is on; SymphonyTradeManage still runs exits/management above).
   if(g_cfg.usePlanner)
   {
      PlannerRun();
      PlannerExecute();
   }
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
   PlannerInit();
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
