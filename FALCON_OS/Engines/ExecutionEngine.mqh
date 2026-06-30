//+------------------------------------------------------------------+
//|  FALCON OS — Execution Layer : ExecutionEngine.mqh             |
//|  Source: Symphony (Execution & Risk)                            |
//|                                                                  |
//|  The OS EXECUTES — it never decides. It reads g_state.exec.action |
//|  (from the Decision Engine) and translates it into orders, sized  |
//|  by the lot engine, gated by the session filter, protected by     |
//|  drawdown protection and the ARC + institutional + phase-composite |
//|  exit logic. (Campaign risk is owned by the PYRO Thermal Risk      |
//|  Engine; the old DRDWCT VaR/UDS trimmer has been fully removed.)   |
//|                                                                  |
//|  MULTI-CAMPAIGN: this account is HEDGING. Long and short          |
//|  campaigns coexist. Exposure is tracked PER DIRECTION on GROSS    |
//|  lots (never netted) so opposite legs never mask each other.      |
//+------------------------------------------------------------------+
#ifndef FALCON_EXEC_ENGINE_MQH
#define FALCON_EXEC_ENGINE_MQH

#include <Trade\Trade.mqh>
#include "../Kernel/FalconState.mqh"
#include "../Kernel/FalconConfig.mqh"
#include "../Kernel/FalconSeries.mqh"
#include "../Kernel/FalconEventBus.mqh"
#include "../Kernel/FalconLog.mqh"
#include "../Kernel/FalconPersistence.mqh"

//==================================================================
// POSITION / MARKET STRUCTS
//==================================================================
struct EE_Position
{
   long   ticket; double lots; double entry; double sl; int direction; double pnl;
};
struct EE_Market { double spot; double atr15; double atr30; double equity; };

// event-driven: cooldown bars after a risk breach (set by subscriber)
int    ee_riskCooldown=0;
// partial take-profit per-ticket stage tracking
long   ee_tpTicket[256]; int ee_tpStage[256]; int ee_tpCount=0;

// SUBSCRIBER: react to a risk breach by blocking new entries for a few bars.
void EE_OnRiskBreach(const FalconEvent &e){ ee_riskCooldown=3; }
datetime ee_lastBarTime=0, ee_lastLongTrade=0, ee_lastShortTrade=0;
bool   ee_lastRiskOk=true;
// Institutional Exit Engine state (Symphony outer-band sweep tracking)
bool   ee_longOuterBreach=false, ee_shortOuterBreach=false;
double ee_lastWaveOrigin=0; int ee_lastWaveDir=0;

void ExecutionEngineInit()
{
   ee_lastBarTime=0; ee_lastLongTrade=0; ee_lastShortTrade=0; ee_lastRiskOk=true;
   ee_longOuterBreach=false; ee_shortOuterBreach=false; ee_lastWaveOrigin=0; ee_lastWaveDir=0;
   ee_riskCooldown=0; ee_tpCount=0;
   FalconSubscribe(EVT_RISK_BREACH, EE_OnRiskBreach);   // event-driven cooldown
}

//==================================================================
// LOT ENGINE — symbol-agnostic (uses broker tick value/size; falls
// back to the configured contract value if the symbol lacks them).
//==================================================================
double EE_ValuePerPoint()
{
   double tickVal=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double tickSz =SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(tickVal>0.0 && tickSz>0.0) return(tickVal/tickSz);   // money per 1.0 lot per price unit
   return(g_cfg.contractValue);                            // fallback (e.g. XAUUSD model)
}

double EE_ComputeLots(const double riskCash,const double entry,const double sl)
{
   double dist=MathAbs(entry-sl);
   if(dist<=0.0) return(0.0);
   double riskPerLot = dist*EE_ValuePerPoint();   // money risked per 1.0 lot at this SL distance
   if(riskPerLot<=0.0) return(0.0);
   double lots=riskCash/riskPerLot;
   double minLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double maxLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double lotStep=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(lotStep<=0) lotStep=0.01;
   if(minLot<=0)  minLot=0.01;
   lots=MathFloor(lots/lotStep)*lotStep;
   if(lots<minLot) lots=minLot;
   if(maxLot>0 && lots>maxLot) lots=maxLot;
   if(g_cfg.maxLots>0 && lots>g_cfg.maxLots) lots=g_cfg.maxLots;   // hard safety cap
   int volDigits=(lotStep>=1.0?0:lotStep>=0.1?1:2);
   return(NormalizeDouble(lots,volDigits));
}

