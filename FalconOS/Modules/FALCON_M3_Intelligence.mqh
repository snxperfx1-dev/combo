//+------------------------------------------------------------------+
//| FALCON_M3_Intelligence.mqh                                        |
//| FALCON OS - Module 3: Strategic Intelligence + Decision           |
//| (Source: LETRA + F16)                                             |
//|                                                                   |
//| Reasons and decides. Owns: ERF (EDE/RE/EAE), Belief, Hypothesis,  |
//| Prediction, Validation, Threat, Opportunity, Intent, Story,       |
//| Chief Strategist, Senseei, Master Decision.                       |
//| Produces ONLY: BUY/SELL/WAIT/ATTACK/DEFEND/EXIT/SCALE/NO TRADE.   |
//| Reads gState.* (market+memory), writes gState.erf + gState.intel. |
//+------------------------------------------------------------------+
#property strict

//==================================================================
// ENERGY RESOLUTION FRAMEWORK (EDE -> RE -> EAE) writes gState.erf
//==================================================================
void M3_UpdateERF()
{
   FALCON_ERF e = gState.erf;
   FALCON_WavePhase ph = gState.wave.phase;

   // EDE state from phase
   if(ph==WP_POINT4_ORIGIN||ph==WP_EXPANSION) e.edeState=EDE_ACCUM;
   else if(ph==WP_EXP_PRECONVEXITY) e.edeState=EDE_REL1;
   else if(ph==WP_EXP_INDUCTION) e.edeState=EDE_REL2;
   else if(ph==WP_EXP_LIQUIDITY) e.edeState=EDE_PURGE;
   else if(ph==WP_NEW_HIGH||ph==WP_NEW_LOW) e.edeState=EDE_DELIVER;
   else e.edeState=EDE_RESOLVE;

   double obsDecay=gState.wave.absorption;
   double obsCurv=gState.wave.convexity;
   double obsLiq=gState.wave.liquidation;

   e.expansionEnergy=MathMin(gState.wave.expansion*0.50+
      (gState.physics.bullImpulse||gState.physics.bearImpulse?30.0:0.0)+
      gState.physics.efficiency*20.0,100.0);
   e.dissipatedEnergy=MathMin(
      (e.edeState>=EDE_REL1?obsDecay*0.40:0.0)+
      (e.edeState>=EDE_REL2?obsCurv*0.30:0.0)+
      (e.edeState>=EDE_PURGE?obsLiq*0.30:0.0),100.0);
   e.dissipationProgress=MathMin(
      (e.edeState>=EDE_REL1?25.0:0.0)+(e.edeState>=EDE_REL2?25.0:0.0)+
      (e.edeState>=EDE_PURGE?25.0:0.0)+(e.edeState>=EDE_DELIVER?25.0:0.0),100.0);

   int expCycles=MathMax(1,MathMin(gState.wave.waveDepth+2,4));
   int compCycles=MathMax(0,MathMin(gState.wave.entryCycle,expCycles));
   e.recursiveCompletion=(expCycles>0)?MathMin((double)compCycles/(double)expCycles*100.0,100.0):0;
   e.residualEnergy=MathMax(0.0,e.expansionEnergy-e.dissipatedEnergy);

   bool objReached=(e.edeState>=EDE_DELIVER);
   bool fullDiss=(e.dissipationProgress>=75.0);
   bool absReturned=((ph==WP_DEMAND_RETURN||ph==WP_SUPPLY_RETURN)&&gState.wave.recursiveComplete);
   if(absReturned&&fullDiss&&e.recursiveCompletion>=75.0) e.resolutionState=FR_RESOLVED;
   else if(objReached&&e.dissipationProgress>=50.0) e.resolutionState=FR_PARTIAL;
   else e.resolutionState=FR_UNRESOLVED;

   // EAE attractor
   double atr=gState.physics.atr; double cl=gState.barClose;
   if(gState.wave.direction==0){ e.primaryAttractorPrice=0; }
   else if(e.resolutionState==FR_UNRESOLVED)
      e.primaryAttractorPrice=(gState.wave.direction==1)?
        (gState.wave.flipBot>0?gState.wave.flipBot:cl-atr*2.0):
        (gState.wave.flipTop>0?gState.wave.flipTop:cl+atr*2.0);
   else if(e.resolutionState==FR_PARTIAL)
      e.primaryAttractorPrice=(gState.wave.direction==1)?
        (gState.wave.point4Low>0?gState.wave.point4Low:cl-atr):
        (gState.wave.point4High>0?gState.wave.point4High:cl+atr);
   else e.primaryAttractorPrice=0;
   e.primaryAttractorScore=MathMin(e.residualEnergy*0.40+
      (e.resolutionState==FR_UNRESOLVED?30.0:e.resolutionState==FR_PARTIAL?20.0:5.0)+
      (e.primaryAttractorPrice>0?MathMax(0.0,30.0-MathAbs(cl-e.primaryAttractorPrice)/MathMax(atr,1e-10)*5.0):0.0),100.0);

   e.confidence=MathMin((e.edeState!=EDE_ACCUM?gState.intel.confidence*0.40:20.0)+
      (e.resolutionState==FR_RESOLVED?30.0:e.resolutionState==FR_PARTIAL?20.0:10.0)+
      e.primaryAttractorScore*0.30,100.0);
   e.tradeReadiness=MathMin(
      (e.resolutionState==FR_RESOLVED?40.0:e.resolutionState==FR_PARTIAL?25.0:10.0)+
      e.recursiveCompletion*0.25+(100.0-e.residualEnergy)*0.20+e.confidence*0.15,100.0);
   e.entryGateOpen=(!CfgERFGateEnabled || e.tradeReadiness>=CfgERFEntryThreshold);
   gState.erf=e;
}


