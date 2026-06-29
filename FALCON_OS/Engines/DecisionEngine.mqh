//+------------------------------------------------------------------+
//|  FALCON OS — Decision Layer : DecisionEngine.mqh               |
//|  Source: F16 Senseei / Chief Strategist                         |
//|                                                                  |
//|  The OS DECIDES. It fuses the four independent voters into a     |
//|  master direction, computes alignment/conflict/confidence/threat |
//|  /opportunity, and emits EXACTLY ONE action:                     |
//|    BUY · SELL · WAIT · ATTACK · DEFEND · EXIT · SCALE · NO TRADE |
//|                                                                  |
//|  CRITICAL LAW: this engine NEVER branches on a phase label. It   |
//|  gates on continuous probabilities (executionProbability,        |
//|  confidence, threat, conflict). Phases are descriptive only.     |
//+------------------------------------------------------------------+
#ifndef FALCON_DECISION_ENGINE_MQH
#define FALCON_DECISION_ENGINE_MQH

#include "../Kernel/FalconState.mqh"
#include "../Kernel/FalconConfig.mqh"
#include "../Kernel/FalconSeries.mqh"
#include "../Kernel/FalconEventBus.mqh"

int de_prevAction=ACT_NO_TRADE;

void DecisionEngineInit(){ de_prevAction=ACT_NO_TRADE; }

//------------------------------------------------------------------
// Opportunity grade label from the opportunity score.
//------------------------------------------------------------------
string DE_OppGrade(const int master, const double conflict, const double opp)
{
   if(master==DIR_NONE) return("NONE");
   if(conflict>60.0)    return("DEVELOPING");
   if(opp<20.0)         return("NONE");
   if(opp<40.0)         return("DEVELOPING");
   if(opp<62.0)         return("GOOD");
   if(opp<82.0)         return("STRONG");
   return("EXCEPTIONAL");
}

//==================================================================
// MASTER ENTRY — Senseei meta-intelligence + verdict
//==================================================================
void DecisionEngineRun()
{
   FalconIntelligence x=g_state.intel;
   FalconWave   w  = g_state.wave;
   FalconHTF    h  = g_state.htf;
   FalconNetwork n = g_state.network;

   //-- FOUR VOTERS -------------------------------------------------
   int vWave  = w.direction;          // LETRA wave
   int vStack = h.stackDir;           // fractal stack
   int vNet   = n.bias;               // invisible network bias
   int vPress = n.pressureDir;        // network authority pressure
   int sum    = vWave+vStack+vNet+vPress;
   int master = sum>0?DIR_LONG:sum<0?DIR_SHORT:DIR_NONE;

   int cast = (vWave!=0?1:0)+(vStack!=0?1:0)+(vNet!=0?1:0)+(vPress!=0?1:0);
   int forV = (vWave==master&&vWave!=0?1:0)+(vStack==master&&vStack!=0?1:0)
             +(vNet==master&&vNet!=0?1:0)+(vPress==master&&vPress!=0?1:0);

   double alignment = (cast>0?(double)forV/(double)cast*100.0:50.0);
   double conflict  = (cast>0?(double)(cast-forV)/(double)cast*100.0:0.0);

   //-- TIME / CYCLE conflict proxy (HTF stack disagreement) --------
   double timeAlign    = h.alignment;
   double timeConflict = h.conflict;

   double residual  = x.residualEnergy;
   double attractor = x.attractorScore;
   double stackPct  = h.alignment;
   int    eligN     = n.liveCount;
   int    resCode   = x.resolutionState;

   //-- THREAT (Senseei formula) -----------------------------------
   double threat = FalconClamp(conflict*0.40 + residual*0.28 + timeConflict*0.12
                   + ((vPress!=DIR_NONE && vPress!=master)?18.0:0.0)
                   + (resCode==RES_PARTIALLY_RESOLVED?10.0:0.0),0,100);

   //-- CONFIDENCE --------------------------------------------------
   double confidence = FalconClamp(alignment*0.40 + timeAlign*0.12 + stackPct*0.18
                       + attractor*0.15 + MathMin(15.0,eligN*1.2) - threat*0.20,0,100);

   //-- OPPORTUNITY -------------------------------------------------
   double oppScore = FalconClamp(alignment*0.40 + attractor*0.30 + stackPct*0.30 - threat*0.35,0,100);
   string oppGrade = DE_OppGrade(master,conflict,oppScore);

   //-- WRITE meta into intel + execution snapshot ------------------
   x.alignment       = alignment;
   x.conflict        = conflict;
   x.confidence      = confidence;
   x.threat          = threat;
   x.opportunity     = oppScore;
   x.opportunityGrade= oppGrade;
   g_state.intel     = x;

   //==============================================================
   // VERDICT — gated on CONTINUOUS PROBABILITIES, not phase labels.
   //   armed = strong opportunity AND confidence high AND threat low
   //           AND executionProbability over the arm threshold.
   //==============================================================
   bool strongOpp  = (oppGrade=="STRONG" || oppGrade=="EXCEPTIONAL");
   bool goodOpp    = (oppGrade=="GOOD" || oppGrade=="STRONG");
   bool confOk     = (confidence>=g_cfg.minConf);
   bool threatOk   = (threat<g_cfg.maxThreat);
   bool probArmed  = (x.executionProbability>=g_cfg.execProbArm);

   int action;
   if(master==DIR_NONE)                          action=ACT_WAIT;
   else if(conflict>g_cfg.maxConflict)           action=ACT_WAIT;
   else if(resCode==RES_RESOLVED)                action=ACT_EXIT;   // energy spent -> bank/manage
   else if(strongOpp && confOk && threatOk && probArmed)
                                                 action=(master==DIR_LONG?ACT_BUY:ACT_SELL);
   else if(strongOpp && confOk && threatOk)      action=ACT_ATTACK; // armed but probability still building
   else if(goodOpp)                              action=ACT_PREPARE;
   else                                          action=ACT_WAIT;

   //-- DEFEND override: open exposure under rising threat/failure --
   bool haveExposure = (g_state.exec.openLongCount>0 || g_state.exec.openShortCount>0);
   if(haveExposure && (threat>=70.0 || x.failureSwingProb>=0.70) && action!=ACT_EXIT)
      action=ACT_DEFEND;

   //-- SCALE: add to a winning, aligned campaign with room left ----
   bool campaignWinning = (g_state.campaign.owner==master && master!=DIR_NONE
                           && g_state.campaign.controlScore>=70.0);
   bool roomToRun = (g_state.convexity.geometryCapacity>40.0 && resCode==RES_UNRESOLVED);
   if(haveExposure && (action==ACT_BUY||action==ACT_SELL) && campaignWinning && roomToRun)
      action=ACT_SCALE;

   g_state.exec.action = action;
   g_state.exec.master = master;

   if(action!=de_prevAction)
   {
      FalconPublish(EVT_VERDICT_CHANGE, action, FalconActionStr(action));
      de_prevAction=action;
   }
}

#endif // FALCON_DECISION_ENGINE_MQH
//+------------------------------------------------------------------+
