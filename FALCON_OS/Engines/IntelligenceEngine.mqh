//+------------------------------------------------------------------+
//|  FALCON OS — Intelligence Layer : IntelligenceEngine.mqh        |
//|  Source: LETRA + F16 (reasoning)                                |
//|                                                                  |
//|  The OS REASONS. Belief scores, the Energy Resolution Framework  |
//|  (EDE dissipation / RE recursion / EAE attractor), a PREDICTIVE  |
//|  recursion-forecast layer, and the continuous executionProbability|
//|  that drives decisions. Per the design law: phases are OUTPUTS,   |
//|  probabilities are the inputs. Writes g_state.intel.             |
//+------------------------------------------------------------------+
#ifndef FALCON_INTEL_ENGINE_MQH
#define FALCON_INTEL_ENGINE_MQH

#include "../Kernel/FalconState.mqh"
#include "../Kernel/FalconConfig.mqh"
#include "../Kernel/FalconSeries.mqh"
#include "../Kernel/FalconEventBus.mqh"

// persistent smoothed beliefs
double ie_bExp=0, ie_bConv=0, ie_bCreate=0, ie_bAbs=0, ie_bRetr=0, ie_bRet=0;
int    ie_prevRes=RES_UNRESOLVED;
// persistent validation-loop state
double ie_prevPredPrice=0; int ie_prevPredDir=0; double ie_valScore=50.0;
// multi-bar forward-test of predictions
int    ie_predPendDir=0; double ie_predPendClose=0; int ie_predBarsLeft=0; bool ie_predActive=false;
// F16 Engine 1A.7 — persistent liquidation-wave state
bool   ie_liqActive=false; bool ie_liqIsRetr=false; int ie_liqDir=0;
double ie_liqTarget=0; double ie_liqInitDist=0;

// SUBSCRIBER: a fresh wave spawn invalidates the prior terminal liquidation.
void IE_OnWaveSpawn(const FalconEvent &e){ ie_liqActive=false; ie_liqTarget=0; ie_liqInitDist=0; }

void IntelligenceEngineInit()
{
   ie_bExp=0; ie_bConv=0; ie_bCreate=0; ie_bAbs=0; ie_bRetr=0; ie_bRet=0;
   ie_prevRes=RES_UNRESOLVED;
   ie_prevPredPrice=0; ie_prevPredDir=0; ie_valScore=50.0;
   ie_predPendDir=0; ie_predPendClose=0; ie_predBarsLeft=0; ie_predActive=false;
   ie_liqActive=false; ie_liqIsRetr=false; ie_liqDir=0; ie_liqTarget=0; ie_liqInitDist=0;
   FalconSubscribe(EVT_WAVE_SPAWN, IE_OnWaveSpawn);   // event-driven reset
}

//------------------------------------------------------------------
// Observation scores from physics (LETRA Section 9).
//------------------------------------------------------------------
double IE_ExpansionScore()
{
   FalconPhysics p=g_state.physics;
   double velScore=MathMin(MathAbs(p.velocity)/MathMax(p.atr*0.1,1e-10)*50.0,100.0);
   return(FalconClamp((p.efficiency>g_cfg.effThresh?p.efficiency*60.0:p.efficiency*30.0)
          + (p.displacement>g_cfg.dispThresh?(p.displacement/MathMax(g_cfg.dispThresh,1e-10)-1.0)*20.0:0.0)
          + ((p.velocity>0&&p.acceleration>0)||(p.velocity<0&&p.acceleration<0)?velScore*0.2:0.0),0,100));
}
double IE_DecayScore()
{
   FalconPhysics p=g_state.physics;
   double convScore=MathMin(MathAbs(p.convexitySmooth)/MathMax(p.atr*g_cfg.convMult,1e-10)*25.0,100.0);
   return(FalconClamp((p.bullDecay||p.bearDecay?40.0:0.0)+(convScore>30?convScore*0.5:0.0),0,100));
}
double IE_CurvatureScore()
{
   FalconPhysics p=g_state.physics;
   return(MathMin(MathAbs(p.convexitySmooth)/MathMax(p.atr*g_cfg.convMult,1e-10)*25.0,100.0));
}
double IE_AbsorptionScore()
{
   FalconPhysics p=g_state.physics;
   return(FalconClamp((p.efficiency<g_cfg.effThresh*0.7?(1.0-p.efficiency/MathMax(g_cfg.effThresh,1e-10))*50.0:0.0)
          +(p.displacement<g_cfg.dispThresh*0.5?20.0:0.0),0,100));
}
double IE_LiquidityScore()
{
   double dec=IE_DecayScore(), cur=IE_CurvatureScore();
   FalconPhysics p=g_state.physics;
   return(FalconClamp(dec*0.4+cur*0.4+(p.displacement>g_cfg.dispThresh*1.2&&(p.bullDecay||p.bearDecay)?20.0:0.0),0,100));
}