//==================================================================
// BELIEF ENGINE (6 simultaneous, EMA smoothed) writes gState.intel
//==================================================================
double m3_convMaturity=0;
void M3_UpdateBelief()
{
   // ERF must run first (beliefs read residual/attractor)
   M3_UpdateERF();

   double wp=gState.wave.completion;
   double atr=gState.physics.atr;
   FALCON_Physics p=gState.physics;
   double obsAbs=gState.wave.absorption, obsLiq=gState.wave.liquidation;
   double obsExp=gState.wave.expansion, obsCurv=gState.wave.convexity;
   bool preConv=(p.bullMomDecay||p.bearMomDecay);
   bool inducEv=(gState.wave.direction==1&&p.bearImpulse&&gState.htf.fractalDir==1)||
                (gState.wave.direction==-1&&p.bullImpulse&&gState.htf.fractalDir==-1);
   m3_convMaturity=FEmaStep(m3_convMaturity,obsCurv,CfgBeliefSmooth);

   double expM=(wp<40.0)?1.20:(wp<60.0)?0.80:0.50;
   double rawExp=MathMin((obsExp*0.45+(p.bullImpulse||p.bearImpulse?30.0:0.0)+
      (p.efficiency>CfgEffThresh*1.1?15.0:0.0)+gState.wave.expansion*0.10)*expM,100.0);
   double convM=(wp>=30.0&&wp<=65.0)?1.30:0.70;
   double rawConv=MathMin((gState.wave.absorption*0.30+obsCurv*0.25+(preConv?15.0:0.0)+
      (inducEv?10.0:0.0)+m3_convMaturity*0.08)*convM,100.0);
   double creatM=(wp>=45.0&&wp<=68.0)?1.40:0.60;
   double rawCreat=MathMin(((m3_convMaturity>50?m3_convMaturity*0.12:0.0)+
      (obsAbs>60?obsAbs*0.20:0.0)+(obsLiq>50?obsLiq*0.20:0.0))*creatM,100.0);
   double rawAbs=MathMin(obsAbs*0.50+(p.efficiency<CfgEffThresh*0.6?25.0:0.0)+
      (p.displacement<CfgDispThresh*0.5?15.0:0.0),100.0);
   double rawRetr=MathMin(((gState.wave.direction==1&&p.bearImpulse)||(gState.wave.direction==-1&&p.bullImpulse)?45.0:0.0)+
      (rawAbs>50?rawAbs*0.30:0.0)+(obsCurv>40?15.0:0.0),100.0);
   bool closeInside=(gState.wave.flipTop>0&&gState.barClose<=gState.wave.flipTop&&gState.barClose>=gState.wave.flipBot);
   double rawDR=MathMin((closeInside?35.0:0.0)+(rawRetr>60?rawRetr*0.30:0.0)+
      (gState.liquidity.heat>50?gState.liquidity.heat*0.15:0.0)+(gState.liquidity.sweepOK?20.0:0.0),100.0);

   FALCON_Intelligence in=gState.intel;
   in.beliefExpansion=FClamp(FEmaStep(in.beliefExpansion,rawExp,CfgBeliefSmooth),0,100);
   in.beliefConvexity=FClamp(FEmaStep(in.beliefConvexity,rawConv,CfgBeliefSmooth),0,100);
   in.beliefCreation=FClamp(FEmaStep(in.beliefCreation,rawCreat,CfgBeliefSmooth),0,100);
   in.beliefAbsorption=FClamp(FEmaStep(in.beliefAbsorption,rawAbs,CfgBeliefSmooth),0,100);
   in.beliefRetracement=FClamp(FEmaStep(in.beliefRetracement,rawRetr,CfgBeliefSmooth),0,100);
   in.beliefDemandReturn=FClamp(FEmaStep(in.beliefDemandReturn,rawDR,CfgBeliefSmooth),0,100);
   gState.intel=in;
}

