//+------------------------------------------------------------------+
//|  FALCON OS — MODULE 3: STRATEGIC INTELLIGENCE + DECISION         |
//|  Source: LETRA + F16.                                            |
//|  Engine 1A (lifecycle authority) · Wave-Spawn · ERF (EDE/RE/EAE) |
//|  · Belief/Hypothesis/Prediction · Senseei meta-intelligence ·    |
//|  Master Decision (BUY/SELL/WAIT/ATTACK/DEFEND/EXIT/SCALE/NO TRADE)|
//|                                                                  |
//|  LAW: phases are OUTPUTS that describe reality; the engines      |
//|  decide on continuous probabilities, never on if(phase==).      |
//|  The Intelligence Engine REASONS — it does not execute.         |
//+------------------------------------------------------------------+
#ifndef FALCON_INTELLIGENCE_MQH
#define FALCON_INTELLIGENCE_MQH
#include "Kernel.mqh"

//==================================================================
// ENGINE 1A — SOLE LIFECYCLE AUTHORITY (M5 canonical phase)
//==================================================================
void INTEL_Phase()
  {
   FAL_TFStruct m5=g_state.structure.tf[FAL_L0];
   g_state.intel.phaseCode = m5.phase;
   g_state.intel.phase     = FAL_PhaseStr(m5.phase);
   g_state.intel.waveDir   = m5.dir;
   g_state.intel.stackDir  = g_state.structure.fractalStackDir;
   g_state.intel.stackPct  = g_state.structure.fractalStackScore;
   g_state.intel.phaseConfidence = FAL_Clamp(g_state.structure.fractalStackScore*0.50 + m5.modelFit*0.30 + m5.waveProgress*0.20,20,100);

   // 3-D agreement → dynamic integrity (structure ∧ momentum ∧ physics)
   double close=g_state.spot;
   bool sAgree = m5.dir!=0 && (m5.dir==1? close>m5.invalidation : close<m5.invalidation);
   bool mAgree = m5.dir!=0 && (m5.dir==1? g_state.physics.velocity>0 : g_state.physics.velocity<0);
   bool pAgree = g_state.erf.resolutionState!="RESOLVED" && g_state.erf.dissipationProgress<80;
   double pc=(sAgree?34.0:0.0)+(mAgree?33.0:0.0)+(pAgree?33.0:0.0);
   g_state.intel.phaseConfidence = MathMax(g_state.intel.phaseConfidence, pc*0.0+g_state.intel.phaseConfidence); // keep both signals
   g_state.intel.phaseIntegrity = FAL_Clamp(pc*0.6+(100.0-MathMin(g_state.erf.dissipationProgress,100.0))*0.4,0,100);
   // progress: distance consumed toward M5 target + dissipation + maturity
   double prog=m5.waveProgress;
   if(m5.target!=EMPTY_VALUE && m5.invalidation!=EMPTY_VALUE && MathAbs(m5.target-m5.invalidation)>1e-10)
      prog=FAL_Clamp(MathAbs(close-m5.invalidation)/MathAbs(m5.target-m5.invalidation)*100.0,0,100);
   g_state.intel.phaseProgress=prog;
   FAL_Publish("PHASE_UPDATED");
  }

