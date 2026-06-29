//+------------------------------------------------------------------+
//|  FALCON OS — Execution Layer : MoneyManager.mqh                 |
//|  Source: SYMPHONY v3.0 (the profitable standalone)               |
//|                                                                  |
//|  The three money-management mechanisms that made the standalone  |
//|  Symphony profitable — ported verbatim in behaviour, adapted to  |
//|  FALCON's shared config + EE order helpers:                      |
//|                                                                  |
//|   1. COUNTER-DIRECTION PROFITABILITY LOCK                        |
//|        Never open longs while the short book is net profitable,  |
//|        and vice-versa. A counter-trend bounce inside a running   |
//|        profitable campaign is noise, not a new campaign. This is |
//|        the single biggest reason v3.0 doesn't chop.              |
//|                                                                  |
//|   2. PRE-ENTRY BASKET RISK CEILING                               |
//|        Size lots DOWN at entry so per-direction dollar-risk-at-SL |
//|        stays under InpMaxBasketRiskPct of equity. Deterministic, |
//|        correct at entry — no trim-after-entry. Lets the book     |
//|        pyramid into a trend while total risk stays bounded.      |
//|                                                                  |
//|   3. LIVE-PnL PROFIT LADDER                                      |
//|        Banks on the realised reward:risk RATIO of the live book  |
//|        (not on phase geometry): R1 @0.7x -> bank+breakeven,      |
//|        R2 @1.5x -> bank+trail 50%, R3 @2.5x -> bank+trail runner. |
//|        Anchored to broker positions; survives phase resets.      |
//|                                                                  |
//|  Reuses EE_ClosePartial / EE_ModifySL. Include AFTER             |
//|  ExecutionEngine, BEFORE SymphonyEngine (which calls these).     |
//+------------------------------------------------------------------+
#ifndef FALCON_MONEY_MANAGER_MQH
#define FALCON_MONEY_MANAGER_MQH

#include "../Kernel/FalconState.mqh"
#include "../Kernel/FalconConfig.mqh"
#include "../Kernel/FalconSeries.mqh"
#include "../Kernel/FalconLog.mqh"

//==================================================================
// LADDER STATE — keyed to the LIVE position book (per direction).
// Rungs reset only when a direction's position count reaches zero
// (campaign fully closed), so they survive phase-engine resets.
//==================================================================
int  mm_longRungs        = 0;
int  mm_shortRungs       = 0;
bool mm_longBEActive     = false;
bool mm_shortBEActive    = false;
bool mm_longTrailActive  = false;
bool mm_shortTrailActive = false;

struct MMPos { ulong ticket; datetime openTime; double lots; };

void MoneyManagerInit()
{
   mm_longRungs=0; mm_shortRungs=0;
   mm_longBEActive=false; mm_shortBEActive=false;
   mm_longTrailActive=false; mm_shortTrailActive=false;
}

//==================================================================
// EXPOSURE / RISK HELPERS
//==================================================================
// Total dollar-risk-at-SL for all open positions in one direction:
//   sum( lots * |entry-sl| * contractValue ).  No VaR, no netting.
double MM_BasketDollarRisk(const int direction)
{
   double totalRisk=0.0;
   double atrFB=FalconATR(1); if(atrFB<=0.0) atrFB=10.0;
   int total=PositionsTotal();
   for(int i=0;i<total;i++)
   {
      ulong ticket=PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol)  continue;
      if(PositionGetInteger(POSITION_MAGIC)!=g_cfg.magic) continue;
      int dir=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?1:-1;
      if(dir!=direction) continue;
      double lots =PositionGetDouble(POSITION_VOLUME);
      double entry=PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   =PositionGetDouble(POSITION_SL);
      double distSL=(sl>0.0)?MathAbs(entry-sl):(2.0*atrFB);
      totalRisk += lots*distSL*g_cfg.contractValue;
   }
   return(totalRisk);
}