//==================================================================
// HYPOTHESIS ENGINE  (primary hypothesis = IE1A family)
//==================================================================
void M3_UpdateHypothesis()
{
   FALCON_WavePhase ph=gState.wave.phase;
   FALCON_Intelligence in=gState.intel;
   if(ph==WP_EXPANSION) in.primaryHypothesis="EXPANSION";
   else if(ph==WP_EXP_PRECONVEXITY||ph==WP_EXP_INDUCTION||ph==WP_EXP_LIQUIDITY) in.primaryHypothesis="CONVEXITY FORMING";
   else if(ph==WP_NEW_HIGH||ph==WP_NEW_LOW) in.primaryHypothesis="CREATION FORMING";
   else if(ph==WP_ABSORPTION) in.primaryHypothesis="ABSORPTION";
   else if(ph==WP_RETRACEMENT||ph==WP_RETR_PRECONVEXITY||ph==WP_RETR_INDUCTION||ph==WP_RETR_LIQUIDITY) in.primaryHypothesis="RETRACEMENT";
   else if(ph==WP_DEMAND_RETURN||ph==WP_SUPPLY_RETURN) in.primaryHypothesis="DEMAND/SUPPLY RETURN";
   else in.primaryHypothesis="EXPANSION";
   in.hypothesisConf=gState.wave.confidence;
   gState.intel=in;
}


