//+------------------------------------------------------------------+
//|  FALCON OS — MODULE 4: EXECUTION ENGINE                         |
//|  Source: Symphony (DRDWCT risk · lot · session · ARC exit ·     |
//|  trade manager · portfolio · raw IOC hedging orders).           |
//|                                                                  |
//|  Execution NEVER decides — it only executes g_state.intel.       |
//|  decision. Risk is PER-CAMPAIGN (grouped by direction); opposite |
//|  directions are NOT netted (each side judged on its gross VaR,   |
//|  with a portfolio-level combined-gross backstop).                |
//+------------------------------------------------------------------+
#ifndef FALCON_EXECUTION_MQH
#define FALCON_EXECUTION_MQH
#include "Kernel.mqh"
#include <Trade\Trade.mqh>

//==================================================================
// DRDWCT RISK STRUCTS  (ported from Symphony)
//==================================================================
struct EXE_Position { long ticket; double lots; double entry; double sl; int direction; double pnl; };
struct EXE_Market   { double spot; double atr15; double atr30; double equity; double marginUsed; };
struct EXE_Metrics  { long ticket; double lots; int direction; double entry; double sl; double distSL;
                      double riskToSL; double rd; double sag; double gammaRaw; double gammaVolScaled;
                      double liqProx; double dVar2; double uds; };
struct EXE_VarResult{ double var2; double var3; };
struct EXE_Trim     { long ticket; double closeLots; };
struct EXE_Config
  {
   double rdLimit, w_rd, w_dVar2, w_gamma, w_liq, w_sag;
   double partialCloseFraction, minLotsForPartial;
   double highLayerQuantile, logisticK, logisticPivot, coreLowerBand, coreUpperBand;
   double volSpikeMultiplier, volSpikeThreshold;
   double liquidityLevels[32]; int liqCount;
  };
EXE_Config g_reCfg;
int g_atr15Handle=INVALID_HANDLE, g_atr30Handle=INVALID_HANDLE;
CTrade g_trade;  // used only for symbol/account helpers; orders go via raw request

//==================================================================
// LOT ENGINE  (XAUUSD $10/pip model from Symphony)
//==================================================================
double EXE_ComputeLots(double riskCash,double entry,double sl)
  {
   double dist=MathAbs(entry-sl); if(dist<=0) return(0.0);
   double distancePips=dist*10.0;
   double riskPerLot=distancePips*10.0;
   if(riskPerLot<=0) return(0.0);
   double lots=riskCash/riskPerLot;
   double minLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double lotStep=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   lots=MathFloor(lots/lotStep)*lotStep;
   if(lots<minLot) lots=minLot;
   return(NormalizeDouble(lots,2));
  }

//==================================================================
// SESSION FILTER  (London + US, no Asia)
//==================================================================
bool EXE_IsTradeTime()
  {
   MqlDateTime g; TimeGMT(g);
   int h=g.hour+g_cfg.targetGMT, m=g.min;
   if(h<0)h+=24; if(h>=24)h-=24;
   int cm=h*60+m;
   bool w1=(cm>=480&&cm<=705), w2=(cm>=705&&cm<=735), w3=(cm>=795&&cm<=825), w4=(cm>=870&&cm<=1080);
   bool k1=(cm>=480&&cm<=540), k2=(cm>=495&&cm<=525), k3=(cm>=885&&cm<=915), k4=(cm>=1005&&cm<=1035);
   return(w1||w2||w3||w4||k1||k2||k3||k4);
  }

//==================================================================
// DRDWCT CORE MATH  (ported from Symphony)
//==================================================================
double EXE_LotValue(double lots){ return(lots*100.0); }
double EXE_RD(double lots,double d){ return(d==0?1e10:lots/d); }
double EXE_SAG(double lots,double d){ return(d==0?1e10:(lots*lots)/(d*d)); }
double EXE_Gamma(double entry,double spot,double lots){ double dd=entry-spot; return(dd*dd*lots); }
double EXE_GammaVS(double g,double a15,double a30){ return(a30==0?g:g*(a15/a30)); }
double EXE_LiqProx(double sl)
  {
   if(g_reCfg.liqCount<=0) return(0);
   double best=1e10;
   for(int i=0;i<g_reCfg.liqCount;i++){ double d=MathAbs(g_reCfg.liquidityLevels[i]-sl); if(d<best)best=d; }
   return(1.0/(1.0+best));
  }

