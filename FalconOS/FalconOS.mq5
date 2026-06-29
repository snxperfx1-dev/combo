//+------------------------------------------------------------------+
//|                                                     FALCON OS    |
//|        Unified Trading Intelligence Platform (MT5 Expert)        |
//|                                                                  |
//|  A single modular trading operating system that merges:          |
//|    • LETRA 37  — Market Intelligence                             |
//|    • F16 Raptor/Senseei — Strategic Intelligence                 |
//|    • Symphony  — Execution & Risk                                |
//|                                                                  |
//|  Architecture (see README.md):                                   |
//|    KERNEL: shared state · event bus · scheduler · config · log   |
//|      ├── Core Market Engine    (observes)                        |
//|      ├── Memory Engine         (remembers)                       |
//|      ├── Intelligence Engine   (reasons)                         |
//|      ├── Decision Engine       (decides)                         |
//|      ├── Execution Engine      (executes)                        |
//|      └── Visualization Engine  (displays)                        |
//|                                                                  |
//|  Every bar runs ONE deterministic pipeline. Every calculation    |
//|  exists exactly once. Every module consumes the shared state.    |
//+------------------------------------------------------------------+
#property strict
#property version   "1.00"
#property description "FALCON OS — unified market/strategic/execution OS"

#include "Include/Falcon/Kernel.mqh"
#include "Include/Falcon/CoreMarket.mqh"
#include "Include/Falcon/Memory.mqh"
#include "Include/Falcon/Intelligence.mqh"
#include "Include/Falcon/Execution.mqh"
#include "Include/Falcon/Visualization.mqh"

//==================================================================
// INPUTS  (Configuration Service — centralised, profile-aware)
//==================================================================
input string  InpSep1  = "──────── SYSTEM ────────";
input FAL_PROFILE InpProfile      = PROFILE_LIVE;     // Profile
input bool    InpTradeEnabled     = true;             // Enable live order execution
input bool    InpShowDashboard    = true;             // Show unified dashboard
input FAL_TAB InpTab              = TAB_ALL;          // Dashboard tab

input string  InpSep2  = "──────── CORE ENGINE ────────";
input int     InpPivotLen         = 5;
input int     InpStructLen        = 10;
input int     InpAtrLen           = 14;
input int     InpEffLen           = 10;
input double  InpEffThresh        = 0.65;
input double  InpDispThresh       = 1.5;
input double  InpConvMult         = 0.01;
input double  InpImpulseAtrMult   = 1.5;
input double  InpChochBufferATR   = 0.75;
input bool    InpStrictStructure  = true;
input int     InpInducLookback    = 80;
input double  InpInducZoneWidth   = 0.25;
input int     InpLiqSweepLookback = 10;
input double  InpLiqRadius        = 0.25;
input double  InpLiqAgeDecay      = 0.95;
input bool    InpRequireLiqSweep  = true;
input int     InpResetBars        = 20;
input int     InpBeliefSmooth     = 3;

input string  InpSep3  = "──────── NETWORK ────────";
input double  InpFuWickFrac       = 0.30;
input int     InpFuLookback       = 3;
input int     InpNodeAuthMin      = 45;
input int     InpNodeMax          = 250;
input int     InpDormantBars      = 120;
input int     InpHistoryBars      = 600;

input string  InpSep4  = "──────── DECISION / RISK ────────";
input int     InpMinConfidence    = 55;
input double  InpRiskPercent      = 0.5;
input bool    InpEnableRiskEngine = true;
input bool    InpBlockNewIfBreach = true;
input double  InpRRMinimum        = 1.5;
input long    InpMagic            = 240220;
input int     InpTargetGMT        = 0;

