//+------------------------------------------------------------------+
//| FALCON_M4_Execution.mqh                                           |
//| FALCON OS - Module 4: Execution Engine (Source: Symphony)         |
//|                                                                   |
//| Executes only. Never decides. Obeys gState.intel.decision.        |
//| Owns: Trade Manager, Risk Engine (DRDWCT/VaR/Gamma/UDS),           |
//| Portfolio, Position Manager, ARC Exit, Lot Engine, Session         |
//| Filter, Hedging, Partial Close, Trailing, Drawdown Protection.    |
//| Writes gState.exec.                                               |
//+------------------------------------------------------------------+
#property strict
#include <Trade\Trade.mqh>

//==================================================================
// SESSION ENGINE (London + US, no Asia)
//==================================================================
bool M4_IsTradeTime()
{
   MqlDateTime g; TimeGMT(g);
   int h=g.hour+CfgTargetGMT; int m=g.min;
   if(h<0)h+=24; if(h>=24)h-=24;
   int cur=h*60+m;
   bool w1=(cur>=480&&cur<=705);   // London AM
   bool w2=(cur>=705&&cur<=735);   // UK micro
   bool w3=(cur>=795&&cur<=825);   // 13:15-13:45
   bool w4=(cur>=870&&cur<=1080);  // US
   bool k1=(cur>=495&&cur<=525);   // 08:30
   bool k2=(cur>=885&&cur<=915);   // 15:00
   bool k3=(cur>=1005&&cur<=1035); // 17:00
   return(w1||w2||w3||w4||k1||k2||k3);
}

//==================================================================
// LOT ENGINE (XAUUSD model)
//==================================================================
double M4_ComputeLots(double riskCash, double entry, double sl)
{
   double dist=MathAbs(entry-sl);
   if(dist<=0.0) return(0.0);
   double distancePips=dist*10.0;
   double riskPerLot=distancePips*10.0;
   if(riskPerLot<=0.0) return(0.0);
   double lots=riskCash/riskPerLot;
   double minLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double lotStep=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   lots=MathFloor(lots/lotStep)*lotStep;
   if(lots<minLot) lots=minLot;
   return(NormalizeDouble(lots,2));
}


//==================================================================
// ORDER PRIMITIVES (RAW IOC, hedging)
//==================================================================
bool M4_SendOrder(int dir, double lots, double sl, string comment)
{
   if(lots<=0.0) return(false);
   MqlTradeRequest req; MqlTradeResult res; ZeroMemory(req); ZeroMemory(res);
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK), bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   req.action=TRADE_ACTION_DEAL; req.symbol=_Symbol; req.magic=CfgMagic;
   req.volume=lots; req.sl=sl; req.tp=0.0; req.deviation=20;
   req.type_filling=ORDER_FILLING_IOC; req.type_time=ORDER_TIME_GTC; req.comment=comment;
   if(dir>0){ req.type=ORDER_TYPE_BUY; req.price=ask; }
   else { req.type=ORDER_TYPE_SELL; req.price=bid; }
   if(!OrderSend(req,res)){ FALCON_Log(LOG_ERROR,"M4.Exec","OrderSend fail rc="+IntegerToString(res.retcode)); return(false); }
   if(res.retcode!=TRADE_RETCODE_DONE && res.retcode!=TRADE_RETCODE_DONE_PARTIAL) return(false);
   return(true);
}

