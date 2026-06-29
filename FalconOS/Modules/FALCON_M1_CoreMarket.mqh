//+------------------------------------------------------------------+
//| FALCON_M1_CoreMarket.mqh                                          |
//| FALCON OS - Module 1: Core Market Engine (Source: LETRA)          |
//|                                                                   |
//| Pure market model. Observes only. No execution, no dashboards.    |
//| Owns: Physics, Structure, Liquidity, Convexity, Wave, FU,         |
//|       Order Blocks, Supply/Demand, HTF.                           |
//| Writes ALL output into gState.physics/structure/liquidity/wave/   |
//| htf/fu and the 6-TF fractal stack gState.tf[].                    |
//| Every calculation lives here exactly once.                        |
//+------------------------------------------------------------------+
#property strict

//==================================================================
// SHARED CHART SERIES (loaded once per bar, used by all M1 stages)
//==================================================================
double m1_close[];
double m1_high[];
double m1_low[];
double m1_open[];
datetime m1_time[];
int    m1_bars = 0;
int    g_atrHandle = INVALID_HANDLE;

//--- Per-TF ATR handles for the fractal stack
int    g_tfAtrHandle[L_TFCOUNT];
ENUM_TIMEFRAMES g_tfPeriods[L_TFCOUNT];

//==================================================================
// SHARED MATH HELPERS (single implementation, used everywhere)
//==================================================================
double FClamp(double v, double lo, double hi)
{
   if(v < lo) return(lo);
   if(v > hi) return(hi);
   return(v);
}

double FEmaStep(double prev, double raw, int period)
{
   double a = 2.0 / (period + 1);
   return(prev + a * (raw - prev));
}

int FWaveDirByOrigin(double origin, double close, int fallback)
{
   if(origin == 0.0) return(fallback);
   if(close > origin) return(1);
   if(close < origin) return(-1);
   return(fallback);
}

double FIdealSim(double e,double d,double v,double c,double ei,double di,double vi,double ci)
{
   double diff = MathPow(e-ei,2)+MathPow(d-di,2)+MathPow(v-vi,2)+MathPow(c-ci,2);
   return(MathMax(0.0, 100.0*(1.0 - diff/4.0)));
}


//==================================================================
// INIT / DATA REFRESH
//==================================================================
void M1_Init()
{
   ArraySetAsSeries(m1_close, true);
   ArraySetAsSeries(m1_high, true);
   ArraySetAsSeries(m1_low, true);
   ArraySetAsSeries(m1_open, true);
   ArraySetAsSeries(m1_time, true);
   g_atrHandle = iATR(_Symbol, _Period, CfgATRLen);

   g_tfPeriods[L_M1]  = PERIOD_M1;
   g_tfPeriods[L_M3]  = PERIOD_M3;
   g_tfPeriods[L_M5]  = PERIOD_M5;
   g_tfPeriods[L_M15] = PERIOD_M15;
   g_tfPeriods[L_H1]  = PERIOD_H1;
   g_tfPeriods[L_H4]  = PERIOD_H4;
   for(int i = 0; i < L_TFCOUNT; i++)
      g_tfAtrHandle[i] = iATR(_Symbol, g_tfPeriods[i], CfgATRLen);
}

bool M1_RefreshSeries(int need = 600)
{
   if(need < 300) need = 300;
   int c1 = CopyClose(_Symbol, _Period, 0, need, m1_close);
   int c2 = CopyHigh(_Symbol, _Period, 0, need, m1_high);
   int c3 = CopyLow(_Symbol, _Period, 0, need, m1_low);
   int c4 = CopyOpen(_Symbol, _Period, 0, need, m1_open);
   int c5 = CopyTime(_Symbol, _Period, 0, need, m1_time);
   if(c1 < 100 || c2 < 100 || c3 < 100 || c4 < 100 || c5 < 100) return(false);
   m1_bars = c1;

   // snapshot bar context into shared state
   gState.barsAvailable = m1_bars;
   gState.barOpen  = m1_open[1];
   gState.barHigh  = m1_high[1];
   gState.barLow   = m1_low[1];
   gState.barClose = m1_close[1];
   gState.barTime  = m1_time[0];
   gState.diag.lastBarTime = m1_time[0];
   return(true);
}

double M1_ATR(int shift)
{
   if(g_atrHandle == INVALID_HANDLE) return(0);
   double b[];
   ArraySetAsSeries(b, true);
   if(CopyBuffer(g_atrHandle, 0, shift, 1, b) < 1) return(0);
   return(b[0]);
}

bool M1_PivotHigh(int c)
{
   if(c <= 0 || c >= m1_bars - CfgPivotLen) return(false);
   double h = m1_high[c];
   for(int k = 1; k <= CfgPivotLen; k++)
   {
      if(c+k >= m1_bars || c-k < 0) return(false);
      if(h <= m1_high[c+k] || h <= m1_high[c-k]) return(false);
   }
   return(true);
}

