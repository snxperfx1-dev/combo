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

//------------------------------------------------------------------
// CHIEF STRATEGIST — maps the meta scores into the base verdict,
// gating ONLY on continuous probabilities (never on a phase label).
//------------------------------------------------------------------
int DE_ChiefStrategist(const int master,const double conflict,const double confidence,
                       const double threat,const string oppGrade,const double execProb,
                       const int resCode)
{
   bool strongOpp = (oppGrade=="STRONG" || oppGrade=="EXCEPTIONAL");
   bool goodOpp   = (oppGrade=="GOOD"   || oppGrade=="STRONG" || oppGrade=="EXCEPTIONAL");
   bool confOk    = (confidence>=g_cfg.minConf);
   bool threatOk  = (threat<g_cfg.maxThreat);
   bool probArmed = (execProb>=g_cfg.execProbArm);

   // A GOOD-or-better opportunity with healthy confidence and low threat is
   // tradeable. STRONG/EXCEPTIONAL simply arm faster. (Phases never gate this.)
   bool tradeable = (goodOpp && confOk && threatOk);

   if(master==DIR_NONE)                 return(ACT_WAIT);
   if(conflict>g_cfg.maxConflict)       return(ACT_WAIT);
   if(resCode==RES_RESOLVED)            return(ACT_EXIT);        // energy spent -> bank
   if(tradeable && probArmed)           return(master==DIR_LONG?ACT_BUY:ACT_SELL);
   if(tradeable)                        return(ACT_ATTACK);      // armed, probability building
   if(goodOpp || strongOpp)             return(ACT_PREPARE);
   return(ACT_WAIT);
}

//------------------------------------------------------------------
// CAMPAIGN AI — overlays multi-campaign management on the base verdict:
// DEFEND open exposure under rising failure risk, and SCALE a winning,
// aligned campaign that still has room to run. Operates per-campaign
// (direction-aware), consistent with the hedging multi-campaign model.
//------------------------------------------------------------------
int DE_CampaignAI(int action,const int master,const double threat)
{
   FalconIntelligence x=g_state.intel;
   bool haveExposure = (g_state.exec.openLongCount>0 || g_state.exec.openShortCount>0);

   // DEFEND: protect exposure when threat spikes or a failure swing looms
   if(haveExposure && (threat>=70.0 || x.failureSwingProb>=0.70) && action!=ACT_EXIT)
      action=ACT_DEFEND;

   // SCALE: add to a winning, aligned campaign with geometry room and unresolved energy
   bool campaignWinning = (g_state.campaign.owner==master && master!=DIR_NONE
                           && g_state.campaign.controlScore>=70.0);
   bool roomToRun = (g_state.convexity.geometryCapacity>40.0 && x.resolutionState==RES_UNRESOLVED);
   if(haveExposure && (action==ACT_BUY||action==ACT_SELL) && campaignWinning && roomToRun)
      action=ACT_SCALE;

   return(action);
}

//------------------------------------------------------------------
// MASTER CHIEF — the final holistic confirmation above Senseei. It
// does not re-derive direction; it CONFIRMS the committed shot by
// checking that the deep layers genuinely agree (curve owner + network
// + prediction validation + reward). If conviction is too low it
// downgrades a live BUY/SELL to ATTACK (armed, but hold fire).
//------------------------------------------------------------------
int DE_MasterChief(int action,const int master)
{
   FalconIntelligence x=g_state.intel;
   bool ownerAgree = (g_state.curve.ownerDir==master && master!=DIR_NONE);
   bool netAgree   = (g_state.network.bias==master);
   bool valOk      = (x.validationScore>=45.0);
   bool execOk     = (x.executionProbability>=g_cfg.execProbArm*0.9);

   double score = (ownerAgree?30.0:0.0)+(netAgree?20.0:0.0)
                 + x.confidence*0.25 + x.validationScore*0.15
                 + (100.0-x.threat)*0.10;
   g_state.intel.masterChiefScore = FalconClamp(score,0,100);

   bool commitOk = ((ownerAgree || netAgree) && valOk && execOk && score>=55.0);
   g_state.intel.masterChiefConfirm = commitOk;

   // Veto only NEW-ENTRY actions (BUY/SELL/ATTACK). If conviction is lacking,
   // downgrade to PREPARE (no fire). SCALE/DEFEND/EXIT are never vetoed.
   bool firing = (action==ACT_BUY || action==ACT_SELL || action==ACT_ATTACK);
   if(firing && !commitOk)
   {
      g_state.intel.masterChiefNote = "hold fire — "+((!ownerAgree && !netAgree)?"owner+net split":!valOk?"unvalidated":!execOk?"low exec prob":"low conviction");
      return(ACT_PREPARE);   // stand down, do not pull the trigger
   }
   g_state.intel.masterChiefNote = commitOk ? "cleared to engage" : "standby";
   return(action);
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

   //==============================================================
   // VERDICT — Chief Strategist (base) then Campaign AI (overlay).
   //==============================================================
   int action = DE_ChiefStrategist(master,conflict,confidence,threat,oppGrade,
                                    x.executionProbability,resCode);
   action     = DE_CampaignAI(action,master,threat);

   // commit the meta scores first so Master Chief reads/writes the shared intel
   g_state.intel = x;
   action        = DE_MasterChief(action,master);   // may downgrade BUY/SELL -> ATTACK
   g_state.intel.finalDecision = FalconActionStr(action);

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
