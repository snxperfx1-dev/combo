//+------------------------------------------------------------------+
//|  FALCON OS — Intelligence : WaveCycleIntel.mqh                  |
//|                                                                  |
//|  THE COMPARATIVE WAVE FRAMEWORK (S12 Wave Intelligence becomes   |
//|  the REFEREE). Don't replace the phase engine — run THREE wave-  |
//|  cycle engines on the SAME shared observations and let the market |
//|  decide which has the highest predictive power:                  |
//|                                                                  |
//|        MARKET ENGINE  (shared observations once / bar)           |
//|              │                                                   |
//|     ┌────────┼────────┐                                          |
//|   LETRA    F16      SYMPHONY                                     |
//|   Eng 1A   Eng 8/F72 Phase Engine                               |
//|     └────────┼────────┘                                          |
//|        Wave Intelligence (referee: compare / validate / score)   |
//|              │                                                   |
//|        Decision & Execution                                      |
//|                                                                  |
//|  Each engine emits a NORMALIZED forecast (phase · stage · dir ·  |
//|  maturity · objective · invalidation · confidence · next event)  |
//|  into g_state.cycles[]. The referee (Part C, below) tracks each   |
//|  engine's demonstrated accuracy and forms a consensus / best.    |
//|                                                                  |
//|  THIS FILE reads g_state only (LETRA + F16 lenses + referee).    |
//|  The Symphony cycle is computed inside SymphonyEngine.mqh where   |
//|  the sym_* phase state lives. Include AFTER CurveLocator.mqh.     |
//+------------------------------------------------------------------+
#ifndef FALCON_WAVE_CYCLE_INTEL_MQH
#define FALCON_WAVE_CYCLE_INTEL_MQH

#include "../Kernel/FalconState.mqh"
#include "../Kernel/FalconConfig.mqh"
#include "../Kernel/FalconSeries.mqh"
#include "../Kernel/FalconEventBus.mqh"

//==================================================================
// NORMALIZATION HELPERS — shared across all three engines so they are
// judged on the SAME yardstick.
//==================================================================
// Fill the entry-trigger fields from the just-computed stage + the
// previous bar's stage (edge detection). A return (CYC_RETURN) is the
// P3 analog; a breakout (CYC_BREAKOUT) is the P4 analog.
void Cycle_FillEntry(WaveCycle &cy,const int prevStage)
{
   cy.prevStage  = prevStage;
   cy.entryArmed = (cy.stage==CYC_RETURN || cy.stage==CYC_BREAKOUT) && cy.direction!=DIR_NONE;
   cy.entryEdge  = cy.entryArmed && (prevStage != cy.stage);
   cy.entryKind  = (cy.stage==CYC_BREAKOUT ? 4 : cy.stage==CYC_RETURN ? 3 : 0);
   cy.entryDir   = cy.entryArmed ? cy.direction : DIR_NONE;
}

// carry referee-learned performance forward (compute steps rebuild the
// descriptive fields each bar but must NOT wipe accumulated accuracy)
void Cycle_CarryPerf(WaveCycle &cy,const WaveCycle &prev)
{
   cy.accuracy    = prev.accuracy;
   cy.objAccuracy = prev.objAccuracy;
   cy.avgLeadBars = prev.avgLeadBars;
   cy.samples     = prev.samples;
   cy.wins        = prev.wins;
}