//------------------------------------------------------------------
// ENERGY DISSIPATION ENGINE (EDE) — from the phase lifecycle.
//------------------------------------------------------------------
void IE_EnergyResolution(FalconIntelligence &x)
{
   FalconWave w=g_state.wave;
   FalconPhysics p=g_state.physics;
   int phase=w.phase;

   int edeState = (phase==PH_P4_ORIGIN||phase==PH_EXPANSION)?1:
                  (phase==PH_EXP_PRECONVEXITY)?2:
                  (phase==PH_EXP_INDUCTION)?3:
                  (phase==PH_EXP_LIQUIDITY)?4:
                  (phase==PH_NEW_HIGH||phase==PH_NEW_LOW)?5:6;

   double expEnergy = FalconClamp(IE_ExpansionScore()*0.50+((p.bullImpulse||p.bearImpulse)?30.0:0.0)+p.efficiency*20.0,0,100);
   double dissip    = FalconClamp((edeState>=2?IE_DecayScore()*0.40:0.0)
                      +(edeState>=3?IE_CurvatureScore()*0.30:0.0)
                      +(edeState>=4?IE_LiquidityScore()*0.30:0.0),0,100);
   double dissipProg= FalconClamp((edeState>=2?25.0:0.0)+(edeState>=3?25.0:0.0)+(edeState>=4?25.0:0.0)+(edeState>=5?25.0:0.0),0,100);

   x.expansionEnergy   = expEnergy;
   x.dissipatedEnergy  = dissip;
   x.dissipationProgress= dissipProg;
   x.residualEnergy    = FalconClamp(MathMax(0.0,expEnergy-dissip),0,100);

   // RESOLUTION ENGINE (RE)
   x.expectedCycles    = (int)MathMax(1,MathMin(w.waveDepth+2,4));
   x.completedCycles   = (int)MathMax(0,MathMin(w.entryCycle,x.expectedCycles));
   x.recursiveCompletion = (x.expectedCycles>0?MathMin((double)x.completedCycles/(double)x.expectedCycles*100.0,100.0):0.0);

   bool objectiveReached = (edeState>=5);
   bool fullDissipation  = (dissipProg>=75.0);
   bool absorbedReturned = (phase==PH_DEMAND_RETURN||phase==PH_SUPPLY_RETURN)&&w.recursiveComplete;

   if(absorbedReturned && fullDissipation && x.recursiveCompletion>=75.0) x.resolutionState=RES_RESOLVED;
   else if(objectiveReached && dissipProg>=50.0) x.resolutionState=RES_PARTIALLY_RESOLVED;
   else x.resolutionState=RES_UNRESOLVED;

   // ENERGY ATTRACTOR ENGINE (EAE)
   double attractorPx=0;
   if(w.direction!=DIR_NONE)
   {
      if(x.resolutionState==RES_UNRESOLVED)
         attractorPx = (w.direction==DIR_LONG? (w.flipBot!=0?w.flipBot:gClose[1]-p.atr*2.0) : (w.flipTop!=0?w.flipTop:gClose[1]+p.atr*2.0));
      else if(x.resolutionState==RES_PARTIALLY_RESOLVED)
         attractorPx = (w.direction==DIR_LONG? (w.point4Low!=0?w.point4Low:gClose[1]-p.atr) : (w.point4High!=0?w.point4High:gClose[1]+p.atr));
   }
   x.attractorPrice = attractorPx;
   x.attractorScore = FalconClamp(x.residualEnergy*0.40
                      + (x.resolutionState==RES_UNRESOLVED?30.0:x.resolutionState==RES_PARTIALLY_RESOLVED?20.0:5.0)
                      + (attractorPx!=0?MathMax(0.0,30.0-MathAbs(gClose[1]-attractorPx)/MathMax(p.atr,1e-10)*5.0):0.0),0,100);

   if(x.resolutionState!=ie_prevRes){ FalconPublish(EVT_RESOLUTION_CHANGE,x.resolutionState); ie_prevRes=x.resolutionState; }
}