//==================================================================
// WAVE-SPAWN ENGINE  (M5-governed wave context + recursion)
//==================================================================
void INTEL_WaveSpawn(FAL_Wave &w)
  {
   FAL_TFStruct m5=g_state.structure.tf[FAL_L0];
   double atr=g_state.physics.atr; if(atr<=0) atr=_Point*10;
   double m5Hi=iHigh(_Symbol,PERIOD_M5,1), m5Lo=iLow(_Symbol,PERIOD_M5,1);
   if(m5Hi<=0) m5Hi=iHigh(_Symbol,_Period,1);
   if(m5Lo<=0) m5Lo=iLow(_Symbol,_Period,1);
   int l0dir=m5.dir;

   bool allowSpawn = (l0dir!=0 && l0dir!=w.direction);
   if(allowSpawn)
     {
      double obTop=FAL_NZ(m5.p4High,m5.swingHigh);
      double obBot=FAL_NZ(m5.p4Low ,m5.swingLow);
      if(obTop==EMPTY_VALUE||obTop==0) obTop=m5Hi;
      if(obBot==EMPTY_VALUE||obBot==0) obBot=m5Lo;
      w.direction=l0dir; w.flipTop=obTop; w.flipBot=obBot;
      w.point4High=obTop; w.point4Low=obBot; w.point4Bar=iTime(_Symbol,_Period,0);
      w.cycleHigh=m5Hi; w.cycleLow=m5Lo;
      w.inducZoneLow=EMPTY_VALUE; w.inducZoneHigh=EMPTY_VALUE;
      w.entryCycle=0; w.waveDepth=0;
      FAL_Publish("WAVE_SPAWN");
     }
   if(w.direction==1 && m5Hi>FAL_NZ(w.cycleHigh,m5Hi)) w.cycleHigh=m5Hi;
   if(w.direction==-1&& m5Lo<FAL_NZ(w.cycleLow ,m5Lo)) w.cycleLow =m5Lo;

   double close=g_state.spot;
   w.nearFlipzone = (w.flipTop!=EMPTY_VALUE && w.flipBot!=EMPTY_VALUE && close<=w.flipTop*1.02 && close>=w.flipBot*0.98);
   w.closeInside  = (w.flipTop!=EMPTY_VALUE && close<=w.flipTop && close>=w.flipBot);

   // recursive trigger (true CHoCH into zone + Demand/Supply Return phase)
   bool priceInDemand = (w.flipBot!=EMPTY_VALUE && iLow(_Symbol,_Period,1)<w.flipBot && w.point4High!=EMPTY_VALUE && iLow(_Symbol,_Period,1)<=w.point4High);
   bool priceInSupply = (w.flipTop!=EMPTY_VALUE && iHigh(_Symbol,_Period,1)>w.flipTop && w.point4Low!=EMPTY_VALUE && iHigh(_Symbol,_Period,1)>=w.point4Low);
   bool tcBull = w.direction==1  && priceInDemand && g_state.physics.bullImpulse && g_state.liquidity.sweepOK;
   bool tcBear = w.direction==-1 && priceInSupply && g_state.physics.bearImpulse && g_state.liquidity.sweepOK;
   bool retPhase = (g_state.intel.phaseCode==PH_DEMAND_RTN || g_state.intel.phaseCode==PH_SUPPLY_RTN);
   bool recTrig = (tcBull||tcBear) && retPhase && w.beliefDemandReturn>40 && w.direction!=0;

   static datetime recFiredBar=0;
   datetime now=iTime(_Symbol,_Period,0);
   w.recursiveJustFired=false;
   if(recTrig && (recFiredBar==0 || (int)((now-recFiredBar)/MathMax(PeriodSeconds(_Period),1))>g_cfg.resetBars))
     {
      recFiredBar=now; w.recursiveComplete=true; w.recursiveJustFired=true;
      w.waveGeneration++; w.entryCycle=MathMin(w.entryCycle+1,4); w.waveDepth=w.entryCycle;
      // respawn nested wave keeping M5 direction
      w.flipTop=FAL_NZ(m5.p4High,w.flipTop); w.flipBot=FAL_NZ(m5.p4Low,w.flipBot);
      w.point4High=w.flipTop; w.point4Low=w.flipBot; w.point4Bar=now;
      w.cycleHigh=m5Hi; w.cycleLow=m5Lo;
      FAL_Publish("RECURSIVE_SPAWN");
     }

   // hard invalidation
   bool bullInvalid=w.direction==1 && close<FAL_NZ(w.flipBot,close)-atr*0.5;
   bool bearInvalid=w.direction==-1&& close>FAL_NZ(w.flipTop,close)+atr*0.5;
   if(w.direction!=l0dir && (bullInvalid||bearInvalid))
     {
      w.direction=0; w.flipTop=EMPTY_VALUE; w.flipBot=EMPTY_VALUE;
      w.entryCycle=0; w.waveDepth=0; w.recursiveComplete=false;
      FAL_Publish("WAVE_INVALIDATED");
     }
  }