// Floating PnL (profit+swap only; MT5 deprecated POSITION_COMMISSION) for a dir.
double MM_DirectionFloatingPnL(const int direction)
{
   double total=0.0;
   int cnt=PositionsTotal();
   for(int i=0;i<cnt;i++)
   {
      ulong ticket=PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol)  continue;
      if(PositionGetInteger(POSITION_MAGIC)!=g_cfg.magic) continue;
      int dir=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?1:-1;
      if(dir!=direction) continue;
      total += PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
   }
   return(total);
}

// COUNTER-DIRECTION LOCK: block a new entry in `dir` while the OPPOSITE
// book is net profitable. (The heart of v3.0's no-chop behaviour.)
bool MM_CounterDirBlocked(const int dir)
{
   if(!g_cfg.counterDirBlock) return(false);
   int opp=-dir;
   return(MM_DirectionFloatingPnL(opp) > 0.0);
}

// PRE-ENTRY BASKET CEILING: scale computedLots down so adding this entry
// keeps the direction's basket dollar-risk under InpMaxBasketRiskPct of
// equity. Returns 0 if even one min-lot would breach. No trim-after-entry.
double MM_AdjustLotsForBasketCeiling(const int direction,const double entry,
                                     const double sl,const double computedLots)
{
   if(computedLots<=0.0) return(0.0);
   if(g_cfg.maxBasketRiskPct<=0.0) return(computedLots);   // ceiling disabled

   double equity        = AccountInfoDouble(ACCOUNT_EQUITY);
   double maxBasketRisk = equity*g_cfg.maxBasketRiskPct/100.0;
   double currentRisk   = MM_BasketDollarRisk(direction);
   double available     = maxBasketRisk-currentRisk;
   if(available<=0.0) return(0.0);                          // ceiling reached

   double distSL=MathAbs(entry-sl);
   if(distSL<=0.0) return(0.0);

   if(computedLots*distSL*g_cfg.contractValue <= available)
      return(computedLots);                                 // fits as-is

   double maxLots = available/(distSL*g_cfg.contractValue);
   double minLot  = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double lotStep = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(lotStep<=0) lotStep=0.01; if(minLot<=0) minLot=0.01;
   maxLots=MathFloor(maxLots/lotStep)*lotStep;
   if(maxLots<minLot) return(0.0);
   return(NormalizeDouble(maxLots,2));
}

//==================================================================
// STOP PROTECTION (after ladder rungs)
//==================================================================
// Move all remaining stops in a direction to at least breakeven (entry).
void MM_MoveStopsToBreakeven(const int direction)
{
   int cnt=PositionsTotal();
   for(int i=0;i<cnt;i++)
   {
      ulong ticket=PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol)  continue;
      if(PositionGetInteger(POSITION_MAGIC)!=g_cfg.magic) continue;
      int dir=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?1:-1;
      if(dir!=direction) continue;
      double entry=PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   =PositionGetDouble(POSITION_SL);
      bool   move=false;
      if(direction>0 && (sl==0.0 || sl<entry)) move=true;
      if(direction<0 && (sl==0.0 || sl>entry)) move=true;
      if(move) EE_ModifySL(ticket,entry);
   }
}

// Trail stops to lock InpTrailLockPct of the move from entry (after R2).
void MM_TrailStops(const int direction)
{
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   int cnt=PositionsTotal();
   for(int i=0;i<cnt;i++)
   {
      ulong ticket=PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol)  continue;
      if(PositionGetInteger(POSITION_MAGIC)!=g_cfg.magic) continue;
      int dir=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?1:-1;
      if(dir!=direction) continue;
      double entry=PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   =PositionGetDouble(POSITION_SL);
      if(direction>0)
      {
         double locked=entry+(bid-entry)*g_cfg.trailLockPct/100.0;
         if(locked>sl && locked>entry) EE_ModifySL(ticket,locked);
      }
      else
      {
         double locked=entry-(entry-ask)*g_cfg.trailLockPct/100.0;
         if((sl==0.0 || locked<sl) && locked<entry) EE_ModifySL(ticket,locked);
      }
   }
}

