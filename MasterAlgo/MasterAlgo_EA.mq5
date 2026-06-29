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
#property copyright "Master Algo v2.0"
#property link      ""
#property version   "2.00"
#property description "Unified Engine: Symphony + Letra 37 + F16 Raptor (FULL)"
#property description "Entry: P3/P4 curvature + Demand/Supply Return lifecycle"
#property description "Exit: ARC convexity + Institutional sweep + Phase transition"
#property description "Intelligence: 6-TF structure + ERF + Senseei + Curve Tree"
#property description "  + FU Blocks + Network Nodes + Liq Wave + Campaign + Lineage"
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
#include "Part9_FUOrderBlockEngine.mqh"
#include "Part10_NetworkNodeEngine.mqh"
#include "Part11_LiquidationWaveRegistry.mqh"
#include "Part12_CampaignCurveMapLineage.mqh"
#include "Part13_VisualSystems.mqh"

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
   Print("  MASTER ALGO v2.0 - FULL INTEGRATION");
   Print("  Symphony + Letra 37 + F16 Raptor");
   Print("  Symbol: ", _Symbol, " | TF: ", EnumToString(_Period));
   Print("  Magic: ", InpMagic, " | Risk: ", InpRiskPercent, "%");
   Print("  Engines: 6-TF Structure + Physics + ERF");
   Print("    + Beliefs + Senseei + Curve Tree");
   Print("    + FU Order Blocks + Network Nodes (250)");
   Print("    + Liquidation Wave + Energy Registry");
   Print("    + Campaign + Participants + MTF Map");
   Print("    + Narrative Lineage + Visual Systems");
   Print("  Entries: P3/P4 + Demand/Supply Return");
   Print("  Exits: ARC + Institutional + Phase Trans");
   Print("  Visuals: Arcs/Zones/FEZ/Fibs/Budget/Web");
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
   CleanupVisualObjects();
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
   
   //--- 5. FU ORDER BLOCK ENGINE (zone detection + MTF pools + AFE)
   //    Produces: g_fuBlocks[], g_fuWick, g_fuPool*, g_afe, g_convConfidence
   UpdateFUEngine();
   
   //--- 6. NETWORK NODE ENGINE (250-node registry + FEZ corridor)
   //    Produces: g_nodes[], g_netBias, g_netPressure, g_fezHigh/Low, paths
   UpdateNetworkEngine();
   
   //--- 7. LIQUIDATION WAVE + ENERGY REGISTRY
   //    Produces: g_liqWave (sub-phases, arrival), g_energyRegistry[]
   //    Integration: suppress/boost reversal, spawn events on wave/cycle
   UpdateLiqWaveAndRegistry();
   
   //--- 8. SENSEEI + CURVE + NETWORK (strategic intelligence layer)
   //    Produces: g_curve, curve tree/life, g_timeIntel, g_senseei,
   //             narrative (reads all prior engines)
   UpdateSenseeiCurveNetwork();
   
   //--- 9. CAMPAIGN + MTF MAP + LINEAGE (strategic context layer)
   //    Produces: g_campaign, g_participants, g_curveMap[], g_lineage,
   //             g_curveBudgetTarget, g_ownerMerge
   UpdateCampaignMapLineage();
   
   //--- 10. EXECUTION (entries + exits + trailing)
   //    Reads all engines; fires Symphony P3/P4 + Letra DR/SR entries;
   //    manages ARC/institutional/structural exits + trailing stops
   UpdateExecution();
   
   //--- 11. DASHBOARD (render all intelligence to chart comment)
   UpdateDashboard();
   
   //--- 12. VISUAL SYSTEMS (chart objects: arcs, zones, web, FEZ, fibs, etc.)
   UpdateVisualSystems();
}

//+------------------------------------------------------------------+
