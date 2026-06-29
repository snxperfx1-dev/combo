//+------------------------------------------------------------------+
//| MasterAlgo_EA.mq5                                                 |
//| MASTER ALGO - Unified MT5 Expert Advisor                          |
//| Combines: Symphony (entry/stop/ARC) + Letra 37 (multi-TF/ERF/    |
//| beliefs/recursive waves) + F16 (Senseei/Curve/Time/Network)       |
//|                                                                   |
//| Architecture:                                                     |
//|   Part 1: Core Infrastructure (buffers, inputs, helpers)          |
//|   Part 2: Multi-TF Structure Engine (6 fixed-TF engines)          |
//|   Part 3: Physics & Wave Phase Engine (obs/similarity/liquidity)  |
//|   Part 4: ERF + Belief Intelligence (EDE/RE/EAE/beliefs/hyp)      |
//|   Part 5: Entry/Exit Execution (Symphony P3/P4 + Letra DR/SR)     |
//|   Part 6: Senseei + Curve + Network (F72/tree/time/verdict)       |
//|   Part 7: Dashboard Panel (Comment-based HUD)                     |
//|   Part 8: THIS FILE - OnInit/OnTick orchestrator                  |
//+------------------------------------------------------------------+
#property copyright "Master Algo v1.0"
#property link      ""
#property version   "1.00"
#property description "Unified Engine: Symphony + Letra 37 + F16 Raptor"
#property description "Entry: P3/P4 curvature + Demand/Supply Return lifecycle"
#property description "Exit: ARC convexity + Institutional sweep + Phase transition"
#property description "Intelligence: 6-TF structure + ERF + Senseei + Curve Tree"
#property strict

//==================================================================
// INCLUDE ALL PARTS
//==================================================================
#include "Part1_CoreInfrastructure.mqh"
#include "Part2_MultiTFStructureEngine.mqh"
#include "Part3_PhysicsWavePhaseEngine.mqh"
#include "Part4_ERFBeliefIntelligence.mqh"
#include "Part5_EntryExitExecution.mqh"
#include "Part6_SenseeiCurveNetwork.mqh"
#include "Part7_DashboardPanel.mqh"

//==================================================================
// OnInit - Initialization
//==================================================================
int OnInit()
{
   // Initialize all global state
   InitGlobalState();
   
   // Initialize structure engines (creates ATR handles per TF)
   InitStructureEngines();
   
   // Initialize liquidity heatmap arrays
   InitLiquidityEngine();
   
   // Initialize validation engine
   InitValidationEngine();
   
   // Verify we can load data
   if(!RefreshSeries())
   {
      Print("MASTER ALGO: Failed to load chart series data");
      return(INIT_FAILED);
   }
   
   // Verify ATR handle
   if(g_handleATR == INVALID_HANDLE)
   {
      g_handleATR = iATR(_Symbol, _Period, InpATRLen);
      if(g_handleATR == INVALID_HANDLE)
      {
         Print("MASTER ALGO: Failed to create main ATR handle");
         return(INIT_FAILED);
      }
   }
   
   Print("============================================");
   Print("  MASTER ALGO v1.0 - LOADED");
   Print("  Symphony + Letra 37 + F16 Raptor");
   Print("  Symbol: ", _Symbol, " | TF: ", EnumToString(_Period));
   Print("  Magic: ", InpMagic, " | Risk: ", InpRiskPercent, "%");
   Print("  Engines: 6-TF Structure + Physics + ERF");
   Print("           + Beliefs + Senseei + Curve Tree");
   Print("  Entries: P3/P4 + Demand/Supply Return");
   Print("  Exits: ARC + Institutional + Phase Trans");
   Print("============================================");
   
   return(INIT_SUCCEEDED);
}

//==================================================================
// OnDeinit - Cleanup
//==================================================================
void OnDeinit(const int reason)
{
   // Clean up chart objects
   CleanupChartObjects();
   Comment("");
   
   Print("MASTER ALGO: Deinit reason=", reason);
}

//==================================================================
// OnTick - Main Processing Loop
//==================================================================
void OnTick()
{
   //--- 0. Refresh chart series data
   if(!RefreshSeries())
      return;
   
   //--- Only process on new bar (bar-close logic)
   if(!IsNewBar())
   {
      // Still update dashboard on every tick for live display
      UpdateDashboard();
      return;
   }
   
   //==========================================================
   // NEW BAR PROCESSING PIPELINE
   // Order matters: each engine consumes outputs from prior
   //==========================================================
   
   //--- 1. MULTI-TF STRUCTURE (foundation - runs all 6 TF engines)
   //    Produces: g_structure[], g_fractalStack, g_direction,
   //             g_flipTop/Bot, g_point4High/Low, g_currentPhase
   UpdateMultiTFStructure();
   
   //--- 2. PHYSICS ENGINE (chart-TF physics + observation scores)
   //    Produces: g_physics, g_obs, similarities, convexity maturity,
   //             wave progress, model fit, liquidity heatmap, Symphony phases
   UpdatePhysicsEngine();
   
   //--- 3. ENERGY RESOLUTION FRAMEWORK
   //    Produces: g_erf (EDE state, resolution, attractor, trade readiness, gate)
   UpdateERF();
   
   //--- 4. BELIEF INTELLIGENCE
   //    Produces: g_beliefs, hypothesis, prediction, validation,
   //             model confidence, direction probability, exec prob
   UpdateBeliefIntelligence();
   
   //--- 5. SENSEEI + CURVE + NETWORK (strategic intelligence layer)
   //    Produces: g_curve, curve tree/life, g_timeIntel, g_senseei,
   //             narrative (reads all prior engines)
   UpdateSenseeiCurveNetwork();
   
   //--- 6. EXECUTION (entries + exits + trailing)
   //    Reads all engines; fires Symphony P3/P4 + Letra DR/SR entries;
   //    manages ARC/institutional/structural exits + trailing stops
   UpdateExecution();
   
   //--- 7. DASHBOARD (render all intelligence to chart)
   UpdateDashboard();
}

//+------------------------------------------------------------------+
