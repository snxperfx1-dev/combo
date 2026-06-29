//+------------------------------------------------------------------+
//| FALCON_M5_Visualization.mqh                                       |
//| FALCON OS - Module 5: Visualization Engine                        |
//|                                                                   |
//| ONE tabbed interface replacing all legacy dashboards. Reads only  |
//| from gState (never recomputes). Tabs: Overview / Physics /        |
//| Structure / Network / Curve / Campaign / Wave / HTF / Risk /      |
//| Execution / Performance / Diagnostics.                            |
//| Active tab selected via CfgActiveTab input.                       |
//+------------------------------------------------------------------+
#property strict

string m5_tabNames[12] = {"Overview","Physics","Structure","Network","Curve","Campaign",
                          "Wave","HTF","Risk","Execution","Performance","Diagnostics"};

//--- gauge bar helper
string M5_Gauge(double pct, int w=10)
{
   int f=(int)MathRound(FClamp(pct,0,100)/(100.0/w));
   string s=""; for(int i=0;i<w;i++) s+=(i<f)?"|":".";
   return(s);
}
string M5_Dir(int d){ return(d==1?"^ BULL":d==-1?"v BEAR":"- FLAT"); }
string M5_Sym(int d){ return(d==1?"^":d==-1?"v":"-"); }

//--- tab header (shows all tabs, marks active)
string M5_TabBar()
{
   string s="";
   for(int i=0;i<12;i++)
      s += (i==CfgActiveTab) ? "["+m5_tabNames[i]+"] " : m5_tabNames[i]+" ";
   return(s);
}


//==================================================================
// TAB RENDERERS — each builds the body string for one tab
//==================================================================
string M5_TabOverview()
{
   string nl="\n"; string s="";
   s+="DECISION: "+FALCON_DecisionStr(gState.intel.decision)+nl;
   s+=gState.intel.actionNarrative+nl;
   s+="Bias: "+M5_Dir(gState.intel.masterBias)+
      "  Conf: "+IntegerToString((int)gState.intel.confidence)+"%"+
      "  Opp: "+gState.intel.opportunity+nl;
   s+="Phase: "+FALCON_PhaseStr(gState.wave.phase)+
      "  Prog: "+IntegerToString((int)gState.wave.completion)+"%"+nl;
   s+="Stack: ["+M5_Gauge(gState.htf.fractalScore)+"] "+IntegerToString((int)gState.htf.fractalScore)+"%"+nl;
   s+="Align "+IntegerToString((int)gState.intel.alignment)+"% | Conflict "+
      IntegerToString((int)gState.intel.conflict)+"% | Threat "+IntegerToString((int)gState.intel.threat)+"%"+nl;
   s+="Curve Life: "+IntegerToString((int)gState.curve.life)+" ("+gState.curve.aliveStatus+")"+nl;
   s+="Story: "+gState.intel.story+nl;
   return(s);
}

string M5_TabPhysics()
{
   string nl="\n"; FALCON_Physics p=gState.physics; string s="";
   s+="ATR: "+DoubleToString(p.atr,_Digits)+"  Vol: "+DoubleToString(p.volatility,2)+nl;
   s+="Velocity: "+DoubleToString(p.velocity,_Digits)+"  Accel: "+DoubleToString(p.acceleration,_Digits)+nl;
   s+="Convexity: "+DoubleToString(p.convexity,_Digits)+"  Smooth: "+DoubleToString(p.convSmoothed,_Digits)+nl;
   s+="Efficiency: "+DoubleToString(p.efficiency,2)+"  Displacement: "+DoubleToString(p.displacement,2)+nl;
   s+="Energy: ["+M5_Gauge(p.energy)+"] "+IntegerToString((int)p.energy)+nl;
   s+="Compression: ["+M5_Gauge(p.compression)+"] "+IntegerToString((int)p.compression)+nl;
   s+="Expansion: ["+M5_Gauge(p.expansion)+"] "+IntegerToString((int)p.expansion)+nl;
   s+="Impulse: "+(p.bullImpulse?"BULL":p.bearImpulse?"BEAR":"-")+
      "  Decay: "+(p.bullMomDecay?"bull":p.bearMomDecay?"bear":"-")+nl;
   return(s);
}