//==================================================================
// SESSION FILTER (London + US windows, GMT baseline)
//==================================================================
bool EE_IsTradeTime()
{
   if(!g_cfg.sessionFilter) return(true);
   MqlDateTime g; TimeGMT(g);
   int hh=g.hour+g_cfg.targetGMT; if(hh<0)hh+=24; if(hh>=24)hh-=24;
   int cur=hh*60+g.min;
   bool w1=(cur>=480&&cur<=705);    // London AM
   bool w2=(cur>=705&&cur<=735);    // UK micro
   bool w3=(cur>=795&&cur<=825);    // 13:30 +-15
   bool w4=(cur>=870&&cur<=1080);   // US session
   bool k1=(cur>=480&&cur<=540);    // early London
   bool k2=(cur>=495&&cur<=525);    // 08:30 +-15
   bool k3=(cur>=885&&cur<=915);    // 15:00 +-15
   bool k4=(cur>=1005&&cur<=1035);  // 17:00 +-15
   return(w1||w2||w3||w4||k1||k2||k3||k4);
}

//==================================================================
// POSITION COLLECTION (grouped by direction = campaign)
//==================================================================
int EE_CollectPositions(EE_Position &out[],const int dirFilter)
{
   int c=0; int total=PositionsTotal();
   for(int i=0;i<total && c<64;i++)
   {
      ulong ticket=PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=g_cfg.magic) continue;
      long type=PositionGetInteger(POSITION_TYPE);
      int dir=(type==POSITION_TYPE_BUY?1:-1);
      if(dirFilter!=0 && dir!=dirFilter) continue;
      EE_Position p;
      p.ticket=(long)ticket;
      p.lots=PositionGetDouble(POSITION_VOLUME);
      p.entry=PositionGetDouble(POSITION_PRICE_OPEN);
      double sl=PositionGetDouble(POSITION_SL);
      p.sl=(sl>0?sl:0.0);
      p.direction=dir;
      p.pnl=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP); // commission is per-deal in MT5
      out[c++]=p;
   }
   return(c);
}

void EE_BuildMarket(EE_Market &m)
{
   m.spot   = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   m.equity = AccountInfoDouble(ACCOUNT_EQUITY);
   m.atr15  = FalconATR(0,1);
   m.atr30  = FalconATR(0,2);
}

//==================================================================
// ORDER HELPERS (raw MqlTradeRequest, IOC)
//==================================================================
ulong ee_lastTicket = 0;   // POSITION ticket of the most recent successful entry
bool EE_SendMarketOrder(const int direction,const double lots,const double sl,const string comment,const double tp=0.0)
{
   if(lots<=0.0) return(false);
   if(!g_cfg.enableTrading) { FalconInfo("ExecutionEngine","trading disabled - skipped order"); return(false); }
   MqlTradeRequest req; MqlTradeResult res; ZeroMemory(req); ZeroMemory(res);
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   req.action=TRADE_ACTION_DEAL; req.symbol=_Symbol; req.magic=g_cfg.magic;
   req.volume=lots; req.sl=sl; req.tp=(tp>0.0?tp:0.0); req.deviation=20;
   req.type_filling=ORDER_FILLING_IOC; req.type_time=ORDER_TIME_GTC; req.comment=comment;
   if(direction>0){ req.type=ORDER_TYPE_BUY; req.price=ask; }
   else           { req.type=ORDER_TYPE_SELL;req.price=bid; }
   if(!OrderSend(req,res) || (res.retcode!=TRADE_RETCODE_DONE && res.retcode!=TRADE_RETCODE_DONE_PARTIAL))
   {
      FalconPublish(EVT_ORDER_FAILED,direction,comment);
      FalconError("ExecutionEngine",StringFormat("order failed dir=%d ret=%d",direction,res.retcode));
      return(false);
   }
   // expose the resulting POSITION ticket (for the trade journal / diagnostics)
   ee_lastTicket = 0;
   if(res.deal>0 && HistoryDealSelect(res.deal))
      ee_lastTicket = (ulong)HistoryDealGetInteger(res.deal, DEAL_POSITION_ID);
   if(ee_lastTicket==0) ee_lastTicket = (ulong)res.order;
   FalconPublish(EVT_ORDER_SENT,direction,comment);
   return(true);
}

