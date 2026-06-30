//+------------------------------------------------------------------+
//|  FALCON OS — Planning Layer : Planner.mqh   (FALCON OS 9.0)      |
//|                                                                  |
//|  The TRADE PLANNING LAYER. It never observes the market, never   |
//|  calculates indicators, never finds structure. It CONSUMES the   |
//|  completed outputs of every Market / Memory / Intelligence engine|
//|  and assembles persistent, executable TradePlan objects, which it |
//|  maintains as a state machine. Every engine OWNS one field of the |
//|  plan; the planner only assembles. The Decision Engine then       |
//|  evaluates plans (it never analyses the market directly).        |
//|                                                                  |
//|     HTF + Campaign + Structure  -> direction / permission        |
//|     OB / S&D / FU / Liquidity / FEZ / owner-TF zone -> LOCATION   |
//|     Structure swing             -> STOP                          |
//|     Curve-tree / ARC / Network / FRZ / Wave -> DESTINATION       |
//|     Liquidity sweep / Participants / Structure -> TRIGGER         |
//|     Time Engine                 -> execution WINDOW              |
//|     Curve Locator / Convexity   -> ROOM (early/late)             |
//|     Wave Matrix / ownership-TF / Intelligence -> CONVICTION      |
//|                                                                  |
//|  Include AFTER SymphonyEngine.mqh (reuses Sym_StructuralStop /   |
//|  Sym_PlaceEntry) and before Visualization.mqh.                   |
//+------------------------------------------------------------------+
#ifndef FALCON_PLANNER_MQH
#define FALCON_PLANNER_MQH

#include "../Kernel/FalconState.mqh"
#include "../Kernel/FalconConfig.mqh"
#include "../Kernel/FalconSeries.mqh"
#include "../Kernel/FalconEventBus.mqh"

int g_planSeq = 0;

void PlannerInit()
{
   for(int i=0;i<FALCON_MAX_PLANS;i++){ ZeroMemory(g_state.plans[i]); g_state.plans[i].active=false; }
   g_state.planCount=0; g_planSeq=0;
}

int Plan_Find(const int type,const int dir)
{
   for(int i=0;i<FALCON_MAX_PLANS;i++)
      if(g_state.plans[i].active && g_state.plans[i].type==type && g_state.plans[i].dir==dir &&
         g_state.plans[i].state!=PLAN_EXECUTED && g_state.plans[i].state!=PLAN_EXPIRED && g_state.plans[i].state!=PLAN_CANCELLED)
         return(i);
   return(-1);
}
int Plan_Alloc()
{
   for(int i=0;i<FALCON_MAX_PLANS;i++)
      if(!g_state.plans[i].active ||
         g_state.plans[i].state==PLAN_EXECUTED || g_state.plans[i].state==PLAN_EXPIRED || g_state.plans[i].state==PLAN_CANCELLED)
         return(i);
   return(-1);
}

