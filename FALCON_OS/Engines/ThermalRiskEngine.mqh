//+------------------------------------------------------------------+
//|  FALCON OS — Execution Layer : ThermalRiskEngine.mqh            |
//|  PYRO — Campaign Thermodynamics Risk Engine                     |
//|                                                                  |
//|  A risk model built specifically for how THIS algo trades:       |
//|  precision Phase 3/4 entries that STACK into a directional       |
//|  campaign (a fleet of correlated positions on one instrument).   |
//|                                                                  |
//|  The fleet is treated as a physical body that carries HEAT.      |
//|                                                                  |
//|    heat = adverseExcursion(blended basket, in ATR)               |
//|           x fragility(stackCount, totalLots)                     |
//|                                                                  |
//|  A WINNING basket runs near-zero heat regardless of size (house  |
//|  money). An UNDERWATER, heavily-stacked basket overheats fast.   |
//|  Heat is the single scalar that governs everything:              |
//|                                                                  |
//|    OPEN      cool        -> full-size stacks allowed             |
//|    THROTTLED warming     -> each new stack shrinks with heat     |
//|    FROZEN    hot/maxed    -> no new stacks (incl. anti-martingale |
//|                             freeze: no averaging-down past N)     |
//|    DE-RISK   critical     -> flatten the campaign (catastrophe)   |
//|                                                                  |
//|  Plus a basket-organism manager (breakeven-lock the whole fleet  |
//|  once it is BasketLockATR in profit) and a dual-campaign          |
//|  THERMOSTAT: long-heat and short-heat are tracked separately     |
//|  (never netted), and if BOTH overheat at once (whipsaw trap) all  |
//|  admissions freeze. Account heat = equity drawdown vs peak.       |
//|                                                                  |
//|  KEY DIFFERENCE vs the old DRDWCT engine: PYRO NEVER trims a      |
//|  winning campaign. Heat is ~0 while in profit, so the only forced |
//|  close is a TRUE runaway (deeply underwater + large) at critical  |
//|  heat — exactly when a stacking book must be cut.                 |
//|                                                                  |
//|  Included AFTER ExecutionEngine (reuses EE_CollectPositions /     |
//|  EE_ModifySL / EE_CloseFull) and BEFORE SymphonyEngine (which     |
//|  calls TR_AdmitLots before every entry).                         |
//+------------------------------------------------------------------+
#ifndef FALCON_THERMAL_RISK_ENGINE_MQH
#define FALCON_THERMAL_RISK_ENGINE_MQH

#include "../Kernel/FalconState.mqh"
#include "../Kernel/FalconConfig.mqh"
#include "../Kernel/FalconSeries.mqh"
#include "../Kernel/FalconEventBus.mqh"
#include "../Kernel/FalconLog.mqh"

//==================================================================
// MODULE STATE — cross-bar memory for velocity / cooling / lock
//==================================================================
double tr_prevHeat[2]   = {0.0,0.0};
double tr_prevPnL[2]    = {0.0,0.0};
double tr_equityPeak    = 0.0;

void ThermalRiskInit()
{
   tr_prevHeat[0]=0.0; tr_prevHeat[1]=0.0;
   tr_prevPnL[0]=0.0;  tr_prevPnL[1]=0.0;
   tr_equityPeak = AccountInfoDouble(ACCOUNT_EQUITY);
}

//==================================================================
// 1) BUILD CAMPAIGN — aggregate the directional fleet into a basket.
//==================================================================
void TR_BuildCampaign(const int dir,FalconThermalCampaign &c)
{
   EE_Position pos[64];
   int n = EE_CollectPositions(pos, dir);

   double atr = MathMax(g_state.physics.atr, 1e-10);
   double lots=0.0, wEntrySum=0.0, pnl=0.0, swap=0.0;
   for(int i=0;i<n;i++)
   {
      lots      += pos[i].lots;
      wEntrySum += pos[i].entry*pos[i].lots;
      pnl       += pos[i].pnl;          // profit + swap (commission excluded — MT5 per-deal)
   }

   c.dir         = dir;
   c.stackCount  = n;
   c.totalLots   = lots;
   c.blendedEntry= (lots>0.0 ? wEntrySum/lots : 0.0);
   c.breakeven   = c.blendedEntry;       // swap drift folded into PnL valuation
   c.unrealizedPnL = pnl;

   // valuation price = the side we would CLOSE at
   double px = (dir==DIR_LONG ? SymbolInfoDouble(_Symbol,SYMBOL_BID)
                              : SymbolInfoDouble(_Symbol,SYMBOL_ASK));
   double excursion = 0.0;
   if(c.blendedEntry>0.0)
      excursion = (dir==DIR_LONG ? (px - c.blendedEntry) : (c.blendedEntry - px)) / atr;
   c.favorableATR = MathMax(0.0,  excursion);   // in profit
   c.adverseATR   = MathMax(0.0, -excursion);   // underwater

   c.exposureLoad = (g_cfg.maxCampaignLots>0.0 ? c.totalLots/g_cfg.maxCampaignLots : 0.0);
   c.stackLoad    = (g_cfg.maxStacks>0        ? (double)c.stackCount/(double)g_cfg.maxStacks : 0.0);
}