//==================================================================
// CONFIG BUILDER
//==================================================================
void FAL_BuildConfig()
  {
   g_cfg.profile=InpProfile;
   g_cfg.pivotLen=InpPivotLen; g_cfg.structLen=InpStructLen; g_cfg.atrLen=InpAtrLen; g_cfg.effLen=InpEffLen;
   g_cfg.effThresh=InpEffThresh; g_cfg.dispThresh=InpDispThresh; g_cfg.convMult=InpConvMult;
   g_cfg.impulseAtrMult=InpImpulseAtrMult; g_cfg.chochBufferATR=InpChochBufferATR;
   g_cfg.useStrictStructure=InpStrictStructure; g_cfg.inducLookback=InpInducLookback;
   g_cfg.inducZoneWidth=InpInducZoneWidth; g_cfg.liqSweepLookback=InpLiqSweepLookback;
   g_cfg.liqRadius=InpLiqRadius; g_cfg.liqAgDecay=InpLiqAgeDecay; g_cfg.requireLiqSweep=InpRequireLiqSweep;
   g_cfg.resetBars=InpResetBars; g_cfg.beliefSmooth=InpBeliefSmooth;
   g_cfg.fuWickFrac=InpFuWickFrac; g_cfg.fuLookback=InpFuLookback; g_cfg.nodeAuthMin=InpNodeAuthMin;
   g_cfg.nodeMax=InpNodeMax; g_cfg.dormantBars=InpDormantBars; g_cfg.historyBars=InpHistoryBars;
   g_cfg.minConfidence=InpMinConfidence; g_cfg.riskPercent=InpRiskPercent;
   g_cfg.enableRiskEngine=InpEnableRiskEngine; g_cfg.blockNewIfBreach=InpBlockNewIfBreach;
   g_cfg.rrMinimum=InpRRMinimum; g_cfg.magic=InpMagic; g_cfg.targetGMT=InpTargetGMT;
   g_cfg.showDashboard=InpShowDashboard;
   // research profile narrates verbosely; backtest disables nothing structurally
   g_cfg.tradeEnabled = InpTradeEnabled && (g_cfg.profile!=PROFILE_RESEARCH);
  }

//==================================================================
// SCHEDULER — the single deterministic master pipeline.
// Order is fixed and dependency-correct; nothing calculates twice.
//==================================================================
void FAL_Pipeline()
  {
   ulong t0=GetMicrosecondCount();
   FAL_BusReset();
   g_state.barTime=iTime(_Symbol,_Period,0);

   //  New Candle
   //   -> Physics / Structure / Fractal stack / FU / HTF  (Core observes)
   CM_StepStructure();
   //   -> Engine 1A phase (Intelligence — lifecycle authority)
   INTEL_Phase();
   //   -> Wave-spawn (current flip zone / point4 / recursion)
   INTEL_WaveSpawn(g_state.wave);
   //   -> Liquidity (now the flip zone is current)
   CM_StepLiquidity();
   //   -> ERF energy framework (needs phase + wave)
   INTEL_ERF(g_state.erf);
   //   -> Wave intelligence: similarity / beliefs / progress / bayesian
   INTEL_WaveIntel(g_state.wave);
   //   -> Memory: invisible network + recursive curve tree (needs ERF/FU)
   MEM_RunEarly();
   //   -> Campaign + participants (needs phase + curve + network)
   MEM_RunCampaign();
   //   -> Senseei meta-intelligence (alignment/threat/opportunity/intent)
   INTEL_Senseei(g_state.intel);
   //   -> Decision Engine (master decision + targets)
   DEC_Decide(g_state.intel);
   //   -> Execution Engine (risk + manage + open; never decides)
   EXE_Run();
   //   -> Visualization Engine (one unified interface)
   VIS_Run(InpTab);

   g_diag.pipelineMicros=GetMicrosecondCount()-t0;
   g_diag.barsProcessed++;
   g_diag.lastBar=g_state.barTime;
   g_diag.healthy=true;
  }

//==================================================================
// MT5 EVENT HANDLERS
//==================================================================
int OnInit()
  {
   FAL_BuildConfig();
   FAL_KernelInit();
   CM_Init();
   MEM_Init();
   INTEL_Init();
   EXE_Init();
   FAL_SetModuleStatus(5,"ok");
   FAL_LogAlways("FALCON","FALCON OS online — kernel + 6 engines loaded. Magic="+IntegerToString((int)g_cfg.magic));
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   Comment("");
   FAL_LogAlways("FALCON","FALCON OS shutdown (reason "+IntegerToString(reason)+").");
  }

datetime g_chartBar=0;
void OnTick()
  {
   // Deterministic: the pipeline advances once per NEW chart bar.
   datetime t=iTime(_Symbol,_Period,0);
   if(t==g_chartBar) return;
   g_chartBar=t;

   // ensure enough history before the first pipeline run
   if(Bars(_Symbol,_Period) < 300) return;

   FAL_Pipeline();
  }
//+------------------------------------------------------------------+
