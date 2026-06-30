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
                       const double threat,const string oppGrade,const int resCode)
{
   FalconEntryCycle ec = g_state.entryCycle;
   bool gatesOk = (conflict<=g_cfg.maxConflict && confidence>=g_cfg.minConf && threat<g_cfg.maxThreat);
   bool decentOpp = (oppGrade=="GOOD" || oppGrade=="STRONG" || oppGrade=="EXCEPTIONAL");

   if(resCode==RES_RESOLVED) return(ACT_EXIT);   // energy spent -> bank

   // EXECUTE only when the ENTRY CYCLE is active in the terminal zone AND the
   // entry direction agrees with the OWNER (ownership has flipped/confirmed to
   // this side). This is the flip-aware campaign gate: at a valid terminal the
   // owner has just flipped to the wave direction, so they match and it fires;
   // during a building counter-move ownership has NOT flipped, so entryDir !=
   // owner and the entry is blocked. No vote — direction is inherited from WHO.
   if(ec.entryCycleActive && ec.entryDir!=DIR_NONE && ec.entryDir==master && gatesOk)
      return(ec.entryDir==DIR_LONG ? ACT_BUY : ACT_SELL);

   // In the terminal zone but the entry cycle has not started yet -> armed/waiting.
   if(ec.terminal && (ec.readiness==ER_PRE_ENTRY || ec.readiness==ER_BUILDING))
      return(ACT_ATTACK);

   // Approaching the terminal, or a decent directional opportunity is forming.
   if(ec.terminal || ec.readiness==ER_EARLY || (master!=DIR_NONE && decentOpp))
      return(ACT_PREPARE);

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
   bool execOk     = (x.executionProbability>=g_cfg.execProbArm*0.9);

   double score = (ownerAgree?30.0:0.0)+(netAgree?20.0:0.0)
                 + x.confidence*0.25 + x.validationScore*0.15
                 + (100.0-x.threat)*0.10;
   g_state.intel.masterChiefScore = FalconClamp(score,0,100);

   // Commit on genuine agreement + reachable exec prob + a SINGLE conviction
   // threshold (intel.confidence vs minConf) — the same threshold the Chief
   // Strategist uses. This collapses the previously-duplicate conviction gates
   // (confidence>=minConf AND a separate score>=55) into one. masterChiefScore
   // remains as a displayed composite only. Validation stays advisory.
   bool commitOk = ((ownerAgree || netAgree) && execOk && x.confidence>=g_cfg.minConf);
   g_state.intel.masterChiefConfirm = commitOk;

   // Veto only NEW-ENTRY actions (BUY/SELL/ATTACK). If conviction is lacking,
   // downgrade to PREPARE (no fire). SCALE/DEFEND/EXIT are never vetoed.
   bool firing = (action==ACT_BUY || action==ACT_SELL || action==ACT_ATTACK);
   if(firing && !commitOk)
   {
      g_state.intel.masterChiefNote = "hold fire — "+((!ownerAgree && !netAgree)?"owner+net split":!execOk?"low exec prob":"low conviction");
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

   //-- OWNERSHIP IS THE DIRECTION AUTHORITY (no voting) ------------
   // Direction EMERGES from who owns price (the flip-driven Campaign owner),
   // scaled by the curve. The four signals below are NOT voters that pick a
   // side — they are EVIDENCE measuring how strongly the market agrees with the
   // established owner. That agreement sets conviction (confidence/threat),
   // never direction.
   int ownerDir = g_state.campaign.owner;
   if(ownerDir==DIR_NONE) ownerDir = g_state.curve.ownerDir;   // fallback before first flip
   int master   = ownerDir;

   int vWave  = w.direction;          // LETRA wave        (evidence)
   int vStack = h.stackDir;           // fractal stack     (evidence)
   int vNet   = n.bias;               // network bias      (evidence)
   int vPress = n.pressureDir;        // network pressure  (evidence)

   int cast = (vWave!=0?1:0)+(vStack!=0?1:0)+(vNet!=0?1:0)+(vPress!=0?1:0);
   int forV = (vWave==master&&master!=0?1:0)+(vStack==master&&master!=0?1:0)
             +(vNet==master&&master!=0?1:0)+(vPress==master&&master!=0?1:0);

   double alignment = (cast>0?(double)forV/(double)cast*100.0:50.0); // agreement WITH owner
   double conflict  = (cast>0?(double)(cast-forV)/(double)cast*100.0:0.0);

   //-- TIME / CYCLE conflict proxy (HTF stack disagreement) --------
   double timeAlign    = h.alignment;
   double timeConflict = h.conflict;
   int    resCode      = x.resolutionState;

   //-- CONVICTION IS NOW CONCRETE — confidence / threat / opportunity are
   //   computed by the Intelligence Engine from the DEEP STRUCTURAL ENGINES
   //   (phases · curve tree · ownership · curve locator · structure · multi-TF),
   //   NOT from belief/energy blends. The Decision Engine consumes them as-is.
   double threat     = x.threat;
   double confidence = x.confidence;
   double oppScore   = x.opportunity;
   string oppGrade   = (x.opportunityGrade!="" ? x.opportunityGrade : DE_OppGrade(master,conflict,oppScore));

   //-- WRITE meta into intel + execution snapshot ------------------
   x.alignment       = alignment;
   x.conflict        = conflict;
   x.opportunityGrade= oppGrade;

   //==============================================================
   // VERDICT — Chief Strategist (base) then Campaign AI (overlay).
   //==============================================================
   int action = DE_ChiefStrategist(master,conflict,confidence,threat,oppGrade,resCode);

   // execution direction = ownership (master). When the entry cycle fires, its
   // entryDir already equals the owner (enforced by the gate above).
   int execMaster = master;
   action     = DE_CampaignAI(action,execMaster,threat);

   // commit the meta scores first so Master Chief reads/writes the shared intel
   g_state.intel = x;
   action        = DE_MasterChief(action,execMaster); // may downgrade a fire -> PREPARE
   g_state.intel.finalDecision = FalconActionStr(action);

   g_state.exec.action = action;
   g_state.exec.master = execMaster;

   if(action!=de_prevAction)
   {
      FalconPublish(EVT_VERDICT_CHANGE, action, FalconActionStr(action));
      de_prevAction=action;
   }
}

#endif // FALCON_DECISION_ENGINE_MQH
//+------------------------------------------------------------------+