bool EE_ClosePartial(const ulong ticket,double lots)
{
   if(lots<=0.0) return(false);
   if(!PositionSelectByTicket(ticket)) return(false);
   if(PositionGetString(POSITION_SYMBOL)!=_Symbol) return(false);
   if(PositionGetInteger(POSITION_MAGIC)!=g_cfg.magic) return(false);
   long type=PositionGetInteger(POSITION_TYPE);
   double posLots=PositionGetDouble(POSITION_VOLUME);
   lots=NormalizeDouble(MathMin(lots,posLots),2);
   if(lots<=0) return(false);
   MqlTradeRequest req; MqlTradeResult res; ZeroMemory(req); ZeroMemory(res);
   req.action=TRADE_ACTION_DEAL; req.symbol=_Symbol; req.magic=g_cfg.magic;
   req.position=ticket; req.volume=lots; req.deviation=20;
   req.type_filling=ORDER_FILLING_IOC; req.type_time=ORDER_TIME_GTC; req.comment="FALCON PARTIAL";
   if(type==POSITION_TYPE_BUY){ req.type=ORDER_TYPE_SELL; req.price=SymbolInfoDouble(_Symbol,SYMBOL_BID); }
   else                       { req.type=ORDER_TYPE_BUY;  req.price=SymbolInfoDouble(_Symbol,SYMBOL_ASK); }
   if(!OrderSend(req,res) || (res.retcode!=TRADE_RETCODE_DONE && res.retcode!=TRADE_RETCODE_DONE_PARTIAL))
      return(false);
   return(true);
}
bool EE_CloseFull(const ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return(false);
   return(EE_ClosePartial(ticket,PositionGetDouble(POSITION_VOLUME)));
}

//==================================================================
// EXPOSURE SNAPSHOT into shared state (used by Decision DEFEND/SCALE)
//==================================================================
void EE_UpdateExposure(const EE_Market &m)
{
   EE_Position lp[64], sp[64];
   int nl=EE_CollectPositions(lp,1);
   int ns=EE_CollectPositions(sp,-1);
   double longLots=0,shortLots=0,pnl=0;
   for(int i=0;i<nl;i++){ longLots+=lp[i].lots; pnl+=lp[i].pnl; }
   for(int i=0;i<ns;i++){ shortLots+=sp[i].lots; pnl+=sp[i].pnl; }
   g_state.exec.openLongCount=nl;
   g_state.exec.openShortCount=ns;
   g_state.exec.longGrossLots=longLots;
   g_state.exec.shortGrossLots=shortLots;
   g_state.exec.openPnL=pnl;

   // ---- TRADE STATE ----
   int ts;
   if(nl>0 && ns>0)      ts=TS_HEDGED;
   else if(nl>0)         ts=TS_LONG_OPEN;
   else if(ns>0)         ts=TS_SHORT_OPEN;
   else                  ts=TS_FLAT;
   if(ts!=TS_FLAT && g_state.exec.action==ACT_SCALE)  ts=TS_SCALING;
   if(ts!=TS_FLAT && g_state.exec.action==ACT_DEFEND) ts=TS_DEFENDING;
   g_state.exec.tradeState=ts;
}