//------------------------------------------------------------------
// LOCATION — the entry zone. Each zone subsystem contributes a candidate;
// the planner picks the nearest one on the correct side of price (demand
// for longs / supply for shorts).
//------------------------------------------------------------------
void Planner_EntryZone(const int dir,const double price,const double atr,double &zTop,double &zBot,string &src)
{
   zTop=0; zBot=0; src="";
   double ct[12], cb[12]; string cs[12]; int n=0;
   int ot=g_state.htf.ownerTF;

   if(dir==DIR_LONG)
   {
      if(g_state.supplyDemand.demandTop>0){ cb[n]=g_state.supplyDemand.demandBot; ct[n]=g_state.supplyDemand.demandTop; cs[n]="demand"; n++; }
      if(g_state.orderBlocks.activeDir==DIR_LONG && g_state.orderBlocks.activeBot>0){ cb[n]=g_state.orderBlocks.activeBot; ct[n]=g_state.orderBlocks.activeTop; cs[n]="OB"; n++; }
      if(g_state.wave.flipBot>0 && g_state.wave.flipTop>0){ cb[n]=g_state.wave.flipBot; ct[n]=g_state.wave.flipTop; cs[n]="flip"; n++; }
      if(g_state.liquidity.induceBot>0){ cb[n]=g_state.liquidity.induceBot; ct[n]=g_state.liquidity.induceTop; cs[n]="inducement"; n++; }
      if(g_state.fu.active && g_state.fu.dir==DIR_LONG && g_state.fu.zoneBot>0){ cb[n]=g_state.fu.zoneBot; ct[n]=g_state.fu.zoneTop; cs[n]="FU"; n++; }
      if(ot>=0 && ot<7 && g_tfZones[ot].valid && g_tfZones[ot].demBot>0){ cb[n]=g_tfZones[ot].demBot; ct[n]=g_tfZones[ot].demTop; cs[n]="ownerDemand"; n++; }
   }
   else if(dir==DIR_SHORT)
   {
      if(g_state.supplyDemand.supplyTop>0){ cb[n]=g_state.supplyDemand.supplyBot; ct[n]=g_state.supplyDemand.supplyTop; cs[n]="supply"; n++; }
      if(g_state.orderBlocks.activeDir==DIR_SHORT && g_state.orderBlocks.activeTop>0){ cb[n]=g_state.orderBlocks.activeBot; ct[n]=g_state.orderBlocks.activeTop; cs[n]="OB"; n++; }
      if(g_state.wave.flipBot>0 && g_state.wave.flipTop>0){ cb[n]=g_state.wave.flipBot; ct[n]=g_state.wave.flipTop; cs[n]="flip"; n++; }
      if(g_state.liquidity.induceTop>0){ cb[n]=g_state.liquidity.induceBot; ct[n]=g_state.liquidity.induceTop; cs[n]="inducement"; n++; }
      if(g_state.fu.active && g_state.fu.dir==DIR_SHORT && g_state.fu.zoneTop>0){ cb[n]=g_state.fu.zoneBot; ct[n]=g_state.fu.zoneTop; cs[n]="FU"; n++; }
      if(ot>=0 && ot<7 && g_tfZones[ot].valid && g_tfZones[ot].supTop>0){ cb[n]=g_tfZones[ot].supBot; ct[n]=g_tfZones[ot].supTop; cs[n]="ownerSupply"; n++; }
   }

   double best=1e18;
   for(int i=0;i<n;i++)
   {
      if(ct[i]<=0 || cb[i]<=0) continue;
      double mid=(ct[i]+cb[i])*0.5;
      bool side = (dir==DIR_LONG ? mid <= price+0.2*atr : mid >= price-0.2*atr);
      if(!side) continue;
      double d=MathAbs(price-mid);
      if(d<best){ best=d; zTop=ct[i]; zBot=cb[i]; src=cs[i]; }
   }
}

//------------------------------------------------------------------
// DESTINATION — three targets owned by Wave/ARC (T1), FRZ/owner-curve
// (T2), Network (T3). Falls back to R-multiples only if an engine has
// nothing to offer.
//------------------------------------------------------------------
void Planner_Targets(const int dir,const double entry,const double stop,const double atr,
                     double &t1,double &t2,double &t3,string &src)
{
   double risk=MathAbs(entry-stop); if(risk<=0.0) risk=atr;
   bool L=(dir==DIR_LONG);

   // T1 — nearest objective (Wave -> ARC)
   t1=0; string s1="";
   double wo=g_state.wave.objective;
   if(wo>0 && ((L&&wo>entry)||(!L&&wo<entry))){ t1=wo; s1="wave"; }
   double arc=(L?g_state.convexity.arcLong:g_state.convexity.arcShort);
   if(t1<=0 && arc>0 && ((L&&arc>entry)||(!L&&arc<entry))){ t1=arc; s1="arc"; }
   if(t1<=0){ t1=(L?entry+2.0*risk:entry-2.0*risk); s1="2R"; }

   // T2 — owner-curve destination (FRZ -> curve owner node)
   t2=0; string s2="";
   if(g_state.frz.active && g_state.frz.targetPrice>0 && ((L&&g_state.frz.targetPrice>t1)||(!L&&g_state.frz.targetPrice<t1)))
   { t2=g_state.frz.targetPrice; s2="FRZ"; }
   double ext=g_state.curve.ownerNodeExtreme, org=g_state.curve.ownerNodeOrigin;
   if(t2<=0 && ext>0 && org>0){ double leg=MathAbs(ext-org); t2=(L?ext+leg*0.5:ext-leg*0.5); s2="owner"; }
   if(t2<=0){ t2=(L?entry+4.0*risk:entry-4.0*risk); s2="4R"; }

   // T3 — next authoritative network node beyond T2 (else extend)
   t3=0; double bestScore=-1.0;
   for(int i=0;i<g_state.network.count;i++)
   {
      if(g_state.network.nstate[i]!=0) continue;       // active nodes only
      double px=g_state.network.px[i];
      bool beyond=(L? px>t2 : px<t2);
      if(beyond && g_state.network.score[i]>bestScore){ bestScore=g_state.network.score[i]; t3=px; }
   }
   if(t3<=0) t3=(L? t2+2.0*risk : t2-2.0*risk);

   src=s2;   // the destination's defining engine
}