string M5_TabStructure()
{
   string nl="\n"; FALCON_Structure st=gState.structure; string s="";
   s+="Trend: "+M5_Dir(st.trend)+"  Break: "+DoubleToString(st.breakStrength,1)+" ATR"+nl;
   s+="HH:"+(st.isHH?"Y":"n")+" HL:"+(st.isHL?"Y":"n")+
      " LH:"+(st.isLH?"Y":"n")+" LL:"+(st.isLL?"Y":"n")+nl;
   s+="SwingH: "+DoubleToString(st.swingHigh,_Digits)+"  SwingL: "+DoubleToString(st.swingLow,_Digits)+nl;
   s+="BOS: "+M5_Sym(st.bos)+"  CHoCH: "+M5_Sym(st.choch)+nl;
   s+="Internal: "+IntegerToString(st.internalStructure)+"  External: "+IntegerToString(st.externalStructure)+nl;
   s+="--- 6-TF STACK ---"+nl;
   string lbl[6]={"M1","M3","M5","M15","H1","H4"};
   for(int i=0;i<L_TFCOUNT;i++)
      s+=lbl[i]+": "+M5_Sym(gState.tf[i].direction)+" "+FALCON_PhaseStr(gState.tf[i].phase)+
         " ["+M5_Gauge(gState.tf[i].waveProgress,6)+"]"+nl;
   return(s);
}

string M5_TabNetwork()
{
   string nl="\n"; FALCON_Network n=gState.network; string s="";
   s+="Nodes: "+IntegerToString(n.nodeCount)+"  Live: "+IntegerToString(n.eligibleCount)+nl;
   s+="Bias: "+M5_Dir(n.bias)+"  Pressure: "+DoubleToString(n.pressure,1)+nl;
   s+="Attractor: "+n.attractorDesc+nl;
   if(n.fezHigh>0&&n.fezLow>0)
      s+="FEZ: "+DoubleToString(n.fezLow,_Digits)+" - "+DoubleToString(n.fezHigh,_Digits)+
        " "+(n.insideFEZ?"INSIDE":"outside")+nl;
   return(s);
}

string M5_TabCurve()
{
   string nl="\n"; FALCON_Curve c=gState.curve; string s="";
   s+="Dir: "+M5_Dir(c.direction)+"  "+c.aliveStatus+nl;
   s+="Life: ["+M5_Gauge(c.life)+"] "+IntegerToString((int)c.life)+nl;
   s+="Force: ["+M5_Gauge(c.force)+"] "+IntegerToString((int)c.force)+" "+c.forceState+nl;
   s+="Energy In/Diss/Res: "+IntegerToString((int)c.energyIn)+"/"+
      IntegerToString((int)c.energyDissipated)+"/"+IntegerToString((int)c.energyResidual)+nl;
   s+="Compress: ["+M5_Gauge(c.compression)+"] "+IntegerToString((int)c.compression)+nl;
   s+="Maturity: ["+M5_Gauge(c.maturity)+"] "+IntegerToString((int)c.maturity)+nl;
   s+="Tree: "+IntegerToString(c.treeNodeCount)+" nodes, depth "+IntegerToString(c.treeMaxDepth)+nl;
   s+="Budget Tgt: "+c.budgetSource+" "+DoubleToString(c.budgetTarget,_Digits)+
      " ("+DoubleToString(c.budgetATR,1)+" ATR)"+nl;
   return(s);
}

string M5_TabCampaign()
{
   string nl="\n"; FALCON_Campaign c=gState.campaign; FALCON_Participants p=gState.participants; string s="";
   s+="Campaign: "+c.owner+"  Location: "+c.location+nl;
   s+="Institution: "+c.institution+"  Control: "+IntegerToString((int)c.controlScore)+"%"+nl;
   s+="Compression: "+c.compRegime+"  Budget: "+IntegerToString((int)c.curveBudget)+"%"+nl;
   s+="Ownership: "+c.ownershipState+nl;
   s+="--- PARTICIPANTS ---"+nl;
   s+="Zone: "+p.zone+nl;
   s+="Interference: "+p.interferenceState+nl;
   s+="Buyer "+IntegerToString((int)p.buyer)+" | Seller "+IntegerToString((int)p.seller)+
      " | Pressure "+DoubleToString(p.marketPressure,0)+nl;
   return(s);
}


string M5_TabWave()
{
   string nl="\n"; FALCON_Wave w=gState.wave; string s="";
   s+="Phase: "+FALCON_PhaseStr(w.phase)+nl;
   s+="Direction: "+M5_Dir(w.direction)+"  Age: "+IntegerToString(w.age)+nl;
   s+="Completion: ["+M5_Gauge(w.completion)+"] "+IntegerToString((int)w.completion)+"%"+nl;
   s+="Strength: "+IntegerToString((int)w.strength)+"  Confidence: "+IntegerToString((int)w.confidence)+nl;
   s+="Origin: "+DoubleToString(w.origin,_Digits)+"  Target: "+DoubleToString(w.target,_Digits)+nl;
   s+="Flip: "+DoubleToString(w.flipBot,_Digits)+" - "+DoubleToString(w.flipTop,_Digits)+nl;
   s+="Cycle: "+IntegerToString(w.entryCycle)+" Depth: "+IntegerToString(w.waveDepth)+
      " Recursive: "+(w.isRecursive?"Y":"n")+nl;
   s+="Exp/Retr/Induc: "+IntegerToString((int)w.expansion)+"/"+
      IntegerToString((int)w.retracement)+"/"+IntegerToString((int)w.induction)+nl;
   return(s);
}

