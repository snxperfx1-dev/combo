//+------------------------------------------------------------------+
//|  FALCON OS — Decision/Execution : TradePlan.mqh                 |
//|                                                                  |
//|  SUBSYSTEMS DO THEIR JOBS. A trade is not a yes/no vote — it is a |
//|  PLAN, and each subsystem fills in the ONE field it owns:        |
//|                                                                  |
//|    DIRECTION   <- Ownership (Curve / Campaign)  — who owns price  |
//|    ENTRY ZONE  <- Liquidity / Order Block / Supply-Demand / FU    |
//|    STOP        <- the INVALIDATION level of that zone (where the  |
//|                   idea is wrong) — NOT a fixed anchor ± ATR        |
//|    TARGET      <- Convexity destination / FRZ owner-destination / |
//|                   Network next node — owner-driven & ESCALATING   |
//|                   with the owning timeframe                       |
//|    SIZE        <- Participant conviction × Campaign control        |
//|    R:R         <- computed from the subsystem stop + target        |
//|                                                                  |
//|  The composer READS each engine's concrete output and assembles  |
//|  the plan. Symphony then EXECUTES the plan (timing/trigger only). |
//|  Include AFTER the engines that write state, BEFORE SymphonyEngine|
//+------------------------------------------------------------------+
#ifndef FALCON_TRADE_PLAN_MQH
#define FALCON_TRADE_PLAN_MQH

#include "../Kernel/FalconState.mqh"
#include "../Kernel/FalconConfig.mqh"
#include "../Kernel/FalconSeries.mqh"

//==================================================================
// THE PLAN — one composed object; each field is owned by a subsystem.
//==================================================================
struct FalconTradePlan
{
   int    dir;            // DIRECTION  — from ownership
   bool   valid;
   double entry;
   double stop;           // STOP       — zone invalidation (liquidity/structure)
   double target;         // TARGET     — owner destination (convexity/FRZ/network)
   double target2;        // runner target (next waypoint)
   int    targetTF;       // owning timeframe of the destination (escalation)
   double rr;             // reward:risk from the composed stop+target
   double convictionMult; // SIZE scale — participants × campaign control
   string stopSrc;        // which subsystem set the stop
   string targetSrc;      // which subsystem set the target
};

FalconTradePlan g_plan;

//------------------------------------------------------------------
// STOP — the invalidation of the zone price is reacting from.
//   LONG: the relevant zone's BOTTOM (demand/OB/flip/inducement/swing/
//   wave origin), minus a buffer. We choose the CLOSEST level below
//   entry that still gives at least a minimum stop distance, so the
//   stop is precise (tight to structure) without being noise-tight.
//------------------------------------------------------------------
double TP_StopLong(const double entry,const double atr,string &src)
{
   double buf  = atr*g_cfg.stopBufATR;
   double minD = MathMax(atr*0.6, buf*2.0);

   // candidate invalidation levels (price, label), each is a zone BOTTOM
   double cand[6]; string lbl[6]; int n=0;
   if(g_state.supplyDemand.inDemand && g_state.supplyDemand.demandBot>0){ cand[n]=g_state.supplyDemand.demandBot; lbl[n]="demand"; n++; }
   if(g_state.orderBlocks.activeDir==DIR_LONG && g_state.orderBlocks.activeBot>0){ cand[n]=g_state.orderBlocks.activeBot; lbl[n]="orderblock"; n++; }
   if(g_state.wave.flipBot>0){ cand[n]=g_state.wave.flipBot; lbl[n]="flip"; n++; }
   if(g_state.liquidity.induceBot>0){ cand[n]=g_state.liquidity.induceBot; lbl[n]="inducement"; n++; }
   if(g_state.structure.swingLow>0){ cand[n]=g_state.structure.swingLow; lbl[n]="swingLow"; n++; }
   if(g_state.wave.origin>0){ cand[n]=g_state.wave.origin; lbl[n]="origin"; n++; }

   // choose the HIGHEST candidate that is below entry by >= minD (tightest precise stop)
   double best=0.0; src="";
   for(int i=0;i<n;i++)
   {
      double lvl=cand[i];
      if(lvl < entry-minD)            // valid invalidation with room
         if(lvl>best){ best=lvl; src=lbl[i]; }
   }
   if(best<=0.0)
   {
      // fallback: deepest available zone bottom, else fixed structural stop
      for(int i=0;i<n;i++) if(cand[i]>0 && cand[i]<entry && (best==0.0||cand[i]<best)){ best=cand[i]; src=lbl[i]; }
      if(best<=0.0){ src="atr"; return(entry - 1.5*atr - buf); }
   }
   return(best - buf);
}

double TP_StopShort(const double entry,const double atr,string &src)
{
   double buf  = atr*g_cfg.stopBufATR;
   double minD = MathMax(atr*0.6, buf*2.0);

   double cand[6]; string lbl[6]; int n=0;
   if(g_state.supplyDemand.inSupply && g_state.supplyDemand.supplyTop>0){ cand[n]=g_state.supplyDemand.supplyTop; lbl[n]="supply"; n++; }
   if(g_state.orderBlocks.activeDir==DIR_SHORT && g_state.orderBlocks.activeTop>0){ cand[n]=g_state.orderBlocks.activeTop; lbl[n]="orderblock"; n++; }
   if(g_state.wave.flipTop>0){ cand[n]=g_state.wave.flipTop; lbl[n]="flip"; n++; }
   if(g_state.liquidity.induceTop>0){ cand[n]=g_state.liquidity.induceTop; lbl[n]="inducement"; n++; }
   if(g_state.structure.swingHigh>0){ cand[n]=g_state.structure.swingHigh; lbl[n]="swingHigh"; n++; }
   if(g_state.wave.origin>0){ cand[n]=g_state.wave.origin; lbl[n]="origin"; n++; }

   // choose the LOWEST candidate that is above entry by >= minD
   double best=0.0; src="";
   for(int i=0;i<n;i++)
   {
      double lvl=cand[i];
      if(lvl > entry+minD)
         if(best==0.0 || lvl<best){ best=lvl; src=lbl[i]; }
   }
   if(best<=0.0)
   {
      for(int i=0;i<n;i++) if(cand[i]>0 && cand[i]>entry && cand[i]>best){ best=cand[i]; src=lbl[i]; }
      if(best<=0.0){ src="atr"; return(entry + 1.5*atr + buf); }
   }
   return(best + buf);
}