bool M4_ClosePartial(ulong ticket, double lots)
{
   if(lots<=0.0) return(false);
   if(!PositionSelectByTicket(ticket)) return(false);
   if(PositionGetString(POSITION_SYMBOL)!=_Symbol || PositionGetInteger(POSITION_MAGIC)!=CfgMagic) return(false);
   long type=PositionGetInteger(POSITION_TYPE);
   double posLots=PositionGetDouble(POSITION_VOLUME);
   lots=NormalizeDouble(MathMin(lots,posLots),2);
   if(lots<=0) return(false);
   MqlTradeRequest req; MqlTradeResult res; ZeroMemory(req); ZeroMemory(res);
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK), bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   req.action=TRADE_ACTION_DEAL; req.symbol=_Symbol; req.magic=CfgMagic; req.position=ticket;
   req.volume=lots; req.deviation=20; req.type_filling=ORDER_FILLING_IOC; req.type_time=ORDER_TIME_GTC;
   req.comment="FALCON TRIM";
   if(type==POSITION_TYPE_BUY){ req.type=ORDER_TYPE_SELL; req.price=bid; }
   else { req.type=ORDER_TYPE_BUY; req.price=ask; }
   if(!OrderSend(req,res)) return(false);
   return(res.retcode==TRADE_RETCODE_DONE||res.retcode==TRADE_RETCODE_DONE_PARTIAL);
}

bool M4_CloseFull(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return(false);
   return(M4_ClosePartial(ticket, PositionGetDouble(POSITION_VOLUME)));
}

int M4_CountPositions(int dir=0)
{
   int c=0; int total=PositionsTotal();
   for(int i=0;i<total;i++)
   {
      ulong t=PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol||PositionGetInteger(POSITION_MAGIC)!=CfgMagic) continue;
      if(dir==0){ c++; continue; }
      long type=PositionGetInteger(POSITION_TYPE);
      if(dir>0&&type==POSITION_TYPE_BUY) c++;
      if(dir<0&&type==POSITION_TYPE_SELL) c++;
   }
   return(c);
}


//==================================================================
// RISK ENGINE (DRDWCT) — VaR / Gamma / UDS / micro-bomb / auto-trim
// Per-position danger scoring with portfolio VaR backstop.
// Multi-campaign aware: longs and shorts evaluated on gross exposure.
//==================================================================
struct M4_Pos { ulong ticket; double lots; double entry; double sl; int dir; double pnl; };

double M4_LotValue(double lots){ return(lots*100.0); }   // contract size 100 (XAUUSD)
double M4_RD(double lots,double distSL){ return((distSL<=0)?1e10:lots/distSL); }
double M4_SAG(double lots,double distSL){ return((distSL<=0)?1e10:(lots*lots)/(distSL*distSL)); }
double M4_Gamma(double entry,double spot,double lots){ double d=entry-spot; return(d*d*lots); }