//------------------------------------------------------------------
// BELIEF ENGINE — smoothed continuous beliefs (LETRA Section 12A).
//------------------------------------------------------------------
void IE_Beliefs(FalconIntelligence &x)
{
   FalconPhysics p=g_state.physics;
   FalconWave w=g_state.wave;
   FalconLiquidity lq=g_state.liquidity;
   double wp=w.completion;
   double expObs=IE_ExpansionScore(), decObs=IE_DecayScore(), curObs=IE_CurvatureScore(), absObs=IE_AbsorptionScore(), liqObs=IE_LiquidityScore();
   bool preConv = p.bullDecay||p.bearDecay;
   bool induct  = (w.direction==DIR_LONG && p.bearImpulse && g_state.structure.trend==DIR_LONG)||
                  (w.direction==DIR_SHORT&& p.bullImpulse && g_state.structure.trend==DIR_SHORT);
   bool liqEv   = liqObs>50.0 && decObs>40.0;

   double expMult = (wp<40.0?1.20:wp<60.0?0.80:0.50);
   double rawExp = FalconClamp((expObs*0.45+((p.bullImpulse||p.bearImpulse)?30.0:0.0)+(p.efficiency>g_cfg.effThresh*1.1?15.0:0.0))*expMult,0,100);
   double convMult=(wp>=30.0&&wp<=65.0?1.30:0.70);
   double rawConv=FalconClamp((decObs*0.30+curObs*0.25+(preConv?15.0:0.0)+(induct?10.0:0.0)+(liqEv?5.0:0.0)+g_state.convexity.maturity*0.08)*convMult,0,100);
   double creatMult=(wp>=45.0&&wp<=68.0?1.40:0.60);
   double rawCreate=FalconClamp(((g_state.convexity.maturity>50?g_state.convexity.maturity*0.12:0.0)+(decObs>60?decObs*0.20:0.0)+(liqObs>50?liqObs*0.20:0.0)+(absObs>20?absObs*0.15:0.0))*creatMult,0,100);
   double rawAbs=FalconClamp(absObs*0.50+(p.efficiency<g_cfg.effThresh*0.6?25.0:0.0)+(p.displacement<g_cfg.dispThresh*0.5?15.0:0.0),0,100);
   double rawRetr=FalconClamp(((w.direction==DIR_LONG&&p.bearImpulse)||(w.direction==DIR_SHORT&&p.bullImpulse)?45.0:0.0)+(rawAbs>50?rawAbs*0.30:0.0)+(curObs>40?15.0:0.0),0,100);
   double rawRet=FalconClamp((w.flipTop!=0&&gClose[1]<=w.flipTop&&gClose[1]>=w.flipBot?35.0:0.0)+(rawRetr>60?rawRetr*0.30:0.0)+(lq.score>50?lq.score*0.15:0.0)+((lq.sweepBull||lq.sweepBear)?20.0:0.0),0,100);

   int sm=g_cfg.beliefSmooth;
   ie_bExp   =FalconEMA(ie_bExp,rawExp,sm);
   ie_bConv  =FalconEMA(ie_bConv,rawConv,sm);
   ie_bCreate=FalconEMA(ie_bCreate,rawCreate,sm);
   ie_bAbs   =FalconEMA(ie_bAbs,rawAbs,sm);
   ie_bRetr  =FalconEMA(ie_bRetr,rawRetr,sm);
   ie_bRet   =FalconEMA(ie_bRet,rawRet,sm);

   x.beliefExpansion =ie_bExp;
   x.beliefConvexity =ie_bConv;
   x.beliefCreation  =ie_bCreate;
   x.beliefAbsorption=ie_bAbs;
   x.beliefRetracement=ie_bRetr;
   x.beliefReturn    =ie_bRet;
}