bool M1_PivotLow(int c)
{
   if(c <= 0 || c >= m1_bars - CfgPivotLen) return(false);
   double l = m1_low[c];
   for(int k = 1; k <= CfgPivotLen; k++)
   {
      if(c+k >= m1_bars || c-k < 0) return(false);
      if(l >= m1_low[c+k] || l >= m1_low[c-k]) return(false);
   }
   return(true);
}


//==================================================================
// STAGE 1 — PHYSICS  (writes gState.physics)
//==================================================================
void M1_UpdatePhysics()
{
   if(m1_bars < CfgEffLen + 10) return;
   int s = 1;
   double atr = M1_ATR(s);
   if(atr <= 0) return;

   double a3 = 0.5; // EMA(3) alpha
   double v0 = m1_close[s]-m1_close[s+1];
   double v1 = m1_close[s+1]-m1_close[s+2];
   double v2 = m1_close[s+2]-m1_close[s+3];
   double v3 = m1_close[s+3]-m1_close[s+4];
   double v4 = m1_close[s+4]-m1_close[s+5];
   double vel = v0*a3 + v1*a3*(1-a3) + v2*(1-a3)*(1-a3);
   double velPrev = v1*a3 + v2*a3*(1-a3) + v3*(1-a3)*(1-a3);
   double acc = vel - velPrev;
   double accPrev = velPrev - (v2*a3 + v3*a3*(1-a3) + v4*(1-a3)*(1-a3));
   double cvx = acc - accPrev;
   double cSmooth = cvx*a3 + gState.physics.convSmoothed*(1-a3);

   double move = MathAbs(m1_close[s] - m1_close[s+CfgEffLen]);
   double path = 0;
   for(int i=s; i<s+CfgEffLen && i<m1_bars-1; i++)
      path += MathAbs(m1_close[i]-m1_close[i+1]);
   double eff = (path>0) ? move/path : 0;
   double disp = (m1_high[s]-m1_low[s]) / MathMax(atr,1e-10);

   FALCON_Physics p;
   p.atr = atr;
   p.velocity = vel;
   p.acceleration = acc;
   p.convexity = cvx;
   p.convSmoothed = cSmooth;
   p.efficiency = eff;
   p.displacement = disp;
   p.momentum = vel - velPrev;
   p.energy = MathMin(eff*60.0 + (disp>CfgDispThresh?30.0:0.0), 100.0);
   p.expansion = MathMin(disp/MathMax(CfgDispThresh,1e-10)*50.0, 100.0);
   p.compression = FClamp((1.0-MathMin(disp/MathMax(CfgDispThresh,1e-10),1.0))*60.0 +
                          (1.0-MathMin(eff/MathMax(CfgEffThresh,1e-10),1.0))*40.0, 0, 100);
   double atrSma = 0; for(int i=1;i<=20;i++) atrSma += M1_ATR(i); atrSma/=20.0;
   p.volatility = (atrSma>0)? atr/atrSma : 1.0;

   double convTh = atr*CfgConvMult;
   p.bullImpulse = (eff>CfgEffThresh && vel>velPrev && acc>0 && m1_close[s]>m1_open[s] && disp>CfgDispThresh);
   p.bearImpulse = (eff>CfgEffThresh && vel<velPrev && acc<0 && m1_close[s]<m1_open[s] && disp>CfgDispThresh);
   p.bullMomDecay = (MathAbs(acc)<MathAbs(accPrev)*0.8 && vel>0);
   p.bearMomDecay = (MathAbs(acc)<MathAbs(accPrev)*0.8 && vel<0);
   p.bullConvShift = (cSmooth>convTh && gState.physics.convSmoothed<=convTh);
   p.bearConvShift = (cSmooth<-convTh && gState.physics.convSmoothed>=-convTh);
   p.velDecay70 = (MathAbs(vel)<MathAbs(velPrev)*0.7);
   p.velDecay50 = (MathAbs(vel)<MathAbs(velPrev)*0.5);

   gState.physics = p;
}


//==================================================================
// PER-TF STRUCTURE ENGINE STATE (the 6-TF fractal stack)
// Compact port of LETRA f_se: swings, BOS, CHoCH, impulse,
// direction, point4, invalidation, target, lifecycle, progress.
//==================================================================
struct M1_TFState
{
   double c[], h[], l[], o[];
   int    bars;
   double curSH, curSL, prSH, prSL;
   double lastPivP; int lastPivD;
   double prevPivP; int prevPivD;
   int    dir;
   double ft, fb, p4h, p4l, inv, tgt, cycH, cycL;
   int    phaseState, lastDirSeen;
   bool   bos1, bos2; double protSw, protSw2, indOrig, indExt; bool indBrk;
   int    recBreaks; bool recArmed; double recDom;
};
M1_TFState m1_tf[L_TFCOUNT];

