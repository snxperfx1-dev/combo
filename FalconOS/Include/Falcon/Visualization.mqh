//+------------------------------------------------------------------+
//|  FALCON OS — MODULE 5: VISUALIZATION ENGINE                     |
//|  ONE unified interface. Replaces every legacy dashboard.        |
//|  Tabs: Overview · Physics · Structure · Network · Curve ·       |
//|  Campaign · Wave · HTF · Risk · Execution · Performance ·       |
//|  Diagnostics. Reads shared state only — never computes.         |
//+------------------------------------------------------------------+
#ifndef FALCON_VISUALIZATION_MQH
#define FALCON_VISUALIZATION_MQH
#include "Kernel.mqh"

enum FAL_TAB
  {
   TAB_OVERVIEW=0, TAB_PHYSICS, TAB_STRUCTURE, TAB_NETWORK, TAB_CURVE,
   TAB_CAMPAIGN, TAB_WAVE, TAB_HTF, TAB_RISK, TAB_EXECUTION,
   TAB_PERFORMANCE, TAB_DIAGNOSTICS, TAB_ALL
  };

string VIS_Bar(double pct)
  {
   int n=(int)MathRound(FAL_Clamp(pct,0,100)/10.0);
   string s=""; for(int i=0;i<10;i++) s+=(i<n?"#":".");
   return(s);
  }
string VIS_P(double v){ return(DoubleToString(v,(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS))); }
string VIS_Pct(double v){ return(IntegerToString((int)MathRound(v))+"%"); }
string VIS_DirArrow(int d){ return(d==1?"BULL":d==-1?"BEAR":"--"); }

string VIS_Overview()
  {
   FAL_Intelligence in=g_state.intel;
   string s="";
   s+="DECISION   "+FAL_DecisionStr(in.decision)+"   conf "+VIS_Pct(in.decisionConfidence)+"\n";
   s+="  why: "+in.decisionReason+"\n";
   s+="MASTER     "+FAL_DirStr(in.master)+"   align "+VIS_Pct(in.alignment)+"  conflict "+VIS_Pct(in.conflict)+"\n";
   s+="PHASE      "+in.phase+"   ("+VIS_Pct(in.phaseProgress)+" done)\n";
   s+="OPPORTUNITY "+in.opportunity+"  ["+VIS_Bar(in.oppScore)+"]   timing "+in.timing+"\n";
   s+="CONFIDENCE "+VIS_Bar(in.confidence)+"  threat "+VIS_Bar(in.threat)+"\n";
   s+="GRADE      "+in.grade+"   finalProb "+VIS_Pct(in.finalProb)+"   netEdge "+DoubleToString(in.netEdge,1)+"\n";
   s+="STACK      "+VIS_DirArrow(in.stackDir)+"  "+VIS_Bar(in.stackPct)+"   network "+VIS_DirArrow(in.netBias)+" (P "+DoubleToString(g_state.network.pressure,0)+")\n";
   s+="TARGETS    T1 "+VIS_P(in.targetT1)+"  T2 "+VIS_P(in.targetT2)+"  T3 "+VIS_P(in.targetT3)+"   R:R "+DoubleToString(in.rr,2)+"\n";
   s+="STOP       "+VIS_P(in.stopPrice)+"   entry "+VIS_P(in.entryPrice)+"\n";
   s+="STORY      "+in.story+"\n";
   return(s);
  }
string VIS_Physics()
  {
   FAL_Physics p=g_state.physics;
   string s="";
   s+="ATR "+VIS_P(p.atr)+"   volRatio "+DoubleToString(p.volRatio,2)+"\n";
   s+="velocity "+DoubleToString(p.velocity,3)+"  accel "+DoubleToString(p.acceleration,4)+"  convSm "+DoubleToString(p.convSmooth,5)+"\n";
   s+="efficiency "+DoubleToString(p.efficiency,2)+"  displacement "+DoubleToString(p.displacement,2)+"  compression "+VIS_Pct(p.compression)+"\n";
   s+="impulse "+(p.bullImpulse?"BULL":p.bearImpulse?"BEAR":"--")+"  decay "+(p.bullDecay?"bull":p.bearDecay?"bear":"--")+"\n";
   s+="obs Exp  ["+VIS_Bar(p.obsExpansion)+"]\n";
   s+="obs Decay["+VIS_Bar(p.obsDecay)+"]   obs Curv ["+VIS_Bar(p.obsCurvature)+"]\n";
   s+="obs Absrb["+VIS_Bar(p.obsAbsorption)+"]   obs Liq  ["+VIS_Bar(p.obsLiquidity)+"]\n";
   s+="consensus "+VIS_Pct(p.physicsConsensus)+"  energy "+VIS_Pct(p.energy)+"\n";
   return(s);
  }