//==================================================================
// ENTRY — translate the decision action into a sized order.
//==================================================================
//==================================================================
// TERMINAL-AWARE STOP & OWNER-DRIVEN TARGET (ODDE)
//   Stop sits just beyond the swept terminal extreme (the supply/demand
//   that price liquidated into), capped so risk stays sane. Target is
//   inherited from the owner curve hierarchy (FRZ / wave objective),
//   with secondary/extended targets for partial scale-out.
//==================================================================
double EE_TerminalStop(const int dir,const double entry,const double atr)
{
   int win=g_cfg.structLen*2+g_cfg.pivotLen;
   double sl;
   if(dir==DIR_LONG)
   {
      double sweptLow = FalconLowest(1,win);
      double zoneLow  = (g_state.supplyDemand.demandBot!=0? g_state.supplyDemand.demandBot
                        : g_state.wave.flipBot!=0? g_state.wave.flipBot : sweptLow);
      sl = MathMin(sweptLow, zoneLow) - atr*0.5;
      if(entry-sl > atr*6.0) sl = entry - atr*3.0;   // cap risk if extreme is far
      if(sl>=entry) sl = entry - atr*1.5;
   }
   else
   {
      double sweptHigh= FalconHighest(1,win);
      double zoneHigh = (g_state.supplyDemand.supplyTop!=0? g_state.supplyDemand.supplyTop
                        : g_state.wave.flipTop!=0? g_state.wave.flipTop : sweptHigh);
      sl = MathMax(sweptHigh, zoneHigh) + atr*0.5;
      if(sl-entry > atr*6.0) sl = entry + atr*3.0;
      if(sl<=entry) sl = entry + atr*1.5;
   }
   return(sl);
}

void EE_OwnerTargets(const int dir,const double entry,const double atr,double &t1,double &t2,double &t3)
{
   // DESTINATION AUTHORITY (WHERE): the conversation route's next node is the
   // primary target when it sits ahead of price in the trade direction. T2/T3
   // extend via the owner-return target (FRZ) and the wave objective (ODDE). If
   // no valid node, fall back to wave objective.
   double obj  = g_state.wave.objective;
   double frz  = g_state.frz.targetPrice;
   double node = g_state.network.nextNodePrice;     // <- conversation route destination
   if(dir==DIR_LONG)
   {
      bool nodeAhead = (node>entry);
      t1 = nodeAhead ? node : (obj>entry ? obj : entry + atr*3.0);
      t2 = MathMax(t1, (obj>entry ? obj : (frz>entry?frz:entry+atr*5.0)));
      t3 = MathMax(t2, entry + atr*8.0);
   }
   else
   {
      bool nodeAhead = (node>0 && node<entry);
      t1 = nodeAhead ? node : (obj<entry && obj>0 ? obj : entry - atr*3.0);
      t2 = MathMin(t1, (obj<entry && obj>0 ? obj : (frz<entry && frz>0 ? frz : entry-atr*5.0)));
      t3 = MathMin(t2, entry - atr*8.0);
   }
}