double M1_TFAtr(int layer, int shift)
{
   if(g_tfAtrHandle[layer] == INVALID_HANDLE) return(0);
   double b[]; ArraySetAsSeries(b, true);
   if(CopyBuffer(g_tfAtrHandle[layer], 0, shift, 1, b) < 1) return(0);
   return(b[0]);
}

bool M1_TFRefresh(int layer)
{
   M1_TFState *s = GetPointer(m1_tf[layer]);
   ArraySetAsSeries(s.c,true); ArraySetAsSeries(s.h,true);
   ArraySetAsSeries(s.l,true); ArraySetAsSeries(s.o,true);
   ENUM_TIMEFRAMES tf = g_tfPeriods[layer];
   int n = 300;
   if(CopyClose(_Symbol,tf,0,n,s.c)<50) return(false);
   if(CopyHigh(_Symbol,tf,0,n,s.h)<50) return(false);
   if(CopyLow(_Symbol,tf,0,n,s.l)<50) return(false);
   if(CopyOpen(_Symbol,tf,0,n,s.o)<50) return(false);
   s.bars = ArraySize(s.c);
   return(true);
}

bool M1_TFPivH(int layer, int c)
{
   M1_TFState *s = GetPointer(m1_tf[layer]);
   if(c<=0 || c>=s.bars-CfgPivotLen) return(false);
   double h=s.h[c];
   for(int k=1;k<=CfgPivotLen;k++){ if(c+k>=s.bars||c-k<0)return(false); if(h<=s.h[c+k]||h<=s.h[c-k])return(false);}
   return(true);
}
bool M1_TFPivL(int layer, int c)
{
   M1_TFState *s = GetPointer(m1_tf[layer]);
   if(c<=0 || c>=s.bars-CfgPivotLen) return(false);
   double l=s.l[c];
   for(int k=1;k<=CfgPivotLen;k++){ if(c+k>=s.bars||c-k<0)return(false); if(l>=s.l[c+k]||l>=s.l[c-k])return(false);}
   return(true);
}


//--- Run one TF structure engine, write into gState.tf[layer]
void M1_RunTFEngine(int layer)
{
   M1_TFState *s = GetPointer(m1_tf[layer]);
   if(s.bars < 50) return;
   double atr = M1_TFAtr(layer, 1);
   if(atr <= 0) return;
   int sh = 1;
   double cl = s.c[sh], hi = s.h[sh], lo = s.l[sh], op = s.o[sh];

   // physics (lightweight)
   double eff=0, disp=0, vel=0;
   if(s.bars > CfgEffLen+5)
   {
      vel = (s.c[sh]-s.c[sh+1]);
      double mv = MathAbs(s.c[sh]-s.c[sh+CfgEffLen]);
      double ps=0; for(int i=sh;i<sh+CfgEffLen && i<s.bars-1;i++) ps+=MathAbs(s.c[i]-s.c[i+1]);
      eff = (ps>0)? mv/ps : 0;
      disp = (hi-lo)/MathMax(atr,1e-10);
   }
   double compIdx = FClamp((1.0-MathMin(disp/MathMax(CfgDispThresh,1e-10),1.0))*60.0 +
                           (1.0-MathMin(eff/MathMax(CfgEffThresh,1e-10),1.0))*40.0, 0, 100);

   // swings
   int cen = CfgPivotLen+1;
   double pivH=0,pivL=0; bool hasH=false,hasL=false;
   if(cen < s.bars-CfgPivotLen)
   {
      if(M1_TFPivH(layer,cen)){ pivH=s.h[cen]; hasH=true; }
      if(M1_TFPivL(layer,cen)){ pivL=s.l[cen]; hasL=true; }
   }
   if(hasH){ s.prSH = (s.curSH==0)?pivH:s.curSH; s.curSH=pivH; }
   if(hasL){ s.prSL = (s.curSL==0)?pivL:s.curSL; s.curSL=pivL; }

   int pivD=0; double pivP=0;
   if(hasH){ pivD=1; pivP=pivH; } else if(hasL){ pivD=-1; pivP=pivL; }
   if(pivD!=0){ s.prevPivP=s.lastPivP; s.prevPivD=s.lastPivD; s.lastPivP=pivP; s.lastPivD=pivD; }

   bool bullBOS = (s.prSH>0 && cl>s.prSH);
   bool bearBOS = (s.prSL>0 && cl<s.prSL);
   bool bullCH  = (s.prSH>0 && cl>s.prSH+atr*CfgChochBufferATR);
   bool bearCH  = (s.prSL>0 && cl<s.prSL-atr*CfgChochBufferATR);
   bool eLong   = (hasH && s.prevPivD==-1 && (pivH-s.prevPivP)>atr*CfgImpulseAtrMult);
   bool eShort  = (hasL && s.prevPivD==1  && (s.prevPivP-pivL)>atr*CfgImpulseAtrMult);

   bool hasCtx = (s.dir!=0 && s.ft>0);
   bool flipDn = (s.dir==1 && bearCH);
   bool flipUp = (s.dir==-1 && bullCH);
   bool isRev  = (eLong&&s.dir==-1)||(eShort&&s.dir==1)||flipUp||flipDn;
   bool spawn  = (eLong||eShort||flipUp||flipDn)&&(!hasCtx||isRev);
   if(spawn)
   {
      int nd = eLong?1: eShort?-1: flipUp?1:-1;
      double hh=MathMax(s.lastPivP,s.prevPivP), ll=MathMin(s.lastPivP,s.prevPivP);
      s.dir=nd; s.ft=hh; s.fb=ll; s.p4h=hh; s.p4l=ll; s.cycH=hi; s.cycL=lo;
      s.inv = (nd==1)? ll : hh;
      double rng = (s.prSH>0&&s.prSL>0)? MathAbs(s.prSH-s.prSL): atr*5.0;
      s.tgt = (nd==1)? hh+rng : ll-rng;
      s.phaseState=0; s.bos1=false; s.bos2=false; s.protSw=0; s.protSw2=0;
      s.indOrig=0; s.indExt=0; s.indBrk=false; s.recBreaks=0; s.recArmed=true; s.recDom=0;
   }
   if(s.dir==1) s.cycH=MathMax(s.cycH,hi);
   if(s.dir==-1) s.cycL=(s.cycL==0)?lo:MathMin(s.cycL,lo);
   M1_TFLifecycle(layer, atr, cl, hi, lo, bullCH, bearCH, eLong, eShort,
                  hasH, hasL, pivH, pivL, eff, disp, compIdx, bullBOS, bearBOS);
}