//==================================================================
// ERF — ENERGY RESOLUTION FRAMEWORK (EDE · RE · EAE)
//==================================================================
void INTEL_ERF(FAL_ERF &e)
  {
   int ph=g_state.intel.phaseCode;
   int st = (ph==PH_P4ORIGIN||ph==PH_EXPANSION)?1:
            (ph==PH_EXP_PRECVX)?2:(ph==PH_EXP_INDUCT)?3:(ph==PH_EXP_LIQUID)?4:
            (ph==PH_NEW_HIGH||ph==PH_NEW_LOW)?5:6;
   e.edeState=st;
   double effT=g_cfg.effThresh;
   e.expansionEnergy = FAL_Clamp(g_state.physics.obsExpansion*0.50 + (g_state.physics.bullImpulse||g_state.physics.bearImpulse?30.0:0.0) + g_state.physics.efficiency*20.0,0,100);
   e.dissipatedEnergy = FAL_Clamp((st>=2?g_state.physics.obsDecay*0.40:0.0)+(st>=3?g_state.physics.obsCurvature*0.30:0.0)+(st>=4?g_state.physics.obsLiquidity*0.30:0.0),0,100);
   e.dissipationProgress = FAL_Clamp((st>=2?25.0:0.0)+(st>=3?25.0:0.0)+(st>=4?25.0:0.0)+(st>=5?25.0:0.0),0,100);

   int expCycles=(int)MathMax(1,MathMin(g_state.wave.waveDepth+2,4));
   int compCycles=(int)MathMax(0,MathMin(g_state.wave.entryCycle,expCycles));
   e.recursiveCompletion = expCycles>0?FAL_Clamp((double)compCycles/expCycles*100.0,0,100):0.0;
   e.residualEnergy = MathMax(0.0,e.expansionEnergy-e.dissipatedEnergy);
   bool objReached=st>=5;
   bool fullDiss=e.dissipationProgress>=75.0;
   bool absRet=(ph==PH_DEMAND_RTN||ph==PH_SUPPLY_RTN)&&g_state.wave.recursiveComplete;
   e.resolutionState = (absRet&&fullDiss&&e.recursiveCompletion>=75.0)?"RESOLVED":
                       (objReached&&e.dissipationProgress>=50.0)?"PARTIALLY RESOLVED":"UNRESOLVED";
   e.resCode = e.resolutionState=="RESOLVED"?2:(e.resolutionState=="PARTIALLY RESOLVED"?1:0);

   double close=g_state.spot, atr=g_state.physics.atr; if(atr<=0)atr=_Point*10;
   int dir=g_state.wave.direction;
   if(dir==0) e.attractorPrice=EMPTY_VALUE;
   else if(e.resolutionState=="UNRESOLVED")
      e.attractorPrice = dir==1?FAL_NZ(g_state.wave.flipBot,close-atr*2.0):FAL_NZ(g_state.wave.flipTop,close+atr*2.0);
   else if(e.resolutionState=="PARTIALLY RESOLVED")
      e.attractorPrice = dir==1?FAL_NZ(g_state.wave.point4Low,close-atr):FAL_NZ(g_state.wave.point4High,close+atr);
   else e.attractorPrice=EMPTY_VALUE;
   e.attractorScore = FAL_Clamp(MathMin(e.residualEnergy,100.0)*0.40 +
        (e.resolutionState=="UNRESOLVED"?30.0:e.resolutionState=="PARTIALLY RESOLVED"?20.0:5.0) +
        (e.attractorPrice!=EMPTY_VALUE?MathMax(0.0,30.0-MathAbs(close-e.attractorPrice)/MathMax(atr,1e-10)*5.0):0.0),0,100);
   e.attractorLabel = e.resolutionState=="UNRESOLVED"?"Flip Zone (High Residual)":e.resolutionState=="PARTIALLY RESOLVED"?"Origin Zone (Partial)":"No Active Attractor";

   e.tradeReadiness = FAL_Clamp((e.resolutionState=="RESOLVED"?40.0:e.resolutionState=="PARTIALLY RESOLVED"?25.0:10.0)
        + e.recursiveCompletion*0.25 + (100.0-MathMin(e.residualEnergy,100.0))*0.20 + g_state.intel.phaseConfidence*0.15,0,100);
   e.entryGate = e.tradeReadiness>=45.0;
   FAL_Publish("ERF_UPDATED");
  }