void EE_HandleEntries(const EE_Market &m)
{
   int action=g_state.exec.action;
   int master=g_state.exec.master;
   datetime barTime=gTime[0];

   // Firing actions: BUY / SELL / SCALE enter in the (entry-cycle) master
   // direction. BUY/SELL are now emitted ONLY when the Entry Cycle Engine
   // reports the entry cycle is active in the terminal zone, so they are the
   // precise execution signals. ATTACK = in terminal, armed, waiting for the
   // cycle to begin -> does NOT fire. PREPARE/WAIT/NO_TRADE/DEFEND/EXIT fire nothing.
   bool wantBuy  = ((action==ACT_BUY||action==ACT_SCALE) && master==DIR_LONG);
   bool wantSell = ((action==ACT_SELL||action==ACT_SCALE) && master==DIR_SHORT);

   if(!wantBuy && !wantSell) return;
   if(!EE_IsTradeTime()) return;
   if(g_cfg.blockIfBreach && !ee_lastRiskOk) return;
   if(ee_riskCooldown>0) return;   // event-driven: cooling off after a risk breach

   // LATE / NO-ROOM GUARD (symmetric for both sides): never OPEN a fresh
   // campaign into exhaustion — no buying the top, no selling the bottom.
   // Blocked when the wave is near terminal or there is little room to the
   // owner target. SCALE (adding to a winner) is exempt.
   if(action!=ACT_SCALE)
   {
      bool tooLate = (g_state.wave.completion    >= g_cfg.maxEntryComplete);
      bool noRoom  = (g_state.convexity.geometryCapacity < g_cfg.minEntryRoomPct);
      if(tooLate || noRoom){ wantBuy=false; wantSell=false; }
   }
   if(!wantBuy && !wantSell) return;

   double atr=g_state.physics.atr;
   double close1=gClose[1];
   double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   double riskCash=equity*g_cfg.riskPercent*0.01;
   // CONVICTION SIZING: cross-TF agreement (Wave Matrix) scales the risk. Full
   // size on strong consensus, reduced size on cross-TF noise. (SCALE is exempt.)
   if(action!=ACT_SCALE)
   {
      double convFactor = FalconClamp(0.40 + 0.60*g_state.waveMatrix.agreement/100.0, 0.40, 1.0);
      riskCash *= convFactor;
   }

   if(wantBuy && ee_lastLongTrade!=barTime)
   {
      double entry=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double sl=EE_TerminalStop(DIR_LONG,entry,atr);
      double t1,t2,t3; EE_OwnerTargets(DIR_LONG,entry,atr,t1,t2,t3);
      double lots=EE_ComputeLots(riskCash,entry,sl);
      if(sl>0 && entry>sl && lots>0 && EE_SendMarketOrder(+1,lots,sl,"FALCON "+FalconActionStr(action)+" L"))
      {
         ee_lastLongTrade=barTime;
         g_state.exec.entry=entry; g_state.exec.stop=sl;
         g_state.exec.target=t1; g_state.exec.target2=t2; g_state.exec.target3=t3;
         g_state.exec.lots=lots; g_state.exec.riskCash=riskCash;
         g_state.exec.reward=(MathAbs(entry-sl)>1e-10)?MathAbs(t1-entry)/MathAbs(entry-sl):0.0;
      }
   }
   if(wantSell && ee_lastShortTrade!=barTime)
   {
      double entry=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double sl=EE_TerminalStop(DIR_SHORT,entry,atr);
      double t1,t2,t3; EE_OwnerTargets(DIR_SHORT,entry,atr,t1,t2,t3);
      double lots=EE_ComputeLots(riskCash,entry,sl);
      if(sl>0 && sl>entry && lots>0 && EE_SendMarketOrder(-1,lots,sl,"FALCON "+FalconActionStr(action)+" S"))
      {
         ee_lastShortTrade=barTime;
         g_state.exec.entry=entry; g_state.exec.stop=sl;
         g_state.exec.target=t1; g_state.exec.target2=t2; g_state.exec.target3=t3;
         g_state.exec.lots=lots; g_state.exec.riskCash=riskCash;
         g_state.exec.reward=(MathAbs(entry-sl)>1e-10)?MathAbs(t1-entry)/MathAbs(entry-sl):0.0;
      }
   }
}

//==================================================================
// INSTITUTIONAL EXIT ENGINE — track per-wave outer-band sweeps so the
// composite exit can require the institutional pattern (Symphony):
//   ARC exhaust + outer-band sweep seen + close back inside inner band
//   + phase trend-end. Reset whenever a fresh wave spawns.
//==================================================================
void EE_UpdateInstitutional()
{
   FalconWave w=g_state.wave;
   double atr=g_state.physics.atr;
   double close1=gClose[1];

   // reset on a new wave (origin or direction changed)
   if(w.origin!=ee_lastWaveOrigin || w.direction!=ee_lastWaveDir)
   {
      ee_longOuterBreach=false; ee_shortOuterBreach=false;
      ee_lastWaveOrigin=w.origin; ee_lastWaveDir=w.direction;
   }

   // inner band = inducement zone (or flip band); outer band = inner ± outerBandAtrMult
   FalconLiquidity lq=g_state.liquidity;
   double innerTopL = (lq.induceTop!=0? lq.induceTop : (w.flipTop!=0? w.flipTop:0));
   double innerBotS = (lq.induceBot!=0? lq.induceBot : (w.flipBot!=0? w.flipBot:0));

   if(w.direction==DIR_LONG && innerTopL>0)
   {
      double outerTopL=innerTopL + g_cfg.outerBandAtrMult*atr;
      if(close1>outerTopL) ee_longOuterBreach=true;
   }
   if(w.direction==DIR_SHORT && innerBotS>0)
   {
      double outerBotS=innerBotS - g_cfg.outerBandAtrMult*atr;
      if(close1<outerBotS) ee_shortOuterBreach=true;
   }
}