//--- Lifecycle state machine + write to gState.tf[layer]
void M1_TFLifecycle(int layer,double atr,double cl,double hi,double lo,
   bool bullCH,bool bearCH,bool eLong,bool eShort,bool hasH,bool hasL,
   double pivH,double pivL,double eff,double disp,double compIdx,
   bool bullBOS,bool bearBOS)
{
   M1_TFState *s = GetPointer(m1_tf[layer]);

   bool reset = (s.dir != s.lastDirSeen);
   s.lastDirSeen = s.dir;
   if(reset){ s.bos1=false; s.bos2=false; s.protSw=0; s.protSw2=0; s.indOrig=0; s.indExt=0; s.indBrk=false; }
   if(s.dir==1 && hasL){ s.protSw2=s.protSw; s.protSw=pivL; }
   if(s.dir==-1 && hasH){ s.protSw2=s.protSw; s.protSw=pivH; }

   bool oppBOS = (s.dir==1 && s.protSw>0 && cl<s.protSw) || (s.dir==-1 && s.protSw>0 && cl>s.protSw);
   if(!s.bos1 && oppBOS){ s.bos1=true; s.indOrig=(s.dir==1)?s.cycH:s.cycL; }
   if(s.bos1 && !s.bos2 && oppBOS && s.protSw2>0)
   { if((s.dir==1 && cl<s.protSw2)||(s.dir==-1 && cl>s.protSw2)) s.bos2=true; }
   if(s.bos1 && s.dir==1)  s.indExt=(s.indExt==0)?cl:MathMin(s.indExt,cl);
   if(s.bos1 && s.dir==-1) s.indExt=(s.indExt==0)?cl:MathMax(s.indExt,cl);
   if(s.bos2 && s.indOrig>0)
   { if(s.dir==1&&cl>s.indOrig)s.indBrk=true; if(s.dir==-1&&cl<s.indOrig)s.indBrk=true; }

   bool atExtreme = (s.dir==1? hi>=s.cycH : lo<=s.cycL);
   bool extended  = (s.inv>0 && MathAbs((s.dir==1?s.cycH:s.cycL)-s.inv)>atr*1.5);
   bool phase2CH  = (s.dir==1&&bearCH)||(s.dir==-1&&bullCH);
   if(reset||(atExtreme&&extended)){ s.recBreaks=0; s.recArmed=true; }
   if((s.dir==1&&hasH)||(s.dir==-1&&hasL)) s.recArmed=true;
   if((phase2CH||oppBOS)&&s.recArmed&&!atExtreme){ s.recBreaks++; s.recArmed=false; }
   double extr=(s.dir==1)?s.cycH:s.cycL;
   double fzMid=(s.ft>0&&s.fb>0)?(s.ft+s.fb)/2.0:0;
   double retrFrac=(fzMid>0&&MathAbs(extr-fzMid)>1e-10)?MathAbs(extr-cl)/MathAbs(extr-fzMid):0;
   s.recDom=MathMin(100.0,MathMax(s.recBreaks*(30.0-compIdx*0.15),retrFrac*80.0));

   double convScore=MathMin(MathAbs(s.c[1]-s.c[2])/MathMax(atr*CfgConvMult,1e-10)*5.0,100.0);
   bool momExpStrong=(eff>CfgEffThresh*0.75 && (s.dir==1?s.c[1]>s.c[2]:s.c[1]<s.c[2]));
   bool momDecaying=(s.dir==1?(s.c[1]<s.c[2]&&s.c[1]>s.c[3]):(s.c[1]>s.c[2]&&s.c[1]<s.c[3]));
   bool momCounter=(s.dir==1?(s.c[1]<s.c[2]&&disp>CfgDispThresh):(s.c[1]>s.c[2]&&disp>CfgDispThresh));
   bool momExhaust=(eff<CfgEffThresh*0.65);
   bool physTransfer=(convScore>48.0);
   bool physConvDevel=(convScore>35.0);
   bool physCapLow=(eff<CfgEffThresh*0.6);

   if(reset) s.phaseState=0;
   if(s.dir!=0 && !reset)
   {
      bool expanding=momExpStrong||eLong||eShort||(s.dir==1?bullBOS:bearBOS);
      if(s.phaseState<1 && expanding) s.phaseState=1;
      if(s.phaseState<2 && s.bos1 && momDecaying && physConvDevel) s.phaseState=2;
      if(s.phaseState<3 && s.bos1 && momCounter && physTransfer) s.phaseState=3;
      if(s.phaseState<4 && s.bos2 && (momDecaying||momCounter) && physTransfer) s.phaseState=4;
      if(s.phaseState<5 && s.indBrk && momExpStrong && !physCapLow) s.phaseState=5;
      if(s.phaseState>=5 && momExhaust && physCapLow) s.phaseState=7;
      if(s.phaseState>=5 && momCounter && !momExhaust && physTransfer) s.phaseState=8;
   }
   int phase=s.phaseState;
   if(phase==5 && s.dir==-1) phase=6;
   double wp=(s.phaseState==0)?10.0:(s.phaseState==1)?25.0:(s.phaseState==2)?40.0:
            (s.phaseState==3)?55.0:(s.phaseState==4)?68.0:(s.phaseState==5)?80.0:
            (s.phaseState==7)?92.0:85.0;

   FALCON_TFStructure o;
   o.direction=FWaveDirByOrigin(s.inv,cl,s.dir);
   o.phase=(FALCON_WavePhase)phase;
   o.swingHigh=s.curSH; o.swingLow=s.curSL; o.prevSwingHigh=s.prSH; o.prevSwingLow=s.prSL;
   o.bos=bullBOS?1:bearBOS?-1:0; o.choch=bullCH?1:bearCH?-1:0;
   o.point4High=s.p4h; o.point4Low=s.p4l; o.invalidation=s.inv; o.target=s.tgt;
   o.flipTop=s.ft; o.flipBot=s.fb; o.waveProgress=wp; o.convexityMaturity=MathMin(convScore,100.0);
   o.modelFit=MathMin(MathMax(eff*100.0,convScore)*0.7+(s.dir!=0?30.0:0.0),100.0);
   o.compression=compIdx; o.recursiveBreaks=s.recBreaks; o.recursiveDominance=s.recDom;
   gState.tf[layer]=o;
}