//==================================================================
// ENGINE 1 — LETRA wave cycle (the per-TF fixed-structure lifecycle).
//   Reads the NATIVE LETRA wave FSM (g_state.wave) BEFORE any phase
//   authority overwrites it. me_pst lifecycle 0..14 -> normalized
//   stage + canonical phase.
//==================================================================
void CycleLetra_Compute()
{
   WaveCycle cy; ZeroMemory(cy);
   Cycle_CarryPerf(cy, g_state.cycles[ENG_LETRA]);
   int prevStage = g_state.cycles[ENG_LETRA].stage;

   FalconWave w = g_state.wave;   // native LETRA at this point in the pipeline
   int pst = w.phase;             // 0..14 lifecycle
   int dir = w.direction;

   cy.engineId  = ENG_LETRA;
   cy.direction = dir;
   cy.maturity  = w.completion;
   cy.objective = w.objective;
   cy.invalidation = w.origin;
   cy.confidence = FalconClamp(w.confidence*0.6 + w.strength*0.4, 0, 100);

   int stage, ph; string nxt;
   switch(pst)
   {
      case 1:  stage=CYC_EXPANSION; ph=PH_EXPANSION;    nxt="decay -> retrace"; break;
      case 2:  stage=CYC_RETRACE;   ph=PH_RETRACEMENT;  nxt="counter-impulse / transfer"; break;
      case 3:  stage=CYC_RETURN;    ph=(dir==DIR_LONG?PH_DEMAND_RETURN:PH_SUPPLY_RETURN); nxt="confirm BOS continuation"; break;
      case 4:  stage=CYC_BREAKOUT;  ph=(dir==DIR_LONG?PH_NEW_HIGH:PH_NEW_LOW);  nxt="extend to objective"; break;
      case 5:  case 6: stage=CYC_BREAKOUT; ph=(dir==DIR_LONG?PH_NEW_HIGH:PH_NEW_LOW); nxt="post-extreme recursion"; break;
      case 7:  stage=CYC_RETRACE;   ph=PH_RETRACEMENT;  nxt="transfer of ownership"; break;
      case 8:  stage=CYC_RETRACE;   ph=PH_TRANSITION;   nxt="return to flip zone"; break;
      case 9:  stage=CYC_RETURN;    ph=(dir==DIR_LONG?PH_DEMAND_RETURN:PH_SUPPLY_RETURN); nxt="impulse from flip"; break;
      case 10: stage=CYC_BREAKOUT;  ph=(dir==DIR_LONG?PH_NEW_HIGH:PH_NEW_LOW);  nxt="continuation to target"; break;
      case 11: stage=CYC_RETRACE;   ph=PH_LIQUIDATION;  nxt="opposing BOS / reversal risk"; break;
      case 12: stage=CYC_RETRACE;   ph=PH_LIQUIDATION;  nxt="liquidity sweep"; break;
      case 13: case 14: stage=CYC_RETURN; ph=(dir==DIR_LONG?PH_DEMAND_RETURN:PH_SUPPLY_RETURN); nxt="terminal reversal confirm"; break;
      default: stage=CYC_NONE;      ph=PH_TRANSITION;   nxt="awaiting impulse"; break;
   }
   cy.stage      = stage;
   cy.phase      = ph;
   cy.phaseLabel = FalconPhaseStr(ph);
   cy.nextEvent  = nxt;
   Cycle_FillEntry(cy, prevStage);

   g_state.cycles[ENG_LETRA] = cy;
}

//==================================================================
// ENGINE 2 — F16 wave cycle (the recursive curve-tree node lens).
//   Phases EMERGE from the owning node (Principle 1). Reads the F72
//   tree summary in g_state.curve (populated by CurveTree.mqh).
//==================================================================
bool CY_Contains(const string s,const string sub){ return(StringFind(s,sub)>=0); }