//==================================================================
// EXITS — ARC + institutional + phase composite + decision EXIT/DEFEND
//==================================================================
void EE_HandleExits()
{
   int action=g_state.exec.action;
   FalconWave w=g_state.wave;
   FalconConvexity cv=g_state.convexity;
   double atr=g_state.physics.atr;
   double close1=gClose[1];

   bool exitLong=false, exitShort=false;
   int  exitReason=XS_NONE;

   // ARC exhaustion (Symphony)
   bool arcExhaustLong  = (w.direction==DIR_LONG  && cv.arcLong>0.0  && close1>=(cv.arcLong - g_cfg.arcToleranceAtr*atr));
   bool arcExhaustShort = (w.direction==DIR_SHORT && cv.arcShort>0.0 && close1<=(cv.arcShort+ g_cfg.arcToleranceAtr*atr));
   bool phaseEndLong  = (w.prevPhase>=PH_NEW_HIGH && w.phase<=PH_EXP_PRECONVEXITY && w.direction==DIR_LONG);
   bool phaseEndShort = (w.prevPhase>=PH_NEW_HIGH && w.phase<=PH_EXP_PRECONVEXITY && w.direction==DIR_SHORT);

   if(arcExhaustLong && phaseEndLong)  { exitLong=true;  exitReason=XS_ARC_EXHAUST; }
   if(arcExhaustShort&& phaseEndShort) { exitShort=true; exitReason=XS_ARC_EXHAUST; }

   // INSTITUTIONAL pattern gate: if an inner band exists, require the outer-band
   // sweep to have occurred AND price to have closed back inside it (Symphony).
   FalconLiquidity lq=g_state.liquidity;
   double innerTopL = (lq.induceTop!=0? lq.induceTop : w.flipTop);
   double innerBotS = (lq.induceBot!=0? lq.induceBot : w.flipBot);
   if(exitLong && innerTopL>0)
   {
      bool instOK = (ee_longOuterBreach && close1<innerTopL);
      if(!instOK) exitLong=false;   // not yet an institutional reversal
   }
   if(exitShort && innerBotS>0)
   {
      bool instOK = (ee_shortOuterBreach && close1>innerBotS);
      if(!instOK) exitShort=false;
   }

   // resolution complete -> exit the resolved side
   if(g_state.intel.resolutionState==RES_RESOLVED)
   {
      if(w.direction==DIR_LONG)  { exitLong=true;  exitReason=XS_RESOLUTION; }
      if(w.direction==DIR_SHORT) { exitShort=true; exitReason=XS_RESOLUTION; }
   }

   // explicit decision EXIT closes the master side; DEFEND closes the losing side
   if(action==ACT_EXIT)
   {
      if(g_state.exec.master==DIR_LONG)  { exitLong=true;  exitReason=XS_DECISION_EXIT; }
      if(g_state.exec.master==DIR_SHORT) { exitShort=true; exitReason=XS_DECISION_EXIT; }
   }
   if(action==ACT_DEFEND)
   {
      // defend = close the side fighting against the failure-swing risk
      if(g_state.intel.failureSwingProb>=0.70)
      {
         if(w.direction==DIR_LONG)  { exitLong=true;  exitReason=XS_DEFEND; }   // long wave failing -> protect longs
         if(w.direction==DIR_SHORT) { exitShort=true; exitReason=XS_DEFEND; }
      }
   }

   // CAMPAIGN INVALIDATION (direction-agnostic, per the multi-campaign rule):
   // a confirmed structural flip kills the opposite campaign's thesis. A bullish
   // CHoCH invalidates open SHORTS; a bearish CHoCH invalidates open LONGS. This
   // closes a bleeding book the moment the move that justified it is broken,
   // instead of orphaning it after the master direction flips.
   if(g_state.structure.choch==DIR_LONG  && g_state.exec.openShortCount>0){ exitShort=true; exitReason=XS_DEFEND; }
   if(g_state.structure.choch==DIR_SHORT && g_state.exec.openLongCount>0 ){ exitLong=true;  exitReason=XS_DEFEND; }

   if(!exitLong && !exitShort) return;
   g_state.exec.exitState=exitReason;

   int total=PositionsTotal();
   for(int i=total-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=g_cfg.magic) continue;
      long type=PositionGetInteger(POSITION_TYPE);
      if(exitLong && type==POSITION_TYPE_BUY)  { if(EE_CloseFull(ticket)) FalconPublish(EVT_EXIT_FIRED,1); }
      if(exitShort&& type==POSITION_TYPE_SELL) { if(EE_CloseFull(ticket)) FalconPublish(EVT_EXIT_FIRED,-1); }
   }
}