//==================================================================
// STAGE 2 — STRUCTURE  (runs 6-TF engines + chart structure + HTF stack)
//==================================================================
void M1_UpdateStructure()
{
   // Run all 6 TF structure engines (the fractal stack)
   for(int i = 0; i < L_TFCOUNT; i++)
   {
      if(M1_TFRefresh(i))
         M1_RunTFEngine(i);
   }

   // Chart structure from M5 engine (execution context) projected to gState.structure
   FALCON_TFStructure m5 = gState.tf[L_M5];
   FALCON_Structure st;
   st.trend = m5.direction;
   st.swingHigh = m5.swingHigh;
   st.swingLow = m5.swingLow;
   st.prevSwingHigh = m5.prevSwingHigh;
   st.prevSwingLow = m5.prevSwingLow;
   st.bos = m5.bos;
   st.choch = m5.choch;
   st.isHH = (m5.swingHigh > m5.prevSwingHigh && m5.prevSwingHigh > 0);
   st.isLH = (m5.swingHigh < m5.prevSwingHigh && m5.prevSwingHigh > 0);
   st.isHL = (m5.swingLow > m5.prevSwingLow && m5.prevSwingLow > 0);
   st.isLL = (m5.swingLow < m5.prevSwingLow && m5.prevSwingLow > 0);
   st.breakStrength = (gState.physics.atr > 0 && m5.prevSwingHigh > 0) ?
      MathAbs(gState.barClose - m5.prevSwingHigh) / gState.physics.atr : 0;
   st.internalStructure = gState.tf[L_M1].direction + gState.tf[L_M3].direction;
   st.externalStructure = gState.tf[L_H1].direction + gState.tf[L_H4].direction;
   gState.structure = st;
}