string M5_TabHTF()
{
   string nl="\n"; FALCON_HTF h=gState.htf; string s="";
   s+="HTF Dir: "+M5_Dir(h.direction)+nl;
   s+="Alignment: ["+M5_Gauge(h.alignment)+"] "+IntegerToString((int)h.alignment)+"%"+nl;
   s+="Conflict: "+IntegerToString((int)h.conflict)+"%  Dominance: "+IntegerToString((int)h.dominance)+"%"+nl;
   s+="Fractal Agreement: "+IntegerToString((int)h.fractalAgreement)+"%"+nl;
   s+="Belief Bull/Bear: "+IntegerToString((int)h.beliefBull)+"/"+IntegerToString((int)h.beliefBear)+nl;
   s+="--- MTF MAP ["+IntegerToString((int)m2_mapAlign)+"/7] ---"+nl;
   s+="Story: "+m2_mapStory+"  Owner: "+m2_mapOwnerTF+nl;
   return(s);
}

string M5_TabRisk()
{
   string nl="\n"; FALCON_Execution e=gState.exec; string s="";
   s+="RISK ENGINE (DRDWCT)"+nl;
   s+="Equity: "+DoubleToString(e.equity,2)+nl;
   s+="VaR2: "+DoubleToString(e.var2,2)+"  VaR3: "+DoubleToString(e.var3,2)+nl;
   s+="UDS Max: "+DoubleToString(e.udsMax,3)+nl;
   s+="VaR Breach: "+(e.varBreach?"YES":"no")+"  Micro-Bomb: "+(e.anyBomb?"YES":"no")+nl;
   s+="Trims this bar: "+IntegerToString(e.trimCount)+nl;
   s+="Positions: "+IntegerToString(e.positionCount)+
      " (L"+IntegerToString(e.longCount)+"/S"+IntegerToString(e.shortCount)+")"+nl;
   s+="Floating PnL: "+DoubleToString(e.floatingPnl,2)+nl;
   return(s);
}

string M5_TabExecution()
{
   string nl="\n"; FALCON_Execution e=gState.exec; FALCON_Intelligence in=gState.intel; string s="";
   s+="State: "+e.tradeState+"  Armed: "+(e.engineArmed?"Y":"n")+nl;
   s+="Decision: "+FALCON_DecisionStr(in.decision)+nl;
   s+="Directive: "+in.execDirective+nl;
   s+="Last Entry: "+DoubleToString(e.entry,_Digits)+"  Stop: "+DoubleToString(e.stop,_Digits)+nl;
   s+="Target: "+DoubleToString(e.target,_Digits)+"  Lots: "+DoubleToString(e.lotSize,2)+nl;
   s+="Risk: "+DoubleToString(e.risk,2)+"  R:R: "+DoubleToString(e.reward,2)+nl;
   s+="BuyProb "+IntegerToString((int)in.buyProb)+"% | SellProb "+IntegerToString((int)in.sellProb)+
      "% | Edge "+DoubleToString(in.netEdge,1)+nl;
   return(s);
}

string M5_TabPerformance()
{
   string nl="\n"; string s="";
   s+="Beliefs:"+nl;
   s+=" Exp "+IntegerToString((int)gState.intel.beliefExpansion)+
      " Conv "+IntegerToString((int)gState.intel.beliefConvexity)+
      " Creat "+IntegerToString((int)gState.intel.beliefCreation)+nl;
   s+=" Abs "+IntegerToString((int)gState.intel.beliefAbsorption)+
      " Retr "+IntegerToString((int)gState.intel.beliefRetracement)+
      " DR "+IntegerToString((int)gState.intel.beliefDemandReturn)+nl;
   s+="Hypothesis: "+gState.intel.primaryHypothesis+nl;
   s+="Predict: "+gState.intel.expectedNextPhase+" ("+IntegerToString((int)gState.intel.expectedNextProb)+"%)"+nl;
   s+="Reliability: "+IntegerToString((int)gState.intel.predReliability)+"%"+nl;
   s+="Model Conf: "+IntegerToString((int)gState.intel.modelConfidence)+"%"+nl;
   s+="Lineage: "+gState.lineage.state+" ("+IntegerToString((int)gState.lineage.narrative)+")"+nl;
   return(s);
}