//==================================================================
// PREDICTION ENGINE  (next phase prediction + probability)
//==================================================================
void M3_UpdatePrediction()
{
   double wp=gState.wave.completion;
   FALCON_Physics p=gState.physics;
   double predExp=(wp<35.0?(35.0-wp)*1.0:0.0)+(gState.intel.beliefExpansion>55?gState.intel.beliefExpansion*0.30:0.0)+(m3_convMaturity<25?20.0:0.0);
   double predConv=(wp>=25.0&&wp<=60.0?30.0:0.0)+(m3_convMaturity>20?m3_convMaturity*0.30:0.0)+(gState.wave.absorption>40?20.0:0.0);
   double predCreat=(m3_convMaturity>55?(m3_convMaturity-55.0)*1.20:0.0)+(gState.liquidity.sweepOK?15.0:0.0);
   double predAbs=(predCreat>50?predCreat*0.40:0.0)+(gState.wave.absorption>35?gState.wave.absorption*0.30:0.0)+(wp>=60.0&&wp<=78.0?15.0:0.0);
   double predRetr=(gState.intel.beliefAbsorption>45?gState.intel.beliefAbsorption*0.35:0.0)+
      ((gState.wave.direction==1&&p.bearImpulse)||(gState.wave.direction==-1&&p.bullImpulse)?25.0:0.0)+(wp>=72.0&&wp<=90.0?20.0:0.0);
   double predDR=(gState.intel.beliefRetracement>45?gState.intel.beliefRetracement*0.35:0.0)+(gState.liquidity.sweepOK?20.0:0.0)+(wp>=88.0?(wp-88.0)*1.20:0.0);
   double mx=MathMax(predExp,MathMax(predConv,MathMax(predCreat,MathMax(predAbs,MathMax(predRetr,predDR)))));
   FALCON_Intelligence in=gState.intel;
   if(predDR>=mx-0.1) in.expectedNextPhase=(gState.wave.direction==-1)?"Supply Return":"Demand Return";
   else if(predRetr>=mx-0.1) in.expectedNextPhase="Retracement";
   else if(predAbs>=mx-0.1) in.expectedNextPhase="Absorption";
   else if(predCreat>=mx-0.1) in.expectedNextPhase=(gState.wave.direction==-1)?"New Low":"New High";
   else if(predConv>=mx-0.1) in.expectedNextPhase="Expansion Pre-Convexity";
   else in.expectedNextPhase="Expansion";
   in.expectedNextProb=(mx>0)?MathMin(mx/MathMax(mx+30.0,1.0)*100.0,95.0):50.0;
   gState.intel=in;
}

//==================================================================
// VALIDATION ENGINE  (rolling prediction accuracy)
//==================================================================
int m3_predOutcomes[100]; int m3_predIdx=0; string m3_lastExpected="Point 4 Origin"; string m3_lastPhase="Point 4 Origin";
void M3_UpdateValidation()
{
   string cur=FALCON_PhaseStr(gState.wave.phase);
   bool trans=(cur!=m3_lastPhase);
   bool ok=(trans && cur==m3_lastExpected);
   if(trans){ m3_predOutcomes[m3_predIdx%100]=ok?1:0; m3_predIdx++; }
   m3_lastExpected=gState.intel.expectedNextPhase; m3_lastPhase=cur;
   int cnt=MathMin(25,m3_predIdx); int sum=0; int start=MathMax(0,m3_predIdx-cnt);
   for(int i=start;i<m3_predIdx;i++) sum+=m3_predOutcomes[i%100];
   FALCON_Intelligence in=gState.intel;
   in.predReliability=(cnt>0)?(double)sum/(double)cnt*100.0:50.0;
   // adaptive confidence
   double inc=(ok?3.0:0.0)+(gState.htf.fractalDir==gState.wave.direction&&gState.wave.direction!=0?1.5:0.0);
   double dec=(trans&&!ok?2.0:0.0)+(gState.htf.fractalDir!=gState.wave.direction&&gState.wave.direction!=0?1.5:0.0);
   in.modelConfidence=FClamp(in.modelConfidence+inc-dec-0.02*(in.modelConfidence-50.0),10,100);
   gState.intel=in;
}