//==================================================================
// FRACTAL STACK (HTF) — called from HTF stage
//==================================================================
void M1_ComputeFractalStack()
{
   int bull=0, bear=0;
   for(int i=0;i<L_TFCOUNT;i++)
   {
      if(gState.tf[i].direction==1) bull++;
      if(gState.tf[i].direction==-1) bear++;
   }
   FALCON_HTF h;
   h.fractalDir = (bull>bear)?1:(bear>bull)?-1:0;
   h.fractalScore = MathMax(bull,bear)/6.0*100.0;
   double wts[6]={4.0,6.0,14.0,20.0,26.0,30.0};
   double ctx=0;
   if(h.fractalDir!=0)
      for(int i=0;i<L_TFCOUNT;i++) if(gState.tf[i].direction==h.fractalDir) ctx+=wts[i];
   h.contextScore = MathMin(ctx,100.0);
   h.direction = h.fractalDir;
   h.alignment = h.fractalScore;
   h.conflict = 100.0 - h.fractalScore;
   h.fractalAgreement = h.fractalScore;
   h.dominance = h.contextScore;
   // HTF beliefs from H1+H4
   int sumHTF = gState.tf[L_H1].direction + gState.tf[L_H4].direction;
   h.beliefBull = (sumHTF>0)? 50.0+sumHTF*25.0 : 50.0;
   h.beliefBear = (sumHTF<0)? 50.0-sumHTF*25.0 : 50.0;
   gState.htf = h;
}

//==================================================================
// STAGE — HTF (fractal stack)
//==================================================================
void M1_UpdateHTF()
{
   M1_ComputeFractalStack();
}


//==================================================================
// STAGE 3 — LIQUIDITY (heatmap + sweep + pools)  writes gState.liquidity
//==================================================================
double m1_liqLvl[]; double m1_liqWt[]; int m1_liqAge[]; int m1_liqCount=0;
#define M1_LIQ_MAX 150

void M1_UpdateLiquidity()
{
   if(m1_bars < CfgPivotLen+5) return;
   double atr = gState.physics.atr;
   if(atr <= 0) return;
   if(ArraySize(m1_liqLvl)==0)
   { ArrayResize(m1_liqLvl,M1_LIQ_MAX); ArrayResize(m1_liqWt,M1_LIQ_MAX); ArrayResize(m1_liqAge,M1_LIQ_MAX); }

   int sh = CfgPivotLen+1;
   bool nh = M1_PivotHigh(sh), nl = M1_PivotLow(sh);
   if(nh || nl)
   {
      double lvl = nh? m1_high[sh] : m1_low[sh];
      double wt = (m1_high[sh]-m1_low[sh])/MathMax(atr,1e-10);
      if(m1_liqCount < M1_LIQ_MAX)
      { m1_liqLvl[m1_liqCount]=lvl; m1_liqWt[m1_liqCount]=wt; m1_liqAge[m1_liqCount]=0; m1_liqCount++; }
      else
      {
         for(int i=0;i<m1_liqCount-1;i++){ m1_liqLvl[i]=m1_liqLvl[i+1]; m1_liqWt[i]=m1_liqWt[i+1]; m1_liqAge[i]=m1_liqAge[i+1]; }
         m1_liqLvl[m1_liqCount-1]=lvl; m1_liqWt[m1_liqCount-1]=wt; m1_liqAge[m1_liqCount-1]=0;
      }
   }
   for(int i=0;i<m1_liqCount;i++) m1_liqAge[i]++;

   double cl = m1_close[1];
   double rad=atr*0.25, radW=atr*0.75, dcyBase=0.95;
   double wD=0,wA=0,wB=0;
   for(int i=0;i<m1_liqCount;i++)
   {
      double dcy=MathPow(dcyBase,m1_liqAge[i]);
      double dist=MathAbs(cl-m1_liqLvl[i]);
      if(dist<rad) wD+=m1_liqWt[i]*dcy;
      if(dist<radW){ if(m1_liqLvl[i]>cl) wA+=m1_liqWt[i]*dcy*(1.0-dist/radW); else wB+=m1_liqWt[i]*dcy*(1.0-dist/radW); }
   }

   FALCON_Liquidity lq = gState.liquidity;
   lq.heat = FClamp(MathMin((wA+wB)/2.0,5.0)/5.0*100.0, 0, 100);
   lq.clusterDensity = wD;
   lq.pressure = (wA+wB>0)? (wB-wA)/(wA+wB)*100.0 : 0;
   lq.score = lq.heat;
   bool vac = (wD<0.5);
   lq.sweepBull = (gState.wave.flipTop>0 && m1_high[1]>gState.wave.flipTop);
   lq.sweepBear = (gState.wave.flipBot>0 && m1_low[1]<gState.wave.flipBot);
   lq.sweepProbability = lq.heat;
   lq.acceptance = (gState.wave.flipTop>0 && cl<=gState.wave.flipTop && cl>=gState.wave.flipBot);
   lq.sweepOK = (lq.sweepBull || lq.sweepBear || vac);
   gState.liquidity = lq;
}