//==================================================================
// 2) HEAT — the master scalar. Adverse excursion amplified by the
//    basket's fragility. In profit, heat collapses to a small
//    exposure baseline (so a big WINNER is not treated as risky).
//==================================================================
void TR_ComputeHeat(const int idx,FalconThermalCampaign &c)
{
   double adverseLoad = (g_cfg.heatAdverseSpan>0.0 ? c.adverseATR/g_cfg.heatAdverseSpan : 0.0);
   c.fragility = 1.0 + 0.5*MathMin(c.exposureLoad,2.0) + 0.5*MathMin(c.stackLoad,2.0);

   double heat = FalconClamp(adverseLoad*c.fragility, 0.0, 2.0);
   // even a profitable book carries a soft exposure baseline (throttles further
   // stacking once it is large) — but never enough to force a de-risk.
   double baseHeat = 0.40*MathMax(c.exposureLoad, c.stackLoad);
   heat = MathMax(heat, MathMin(baseHeat, g_cfg.heatFreeze*0.9));
   if(c.stackCount==0) heat=0.0;

   c.heat         = heat;
   c.heatVelocity = heat - tr_prevHeat[idx];
   c.coolingRate  = c.unrealizedPnL - tr_prevPnL[idx];
   tr_prevHeat[idx]= heat;
   tr_prevPnL[idx] = c.unrealizedPnL;
}

//==================================================================
// 3) ADMISSION — may this campaign accept a new stack, and how big?
//    (continuous lot scale 0..1). Anti-martingale freeze on adding
//    into a deepening underwater basket past MaxAvgDownStacks.
//==================================================================
void TR_Admission(FalconThermalCampaign &c,const FalconThermostat &th)
{
   int    adm   = ADM_OPEN;
   double scale = 1.0;

   if(c.heat >= g_cfg.heatCritical)      { adm=ADM_DERISK;    scale=0.0; }
   else if(c.heat >= g_cfg.heatFreeze)   { adm=ADM_FROZEN;    scale=0.0; }
   else if(c.heat >= g_cfg.heatThrottle)
   {
      adm=ADM_THROTTLED;
      double span=MathMax(g_cfg.heatFreeze-g_cfg.heatThrottle,1e-6);
      scale=FalconClamp((g_cfg.heatFreeze-c.heat)/span,0.0,1.0);   // 1 -> 0 across the band
   }

   // ANTI-MARTINGALE: never deepen an underwater basket past the limit.
   if(c.adverseATR>0.10 && c.stackCount>=g_cfg.maxAvgDownStacks)
   { scale=0.0; if(adm<ADM_FROZEN) adm=ADM_FROZEN; }

   // hard ceilings
   if(c.stackCount>=g_cfg.maxStacks)          { scale=0.0; if(adm<ADM_FROZEN) adm=ADM_FROZEN; }
   if(c.totalLots >=g_cfg.maxCampaignLots)    { scale=0.0; if(adm<ADM_FROZEN) adm=ADM_FROZEN; }

   // PORTFOLIO THERMOSTAT: whipsaw lock or account-heat freeze all admissions.
   if(th.whipsawLock || th.accountHeat>=1.0)  { scale=0.0; if(adm<ADM_FROZEN) adm=ADM_FROZEN; }

   c.admission     = adm;
   c.admitLotScale = FalconClamp(scale,0.0,1.0);
}

