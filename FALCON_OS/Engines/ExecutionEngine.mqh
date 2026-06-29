//+------------------------------------------------------------------+
//|  FALCON OS — Execution Layer : ExecutionEngine.mqh             |
//|  Source: Symphony (Execution & Risk)                            |
//|                                                                  |
//|  The OS EXECUTES — it never decides. It reads g_state.exec.action |
//|  (from the Decision Engine) and translates it into orders, sized  |
//|  by the lot engine, gated by the session filter, protected by the |
//|  DRDWCT risk engine (VaR / UDS / gamma / micro-bomb trimming) and |
//|  the ARC + institutional + phase-composite exit logic.            |
//|                                                                  |
//|  MULTI-CAMPAIGN: this account is HEDGING. Long and short          |
//|  campaigns coexist. Risk is evaluated PER DIRECTION on GROSS      |
//|  exposure (never netted), with a portfolio backstop on combined   |
//|  gross VaR. Opposite legs never mask each other's bleed.          |
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
// DRDWCT STRUCTS (ported from Symphony, trimmed to essentials)
//==================================================================
struct EE_Position
{
   long   ticket; double lots; double entry; double sl; int direction; double pnl;
};
struct EE_Market { double spot; double atr15; double atr30; double equity; };
struct EE_Metrics
{
   long ticket; double lots; int direction; double entry; double sl;
   double distSL; double rd; double sag; double gammaRaw; double gammaVolScaled;
   double liqProx; double dVar2; double uds;
};
struct EE_VarResult { double var2; double var3; };

double ee_liqLevels[32]; int ee_liqCount=0;
double ee_w_rd=0.35, ee_w_dVar2=0.25, ee_w_gamma=0.20, ee_w_liq=0.10, ee_w_sag=0.10;
datetime ee_lastBarTime=0, ee_lastLongTrade=0, ee_lastShortTrade=0;
bool   ee_lastRiskOk=true;
// Institutional Exit Engine state (Symphony outer-band sweep tracking)
bool   ee_longOuterBreach=false, ee_shortOuterBreach=false;
double ee_lastWaveOrigin=0; int ee_lastWaveDir=0;

void ExecutionEngineInit()
{
   ee_lastBarTime=0; ee_lastLongTrade=0; ee_lastShortTrade=0; ee_lastRiskOk=true;
   ee_liqCount=0;
   ee_longOuterBreach=false; ee_shortOuterBreach=false; ee_lastWaveOrigin=0; ee_lastWaveDir=0;
}