string VIS_Structure()
  {
   string s="rung  dir  phase                    prog  conv  fit\n";
   for(int i=0;i<FAL_TF_COUNT;i++)
     {
      FAL_TFStruct t=g_state.structure.tf[i];
      s+=StringFormat("%-4s  %-4s %-24s %3d%%  %3d%%  %3d%%\n",
         FAL_TF_LBL[i],VIS_DirArrow(t.dir),FAL_PhaseStr(t.phase),
         (int)t.waveProgress,(int)t.convMaturity,(int)t.modelFit);
     }
   s+="fractal stack "+VIS_DirArrow(g_state.structure.fractalStackDir)+"  ["+VIS_Bar(g_state.structure.fractalStackScore)+"]  ("+IntegerToString(g_state.structure.stackBull)+"B/"+IntegerToString(g_state.structure.stackBear)+"S)\n";
   s+="structBias "+VIS_DirArrow(g_state.structure.structBias)+"\n";
   return(s);
  }
string VIS_Network()
  {
   FAL_Network n=g_state.network;
   string s="";
   s+="bias "+VIS_DirArrow(n.bias)+"   pressure "+DoubleToString(n.pressure,0)+"  ("+VIS_DirArrow(g_state.intel.pdir)+")\n";
   s+="nodes "+IntegerToString(n.count)+"  ("+IntegerToString(n.eligible)+" live)\n";
   s+="FEZ corridor  hi "+(n.fezHi==EMPTY_VALUE?"-":VIS_P(n.fezHi))+"   lo "+(n.fezLo==EMPTY_VALUE?"-":VIS_P(n.fezLo))+"\n";
   s+="attractor "+(n.attractorIdx>=0?VIS_P(n.px[n.attractorIdx]):"-")+"   auth "+DoubleToString(n.attractorScore,0)+"\n";
   s+="FU magnet "+(g_state.fu.winTarget==EMPTY_VALUE?"-":VIS_P(g_state.fu.winTarget))+"   recAlign "+VIS_Pct(g_state.fu.recursiveAlign)+"  active "+IntegerToString(g_state.fu.activeCount)+"\n";
   return(s);
  }
string VIS_Curve()
  {
   FAL_Curve c=g_state.curve;
   string s="";
   s+="dir "+VIS_DirArrow(c.dir)+"   maturity "+VIS_Pct(c.maturity)+"   dispATR "+DoubleToString(c.dispATR,1)+"\n";
   s+="energy in ["+VIS_Bar(c.eIn)+"]  diss ["+VIS_Bar(c.eDiss)+"]  res ["+VIS_Bar(c.eRes)+"]\n";
   s+="convex ["+VIS_Bar(c.convex)+"]  compress ["+VIS_Bar(c.compress)+"]\n";
   s+="TREE  alive "+IntegerToString(c.treeAlive)+"  depth "+IntegerToString(c.treeDepth)+"/"+IntegerToString(c.budgetDepth)+"\n";
   s+="owner "+VIS_DirArrow(c.ownerDir)+"  energy "+DoubleToString(c.ownerEnergy,0)+"  O "+VIS_P(c.ownerOrigin)+" -> X "+VIS_P(c.ownerExtreme)+"\n";
   s+="LIFE  ["+VIS_Bar(c.life)+"]   force "+c.cpState+" ("+DoubleToString(c.cpForce,0)+")   lineage "+c.narrState+"\n";
   s+="budget target "+VIS_P(c.budgetTarget)+"\n";
   return(s);
  }