void CycleF16_Compute()
{
   WaveCycle cy; ZeroMemory(cy);
   Cycle_CarryPerf(cy, g_state.cycles[ENG_F16]);
   int prevStage = g_state.cycles[ENG_F16].stage;

   FalconCurve cu = g_state.curve;
   int dir   = cu.ownerNodeDir!=DIR_NONE ? cu.ownerNodeDir : cu.ownerDir;
   string st = cu.ownerNodeState;
   double org= cu.ownerNodeOrigin;
   double ext= cu.ownerNodeExtreme;

   cy.engineId  = ENG_F16;
   cy.direction = dir;
   cy.maturity  = FalconClamp(cu.ownerNodeEnergy, 0, 100);
   cy.invalidation = org;
   // owner-curve destination: project the leg beyond its extreme
   double leg = (org!=0.0 && ext!=0.0) ? MathAbs(ext-org) : 0.0;
   cy.objective = (ext!=0.0 && leg>0.0) ? (dir==DIR_LONG ? ext+leg*0.5 : ext-leg*0.5)
                                        : g_state.wave.objective;
   cy.confidence= FalconClamp(cu.ownerNodeEnergy*0.55 + cu.narrative*0.30 + (cu.recursionComplete?0:15.0), 0, 100);

   int stage, ph; string nxt;
   if(CY_Contains(st,"New High"))      { stage=CYC_BREAKOUT; ph=PH_NEW_HIGH;  nxt="extend / recursion budget"; }
   else if(CY_Contains(st,"New Low"))  { stage=CYC_BREAKOUT; ph=PH_NEW_LOW;   nxt="extend / recursion budget"; }
   else if(CY_Contains(st,"Climax"))   { stage=CYC_BREAKOUT; ph=(dir==DIR_LONG?PH_NEW_HIGH:PH_NEW_LOW); nxt="exhaustion / transfer"; }
   else if(CY_Contains(st,"Origin"))   { stage=CYC_RETURN;   ph=(dir==DIR_LONG?PH_DEMAND_RETURN:PH_SUPPLY_RETURN); nxt="impulse off node origin"; }
   else if(CY_Contains(st,"recursive")){ stage=CYC_RETURN;   ph=(dir==DIR_LONG?PH_DEMAND_RETURN:PH_SUPPLY_RETURN); nxt="child curve resolves"; }
   else if(CY_Contains(st,"Retracement")){ stage=CYC_RETRACE; ph=PH_RETRACEMENT; nxt="return to demand/supply"; }
   else if(CY_Contains(st,"Induction")){ stage=CYC_EXPANSION; ph=PH_EXP_INDUCTION; nxt="liquidity engineered"; }
   else if(CY_Contains(st,"Liquidity")){ stage=CYC_EXPANSION; ph=PH_EXP_LIQUIDITY; nxt="sweep then continue"; }
   else if(CY_Contains(st,"Expansion")){ stage=CYC_EXPANSION; ph=PH_EXPANSION;  nxt="convexity develops"; }
   else                                { stage=CYC_NONE;     ph=PH_TRANSITION;  nxt="awaiting owner node"; }

   cy.stage      = stage;
   cy.phase      = ph;
   cy.phaseLabel = (st!="" && st!="—") ? st : FalconPhaseStr(ph);
   cy.nextEvent  = nxt;
   Cycle_FillEntry(cy, prevStage);

   g_state.cycles[ENG_F16] = cy;
}

//==================================================================
// ════════ S12J — WAVE INTELLIGENCE REFEREE (Engine Comparison) ════
//   Rather than ONE truth, the referee asks "who has been right
//   recently?" It opens a SHADOW PREDICTION whenever an engine casts a
//   directional entry edge, resolves it after cycleEvalBars (or when a
//   +/- cycleEvalATR excursion settles it), and rolls each engine's
//   demonstrated directional + objective accuracy (EWMA). It also forms
//   the consensus, measures disagreement (wave deviation), and flags
//   the best / leading engine — turning FALCON into a self-evaluating
//   research platform. Phases stay OUTPUTS: the referee scores evidence.
//==================================================================
struct CyclePrediction
{
   bool   active;
   int    engineId;
   int    dir;
   double entryPx;
   double objective;
   double atr;
   int    openBar;
   double mfe;     // best favorable excursion (price units)
   double mae;     // worst adverse excursion
};
#define CY_MAX_PRED 48
CyclePrediction cy_pred[CY_MAX_PRED];
int             cy_predCount = 0;