//------------------------------------------------------------------
// REFRESH — re-assemble a plan's fields from the current engine outputs
// and advance its state machine.
//------------------------------------------------------------------
void Plan_Refresh(const int idx,const int dir,const double price,const double atr,const int ot)
{
   FalconPlan p=g_state.plans[idx];
   if(p.state==PLAN_EXECUTED || p.state==PLAN_EXPIRED || p.state==PLAN_CANCELLED) return;

   // LOCATION
   double zt,zb; string zs; Planner_EntryZone(dir,price,atr,zt,zb,zs);
   p.ownerTF=ot;
   if(zt<=0.0 || zb<=0.0)
   {
      // STAGE-AHEAD: no live zone yet -> stage the entry at the wave's FORECAST
      // return zone, so the plan exists BEFORE price arrives (plan-before-it-exists).
      double rz=g_state.wave.expectedReturnZone;
      if(rz>0.0){ zt=rz+atr*0.25; zb=rz-atr*0.25; zs="forecast"; }
      else { p.zoneSrc="(no zone)"; p.state=PLAN_WAITING; g_state.plans[idx]=p; return; }
   }
   p.zoneTop=zt; p.zoneBot=zb; p.zoneSrc=zs;
   p.fuAnchor=(g_state.fu.active && g_state.fu.dir==dir)? g_state.fu.mid : 0.0;

   // RISK (structural stop) — no structure -> plan can't arm
   double sl=Sym_StructuralStop(dir,price,atr);
   if(sl<=0.0){ p.stopSrc="(no struct)"; p.state=PLAN_WAITING; g_state.plans[idx]=p; return; }
   p.entry=price; p.stop=sl; p.stopSrc="structure";

   // DESTINATION
   double t1,t2,t3; string ts; Planner_Targets(dir,price,sl,atr,t1,t2,t3,ts);
   p.t1=t1; p.t2=t2; p.t3=t3; p.tgtSrc=ts;
   double risk=MathAbs(price-sl);
   p.rr=(risk>0.0 ? MathAbs(t2-price)/risk : 0.0);

   // TRIGGERS / DEPENDENCIES
   p.atZone   = (price>=zb && price<=zt);
   // SCHEDULER: when time intel is on, only the best execution window opens the
   // gate (kill-zone or just before an hourly turn) — true scheduling, not just
   // "London is open".
   p.inWindow = (!g_cfg.useTimeIntel || g_state.timeIntel.bestEntryWindow);
   p.needSweep= g_cfg.planNeedSweep;
   p.sweepDone= (!p.needSweep) || g_state.liquidity.induceSwept ||
                (dir==DIR_LONG ? g_state.liquidity.sweepBull : g_state.liquidity.sweepBear);
   p.needStruct=g_cfg.planNeedStruct;
   bool structAgainst=(dir==DIR_LONG && g_state.structure.choch==DIR_SHORT) ||
                      (dir==DIR_SHORT && g_state.structure.choch==DIR_LONG);
   p.structDone=(!p.needStruct) || !structAgainst;
   p.hasRoom = (!g_cfg.useCurveLocator || g_state.curveLocator.pos < g_cfg.maxOwnerLegPos) &&
               (g_state.convexity.geometryCapacity >= g_cfg.minEntryRoomPct) &&
               (g_state.wave.completion < g_cfg.maxEntryComplete);

   // CONVICTION / RANK — composed, then VALIDATED by the Intelligence layer
   // (referee consensus + execution probability). The planner builds; the
   // intelligence layer scores — it does not generate the plan.
   double conv = g_state.htf.alignment*0.30 + g_state.waveMatrix.agreement*0.25
               + g_state.curve.ownerNodeEnergy*0.25 + g_state.wave.forecastProb*0.20;
   bool refAgree = (g_state.referee.consensusDir==dir);     // comparative referee agrees
   if(refAgree)        conv += 10.0;                        // consensus validation
   if(p.fuAnchor>0.0)  conv += 5.0;                         // FU execution anchor present
   p.confidence = FalconClamp(conv,0,100);
   p.execProb   = g_state.intel.executionProbability;       // 0..1
   double refBest = (g_state.referee.bestAccuracy>0.0 ? g_state.referee.bestAccuracy : 50.0);
   p.priority = (int)FalconClamp(
                   p.confidence*0.50
                 + ot*4.0                                   // higher-TF owner = higher priority
                 + (p.rr>=g_cfg.minRR?10.0:0.0)
                 + p.execProb*100.0*0.15                    // intelligence execution probability
                 + refBest*0.10                             // best engine's demonstrated accuracy
                 + (refAgree?10.0:0.0), 0, 100);

   // EXPIRY
   if(g_barCounter - p.createdBar > g_cfg.planExpiryBars){ p.state=PLAN_EXPIRED; g_state.plans[idx]=p; return; }

   // STATE MACHINE
   bool waitChild = g_state.curve.waitForChild;     // curve tree says: wait for the child/transfer
   if(waitChild)                                                        p.state=PLAN_DORMANT;
   else if(p.rr < g_cfg.minRR || p.confidence < g_cfg.planMinConf)      p.state=PLAN_WAITING;
   else if(!p.atZone)                                                   p.state=PLAN_WAITING;
   else if(!p.inWindow)                                                 p.state=PLAN_ARMED;
   else if(p.sweepDone && p.structDone && p.hasRoom)                    p.state=PLAN_TRIGGERED;
   else                                                                 p.state=PLAN_ARMED;

   g_state.plans[idx]=p;
}