//------------------------------------------------------------------
// RECURSIVE FORECAST + GEOMETRY (RFE/FGE) — PREDICTIVE, not descriptive.
// Output: expected loops remaining, failure-swing prob, immediate-
// execution prob — derived from geometry (distance/compression/
// velocity/convexity/curvature). Per spec v10: predict what is
// physically possible from here.
//------------------------------------------------------------------
void IE_Forecast(FalconIntelligence &x)
{
   FalconPhysics p=g_state.physics;
   FalconWave w=g_state.wave;
   FalconConvexity cv=g_state.convexity;
   double atr=MathMax(p.atr,1e-10);

   double distToTarget = (w.objective!=0)? MathAbs(w.objective-gClose[1])/atr : 4.0;
   double compression  = p.compression/100.0;          // 0..1
   double velNorm      = MathMin(MathAbs(p.velocity)/MathMax(atr*0.15,1e-10),1.0);
   double convexNorm   = MathMin(MathAbs(p.convexitySmooth)/MathMax(atr*g_cfg.convMult*2.0,1e-10),1.0);

   // high compression -> many tiny recursive loops; low -> few large
   x.expectedLoopsRemaining = FalconClamp(distToTarget*(0.5+compression*2.5),0,12);

   // failure-swing probability: rises with residual energy against direction + low velocity into target
   x.failureSwingProb = FalconClamp((x.residualEnergy*0.5 + (1.0-velNorm)*40.0
                        + (g_state.network.pressureDir!=DIR_NONE && g_state.network.pressureDir!=w.direction?20.0:0.0))/100.0,0,1);

   // immediate-execution probability: close to attractor, energy spent into the zone, geometry capacity low
   double proximity = (x.attractorPrice!=0)? MathMax(0.0,1.0-MathAbs(gClose[1]-x.attractorPrice)/(atr*3.0)):0.0;
   x.immediateExecutionProb = FalconClamp(proximity*0.45 + (cv.geometryCapacity<30?0.30:0.0)
                              + (x.dissipationProgress>60?0.25:0.0),0,1);

   // CONTINUOUS EXECUTION PROBABILITY (the law: this drives decisions, not phase)
   // Combines ownership · maturity · geometry · destination · recursion.
   // NOTE: a raw 5-way product collapses toward zero (0.7^5 ~ 0.17) and can
   // essentially never exceed 0.90, so the engine would never arm. Instead we
   // use a calibrated WEIGHTED BLEND, and preserve the multiplicative SPIRIT
   // with a "weakest-link" veto: if ownership/geometry/recursion are weak, the
   // probability is capped (a single broken pillar still kills the shot).
   double ownership   = g_state.htf.alignment/100.0;
   double maturity     = FalconClamp(cv.maturity/100.0,0,1);
   double geometry     = FalconClamp(cv.geometryCapacity/100.0,0,1); // ROOM TO TARGET — entries need room, not exhaustion
   double destination  = FalconClamp(x.attractorScore/100.0,0,1);
   double recursion    = FalconClamp(1.0 - x.failureSwingProb,0,1);

   double blend   = 0.30*ownership + 0.20*maturity + 0.20*geometry + 0.15*destination + 0.15*recursion;
   double weakest = MathMin(ownership, MathMin(geometry, recursion));
   double veto    = FalconClamp(0.45 + 0.55*weakest, 0, 1); // weak core pillar caps conviction
   x.executionProbability = FalconClamp(blend*veto, 0, 1);
   // a clean immediate magnet can arm directly
   x.executionProbability = FalconClamp(MathMax(x.executionProbability, x.immediateExecutionProb*ownership),0,1);
}