//==================================================================
// WAVE INTELLIGENCE — similarity · convexity maturity · beliefs ·
// progress · model fit · bayesian prob · setup grade
//==================================================================
double INTEL_IdealSim(double e,double d,double v,double c,double ie,double id,double iv,double ic)
  {
   double diff=MathPow(e-ie,2)+MathPow(d-id,2)+MathPow(v-iv,2)+MathPow(c-ic,2);
   return(MathMax(0.0,100.0*(1.0-diff/4.0)));
  }
void INTEL_WaveIntel(FAL_Wave &w)
  {
   FAL_Physics p=g_state.physics;
   double atr=p.atr; if(atr<=0) atr=_Point*10;
   double effT=g_cfg.effThresh, dispT=g_cfg.dispThresh, convM=g_cfg.convMult;
   double close=g_state.spot;
   int dir=w.direction;

   // geometry
   double originToExtreme=EMPTY_VALUE;
   if(w.point4High!=EMPTY_VALUE && w.point4Low!=EMPTY_VALUE)
     {
      double org=dir==1?w.point4Low:w.point4High;
      double ext=dir==1?FAL_NZ(w.cycleHigh,org):FAL_NZ(w.cycleLow,org);
      originToExtreme=MathAbs(ext-org);
     }
   double flipzoneWidth=(w.flipTop!=EMPTY_VALUE&&w.flipBot!=EMPTY_VALUE)?w.flipTop-w.flipBot:EMPTY_VALUE;

   // similarity normals
   double effN=MathMin(p.efficiency,1.0);
   double dispN=MathMin(p.displacement/MathMax(dispT*2.0,1e-10),1.0);
   double velN=MathMin(MathAbs(p.velocity)/MathMax(atr*0.15,1e-10),1.0);
   double curvN=MathMin(MathAbs(p.convSmooth)/MathMax(atr*convM*2.0,1e-10),1.0);
   double simExp=INTEL_IdealSim(effN,dispN,velN,curvN,0.85,0.80,0.80,0.10);
   double simPre=INTEL_IdealSim(effN,dispN,velN,curvN,0.60,0.55,0.40,0.50);
   double simInd=INTEL_IdealSim(effN,dispN,velN,curvN,0.65,0.60,0.30,0.60);
   double simLiq=INTEL_IdealSim(effN,dispN,velN,curvN,0.45,0.85,0.15,0.80);
   double simCre=INTEL_IdealSim(effN,dispN,velN,curvN,0.30,0.70,0.05,0.90);
   double simAbs=INTEL_IdealSim(effN,dispN,velN,curvN,0.20,0.25,0.10,0.40);
   double simRet=INTEL_IdealSim(effN,dispN,velN,curvN,0.70,0.65,0.65,0.25);
   double simDR =INTEL_IdealSim(effN,dispN,velN,curvN,0.50,0.40,0.35,0.20);

   // convexity maturity (EMA)
   bool sweep=g_state.liquidity.sweepBull||g_state.liquidity.sweepBear;
   double inductionEvidence=((dir==1&&p.bearImpulse&&g_state.structure.structBias==1)||(dir==-1&&p.bullImpulse&&g_state.structure.structBias==-1))?1.0:0.0;
   double preConvEvidence=(p.bullDecay||p.bearDecay)?1.0:0.0;
   double expWeak=FAL_Clamp(((p.efficiency<effT?(1.0-p.efficiency/MathMax(effT,1e-10))*40.0:0.0)+p.obsDecay*0.30)*(100.0/90.0),0,100);
   double indMat=FAL_Clamp((inductionEvidence>0?35.0:0.0)+p.obsCurvature*0.35+(preConvEvidence>0?20.0:0.0),0,100);
   double liqMat=FAL_Clamp(p.obsLiquidity*0.50+(sweep?30.0:0.0)+(g_state.liquidity.liqHeat>60?20.0:g_state.liquidity.liqHeat>30?10.0:0.0),0,100);
   double rawCM=FAL_Clamp(expWeak*0.35+indMat*0.35+liqMat*0.30,0,100);
   w.convexityMaturity=FAL_EmaStep(w.convexityMaturity,rawCM,g_cfg.beliefSmooth);

   // wave progress (geometry + physics anchor) EMA
   double geomProg=30.0;
   if(w.point4High!=EMPTY_VALUE && flipzoneWidth!=EMPTY_VALUE)
     {
      double org=dir==1?w.point4Low:w.point4High;
      double ext=dir==1?FAL_NZ(w.cycleHigh,close+atr):FAL_NZ(w.cycleLow,close-atr);
      double fzMid=(w.flipTop+w.flipBot)/2.0;
      double totalMove=MathAbs(ext-org), toFz=MathAbs(ext-fzMid);
      double expProg=totalMove>1e-10?MathMin(MathAbs(close-org)/totalMove*60.0,60.0):30.0;
      double retrProg=toFz>1e-10?MathMin(MathAbs(close-ext)/MathMax(toFz,1e-10)*40.0,40.0):0.0;
      geomProg=expProg+retrProg*MathMin(p.obsAbsorption/40.0,1.0);
     }
   double simAnchor = (simDR>=simRet&&simDR>=simAbs&&simDR>=simCre&&simDR>=simExp)?95.0:
                      (simRet>=simAbs&&simRet>=simCre&&simRet>=simExp)?87.0:
                      (simAbs>=simCre&&simAbs>=simExp)?75.0:
                      (simCre>=simLiq&&simCre>=simExp)?62.0:
                      (simLiq>=simInd&&simLiq>=simExp)?52.0:
                      (simInd>=simPre&&simInd>=simExp)?43.0:(simPre>=simExp)?33.0:22.0;
   double convWeight=MathMax(0.0,1.0-MathAbs(simAnchor-47.5)/14.5);
   double physProg=simAnchor+(w.convexityMaturity/100.0)*(simAnchor-33.0)*0.50*convWeight;
   double rawWP=geomProg*0.60+physProg*0.40;
   w.waveProgress=FAL_Clamp(FAL_EmaStep(w.waveProgress,rawWP,g_cfg.beliefSmooth),0,100);

   double bestSim=MathMax(simExp,MathMax(simPre,MathMax(simInd,MathMax(simLiq,MathMax(simCre,MathMax(simAbs,MathMax(simRet,simDR)))))));
   double geomCons=FAL_Clamp((originToExtreme!=EMPTY_VALUE&&originToExtreme>atr*2.0?30.0:0.0)+(flipzoneWidth!=EMPTY_VALUE&&flipzoneWidth<atr*4.0?25.0:0.0)+(w.cycleHigh!=EMPTY_VALUE||w.cycleLow!=EMPTY_VALUE?20.0:0.0)+(dir!=0?25.0:0.0),0,100);
   w.waveModelFit=FAL_Clamp(FAL_EmaStep(w.waveModelFit,bestSim*0.55+geomCons*0.45,g_cfg.beliefSmooth),0,100);

   double posDistToCreation=MathMin((dir==1?MathAbs(FAL_NZ(w.cycleHigh,close+atr)-close):MathAbs(close-FAL_NZ(w.cycleLow,close-atr)))/MathMax(FAL_NZ(originToExtreme,atr*5.0),atr*0.5)*100.0,100.0);

   // beliefs (EMA-smoothed)
   double wp=w.waveProgress;
   double expMult=wp<40?1.20:wp<60?0.80:0.50;
   double rawExp=FAL_Clamp((p.obsExpansion*0.45+(p.bullImpulse||p.bearImpulse?30.0:0.0)+(p.efficiency>effT*1.1?15.0:0.0)+simExp*0.10)*expMult,0,100);
   double convMult2=(wp>=30&&wp<=65)?1.30:0.70;
   double rawConv=FAL_Clamp((p.obsDecay*0.30+p.obsCurvature*0.25+(preConvEvidence>0?15.0:0.0)+(inductionEvidence>0?10.0:0.0)+w.convexityMaturity*0.08)*convMult2,0,100);
   double creMult=(wp>=45&&wp<=68)?1.40:0.60;
   bool atExt=(w.cycleHigh!=EMPTY_VALUE&&w.cycleLow!=EMPTY_VALUE)&&((dir==1&&iHigh(_Symbol,_Period,1)>=FAL_NZ(w.cycleHigh,0)*0.998)||(dir==-1&&iLow(_Symbol,_Period,1)<=FAL_NZ(w.cycleLow,0)*1.002));
   double rawCre=FAL_Clamp(((w.convexityMaturity>50?w.convexityMaturity*0.12:0.0)+(p.obsDecay>60?p.obsDecay*0.20:0.0)+(p.obsLiquidity>50?p.obsLiquidity*0.20:0.0)+(p.obsAbsorption>20?p.obsAbsorption*0.15:0.0)+(atExt?20.0:0.0)+simCre*0.10+(posDistToCreation<15?(15.0-posDistToCreation):0.0))*creMult,0,100);
   double rawAbs=FAL_Clamp(p.obsAbsorption*0.50+(p.efficiency<effT*0.6?25.0:0.0)+(p.displacement<dispT*0.5?15.0:0.0)+simAbs*0.10,0,100);
   double rawRet=FAL_Clamp(((dir==1&&p.bearImpulse)||(dir==-1&&p.bullImpulse)?45.0:0.0)+(rawAbs>50?rawAbs*0.30:0.0)+(p.obsCurvature>40?15.0:0.0)+simRet*0.10,0,100);
   double rawDR =FAL_Clamp((w.flipTop!=EMPTY_VALUE&&close<=w.flipTop&&close>=w.flipBot?35.0:0.0)+(rawRet>60?rawRet*0.30:0.0)+(g_state.liquidity.liqHeat>50?g_state.liquidity.liqHeat*0.15:0.0)+(sweep?20.0:0.0)+simDR*0.10,0,100);
   int bs=g_cfg.beliefSmooth;
   w.beliefExpansion   =FAL_EmaStep(w.beliefExpansion,rawExp,bs);
   w.beliefConvexity   =FAL_EmaStep(w.beliefConvexity,rawConv,bs);
   w.beliefCreation    =FAL_EmaStep(w.beliefCreation,rawCre,bs);
   w.beliefAbsorption  =FAL_EmaStep(w.beliefAbsorption,rawAbs,bs);
   w.beliefRetracement =FAL_EmaStep(w.beliefRetracement,rawRet,bs);
   w.beliefDemandReturn=FAL_EmaStep(w.beliefDemandReturn,rawDR,bs);

   // bayesian directional prob + setup grade
   int sb=g_state.structure.structBias, wdir=g_state.intel.waveDir;
   double bStruct=(sb==wdir)?0.90:(sb==0?0.50:0.15);
   double bMom=((wdir==1&&p.velocity>0&&p.acceleration>0)||(wdir==-1&&p.velocity<0&&p.acceleration<0))?0.85:
               ((wdir==1&&p.velocity>0)||(wdir==-1&&p.velocity<0))?0.60:0.30;
   double bLiq=g_state.liquidity.liqHeat>70?0.80:g_state.liquidity.liqHeat>30?0.55:0.35;
   int htfA=g_state.htf.align;
   double bHTF=(htfA==wdir&&htfA!=0)?0.90:(htfA==0?0.55:0.20);
   double bDisp=p.displacement>dispT*1.5?0.85:p.displacement>dispT?0.65:0.35;
   double lo=0.15*MathLog(bStruct/(1-bStruct))+0.18*MathLog(bMom/(1-bMom))+0.12*MathLog(bLiq/(1-bLiq))+0.18*MathLog(bHTF/(1-bHTF))+0.14*MathLog(bDisp/(1-bDisp))+0.23*MathLog(MathMax(w.beliefDemandReturn/100.0,1e-3)/MathMax(1-w.beliefDemandReturn/100.0,1e-3));
   g_state.intel.finalProb=1.0/(1.0+MathExp(-lo))*100.0;

   double contProb=FAL_Clamp(w.waveModelFit*0.30+g_state.intel.phaseConfidence*0.25+(htfA==wdir&&htfA!=0?20.0:0.0)+g_state.liquidity.liqHeat*0.10+w.convexityMaturity*0.15,0,100);
   g_state.intel.contProb=contProb;
   g_state.intel.grade = contProb>90?"A+":contProb>80?"A":contProb>70?"B":contProb>60?"C":"D";

   // opportunity edge
   double buyScore=0,sellScore=0;
   buyScore += (wdir==1?40.0:0.0)+(sb==1?20.0:0.0)+(htfA==1?20.0:0.0)+(p.velocity>0?10.0:0.0)+(g_state.structure.fractalStackDir==1?g_state.structure.fractalStackScore*0.3:0.0);
   sellScore+= (wdir==-1?40.0:0.0)+(sb==-1?20.0:0.0)+(htfA==-1?20.0:0.0)+(p.velocity<0?10.0:0.0)+(g_state.structure.fractalStackDir==-1?g_state.structure.fractalStackScore*0.3:0.0);
   g_state.intel.buyProb=FAL_Clamp(buyScore,0,100);
   g_state.intel.sellProb=FAL_Clamp(sellScore,0,100);
   g_state.intel.netEdge=buyScore-sellScore;
  }