//==================================================================
// DIRECTION PROBABILITY (Bayesian) — feeds opportunity + decision
//==================================================================
void M3_ComputeDirectionProb()
{
   int waveDir=gState.tf[L_M5].direction;
   int htfAlign=(gState.tf[L_H1].direction==gState.tf[L_H4].direction&&gState.tf[L_H1].direction!=0)?gState.tf[L_H1].direction:0;
   int structBias=gState.htf.fractalDir;
   FALCON_Physics p=gState.physics;

   double bStruct=(structBias==waveDir)?0.90:(structBias==0)?0.50:0.15;
   double bMom=0.50;
   if((waveDir==1&&p.velocity>0&&p.acceleration>0)||(waveDir==-1&&p.velocity<0&&p.acceleration<0)) bMom=0.85;
   else if((waveDir==1&&p.velocity>0)||(waveDir==-1&&p.velocity<0)) bMom=0.60; else bMom=0.30;
   double bLiq=(gState.liquidity.heat>70)?0.80:(gState.liquidity.heat>30)?0.55:0.35;
   double bHTF=(htfAlign==waveDir&&htfAlign!=0)?0.90:(htfAlign==0)?0.55:0.20;
   double bDisp=(p.displacement>CfgDispThresh*1.5)?0.85:(p.displacement>CfgDispThresh)?0.65:0.35;
   FALCON_WavePhase ph=gState.wave.phase;
   double bFlip=0.25;
   if(ph==WP_DEMAND_RETURN||ph==WP_SUPPLY_RETURN) bFlip=0.92;
   else if(ph==WP_RETRACEMENT||ph==WP_RETR_PRECONVEXITY) bFlip=0.75;
   else if(gState.wave.completion>=60) bFlip=0.58;

   double w1=0.15,w2=0.14,w3=0.10,w4=0.14,w5=0.11,w6=0.17;
   double lo=
      w1*MathLog(MathMax(bStruct,1e-10)/MathMax(1.0-bStruct,1e-10))+
      w2*MathLog(MathMax(bMom,1e-10)/MathMax(1.0-bMom,1e-10))+
      w3*MathLog(MathMax(bLiq,1e-10)/MathMax(1.0-bLiq,1e-10))+
      w4*MathLog(MathMax(bHTF,1e-10)/MathMax(1.0-bHTF,1e-10))+
      w5*MathLog(MathMax(bDisp,1e-10)/MathMax(1.0-bDisp,1e-10))+
      w6*MathLog(MathMax(bFlip,1e-10)/MathMax(1.0-bFlip,1e-10));

   double confMult=MathMax(0.7,MathMin(gState.intel.modelConfidence/100.0*1.3,1.3));
   double fracBonus=gState.htf.contextScore*0.30;
   double baseTrend=p.efficiency*30.0;
   double impS=(p.displacement>CfgDispThresh)?20.0:0.0;
   double momS=(p.momentum>0)?10.0:-10.0;
   double structS=(structBias==1)?20.0:(structBias==-1)?-20.0:0.0;
   double htfS=(htfAlign==1)?20.0:(htfAlign==-1)?-20.0:0.0;
   bool closeInside=(gState.wave.flipTop>0&&gState.barClose<=gState.wave.flipTop&&gState.barClose>=gState.wave.flipBot);
   double zoneS=closeInside?15.0:0.0;
   double beliefBonus=(gState.intel.beliefDemandReturn>60)?gState.intel.beliefDemandReturn*0.10:0.0;

   FALCON_Intelligence in=gState.intel;
   in.buyProb=FClamp((baseTrend+impS+MathMax(momS,0.0)+MathMax(structS,0.0)+MathMax(htfS,0.0)+zoneS+beliefBonus+(structBias==1?fracBonus:0.0))*confMult,0,100);
   in.sellProb=FClamp((baseTrend+impS+MathMax(-momS,0.0)+MathMax(-structS,0.0)+MathMax(-htfS,0.0)+zoneS+beliefBonus+(structBias==-1?fracBonus:0.0))*confMult,0,100);
   in.netEdge=in.buyProb-in.sellProb;
   if(in.netEdge>25) in.liveDirective="BUY PRESSURE";
   else if(in.netEdge>10) in.liveDirective="BULLISH BIAS";
   else if(in.netEdge<-25) in.liveDirective="SELL PRESSURE";
   else if(in.netEdge<-10) in.liveDirective="BEARISH BIAS";
   else in.liveDirective="NEUTRAL / WAIT";
   gState.intel=in;
}

