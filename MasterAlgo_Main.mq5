//+------------------------------------------------------------------+
//| MasterAlgo_Main.mq5                                              |
//| Master EA - Main Entry Point                                      |
//| Orchestrates all 5 subsystems: Phase Engine, MTF Structure,      |
//| Intelligence Engines, Execution Engine, and Dashboards            |
//| Version: 1.0                                                      |
//| Copyright 2024 - Master Algorithm                                 |
//+------------------------------------------------------------------+
#property copyright   "Master Algorithm"
#property link        ""
#property version     "1.00"
#property description "Master EA combining Symphony phase engine, F16 intelligence,"
#property description "and Letra 37 MTF structure into unified execution system."
#property strict

//==================================================================
// INCLUDE ALL SUBSYSTEMS (order matters - later parts depend on earlier)
//==================================================================
#include "MasterAlgo_Part1_PhaseEngine.mq5"
#include "MasterAlgo_Part2_MTFStructure.mq5"
#include "MasterAlgo_Part3_Intelligence.mq5"
#include "MasterAlgo_Part4_ExecutionEngine.mq5"
#include "MasterAlgo_Part5_Dashboards.mq5"

//==================================================================
// MASTER EA INPUTS
//==================================================================
input bool   InpAlertOnAttack       = true;   // Alert when Senseei flips to ATTACK
input bool   InpAlertOnCurveDeath   = true;   // Alert when curve life < 33
input bool   InpAlertOnStackFlip    = true;   // Alert when fractal stack dir changes
input bool   InpAlertOnObjArrival   = true;   // Alert on liquidation objective arrival

//==================================================================
// MASTER STATE - ALERT TRACKING
//==================================================================
string g_prevSenseeiAction    = "WAIT";
int    g_prevFractalStackDir  = 0;
bool   g_prevObjArrival       = false;
bool   g_prevCurveDead        = false;

//==================================================================
// CHART OBJECT PREFIX - for clean removal on deinit
//==================================================================
#define MASTER_PREFIX "MASTER_"

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- 1. Initialize series buffers (first call populates arrays)
   if(!RefreshSeries(5000))
   {
      Print("[MASTER] FATAL: RefreshSeries failed on init. Check symbol/timeframe.");
      return(INIT_FAILED);
   }

   //--- 2. Initialize Phase Engine state (Part 1 globals)
   g_prevPivotPrice  = 0.0;
   g_prevPivotShift  = -1;
   g_prevPivotDir    = 0;
   g_mode            = 0;
   g_anchorHigh      = 0.0;
   g_anchorLow       = 0.0;
   g_anchorHighShift = -1;
   g_anchorLowShift  = -1;
   g_phaseShort      = 0;
   g_phaseLong       = 0;
   g_prevPhaseShort  = 0;
   g_prevPhaseLong   = 0;
   g_shortInducPrice = 0.0;
   g_shortInducLow   = 0.0;
   g_shortInducHigh  = 0.0;
   g_longInducPrice  = 0.0;
   g_longInducLow    = 0.0;
   g_longInducHigh   = 0.0;
   g_shortPreConvSeen= false;
   g_longPreConvSeen = false;
   g_arcLong         = 0.0;
   g_arcShort        = 0.0;
   g_longOuterBreachSeen  = false;
   g_shortOuterBreachSeen = false;
   g_lastBarTime     = 0;
   g_lastLongTradeTime  = 0;
   g_lastShortTradeTime = 0;

   //--- 3. Initialize MTF Structure Engine (Part 2)
   SE_InitAll();

   //--- 4. Initialize Intelligence Engines (Part 3)
   Intel_Init();

   //--- 5. Initialize Execution Engine (Part 4)
   Exec_Init();

   //--- 6. Initialize alert tracking
   g_prevSenseeiAction   = "WAIT";
   g_prevFractalStackDir = 0;
   g_prevObjArrival      = false;
   g_prevCurveDead       = false;

   //--- 7. Print startup message
   Print("==========================================================");
   Print("[MASTER] MasterAlgo EA v1.00 Initialized");
   Print("[MASTER] Symbol: ", _Symbol, " | Period: ", EnumToString(_Period));
   Print("[MASTER] Parts loaded: PhaseEngine, MTFStructure, Intelligence, Execution, Dashboards");
   Print("[MASTER] Phase Engine: 4-phase curvature (Symphony base)");
   Print("[MASTER] Structure Engine: 6 TF (M1/M3/M5/M15/H1/H4)");
   Print("[MASTER] Intelligence: Physics+ERF+Beliefs+Hypothesis+Prediction+Senseei+LiqWave");
   Print("[MASTER] Execution: Curve Object/Tree+Campaign+Time Intelligence+Composite Exit");
   Print("[MASTER] Dashboards: 13-section HUD + chart levels");
   Print("[MASTER] Risk: ", DoubleToString(InpRiskPercent, 2), "% | Magic: ", InpMagic);
   Print("==========================================================");

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                    |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- 1. Clean up dashboard chart objects (Part 5)
   Dash_Cleanup();

   //--- 2. Delete any master-level chart objects by prefix
   ObjectsDeleteAll(0, MASTER_PREFIX);

   //--- 3. Print shutdown message
   string reasonStr;
   switch(reason)
   {
      case REASON_REMOVE:     reasonStr = "Removed from chart"; break;
      case REASON_RECOMPILE:  reasonStr = "Recompiled"; break;
      case REASON_CHARTCHANGE:reasonStr = "Symbol/period changed"; break;
      case REASON_CHARTCLOSE: reasonStr = "Chart closed"; break;
      case REASON_PARAMETERS: reasonStr = "Inputs changed"; break;
      case REASON_ACCOUNT:    reasonStr = "Account changed"; break;
      case REASON_TEMPLATE:   reasonStr = "Template applied"; break;
      default:                reasonStr = "Other (" + IntegerToString(reason) + ")"; break;
   }

   Print("==========================================================");
   Print("[MASTER] MasterAlgo EA Shutting Down");
   Print("[MASTER] Reason: ", reasonStr);
   Print("[MASTER] Final state - Phase L:", g_phaseLong, " S:", g_phaseShort,
         " | Stack:", g_fractalStackDir,
         " | Action:", g_senseei_action,
         " | Life:", DoubleToString(g_curveLifeScore, 1));
   Print("==========================================================");
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   //=================================================================
   // STEP 1: Refresh series data (Close[], High[], Low[], Time[])
   //=================================================================
   if(!RefreshSeries())
      return;

   //=================================================================
   // STEP 2: New bar guard - only process on new bars
   //=================================================================
   if(!IsNewBar())
      return;

   //=================================================================
   // STEP 3: Phase Engine (Part 1) - provides g_phaseLong, g_phaseShort
   //=================================================================
   UpdatePhaseEngine();

   //=================================================================
   // STEP 4: ARC v2 (Part 1) - provides g_arcLong, g_arcShort
   //=================================================================
   UpdateARC();

   //=================================================================
   // STEPS 5-6: MTF Structure Engines + Fractal Stack (Part 2)
   // SE_UpdateAll() runs f_se_compute on all 6 TFs and then calls
   // SE_UpdateFractalStack() internally for direction consensus.
   //=================================================================
   SE_UpdateAll();

   //=================================================================
   // STEPS 7-15: Intelligence Engines (Part 3) - all in dependency order
   //   7.  Physics Observation (needs M5 SE data)
   //   8.  EDE - Energy Dissipation (needs physics + phase)
   //   9.  RE - Resolution Engine (needs EDE)
   //   10. EAE - Energy Attractors (needs RE)
   //   11. Belief Engine (needs ERF + physics + similarity)
   //   12. Hypothesis Engine (needs beliefs)
   //   13. Prediction Engine (needs beliefs + wave progress)
   //   14. Senseei Meta-Intelligence (needs all above + stack)
   //   15. Liquidation Wave Overlay (needs EDE + RE + phase)
   //=================================================================
   Intel_UpdateAll();

   //=================================================================
   // STEPS 16-21: Execution Engine (Part 4) - all in dependency order
   //   16. Curve Object (needs SE + EDE/RE)
   //   17. Curve Tree (needs curve object + CHoCH)
   //   18. Campaign Ownership (needs curve + EDE + liqg)
   //   19. Time Intelligence (HTF cycle data)
   //   20. Composite Exit (ARC + intelligence states)
   //   21. Master Entry (phase engine + intelligence gate)
   //=================================================================
   Exec_UpdateAll();

   //=================================================================
   // STEP 22: Alert Conditions - fire on key state transitions
   //=================================================================
   CheckAlertConditions();

   //=================================================================
   // STEP 23: Dashboards (Part 5) - render all panels
   //=================================================================
   UpdateDashboards();
}