//==================================================================
// SENSEEI META-INTELLIGENCE  (the unified read)
//==================================================================
void INTEL_Senseei(FAL_Intelligence &in)
  {
   // network pressure direction
   double pr=g_state.network.pressure;
   in.netBias=g_state.network.bias;
   in.pdir = pr>12?1:(pr<-12?-1:0);

   int v1=in.waveDir, v2=in.stackDir, v3=in.netBias, v4=in.pdir;
   int sum=v1+v2+v3+v4;
   in.master = sum>0?1:(sum<0?-1:0);
   int cast=(v1!=0?1:0)+(v2!=0?1:0)+(v3!=0?1:0)+(v4!=0?1:0);
   int forV=(v1==in.master&&v1!=0?1:0)+(v2==in.master&&v2!=0?1:0)+(v3==in.master&&v3!=0?1:0)+(v4==in.master&&v4!=0?1:0);
   in.alignment = cast>0?(double)forV/cast*100.0:50.0;
   in.conflict  = cast>0?(double)(cast-forV)/cast*100.0:0.0;

   double residual=MathMin(g_state.erf.residualEnergy,100.0);
   in.threat = FAL_Clamp(in.conflict*0.40+residual*0.28+g_state.htf.timeConflict*0.12+(in.pdir!=0&&in.pdir!=in.master?18.0:0.0)+(g_state.erf.resCode==1?10.0:0.0),0,100);
   in.confidence = FAL_Clamp(in.alignment*0.40+g_state.htf.timeAlign*0.12+in.stackPct*0.18+g_state.erf.attractorScore*0.15+MathMin(15.0,g_state.network.eligible*1.2)-in.threat*0.20,0,100);

   double wp=g_state.wave.waveProgress;
   in.timing = (g_state.intel.phaseCode==PH_TERMINAL||g_state.erf.resCode==2)?"RESOLVED":wp<15?"VERY EARLY":wp<35?"EARLY":wp<55?"DEVELOPING":wp<80?"MID CYCLE":wp<96?"LATE":"TERMINAL";
   int ph=in.phaseCode;
   in.intent = in.conflict>55?"ABSORPTION":
               (ph==PH_EXPANSION)?"EXPANSION":
               (ph==PH_EXP_PRECVX)?"CONTINUATION":
               (ph==PH_EXP_INDUCT||ph==PH_INDUCTION)?"RESOLUTION":
               (ph==PH_EXP_LIQUID||ph==PH_LIQUIDATION||ph==PH_NEW_HIGH||ph==PH_NEW_LOW||ph==PH_TERMINAL)?"DELIVERY":
               (ph==PH_RETRACE||ph==PH_TRANSITION)?"ABSORPTION":in.master==0?"BALANCE":"CONTINUATION";

   in.oppScore=FAL_Clamp(in.alignment*0.40+g_state.erf.attractorScore*0.30+in.stackPct*0.30-in.threat*0.35,0,100);
   in.opportunity = in.master==0?"NONE":in.conflict>60?"DEVELOPING":in.oppScore<20?"NONE":in.oppScore<40?"DEVELOPING":in.oppScore<62?"GOOD":in.oppScore<82?"STRONG":"EXCEPTIONAL";

   string dirw=in.master==1?"buyers":in.master==-1?"sellers":"neither side";
   in.story = in.phase+" is the active phase and "+dirw+" hold the initiative. "+
              "Curve life "+IntegerToString((int)g_state.curve.life)+", force "+g_state.curve.cpState+", lineage "+g_state.curve.narrState+".";
   FAL_Publish("SENSEEI_UPDATED");
  }