int EXE_CollectPositions(EXE_Position &out[],int wantDir=0)
  {
   int c=0,total=PositionsTotal();
   for(int i=0;i<total && c<64;i++)
     {
      ulong tk=PositionGetTicket(i); if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=g_cfg.magic) continue;
      int dir=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?1:-1;
      if(wantDir!=0 && dir!=wantDir) continue;
      EXE_Position p;
      p.ticket=(long)tk; p.lots=PositionGetDouble(POSITION_VOLUME);
      p.entry=PositionGetDouble(POSITION_PRICE_OPEN);
      double sl=PositionGetDouble(POSITION_SL); p.sl=(sl>0?sl:0.0);
      p.direction=dir; p.pnl=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
      ArrayResize(out,c+1); out[c]=p; c++;
     }
   return(c);
  }

void EXE_BuildMarket(EXE_Market &m)
  {
   m.spot=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   m.equity=AccountInfoDouble(ACCOUNT_EQUITY);
   m.marginUsed=AccountInfoDouble(ACCOUNT_MARGIN);
   double b15[1],b30[1]; ArraySetAsSeries(b15,true);ArraySetAsSeries(b30,true);
   if(g_atr15Handle!=INVALID_HANDLE && CopyBuffer(g_atr15Handle,0,0,1,b15)>0) m.atr15=b15[0]; else m.atr15=0;
   if(g_atr30Handle!=INVALID_HANDLE && CopyBuffer(g_atr30Handle,0,0,1,b30)>0) m.atr30=b30[0]; else m.atr30=0;
  }

// gross-exposure VaR for ONE campaign side (no netting against the other side)
double EXE_GrossVaR(EXE_Position &pos[],int n,EXE_Market &m)
  {
   if(n<=0) return(0);
   double sigma=m.atr30; if(sigma<=0) sigma=m.atr15; if(sigma<=0) sigma=1.0;
   // worst 2-sigma adverse move for the side, summed gross
   double worst=0;
   double scen[6]; scen[0]=m.spot-1*sigma; scen[1]=m.spot-2*sigma; scen[2]=m.spot-3*sigma;
   scen[3]=m.spot+1*sigma; scen[4]=m.spot+2*sigma; scen[5]=m.spot+3*sigma;
   for(int s=0;s<6;s++)
     {
      double tot=0;
      for(int i=0;i<n;i++)
        {
         double move=scen[s]-pos[i].entry;
         double sgn=(pos[i].direction<0?-move:move);
         tot+=sgn*EXE_LotValue(pos[i].lots);
        }
      if(tot<worst) worst=tot;
     }
   return(MathAbs(worst));
  }

void EXE_DynamicVarLimits(double equity,double &v2,double &v3)
  {
   if(equity<=0){ v2=0.04; v3=0.08; return; }
   if(equity<1000){ v2=0.04; v3=0.08; }
   else if(equity<10000){ v2=0.035; v3=0.07; }
   else if(equity<100000){ v2=0.03; v3=0.06; }
   else if(equity<1000000){ v2=0.025; v3=0.05; }
   else { v2=0.015; v3=0.03; }
  }

bool EXE_IsMicroBomb(double lots,double distSL){ if(distSL==0) return(true); return((lots/distSL)>g_reCfg.rdLimit); }

//==================================================================
// RAW ORDER EXECUTION  (IOC, hedging)
//==================================================================
bool EXE_SendMarket(int dir,double lots,double sl,const string cm)
  {
   if(lots<=0) return(false);
   MqlTradeRequest req; MqlTradeResult res; ZeroMemory(req); ZeroMemory(res);
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK), bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   req.action=TRADE_ACTION_DEAL; req.symbol=_Symbol; req.magic=g_cfg.magic;
   req.volume=lots; req.sl=sl; req.tp=0.0; req.deviation=20;
   req.type_filling=ORDER_FILLING_IOC; req.type_time=ORDER_TIME_GTC; req.comment=cm;
   if(dir>0){ req.type=ORDER_TYPE_BUY; req.price=ask; } else { req.type=ORDER_TYPE_SELL; req.price=bid; }
   if(!OrderSend(req,res)){ FAL_LogAlways("EXEC","OrderSend failed retcode="+IntegerToString(res.retcode)); return(false); }
   if(res.retcode!=TRADE_RETCODE_DONE && res.retcode!=TRADE_RETCODE_DONE_PARTIAL) return(false);
   return(true);
  }