string M5_TabDiagnostics()
{
   string nl="\n"; string s="";
   s+="Profile: "+FALCON_ProfileName()+nl;
   s+=FALCON_DiagSummary()+nl;
   s+="Module times (us):"+nl;
   s+=" M1 "+IntegerToString((int)gState.diag.moduleMicros[0])+
      " M2 "+IntegerToString((int)gState.diag.moduleMicros[1])+
      " M3 "+IntegerToString((int)gState.diag.moduleMicros[2])+nl;
   s+=" Dec "+IntegerToString((int)gState.diag.moduleMicros[3])+
      " M4 "+IntegerToString((int)gState.diag.moduleMicros[4])+
      " M5 "+IntegerToString((int)gState.diag.moduleMicros[5])+nl;
   s+="Health: M"+(gState.diag.marketHealthy?"+":"-")+
      " Mem"+(gState.diag.memoryHealthy?"+":"-")+
      " I"+(gState.diag.intelHealthy?"+":"-")+
      " E"+(gState.diag.execHealthy?"+":"-")+nl;
   if(gState.diag.lastError!="") s+="Last Err: "+gState.diag.lastError+nl;
   return(s);
}


//==================================================================
// CHART OBJECT OVERLAY (key levels) — single source from gState
//==================================================================
void M5_SetHLine(string name, double price, color clr, int style)
{
   if(price<=0){ ObjectDelete(0,name); return; }
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_HLINE,0,0,price);
   ObjectSetDouble(0,name,OBJPROP_PRICE,price);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_STYLE,style);
   ObjectSetInteger(0,name,OBJPROP_BACK,true);
}

void M5_DrawChartLevels()
{
   if(!FALCON_VisualsEnabled()) return;
   M5_SetHLine("FALCON_TGT", gState.wave.target, clrDodgerBlue, STYLE_DOT);
   M5_SetHLine("FALCON_INV", gState.wave.origin, clrRed, STYLE_DOT);
   M5_SetHLine("FALCON_FLIPT", gState.wave.flipTop, clrMediumPurple, STYLE_DASHDOT);
   M5_SetHLine("FALCON_FLIPB", gState.wave.flipBot, clrMediumPurple, STYLE_DASHDOT);
   M5_SetHLine("FALCON_ATTR", gState.erf.primaryAttractorPrice, clrGold, STYLE_DASH);
   M5_SetHLine("FALCON_BUDGET", gState.curve.budgetTarget, clrAqua, STYLE_DASH);
}

void M5_CleanupObjects()
{
   ObjectDelete(0,"FALCON_TGT"); ObjectDelete(0,"FALCON_INV");
   ObjectDelete(0,"FALCON_FLIPT"); ObjectDelete(0,"FALCON_FLIPB");
   ObjectDelete(0,"FALCON_ATTR"); ObjectDelete(0,"FALCON_BUDGET");
}

//==================================================================
// MAIN VISUALIZE — single tabbed interface
//==================================================================
void M5_Visualize()
{
   if(!CfgShowDashboard){ Comment(""); return; }

   string body="";
   switch(CfgActiveTab)
   {
      case 0:  body=M5_TabOverview(); break;
      case 1:  body=M5_TabPhysics(); break;
      case 2:  body=M5_TabStructure(); break;
      case 3:  body=M5_TabNetwork(); break;
      case 4:  body=M5_TabCurve(); break;
      case 5:  body=M5_TabCampaign(); break;
      case 6:  body=M5_TabWave(); break;
      case 7:  body=M5_TabHTF(); break;
      case 8:  body=M5_TabRisk(); break;
      case 9:  body=M5_TabExecution(); break;
      case 10: body=M5_TabPerformance(); break;
      case 11: body=M5_TabDiagnostics(); break;
      default: body=M5_TabOverview(); break;
   }

   string nl="\n";
   string head="========= FALCON OS ["+FALCON_ProfileName()+"] =========" + nl;
   head += M5_TabBar() + nl;
   head += "----------------------------------------------" + nl;
   string foot = "----------------------------------------------" + nl;
   foot += "DECISION: " + FALCON_DecisionStr(gState.intel.decision) +
           "  |  " + FALCON_DecisionStr(gState.intel.decision) + nl;

   Comment(head + body + foot);

   M5_DrawChartLevels();
}

//+------------------------------------------------------------------+