//==================================================================
// OPPORTUNITY ENGINE (Senseei opportunity scoring)
//==================================================================
void M3_UpdateOpportunity()
{
   M3_ComputeDirectionProb();

   // Senseei 4-voter master bias
   int vt1=gState.tf[L_M5].direction;
   int vt2=gState.htf.fractalDir;
   int vt3=gState.network.bias;
   int vt4=(gState.intel.netEdge>12)?1:(gState.intel.netEdge<-12)?-1:0;
   int sum=vt1+vt2+vt3+vt4;
   int master=(sum>0)?1:(sum<0)?-1:0;
   int cast=(vt1!=0?1:0)+(vt2!=0?1:0)+(vt3!=0?1:0)+(vt4!=0?1:0);
   int forV=0;
   if(master!=0) forV=(vt1==master?1:0)+(vt2==master?1:0)+(vt3==master?1:0)+(vt4==master?1:0);
   double alignment=(cast>0)?(double)forV/(double)cast*100.0:50.0;
   double conflict=(cast>0)?(double)(cast-forV)/(double)cast*100.0:0.0;
   double oppScore=FClamp(alignment*0.40+gState.erf.primaryAttractorScore*0.30+gState.htf.fractalScore*0.30-gState.intel.threat*0.35,0,100);

   FALCON_Intelligence in=gState.intel;
   in.masterBias=master; in.alignment=alignment; in.conflict=conflict; in.opportunityScore=oppScore;
   if(master==0) in.opportunity="NONE";
   else if(conflict>60) in.opportunity="DEVELOPING";
   else if(oppScore<20) in.opportunity="NONE";
   else if(oppScore<40) in.opportunity="DEVELOPING";
   else if(oppScore<62) in.opportunity="GOOD";
   else if(oppScore<82) in.opportunity="STRONG";
   else in.opportunity="EXCEPTIONAL";
   gState.intel=in;
}


//==================================================================
// THREAT ENGINE
//==================================================================
void M3_UpdateThreat()
{
   FALCON_Intelligence in=gState.intel;
   int vt4=(in.netEdge>12)?1:(in.netEdge<-12)?-1:0;
   double threat=FClamp(
      in.conflict*0.40+
      gState.erf.residualEnergy*0.28+
      gState.htf.conflict*0.12+
      (vt4!=0&&vt4!=in.masterBias?18.0:0.0)+
      (gState.erf.resolutionState==FR_PARTIAL?10.0:0.0),0,100);
   in.threat=threat;
   // confidence (depends on threat)
   in.confidence=FClamp(in.alignment*0.40+gState.htf.alignment*0.12+gState.htf.fractalScore*0.18+
      gState.erf.primaryAttractorScore*0.15+MathMin(15.0,gState.network.eligibleCount*1.2)-threat*0.20,0,100);
   gState.intel=in;
}