//------------------------------------------------------------------
// TARGET — owner-driven destination, ESCALATING with the owning TF.
//   Priority: FRZ owner-destination > convexity ARC > network next
//   authoritative node > wave objective > 2R fallback. Each is owned
//   by a different engine doing its job.
//------------------------------------------------------------------
double TP_TargetLong(const double entry,const double stop,int &tf,string &src,double &t2)
{
   double t=0.0; tf=g_state.curve.ownerTF; src=""; t2=0.0;
   if(g_state.frz.active && g_state.frz.targetPrice>entry)
   { t=g_state.frz.targetPrice; tf=g_state.frz.ownerTF; src="FRZ"; }
   else if(g_state.convexity.arcLong>entry)            { t=g_state.convexity.arcLong; src="convexity"; }
   else if(g_state.network.nextNodePrice>entry)        { t=g_state.network.nextNodePrice; src="network"; }
   else if(g_state.wave.objective>entry)               { t=g_state.wave.objective; src="wave"; }
   else                                                { t=entry+(entry-stop)*2.0; src="2R"; }

   // runner waypoint = the next distinct destination beyond t
   if(g_state.network.nextNodePrice>t)  t2=g_state.network.nextNodePrice;
   else if(g_state.wave.objective>t)    t2=g_state.wave.objective;
   else                                 t2=t+(t-entry)*0.6;
   return(t);
}

double TP_TargetShort(const double entry,const double stop,int &tf,string &src,double &t2)
{
   double t=0.0; tf=g_state.curve.ownerTF; src=""; t2=0.0;
   if(g_state.frz.active && g_state.frz.targetPrice>0 && g_state.frz.targetPrice<entry)
   { t=g_state.frz.targetPrice; tf=g_state.frz.ownerTF; src="FRZ"; }
   else if(g_state.convexity.arcShort>0 && g_state.convexity.arcShort<entry)   { t=g_state.convexity.arcShort; src="convexity"; }
   else if(g_state.network.nextNodePrice>0 && g_state.network.nextNodePrice<entry){ t=g_state.network.nextNodePrice; src="network"; }
   else if(g_state.wave.objective>0 && g_state.wave.objective<entry)           { t=g_state.wave.objective; src="wave"; }
   else                                                                        { t=entry-(stop-entry)*2.0; src="2R"; }

   if(g_state.network.nextNodePrice>0 && g_state.network.nextNodePrice<t)  t2=g_state.network.nextNodePrice;
   else if(g_state.wave.objective>0 && g_state.wave.objective<t)           t2=g_state.wave.objective;
   else                                                                    t2=t-(entry-t)*0.6;
   return(t);
}

//------------------------------------------------------------------
// SIZE conviction — Participant balance × Campaign control.
//   own-side participation strong + high campaign control => up to 1.5x;
//   weak / contested => down to 0.5x. The participant + campaign engines
//   doing their job (sizing), not gating.
//------------------------------------------------------------------
double TP_Conviction(const int dir)
{
   double own = (dir==DIR_LONG ? g_state.participants.buyer  : g_state.participants.seller);
   double opp = (dir==DIR_LONG ? g_state.participants.seller : g_state.participants.buyer);
   double ctrl= FalconClamp(g_state.campaign.controlScore,0,100);
   double partMult = FalconClamp(1.0 + 0.5*((own-opp)/100.0), 0.5, 1.5);
   double ctrlMult = FalconClamp(0.6 + 0.4*ctrl/100.0, 0.6, 1.0);
   return(FalconClamp(partMult*ctrlMult, 0.4, 1.5));
}

//==================================================================
// COMPOSE — assemble the full plan from the subsystems for `dir`.
//==================================================================
FalconTradePlan ComposeTradePlan(const int dir,const double entry,const double atr)
{
   FalconTradePlan p; p.valid=false; p.dir=dir; p.entry=entry;
   p.stop=0; p.target=0; p.target2=0; p.targetTF=0; p.rr=0; p.convictionMult=1.0;
   p.stopSrc=""; p.targetSrc="";
   if(atr<=0.0) return(p);

   if(dir==DIR_LONG)
   {
      p.stop   = TP_StopLong(entry,atr,p.stopSrc);
      p.target = TP_TargetLong(entry,p.stop,p.targetTF,p.targetSrc,p.target2);
      if(p.stop>0 && p.stop<entry && p.target>entry)
         p.rr = (p.target-entry)/(entry-p.stop);
   }
   else if(dir==DIR_SHORT)
   {
      p.stop   = TP_StopShort(entry,atr,p.stopSrc);
      p.target = TP_TargetShort(entry,p.stop,p.targetTF,p.targetSrc,p.target2);
      if(p.stop>entry && p.target>0 && p.target<entry)
         p.rr = (entry-p.target)/(p.stop-entry);
   }
   p.convictionMult = TP_Conviction(dir);
   p.valid = (p.stop>0.0 && p.target>0.0 && p.rr>0.0);
   g_plan = p;
   return(p);
}

#endif // FALCON_TRADE_PLAN_MQH
//+------------------------------------------------------------------+
