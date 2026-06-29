//+------------------------------------------------------------------+
//|  FALCON OS — Visualization Layer : Visualization.mqh           |
//|                                                                  |
//|  ONE interface. Replaces every legacy dashboard (LETRA A/B/C/P3/ |
//|  FU, F16 Readout/Strategist/Copilot/Matrix/Campaign/Curve, ...). |
//|  A single chart panel with selectable tabs, all reading the one  |
//|  shared MarketState. No duplicated dashboards anywhere.          |
//|                                                                  |
//|  Tabs: Overview · Physics · Structure · Network · Curve ·        |
//|        Campaign · Wave · HTF · Risk · Execution · Performance ·  |
//|        Diagnostics                                               |
//+------------------------------------------------------------------+
#ifndef FALCON_VIZ_MQH
#define FALCON_VIZ_MQH

#include "../Kernel/FalconState.mqh"
#include "../Kernel/FalconConfig.mqh"
#include "../Kernel/FalconLog.mqh"
#include "../Kernel/FalconEventBus.mqh"
#include "../Kernel/FalconPersistence.mqh"

#define VIZ_OBJ "FALCON_DASH"

string VZ_Pct(const double v){ return(DoubleToString(v,0)+"%"); }
string VZ_Px(const double v){ return(v==0?"—":DoubleToString(v,_Digits)); }
string VZ_Dir(const int d){ return(d==DIR_LONG?"BULL":d==DIR_SHORT?"BEAR":"—"); }

string VZ_TabName(const int t)
{
   switch(t)
   {
      case 0: return("OVERVIEW");
      case 1: return("PHYSICS");
      case 2: return("STRUCTURE");
      case 3: return("NETWORK");
      case 4: return("CURVE");
      case 5: return("CAMPAIGN");
      case 6: return("WAVE");
      case 7: return("HTF");
      case 8: return("RISK");
      case 9: return("EXECUTION");
      case 10:return("PERFORMANCE");
      default:return("DIAGNOSTICS");
   }
}

