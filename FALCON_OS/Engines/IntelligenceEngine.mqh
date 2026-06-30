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
//==================================================================
// REASONING SYSTEMS REMOVED — Belief · Hypothesis · Prediction ·
// Validation · Threat · Opportunity · Intent · Story · Energy
// Resolution are GONE. Reasoning is now the concrete engines only
// (phases · curve tree · campaign ownership · curve locator ·
// structure · true multi-TF) — see IE_ConcreteReason below.
//==================================================================

void IE_LiquidationWave(FalconIntelligence &x, FalconEntryCycle &ec)
{
   FalconWave w=g_state.wave;
   FalconPhysics p=g_state.physics;
   double close1=gClose[1];
   double atr=MathMax(p.atr,1e-10);

   bool isRetr = (w.phase==PH_INDUCTION);                       // retracement-side induction
   bool arm    = (w.phase>=PH_HTF_FLIP_ZONE || w.phase==PH_EXP_INDUCTION);
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
   // RECLAIM TRIGGER: a confirmed CHoCH in the owner/continuation direction while
   // in the terminal zone IS the entry cycle (the turn off supply/demand). This
   // is the reliable on-chart trigger — without it the strict FSM can sit at the
   // flip zone for hundreds of bars and never crawl to the RETURN phase, so no
   // entry ever fires.
   bool reclaim = (g_state.structure.choch==w.direction && w.direction!=DIR_NONE);
   if(ec.terminal && reclaim) rd=ER_ENTRY_ACTIVE;
   ec.readiness = rd;

   // entry cycle is active on a terminal reclaim, F16 liquidation arrival/CHoCH,
   // or once the terminal phase band confirms the return.
   bool cycleGo = (ec.liqObjArrival || ec.liqTrueChoch
                   || (ec.terminal && reclaim)
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

   // ZONE-DIRECTION LAW (buy demand / sell supply, NEVER the opposite extreme):
   // an entry may only fire from the zone that matches its direction. A LONG
   // (buy) is only valid in DEMAND (activeZone==LONG); a SHORT (sell) only in
   // SUPPLY (activeZone==SHORT). Being in the OPPOSITE zone (e.g. selling at a
   // demand low) is hard-blocked — this stops the "sell the low / buy the high"
   // behaviour. With no active zone, a matching node is allowed.
   bool wrongZone = (sd.activeZone!=DIR_NONE && sd.activeZone!=w.direction);
   bool zoneOK    = (sd.activeZone!=DIR_NONE && sd.activeZone==w.direction);
   bool attentionOK = (!wrongZone) && (zoneOK || nearNode || g_cfg.attentionATR<=0.0);

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
// CONCRETE REASONING — the reasoning is the DEEP STRUCTURAL ENGINES,
// not belief/probability blends. confidence / threat / opportunity /
// executionProbability are derived ONLY from: phases, curve tree,
// campaign ownership, curve locator, structure, and true multi-TF.
// The belief / energy-resolution / forecast / hypothesis / prediction
// / validation engines are REMOVED from the decision path (per design
// law: phases are outputs, structure is the reasoning).
//==================================================================
void IE_ConcreteReason(FalconIntelligence &x)
{
   FalconWave         w  = g_state.wave;
   FalconHTF          h  = g_state.htf;
   FalconCurve        c  = g_state.curve;
   FalconCampaign     cm = g_state.campaign;
   FalconStructure    st = g_state.structure;
   FalconConvexity    cv = g_state.convexity;
   FalconCurveLocator cl = g_state.curveLocator;

   int    owner = (cm.owner!=DIR_NONE ? cm.owner : c.ownerDir);   // campaign / curve ownership
   double mtf   = h.alignment;                                    // true multi-TF agreement
   double ctrl  = MathMax(cm.controlScore, c.life);               // ownership control / curve life
   double room  = cv.geometryCapacity;                            // remaining geometry (concrete)
   bool   structAgree = (st.trend==owner && owner!=DIR_NONE);     // structure
   bool   chochAgainst= (owner!=DIR_NONE && st.choch==-owner);
   bool   htfOpposes  = (h.stackDir!=DIR_NONE && owner!=DIR_NONE && h.stackDir!=owner);
   bool   advancing   = (!g_cfg.useCurveLocator) || cl.advancing; // curve locator
   double locPos      = (g_cfg.useCurveLocator ? cl.pos : 0.5);

   // --- belief / energy / forecast fields REMOVED (zeroed; no longer reasoned on) ---
   x.beliefExpansion=0; x.beliefConvexity=0; x.beliefCreation=0;
   x.beliefAbsorption=0; x.beliefRetracement=0; x.beliefReturn=0;
   x.expansionEnergy=0; x.dissipatedEnergy=0; x.dissipationProgress=0;
   x.attractorPrice=0; x.attractorScore=0;

   // residual / resolution derived CONCRETELY from curve geometry + locator
   x.residualEnergy  = FalconClamp(room,0,100);
   x.resolutionState = (locPos>=0.92 ? RES_RESOLVED : locPos>=0.60 ? RES_PARTIALLY_RESOLVED : RES_UNRESOLVED);
   x.failureSwingProb= FalconClamp(((chochAgainst?40.0:0.0)+(htfOpposes?30.0:0.0)
                       +(!advancing?20.0:0.0)+(locPos>=0.85?20.0:0.0))/100.0,0,1);
   x.immediateExecutionProb = FalconClamp((locPos<0.5 && advancing?0.55:0.20)+(structAgree?0.20:0.0),0,1);

   // CONFIDENCE — concrete structural conviction (multi-TF · ownership · structure · locator)
   x.confidence = FalconClamp(0.40*mtf + 0.22*ctrl + (structAgree?14.0:0.0) + (advancing?8.0:0.0)
                  + (h.fractalAgreement?10.0:0.0) - (chochAgainst?25.0:0.0) - (htfOpposes?15.0:0.0),0,100);

   // EXECUTION PROBABILITY — concrete: ownership · multi-TF · room · locator · structure
   double ep = 0.35*(mtf/100.0) + 0.22*(ctrl/100.0) + 0.18*(room/100.0)
             + 0.13*(advancing?1.0:0.0) + 0.12*(structAgree?1.0:0.0);
   ep *= (chochAgainst?0.35:1.0);
   ep *= (locPos>=0.85?0.45:1.0);
   x.executionProbability = FalconClamp(ep,0,1);

   // THREAT / OPPORTUNITY / HYPOTHESIS / PREDICTION / VALIDATION / INTENT / STORY
   // are REMOVED reasoning systems — kept as inert fields only (never reasoned on).
   x.threat=0; x.opportunity=0; x.opportunityGrade="";
   x.hypothesis=""; x.hypothesisDir=DIR_NONE; x.hypothesisProb=0;
   x.prediction=""; x.predictionPrice=0; x.predictionProb=0;
   x.validated=false; x.validationScore=0;
   x.intent=""; x.timing=""; x.story="";
}

//==================================================================
// MASTER ENTRY — Intelligence Engine pipeline step
//==================================================================
void IntelligenceEngineRun()
{
   FalconIntelligence x=g_state.intel;
   IE_ConcreteReason(x);   // reasoning = phases · curve tree · ownership · locator · structure · multi-TF
   g_state.intel=x;
   IE_EntryCycle(x);       // concrete build-vs-execute brain (ownership / terminal / zones)
   g_state.campaign.remainingEnergy = x.residualEnergy;   // = remaining curve geometry
}

#endif // FALCON_INTEL_ENGINE_MQH
//+------------------------------------------------------------------+