//==================================================================
// TRAILING ENGINE — once a position is in profit beyond trailStartATR,
// trail its stop at trailDistATR behind price (direction-aware).
//==================================================================
bool EE_ModifySL(const ulong ticket,const double newSL)
{
   if(!PositionSelectByTicket(ticket)) return(false);
   MqlTradeRequest req; MqlTradeResult res; ZeroMemory(req); ZeroMemory(res);
   req.action  = TRADE_ACTION_SLTP;
   req.symbol  = _Symbol;
   req.magic   = g_cfg.magic;
   req.position= ticket;
   req.sl      = NormalizeDouble(newSL,_Digits);
   req.tp      = PositionGetDouble(POSITION_TP);
   if(!OrderSend(req,res)) return(false);
   return(res.retcode==TRADE_RETCODE_DONE);
}

void EE_Trailing()
{
   if(!g_cfg.trailEnable) return;
   double atr=g_state.physics.atr;
   if(atr<=0) return;
   double startDist=atr*g_cfg.trailStartATR;
   double trailDist=atr*g_cfg.trailDistATR;
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);

   int total=PositionsTotal();
   for(int i=0;i<total;i++)
   {
      ulong ticket=PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=g_cfg.magic) continue;
      long type=PositionGetInteger(POSITION_TYPE);
      double entry=PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   =PositionGetDouble(POSITION_SL);

      if(type==POSITION_TYPE_BUY)
      {
         double profit=bid-entry;
         if(profit>startDist)
         {
            double newSL=bid-trailDist;
            if(newSL>entry && (sl==0 || newSL>sl)) { if(EE_ModifySL(ticket,newSL)) g_state.exec.exitState=XS_TRAIL_STOP; }
         }
      }
      else // SELL
      {
         double profit=entry-ask;
         if(profit>startDist)
         {
            double newSL=ask+trailDist;
            if(newSL<entry && (sl==0 || newSL<sl)) { if(EE_ModifySL(ticket,newSL)) g_state.exec.exitState=XS_TRAIL_STOP; }
         }
      }
   }
}

//==================================================================
// DRAWDOWN PROTECTION — uses the persistence layer's equity-peak /
// drawdown tracker. Blocks new entries above maxDrawdownPct and
// flattens ALL exposure above ddFlattenPct. Returns true if entries
// are allowed.
//==================================================================
bool EE_DrawdownProtection()
{
   if(!g_cfg.ddProtect) return(true);
   double ddPct = g_perf.maxDrawdownPct;          // rolling peak-to-trough %
   // live drawdown from current equity vs peak (more responsive than the max)
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   double liveDD=(g_perf.peakEquity>0 ? (g_perf.peakEquity-eq)/g_perf.peakEquity*100.0 : 0.0);
   double worst=MathMax(ddPct,liveDD);

   if(worst>=g_cfg.ddFlattenPct)
   {
      // hard protection: flatten everything — UNLESS the risk layer is set to
      // not auto-close (then TALON / money manager / SL-TP own all exits; we
      // still block new entries below).
      if(g_cfg.riskAutoClose)
      {
         int total=PositionsTotal();
         for(int i=total-1;i>=0;i--)
         {
            ulong ticket=PositionGetTicket(i);
            if(!PositionSelectByTicket(ticket)) continue;
            if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
            if(PositionGetInteger(POSITION_MAGIC)!=g_cfg.magic) continue;
            EE_CloseFull(ticket);
         }
         g_state.exec.exitState=XS_DD_FLATTEN;
      }
      FalconPublish(EVT_RISK_BREACH, worst, "drawdown flatten");
      return(false);
   }
   if(worst>=g_cfg.maxDrawdownPct)
   {
      FalconPublish(EVT_RISK_BREACH, worst, "drawdown block");
      return(false);   // block new entries, keep managing existing
   }
   return(true);
}