void M4_UpdateRisk()
{
   double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   gState.exec.equity=equity;
   if(!CfgEnableRiskEngine){ gState.exec.varBreach=false; gState.exec.anyBomb=false; return; }

   // collect our positions
   M4_Pos pos[64]; int n=0;
   int total=PositionsTotal();
   for(int i=0;i<total&&n<64;i++)
   {
      ulong t=PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol||PositionGetInteger(POSITION_MAGIC)!=CfgMagic) continue;
      pos[n].ticket=t; pos[n].lots=PositionGetDouble(POSITION_VOLUME);
      pos[n].entry=PositionGetDouble(POSITION_PRICE_OPEN);
      double sl=PositionGetDouble(POSITION_SL);
      pos[n].dir=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?1:-1;
      pos[n].sl=(sl>0)?sl:(pos[n].dir>0?pos[n].entry-10.0:pos[n].entry+10.0);
      pos[n].pnl=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP)+PositionGetDouble(POSITION_COMMISSION);
      n++;
   }
   if(n==0){ gState.exec.varBreach=false; gState.exec.anyBomb=false; gState.exec.var2=0; gState.exec.var3=0; gState.exec.udsMax=0; gState.exec.trimCount=0; return; }

   double spot=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double sigma=gState.physics.atr*2.0;  // ~2 ATR scenario sigma proxy

   // VaR: worst-case + 2-sigma scenario PnL (gross, multi-campaign safe)
   double worst=0; bool wInit=false; double near2=0; bool n2=false; double tgt2=spot-2*sigma;
   for(int sc=-3;sc<=3;sc++)
   {
      double price=spot+sc*sigma;
      double pnl=0;
      for(int i=0;i<n;i++){ double mv=price-pos[i].entry; pnl+=(pos[i].dir<0?-mv:mv)*M4_LotValue(pos[i].lots); }
      if(!wInit||pnl<worst){ worst=pnl; wInit=true; }
      double dd=MathAbs(price-tgt2);
      if(!n2||dd<near2){ near2=dd; n2=true; }
   }
   gState.exec.var3=MathAbs(worst);
   gState.exec.var2=MathAbs(worst)*0.5;  // 2-sigma proxy

   // UDS + micro-bomb (per-position risk density)
   double udsMax=0; bool anyBomb=false;
   for(int i=0;i<n;i++)
   {
      double distSL=MathAbs(pos[i].sl-pos[i].entry);
      double rd=M4_RD(pos[i].lots,distSL);
      double gamma=M4_Gamma(pos[i].entry,spot,pos[i].lots);
      double uds=MathMin(rd*50.0+gamma*0.0001,1.0);
      if(uds>udsMax) udsMax=uds;
      if(rd>CfgRDLimit) anyBomb=true;
   }
   gState.exec.udsMax=udsMax; gState.exec.anyBomb=anyBomb;

   // VaR limits (equity-tier, aggressive intraday)
   double v2Frac=0.03, v3Frac=0.06;
   if(equity<1000){ v2Frac=0.04; v3Frac=0.08; }
   else if(equity<100000){ v2Frac=0.03; v3Frac=0.06; }
   else { v2Frac=0.02; v3Frac=0.04; }
   bool var2Bad=(gState.exec.var2>v2Frac*equity);
   bool var3Bad=(gState.exec.var3>v3Frac*equity);
   gState.exec.varBreach=(var2Bad||var3Bad||anyBomb);

   // AUTO-TRIM: if breached, partial-close the highest-UDS position
   gState.exec.trimCount=0;
   if(gState.exec.varBreach && n>0)
   {
      int worstIdx=0; double worstUDS=-1;
      for(int i=0;i<n;i++)
      {
         double distSL=MathAbs(pos[i].sl-pos[i].entry);
         double rd=M4_RD(pos[i].lots,distSL);
         double uds=MathMin(rd*50.0,1.0);
         if(rd>CfgRDLimit) uds+=1.0;  // bomb priority
         if(uds>worstUDS){ worstUDS=uds; worstIdx=i; }
      }
      double closeLots=(pos[worstIdx].lots>=0.04)? pos[worstIdx].lots*0.4 : pos[worstIdx].lots;
      if(M4_ClosePartial(pos[worstIdx].ticket,closeLots))
      {
         gState.exec.trimCount=1;
         FALCON_Publish(EVT_RISK_BREACH);
         FALCON_Log(LOG_WARN,"M4.Risk","VaR breach - trimmed ticket "+IntegerToString((int)pos[worstIdx].ticket));
      }
   }
}


//==================================================================
// ARC + INSTITUTIONAL + PHASE EXITS (reads M1 ARC lines via gState)
//==================================================================
void M4_ManageExits()
{
   double atr=gState.physics.atr; if(atr<=0) return;
   double cl=gState.barClose;

   // ARC exhaustion (from wave/curve maturity + dissipation)
   bool arcExhaustLong = (gState.wave.direction==1 && gState.erf.dissipationProgress>60 && gState.wave.completion>80);
   bool arcExhaustShort= (gState.wave.direction==-1 && gState.erf.dissipationProgress>60 && gState.wave.completion>80);

   // Phase transition against position
   bool phaseEnd=(gState.wave.phase==WP_ABSORPTION||gState.wave.phase==WP_RETRACEMENT);

   bool exitLong  = (arcExhaustLong && phaseEnd);
   bool exitShort = (arcExhaustShort && phaseEnd);

   if(!exitLong && !exitShort) return;
   int total=PositionsTotal();
   for(int i=total-1;i>=0;i--)
   {
      ulong t=PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol||PositionGetInteger(POSITION_MAGIC)!=CfgMagic) continue;
      long type=PositionGetInteger(POSITION_TYPE);
      if(exitLong && type==POSITION_TYPE_BUY){ M4_CloseFull(t); FALCON_Log(LOG_INFO,"M4.Exit","ARC+Phase Long"); }
      if(exitShort && type==POSITION_TYPE_SELL){ M4_CloseFull(t); FALCON_Log(LOG_INFO,"M4.Exit","ARC+Phase Short"); }
   }
}

