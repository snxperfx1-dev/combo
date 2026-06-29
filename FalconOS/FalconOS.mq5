//+------------------------------------------------------------------+
//| FalconOS.mq5                                                      |
//| FALCON OS - Unified Trading Intelligence Platform                 |
//|                                                                   |
//| A modular trading operating system merging LETRA 37 (market       |
//| intelligence), F16/Senseei (strategic intelligence) and Symphony  |
//| (execution & risk) into one shared-state, event-driven,           |
//| deterministic-pipeline architecture.                              |
//|                                                                   |
//| KERNEL:  Shared State, Event Bus, Scheduler, Config, Logger,      |
//|          Persistence                                              |
//| MODULES: 1 Core Market | 2 Memory | 3 Intelligence+Decision |     |
//|          4 Execution(+Risk) | 5 Visualization                     |
//|                                                                   |
//| Single source of truth: gState. Every bar runs ONE pipeline.      |
//+------------------------------------------------------------------+
#property copyright "FALCON OS"
#property version   "1.00"
#property description "Unified Trading OS - LETRA + F16 + Symphony"
#property description "Kernel + 6 modules, shared state, deterministic pipeline"
#property strict

//==================================================================
// INCLUDE ORDER (dependencies first)
//   State -> Config -> Logger -> EventBus -> Persistence
//   -> Modules (M1..M5) -> Scheduler (calls module fns)
//==================================================================
#include "Kernel/FALCON_State.mqh"
#include "Kernel/FALCON_Config.mqh"
#include "Kernel/FALCON_Logger.mqh"
#include "Kernel/FALCON_EventBus.mqh"
#include "Modules/FALCON_M1_CoreMarket.mqh"
#include "Modules/FALCON_M2_Memory.mqh"
#include "Kernel/FALCON_Persistence.mqh"
#include "Modules/FALCON_M3_Intelligence.mqh"
#include "Modules/FALCON_M4_Execution.mqh"
#include "Modules/FALCON_M5_Visualization.mqh"
#include "Kernel/FALCON_Scheduler.mqh"


//==================================================================
// NEW-BAR DETECTION
//==================================================================
datetime g_falconLastBar = 0;
bool FALCON_IsNewBar()
{
   datetime t[];
   ArraySetAsSeries(t,true);
   if(CopyTime(_Symbol,_Period,0,1,t)<1) return(false);
   if(t[0]!=g_falconLastBar){ g_falconLastBar=t[0]; return(true); }
   return(false);
}

//==================================================================
// EVENT SUBSCRIBERS (event-driven hooks - extensibility points)
// Modules can react to events without modifying the pipeline.
//==================================================================
void OnRiskBreachHandler()
{
   FALCON_Log(LOG_WARN,"Kernel","Risk breach event handled");
}
void OnEntryFiredHandler()
{
   FALCON_Log(LOG_INFO,"Kernel","Entry fired - persisting state");
   FALCON_SaveNetworkMemory();
}
void OnDecisionHandler()
{
   if(FALCON_VerboseLogging())
      FALCON_Log(LOG_DEBUG,"Kernel","Decision: "+FALCON_DecisionStr(gState.intel.decision));
}

//==================================================================
// KERNEL BOOT
//==================================================================
bool FALCON_Boot()
{
   FALCON_ResetState();
   FALCON_ResetEventBus();

   // wire event subscribers (publish/subscribe wiring)
   FALCON_Subscribe(EVT_RISK_BREACH,  OnRiskBreachHandler, "RiskBreachLog");
   FALCON_Subscribe(EVT_ENTRY_FIRED,  OnEntryFiredHandler, "PersistOnEntry");
   FALCON_Subscribe(EVT_DECISION_MADE,OnDecisionHandler,   "DecisionLog");

   // init core market (creates handles + per-TF ATR)
   M1_Init();

   // verify data
   if(!M1_RefreshSeries())
   {
      FALCON_Log(LOG_ERROR,"Kernel","Boot failed - cannot load series");
      return(false);
   }
   return(true);
}

//==================================================================
// STANDARD MQL5 CALLBACKS
//==================================================================
int OnInit()
{
   if(!FALCON_Boot())
      return(INIT_FAILED);

   Print("==================================================");
   Print("  FALCON OS v1.0 - ONLINE");
   Print("  Profile: ", FALCON_ProfileName());
   Print("  Symbol: ", _Symbol, " | TF: ", EnumToString(_Period));
   Print("  Magic: ", CfgMagic, " | Risk: ", CfgRiskPercent, "%");
   Print("  Kernel: State+EventBus+Scheduler+Config");
   Print("          +Logger+Persistence");
   Print("  Modules: CoreMarket | Memory | Intelligence");
   Print("           | Execution(+DRDWCT Risk) | Visualization");
   Print("  Pipeline: 21-stage deterministic, single MarketState");
   Print("==================================================");
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   FALCON_SaveNetworkMemory();
   M5_CleanupObjects();
   Comment("");
   Print("FALCON OS: shutdown (reason=", reason, ")");
}

void OnTick()
{
   // Refresh series every tick (cheap), gate heavy pipeline to new bars
   if(!M1_RefreshSeries())
      return;

   if(!FALCON_IsNewBar())
   {
      // light refresh: only the live dashboard for responsiveness
      M5_Visualize();
      return;
   }

   // ONE deterministic pipeline per new candle (kernel scheduler)
   FALCON_RunPipeline();
}
//+------------------------------------------------------------------+