// per-engine running stats (live; mirrored into g_state.cycles each bar)
double cy_acc[FALCON_NCYCLES];      // EWMA directional accuracy %%
double cy_objAcc[FALCON_NCYCLES];   // EWMA objective-reach %%
double cy_lead[FALCON_NCYCLES];     // EWMA early-detection lead (bars)
int    cy_samples[FALCON_NCYCLES];
int    cy_wins[FALCON_NCYCLES];
int    cy_lastDirBar[FALCON_NCYCLES]; // bar each engine last FLIPPED direction
int    cy_lastDir[FALCON_NCYCLES];
int    cy_leadCount[FALCON_NCYCLES];  // times this engine led a shared flip

void WaveRefereeInit()
{
   cy_predCount=0;
   for(int i=0;i<CY_MAX_PRED;i++){ ZeroMemory(cy_pred[i]); cy_pred[i].active=false; }
   for(int i=0;i<FALCON_NCYCLES;i++)
   {
      cy_acc[i]=50.0; cy_objAcc[i]=50.0; cy_lead[i]=0.0;
      cy_samples[i]=0; cy_wins[i]=0;
      cy_lastDirBar[i]=0; cy_lastDir[i]=DIR_NONE; cy_leadCount[i]=0;
   }
   ZeroMemory(g_state.referee);
}

//------------------------------------------------------------------
// open a shadow prediction for an engine's directional entry edge
//------------------------------------------------------------------
void CY_OpenPrediction(const int eng,const int dir,const double objective)
{
   if(dir==DIR_NONE) return;
   double atr = g_state.physics.atr; if(atr<=0.0) atr=FalconATR(1); if(atr<=0.0) return;
   // dedupe: one active prediction per engine+direction
   for(int i=0;i<cy_predCount;i++)
      if(cy_pred[i].active && cy_pred[i].engineId==eng && cy_pred[i].dir==dir) return;

   if(cy_predCount>=CY_MAX_PRED)
   {
      // shift oldest out
      for(int i=1;i<cy_predCount;i++) cy_pred[i-1]=cy_pred[i];
      cy_predCount--;
   }
   CyclePrediction p; ZeroMemory(p);
   p.active=true; p.engineId=eng; p.dir=dir; p.entryPx=gClose[1];
   p.objective=objective; p.atr=atr; p.openBar=g_barCounter; p.mfe=0.0; p.mae=0.0;
   cy_pred[cy_predCount++]=p;
}

//------------------------------------------------------------------
// resolve a prediction: WIN if it ran +cycleEvalATR favorably (or hit
// objective) before -cycleEvalATR adverse; LOSS otherwise. Updates EWMA.
//------------------------------------------------------------------
void CY_ScorePrediction(const int idx,const bool win,const bool objHit)
{
   int e = cy_pred[idx].engineId;
   if(e<0||e>=FALCON_NCYCLES) return;
   double a = g_cfg.refereeLearn ? 0.12 : 0.0;   // EWMA weight
   cy_acc[e]    = cy_acc[e]*(1.0-a)    + (win?100.0:0.0)*a;
   cy_objAcc[e] = cy_objAcc[e]*(1.0-a) + (objHit?100.0:0.0)*a;
   cy_samples[e]++;
   if(win) cy_wins[e]++;
   cy_pred[idx].active=false;
}

//------------------------------------------------------------------
// advance + resolve all open predictions on the new bar
//------------------------------------------------------------------
void CY_AdvancePredictions()
{
   double hi=gHigh[1], lo=gLow[1];
   for(int i=0;i<cy_predCount;i++)
   {
      if(!cy_pred[i].active) continue;
      double favTarget = cy_pred[i].atr*g_cfg.cycleEvalATR;
      double fav = (cy_pred[i].dir==DIR_LONG ? hi-cy_pred[i].entryPx : cy_pred[i].entryPx-lo);
      double adv = (cy_pred[i].dir==DIR_LONG ? cy_pred[i].entryPx-lo : hi-cy_pred[i].entryPx);
      if(fav>cy_pred[i].mfe) cy_pred[i].mfe=fav;
      if(adv>cy_pred[i].mae) cy_pred[i].mae=adv;

      bool objHit = (cy_pred[i].objective!=0.0 &&
                     (cy_pred[i].dir==DIR_LONG ? hi>=cy_pred[i].objective : lo<=cy_pred[i].objective));
      // settle: favorable target reached -> win; adverse target first -> loss
      if(cy_pred[i].mfe>=favTarget || objHit){ CY_ScorePrediction(i,true,objHit); continue; }
      if(cy_pred[i].mae>=favTarget){ CY_ScorePrediction(i,false,false); continue; }
      // timeout: judge on net excursion at the horizon
      if(g_barCounter-cy_pred[i].openBar >= g_cfg.cycleEvalBars)
      { CY_ScorePrediction(i, cy_pred[i].mfe>cy_pred[i].mae, false); }
   }
   // compact resolved
   int w=0;
   for(int i=0;i<cy_predCount;i++) if(cy_pred[i].active) cy_pred[w++]=cy_pred[i];
   cy_predCount=w;
}