//------------------------------------------------------------------
// INTENT / TIMING / OPPORTUNITY descriptors (human-readable OUTPUTS).
//------------------------------------------------------------------
void IE_Narrative(FalconIntelligence &x)
{
   FalconWave w=g_state.wave;
   int phase=w.phase;
   double wp=w.completion;

   x.timing = (phase==PH_DEMAND_RETURN||phase==PH_SUPPLY_RETURN||x.resolutionState==RES_RESOLVED)?"RESOLVED":
              wp<15?"VERY EARLY":wp<35?"EARLY":wp<55?"DEVELOPING":wp<80?"MID CYCLE":wp<96?"LATE":"TERMINAL";

   x.intent = (phase==PH_EXPANSION)?"EXPANSION":
              (phase==PH_EXP_PRECONVEXITY)?"CONTINUATION":
              (phase==PH_EXP_INDUCTION||phase==PH_INDUCTION)?"RESOLUTION":
              (phase==PH_EXP_LIQUIDITY||phase==PH_LIQUIDATION||phase==PH_NEW_HIGH||phase==PH_NEW_LOW)?"DELIVERY":
              (phase==PH_RETRACEMENT)?"RETRACEMENT":
              (phase==PH_DEMAND_RETURN||phase==PH_SUPPLY_RETURN)?"RETURN":"BALANCE";

   x.story = FalconDirStr(w.direction)+" wave "+DoubleToString(wp,0)+"% — "+FalconPhaseStr(phase)
             +" · "+FalconResStr(x.resolutionState)+" · intent "+x.intent;
}

//------------------------------------------------------------------
// HYPOTHESIS ENGINE — forms the current leading market hypothesis from
// the belief field + owner curve. "What is most likely happening?"
//------------------------------------------------------------------
void IE_Hypothesis(FalconIntelligence &x)
{
   FalconWave w=g_state.wave;
   int ownerDir=g_state.curve.ownerDir;

   // pick the dominant belief
   double bMax=x.beliefExpansion; string label="Expansion continuation"; int dir=w.direction;
   if(x.beliefRetracement>bMax){ bMax=x.beliefRetracement; label="Retracement into zone"; }
   if(x.beliefCreation>bMax){ bMax=x.beliefCreation; label="New cycle creation"; }
   if(x.beliefAbsorption>bMax){ bMax=x.beliefAbsorption; label="Absorption / stall"; }
   if(x.beliefReturn>bMax){ bMax=x.beliefReturn; label="Return from zone"; dir=-w.direction; }
   if(x.beliefConvexity>bMax){ bMax=x.beliefConvexity; label="Convexity transfer"; }

   x.hypothesis    = FalconDirStr(ownerDir!=DIR_NONE?ownerDir:dir)+" — "+label;
   x.hypothesisDir = (ownerDir!=DIR_NONE?ownerDir:dir);
   x.hypothesisProb= FalconClamp(bMax/100.0,0,1);
}

//------------------------------------------------------------------
// PREDICTION ENGINE — projects the next destination price + the
// probability of reaching it, using the owner-driven FEZ/FRZ and the
// predictive forecast (NOT a phase label).
//------------------------------------------------------------------
void IE_Prediction(FalconIntelligence &x)
{
   FalconFEZ fz=g_state.fez;
   FalconFRZ fr=g_state.frz;
   int hd=x.hypothesisDir;

   double dest=0; string what="";
   if(x.resolutionState==RES_UNRESOLVED && fz.active)
   {
      dest=(fz.top+fz.bot)*0.5; what="engage "+FalconDirStr(fz.dir)+" liquidity";
   }
   else if(fr.active)
   {
      dest=fr.targetPrice; what="return to owner "+FalconDirStr(fr.dir)+" origin";
   }
   else
   {
      dest=g_state.wave.objective; what="wave objective";
   }

   x.predictionPrice = dest;
   x.prediction      = what+(dest!=0?(" @ "+DoubleToString(dest,_Digits)):"");
   // probability blends immediate-execution proximity, exec prob and owner alignment
   x.predictionProb  = FalconClamp(0.45*x.immediateExecutionProb + 0.35*x.executionProbability
                       + 0.20*(g_state.htf.alignment/100.0),0,1);
}