//------------------------------------------------------------------
// Compose the body text for the selected tab from shared state.
//------------------------------------------------------------------
string VZ_Body(const int tab)
{
   string s="";
   FalconPhysics  ph=g_state.physics;
   FalconStructure st=g_state.structure;
   FalconLiquidity lq=g_state.liquidity;
   FalconConvexity cv=g_state.convexity;
   FalconWave     w =g_state.wave;
   FalconHTF      h =g_state.htf;
   FalconNetwork  n =g_state.network;
   FalconCurve    cu=g_state.curve;
   FalconCampaign cm=g_state.campaign;
   FalconParticipants pa=g_state.participants;
   FalconIntelligence x=g_state.intel;
   FalconExecution e=g_state.exec;
   FalconOrderBlocks ob=g_state.orderBlocks;
   FalconSupplyDemand sd=g_state.supplyDemand;
   FalconWaveMatrix wmx=g_state.waveMatrix;
   FalconFEZ fez=g_state.fez;
   FalconFRZ frz=g_state.frz;

   switch(tab)
   {
      case 0: // OVERVIEW
         s+="Action      : "+FalconActionStr(e.action)+"   ("+VZ_Dir(e.master)+")\n";
         s+="Phase       : "+FalconPhaseStr(w.phase)+"  "+VZ_Pct(w.completion)+"\n";
         s+="Intent      : "+x.intent+"   Timing "+x.timing+"\n";
         s+="Hypothesis  : "+x.hypothesis+"  ("+DoubleToString(x.hypothesisProb*100.0,0)+"%)\n";
         s+="Prediction  : "+x.prediction+"\n";
         s+="Validation  : "+(x.validated?"confirming":"pending")+"  ("+DoubleToString(x.validationScore,0)+"% hit)\n";
         s+="Confidence  : "+DoubleToString(x.confidence,0)+"   Threat "+DoubleToString(x.threat,0)+"\n";
         s+="Opportunity : "+x.opportunityGrade+"  ("+DoubleToString(x.opportunity,0)+")\n";
         s+="Exec Prob   : "+DoubleToString(x.executionProbability*100.0,0)+"%   Resolution "+FalconResStr(x.resolutionState)+"\n";
         s+="Story       : "+x.story;
         break;
      case 1: // PHYSICS
         s+="ATR         : "+DoubleToString(ph.atr,_Digits)+"   Vol "+DoubleToString(ph.volatility,2)+"\n";
         s+="Velocity    : "+DoubleToString(ph.velocity,_Digits)+"\n";
         s+="Accel       : "+DoubleToString(ph.acceleration,_Digits)+"\n";
         s+="Convexity   : "+DoubleToString(ph.convexitySmooth,_Digits)+"\n";
         s+="Efficiency  : "+DoubleToString(ph.efficiency,2)+"   Disp "+DoubleToString(ph.displacement,2)+"\n";
         s+="Energy      : "+DoubleToString(ph.energy,0)+"   Compr "+DoubleToString(ph.compression,0)+"   Exp "+DoubleToString(ph.expansion,0)+"\n";
         s+="Impulse     : "+(ph.bullImpulse?"BULL":ph.bearImpulse?"BEAR":"—")+"   Decay "+(ph.bullDecay||ph.bearDecay?"yes":"no");
         break;
      case 2: // STRUCTURE
         s+="Trend       : "+VZ_Dir(st.trend)+"\n";
         s+="Swing Hi/Lo : "+VZ_Px(st.swingHigh)+" / "+VZ_Px(st.swingLow)+"\n";
         s+="HH/HL/LH/LL : "+(st.hh?"HH ":"")+(st.hl?"HL ":"")+(st.lh?"LH ":"")+(st.ll?"LL":"")+"\n";
         s+="BOS / CHoCH : "+VZ_Dir(st.bos)+" / "+VZ_Dir(st.choch)+"\n";
         s+="Break Str   : "+DoubleToString(st.breakStrength,2)+" ATR\n";
         s+="Order Block : "+(ob.activeDir!=DIR_NONE?VZ_Px(ob.activeBot)+"-"+VZ_Px(ob.activeTop)+" "+VZ_Dir(ob.activeDir)+" str "+DoubleToString(ob.activeStrength,0):"—")+"\n";
         s+="Supply/Dmd  : "+(sd.activeZone==DIR_LONG?"IN DEMAND":sd.activeZone==DIR_SHORT?"IN SUPPLY":"—")
            +"  D "+DoubleToString(sd.demandStrength,0)+" / S "+DoubleToString(sd.supplyStrength,0)+"\n";
         s+="Liquidity   : heat "+DoubleToString(lq.score,0)+"  pressure "+DoubleToString(lq.pressure,0)+(lq.vacuum?"  VACUUM":"");
         break;
      case 3: // NETWORK
         s+="Nodes       : "+IntegerToString(n.count)+"  ("+IntegerToString(n.liveCount)+" live)\n";
         s+="Bias        : "+VZ_Dir(n.bias)+"\n";
         s+="Pressure    : "+DoubleToString(n.pressure,0)+"  ("+VZ_Dir(n.pressureDir)+")\n";
         s+="Bull Auth   : "+DoubleToString(n.bullAuthority,0)+"\n";
         s+="Bear Auth   : "+DoubleToString(n.bearAuthority,0)+"\n";
         s+="Conversation: "+IntegerToString(n.connections)+" edges  weight "+DoubleToString(n.conversationWeight,0)+"\n";
         if(n.nearestAttractorIdx>=0 && n.nearestAttractorIdx<n.count)
            s+="Attractor   : "+VZ_Px(n.px[n.nearestAttractorIdx])+"  "+VZ_Dir(n.dir[n.nearestAttractorIdx]);
         break;
      case 4: // CURVE
         s+="Owner Dir   : "+VZ_Dir(cu.ownerDir)+"   ownerTF idx "+IntegerToString(cu.ownerTF)+"\n";
         s+="Root        : "+VZ_Px(cu.rootOrigin)+" -> "+VZ_Px(cu.rootExtreme)+"  "+VZ_Dir(cu.rootDir)+"\n";
         s+="Parent      : "+VZ_Px(cu.parentOrigin)+" -> "+VZ_Px(cu.parentExtreme)+"  "+VZ_Dir(cu.parentDir)+"\n";
         s+="Life/Energy : "+DoubleToString(cu.life,0)+" / "+DoubleToString(cu.energy,0)+"\n";
         s+="Evolution   : "+DoubleToString(cu.evolution,0)+"%   emergent nodes "+IntegerToString(cu.emergentNodes)+"\n";
         s+="Wave Matrix : dom TF "+IntegerToString(wmx.dominantTF)+" "+VZ_Dir(wmx.dominantDir)
            +"  agree "+DoubleToString(wmx.agreement,0)+"%  E "+DoubleToString(wmx.matrixEnergy,0)+"\n";
         s+="Emergent    : "+FalconPhaseStr(cu.emergentPhase);
         break;
      case 5: // CAMPAIGN
         s+="Owner       : "+VZ_Dir(cm.owner)+"  ("+cm.institution+")\n";
         s+="Control     : "+DoubleToString(cm.controlScore,0)+"%\n";
         s+="Objective   : "+VZ_Dir(cm.objectiveDir)+"\n";
         s+="Remaining E : "+DoubleToString(cm.remainingEnergy,0)+"\n";
         s+="Age         : "+IntegerToString(cm.age)+" bars\n";
         s+="Participants: buy "+DoubleToString(pa.buyer,0)+"  sell "+DoubleToString(pa.seller,0)+"  press "+DoubleToString(pa.marketPressure,0);
         break;
      case 6: // WAVE
         s+="Direction   : "+VZ_Dir(w.direction)+"\n";
         s+="Phase       : "+FalconPhaseStr(w.phase)+"  ("+VZ_Pct(w.completion)+")\n";
         s+="Origin/Ext  : "+VZ_Px(w.origin)+" / "+VZ_Px(w.extreme)+"   Obj "+VZ_Px(w.objective)+"\n";
         s+="Flip Zone   : "+VZ_Px(w.flipBot)+" - "+VZ_Px(w.flipTop)+"\n";
         s+="Sub-scores  : Exp "+DoubleToString(w.expansionScore,0)+" PreCvx "+DoubleToString(w.preConvexityScore,0)
            +" Cvx "+DoubleToString(w.convexityScore,0)+" Ind "+DoubleToString(w.inductionScore,0)+"\n";
         s+="            : Liq "+DoubleToString(w.liquidationScore,0)+" Abs "+DoubleToString(w.absorptionScore,0)
            +" Retr "+DoubleToString(w.retracementScore,0)+"\n";
         s+="FEZ         : "+(fez.active?VZ_Px(fez.bot)+"-"+VZ_Px(fez.top)+" "+VZ_Dir(fez.dir)+" "+DoubleToString(fez.distanceATR,1)+"ATR":"—")+"\n";
         s+="FRZ (return): "+(frz.active?VZ_Px(frz.targetPrice)+" "+VZ_Dir(frz.dir)+" ownerTF "+IntegerToString(frz.ownerTF):"—")+"\n";
         s+="Recursion   : breaks "+IntegerToString(w.recursionBreaks)+"  transfer "+DoubleToString(w.dominanceTransfer,0)+"%";
         break;
      case 7: // HTF
         s+="M1  "+VZ_Dir(h.dir[0])+"   M5  "+VZ_Dir(h.dir[1])+"\n";
         s+="M15 "+VZ_Dir(h.dir[2])+"   M30 "+VZ_Dir(h.dir[3])+"\n";
         s+="H1  "+VZ_Dir(h.dir[4])+"   H4  "+VZ_Dir(h.dir[5])+"\n";
         s+="Stack Dir   : "+VZ_Dir(h.stackDir)+"\n";
         s+="Alignment   : "+DoubleToString(h.alignment,0)+"%   Conflict "+DoubleToString(h.conflict,0)+"%\n";
         s+="Owner TF idx: "+IntegerToString(h.ownerTF)+"   Fractal "+(h.fractalAgreement?"AGREE":"split");
         break;
      case 8: // RISK
         s+="Risk OK     : "+(e.riskOk?"YES":"NO")+"\n";
         s+="VaR3 / lim  : "+DoubleToString(e.var3,0)+" / "+DoubleToString(e.var3Limit,0)+"\n";
         s+="Long  gross : "+DoubleToString(e.longGrossLots,2)+" lots  VaR "+DoubleToString(e.longGrossVaR,0)+"\n";
         s+="Short gross : "+DoubleToString(e.shortGrossLots,2)+" lots  VaR "+DoubleToString(e.shortGrossVaR,0)+"\n";
         s+="UDS max     : "+DoubleToString(e.udsMax,2)+"   Bomb "+(e.anyBomb?"YES":"no")+"\n";
         s+="Failure swg : "+DoubleToString(x.failureSwingProb*100.0,0)+"%   Loops left "+DoubleToString(x.expectedLoopsRemaining,1);
         break;
      case 9: // EXECUTION
         s+="Action      : "+FalconActionStr(e.action)+"\n";
         s+="Entry/Stop  : "+VZ_Px(e.entry)+" / "+VZ_Px(e.stop)+"\n";
         s+="Target      : "+VZ_Px(e.target)+"\n";
         s+="Lots        : "+DoubleToString(e.lots,2)+"   Risk $ "+DoubleToString(e.riskCash,0)+"\n";
         s+="Open L/S    : "+IntegerToString(e.openLongCount)+" / "+IntegerToString(e.openShortCount)+"\n";
         s+="Open PnL    : "+DoubleToString(e.openPnL,2)+"\n";
         s+="Session     : "+(e.sessionOpen?"OPEN":"closed");
         break;
      case 10: // PERFORMANCE
         s+="Open PnL    : "+DoubleToString(e.openPnL,2)+"\n";
         s+="Equity      : "+DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY),2)+"\n";
         s+="Peak equity : "+DoubleToString(g_perf.peakEquity,2)+"\n";
         s+="Max DD      : "+DoubleToString(g_perf.maxDrawdown,2)+"  ("+DoubleToString(g_perf.maxDrawdownPct,1)+"%)\n";
         s+="Trades W/L  : "+IntegerToString(g_perf.wins)+" / "+IntegerToString(g_perf.losses)+"\n";
         s+="Margin free : "+DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_FREE),2)+"\n";
         s+="Pipeline    : "+IntegerToString((int)g_diag.pipelineRuns)+" runs  "+DoubleToString((double)g_diag.pipelineMicros,0)+"us last";
         break;
      default: // DIAGNOSTICS
         for(int m=0;m<MOD_COUNT;m++)
            s+=StringFormat("%-14s %s  avg %.0fus  runs %d\n",
               FalconModuleName(m), g_diag.health[m].ok?"OK ":"ERR",
               FalconAvgMicros(m), g_diag.health[m].runs);
         s+=StringFormat("Events: bar %d impulse %d/%d bos %d choch %d spawn %d verdict %d orders %d",
             FalconEventCount(EVT_NEW_BAR),FalconEventCount(EVT_IMPULSE_BULL),FalconEventCount(EVT_IMPULSE_BEAR),
             FalconEventCount(EVT_BOS),FalconEventCount(EVT_CHOCH),FalconEventCount(EVT_WAVE_SPAWN),
             FalconEventCount(EVT_VERDICT_CHANGE),FalconEventCount(EVT_ORDER_SENT));
         break;
   }
   return(s);
}

//------------------------------------------------------------------
// Render the panel as a single multiline chart label.
//------------------------------------------------------------------
void VisualizationRun()
{
   if(!g_cfg.showDashboard) return;

   int tab=g_cfg.dashboardTab;
   string header="◤ FALCON OS ▌ "+VZ_TabName(tab)
                 +"   "+FalconActionStr(g_state.exec.action)
                 +"  ["+VZ_Dir(g_state.exec.master)+"]";
   // Tabs hint so the user knows how to switch views via the input.
   string tabs="Tabs: 0 Ovr·1 Phys·2 Struct·3 Net·4 Curve·5 Camp·6 Wave·7 HTF·8 Risk·9 Exec·10 Perf·11 Diag";

   string txt=header+"\n"
              +"────────────────────────────\n"
              +VZ_Body(tab)+"\n"
              +"────────────────────────────\n"
              +tabs;

   // Comment() is the single, reliable multiline render surface in MT5.
   Comment(txt);
}

void VisualizationDeinit()
{
   Comment("");
   ObjectDelete(0,VIZ_OBJ);
}

#endif // FALCON_VIZ_MQH
//+------------------------------------------------------------------+
