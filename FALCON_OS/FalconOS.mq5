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
#include "Kernel/FalconConfig.mqh"
#include "Kernel/FalconState.mqh"
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
   CurveTreeRun();      // F72 recursive curve tree — enrich ownership/recursion after memory resolves the owner TF
   TimeEngineRun();     // TIE — 5-cycle temporal stack (session/killzone/time-quality)
   CurveLocatorRun();   // always-on "you are here" on the curve (multi-TF, persistent)
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