//==================================================================
// INTENT ENGINE + STORY (timing + intent + narrative)
//==================================================================
void M3_UpdateIntent()
{
   FALCON_Intelligence in=gState.intel;
   FALCON_WavePhase ph=gState.wave.phase;
   double wp=gState.wave.completion;

   // timing
   if(ph==WP_ABSORPTION||gState.erf.resolutionState==FR_RESOLVED) in.timing="RESOLVED";
   else if(wp<15) in.timing="VERY EARLY";
   else if(wp<35) in.timing="EARLY";
   else if(wp<55) in.timing="DEVELOPING";
   else if(wp<80) in.timing="MID CYCLE";
   else if(wp<96) in.timing="LATE";
   else in.timing="TERMINAL";

   // intent
   if(in.conflict>55) in.intent="ABSORPTION";
   else if(ph==WP_EXPANSION) in.intent="EXPANSION";
   else if(ph==WP_EXP_PRECONVEXITY) in.intent="CONTINUATION";
   else if(ph==WP_EXP_INDUCTION||ph==WP_RETR_INDUCTION) in.intent="RESOLUTION";
   else if(ph==WP_EXP_LIQUIDITY||ph==WP_NEW_HIGH||ph==WP_NEW_LOW) in.intent="DELIVERY";
   else if(ph==WP_ABSORPTION) in.intent="ABSORPTION";
   else if(in.masterBias==0) in.intent="BALANCE";
   else in.intent="CONTINUATION";

   // execution probabilities (continuation/reversal/etc)
   int htfSum=gState.tf[L_H1].direction+gState.tf[L_H4].direction;
   int htfBias=(htfSum>0)?1:(htfSum<0)?-1:0;
   int ltfSum=gState.tf[L_M1].direction+gState.tf[L_M3].direction+gState.tf[L_M5].direction;
   int ltfBias=(ltfSum>0)?1:(ltfSum<0)?-1:0;
   bool aligned=(htfBias!=0&&ltfBias==htfBias);
   bool conflict=(htfBias!=0&&ltfBias==-htfBias);
   double cons=gState.htf.fractalScore;
   in.pContinuation=FClamp((aligned?40.0:0.0)+(aligned&&gState.tf[L_H1].phase==WP_EXPANSION?20.0:0.0)+cons*0.25-(conflict?55.0:0.0),0,100);
   in.pReversal=MathMin((conflict?35.0:0.0)+(m3_convMaturity>60?m3_convMaturity*0.15:0.0)+(gState.wave.absorption>40?15.0:0.0),100.0);
   in.pExpansion=MathMin((aligned?cons*0.25:0.0)+(aligned&&gState.wave.expansion>60?35.0:0.0)+(gState.liquidity.sweepOK?15.0:0.0),100.0);
   in.pCreation=MathMin((gState.intel.beliefCreation>50?gState.intel.beliefCreation*0.45:0.0)+(m3_convMaturity>65?20.0:0.0),100.0);
   in.pAbsorption=MathMin((gState.intel.beliefAbsorption>40?gState.intel.beliefAbsorption*0.45:0.0)+(conflict?15.0:0.0)+(gState.wave.absorption>50?20.0:0.0),100.0);
   in.pStandDown=MathMin((htfBias==0?30.0:0.0)+(gState.htf.fractalDir==0?25.0:0.0),100.0);
   double mxp=MathMax(in.pContinuation,MathMax(in.pReversal,MathMax(in.pExpansion,MathMax(in.pCreation,MathMax(in.pAbsorption,in.pStandDown)))));
   if(in.pStandDown>=55) in.execDirective="STAND DOWN";
   else if(conflict&&in.pReversal>=45) in.execDirective="TRANSITION";
   else if(in.pAbsorption>=mxp-0.1) in.execDirective="ABSORPTION - PREPARE REVERSAL";
   else if(in.pReversal>=mxp-0.1) in.execDirective="REVERSAL DOMINANT";
   else if(in.pCreation>=mxp-0.1) in.execDirective="NEW HIGH/LOW FORMING";
   else if(in.pExpansion>=mxp-0.1) in.execDirective="EXPANSION ENTRY";
   else if(in.pContinuation>=mxp-0.1) in.execDirective="CONTINUATION - HOLD";
   else in.execDirective="AWAIT ALIGNMENT";

   // story
   string dirWord=(in.masterBias==1)?"Bullish":(in.masterBias==-1)?"Bearish":"Neutral";
   in.story=dirWord+" "+FALCON_PhaseStr(ph)+" | Prog "+IntegerToString((int)wp)+"% | Stack "+
      IntegerToString((int)gState.htf.fractalScore)+"% | Life "+IntegerToString((int)gState.curve.life);
   gState.intel=in;
}