//------------------------------------------------------------------
// early-detection lead: when engines agree on a NEW direction, the one
// that flipped first earns lead bars over the laggards.
//------------------------------------------------------------------
void CY_TrackLead()
{
   for(int e=0;e<FALCON_NCYCLES;e++)
   {
      int d=g_state.cycles[e].direction;
      if(d!=DIR_NONE && d!=cy_lastDir[e]){ cy_lastDir[e]=d; cy_lastDirBar[e]=g_barCounter; }
   }
   // find the consensus direction and who reached it earliest
   for(int e=0;e<FALCON_NCYCLES;e++)
   {
      int d=cy_lastDir[e]; if(d==DIR_NONE) continue;
      int agree=0, earliest=g_barCounter+1, leadEng=e;
      for(int k=0;k<FALCON_NCYCLES;k++)
         if(cy_lastDir[k]==d){ agree++; if(cy_lastDirBar[k]<earliest){ earliest=cy_lastDirBar[k]; leadEng=k; } }
      if(agree>=2 && leadEng==e)
      {
         // lead = how many bars ahead of the latest agreeing engine
         int latest=0;
         for(int k=0;k<FALCON_NCYCLES;k++) if(cy_lastDir[k]==d && cy_lastDirBar[k]>latest) latest=cy_lastDirBar[k];
         double lb=(double)(latest-cy_lastDirBar[e]);
         if(lb>0){ cy_lead[e]=cy_lead[e]*0.8+lb*0.2; cy_leadCount[e]++; }
      }
   }
}

