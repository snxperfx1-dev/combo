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
      case 12:return("LEARNING");
      case 13:return("ENGINES");
      case 14:return("COMMAND");
      case 15:return("PLANS");
      default:return("DIAGNOSTICS");
   }
}

string VZ_Band(const int b){ return(b==0?"Early":b==1?"Dev":b==2?"Mid":b==3?"Late":"Term"); }
string VZ_Reason(const int c)
{
   switch(c){ case VR_NOZONE:return("no-zone"); case VR_NOROOM:return("no-room");
              case VR_EXHAUST:return("exhausted"); case VR_LATE:return("late-curve");
              case VR_NETWORK:return("net-counter"); case VR_PARTICIPANT:return("part-counter"); }
   return("?");
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
   FalconFU  fuv=g_state.fu;
   FalconEntryCycle ecv=g_state.entryCycle;

   switch(tab)
   {
      case 0: // OVERVIEW
         s+="Action      : "+FalconActionStr(e.action)+"   ("+VZ_Dir(e.master)+")\n";
         s+="Cycle       : "+(ecv.terminal?"TERMINAL":"BUILDING")+"  "+FalconReadinessStr(ecv.readiness)
            +(ecv.entryCycleActive?"  <<ENTRY>>":"")+"\n";
         s+="Compression : "+FalconCompressionStr(ecv.compressionRegime)+"   recursions "+IntegerToString(ecv.recursionDepth)
            +"/"+DoubleToString(ecv.expectedDepth,1)+"  transfer "+(ecv.transitionComplete?"done":"building")+"\n";
         s+="Liq Wave    : "+(ecv.liqSubPhase==""?"—":ecv.liqSubPhase)+(ecv.liqActive?"  dist "+DoubleToString(ecv.liqDistPct,0)+"%":"")
            +(ecv.liqTrueChoch?"  CHoCH":"")+"\n";
         s+="Phase       : "+FalconPhaseStr(w.phase)+"  "+VZ_Pct(w.completion)+"\n";
         s+="Symphony    : "+(w.symMode==1?"LONG":w.symMode==-1?"SHORT":"—")
            +"  Pl="+IntegerToString(w.symPhaseLong)+" Ps="+IntegerToString(w.symPhaseShort)
            +(g_cfg.useSymphony?"  [AUTHORITY]":"")+"\n";
         s+="Owner       : "+VZ_Dir(g_state.campaign.owner)+"  ctrl "+DoubleToString(g_state.campaign.controlScore,0)
            +"  HTF "+DoubleToString(g_state.htf.alignment,0)+"%"+(g_state.htf.fractalAgreement?" agree":"")+"\n";
         s+="Curve here  : "+DoubleToString(g_state.curveLocator.pos*100.0,0)+"% "+g_state.curveLocator.label
            +(g_state.curveLocator.advancing?" adv":" retr")+"  room "+DoubleToString(g_state.convexity.geometryCapacity,0)
            +"  "+FalconResStr(x.resolutionState)+"\n";
         s+="Conviction  : "+DoubleToString(x.confidence,0)+"   ExecProb "+DoubleToString(x.executionProbability*100.0,0)+"%\n";
         s+="Master Chief: "+(x.masterChiefConfirm?"CLEARED":"HOLD")+"  ("+DoubleToString(x.masterChiefScore,0)+")  "+x.masterChiefNote+"\n";
         s+="SELF        : "+(g_cfg.useSelfAware? (g_state.self.label+"  conf "+DoubleToString(g_state.self.selfConfidence,0)
            +"  throttle x"+DoubleToString(g_state.self.throttle,2)
            +"  (calib "+DoubleToString(g_state.self.calibration,0)
            +" form "+DoubleToString(g_state.self.form,0)+" streak "+IntegerToString(g_state.self.winStreak)+"/"+IntegerToString(g_state.self.lossStreak)+")") : "off (full size)")+"\n";
         s+="Reasoning   : concrete engines (phases / ownership / curve / structure / multi-TF)\n";
         s+="Active cfg  : "+FalconEngineStr(g_cfg.entryEngine)+"  minR "+DoubleToString(g_cfg.minRR,1)
            +"  maxPos "+IntegerToString(g_cfg.maxOpenPositions)+(g_cfg.noHedge?" 1-dir":"")
            +"  TALON "+(g_cfg.useTalon?"on":"off")+"  PYRO "+(g_cfg.useThermalRisk?"on":"off")
            +"  free "+((g_cfg.cycleFreeRun&&g_cfg.runAllCycles)?"on":"off")+"\n";
         s+="Time        : "+g_state.timeIntel.sessionName+"  Q "+DoubleToString(g_state.timeIntel.timeQuality,0)+" "+g_state.timeIntel.label
            +(g_state.timeIntel.killzone?("  KZ:"+g_state.timeIntel.killzoneName):"");
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
         s+="Inducement  : "+(lq.induceActive?VZ_Px(lq.inducePrice)+(lq.induceSwept?" SWEPT":" armed"):"—")+"\n";
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
         s+="YOU ARE HERE: "+DoubleToString(g_state.curveLocator.pos*100.0,0)+"% of owner leg ("+g_state.curveLocator.label+")  "
            +(g_state.curveLocator.advancing?"advancing":"retracing")+"  conf "+DoubleToString(g_state.curveLocator.conf,0)+"\n";
         s+="Root        : "+VZ_Px(cu.rootOrigin)+" -> "+VZ_Px(cu.rootExtreme)+"  "+VZ_Dir(cu.rootDir)+"\n";
         s+="Parent      : "+VZ_Px(cu.parentOrigin)+" -> "+VZ_Px(cu.parentExtreme)+"  "+VZ_Dir(cu.parentDir)+"\n";
         s+="Life/Energy : "+DoubleToString(cu.life,0)+" / "+DoubleToString(cu.energy,0)+"\n";
         s+="Evolution   : "+DoubleToString(cu.evolution,0)+"%   emergent nodes "+IntegerToString(cu.emergentNodes)+"\n";
         s+="Wave Matrix : dom TF "+IntegerToString(wmx.dominantTF)+" "+VZ_Dir(wmx.dominantDir)
            +"  agree "+DoubleToString(wmx.agreement,0)+"%  E "+DoubleToString(wmx.matrixEnergy,0)+"\n";
         s+="Emergent    : "+FalconPhaseStr(cu.emergentPhase)+"\n";
         s+="── F72 TREE ─────────────────────────\n";
         s+="Nodes/Depth : "+IntegerToString(cu.treeNodeCount)+" alive  depth "+IntegerToString(cu.treeDepth)
            +"/"+IntegerToString(cu.budgetDepth)+(cu.recursionComplete?"  [RECURSION SPENT]":"")+"\n";
         s+="Owner Node  : "+VZ_Dir(cu.ownerNodeDir)+"  E "+DoubleToString(cu.ownerNodeEnergy,0)
            +"  d"+IntegerToString(cu.ownerNodeDepth)+"  "+cu.ownerNodeState+"\n";
         s+="Node leg    : "+VZ_Px(cu.ownerNodeOrigin)+" -> "+VZ_Px(cu.ownerNodeExtreme)+"\n";
         s+="Compression : "+cu.compState+"  force "+DoubleToString(cu.compForce,0)+"\n";
         s+="Migration   : 0.5 "+VZ_Px(cu.migration50)+"   0.618 "+VZ_Px(cu.migration618)+"\n";
         s+="Narrative   : "+DoubleToString(cu.narrative,0)+(cu.narrative>=55?" strengthening":cu.narrative<=45?" weakening":" balanced")
            +"  (sup "+IntegerToString(cu.supportVotes)+" / deg "+IntegerToString(cu.degradeVotes)+")\n";
         s+="── TIME (TIE) ───────────────────────\n";
         s+="Session     : "+g_state.timeIntel.sessionName+"  "+DoubleToString(g_state.timeIntel.sessionProgress*100.0,0)+"%"
            +(g_state.timeIntel.killzone?("  KZ:"+g_state.timeIntel.killzoneName):"")+"\n";
         s+="Time Quality: "+DoubleToString(g_state.timeIntel.timeQuality,0)+"  "+g_state.timeIntel.label
            +"  path "+DoubleToString(g_state.timeIntel.pathProbability*100.0,0)+"%"+(g_state.timeIntel.permit?"":"  [DEAD]");
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
      case 7: // HTF — absolute fractal ladder [0]M1 [1]M5 [2]M15 [3]H1 [4]H4 [5]D1 [6]W1
         s+="W1  "+VZ_Dir(h.dir[6])+"   D1  "+VZ_Dir(h.dir[5])+"\n";
         s+="H4  "+VZ_Dir(h.dir[4])+"   H1  "+VZ_Dir(h.dir[3])+"\n";
         s+="M15 "+VZ_Dir(h.dir[2])+"   M5  "+VZ_Dir(h.dir[1])+"   M1 "+VZ_Dir(h.dir[0])+"\n";
         s+="Operating TF: "+EnumToString(g_cfg.operatingTF)+"\n";
         s+="Stack Dir   : "+VZ_Dir(h.stackDir)+"\n";
         s+="Alignment   : "+DoubleToString(h.alignment,0)+"%   Conflict "+DoubleToString(h.conflict,0)+"%\n";
         s+="Owner TF idx: "+IntegerToString(h.ownerTF)+" ("+VZ_Dir(g_state.curve.ownerDir)+")   Fractal "+(h.fractalAgreement?"AGREE":"split")+"\n";
         s+="Owner zone  : "+((h.ownerTF>=0 && h.ownerTF<7 && g_tfZones[h.ownerTF].valid)?
              ("D "+VZ_Px(g_tfZones[h.ownerTF].demBot)+"-"+VZ_Px(g_tfZones[h.ownerTF].demTop)
              +"  S "+VZ_Px(g_tfZones[h.ownerTF].supBot)+"-"+VZ_Px(g_tfZones[h.ownerTF].supTop)) : "—")+"\n";
         s+="FU Candle   : "+(fuv.active?VZ_Dir(fuv.dir)+" zone "+VZ_Px(fuv.zoneBot)+"-"+VZ_Px(fuv.zoneTop)+"  conf "+DoubleToString(fuv.confidence,0)+"  life "+IntegerToString(fuv.lifecycle):"none");
         break;
      case 8: // RISK — PYRO Campaign Thermodynamics
      {
         FalconThermalCampaign cl=g_state.risk.campaign[0];
         FalconThermalCampaign cs=g_state.risk.campaign[1];
         FalconThermostat th=g_state.risk.thermostat;
         s+="Engine      : "+(g_cfg.useThermalRisk?"PYRO thermal ON":"OFF")+"   Risk OK "+(e.riskOk?"YES":"NO")+"\n";
         s+="LONG  camp  : "+IntegerToString(cl.stackCount)+" stacks  "+DoubleToString(cl.totalLots,2)+" lots\n";
         s+="  heat "+DoubleToString(cl.heat,2)+"  "+FalconAdmitStr(cl.admission)+"  x"+DoubleToString(cl.admitLotScale,2)
            +(cl.adverseATR>0.0?"  -"+DoubleToString(cl.adverseATR,1)+"ATR":"  +"+DoubleToString(cl.favorableATR,1)+"ATR")
            +(cl.breakevenLocked?"  BE-LOCK":"")+"\n";
         s+="SHORT camp  : "+IntegerToString(cs.stackCount)+" stacks  "+DoubleToString(cs.totalLots,2)+" lots\n";
         s+="  heat "+DoubleToString(cs.heat,2)+"  "+FalconAdmitStr(cs.admission)+"  x"+DoubleToString(cs.admitLotScale,2)
            +(cs.adverseATR>0.0?"  -"+DoubleToString(cs.adverseATR,1)+"ATR":"  +"+DoubleToString(cs.favorableATR,1)+"ATR")
            +(cs.breakevenLocked?"  BE-LOCK":"")+"\n";
         s+="Thermostat  : combined "+DoubleToString(th.combinedHeat,2)+"  acct "+DoubleToString(th.accountHeat*100.0,0)+"%"
            +(th.whipsawLock?"  WHIPSAW-LOCK":"")+"\n";
         s+="Blended E   : L "+VZ_Px(cl.blendedEntry)+"  S "+VZ_Px(cs.blendedEntry)+"\n";
         s+="Failure swg : "+DoubleToString(x.failureSwingProb*100.0,0)+"%   Loops left "+DoubleToString(x.expectedLoopsRemaining,1);
         break;
      }
      case 9: // EXECUTION
         s+="Action      : "+FalconActionStr(e.action)+"\n";
         s+="Last entry  : "+(e.lastEntrySource==""?"— none yet":(e.lastEntrySource+"  <"+e.lastEntryTag+">"
            +(e.lastEntryTime>0?("  "+TimeToString(e.lastEntryTime,TIME_MINUTES)):"")))+"\n";
         s+="Trade State : "+FalconTradeStateStr(e.tradeState)+"   Last exit "+FalconExitStateStr(e.exitState)+"\n";
         s+="Entry/Stop  : "+VZ_Px(e.entry)+" / "+VZ_Px(e.stop)+"\n";
         s+="Target      : "+VZ_Px(e.target)+"   R:R "+DoubleToString(e.reward,2)+"\n";
         s+="Plan        : stop<"+(g_plan.stopSrc==""?"—":g_plan.stopSrc)+"> target<"+(g_plan.targetSrc==""?"—":g_plan.targetSrc)+"> tf"+IntegerToString(g_plan.targetTF)+"  conv x"+DoubleToString(g_plan.convictionMult,2)+"\n";
         s+="TALON grip  : L "+(e.gripLong>0?VZ_Px(e.gripLong)+" "+FalconTalonStr(e.talonStageLong):"—")
            +"   S "+(e.gripShort>0?VZ_Px(e.gripShort)+" "+FalconTalonStr(e.talonStageShort):"—")+"\n";
         s+="Lots        : "+DoubleToString(e.lots,2)+"   Risk $ "+DoubleToString(e.riskCash,0)+"\n";
         s+="Fact gate   : "+(g_cfg.useFactGate?(sym_factVeto==""?"clear":"VETO — "+sym_factVeto):"off")+"\n";
         s+="Self-learn  : L x"+DoubleToString(AD_SizeMult(AD_Bucket(DIR_LONG)),2)+" (n"+IntegerToString(ad_n[AD_Bucket(DIR_LONG)])+")"
            +"  S x"+DoubleToString(AD_SizeMult(AD_Bucket(DIR_SHORT)),2)+" (n"+IntegerToString(ad_n[AD_Bucket(DIR_SHORT)])+")\n";
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
      case 12: // LEARNING — what the OS is learning about itself
      {
         FalconSelfAwareness sf=g_state.self;
         if(!g_cfg.useSelfAware)
            s+="SELF        : off (no throttle / no stand-down)\n";
         else {
         s+="SELF        : "+sf.label+"  conf "+DoubleToString(sf.selfConfidence,0)
            +"  throttle x"+DoubleToString(sf.throttle,2)+"\n";
         s+="            : calib "+DoubleToString(sf.calibration,0)+"  form "+DoubleToString(sf.form,0)
            +"  regime "+DoubleToString(sf.regimeFit,0)+"  streak "+IntegerToString(sf.winStreak)+"W/"+IntegerToString(sf.lossStreak)+"L\n";
         }
         s+="── ADAPTIVE — which setups pay (size/veto) ──\n";
         int shown=0;
         for(int b=0;b<AD_NBUCKETS;b++)
         {
            if(ad_n[b]==0) continue;
            double wr=100.0*ad_wins[b]/ad_n[b];
            string tag=(b<5?"L":"S")+("-"+VZ_Band(b%5));
            s+=StringFormat("  %-7s n%-3d wr%2.0f%%  R%+.2f  x%.2f%s\n",
                 tag, ad_n[b], wr, ad_ewmaR[b], AD_SizeMult(b),
                 (AD_Veto(b)?"  VETO":""));
            shown++;
         }
         if(shown==0) s+="  (no closed trades yet)\n";
         s+="── REGRET — misses it would've won (override) ──\n";
         int codes[6]={VR_NOZONE,VR_NOROOM,VR_EXHAUST,VR_LATE,VR_NETWORK,VR_PARTICIPANT};
         int rshown=0;
         for(int i=0;i<6;i++)
         {
            int c=codes[i]; if(mt_n[c]==0) continue;
            double wr=100.0*mt_win[c]/mt_n[c];
            s+=StringFormat("  %-12s n%-3d wr%2.0f%%  R%+.2f%s\n",
                 VZ_Reason(c), mt_n[c], wr, mt_R[c], (MT_Override(c)?"  TAKING":""));
            rshown++;
         }
         if(rshown==0) s+="  (no resolved shadow trades yet)";
         break;
      }
      case 13: // ENGINES — comparative multi-engine wave cycles (A/B/C)
      {
         WaveReferee rf=g_state.referee;
         WaveCycle L=g_state.cycles[ENG_LETRA];
         WaveCycle F=g_state.cycles[ENG_F16];
         WaveCycle Y=g_state.cycles[ENG_SYMPHONY];
         s+="AUTHORITY   : "+FalconEngineStr(g_cfg.entryEngine)+" -> drives "+rf.selectedName
            +(g_cfg.runAllCycles?"":"  (compare OFF)")+"\n";
         s+="                 LETRA       F16        SYMPHONY\n";
         s+=StringFormat("dir         : %-11s %-10s %-10s\n", VZ_Dir(L.direction),VZ_Dir(F.direction),VZ_Dir(Y.direction));
         s+=StringFormat("stage       : %-11s %-10s %-10s\n", FalconStageStr(L.stage),FalconStageStr(F.stage),FalconStageStr(Y.stage));
         s+=StringFormat("phase       : %-11s %-10s %-10s\n",
              StringSubstr(L.phaseLabel,0,10),StringSubstr(F.phaseLabel,0,10),StringSubstr(Y.phaseLabel,0,10));
         s+=StringFormat("maturity    : %-11.0f %-10.0f %-10.0f\n", L.maturity,F.maturity,Y.maturity);
         s+=StringFormat("confidence  : %-11.0f %-10.0f %-10.0f\n", L.confidence,F.confidence,Y.confidence);
         s+=StringFormat("objective   : %-11s %-10s %-10s\n", VZ_Px(L.objective),VZ_Px(F.objective),VZ_Px(Y.objective));
         s+=StringFormat("entry now   : %-11s %-10s %-10s\n",
              (L.entryEdge?("P"+IntegerToString(L.entryKind)+" "+VZ_Dir(L.entryDir)):"-"),
              (F.entryEdge?("P"+IntegerToString(F.entryKind)+" "+VZ_Dir(F.entryDir)):"-"),
              (Y.entryEdge?("P"+IntegerToString(Y.entryKind)+" "+VZ_Dir(Y.entryDir)):"-"));
         s+="── DEMONSTRATED EDGE (referee) ──────\n";
         s+=StringFormat("dir acc%%    : %-11s %-10s %-10s\n",
              StringFormat("%.0f(%d)",L.accuracy,L.samples),
              StringFormat("%.0f(%d)",F.accuracy,F.samples),
              StringFormat("%.0f(%d)",Y.accuracy,Y.samples));
         s+=StringFormat("obj acc%%    : %-11.0f %-10.0f %-10.0f\n", L.objAccuracy,F.objAccuracy,Y.objAccuracy);
         s+=StringFormat("lead (bars) : %-11.1f %-10.1f %-10.1f\n", L.avgLeadBars,F.avgLeadBars,Y.avgLeadBars);
         s+="── REFEREE VERDICT ──────────────────\n";
         s+="consensus   : "+VZ_Dir(rf.consensusDir)+"  "+FalconStageStr(rf.consensusStage)
            +"  conf "+DoubleToString(rf.consensusConf,0)+"\n";
         s+="deviation   : stage "+DoubleToString(rf.deviationStage,0)+"   objective "+DoubleToString(rf.deviationObjATR,1)+" ATR\n";
         s+="best engine : "+FalconEngineStr(rf.bestEngine)+"  acc "+DoubleToString(rf.bestAccuracy,0)
            +"%   leader "+FalconEngineStr(rf.leader)+"\n";
         s+="money mgr   : "+((g_cfg.useProfitLadder||g_cfg.counterDirBlock||g_cfg.maxBasketRiskPct>0)?"on":"DISABLED");
         break;
      }
      case 14: // COMMAND — execution + self-learning + engine comparison at a glance
      {
         WaveReferee rf=g_state.referee;
         WaveCycle L=g_state.cycles[ENG_LETRA];
         WaveCycle F=g_state.cycles[ENG_F16];
         WaveCycle Y=g_state.cycles[ENG_SYMPHONY];
         // ---- EXECUTION ----
         s+="── EXECUTION ─────────────────────────\n";
         s+="Act "+FalconActionStr(e.action)+"  "+FalconTradeStateStr(e.tradeState)+"  open L/S "+IntegerToString(e.openLongCount)+"/"+IntegerToString(e.openShortCount)+"\n";
         s+="E/SL/TP "+VZ_Px(e.entry)+" / "+VZ_Px(e.stop)+" / "+VZ_Px(e.target)+"  R:R "+DoubleToString(e.reward,2)+"\n";
         s+="GEOM    : "+TG_BandStr(e.tradeBand)+"  stop "+VZ_Px(e.stopDistPts)+"  tgt "+VZ_Px(e.tgtDistPts)
            +"  ("+DoubleToString((g_state.physics.atr>0?e.stopDistPts/g_state.physics.atr:0),1)+" ATR)\n";
         s+="TALON L "+(e.gripLong>0?VZ_Px(e.gripLong)+" "+FalconTalonStr(e.talonStageLong):"—")
            +"  S "+(e.gripShort>0?VZ_Px(e.gripShort)+" "+FalconTalonStr(e.talonStageShort):"—")+"\n";
         s+="Lots "+DoubleToString(e.lots,2)+"  Risk$ "+DoubleToString(e.riskCash,0)+"  PnL "+DoubleToString(e.openPnL,2)
            +"  "+(e.sessionOpen?"SES":"--")+"  gate "+(g_cfg.useFactGate?(sym_factVeto==""?"clear":sym_factVeto):"off")+"\n";
         // ---- SELF-LEARNING ----
         s+="── SELF-LEARNING ─────────────────────\n";
         if(g_cfg.useSelfAware)
            s+="SELF "+g_state.self.label+" x"+DoubleToString(g_state.self.throttle,2)
               +"  "+IntegerToString(g_state.self.winStreak)+"W/"+IntegerToString(g_state.self.lossStreak)+"L\n";
         else s+="SELF off\n";
         s+="Adaptive L x"+DoubleToString(AD_SizeMult(AD_Bucket(DIR_LONG)),2)+"(n"+IntegerToString(ad_n[AD_Bucket(DIR_LONG)])+")"
            +"  S x"+DoubleToString(AD_SizeMult(AD_Bucket(DIR_SHORT)),2)+"(n"+IntegerToString(ad_n[AD_Bucket(DIR_SHORT)])+")"
            +"  globR "+DoubleToString(ad_globalR,2)+"\n";
         int ccodes[6]={VR_NOZONE,VR_NOROOM,VR_EXHAUST,VR_LATE,VR_NETWORK,VR_PARTICIPANT};
         int taking=0; for(int i=0;i<6;i++) if(MT_Override(ccodes[i])) taking++;
         s+="Regret overrides active: "+IntegerToString(taking)+"\n";
         // ---- ENGINE COMPARISON ----
         s+="── ENGINES (dir · stage · acc%(n)) ───\n";
         s+=StringFormat("LETRA %-5s %-10s %.0f(%d)\n", VZ_Dir(L.direction),FalconStageStr(L.stage),L.accuracy,L.samples);
         s+=StringFormat("F16   %-5s %-10s %.0f(%d)\n", VZ_Dir(F.direction),FalconStageStr(F.stage),F.accuracy,F.samples);
         s+=StringFormat("SYMPH %-5s %-10s %.0f(%d)\n", VZ_Dir(Y.direction),FalconStageStr(Y.stage),Y.accuracy,Y.samples);
         s+="Consensus "+VZ_Dir(rf.consensusDir)+" "+FalconStageStr(rf.consensusStage)
            +"  dev st"+DoubleToString(rf.deviationStage,0)+"/"+DoubleToString(rf.deviationObjATR,1)+"ATR\n";
         s+="Best "+FalconEngineStr(rf.bestEngine)+" "+DoubleToString(rf.bestAccuracy,0)+"%"
            +"  Lead "+FalconEngineStr(rf.leader)+"  Auth "+FalconEngineStr(g_cfg.entryEngine);
         break;
      }
      case 15: // PLANS — the Trade Planning Layer queue (FALCON OS 9.0)
      {
         s+="PLANNER     : "+(g_cfg.usePlanner?"ON":"off")+"   live plans "+IntegerToString(g_state.planCount)+"\n";
         s+="── FORECAST (what the engines expect next) ──\n";
         s+="Wave next   : "+FalconPhaseStr(w.expectedNextPhase)+"  ret "+VZ_Px(w.expectedReturnZone)
            +"  p"+DoubleToString(w.forecastProb,0)+"%  ~"+IntegerToString(w.expectedBars)+"b"
            +"  cap "+DoubleToString(w.remainingCapacity,0)+"%\n";
         s+="Curve       : "+(cu.childExpected?("child~"+IntegerToString(cu.expectedSpawnBars)+"b"):"no-child")
            +"  "+(cu.transferLikely?"transfer-likely":"owner-holds")
            +(cu.waitForChild?"  [WAIT-CHILD]":"")+"\n";
         s+="Schedule    : next turn ~"+IntegerToString(g_state.timeIntel.barsToNextTurn)+"b"
            +"  "+(g_state.timeIntel.bestEntryWindow?"WINDOW-OPEN":"window-wait")
            +(g_state.timeIntel.nextEvent!=""?("  ("+g_state.timeIntel.nextEvent+")"):"")+"\n";
         s+="─────────────────────────────────────\n";
         int shown=0;
         for(int i=0;i<FALCON_MAX_PLANS;i++)
         {
            FalconPlan p=g_state.plans[i];
            if(!p.active) continue;
            if(p.state==PLAN_EXPIRED || p.state==PLAN_CANCELLED) continue;
            shown++;
            s+=StringFormat("#%d %-12s %-4s %-9s pr%d rr%.1f\n",
                 p.id, FalconPlanTypeStr(p.type), VZ_Dir(p.dir), FalconPlanStateStr(p.state), p.priority, p.rr);
            s+="   zone "+VZ_Px(p.zoneBot)+"-"+VZ_Px(p.zoneTop)+" ("+p.zoneSrc+")"
               +(p.fuAnchor>0?("  FU "+VZ_Px(p.fuAnchor)):"")+"\n";
            s+="   SL "+VZ_Px(p.stop)+"  T1 "+VZ_Px(p.t1)+"  T2 "+VZ_Px(p.t2)+"("+p.tgtSrc+")  T3 "+VZ_Px(p.t3)+"\n";
            s+="   "+(p.atZone?"@zone":"away")+" "+(p.inWindow?"time-ok":"time-wait")
               +" "+(p.needSweep?(p.sweepDone?"swept":"no-sweep"):"-")
               +" "+(p.structDone?"struct-ok":"struct-wait")
               +" "+(p.hasRoom?"room":"no-room")
               +"  conf "+DoubleToString(p.confidence,0)+"\n";
         }
         if(shown==0) s+="  (no active plans — owner direction unresolved or no zone)";
         break;
      }
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
//------------------------------------------------------------------
// FLIGHT HUD — plot the live flight plan as horizontal levels on the
// chart: entry · stop · target · flip-top · flip-bot · inducement.
// Replaces F16's HUD; reads only shared state.
//------------------------------------------------------------------
void VZ_HLine(const string tag,const double price,const color col,const int style)
{
   if(price<=0){ ObjectDelete(0,tag); return; }
   if(ObjectFind(0,tag)<0)
   {
      ObjectCreate(0,tag,OBJ_HLINE,0,0,price);
      ObjectSetInteger(0,tag,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,tag,OBJPROP_BACK,true);
      ObjectSetInteger(0,tag,OBJPROP_WIDTH,1);
   }
   ObjectSetInteger(0,tag,OBJPROP_COLOR,col);
   ObjectSetInteger(0,tag,OBJPROP_STYLE,style);
   ObjectSetDouble (0,tag,OBJPROP_PRICE,price);
}

void VZ_FlightHUD()
{
   if(!g_cfg.showHUD)
   {
      ObjectDelete(0,VIZ_OBJ+"_entry"); ObjectDelete(0,VIZ_OBJ+"_stop");
      ObjectDelete(0,VIZ_OBJ+"_tgt");   ObjectDelete(0,VIZ_OBJ+"_ftop");
      ObjectDelete(0,VIZ_OBJ+"_fbot");  ObjectDelete(0,VIZ_OBJ+"_induc");
      return;
   }
   FalconWave w=g_state.wave;
   FalconExecution e=g_state.exec;
   FalconLiquidity lq=g_state.liquidity;

   VZ_HLine(VIZ_OBJ+"_entry", e.entry,        clrDeepSkyBlue, STYLE_SOLID);
   VZ_HLine(VIZ_OBJ+"_stop",  e.stop,         clrTomato,      STYLE_DOT);
   VZ_HLine(VIZ_OBJ+"_tgt",   e.target,       clrLime,        STYLE_DASH);
   VZ_HLine(VIZ_OBJ+"_ftop",  w.flipTop,      clrDimGray,     STYLE_DOT);
   VZ_HLine(VIZ_OBJ+"_fbot",  w.flipBot,      clrDimGray,     STYLE_DOT);
   VZ_HLine(VIZ_OBJ+"_induc", lq.inducePrice, clrGold,        STYLE_DASHDOT);
}

void VisualizationRun()
{
   VZ_FlightHUD();   // self-cleans when disabled
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
   ObjectDelete(0,VIZ_OBJ+"_entry"); ObjectDelete(0,VIZ_OBJ+"_stop");
   ObjectDelete(0,VIZ_OBJ+"_tgt");   ObjectDelete(0,VIZ_OBJ+"_ftop");
   ObjectDelete(0,VIZ_OBJ+"_fbot");  ObjectDelete(0,VIZ_OBJ+"_induc");
}

//------------------------------------------------------------------
// Tab switching. Press T (or RIGHT arrow) to advance tabs, SHIFT+T
// (or LEFT arrow) to go back. Wired from the EA's OnChartEvent.
//------------------------------------------------------------------
void FalconVizOnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   if(id!=CHARTEVENT_KEYDOWN) return;
   int prev=g_cfg.dashboardTab;
   if(lparam==84 || lparam==39)       g_cfg.dashboardTab = (g_cfg.dashboardTab+1)%16;  // 'T' / RIGHT
   else if(lparam==37)                g_cfg.dashboardTab = (g_cfg.dashboardTab+15)%16;  // LEFT
   if(g_cfg.dashboardTab!=prev) VisualizationRun();
}

#endif // FALCON_VIZ_MQH
//+------------------------------------------------------------------+