//==================================================================
// LOT ENGINE (Symphony XAUUSD-style sizing, generalized)
//==================================================================
double EE_ComputeLots(const double riskCash,const double entry,const double sl)
{
   double dist=MathAbs(entry-sl);
   if(dist<=0.0) return(0.0);
   double riskPerLot = dist*g_cfg.contractValue;   // value per price unit per lot
   if(riskPerLot<=0.0) return(0.0);
   double lots=riskCash/riskPerLot;
   double minLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double lotStep=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(lotStep<=0) lotStep=0.01;
   lots=MathFloor(lots/lotStep)*lotStep;
   if(lots<minLot) lots=minLot;
   return(NormalizeDouble(lots,2));
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
// DRDWCT MATH
//==================================================================
double EE_LotValue(const double lots){ return(lots*g_cfg.contractValue); }
double EE_RD(const double lots,const double distSL){ return(distSL==0?1e10:lots/distSL); }
double EE_SAG(const double lots,const double distSL){ return(distSL==0?1e10:(lots*lots)/(distSL*distSL)); }
double EE_Gamma(const double entry,const double spot,const double lots){ double d=entry-spot; return(d*d*lots); }
double EE_GammaVol(const double g,const double a15,const double a30){ return(a30==0?g:g*(a15/a30)); }
double EE_LiqProx(const double sl)
{
   if(ee_liqCount<=0) return(0.0);
   double best=1e10;
   for(int i=0;i<ee_liqCount;i++){ double d=MathAbs(ee_liqLevels[i]-sl); if(d<best)best=d; }
   return(1.0/(1.0+best));
}

void EE_BuildLiquidity()
{
   // pull liquidity scenario levels from the shared liquidity pools
   ee_liqCount=0;
   FalconLiquidity lq=g_state.liquidity;
   for(int i=0;i<lq.poolCount && ee_liqCount<32;i++)
      ee_liqLevels[ee_liqCount++]=lq.pools[i];
}

//==================================================================
// VAR ENGINE (scenario based, per-position set)
//==================================================================
void EE_BuildScenarios(const EE_Market &m,double &scen[],int &sc)
{
   double sigma=m.atr30; double spot=m.spot;
   double tmp[64]; int c=0;
   tmp[c++]=spot-1*sigma; tmp[c++]=spot-2*sigma; tmp[c++]=spot-3*sigma;
   tmp[c++]=spot+1*sigma; tmp[c++]=spot+2*sigma; tmp[c++]=spot+3*sigma;
   for(int i=0;i<ee_liqCount&&c<64;i++) tmp[c++]=ee_liqLevels[i];
   sc=0;
   for(int i=0;i<c;i++)
   {
      bool ex=false;
      for(int j=0;j<sc;j++) if(MathAbs(tmp[i]-scen[j])<1e-5){ ex=true; break; }
      if(!ex){ scen[sc++]=tmp[i]; }
   }
}
double EE_ScenarioPnL(const EE_Position &pos[],const int n,const double price)
{
   double tot=0;
   for(int i=0;i<n;i++)
   {
      double move=price-pos[i].entry;
      double sm=(pos[i].direction<0?-move:move);
      tot+=sm*EE_LotValue(pos[i].lots);
   }
   return(tot);
}
void EE_ComputeVaR(const EE_Position &pos[],const int n,const EE_Market &m,EE_VarResult &out)
{
   out.var2=0; out.var3=0; if(n<=0) return;
   double scen[64]; int sc=0; EE_BuildScenarios(m,scen,sc); if(sc<=0) return;
   double sigma=m.atr30; double netLots=0;
   for(int i=0;i<n;i++){ int s=(pos[i].direction<0?-1:1); netLots+=s*pos[i].lots; }
   double target2=(netLots<0?m.spot+2*sigma:m.spot-2*sigma);
   bool wI=false,cI=false; double worst=0,closest=0,cd=0;
   for(int i=0;i<sc;i++)
   {
      double pnl=EE_ScenarioPnL(pos,n,scen[i]);
      if(!wI||pnl<worst){ worst=pnl; wI=true; }
      double d=MathAbs(scen[i]-target2);
      if(!cI||d<cd){ cd=d; closest=pnl; cI=true; }
   }
   out.var3=MathAbs(worst); out.var2=MathAbs(closest);
}

void EE_DynamicVarLimits(const double equity,double &v2,double &v3)
{
   // aggressive intraday band (Symphony profile)
   if(equity<=0){ v2=0.04; v3=0.08; return; }
   if(equity<1000){ v2=0.04; v3=0.08; }
   else if(equity<10000){ v2=0.035; v3=0.07; }
   else if(equity<100000){ v2=0.03; v3=0.06; }
   else if(equity<1000000){ v2=0.025; v3=0.05; }
   else if(equity<10000000){ v2=0.015; v3=0.03; }
   else { v2=0.01; v3=0.02; }
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
      p.pnl=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP)+PositionGetDouble(POSITION_COMMISSION);
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
bool EE_SendMarketOrder(const int direction,const double lots,const double sl,const string comment)
{
   if(lots<=0.0) return(false);
   if(!g_cfg.enableTrading) { FalconInfo("ExecutionEngine","trading disabled - skipped order"); return(false); }
   MqlTradeRequest req; MqlTradeResult res; ZeroMemory(req); ZeroMemory(res);
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   req.action=TRADE_ACTION_DEAL; req.symbol=_Symbol; req.magic=g_cfg.magic;
   req.volume=lots; req.sl=sl; req.tp=0.0; req.deviation=20;
   req.type_filling=ORDER_FILLING_IOC; req.type_time=ORDER_TIME_GTC; req.comment=comment;
   if(direction>0){ req.type=ORDER_TYPE_BUY; req.price=ask; }
   else           { req.type=ORDER_TYPE_SELL;req.price=bid; }
   if(!OrderSend(req,res) || (res.retcode!=TRADE_RETCODE_DONE && res.retcode!=TRADE_RETCODE_DONE_PARTIAL))
   {
      FalconPublish(EVT_ORDER_FAILED,direction,comment);
      FalconError("ExecutionEngine",StringFormat("order failed dir=%d ret=%d",direction,res.retcode));
      return(false);
   }
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
   req.type_filling=ORDER_FILLING_IOC; req.type_time=ORDER_TIME_GTC; req.comment="FALCON TRIM";
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
// PER-CAMPAIGN RISK — evaluate one direction's GROSS book.
//   Returns true if the book is safe; trims micro-bombs in place.
//==================================================================
bool EE_RunCampaignRisk(const int dir,const EE_Market &m,double &grossLots,double &grossVaR,double &udsMax,bool &anyBomb)
{
   grossLots=0; grossVaR=0; udsMax=0; anyBomb=false;
   EE_Position pos[64];
   int n=EE_CollectPositions(pos,dir);
   if(n<=0) return(true);

   for(int i=0;i<n;i++) grossLots+=pos[i].lots;

   // metrics + micro-bomb detection
   double rdLimit=g_cfg.rdLimit;
   int worstIdx=-1; double worstUds=-1;
   for(int i=0;i<n;i++)
   {
      double sl=(pos[i].sl>0?pos[i].sl:(dir<0?m.spot+10.0:m.spot-10.0));
      double distSL=MathAbs(sl-pos[i].entry);
      double rd=EE_RD(pos[i].lots,distSL);
      double sag=EE_SAG(pos[i].lots,distSL);
      double gam=EE_GammaVol(EE_Gamma(pos[i].entry,m.spot,pos[i].lots),m.atr15,m.atr30);
      double liq=EE_LiqProx(sl);
      double uds=ee_w_rd*rd + ee_w_sag*sag*1e-4 + ee_w_gamma*gam*1e-6 + ee_w_liq*liq + ee_w_dVar2*0.0;
      if(uds>udsMax) udsMax=uds;
      if(uds>worstUds){ worstUds=uds; worstIdx=i; }
      if(rd>rdLimit) anyBomb=true;
   }

   EE_VarResult vr; EE_ComputeVaR(pos,n,m,vr);
   grossVaR=vr.var3;   // worst-case gross VaR for THIS direction

   double v2f,v3f; EE_DynamicVarLimits(m.equity,v2f,v3f);
   double v3Lim=v3f*m.equity;

   bool safe=(grossVaR<=v3Lim && !anyBomb);
   if(!safe && worstIdx>=0)
   {
      // trim the worst micro-bomb in this campaign (partial)
      double closeLots=pos[worstIdx].lots*0.4;
      if(closeLots<SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN)) closeLots=pos[worstIdx].lots;
      if(EE_ClosePartial((ulong)pos[worstIdx].ticket,closeLots))
         FalconPublish(EVT_TRIM,dir,"campaign micro-bomb trim");
   }
   return(safe);
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
void EE_HandleEntries(const EE_Market &m)
{
   int action=g_state.exec.action;
   int master=g_state.exec.master;
   datetime barTime=gTime[0];

   // Firing actions: BUY / SELL / ATTACK / SCALE all enter in the master
   // direction. ATTACK is the Senseei "take the shot" verdict (the Master Chief
   // has already vetoed it down to PREPARE if conviction was lacking).
   // PREPARE / WAIT / NO_TRADE / DEFEND / EXIT do not open new positions here.
   bool wantBuy  = ((action==ACT_BUY||action==ACT_ATTACK||action==ACT_SCALE) && master==DIR_LONG);
   bool wantSell = ((action==ACT_SELL||action==ACT_ATTACK||action==ACT_SCALE) && master==DIR_SHORT);

   if(!wantBuy && !wantSell) return;
   if(!EE_IsTradeTime()) return;
   if(g_cfg.blockIfBreach && !ee_lastRiskOk) return;

   double atr=g_state.physics.atr;
   double close1=gClose[1];
   double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   double riskCash=equity*g_cfg.riskPercent*0.01;

   if(wantBuy && ee_lastLongTrade!=barTime)
   {
      double entry=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double sl=(g_state.wave.origin!=0? g_state.wave.origin-atr*0.25 : close1-atr*1.5);
      double lots=EE_ComputeLots(riskCash,entry,sl);
      if(sl>0 && entry>sl && lots>0 && EE_SendMarketOrder(+1,lots,sl,"FALCON "+FalconActionStr(action)+" L"))
      {
         ee_lastLongTrade=barTime;
         g_state.exec.entry=entry; g_state.exec.stop=sl;
         g_state.exec.target=g_state.wave.objective; g_state.exec.lots=lots; g_state.exec.riskCash=riskCash;
         double rr=(MathAbs(entry-sl)>1e-10 && g_state.wave.objective!=0)?MathAbs(g_state.wave.objective-entry)/MathAbs(entry-sl):0.0;
         g_state.exec.reward=rr;
      }
   }
   if(wantSell && ee_lastShortTrade!=barTime)
   {
      double entry=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double sl=(g_state.wave.origin!=0? g_state.wave.origin+atr*0.25 : close1+atr*1.5);
      double lots=EE_ComputeLots(riskCash,entry,sl);
      if(sl>0 && sl>entry && lots>0 && EE_SendMarketOrder(-1,lots,sl,"FALCON "+FalconActionStr(action)+" S"))
      {
         ee_lastShortTrade=barTime;
         g_state.exec.entry=entry; g_state.exec.stop=sl;
         g_state.exec.target=g_state.wave.objective; g_state.exec.lots=lots; g_state.exec.riskCash=riskCash;
         double rr=(MathAbs(entry-sl)>1e-10 && g_state.wave.objective!=0)?MathAbs(g_state.wave.objective-entry)/MathAbs(entry-sl):0.0;
         g_state.exec.reward=rr;
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
      // hard protection: flatten everything
      int total=PositionsTotal();
      for(int i=total-1;i>=0;i--)
      {
         ulong ticket=PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
         if(PositionGetInteger(POSITION_MAGIC)!=g_cfg.magic) continue;
         EE_CloseFull(ticket);
      }
      FalconPublish(EVT_RISK_BREACH, worst, "drawdown flatten");
      g_state.exec.exitState=XS_DD_FLATTEN;
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
// MASTER ENTRY — Execution Engine pipeline step
//==================================================================
void ExecutionEngineRun()
{
   EE_Market m; EE_BuildMarket(m);
   EE_BuildLiquidity();
   EE_UpdateExposure(m);

   // ---- PER-CAMPAIGN RISK (multi-direction, gross, never netted) ----
   bool longOk=true, shortOk=true;
   double lLots=0,sLots=0,lVaR=0,sVaR=0,lUds=0,sUds=0; bool lBomb=false,sBomb=false;
   if(g_cfg.enableRiskEng)
   {
      longOk  = EE_RunCampaignRisk( 1,m,lLots,lVaR,lUds,lBomb);
      shortOk = EE_RunCampaignRisk(-1,m,sLots,sVaR,sUds,sBomb);
   }
   g_state.exec.longGrossVaR=lVaR;
   g_state.exec.shortGrossVaR=sVaR;
   g_state.exec.udsMax=MathMax(lUds,sUds);
   g_state.exec.anyBomb=(lBomb||sBomb);

   // ---- PORTFOLIO BACKSTOP on COMBINED GROSS VaR ----
   double v2f,v3f; EE_DynamicVarLimits(m.equity,v2f,v3f);
   g_state.exec.var2Limit=v2f*m.equity;
   g_state.exec.var3Limit=v3f*m.equity;
   double combinedGrossVaR=lVaR+sVaR;   // GROSS sum, not net
   g_state.exec.var3=combinedGrossVaR;
   bool portfolioOk=(combinedGrossVaR <= g_state.exec.var3Limit*1.5);

   // ---- DRAWDOWN PROTECTION (may flatten / block) ----
   bool ddOk = EE_DrawdownProtection();

   ee_lastRiskOk=(longOk && shortOk && portfolioOk && ddOk);
   g_state.exec.riskOk=ee_lastRiskOk;
   g_state.exec.sessionOpen=EE_IsTradeTime();
   if(!ee_lastRiskOk) FalconPublish(EVT_RISK_BREACH,combinedGrossVaR);

   // ---- TRAILING (manage open winners) ----
   EE_Trailing();

   // ---- INSTITUTIONAL band tracking, then EXITS, then ENTRIES ----
   EE_UpdateInstitutional();
   EE_HandleExits();
   EE_HandleEntries(m);

   // refresh exposure snapshot after actions
   EE_UpdateExposure(m);
}

#endif // FALCON_EXEC_ENGINE_MQH
//+------------------------------------------------------------------+