//==================================================================
// STAGE 4 — CONVEXITY (maturity + observation scores)
//==================================================================
double m1_convMaturity=0;
void M1_UpdateConvexity()
{
   FALCON_Physics p = gState.physics;
   double atr=p.atr; if(atr<=0) return;
   double convScore=MathMin(MathAbs(p.convSmoothed)/MathMax(atr*CfgConvMult,1e-10)*25.0,100.0);
   bool preConv=(p.bullMomDecay||p.bearMomDecay);
   double obsDecay=MathMin((preConv?40.0:0.0)+(convScore>30?convScore*0.5:0.0)+(p.velDecay70?30.0:0.0),100.0);
   double obsLiq=MathMin(obsDecay*0.4+convScore*0.4,100.0);
   double expWeak=MathMin(((p.efficiency<CfgEffThresh?(1.0-p.efficiency/MathMax(CfgEffThresh,1e-10))*40.0:0.0)+obsDecay*0.30+(p.velDecay70?20.0:0.0))*(100.0/90.0),100.0);
   double liqMat=MathMin(obsLiq*0.5+(gState.liquidity.heat>60?20.0:gState.liquidity.heat>30?10.0:0.0)+(gState.liquidity.sweepOK?30.0:0.0),100.0);
   double inducMat=MathMin(convScore*0.35+(preConv?20.0:0.0),100.0);
   double raw=MathMin(expWeak*0.35+inducMat*0.35+liqMat*0.30,100.0);
   m1_convMaturity=FEmaStep(m1_convMaturity,raw,CfgBeliefSmooth);
   gState.wave.convexity = convScore;
   gState.wave.preConvexity = expWeak;
   gState.wave.absorption = obsDecay;
   gState.wave.liquidation = obsLiq;
}


//==================================================================
// STAGE 5 — WAVE (spawn engine + lifecycle + ARC, writes gState.wave)
// M5-governed execution wave context (LETRA Section 13)
//==================================================================
double m1_arcLong=0, m1_arcShort=0;
int    m1_mode=0; double m1_anchorHigh=0, m1_anchorLow=0; int m1_anchorHighShift=-1, m1_anchorLowShift=-1;
int    m1_obBirthBar=-1;

void M1_UpdateWave()
{
   FALCON_TFStructure m5 = gState.tf[L_M5];
   int l0Dir = m5.direction;
   FALCON_Wave w = gState.wave;

   // Spawn on M5 flip
   if(l0Dir != 0 && l0Dir != w.direction)
   {
      w.direction = l0Dir;
      w.flipTop = (m5.point4High>0)? m5.point4High : m5.flipTop;
      w.flipBot = (m5.point4Low>0)? m5.point4Low : m5.flipBot;
      w.point4High = w.flipTop;
      w.point4Low = w.flipBot;
      w.origin = m5.invalidation;
      w.target = m5.target;
      w.cycleHigh = m1_high[1];
      w.cycleLow = m1_low[1];
      w.isRecursive = false;
      w.entryCycle = 0;
      w.waveDepth = 0;
      w.recursiveComplete = false;
      w.age = 0;
      m1_obBirthBar = 0;
      FALCON_Log(LOG_INFO, "M1.Wave", "Spawn dir="+IntegerToString(l0Dir));
   }
   // Update cycle extremes
   if(w.direction==1 && m1_high[1]>w.cycleHigh) w.cycleHigh=m1_high[1];
   if(w.direction==-1 && (w.cycleLow==0 || m1_low[1]<w.cycleLow)) w.cycleLow=m1_low[1];
   w.age++;

   // Phase from M5 engine (Engine 1A authority)
   w.phase = m5.phase;
   w.completion = m5.waveProgress;
   w.origin = m5.invalidation;
   w.target = m5.target;

   // Invalidation check
   double atr=gState.physics.atr;
   if(w.direction==1 && w.flipBot>0 && m1_close[1]<w.flipBot-atr*0.5)
   { w.direction=0; w.flipTop=0; w.flipBot=0; }
   if(w.direction==-1 && w.flipTop>0 && m1_close[1]>w.flipTop+atr*0.5)
   { w.direction=0; w.flipTop=0; w.flipBot=0; }

   // Wave component scores via similarity engine
   double eN=MathMin(gState.physics.efficiency,1.0);
   double dN=MathMin(gState.physics.displacement/MathMax(CfgDispThresh*2.0,1e-10),1.0);
   double vN=MathMin(MathAbs(gState.physics.velocity)/MathMax(atr*0.15,1e-10),1.0);
   double cN=MathMin(MathAbs(gState.physics.convSmoothed)/MathMax(atr*CfgConvMult*2.0,1e-10),1.0);
   w.expansion=FIdealSim(eN,dN,vN,cN,0.85,0.80,0.80,0.10);
   w.retracement=FIdealSim(eN,dN,vN,cN,0.70,0.65,0.65,0.25);
   w.induction=FIdealSim(eN,dN,vN,cN,0.65,0.60,0.30,0.60);
   w.strength=MathMax(w.expansion,w.retracement);
   w.energy=gState.physics.energy;
   w.confidence=m5.modelFit;

   gState.wave = w;

   // ARC v2 (Symphony) - convexity arc target lines
   m1_arcLong=0; m1_arcShort=0;
   if(w.direction==1 && w.origin>0 && w.cycleHigh>0)
   {
      double imp=w.cycleHigh-w.origin;
      if(imp>0){ double t=FClamp((double)(w.age)/(double)CfgArcHorizonBars,0,1); m1_arcLong=w.origin+(w.origin+imp*CfgArcExtMult-w.origin)*MathPow(t,CfgConvPower);}
   }
   if(w.direction==-1 && w.origin>0 && w.cycleLow>0)
   {
      double imp=w.origin-w.cycleLow;
      if(imp>0){ double t=FClamp((double)(w.age)/(double)CfgArcHorizonBars,0,1); m1_arcShort=w.origin+((w.origin-imp*CfgArcExtMult)-w.origin)*MathPow(t,CfgConvPower);}
   }
}