//==================================================================
// TRAILING STOP (breakeven at 1.5 ATR, trail to M5 swing)
//==================================================================
void M4_ManageTrailing()
{
   double atr=gState.physics.atr; if(atr<=0) return;
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID), ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   int total=PositionsTotal();
   for(int i=0;i<total;i++)
   {
      ulong t=PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol||PositionGetInteger(POSITION_MAGIC)!=CfgMagic) continue;
      long type=PositionGetInteger(POSITION_TYPE);
      double entry=PositionGetDouble(POSITION_PRICE_OPEN);
      double curSL=PositionGetDouble(POSITION_SL);
      if(type==POSITION_TYPE_BUY && bid-entry>atr*1.5)
      {
         double be=entry+atr*0.1;
         double sw=gState.tf[L_M5].swingLow;
         double newSL=MathMax(be, sw>0? sw-atr*0.15 : be);
         if(newSL>curSL && newSL<bid-atr*0.5) M4_SetSL(t,NormalizeDouble(newSL,digits));
      }
      else if(type==POSITION_TYPE_SELL && entry-ask>atr*1.5)
      {
         double be=entry-atr*0.1;
         double sw=gState.tf[L_M5].swingHigh;
         double newSL=MathMin(be, sw>0? sw+atr*0.15 : be);
         if(newSL<curSL && newSL>ask+atr*0.5) M4_SetSL(t,NormalizeDouble(newSL,digits));
      }
   }
}

void M4_SetSL(ulong ticket, double sl)
{
   MqlTradeRequest req; MqlTradeResult res; ZeroMemory(req); ZeroMemory(res);
   req.action=TRADE_ACTION_SLTP; req.position=ticket; req.symbol=_Symbol; req.sl=sl; req.tp=0;
   OrderSend(req,res);
}

//==================================================================
// CLOSE ALL (for EXIT verdict)
//==================================================================
void M4_CloseAll()
{
   int total=PositionsTotal();
   for(int i=total-1;i>=0;i--)
   {
      ulong t=PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol||PositionGetInteger(POSITION_MAGIC)!=CfgMagic) continue;
      M4_CloseFull(t);
   }
}


//==================================================================
// EXECUTION DISPATCH — obeys gState.intel.decision ONLY
// Execution never decides. It translates the verdict into orders.
//==================================================================
datetime m4_lastLongTime=0, m4_lastShortTime=0;

