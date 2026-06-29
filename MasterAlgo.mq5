//+------------------------------------------------------------------+
//| MasterAlgo.mq5 - Master MT5 Expert Advisor                      |
//| Symphony Phase Engine + Letra Structure/Energy + F16 Network/   |
//| Senseei/CurveTree - Probabilistic Entry (threshold=90%)         |
//+------------------------------------------------------------------+
#property copyright "Master Algo - Symphony + Letra + F16"
#property version   "1.00"
#property strict
#property description "Master MT5 EA: Symphony Phase Engine + Letra Structure/Energy + F16 Network/Senseei/CurveTree"

#include "Part1_Core.mqh"
#include "Part2_PhaseEngine.mqh"
#include "Part3_LetraEngine.mqh"
#include "Part4_EnergyFramework.mqh"
#include "Part5_Network.mqh"
#include "Part6_CurveTree.mqh"
#include "Part7_Senseei.mqh"
#include "Part8_Execution.mqh"
#include "Part9_Panels.mqh"

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize series buffers
   if(!RefreshSeries()) return(INIT_FAILED);

   // Initialize network engine (EMA50 handle)
   InitNetworkEngine();

   // Initialize panels
   InitPanels();

   // Initialize phase engine state
   ZeroMemory(g_phase);
   ZeroMemory(g_spawn);
   ZeroMemory(g_energy);
   ZeroMemory(g_curve);
   ZeroMemory(g_senseei);
   ZeroMemory(g_energyState);
   g_nodeCount = 0;
   g_curveTreeCount = 0;

   Print("MASTER ALGO loaded: Symphony + Letra + F16 | Probabilistic Entry (threshold=",
         InpEntryProbThreshold, "%)");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   DeinitNetworkEngine();
   DeinitPanels();
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!RefreshSeries()) return;
   if(!IsNewBar()) return;

   // 1. Symphony Phase Engine (entry detection)
   UpdatePhaseEngine();

   // 2. Symphony ARC v2 (exit targets)
   UpdateARC();

   // 3. Letra Multi-TF Structure Engines (6 timeframes)
   UpdateAllLetraEngines();

   // 4. Energy Resolution Framework (EDE + RE + EAE + beliefs)
   UpdateEnergyFramework();

   // 5. Invisible Network + Time Intelligence
   UpdateNetworkAndTimeIntel();

   // 6. F72 Curve Object + Recursive Tree + Campaign
   UpdateCurveTree();

   // 7. Senseei Meta-Intelligence + Entry Probability
   UpdateSenseei();

   // 8. ARC + Institutional + Phase Composite Exits
   ManageArcInstitutionalExits();

   // 9. Position Management (curve-alive + Senseei driven)
   ManagePositions();

   // 10. Execute New Entries (probabilistic gate)
   ExecuteTrading();

   // 11. Update All Dashboard Panels
   UpdatePanels();
}
//+------------------------------------------------------------------+