string VIS_Campaign()
  {
   FAL_Campaign c=g_state.campaign;
   string s="";
   s+="campaign "+c.state+"   owner "+VIS_DirArrow(c.ownerDir)+"\n";
   s+="location "+c.location+(c.htfZone==EMPTY_VALUE?"":" @ "+VIS_P(c.htfZone))+"\n";
   s+="compression "+c.compRegime+"   budget->HTF "+(c.curveBudget==EMPTY_VALUE?"-":VIS_Pct(c.curveBudget))+"\n";
   s+="recursion exp "+IntegerToString(c.expDepth)+"/4\n";
   s+="participant zone: "+c.partZone+"\n";
   s+="  0.618 "+(c.f618==EMPTY_VALUE?"-":VIS_P(c.f618))+"  0.70 "+(c.f70==EMPTY_VALUE?"-":VIS_P(c.f70))+"  0.786 "+(c.f786==EMPTY_VALUE?"-":VIS_P(c.f786))+"\n";
   s+="  FLIP "+(c.flipLvl==EMPTY_VALUE?"-":VIS_P(c.flipLvl))+"   interference "+c.interference+"\n";
   return(s);
  }
string VIS_Wave()
  {
   FAL_Wave w=g_state.wave;
   string s="";
   s+="direction "+VIS_DirArrow(w.direction)+"   cycle "+IntegerToString(w.entryCycle)+"  depth "+IntegerToString(w.waveDepth)+"\n";
   s+="flip "+VIS_P(w.flipBot)+" - "+VIS_P(w.flipTop)+"   P4 "+VIS_P(w.point4Low)+" - "+VIS_P(w.point4High)+"\n";
   s+="progress "+VIS_Pct(w.waveProgress)+"   convMat "+VIS_Pct(w.convexityMaturity)+"   modelFit "+VIS_Pct(w.waveModelFit)+"\n";
   s+="beliefs  Exp ["+VIS_Bar(w.beliefExpansion)+"]\n";
   s+="         Cvx ["+VIS_Bar(w.beliefConvexity)+"]  Cre ["+VIS_Bar(w.beliefCreation)+"]\n";
   s+="         Abs ["+VIS_Bar(w.beliefAbsorption)+"]  Ret ["+VIS_Bar(w.beliefRetracement)+"]  DR ["+VIS_Bar(w.beliefDemandReturn)+"]\n";
   s+="ERF "+g_state.erf.resolutionState+"  diss "+VIS_Pct(g_state.erf.dissipationProgress)+"  residual "+VIS_Pct(g_state.erf.residualEnergy)+"\n";
   s+="  attractor "+(g_state.erf.attractorPrice==EMPTY_VALUE?"-":VIS_P(g_state.erf.attractorPrice))+" ("+g_state.erf.attractorLabel+")  readiness "+VIS_Pct(g_state.erf.tradeReadiness)+"  gate "+(g_state.erf.entryGate?"OPEN":"shut")+"\n";
   return(s);
  }
string VIS_HTF()
  {
   FAL_HTF h=g_state.htf;
   string s="";
   s+="H1 "+VIS_DirArrow(h.biasH1)+"   H4 "+VIS_DirArrow(h.biasH4)+"   align "+VIS_DirArrow(h.align)+"\n";
   s+="time stack dir "+VIS_DirArrow(h.timeDir)+"   align "+VIS_Pct(h.timeAlign)+"  conflict "+VIS_Pct(h.timeConflict)+"\n";
   s+="H1 timing "+h.h1Timing+"\n";
   return(s);
  }
string VIS_Risk()
  {
   FAL_Execution x=g_state.exec;
   string s="";
   s+="risk "+(x.riskOk?"OK":"BREACH")+"   equity "+DoubleToString(x.equity,2)+"\n";
   s+="VaR(worst campaign) "+DoubleToString(x.var2,0)+" / lim "+DoubleToString(x.var2Limit,0)+"\n";
   s+="VaR(gross both)     "+DoubleToString(x.var3,0)+" / lim "+DoubleToString(x.var3Limit,0)+"\n";
   s+="udsMax "+DoubleToString(x.udsMax,2)+"   microBomb "+(x.anyBomb?"YES":"no")+"   trims "+IntegerToString(x.trimsThisBar)+"\n";
   s+="LONG  "+IntegerToString(x.longPositions)+" pos  "+DoubleToString(x.longLots,2)+" lots  PnL "+DoubleToString(x.longPnL,2)+"\n";
   s+="SHORT "+IntegerToString(x.shortPositions)+" pos  "+DoubleToString(x.shortLots,2)+" lots  PnL "+DoubleToString(x.shortPnL,2)+"\n";
   return(s);
  }