//------------------------------------------------------------------
// propose-or-refresh a plan of a given type+direction; cancel a type.
//------------------------------------------------------------------
void Plan_Ensure(const int type,const int dir,const double price,const double atr,const int ot,const string note)
{
   if(dir==DIR_NONE) return;
   int idx=Plan_Find(type,dir);
   if(idx<0)
   {
      idx=Plan_Alloc();
      if(idx<0) return;
      FalconPlan np; ZeroMemory(np);
      np.id=++g_planSeq; np.active=true; np.type=type; np.dir=dir;
      np.state=PLAN_WAITING; np.createdBar=g_barCounter; np.ownerTF=ot; np.note=note;
      g_state.plans[idx]=np;
   }
   Plan_Refresh(idx,dir,price,atr,ot);
}
void Plan_CancelType(const int type)
{
   for(int i=0;i<FALCON_MAX_PLANS;i++)
      if(g_state.plans[i].active && g_state.plans[i].type==type &&
         g_state.plans[i].state!=PLAN_EXECUTED && g_state.plans[i].state!=PLAN_EXPIRED && g_state.plans[i].state!=PLAN_CANCELLED)
         g_state.plans[i].state=PLAN_CANCELLED;
}

//==================================================================
// MASTER — propose & maintain the plan queue (does NOT execute; the
// Decision/execution wiring fires TRIGGERED plans).
//==================================================================
void PlannerRun()
{
   if(!g_cfg.usePlanner) return;
   double atr=g_state.physics.atr; if(atr<=0.0) atr=FalconATR(1); if(atr<=0.0) return;
   double price=(gClose[1]>0.0?gClose[1]:g_state.close);
   int ot=g_state.htf.ownerTF; if(ot<0||ot>6) ot=4;

   // owner direction — who controls price (curve tree -> ownership -> HTF)
   int dir=g_state.curve.ownerNodeDir;
   if(dir==DIR_NONE) dir=g_state.curve.ownerDir;
   if(dir==DIR_NONE) dir=g_state.htf.stackDir;

   // 1) expire on timer; cancel a CONTINUATION plan only when ownership flips
   for(int i=0;i<FALCON_MAX_PLANS;i++)
   {
      if(!g_state.plans[i].active) continue;
      int st=g_state.plans[i].state;
      if(st==PLAN_EXECUTED || st==PLAN_EXPIRED || st==PLAN_CANCELLED) continue;
      if(g_barCounter - g_state.plans[i].createdBar > g_cfg.planExpiryBars){ g_state.plans[i].state=PLAN_EXPIRED; continue; }
      if(g_state.plans[i].type==PT_CONTINUATION && dir!=DIR_NONE && dir!=g_state.plans[i].dir)
         g_state.plans[i].state=PLAN_CANCELLED;
   }

   // 2) CONTINUATION — trade WITH the owner toward its destination
   if(dir!=DIR_NONE) Plan_Ensure(PT_CONTINUATION, dir, price, atr, ot, "owner continuation");

   // 3) RETURN — countertrend return into the higher-TF destination when the
   //    owner leg is MATURE (price extended -> expect a return to the FRZ)
   if(dir!=DIR_NONE && g_state.wave.completion>=70.0 && g_state.frz.active && g_state.frz.targetPrice>0.0)
      Plan_Ensure(PT_RETURN, -dir, price, atr, ot, "countertrend return");
   else
      Plan_CancelType(PT_RETURN);

   // 4) REVERSAL — ownership transfer: curve says transfer likely + an opposing
   //    change-of-character has printed (a new owner is taking control)
   int choch=g_state.structure.choch;
   if(g_state.curve.transferLikely && choch!=DIR_NONE && choch!=dir)
      Plan_Ensure(PT_REVERSAL, choch, price, atr, ot, "ownership reversal");
   else
      Plan_CancelType(PT_REVERSAL);

   // 3) count live plans
   int c=0;
   for(int i=0;i<FALCON_MAX_PLANS;i++)
      if(g_state.plans[i].active &&
         g_state.plans[i].state!=PLAN_EXECUTED && g_state.plans[i].state!=PLAN_EXPIRED && g_state.plans[i].state!=PLAN_CANCELLED) c++;
   g_state.planCount=c;
}