void M4_Execute()
{
   // refresh portfolio snapshot into state
   gState.exec.positionCount=M4_CountPositions(0);
   gState.exec.longCount=M4_CountPositions(1);
   gState.exec.shortCount=M4_CountPositions(-1);
   gState.exec.equity=AccountInfoDouble(ACCOUNT_EQUITY);
   double pnl=0; int total=PositionsTotal();
   for(int i=0;i<total;i++)
   {
      ulong t=PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol||PositionGetInteger(POSITION_MAGIC)!=CfgMagic) continue;
      pnl+=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP)+PositionGetDouble(POSITION_COMMISSION);
   }
   gState.exec.floatingPnl=pnl;
   gState.exec.tradeState=(gState.exec.longCount>0&&gState.exec.shortCount>0)?"MIXED":
      (gState.exec.longCount>0)?"LONG":(gState.exec.shortCount>0)?"SHORT":"FLAT";

   // always manage existing positions (risk-first)
   M4_ManageTrailing();
   M4_ManageExits();

   FALCON_Decision d=gState.intel.decision;

   // EXIT / DEFEND first (protective verdicts act regardless of session)
   if(d==DEC_EXIT){ M4_CloseAll(); FALCON_Publish(EVT_EXIT_FIRED); return; }
   if(d==DEC_DEFEND)
   {
      // tighten: move all to breakeven-ish (handled by trailing); no new risk
      return;
   }

   // Entry verdicts require: session ok, gate open, no VaR breach block
   bool sessionOK=M4_IsTradeTime();
   bool gateBlock=(CfgEnableRiskEngine && CfgBlockNewIfBreach && gState.exec.varBreach);
   if(!sessionOK || gateBlock) return;

   double riskCash=gState.exec.equity*CfgRiskPercent*0.01;
   double atr=gState.physics.atr;
   datetime bt=gState.barTime;

   bool wantLong  = (d==DEC_BUY) || (d==DEC_ATTACK && gState.intel.masterBias==1) || (d==DEC_SCALE && gState.intel.masterBias==1);
   bool wantShort = (d==DEC_SELL) || (d==DEC_ATTACK && gState.intel.masterBias==-1) || (d==DEC_SCALE && gState.intel.masterBias==-1);

   if(wantLong && m4_lastLongTime!=bt)
   {
      double entry=gState.barClose;
      double sl=(gState.wave.flipBot>0)? gState.wave.flipBot-atr*0.3 :
                (gState.tf[L_M5].invalidation>0)? gState.tf[L_M5].invalidation-atr*0.25 : entry-atr*2.0;
      double lots=M4_ComputeLots(riskCash,entry,sl);
      if(d==DEC_SCALE) lots*=0.5;  // scale-in is half size
      if(sl>0 && entry>sl && lots>0)
      {
         gState.exec.entry=entry; gState.exec.stop=sl; gState.exec.lotSize=lots;
         gState.exec.target=gState.curve.budgetTarget;
         gState.exec.risk=riskCash;
         gState.exec.reward=(gState.curve.budgetTarget>0)?MathAbs(gState.curve.budgetTarget-entry)/MathMax(MathAbs(entry-sl),1e-10):0;
         if(M4_SendOrder(1,lots,sl,"FALCON "+FALCON_DecisionStr(d)+" L"))
         {
            m4_lastLongTime=bt; FALCON_Publish(EVT_ENTRY_FIRED);
            FALCON_LogPerformance("ENTRY_LONG",0);
         }
      }
   }
   if(wantShort && m4_lastShortTime!=bt)
   {
      double entry=gState.barClose;
      double sl=(gState.wave.flipTop>0)? gState.wave.flipTop+atr*0.3 :
                (gState.tf[L_M5].invalidation>0)? gState.tf[L_M5].invalidation+atr*0.25 : entry+atr*2.0;
      double lots=M4_ComputeLots(riskCash,entry,sl);
      if(d==DEC_SCALE) lots*=0.5;
      if(sl>0 && sl>entry && lots>0)
      {
         gState.exec.entry=entry; gState.exec.stop=sl; gState.exec.lotSize=lots;
         gState.exec.target=gState.curve.budgetTarget;
         gState.exec.risk=riskCash;
         gState.exec.reward=(gState.curve.budgetTarget>0)?MathAbs(gState.curve.budgetTarget-entry)/MathMax(MathAbs(entry-sl),1e-10):0;
         if(M4_SendOrder(-1,lots,sl,"FALCON "+FALCON_DecisionStr(d)+" S"))
         {
            m4_lastShortTime=bt; FALCON_Publish(EVT_ENTRY_FIRED);
            FALCON_LogPerformance("ENTRY_SHORT",0);
         }
      }
   }
}

//+------------------------------------------------------------------+