//==================================================================
// PARTIAL TAKE-PROFIT / SCALE-OUT — bank a third at T1, a third at T2,
// and the remainder at T3 (owner-driven targets). Per-ticket stage is
// tracked so each level fires once.  (state declared with the globals above)
//==================================================================
int EE_TPSlot(const long ticket)
{
   for(int i=0;i<ee_tpCount;i++) if(ee_tpTicket[i]==ticket) return(i);
   if(ee_tpCount<256){ ee_tpTicket[ee_tpCount]=ticket; ee_tpStage[ee_tpCount]=0; ee_tpCount++; return(ee_tpCount-1); }
   return(0);
}

void EE_ManagePartialTP()
{
   double t1=g_state.exec.target, t2=g_state.exec.target2, t3=g_state.exec.target3;
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID), ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   int total=PositionsTotal();
   for(int i=0;i<total;i++)
   {
      ulong ticket=PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=g_cfg.magic) continue;
      long type=PositionGetInteger(POSITION_TYPE);
      double vol=PositionGetDouble(POSITION_VOLUME);
      int slot=EE_TPSlot((long)ticket);
      int stage=ee_tpStage[slot];

      if(type==POSITION_TYPE_BUY)
      {
         if(stage<1 && t1>0 && bid>=t1){ if(EE_ClosePartial(ticket,vol*0.34)) ee_tpStage[slot]=1; }
         else if(stage<2 && t2>0 && bid>=t2){ if(EE_ClosePartial(ticket,vol*0.50)) ee_tpStage[slot]=2; }
         else if(stage<3 && t3>0 && bid>=t3){ if(EE_CloseFull(ticket)) ee_tpStage[slot]=3; }
      }
      else
      {
         if(stage<1 && t1>0 && ask<=t1){ if(EE_ClosePartial(ticket,vol*0.34)) ee_tpStage[slot]=1; }
         else if(stage<2 && t2>0 && ask<=t2){ if(EE_ClosePartial(ticket,vol*0.50)) ee_tpStage[slot]=2; }
         else if(stage<3 && t3>0 && ask<=t3){ if(EE_CloseFull(ticket)) ee_tpStage[slot]=3; }
      }
   }
}

//==================================================================
// MASTER ENTRY — Execution Engine pipeline step
//==================================================================
void ExecutionEngineRun()
{
   EE_Market m; EE_BuildMarket(m);
   EE_UpdateExposure(m);
   if(ee_riskCooldown>0) ee_riskCooldown--;

   // ---- DRDWCT RISK ENGINE FULLY REMOVED ----
   // The old VaR/UDS per-campaign trimmer (which closed open winners) is gone.
   // Campaign risk is now owned by the PYRO Thermal Risk Engine. This layer
   // only handles: per-trade stop sizing (lot engine), drawdown protection
   // (equity kill-switch), and decision-layer DEFEND/EXIT.
   bool ddOk = EE_DrawdownProtection();   // equity kill-switch only (no trimming)
   ee_lastRiskOk = ddOk;
   g_state.exec.riskOk = ee_lastRiskOk;
   g_state.exec.sessionOpen = EE_IsTradeTime();
   if(!ddOk) FalconPublish(EVT_RISK_BREACH,0.0);

   // ---- TRAILING + PARTIAL TAKE-PROFIT (manage open winners) ----
   // When Symphony is the active authority, it owns entries AND exits (ARC +
   // institutional + phase composite) with its own stop placement, so FALCON's
   // trailing/partial/exit/entry block is suppressed to avoid double-trading.
   // Drawdown protection + exposure snapshot always run.
   if(!g_cfg.useSymphony)
   {
      // EE's own ATR trail + partial yield to TALON or the money-manager ladder
      // whenever either owns exits — never run two trailing managers at once.
      if(!g_cfg.useTalon && !g_cfg.useProfitLadder)
      {
         EE_Trailing();
         EE_ManagePartialTP();
      }

      // ---- INSTITUTIONAL band tracking, then EXITS, then ENTRIES ----
      EE_UpdateInstitutional();
      EE_HandleExits();
      EE_HandleEntries(m);
   }

   // refresh exposure snapshot after actions
   EE_UpdateExposure(m);
}

#endif // FALCON_EXEC_ENGINE_MQH
//+------------------------------------------------------------------+