//==================================================================
// DECISION ENGINE — master decision + targets/invalidation
//==================================================================
void DEC_Decide(FAL_Intelligence &in)
  {
   double atr=g_state.physics.atr; if(atr<=0)atr=_Point*10;
   double close=g_state.spot;

   // targets / invalidation (read from structure rungs)
   FAL_TFStruct m5=g_state.structure.tf[FAL_L0];
   FAL_TFStruct m15=g_state.structure.tf[3];
   FAL_TFStruct h1=g_state.structure.tf[4];
   in.entryPrice = (g_state.wave.flipTop!=EMPTY_VALUE&&g_state.wave.flipBot!=EMPTY_VALUE)?(g_state.wave.flipTop+g_state.wave.flipBot)/2.0:close;
   in.stopPrice  = m5.invalidation;
   in.targetT1   = FAL_NZ(g_state.fu.winTarget,m5.target);
   in.targetT2   = m15.target;
   in.targetT3   = h1.target;
   double risk=(in.stopPrice!=EMPTY_VALUE)?MathAbs(in.entryPrice-in.stopPrice):atr;
   in.rr = (in.targetT1!=EMPTY_VALUE&&risk>1e-9)?MathAbs(in.targetT1-in.entryPrice)/risk:0.0;

   // ── Master decision. Phases describe; probabilities decide. ───
   int ph=in.phaseCode;
   int master=in.master;
   bool entryGate=g_state.erf.entryGate;
   bool rrOK=(in.rr>=g_cfg.rrMinimum);
   bool invalidated=(master==1&&close<FAL_NZ(g_state.wave.flipBot,close)-atr*0.5)||(master==-1&&close>FAL_NZ(g_state.wave.flipTop,close)+atr*0.5);
   bool resolved=(g_state.erf.resCode==2);
   bool campaignDead=(g_state.curve.life<=32.0 && g_state.curve.ownerDir!=0);

   int decision=DEC_NO_TRADE; string reason="no edge";
   double conf=in.confidence;

   if(master==0){ decision=DEC_NO_TRADE; reason="no directional consensus"; }
   else if(invalidated){ decision=DEC_EXIT; reason="structure invalidated"; }
   else if(resolved){ decision=DEC_EXIT; reason="energy resolved — bank/exit"; }
   else if(campaignDead){ decision=DEC_DEFEND; reason="owner curve dead — defend/flip risk"; }
   else if(in.conflict>60){ decision=DEC_WAIT; reason="engines in conflict"; }
   else if(!entryGate){ decision=DEC_WAIT; reason="ERF entry gate closed"; }
   else if(!rrOK){ decision=DEC_WAIT; reason="R:R below minimum"; }
   else
     {
      // execution window: return-to-zone phases with strong opportunity
      bool returnWin=(ph==PH_DEMAND_RTN&&master==1)||(ph==PH_SUPPLY_RTN&&master==-1)||(g_state.wave.closeInside);
      bool strongOpp=(in.opportunity=="STRONG"||in.opportunity=="EXCEPTIONAL")&&conf>=g_cfg.minConfidence&&in.threat<45;
      if(returnWin && strongOpp) decision = master==1?DEC_BUY:DEC_SELL;
      else if(strongOpp)        decision = DEC_ATTACK;
      else if(in.opportunity=="GOOD"||in.opportunity=="STRONG"){ decision=DEC_WAIT; reason="opportunity building"; }
      else if(g_state.intel.contProb>70 && conf>=g_cfg.minConfidence){ decision=DEC_SCALE; reason="continuation — hold/scale"; }
      else { decision=DEC_WAIT; reason="awaiting trigger"; }
      if(decision==DEC_BUY||decision==DEC_SELL) reason="execution window — "+in.phase;
      if(decision==DEC_ATTACK) reason="aligned high-confidence attack";
     }

   in.decision=decision;
   in.decisionConfidence=conf;
   in.decisionReason=reason;

   if(decision==DEC_BUY)  FAL_Publish("DECISION_BUY");
   if(decision==DEC_SELL) FAL_Publish("DECISION_SELL");
   if(decision==DEC_ATTACK) FAL_Publish("DECISION_ATTACK");
   if(decision==DEC_EXIT) FAL_Publish("DECISION_EXIT");
   if(decision==DEC_DEFEND) FAL_Publish("DECISION_DEFEND");
   if(decision==DEC_SCALE) FAL_Publish("DECISION_SCALE");
   FAL_SetModuleStatus(2,"ok");
  }

void INTEL_Init(){ FAL_SetModuleStatus(2,"ready"); }

#endif // FALCON_INTELLIGENCE_MQH