//==================================================================
// EXECUTE — the Decision step: pick the highest-priority TRIGGERED plan
// and fire it with the plan's OWNER-DESTINATION target. Honors the same
// portfolio guards as the Symphony path (session / risk / cooldown /
// max-positions / no-hedge / one-per-direction / one-per-owner-curve).
//==================================================================
void PlannerExecute()
{
   if(!g_cfg.usePlanner || !g_cfg.enableTrading) return;
   double atr=g_state.physics.atr; if(atr<=0.0) atr=FalconATR(1); if(atr<=0.0) return;
   double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   double riskCash=equity*g_cfg.riskPercent*0.01;

   // portfolio gating
   if(!EE_IsTradeTime()) return;
   if(g_cfg.blockIfBreach && !ee_lastRiskOk) return;
   if(ee_riskCooldown>0) return;
   // cooldown: dual mode uses the PLANNER's own last entry; legacy uses any entry.
   {
      int lastBar = g_cfg.dualSourceFire ? pln_lastEntryBar : MathMax(sym_lastEntryBar,pln_lastEntryBar);
      if(g_cfg.reentryCooldown>0 && (g_barCounter - lastBar) < g_cfg.reentryCooldown) return;
   }

   int openL=g_state.exec.openLongCount, openS=g_state.exec.openShortCount;
   if(g_cfg.maxOpenPositions>0 && (openL+openS)>=g_cfg.maxOpenPositions) return;

   // select highest-priority TRIGGERED plan
   int best=-1, bestPr=-1;
   for(int i=0;i<FALCON_MAX_PLANS;i++)
   {
      if(!g_state.plans[i].active || g_state.plans[i].state!=PLAN_TRIGGERED) continue;
      if(g_state.plans[i].priority>bestPr){ bestPr=g_state.plans[i].priority; best=i; }
   }
   if(best<0) return;

   FalconPlan p=g_state.plans[best];
   int dir=p.dir;

   // noHedge stays portfolio-wide (never hold opposite directions).
   if(g_cfg.noHedge)       { if(dir==DIR_LONG && openS>0) return; if(dir==DIR_SHORT && openL>0) return; }
   // one-per-dir: dual mode scopes to the PLANNER's own positions; legacy is portfolio-wide.
   if(g_cfg.oneEntryPerDir)
   {
      int dL = g_cfg.dualSourceFire ? g_state.exec.openLongPlan  : openL;
      int dS = g_cfg.dualSourceFire ? g_state.exec.openShortPlan : openS;
      if(dir==DIR_LONG && dL>0) return; if(dir==DIR_SHORT && dS>0) return;
   }
   if(g_cfg.oneEntryPerCurve)
   {
      int oid=g_state.curve.ownerNodeId;
      if(oid>0)
      {
         int ownL = g_cfg.dualSourceFire ? pln_ownerEntryLong  : sym_ownerEntryLong;
         int ownS = g_cfg.dualSourceFire ? pln_ownerEntryShort : sym_ownerEntryShort;
         if(dir==DIR_LONG  && (oid==ownL || (!g_cfg.dualSourceFire && oid==pln_ownerEntryLong)))  return;
         if(dir==DIR_SHORT && (oid==ownS || (!g_cfg.dualSourceFire && oid==pln_ownerEntryShort))) return;
      }
   }

   // FIRE — structural stop (computed in Sym_PlaceEntry) + the plan's
   // owner-destination target (T2). All exit infra (band model, owner
   // scoping, cooldown arm) is reused via Sym_PlaceEntry.
   Sym_PlaceEntry(dir, "PLAN "+FalconPlanTypeStr(p.type), riskCash, atr, true, p.t2);
   p.state=PLAN_EXECUTED;
   g_state.plans[best]=p;
   FalconPublish(EVT_ORDER_SENT, dir, "plan executed");
}

#endif // FALCON_PLANNER_MQH
//+------------------------------------------------------------------+