bool EXE_ClosePartial(ulong ticket,double lotsToClose)
  {
   if(lotsToClose<=0) return(false);
   if(!PositionSelectByTicket(ticket)) return(false);
   if(PositionGetString(POSITION_SYMBOL)!=_Symbol) return(false);
   if(PositionGetInteger(POSITION_MAGIC)!=g_cfg.magic) return(false);
   double posLots=PositionGetDouble(POSITION_VOLUME);
   long type=PositionGetInteger(POSITION_TYPE);
   lotsToClose=NormalizeDouble(MathMin(lotsToClose,posLots),2);
   if(lotsToClose<=0) return(false);
   MqlTradeRequest req; MqlTradeResult res; ZeroMemory(req); ZeroMemory(res);
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK), bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   req.action=TRADE_ACTION_DEAL; req.symbol=_Symbol; req.magic=g_cfg.magic; req.position=ticket;
   req.volume=lotsToClose; req.deviation=20; req.type_filling=ORDER_FILLING_IOC; req.type_time=ORDER_TIME_GTC; req.comment="FALCON CLOSE";
   if(type==POSITION_TYPE_BUY){ req.type=ORDER_TYPE_SELL; req.price=bid; } else { req.type=ORDER_TYPE_BUY; req.price=ask; }
   if(!OrderSend(req,res)) return(false);
   return(res.retcode==TRADE_RETCODE_DONE||res.retcode==TRADE_RETCODE_DONE_PARTIAL);
  }
bool EXE_CloseFull(ulong ticket)
  {
   if(!PositionSelectByTicket(ticket)) return(false);
   return(EXE_ClosePartial(ticket,PositionGetDouble(POSITION_VOLUME)));
  }
void EXE_CloseSide(int dir)
  {
   int total=PositionsTotal();
   for(int i=total-1;i>=0;i--)
     {
      ulong tk=PositionGetTicket(i); if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=g_cfg.magic) continue;
      int d=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?1:-1;
      if(dir==0||d==dir) EXE_CloseFull(tk);
     }
  }