//------------------------------------------------------------------
// VALIDATION ENGINE — checks whether the PRIOR bar's prediction is
// being confirmed by price, and rolls a hit-rate score. Closes the
// belief → hypothesis → prediction → validation loop.
//------------------------------------------------------------------
void IE_Validation(FalconIntelligence &x)
{
   double close1=gClose[1];
   double atr=MathMax(g_state.physics.atr,1e-10);

   // MULTI-BAR FORWARD TEST: a prediction is confirmed if price travels a
   // meaningful distance (>=0.5 ATR) in the predicted direction within a
   // horizon; it is a miss if the horizon elapses without that move. This
   // replaces the noisy single-bar check that pinned the score low in ranges.
   if(ie_predActive)
   {
      double move = close1 - ie_predPendClose;
      double favorable = (ie_predPendDir==DIR_LONG ? move : -move);
      bool resolved=false, hit=false;
      if(favorable >= atr*0.5){ resolved=true; hit=true; }
      else
      {
         ie_predBarsLeft--;
         if(ie_predBarsLeft<=0){ resolved=true; hit=(favorable>0.0); }
      }
      if(resolved)
      {
         ie_valScore = FalconEMA(ie_valScore, hit?100.0:0.0, 8);
         x.validated = hit;
         ie_predActive=false;
      }
   }
   // open a new forward-test when none is pending and we have a prediction
   if(!ie_predActive && x.predictionPrice!=0.0)
   {
      ie_predPendDir   = (x.predictionPrice>close1?DIR_LONG:DIR_SHORT);
      ie_predPendClose = close1;
      ie_predBarsLeft  = 6;          // horizon in bars
      ie_predActive    = true;
   }
   x.validationScore = FalconClamp(ie_valScore,0,100);
}

//------------------------------------------------------------------
// LIQUIDATION WAVE ENGINE — verbatim port of F16 Engine 1A.7. Tracks
// the pre-objective liquidation toward the owner target and classifies
// the terminal sub-sequence (Push -> Displacement -> Induction ->
// Terminal Liquidation -> Objective Arrival), plus the confirmed
// terminal CHoCH. This is F16's NATIVE entry-sequence mechanism — the
// entry cycle keys off it instead of a re-derived heuristic.
//------------------------------------------------------------------
void IE_LiquidationWave(FalconIntelligence &x, FalconEntryCycle &ec)
{
   FalconWave w=g_state.wave;
   FalconPhysics p=g_state.physics;
   double close1=gClose[1];
   double atr=MathMax(p.atr,1e-10);

   bool isRetr = (w.phase==PH_INDUCTION);                       // retracement-side induction
   bool arm    = (w.phase==PH_EXP_INDUCTION || isRetr);
   double obj  = w.objective;

   if(arm && !ie_liqActive && obj!=0)
   {
      ie_liqActive  = true;
      ie_liqIsRetr  = isRetr;
      ie_liqTarget  = obj;
      ie_liqDir     = (obj>close1?DIR_LONG:DIR_SHORT);
      ie_liqInitDist= MathMax(MathAbs(obj-close1), atr*0.5);
   }
   if(ie_liqActive && obj!=0) ie_liqTarget=obj;

   double remain = (ie_liqActive)? MathAbs(ie_liqTarget-close1) : 0.0;
   double distPct= (ie_liqActive && ie_liqInitDist>0)? MathMin(100.0, remain/ie_liqInitDist*100.0) : 100.0;

   bool capExh   = (x.dissipationProgress>60.0 || g_state.convexity.maturity>60.0);
   bool resolved = (x.resolutionState==RES_RESOLVED);
   bool energyLo = (p.efficiency < g_cfg.effThresh*0.7);
   bool magnet   = (ie_liqActive && distPct<20.0);
   bool arrStruct= (ie_liqActive && (ie_liqDir==DIR_LONG? close1>=ie_liqTarget : close1<=ie_liqTarget));
   bool arrPhys  = (capExh && (resolved || magnet));
   bool objArr   = (arrStruct && energyLo && arrPhys);
   bool counterBOS=(ie_liqDir==DIR_LONG? g_state.structure.bos==DIR_SHORT : g_state.structure.bos==DIR_LONG);
   bool trueChoch= (objArr && counterBOS && energyLo && resolved);

   string sub = (!ie_liqActive)?"" :
                objArr?"Objective Arrival" :
                (magnet && energyLo)?"Terminal Liquidation" :
                (g_state.convexity.maturity>40.0 || x.dissipationProgress>40.0)?"Induction" :
                (distPct<70.0)?"Displacement" :
                (distPct<95.0)?"Push":"Initialization";

   bool inWindow = (w.phase==PH_EXP_INDUCTION||w.phase==PH_EXP_LIQUIDITY||w.phase==PH_INDUCTION||w.phase==PH_LIQUIDATION||w.phase==PH_TERMINAL_CURVE);
   if(ie_liqActive && (!inWindow || (objArr && trueChoch))) ie_liqActive=false;

   ec.liqActive    = ie_liqActive;
   ec.liqDistPct   = distPct;
   ec.liqObjArrival= objArr;
   ec.liqTrueChoch = trueChoch;
   ec.liqSubPhase  = sub;
}