string VIS_Execution()
  {
   FAL_Execution x=g_state.exec;
   string s="";
   s+="session "+(x.sessionOpen?"OPEN":"closed")+"   trading "+(g_cfg.tradeEnabled?"ENABLED":"off")+"\n";
   s+="risk cash/trade "+DoubleToString(x.riskCash,2)+"   riskPct "+DoubleToString(g_cfg.riskPercent,2)+"\n";
   s+="last action: "+x.lastAction+"\n";
   s+="decision: "+FAL_DecisionStr(g_state.intel.decision)+"  ("+g_state.intel.decisionReason+")\n";
   return(s);
  }
string VIS_Performance()
  {
   string s="";
   s+="closed equity "+DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY),2)+"\n";
   s+="balance "+DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE),2)+"\n";
   s+="open PnL "+DoubleToString(g_state.exec.longPnL+g_state.exec.shortPnL,2)+"\n";
   s+="bars processed "+IntegerToString(g_diag.barsProcessed)+"\n";
   return(s);
  }
string VIS_Diagnostics()
  {
   string s="";
   s+="pipeline "+IntegerToString((int)g_diag.pipelineMicros)+" us   healthy "+(g_diag.healthy?"yes":"NO")+"\n";
   string mods[6]={"CoreMarket","Memory","Intelligence/Decision","Execution","Visualization","Kernel"};
   for(int i=0;i<5;i++) s+="  "+mods[i]+": "+g_diag.moduleStatus[i]+"\n";
   s+="events this bar: "+IntegerToString(g_bus.count)+"\n";
   if(g_diag.lastError!="") s+="last error: "+g_diag.lastError+"\n";
   return(s);
  }

void VIS_Run(int tab)
  {
   if(!g_cfg.showDashboard){ Comment(""); return; }
   string s="==================== FALCON OS ====================\n";
   s+=_Symbol+"  "+EnumToString((ENUM_TIMEFRAMES)_Period)+"   spot "+VIS_P(g_state.spot)+"   "+TimeToString(g_state.barTime,TIME_DATE|TIME_MINUTES)+"\n";
   s+="profile "+(g_cfg.profile==PROFILE_LIVE?"LIVE":g_cfg.profile==PROFILE_BACKTEST?"BACKTEST":"RESEARCH")+"\n";
   s+="---------------------------------------------------\n";

   if(tab==TAB_ALL)
     {
      s+="[OVERVIEW]\n"+VIS_Overview();
      s+="\n[STRUCTURE]\n"+VIS_Structure();
      s+="\n[WAVE/ERF]\n"+VIS_Wave();
      s+="\n[CURVE]\n"+VIS_Curve();
      s+="\n[CAMPAIGN]\n"+VIS_Campaign();
      s+="\n[NETWORK]\n"+VIS_Network();
      s+="\n[RISK]\n"+VIS_Risk();
      s+="\n[EXECUTION]\n"+VIS_Execution();
     }
   else
     {
      switch(tab)
        {
         case TAB_OVERVIEW:    s+="[OVERVIEW]\n"+VIS_Overview(); break;
         case TAB_PHYSICS:     s+="[PHYSICS]\n"+VIS_Physics(); break;
         case TAB_STRUCTURE:   s+="[STRUCTURE]\n"+VIS_Structure(); break;
         case TAB_NETWORK:     s+="[NETWORK]\n"+VIS_Network(); break;
         case TAB_CURVE:       s+="[CURVE]\n"+VIS_Curve(); break;
         case TAB_CAMPAIGN:    s+="[CAMPAIGN]\n"+VIS_Campaign(); break;
         case TAB_WAVE:        s+="[WAVE/ERF]\n"+VIS_Wave(); break;
         case TAB_HTF:         s+="[HTF/TIME]\n"+VIS_HTF(); break;
         case TAB_RISK:        s+="[RISK]\n"+VIS_Risk(); break;
         case TAB_EXECUTION:   s+="[EXECUTION]\n"+VIS_Execution(); break;
         case TAB_PERFORMANCE: s+="[PERFORMANCE]\n"+VIS_Performance(); break;
         case TAB_DIAGNOSTICS: s+="[DIAGNOSTICS]\n"+VIS_Diagnostics(); break;
         default:              s+="[OVERVIEW]\n"+VIS_Overview(); break;
        }
     }
   Comment(s);
   FAL_SetModuleStatus(4,"ok");
  }

#endif // FALCON_VISUALIZATION_MQH