void MM_RunStopProtection()
{
   if(mm_longBEActive  && !mm_longTrailActive)  MM_MoveStopsToBreakeven(1);
   if(mm_shortBEActive && !mm_shortTrailActive) MM_MoveStopsToBreakeven(-1);
   if(mm_longTrailActive)  MM_TrailStops(1);
   if(mm_shortTrailActive) MM_TrailStops(-1);
}

//==================================================================
// PROFIT LADDER
//==================================================================
// Close `fractionPerPos` of EVERY open position in a direction (proportional),
// so every leg banks at each rung — not just the oldest.
void MM_CloseProportionalAll(const int direction,const double fractionPerPos,const string tag)
{
   if(fractionPerPos<=0.0) return;
   double minLot =SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double lotStep=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(lotStep<=0) lotStep=0.01; if(minLot<=0) minLot=0.01;
   int total=PositionsTotal();
   for(int i=0;i<total;i++)
   {
      ulong ticket=PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol)  continue;
      if(PositionGetInteger(POSITION_MAGIC)!=g_cfg.magic) continue;
      int dir=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?1:-1;
      if(dir!=direction) continue;
      double lots=PositionGetDouble(POSITION_VOLUME);
      double closeThis=MathFloor((lots*fractionPerPos)/lotStep)*lotStep;
      if(closeThis<minLot) continue;
      EE_ClosePartial(ticket,closeThis);
   }
}

// One direction's ladder: read live book, compute realised reward:risk ratio,
// fire at most one rung per bar. Reset when the direction is flat.
void MM_RunLadderDirection(const int direction,int &rungs)
{
   double totalLots=0.0,totalRisk=0.0,totalPnL=0.0;
   int    posCount=0;
   double atrFB=FalconATR(1); if(atrFB<=0.0) atrFB=10.0;

   int total=PositionsTotal();
   for(int i=0;i<total;i++)
   {
      ulong ticket=PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol)  continue;
      if(PositionGetInteger(POSITION_MAGIC)!=g_cfg.magic) continue;
      int dir=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?1:-1;
      if(dir!=direction) continue;
      double lots =PositionGetDouble(POSITION_VOLUME);
      double entry=PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   =PositionGetDouble(POSITION_SL);
      double pnl  =PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
      double distSL=(sl>0.0)?MathAbs(entry-sl):0.0;
      // Once SL is at/past breakeven distSL->0 would kill the denominator;
      // floor it at 1 ATR so rungs 2/3 can still evaluate.
      if(distSL<1.0) distSL=atrFB;
      totalLots+=lots; totalRisk+=lots*distSL*g_cfg.contractValue; totalPnL+=pnl;
      posCount++;
   }

   if(posCount==0)
   {
      rungs=0;
      if(direction>0){ mm_longBEActive=false;  mm_longTrailActive=false; }
      else           { mm_shortBEActive=false; mm_shortTrailActive=false; }
      return;
   }
   if(totalRisk<=0.0) return;

   double ratio=totalPnL/totalRisk;

   if(rungs==0 && ratio>=g_cfg.ladderR1)
   {
      MM_CloseProportionalAll(direction,g_cfg.ladderFrac1,"FALCON LADDER R1");
      rungs=1;
      if(direction>0) mm_longBEActive=true;  else mm_shortBEActive=true;
      MM_MoveStopsToBreakeven(direction);
   }
   else if(rungs==1 && ratio>=g_cfg.ladderR2)
   {
      MM_CloseProportionalAll(direction,g_cfg.ladderFrac2,"FALCON LADDER R2");
      rungs=2;
      if(direction>0){ mm_longBEActive=false;  mm_longTrailActive=true; }
      else           { mm_shortBEActive=false; mm_shortTrailActive=true; }
   }
   else if(rungs==2 && ratio>=g_cfg.ladderR3)
   {
      MM_CloseProportionalAll(direction,g_cfg.ladderFrac3,"FALCON LADDER R3");
      rungs=3;
   }
}

void MM_RunProfitLadder()
{
   MM_RunLadderDirection( 1, mm_longRungs);
   MM_RunLadderDirection(-1, mm_shortRungs);
}

#endif // FALCON_MONEY_MANAGER_MQH
//+------------------------------------------------------------------+