//------------------------------------------------------------------
// ENTRY CYCLE ENGINE — the build-vs-execute brain (F72 model).
//   Markets are recursive curves. The job is NOT "what phase?" but:
//   who owns price, are we BUILDING or TERMINAL, how much curve
//   remains, and HAS THE ENTRY CYCLE BEGUN. Entries only occur in the
//   terminal region (the wave's own HTF flip / supply-demand), after
//   the recursive transition matures — never during expansion. This
//   is what stops the engine chasing an expansion into the opposite
//   extreme (e.g. shorting the demand low).
//------------------------------------------------------------------
void IE_EntryCycle(FalconIntelligence &x)
{
   FalconEntryCycle ec;
   FalconWave  w  = g_state.wave;
   FalconPhysics p= g_state.physics;
   FalconConvexity cv=g_state.convexity;
   FalconSupplyDemand sd=g_state.supplyDemand;
   FalconHTF h=g_state.htf;
   double atr=MathMax(p.atr,1e-10);

   // --- COMPRESSION REGIME (matters most near terminals) ---
   double comp=p.compression;
   ec.compressionRegime = comp<25?COMP_LOW : comp<50?COMP_MEDIUM : comp<75?COMP_HIGH : COMP_EXTREME;

   // --- CURVE OWNERSHIP (who owns price) ---
   ec.ownerTF = h.ownerTF;
   for(int i=0;i<7;i++) ec.ownerPct[i]=0.0;
   int agree=0;
   for(int i=0;i<7;i++) if(h.dir[i]==h.stackDir && h.stackDir!=DIR_NONE) agree++;
   for(int i=0;i<7;i++)
      ec.ownerPct[i] = (agree>0 && h.dir[i]==h.stackDir)? (100.0/agree) : 0.0;

   // --- TRANSITION COMPLETE (the high transition / dominance transfer) ---
   ec.transitionComplete = (w.dominanceTransfer>=50.0);

   // --- BUILDING vs TERMINAL ---
   // Terminal = price has reached the wave's own terminal region: the HTF
   // flip-zone phase band (9..14) OR sitting inside the matching supply/demand.
   bool terminalPhase = (w.phase>=PH_HTF_FLIP_ZONE);
   bool inZone        = (sd.activeZone!=DIR_NONE);
   ec.terminal  = (terminalPhase || inZone);
   ec.building  = !ec.terminal;

   // --- REMAINING CURVE BUDGET + EXPECTED RECURSION DEPTH ---
   // budget = distance-to-target / convexity-width / compression. High
   // compression shrinks the budget -> fewer/smaller recursions (failure
   // swing + tiny cycles); low compression -> big loops.
   double dist = (w.objective!=0)? MathAbs(w.objective-gClose[1])/atr : MathMax(cv.geometryCapacity/25.0,0.1);
   double cw   = MathMax(cv.convexityWidth/atr, 0.25);
   double compFactor = 1.0 + comp/50.0;
   ec.remainingBudget = dist/(cw*compFactor);
   ec.expectedDepth   = FalconClamp(ec.remainingBudget, 0, 4);
   ec.recursionDepth  = w.recursionBreaks;

   // --- LIQUIDATION WAVE (F16 native terminal sequence) ---
   IE_LiquidationWave(x, ec);

   // --- READINESS LADDER ---
   int rd;
   if(ec.building && w.completion<60.0)              rd=ER_NOT_READY;
   else if(ec.building)                              rd=ER_EARLY;
   else if(w.phase==PH_HTF_FLIP_ZONE)                rd=ER_BUILDING;
   else if(w.phase==PH_INDUCTION||w.phase==PH_LIQUIDATION) rd=ER_PRE_ENTRY;
   else if(w.phase==PH_TERMINAL_CURVE||w.phase==PH_DEMAND_RETURN||w.phase==PH_SUPPLY_RETURN) rd=ER_ENTRY_ACTIVE;
   else                                              rd=ER_BUILDING;
   // F16 liquidation-wave overrides: terminal liquidation / objective arrival /
   // confirmed terminal CHoCH ARE the entry cycle. Use them directly.
   if(ec.liqSubPhase=="Terminal Liquidation" && rd<ER_PRE_ENTRY) rd=ER_PRE_ENTRY;
   if(ec.liqObjArrival || ec.liqTrueChoch) rd=ER_ENTRY_ACTIVE;
   ec.readiness = rd;

   // entry cycle is active on F16's native terminal arrival/CHoCH, or once the
   // terminal phase band confirms the return.
   bool cycleGo = (ec.liqObjArrival || ec.liqTrueChoch
                   || w.phase==PH_DEMAND_RETURN || w.phase==PH_SUPPLY_RETURN
                   || (rd==ER_ENTRY_ACTIVE && ec.terminal));

   // ATTENTION MODEL (FOCUS): execution may only fire where the market is
   // actually negotiating — at the active node (conversation route) OR inside a
   // supply/demand zone. This narrows the search space from the whole terminal
   // band to the specific node/zone. If attention is disabled (InpAttentionATR<=0)
   // or no node exists, the supply/demand zone alone provides the focus.
   double node = g_state.network.nextNodePrice;
   bool nearNode = (g_cfg.attentionATR>0.0 && node!=0.0
                    && MathAbs(gClose[1]-node) <= atr*g_cfg.attentionATR);
   bool attentionOK = (nearNode || inZone || g_cfg.attentionATR<=0.0);

   ec.entryCycleActive = (cycleGo && attentionOK);
   // entry direction = the wave's continuation/return direction (buy demand in
   // an up-wave, sell supply in a down-wave) — NOT the expansion direction.
   ec.entryDir = w.direction;

   ec.entryCycleProb = FalconClamp(
        (ec.terminal?0.35:0.0)
      + (ec.transitionComplete?0.15:0.0)
      + (ec.liqObjArrival||ec.liqTrueChoch?0.35: ec.liqSubPhase=="Terminal Liquidation"?0.20:0.0)
      + 0.15*x.executionProbability, 0, 1);

   g_state.entryCycle=ec;
}

//==================================================================
// MASTER ENTRY — Intelligence Engine pipeline step
//==================================================================
void IntelligenceEngineRun()
{
   FalconIntelligence x=g_state.intel;
   IE_EnergyResolution(x);
   IE_Beliefs(x);
   IE_Forecast(x);
   IE_Hypothesis(x);
   IE_Prediction(x);
   IE_Validation(x);
   IE_Narrative(x);
   g_state.intel=x;
   IE_EntryCycle(x);   // build-vs-execute brain (reads finalized intel)
   // back-fill campaign remaining energy now that residual is known
   g_state.campaign.remainingEnergy=x.residualEnergy;
}

#endif // FALCON_INTEL_ENGINE_MQH
//+------------------------------------------------------------------+