//==================================================================
// 4) BASKET MANAGER — the ONLY forced close: a CRITICAL-heat catastrophe
//    flatten (deeply underwater + large). Winners are never trimmed.
//    Breakeven + trailing are owned by the TALON grip (Symphony layer).
//==================================================================
void TR_ManageBasket(const int idx,FalconThermalCampaign &c)
{
   int dir = c.dir;
   c.breakevenLocked = false;
   if(c.stackCount==0) return;

   // --- CATASTROPHE STOP: thermal runaway -> flatten this campaign ---
   if(c.admission==ADM_DERISK)
   {
      int total=PositionsTotal();
      for(int i=total-1;i>=0;i--)
      {
         ulong ticket=PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
         if(PositionGetInteger(POSITION_MAGIC)!=g_cfg.magic) continue;
         long type=PositionGetInteger(POSITION_TYPE);
         int  pdir=(type==POSITION_TYPE_BUY?DIR_LONG:DIR_SHORT);
         if(pdir==dir) EE_CloseFull(ticket);
      }
      FalconPublish(EVT_RISK_BREACH, c.heat, "PYRO thermal runaway flatten");
      g_state.exec.exitState=XS_DD_FLATTEN;
   }
}

//==================================================================
// MASTER — Thermal Risk pipeline step. Build both campaigns, compute
// the portfolio thermostat, set admissions, then manage the baskets.
//==================================================================
void ThermalRiskUpdate()
{
   FalconRisk r;

   // 1) build + heat for each direction
   TR_BuildCampaign(DIR_LONG,  r.campaign[0]);
   TR_BuildCampaign(DIR_SHORT, r.campaign[1]);
   TR_ComputeHeat(0, r.campaign[0]);
   TR_ComputeHeat(1, r.campaign[1]);

   // 2) PORTFOLIO THERMOSTAT (never nets opposite directions)
   FalconThermostat th;
   th.longHeat    = r.campaign[0].heat;
   th.shortHeat   = r.campaign[1].heat;
   th.combinedHeat= th.longHeat + th.shortHeat;
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq>tr_equityPeak) tr_equityPeak=eq;
   double ddPct=(tr_equityPeak>0.0 ? (tr_equityPeak-eq)/tr_equityPeak*100.0 : 0.0);
   th.equityPeak  = tr_equityPeak;
   th.accountHeat = FalconClamp(ddPct/MathMax(g_cfg.acctHeatDDPct,1e-6),0.0,1.0);
   // whipsaw trap: BOTH books warm at the same time
   th.whipsawLock = (th.longHeat>=g_cfg.heatThrottle && th.shortHeat>=g_cfg.heatThrottle);
   r.thermostat   = th;

   // 3) admission for each campaign (consults the thermostat)
   TR_Admission(r.campaign[0], th);
   TR_Admission(r.campaign[1], th);

   // commit shared state BEFORE managing (admissions drive the basket manager)
   g_state.risk = r;

   // 4) catastrophe-only basket management (TALON owns breakeven + trailing)
   TR_ManageBasket(0, g_state.risk.campaign[0]);
   TR_ManageBasket(1, g_state.risk.campaign[1]);
}

//==================================================================
// PUBLIC GATE — Symphony calls this before EVERY entry. Returns the
// admitted lot size (0 = entry denied). Scales the proposed size by
// the campaign's thermal admission and caps it to the remaining
// per-campaign lot budget.
//==================================================================
double TR_AdmitLots(const int dir,const double proposedLots)
{
   if(!g_cfg.useThermalRisk) return(proposedLots);
   if(proposedLots<=0.0)     return(0.0);

   int idx = (dir==DIR_LONG ? 0 : 1);
   FalconThermalCampaign c = g_state.risk.campaign[idx];

   if(c.admission==ADM_FROZEN || c.admission==ADM_DERISK) return(0.0);
   if(c.stackCount>=g_cfg.maxStacks)                      return(0.0);

   double scaled = proposedLots*c.admitLotScale;
   double remaining = g_cfg.maxCampaignLots - c.totalLots;
   if(remaining<=0.0) return(0.0);
   if(scaled>remaining) scaled=remaining;

   // normalise to broker volume step
   double lotStep=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double minLot =SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   if(lotStep<=0) lotStep=0.01;
   if(minLot<=0)  minLot=0.01;
   scaled = MathFloor(scaled/lotStep)*lotStep;
   if(scaled<minLot)
   {
      // only allow the floor lot if the campaign is OPEN/THROTTLED and has room
      if(c.admission==ADM_OPEN && remaining>=minLot) scaled=minLot;
      else return(0.0);
   }
   if(g_cfg.maxLots>0 && scaled>g_cfg.maxLots) scaled=g_cfg.maxLots;
   int volDigits=(lotStep>=1.0?0:lotStep>=0.1?1:2);
   return(NormalizeDouble(scaled,volDigits));
}

#endif // FALCON_THERMAL_RISK_ENGINE_MQH
//+------------------------------------------------------------------+