//==================================================================
// PER-CAMPAIGN RISK ENGINE (direction-grouped, no netting)
//==================================================================
void EXE_RiskEngine(FAL_Execution &x)
  {
   x.trimsThisBar=0;
   EXE_Market m; EXE_BuildMarket(m);
   x.equity=m.equity;

   EXE_Position longs[], shorts[], all[];
   int nl=EXE_CollectPositions(longs,1);
   int ns=EXE_CollectPositions(shorts,-1);
   int na=EXE_CollectPositions(all,0);

   // per-side gross book stats
   double longLots=0,shortLots=0,longPnL=0,shortPnL=0;
   for(int i=0;i<nl;i++){ longLots+=longs[i].lots; longPnL+=longs[i].pnl; }
   for(int i=0;i<ns;i++){ shortLots+=shorts[i].lots; shortPnL+=shorts[i].pnl; }
   x.longPositions=nl; x.shortPositions=ns;
   x.longLots=longLots; x.shortLots=shortLots; x.longPnL=longPnL; x.shortPnL=shortPnL;

   double v2f,v3f; EXE_DynamicVarLimits(m.equity,v2f,v3f);
   double v2Lim=v2f*m.equity, v3Lim=v3f*m.equity;
   x.var2Limit=v2Lim; x.var3Limit=v3Lim;

   double varLong=EXE_GrossVaR(longs,nl,m);
   double varShort=EXE_GrossVaR(shorts,ns,m);
   double grossVaR=varLong+varShort;     // portfolio combined-gross backstop
   x.var2=MathMax(varLong,varShort);     // worst single campaign
   x.var3=grossVaR;

   // micro-bomb scan (per position, direction-agnostic protection)
   bool anyBomb=false; double udsMax=0;
   long bombTicket=0; double bombUds=-1;
   for(int i=0;i<na;i++)
     {
      double sl=all[i].sl; if(sl==0) sl=all[i].direction<0?m.spot+10.0:m.spot-10.0;
      double distSL=MathAbs(sl-all[i].entry);
      double rd=EXE_RD(all[i].lots,distSL);
      double sag=EXE_SAG(all[i].lots,distSL);
      double gamma=EXE_GammaVS(EXE_Gamma(all[i].entry,m.spot,all[i].lots),m.atr15,m.atr30);
      double uds=g_reCfg.w_rd*FAL_Clamp(rd*100,0,1)+g_reCfg.w_sag*FAL_Clamp(sag*1000,0,1)+g_reCfg.w_gamma*FAL_Clamp(gamma/1e6,0,1)+g_reCfg.w_liq*EXE_LiqProx(sl);
      if(uds>udsMax) udsMax=uds;
      if(EXE_IsMicroBomb(all[i].lots,distSL)){ anyBomb=true; if(uds>bombUds){ bombUds=uds; bombTicket=all[i].ticket; } }
     }
   x.udsMax=udsMax; x.anyBomb=anyBomb;

   // trim the worst micro-bomb if the book breaches limits
   bool breach=(x.var2>v2Lim)||(x.var3>v3Lim)||anyBomb;
   if(breach && bombTicket!=0)
     {
      if(PositionSelectByTicket((ulong)bombTicket))
        {
         double lots=PositionGetDouble(POSITION_VOLUME);
         double closeLots = lots>=g_reCfg.minLotsForPartial ? lots*g_reCfg.partialCloseFraction : lots;
         if(EXE_ClosePartial((ulong)bombTicket,closeLots)) x.trimsThisBar++;
        }
     }

   x.riskOk = !((x.var2>v2Lim)||(x.var3>v3Lim));
  }

//==================================================================
// TRADE MANAGER  (open from decision · ARC/phase exits · scale)
//==================================================================
datetime g_lastLongBar=0, g_lastShortBar=0;
void EXE_OpenFromDecision(FAL_Execution &x)
  {
   FAL_Intelligence in=g_state.intel;
   x.lastAction="hold";
   if(!g_cfg.tradeEnabled) { x.lastAction="trading disabled"; return; }
   if(g_cfg.enableRiskEngine && g_cfg.blockNewIfBreach && !g_state.exec.riskOk){ x.lastAction="blocked (risk)"; return; }
   x.sessionOpen=EXE_IsTradeTime();
   if(!x.sessionOpen){ x.lastAction="out of session"; return; }

   double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   double riskCash=equity*g_cfg.riskPercent*0.01;
   x.riskCash=riskCash;
   double close=g_state.spot, atr=g_state.physics.atr; if(atr<=0)atr=_Point*10;
   datetime barT=iTime(_Symbol,_Period,0);

   int dec=in.decision;
   bool wantLong  = (dec==DEC_BUY)  || (dec==DEC_ATTACK && in.master==1) || (dec==DEC_SCALE && in.master==1);
   bool wantShort = (dec==DEC_SELL) || (dec==DEC_ATTACK && in.master==-1)|| (dec==DEC_SCALE && in.master==-1);

   if(wantLong && g_lastLongBar!=barT)
     {
      double entry=close;
      double sl=(in.stopPrice!=EMPTY_VALUE && in.stopPrice<entry)?in.stopPrice-atr*0.10:entry-atr*1.5;
      double lots=EXE_ComputeLots(riskCash,entry,sl);
      if(sl>0 && entry>sl && lots>0 && EXE_SendMarket(1,lots,sl,"FALCON "+FAL_DecisionStr(dec)+" L"))
        { g_lastLongBar=barT; x.lastAction="OPEN LONG"; FAL_Publish("ORDER_LONG"); }
     }
   if(wantShort && g_lastShortBar!=barT)
     {
      double entry=close;
      double sl=(in.stopPrice!=EMPTY_VALUE && in.stopPrice>entry)?in.stopPrice+atr*0.10:entry+atr*1.5;
      double lots=EXE_ComputeLots(riskCash,entry,sl);
      if(sl>0 && sl>entry && lots>0 && EXE_SendMarket(-1,lots,sl,"FALCON "+FAL_DecisionStr(dec)+" S"))
        { g_lastShortBar=barT; x.lastAction="OPEN SHORT"; FAL_Publish("ORDER_SHORT"); }
     }
  }