//==================================================================
// STAGE 6 — FU ENGINE (chart-TF FU wick authority + zone)
// Order blocks + supply/demand are captured as FU zones here.
//==================================================================
void M1_UpdateFU()
{
   if(m1_bars < CfgFULookback+3) return;
   double atr=gState.physics.atr; if(atr<=0) return;
   int s=1;
   double range=MathMax(m1_high[s]-m1_low[s],1e-10);
   double priorHi=0, priorLo=99999999;
   for(int i=s+1;i<=s+CfgFULookback && i<m1_bars;i++)
   { if(m1_high[i]>priorHi)priorHi=m1_high[i]; if(m1_low[i]<priorLo)priorLo=m1_low[i]; }

   double minWick=0.4;
   bool bearCand=(priorHi>0 && m1_high[s]>priorHi && m1_close[s]<priorHi &&
                  (m1_high[s]-MathMax(m1_open[s],m1_close[s]))/range>=minWick);
   bool bullCand=(priorLo<99999999 && m1_low[s]<priorLo && m1_close[s]>priorLo &&
                  (MathMin(m1_open[s],m1_close[s])-m1_low[s])/range>=minWick);

   FALCON_FU fu = gState.fu;
   if(bearCand)
   {
      fu.wickDirection=-1; fu.wickTip=m1_high[s];
      double bH=MathMax(m1_open[s],m1_close[s]);
      fu.wickMid=bH+(m1_high[s]-bH)*0.50;
      fu.inductionBandLo=bH+(m1_high[s]-bH)*0.38;
      fu.inductionBandHi=bH+(m1_high[s]-bH)*0.62;
      fu.leftPoolMagnet=priorHi; fu.wickValidated=false;
      fu.zoneTop=bH; fu.zoneBot=m1_low[s]; fu.candleActive=true;
      fu.strength=MathMin(100.0,(m1_high[s]-bH)/MathMax(atr,1e-10)*40.0+40.0);
   }
   else if(bullCand)
   {
      fu.wickDirection=1; fu.wickTip=m1_low[s];
      double bL=MathMin(m1_open[s],m1_close[s]);
      fu.wickMid=m1_low[s]+(bL-m1_low[s])*0.50;
      fu.inductionBandLo=m1_low[s]+(bL-m1_low[s])*0.38;
      fu.inductionBandHi=m1_low[s]+(bL-m1_low[s])*0.62;
      fu.leftPoolMagnet=priorLo; fu.wickValidated=false;
      fu.zoneTop=m1_high[s]; fu.zoneBot=bL; fu.candleActive=true;
      fu.strength=MathMin(100.0,(bL-m1_low[s])/MathMax(atr,1e-10)*40.0+40.0);
   }
   // validation: opposite extreme broken
   if(!fu.wickValidated && fu.wickTip>0)
   {
      if(fu.wickDirection==-1 && m1_close[s]<fu.zoneBot) fu.wickValidated=true;
      if(fu.wickDirection==1 && m1_close[s]>fu.zoneTop) fu.wickValidated=true;
   }
   fu.confidence=fu.strength;
   fu.lifecycle = fu.wickValidated?1:0;
   gState.fu = fu;
}

//+------------------------------------------------------------------+