//==================================================================
// DECISION ENGINE (Chief Strategist / Senseei head)
// The ONLY producer of the 8 verdicts. Execution obeys this.
//==================================================================
void M3_MakeDecision()
{
   FALCON_Intelligence in=gState.intel;
   int master=in.masterBias;
   FALCON_WavePhase ph=gState.wave.phase;
   FALCON_Decision d=DEC_NO_TRADE;

   // Hard guards first
   bool haveOpenRisk=(gState.exec.positionCount>0);
   bool curveDead=(gState.curve.life<=32 && gState.curve.aliveStatus=="DEAD - FLIP");
   bool erfResolved=(gState.erf.resolutionState==FR_RESOLVED && gState.wave.completion>90);

   // 1) EXIT — energy resolved or curve dead while holding
   if(haveOpenRisk && (erfResolved || curveDead))
      d=DEC_EXIT;
   // 2) DEFEND — high threat while holding, no fresh edge
   else if(haveOpenRisk && in.threat>70 && in.opportunity!="STRONG" && in.opportunity!="EXCEPTIONAL")
      d=DEC_DEFEND;
   // 3) SCALE — strong continuation in our favour while holding, curve alive
   else if(haveOpenRisk && in.pContinuation>60 && gState.curve.life>=60 &&
           ((master==1 && gState.exec.longCount>0) || (master==-1 && gState.exec.shortCount>0)))
      d=DEC_SCALE;
   // 4) ATTACK — exceptional aligned opportunity, gate open
   else if(master!=0 && in.conflict<=60 && gState.erf.entryGateOpen &&
           (in.opportunity=="STRONG"||in.opportunity=="EXCEPTIONAL") &&
           in.confidence>=CfgMinConfAttack && in.threat<45)
      d=DEC_ATTACK;
   // 5) BUY/SELL — lifecycle Demand/Supply Return entry, belief-confirmed
   else if(master==1 && ph==WP_DEMAND_RETURN && in.beliefDemandReturn>50 &&
           gState.erf.entryGateOpen && in.netEdge>CfgExecThreshold)
      d=DEC_BUY;
   else if(master==-1 && ph==WP_SUPPLY_RETURN && in.beliefDemandReturn>50 &&
           gState.erf.entryGateOpen && in.netEdge<-CfgExecThreshold)
      d=DEC_SELL;
   // 6) WAIT — bias exists but conditions not ripe
   else if(master!=0)
      d=DEC_WAIT;
   // 7) NO TRADE — no bias
   else
      d=DEC_NO_TRADE;

   in.decision=d;
   // action narrative
   switch(d)
   {
      case DEC_ATTACK: in.actionNarrative="ATTACK - aligned opportunity, gate open"; break;
      case DEC_BUY:    in.actionNarrative="BUY - demand return confirmed"; break;
      case DEC_SELL:   in.actionNarrative="SELL - supply return confirmed"; break;
      case DEC_SCALE:  in.actionNarrative="SCALE - add to winner, curve alive"; break;
      case DEC_DEFEND: in.actionNarrative="DEFEND - threat high, protect position"; break;
      case DEC_EXIT:   in.actionNarrative="EXIT - energy resolved / curve dead"; break;
      case DEC_WAIT:   in.actionNarrative="WAIT - bias forming, await trigger"; break;
      default:         in.actionNarrative="NO TRADE - no directional edge"; break;
   }
   gState.intel=in;

   if(d==DEC_ATTACK||d==DEC_BUY||d==DEC_SELL)
      FALCON_Log(LOG_INFO,"M3.Decision",FALCON_DecisionStr(d)+" master="+IntegerToString(master)+" conf="+DoubleToString(in.confidence,0));
}

//+------------------------------------------------------------------+