void EXE_ManageExits(FAL_Execution &x)
  {
   FAL_Intelligence in=g_state.intel;
   int dec=in.decision;

   // EXIT decision -> close the campaign aligned with the master/owner side
   if(dec==DEC_EXIT)
     {
      int side = g_state.curve.ownerDir!=0?g_state.curve.ownerDir:in.master;
      EXE_CloseSide(side);
      if(side==0) EXE_CloseSide(0);
      x.lastAction="EXIT side "+FAL_DirStr(side);
      return;
     }
   // DEFEND -> partial-trim the exposed side (winner/age-agnostic; protects the leg)
   if(dec==DEC_DEFEND)
     {
      int side=g_state.curve.ownerDir;
      EXE_Position pos[]; int n=EXE_CollectPositions(pos,side);
      for(int i=0;i<n;i++) EXE_ClosePartial((ulong)pos[i].ticket,pos[i].lots*0.5);
      x.lastAction="DEFEND trim "+FAL_DirStr(side);
      return;
     }
   // phase-based composite exit: a held side meeting its terminal/return phase
   int ph=in.phaseCode;
   bool longExit  = (ph==PH_SUPPLY_RTN||ph==PH_TERMINAL) && in.waveDir==-1;
   bool shortExit = (ph==PH_DEMAND_RTN||ph==PH_TERMINAL) && in.waveDir==1;
   if(longExit)  { EXE_CloseSide(1);  x.lastAction="PHASE EXIT long"; }
   if(shortExit) { EXE_CloseSide(-1); x.lastAction="PHASE EXIT short"; }
  }

//==================================================================
// MODULE 4 INIT + RUN
//==================================================================
void EXE_BuildRiskConfig(double equity)
  {
   g_reCfg.rdLimit=0.0095; g_reCfg.w_rd=0.35; g_reCfg.w_dVar2=0.25; g_reCfg.w_gamma=0.20; g_reCfg.w_liq=0.10; g_reCfg.w_sag=0.10;
   g_reCfg.highLayerQuantile=0.75; g_reCfg.logisticK=8; g_reCfg.logisticPivot=0.26; g_reCfg.coreLowerBand=0.45; g_reCfg.coreUpperBand=0.55;
   g_reCfg.volSpikeMultiplier=1.2; g_reCfg.volSpikeThreshold=3.0;
   double liq[]={2300,2320,2350,2380,2400,2415,2430,2450}; int nn=ArraySize(liq);
   g_reCfg.liqCount=(nn>32?32:nn); for(int i=0;i<g_reCfg.liqCount;i++) g_reCfg.liquidityLevels[i]=liq[i];
   if(equity<1000){ g_reCfg.partialCloseFraction=0.5; g_reCfg.minLotsForPartial=0.02; }
   else if(equity<10000){ g_reCfg.partialCloseFraction=0.4; g_reCfg.minLotsForPartial=0.03; }
   else if(equity<100000){ g_reCfg.partialCloseFraction=0.3; g_reCfg.minLotsForPartial=0.03; }
   else { g_reCfg.partialCloseFraction=0.25; g_reCfg.minLotsForPartial=0.05; }
  }
void EXE_Init()
  {
   EXE_BuildRiskConfig(AccountInfoDouble(ACCOUNT_EQUITY));
   g_atr15Handle=iATR(_Symbol,_Period,15);
   g_atr30Handle=iATR(_Symbol,_Period,30);
   g_lastLongBar=0; g_lastShortBar=0;
   g_state.exec.riskOk=true;
   FAL_SetModuleStatus(3,"ready");
  }
void EXE_Run()
  {
   if(g_cfg.enableRiskEngine) EXE_RiskEngine(g_state.exec); else g_state.exec.riskOk=true;
   EXE_ManageExits(g_state.exec);
   EXE_OpenFromDecision(g_state.exec);
   FAL_Publish("EXECUTION_DONE");
   FAL_SetModuleStatus(3,"ok");
  }

#endif // FALCON_EXECUTION_MQH