//==================================================================
// MASTER ENTRY — the referee. Runs AFTER all three cycles are computed.
//==================================================================
void WaveRefereeRun()
{
   // 1) score open predictions on this freshly-closed bar
   CY_AdvancePredictions();

   // 2) open new shadow predictions for any engine casting an entry edge
   for(int e=0;e<FALCON_NCYCLES;e++)
      if(g_state.cycles[e].entryEdge && g_state.cycles[e].entryDir!=DIR_NONE)
         CY_OpenPrediction(e, g_state.cycles[e].entryDir, g_state.cycles[e].objective);

   // 3) early-detection lead tracking
   CY_TrackLead();

   // 4) publish per-engine stats back into the cycle structs
   for(int e=0;e<FALCON_NCYCLES;e++)
   {
      g_state.cycles[e].accuracy    = cy_acc[e];
      g_state.cycles[e].objAccuracy = cy_objAcc[e];
      g_state.cycles[e].avgLeadBars = cy_lead[e];
      g_state.cycles[e].samples     = cy_samples[e];
      g_state.cycles[e].wins        = cy_wins[e];
   }

   // 5) CONSENSUS — direction agreed by >=2 engines (weight by demonstrated
   //    accuracy so a proven engine breaks ties).
   WaveReferee r; ZeroMemory(r);
   double bull=0.0, bear=0.0;
   for(int e=0;e<FALCON_NCYCLES;e++)
   {
      double wgt = FalconClamp(g_state.cycles[e].accuracy/100.0,0.1,1.0);
      if(g_state.cycles[e].direction==DIR_LONG)  bull+=wgt;
      if(g_state.cycles[e].direction==DIR_SHORT) bear+=wgt;
   }
   int agreeL=0, agreeS=0;
   for(int e=0;e<FALCON_NCYCLES;e++)
   {
      if(g_state.cycles[e].direction==DIR_LONG)  agreeL++;
      if(g_state.cycles[e].direction==DIR_SHORT) agreeS++;
   }
   if(agreeL>=2 && bull>bear)      r.consensusDir=DIR_LONG;
   else if(agreeS>=2 && bear>bull) r.consensusDir=DIR_SHORT;
   else                            r.consensusDir=DIR_NONE;

   // consensus stage + confidence = average over engines that match consensus
   int    cnt=0; double confSum=0.0, stageSum=0.0;
   for(int e=0;e<FALCON_NCYCLES;e++)
      if(r.consensusDir!=DIR_NONE && g_state.cycles[e].direction==r.consensusDir)
      { confSum+=g_state.cycles[e].confidence; stageSum+=g_state.cycles[e].stage; cnt++; }
   r.consensusConf  = (cnt>0?confSum/cnt:0.0);
   r.consensusStage = (cnt>0?(int)MathRound(stageSum/cnt):CYC_NONE);

   // 6) WAVE DEVIATION — disagreement across engines (stage + objective).
   int sMin=9, sMax=-1; double oMin=DBL_MAX, oMax=-DBL_MAX; int oCnt=0;
   for(int e=0;e<FALCON_NCYCLES;e++)
   {
      int s=g_state.cycles[e].stage;
      if(s<sMin) sMin=s; if(s>sMax) sMax=s;
      double o=g_state.cycles[e].objective;
      if(o!=0.0){ if(o<oMin) oMin=o; if(o>oMax) oMax=o; oCnt++; }
   }
   r.deviationStage  = (sMax>=0? (double)(sMax-sMin):0.0);
   double atr=g_state.physics.atr; if(atr<=0.0) atr=FalconATR(1); if(atr<=0.0) atr=1.0;
   r.deviationObjATR = (oCnt>=2? (oMax-oMin)/atr : 0.0);

   // 7) BEST + LEADER engines (need a minimum sample before trusting).
   r.bestEngine=ENG_SYMPHONY; r.bestAccuracy=-1.0; r.leader=ENG_SYMPHONY;
   int bestLead=-1;
   for(int e=0;e<FALCON_NCYCLES;e++)
   {
      if(cy_samples[e]>=g_cfg.bestMinSamples && cy_acc[e]>r.bestAccuracy)
      { r.bestAccuracy=cy_acc[e]; r.bestEngine=e; }
      if(cy_leadCount[e]>bestLead){ bestLead=cy_leadCount[e]; r.leader=e; }
   }
   if(r.bestAccuracy<0.0){ r.bestEngine=ENG_SYMPHONY; r.bestAccuracy=cy_acc[ENG_SYMPHONY]; }

   // 8) RESOLVE the engine that DRIVES this bar (selector).
   int sel;
   if(g_cfg.entryEngine==ENG_BEST)           sel=r.bestEngine;
   else if(g_cfg.entryEngine==ENG_CONSENSUS) sel=ENG_CONSENSUS;   // handled specially downstream
   else                                      sel=g_cfg.entryEngine;
   r.selectedEngine=sel;
   r.selectedName  =FalconEngineStr(g_cfg.entryEngine==ENG_BEST?r.bestEngine:g_cfg.entryEngine);
   r.note = StringFormat("L%.0f%% F%.0f%% S%.0f%%  dev:st%.0f obj%.1fATR",
              cy_acc[ENG_LETRA], cy_acc[ENG_F16], cy_acc[ENG_SYMPHONY],
              r.deviationStage, r.deviationObjATR);

   g_state.referee=r;
}

#endif // FALCON_WAVE_CYCLE_INTEL_MQH
//+------------------------------------------------------------------+