//+------------------------------------------------------------------+
//| ALERT CONDITIONS - Fire on key state transitions                   |
//+------------------------------------------------------------------+
void CheckAlertConditions()
{
   //--- Alert: Senseei flips to ATTACK
   if(InpAlertOnAttack)
   {
      if(g_senseei_action == "ATTACK" && g_prevSenseeiAction != "ATTACK")
      {
         string dir = (g_senseei_master == 1) ? "LONG" : "SHORT";
         Alert("[MASTER] Senseei ATTACK triggered - Direction: ", dir,
               " | Confidence: ", DoubleToString(g_senseei_confidence, 1),
               " | Alignment: ", DoubleToString(g_senseei_alignment, 1));
      }
   }

   //--- Alert: Curve life drops below death threshold (< 33)
   if(InpAlertOnCurveDeath)
   {
      bool curDead = (g_curveLifeScore < 33.0);
      if(curDead && !g_prevCurveDead)
      {
         Alert("[MASTER] Curve DEATH detected - Life: ",
               DoubleToString(g_curveLifeScore, 1),
               " | State: ", g_curveLifeState,
               " | Curve Dir: ", g_curve.dir);
      }
      g_prevCurveDead = curDead;
   }

   //--- Alert: Fractal stack direction flips
   if(InpAlertOnStackFlip)
   {
      if(g_fractalStackDir != g_prevFractalStackDir && g_prevFractalStackDir != 0)
      {
         string fromDir = (g_prevFractalStackDir == 1) ? "BULL" : "BEAR";
         string toDir   = (g_fractalStackDir == 1) ? "BULL" :
                          (g_fractalStackDir == -1) ? "BEAR" : "FLAT";
         Alert("[MASTER] Fractal Stack FLIP: ", fromDir, " -> ", toDir,
               " | Score: ", DoubleToString(g_fractalStackScore, 1));
      }
   }

   //--- Alert: Liquidation wave objective arrival
   if(InpAlertOnObjArrival)
   {
      if(g_liqg_objArrival && !g_prevObjArrival)
      {
         Alert("[MASTER] Liquidation Objective ARRIVAL - Target: ",
               DoubleToString(g_liqg_target, _Digits),
               " | Dir: ", (g_liqg_dir == 1) ? "BULL" : "BEAR");
      }
      g_prevObjArrival = g_liqg_objArrival;
   }

   //--- Update previous state for next bar comparison
   g_prevSenseeiAction   = g_senseei_action;
   g_prevFractalStackDir = g_fractalStackDir;
}
//+------------------------------------------------------------------+
